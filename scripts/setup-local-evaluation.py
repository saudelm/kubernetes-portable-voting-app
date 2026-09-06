#!/usr/bin/env python3
"""Create only a new, isolated local evaluation cluster; never touch the demo."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def check_name(value):
    if not re.fullmatch(r"voting-test-[a-z0-9-]{1,20}", value):
        raise ValueError("Name must be voting-test-* with at most 32 characters")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True, type=check_name)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--build-record", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--execute", action="store_true", help="Actually create the new cluster")
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535 or args.port in (8080, 8443):
        parser.error("Use a free non-demo port between 1024 and 65535")
    record_path = Path(args.build_record).resolve()
    build = json.loads(record_path.read_text())
    if set(build.get("images", {})) != {"vote", "result", "worker"} or not build.get("finished_utc"):
        parser.error("A completed three-image build record is required")
    tags = {i["reference"].rsplit(":", 1)[1] for i in build["images"].values()}
    if len(tags) != 1:
        parser.error("All three image tags must agree")
    output = Path(args.output).resolve()
    if output.exists():
        parser.error("Output directory already exists; do not overwrite a previous run")
    for key in ("TF_VAR_postgres_password", "TF_VAR_grafana_admin_password"):
        if len(os.environ.get(key, "")) < 16:
            parser.error(key + " must be supplied externally with at least 16 characters")
    docker = json.loads(subprocess.check_output(["docker", "info", "--format", "{{json .}}"], text=True))
    if docker["MemTotal"] < 7 * 1024 ** 3:
        parser.error("Insufficient Docker RAM for demo plus complete evaluation; obtain approval before changing RAM")
    clusters = json.loads(subprocess.check_output(["k3d", "cluster", "list", "-o", "json"], text=True))
    if any(c["name"] == args.name for c in clusters):
        parser.error("Cluster already exists; refusing to reuse it")
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", args.port))
    for image in build["images"].values():
        inspected = json.loads(subprocess.check_output(["docker", "image", "inspect", image["reference"]], text=True))[0]
        if inspected["Id"] not in image["runtime_digests"]:
            parser.error("A local image no longer matches the build record")
        if inspected["Architecture"] != docker["Architecture"].replace("aarch64", "arm64").replace("x86_64", "amd64"):
            parser.error("Image architecture does not match the local Docker host")
    output.mkdir(parents=True, mode=0o700)
    output.chmod(0o700)
    source = output / "source"
    source.mkdir()
    source_root = record_path.parent / "source" if build["mode"] == "final" else ROOT
    for directory in ("infra/onprem-k3d", "charts/voting-app"):
        shutil.copytree(source_root / directory, source / directory,
                        ignore=shutil.ignore_patterns(".terraform", "*.tfstate*", "*.tfvars*", "tfplan*", "crash.log"))
    hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in source.rglob("*") if p.is_file()}
    suffix = args.name + ".127.0.0.1.nip.io"
    config = {
        "kubeconfig_path": str(output / "kubeconfig"),
        "kube_context": "k3d-" + args.name,
        "app_namespace": args.name, "app_release": args.name, "isolated_test": True,
        "http_port": args.port, "host_suffix": suffix, "enable_monitoring": True,
        "image_tag": tags.pop(),
        "image_repositories": {k: v["reference"].rsplit(":", 1)[0] for k, v in build["images"].items()}
    }
    module = source / "infra/onprem-k3d"
    (module / "evaluation.auto.tfvars.json").write_text(json.dumps(config, indent=2) + "\n")
    report = {"status": "NOT_RUN", "source_commit": build["source_commit"], "mode": build["mode"],
              "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "configuration_sha256": hashes,
              "build_record": str(record_path), "cluster": args.name, "namespace": args.name,
              "release": args.name, "context": config["kube_context"],
              "kubeconfig": config["kubeconfig_path"], "steps": [],
              "urls": {k: "http://" + k + "." + suffix + ":" + str(args.port) for k in ("vote", "result", "grafana")}}
    def command(command, private=False, timeout=1200):
        started = time.monotonic()
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        report["steps"].append({"command": command, "seconds": round(time.monotonic() - started, 3),
                                "exit_code": result.returncode})
        if not private:
            log = output / ("step-" + str(len(report["steps"])) + ".log")
            log.write_text(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError("Setup command failed; inspect private setup directory: " + command[0])
        return result.stdout
    try:
        if not args.execute:
            print("Prepared only; cluster not created. Use a NEW output directory with --execute after review.")
            return
        command(["k3d", "cluster", "create", args.name, "--servers", "1", "--agents", "2",
                 "--image", "rancher/k3s:v1.35.4-k3s1", "--api-port", "127.0.0.1:0",
                 "--kubeconfig-update-default=false", "--kubeconfig-switch-context=false",
                 "--k3s-arg", "--disable=traefik@server:*", "--port",
                 "127.0.0.1:" + str(args.port) + ":80@loadbalancer", "--wait", "--timeout", "300s"])
        kubeconfig = command(["k3d", "kubeconfig", "get", args.name], private=True)
        Path(config["kubeconfig_path"]).write_text(kubeconfig)
        Path(config["kubeconfig_path"]).chmod(0o600)
        command(["k3d", "image", "import", *[i["reference"] for i in build["images"].values()], "-c", args.name])
        command(["terraform", "-chdir=" + str(module), "init", "-input=false"])
        command(["terraform", "-chdir=" + str(module), "validate"])
        command(["terraform", "-chdir=" + str(module), "plan", "-input=false", "-out=evaluation.tfplan"])
        plan = json.loads(command(["terraform", "-chdir=" + str(module), "show", "-json", "evaluation.tfplan"], private=True))
        allowed = {"kubernetes_namespace_v1", "helm_release"}
        for change in plan.get("resource_changes", []):
            if change["type"] not in allowed or change["change"]["actions"] not in (["create"], ["no-op"]):
                raise RuntimeError("Unexpected Terraform operation; refusing apply")
        command(["terraform", "-chdir=" + str(module), "apply", "-input=false", "evaluation.tfplan"], timeout=2400)
        report["status"] = "PASS"
    except Exception as exc:
        report.update(status="ERROR", error=str(exc))
        raise
    finally:
        report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        (output / "setup-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"status": report["status"], "report": str(output / "setup-report.json"),
                          "urls": report["urls"]}, indent=2))


if __name__ == "__main__":
    main()

