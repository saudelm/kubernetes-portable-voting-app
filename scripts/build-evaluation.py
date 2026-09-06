#!/usr/bin/env python3
"""Build exact committed sources, never publish images or mutate a cluster."""
import argparse
import datetime as dt
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[1]


def call(args, **kwargs):
    return subprocess.check_output(args, cwd=ROOT, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--platform", choices=("linux/arm64", "linux/amd64"), required=True)
    parser.add_argument("--mode", choices=("candidate", "final"), required=True)
    parser.add_argument("--builder")
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    commit = call(["git", "rev-parse", "HEAD"], text=True).strip()
    dirty = call(["git", "status", "--porcelain", "--untracked-files=no"], text=True)
    untracked = call(["git", "ls-files", "--others", "--exclude-standard"], text=True).splitlines()
    code_untracked = [p for p in untracked if not p.startswith("evidence/")]
    if args.mode == "final" and (dirty or code_untracked):
        raise RuntimeError("Final build requires committed code and no untracked source files")
    source = output / "source"
    source.mkdir()
    archive = call(["git", "archive", "--format=tar", commit])
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(source, filter="data")
    if args.mode == "candidate":
        # Only source directories; never copy local state, credentials or historical evidence.
        for component in ("vote", "result", "worker"):
            shutil.rmtree(source / component)
            shutil.copytree(ROOT / component, source / component,
                            ignore=shutil.ignore_patterns("node_modules", "__pycache__", "bin", "obj", ".local"))
        (output / "candidate.patch").write_text(call(["git", "diff", "HEAD"], text=True))
    hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
              for component in ("vote", "result", "worker") for p in (source / component).rglob("*") if p.is_file()}
    source_hash = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
    report = {"mode": args.mode, "source_commit": commit, "source_tree": call(["git", "rev-parse", "HEAD^{tree}"], text=True).strip(),
              "application_files_sha256": hashes, "application_snapshot_sha256": source_hash,
              "platform": args.platform, "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "images": {}}
    tag = commit + ("-candidate-" + source_hash[:8] if args.mode == "candidate" else "") + "-" + args.platform.split("/")[1]
    for component in ("vote", "result", "worker"):
        reference = f"voting-test-{component}:{tag}"
        metadata = output / (component + "-buildx.json")
        command = ["docker", "buildx", "build", "--platform", args.platform, "--load", "--provenance=false",
                   "--label", "org.opencontainers.image.revision=" + commit,
                   "--label", "thesis.build.mode=" + args.mode, "--metadata-file", str(metadata),
                   "-t", reference, str(source / component)]
        if args.builder:
            command.extend(["--builder", args.builder])
        started = time.monotonic()
        with (output / (component + "-build.log")).open("w") as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        meta = json.loads(metadata.read_text())
        inspected = json.loads(call(["docker", "image", "inspect", reference], text=True))[0]
        digests = {inspected["Id"]}
        digests.update(r.split("@")[-1] for r in inspected.get("RepoDigests", []))
        digests.update(meta[k] for k in ("containerimage.digest", "containerimage.config.digest") if k in meta)
        report["images"][component] = {
            "reference": reference, "runtime_digests": sorted(digests),
            "architecture": inspected["Architecture"], "os": inspected["Os"],
            "revision_label": inspected["Config"]["Labels"]["org.opencontainers.image.revision"],
            "build_seconds": round(time.monotonic() - started, 3), "command": command}
        (output / "build-record.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f"Built {component} {args.platform} ({report['images'][component]['build_seconds']}s)", flush=True)
    report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    (output / "build-record.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
