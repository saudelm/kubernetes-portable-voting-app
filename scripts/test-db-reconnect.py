#!/usr/bin/env python3
"""Isolated Docker integration test, explicitly not a Kubernetes portability test."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import time
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-record", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    build = json.loads(Path(args.build_record).read_text())
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    prefix = "voting-reconnect-test-" + uuid.uuid4().hex[:10]
    label = "testing.portable-voting/isolated=true"
    containers = {}
    created_network = False
    created_volume = False
    report = {"scope": __doc__, "status": "NOT_RUN", "source_commit": build["source_commit"],
              "mode": build["mode"], "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "cycles": []}
    env = dict(os.environ, POSTGRES_PASSWORD=secrets.token_urlsafe(24))
    def command(command, timeout=120):
        start = time.monotonic()
        p = subprocess.run(["docker", *command], capture_output=True, text=True, timeout=timeout, env=env)
        with (output / "commands.jsonl").open("a") as log:
            log.write(json.dumps({"command": ["docker", *command], "seconds": round(time.monotonic()-start, 3),
                                  "exit_code": p.returncode, "stdout": p.stdout, "stderr": p.stderr}) + "\n")
        if p.returncode:
            raise RuntimeError(p.stderr)
        return p.stdout.strip()
    def wait(predicate, timeout=60):
        until = time.monotonic() + timeout
        while time.monotonic() < until:
            if predicate():
                return
            time.sleep(0.5)
        raise AssertionError("Condition timed out")
    def sql(query):
        return command(["exec", containers["postgres"], "psql", "-U", "postgres", "-Atc", query])
    def ready():
        script = "require('http').get('http://127.0.0.1:8080/readyz',r=>{console.log(r.statusCode);r.resume()}).on('error',()=>console.log(0))"
        return int(command(["exec", containers["result"], "node", "-e", script]))
    def process(name):
        value = command(["inspect", "--format",
                         "{{json .State}}", containers[name]])
        state = json.loads(value)
        if not state["Running"] or state.get("OOMKilled"):
            raise AssertionError("Application process ended")
        return {"id": containers[name], "started_at": state["StartedAt"],
                "restart_count": int(command(["inspect", "--format", "{{.RestartCount}}", containers[name]]))}
    expected = {}
    def enqueue(key, choice):
        command(["exec", containers["redis"], "redis-cli", "RPUSH", "votes",
                 json.dumps({"voter_id": key, "vote": choice})])
        expected[key] = choice
    def rows():
        return json.loads(sql("SELECT coalesce(json_agg(t ORDER BY id), '[]'::json) FROM (SELECT id,vote FROM votes) t"))
    def expected_rows():
        return [{"id": key, "vote": expected[key]} for key in sorted(expected)]
    try:
        for component in ("result", "worker"):
            image = build["images"][component]
            actual = command(["image", "inspect", "--format", "{{.Id}}", image["reference"]])
            if actual not in image["runtime_digests"]:
                raise AssertionError("Candidate image differs from its build record")
        command(["network", "create", "--internal", "--label", label, prefix])
        created_network = True
        command(["volume", "create", "--label", label, prefix])
        created_volume = True
        def launch(component, image, extra, tail=None):
            containers[component] = command(["run", "-d", "--name", prefix + "-" + component,
                                            "--label", label, "--network", prefix, *extra, image, *(tail or [])])
        launch("postgres", "postgres:16-alpine",
               ["--network-alias", "db", "--memory", "192m", "--cpus", "0.5",
                "--env", "POSTGRES_PASSWORD", "--mount", "type=volume,src=" + prefix + ",dst=/var/lib/postgresql/data"],
               ["postgres", "-c", "shared_buffers=16MB", "-c", "max_connections=20"])
        launch("redis", "redis:7.4.9-alpine",
               ["--network-alias", "redis", "--memory", "48m", "--cpus", "0.25"])
        wait(lambda: command(["exec", containers["postgres"], "sh", "-c", "pg_isready -U postgres >/dev/null; printf '%s' $?"]) == "0")
        launch("worker", build["images"]["worker"]["reference"],
               ["--memory", "160m", "--cpus", "0.5", "--env", "POSTGRES_PASSWORD"])
        wait(lambda: sql("SELECT count(*) FROM information_schema.tables WHERE table_name='votes'") == "1")
        launch("result", build["images"]["result"]["reference"],
               ["--memory", "128m", "--cpus", "0.5", "--env", "POSTGRES_PASSWORD"])
        wait(lambda: ready() == 200)
        initial = {c: process(c) for c in ("result", "worker")}
        enqueue("one", "a")
        enqueue("two", "b")
        wait(lambda: rows() == expected_rows())
        for cycle in range(1, 4):
            start = time.monotonic()
            command(["stop", "--time", "1", containers["postgres"]])
            enqueue("outage-" + str(cycle), "a" if cycle % 2 else "b")
            wait(lambda: ready() == 503)
            time.sleep(4)
            during = {c: process(c) for c in ("result", "worker")}
            if during != initial:
                raise AssertionError("Result or Worker restarted during outage")
            command(["start", containers["postgres"]])
            wait(lambda: command(["exec", containers["postgres"], "sh", "-c", "pg_isready -U postgres >/dev/null; printf '%s' $?"]) == "0")
            wait(lambda: rows() == expected_rows())
            wait(lambda: ready() == 200)
            after = {c: process(c) for c in ("result", "worker")}
            if after != initial:
                raise AssertionError("Application restarted on recovery")
            report["cycles"].append({"cycle": cycle, "status": "PASS", "seconds": round(time.monotonic()-start,3),
                                      "ready_during_outage": 503, "ready_after": 200,
                                      "rows": rows(), "processes": after})
        enqueue("one", "b")
        wait(lambda: rows() == expected_rows())
        report["final_rows"] = rows()
        report["status"] = "PASS"
    except Exception as exc:
        report.update(status="FAIL" if isinstance(exc, AssertionError) else "ERROR", error=str(exc))
    finally:
        for name, container in containers.items():
            try:
                command(["logs", "--timestamps", container])
            finally:
                command(["rm", "--force", container])
        if created_volume:
            command(["volume", "rm", prefix])
        if created_network:
            command(["network", "rm", prefix])
        report["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        (output / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
        (output / "build-record.json").write_text(json.dumps(build, indent=2) + "\n")
        hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir() if p.is_file()}
        (output / "checksums.json").write_text(json.dumps(hashes, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    raise SystemExit(0 if report["status"] == "PASS" else 1)


if __name__ == "__main__":
    main()
