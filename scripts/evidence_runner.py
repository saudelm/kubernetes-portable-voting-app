#!/usr/bin/env python3
"""Destructive experiments only in explicitly marked, isolated test namespaces."""
import argparse
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
MARKER = "testing.portable-voting/isolated"
RELEASE = "testing.portable-voting/release"
STATES = ("PASS", "FAIL", "ERROR", "NOT_RUN")


class TestFailure(Exception):
    pass


class ToolError(Exception):
    pass


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def validate_target(context, namespace, release, metadata):
    if context in {"k3d-portable-voting", ""}:
        raise ToolError("Demo context is prohibited")
    if not re.fullmatch(r"voting-test-[a-z0-9-]+", namespace):
        raise ToolError("Namespace must be a separate voting-test-* namespace")
    if metadata.get("labels", {}).get(MARKER) != "true":
        raise ToolError("Namespace is not marked as isolated")
    if metadata.get("annotations", {}).get(RELEASE) != release:
        raise ToolError("Namespace is not assigned to this test release")


def classify_probe(result):
    if not isinstance(result, dict):
        raise ToolError("Probe did not return structured data")
    state = result.get("state")
    if state not in {"CONNECTED", "TIMEOUT", "REFUSED"}:
        raise ToolError("DNS, execution or socket error: " + str(result))
    return state


def same_rows(actual, expected):
    return actual == sorted([{"id": key, "vote": value} for key, value in expected.items()],
                            key=lambda row: row["id"])


def database_dns_target(service, pod, slices):
    addresses = {address for item in slices for endpoint in item.get("endpoints", [])
                 if endpoint.get("conditions", {}).get("ready") is True
                 and endpoint.get("targetRef", {}).get("uid") == pod["metadata"]["uid"]
                 for address in endpoint.get("addresses", [])}
    if pod["status"]["podIP"] not in addresses:
        raise ToolError("PostgreSQL is not a ready endpoint of the selected Service")
    cluster_ip = service["spec"]["clusterIP"]
    return pod["status"]["podIP"] if cluster_ip == "None" else cluster_ip


class Runner:
    def __init__(self, args):
        self.a = args
        self.output = Path(args.output).resolve()
        self.output.mkdir(parents=True, exist_ok=False)
        self.events = self.output / "commands.jsonl"
        self.tests = []
        self.expected = {}
        self.base = args.release + "-voting-app"
        self.pg = self.base + "-postgres-0"
        self.sequence = 0
        self.report = {"started_utc": utc(), "context": args.context, "namespace": args.namespace,
                       "release": args.release, "mode": args.mode, "source_commit": args.source_commit,
                       "tests": self.tests, "status": "NOT_RUN",
                       "scope": "Deployment portability; same-volume retention, no data migration"}

    def write(self, name, value):
        (self.output / name).write_text(json.dumps(value, indent=2) + "\n")

    def command(self, args, input_text=None, timeout=60):
        started = time.monotonic()
        stamp = utc()
        try:
            p = subprocess.run(args, input=input_text, capture_output=True, text=True, timeout=timeout)
        except (OSError, subprocess.TimeoutExpired) as exc:
            self.sequence += 1
            with self.events.open("a") as stream:
                stream.write(json.dumps({"step": self.sequence, "started_utc": stamp, "command": args,
                                         "duration_seconds": round(time.monotonic() - started, 3),
                                         "status": "ERROR", "error": type(exc).__name__}) + "\n")
            raise ToolError(str(exc)) from exc
        self.sequence += 1
        with self.events.open("a") as stream:
            stream.write(json.dumps({"step": self.sequence, "started_utc": stamp, "command": args,
                                     "duration_seconds": round(time.monotonic() - started, 3),
                                     "exit_code": p.returncode, "stdout": p.stdout, "stderr": p.stderr}) + "\n")
        if p.returncode:
            raise ToolError(f"Command failed ({p.returncode}): {args[0]}: {p.stderr[-1000:]}")
        return p.stdout

    def kubectl(self, *args, input_text=None, timeout=60):
        return self.command(["kubectl", "--context", self.a.context, "--namespace", self.a.namespace,
                             "--request-timeout=30s", *args], input_text, timeout)

    def get(self, *args):
        return json.loads(self.kubectl("get", *args, "-o", "json"))

    def pods(self, component=None):
        selector = "app.kubernetes.io/instance=" + self.a.release
        if component:
            selector += ",app.kubernetes.io/component=" + component
        return self.get("pods", "-l", selector)["items"]

    def snapshot(self):
        return [{"name": p["metadata"]["name"], "uid": p["metadata"]["uid"],
                 "component": p["metadata"]["labels"].get("app.kubernetes.io/component"),
                 "node": p["spec"].get("nodeName"),
                 "containers": [{"name": c["name"], "image": c["image"], "imageID": c.get("imageID"),
                                 "containerID": c.get("containerID"), "restarts": c.get("restartCount"),
                                 "ready": c.get("ready")} for c in p["status"].get("containerStatuses", [])]}
                for p in self.pods()]

    def sql(self, sql):
        return self.kubectl("exec", self.pg, "--", "psql", "-U", "postgres", "-d", "postgres",
                            "-v", "ON_ERROR_STOP=1", "-Atc", sql).strip()

    def rows(self):
        return json.loads(self.sql("SELECT coalesce(json_agg(t ORDER BY id), '[]'::json) FROM (SELECT id,vote FROM votes) t"))

    def eventually(self, predicate, timeout=90):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(1)
        raise TestFailure(f"Condition not satisfied within {timeout} seconds")

    def ready_component(self, component, count):
        def ready():
            pods = [p for p in self.pods(component) if not p["metadata"].get("deletionTimestamp")]
            return len(pods) == count and all(
                any(c["type"] == "Ready" and c["status"] == "True" for c in p["status"].get("conditions", []))
                for p in pods)
        self.eventually(ready, 300)

    def http(self, url, data=None, headers=None):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers or {}), timeout=15) as r:
                return r.read().decode()
        except (urllib.error.URLError, TimeoutError) as exc:
            raise ToolError("HTTP request failed: " + str(exc)) from exc

    def cast(self, key, choice):
        self.http(self.a.vote_url.rstrip("/") + "/", urllib.parse.urlencode({"vote": choice}).encode(),
                  {"Cookie": "voter_id=" + key, "Content-Type": "application/x-www-form-urlencoded"})
        self.expected[key] = choice

    def verify_function(self, name):
        self.eventually(lambda: same_rows(self.rows(), self.expected))
        counts = {v: list(self.expected.values()).count(v) for v in ("a", "b")}
        self.command([self.a.node, str(ROOT / "scripts/check-result.cjs"), self.a.result_url,
                      json.dumps(counts), str(self.output / (name + "-result.png"))], timeout=90)
        self.write(name + "-data.json", {"expected_rows": self.expected, "actual_rows": self.rows(), "scores": counts})

    def preflight(self):
        if self.a.mode == "final":
            commit = self.command(["git", "-C", str(ROOT), "rev-parse", "HEAD"]).strip()
            dirty = self.command(["git", "-C", str(ROOT), "status", "--porcelain", "--untracked-files=no"])
            untracked = self.command(["git", "-C", str(ROOT), "ls-files", "--others", "--exclude-standard"]).splitlines()
            if commit != self.a.source_commit or dirty or any(not p.startswith("evidence/") for p in untracked):
                raise ToolError("Final evaluation requires the matching clean committed runner and source tree")
        validate_target(self.a.context, self.a.namespace, self.a.release, self.get("namespace", self.a.namespace)["metadata"])
        if self.a.context.startswith("gke_"):
            if not self.a.gke_approval:
                raise ToolError("A separate GKE approval record is required")
            approval = json.loads(Path(self.a.gke_approval).read_text())
            required = {"context": self.a.context, "namespace": self.a.namespace, "approved": True,
                        "trial_active": True, "capacity_checked": True, "upgrade_allowed": False}
            if any(approval.get(k) != v for k, v in required.items()) or not approval.get("remaining_credit"):
                raise ToolError("GKE approval, trial, credit or capacity check incomplete")
            checked = dt.datetime.fromisoformat(approval["checked_at_utc"])
            age = (dt.datetime.now(dt.timezone.utc) - checked).total_seconds()
            if not 0 <= age <= 3600:
                raise ToolError("GKE approval check must be less than one hour old")
            self.write("gke-approval.json", approval)
        elif not self.a.context.startswith("k3d-voting-test-"):
            raise ToolError("Local execution requires a separate k3d-voting-test-* cluster")
        all_pods = self.get("pods")["items"]
        if not all_pods or any(p["metadata"].get("labels", {}).get("app.kubernetes.io/instance") != self.a.release for p in all_pods):
            raise ToolError("Namespace contains workloads outside the test release")
        for component, count in (("vote", 2), ("result", 2), ("worker", 1), ("postgres", 1), ("redis", 1)):
            self.ready_component(component, count)
        ingresses = self.get("ingress")["items"]
        hosts = {rule["host"] for item in ingresses for rule in item["spec"]["rules"]
                 if item["metadata"].get("labels", {}).get("app.kubernetes.io/instance") == self.a.release}
        for url in (self.a.vote_url, self.a.result_url):
            parsed = urllib.parse.urlparse(url)
            if parsed.scheme not in ("http", "https") or parsed.hostname not in hosts:
                raise ToolError("URL does not belong to the isolated release ingress")
        page = self.http(self.a.vote_url.rstrip("/") + "/")
        if not any(p["metadata"]["name"] in page for p in self.pods("vote")):
            raise ToolError("Vote URL does not serve a pod from this test installation")
        if self.rows():
            raise ToolError("Test installation must start with an empty votes table; never erase existing data")
        pvc = self.get("pvc")["items"]
        if len(pvc) != 1 or pvc[0]["metadata"].get("labels", {}).get("app.kubernetes.io/instance") != self.a.release:
            raise ToolError("Expected exactly one release-owned test PVC")
        pv = self.get("pv", pvc[0]["spec"]["volumeName"])
        if pv["spec"]["claimRef"].get("uid") != pvc[0]["metadata"]["uid"]:
            raise ToolError("PVC/PV ownership mismatch")
        ns_created = self.get("namespace", self.a.namespace)["metadata"]["creationTimestamp"]
        if pv["metadata"]["creationTimestamp"] < ns_created:
            raise ToolError("Test PV predates the isolated test namespace")
        self.write("storage-initial.json", {"pvc": pvc[0], "pv": pv})
        build = json.loads(Path(self.a.build_record).read_text())
        if build.get("source_commit") != self.a.source_commit or build.get("mode") != self.a.mode:
            raise ToolError("Build record does not match source/mode")
        initial = self.snapshot()
        nodes = self.get("nodes")
        architectures = {n["metadata"]["name"]: n["status"]["nodeInfo"]["architecture"] for n in nodes["items"]}
        for pod in initial:
            if pod["component"] in ("vote", "result", "worker"):
                image = build["images"][pod["component"]]
                if architectures.get(pod["node"]) != image.get("architecture"):
                    raise ToolError("Build architecture differs from the actual node architecture")
                for container in pod["containers"]:
                    if container["image"] != image["reference"] or not container["imageID"]:
                        raise ToolError("Runtime image reference missing or differs from build")
                    digest = container["imageID"].split("@")[-1].split("://")[-1]
                    if digest not in image.get("runtime_digests", []):
                        raise ToolError("Executed image digest does not match the build record")
        self.write("build-record.json", build)
        self.write("runtime-before.json", initial)
        self.write("nodes.json", nodes)
        self.write("policies-before.json", self.get("networkpolicy"))

    def t1(self, run):
        prefix = "test-" + uuid.uuid4().hex[:12]
        for i, choice in enumerate(("a", "b", "a")):
            self.cast(f"{prefix}-{i}", choice)
            self.eventually(lambda: same_rows(self.rows(), self.expected))
        counts = {v: list(self.expected.values()).count(v) for v in ("a", "b")}
        after = dict(counts, a=counts["a"] - 1, b=counts["b"] + 1)
        self.command([self.a.node, str(ROOT / "scripts/check-result.cjs"), self.a.result_url,
                      json.dumps(counts), str(self.output / f"r{run}-t1-live.png"),
                      json.dumps({"vote_url": self.a.vote_url, "key": prefix + "-0",
                                  "choice": "b", "after": after})], timeout=120)
        self.expected[prefix + "-0"] = "b"
        self.verify_function(f"r{run}-t1")

    def storage_identity(self):
        pvc = self.get("pvc")["items"][0]
        return {k: v for k, v in {"pvc_uid": pvc["metadata"]["uid"], "name": pvc["metadata"]["name"],
                                  "volume": pvc["spec"]["volumeName"]}.items()}

    def t2(self, run):
        before = {"rows": self.rows(), "storage": self.storage_identity(),
                  "uid": self.get("pod", self.pg)["metadata"]["uid"],
                  "applications": [p for p in self.snapshot() if p["component"] in ("result", "worker")]}
        outage = self.database_outage(run)
        self.ready_component("postgres", 1)
        self.eventually(lambda: same_rows(self.rows(), self.expected))
        for component, count in (("result", 2), ("worker", 1)):
            self.ready_component(component, count)
        after = {"rows": self.rows(), "storage": self.storage_identity(),
                 "uid": self.get("pod", self.pg)["metadata"]["uid"],
                 "applications": [p for p in self.snapshot() if p["component"] in ("result", "worker")]}
        for component in ("result", "worker"):
            for pod in self.pods(component):
                self.kubectl("logs", pod["metadata"]["name"], "--since=10m", "--timestamps")
        self.write(f"r{run}-t2.json", {"before": before, "after": after, "outage": outage})
        if before["storage"] != after["storage"] or before["uid"] == after["uid"]:
            raise TestFailure("Storage changed or PostgreSQL pod was not replaced")
        after_rows = {r["id"]: r["vote"] for r in after["rows"]}
        if any(after_rows.get(r["id"]) != r["vote"] for r in before["rows"]):
            raise TestFailure("Existing complete test rows changed")
        def processes(items):
            return sorted((p["uid"], c["containerID"], c["restarts"]) for p in items for c in p["containers"])
        if processes(before["applications"]) != processes(after["applications"]):
            raise TestFailure("Result/Worker process restarted during PostgreSQL replacement")
        if any(self.result_readiness(p["metadata"]["name"]) != 200 for p in self.pods("result")):
            raise TestFailure("Result did not recover readiness after database restoration")
        self.verify_function(f"r{run}-t2")

    def result_readiness(self, pod):
        # Direct loopback probe still works while an unready pod is removed from its Service.
        script = ("require('http').get('http://127.0.0.1:4000/readyz',r=>{"
                  "console.log(r.statusCode);r.resume()}).on('error',e=>{"
                  "console.error(e.message);process.exitCode=1})")
        status = int(self.kubectl("exec", pod, "--", "node", "-e", script).strip())
        if status not in (200, 503):
            raise ToolError("Unexpected Result readiness status: " + str(status))
        return status

    def database_outage(self, run):
        statefulset = self.base + "-postgres"
        spec = self.get("statefulset", statefulset)["spec"]
        if spec["replicas"] != 1:
            raise ToolError("Controlled outage requires exactly one PostgreSQL replica")
        if spec.get("persistentVolumeClaimRetentionPolicy", {}).get("whenScaled", "Retain") != "Retain":
            raise ToolError("Outage refuses a StatefulSet that deletes PVCs when scaled")
        observations = {"started_utc": utc(), "method": "scale 1 -> 0 -> 1; same PVC", "samples": []}
        try:
            self.kubectl("scale", "statefulset", statefulset, "--replicas=0")
            self.eventually(lambda: not self.pods("postgres"), 90)
            observations["no_postgres_pods_utc"] = utc()
            self.cast("test-outage-" + uuid.uuid4().hex[:12], "a")
            def exposed():
                results = self.pods("result")
                workers = self.pods("worker")
                if len(results) != 2 or len(workers) != 1:
                    raise ToolError("Unexpected application replica count during outage")
                statuses = {p["metadata"]["name"]: self.result_readiness(p["metadata"]["name"])
                            for p in results}
                logs = {p["metadata"]["name"]: self.kubectl("logs", p["metadata"]["name"],
                        "--since-time=" + observations["started_utc"], "--timestamps")
                        for p in results + workers}
                sample = {"at": utc(), "readiness": statuses, "logs": logs}
                observations["samples"].append(sample)
                return (all(code == 503 for code in statuses.values())
                        and all("Database unavailable:" in logs[p["metadata"]["name"]] for p in results)
                        and any(marker in logs[workers[0]["metadata"]["name"]] for marker in
                                ("Database interrupted; reconnecting:", "Database timeout; reconnecting")))
            self.eventually(exposed, 60)
            observations["exposure_confirmed_utc"] = utc()
        finally:
            # Restore the test workload even when observation or kubectl fails.
            try:
                self.kubectl("scale", "statefulset", statefulset, "--replicas=1")
                observations["restore_requested_utc"] = utc()
            finally:
                self.write(f"r{run}-t2-outage.json", observations)
        return observations

    def t3(self, run):
        before = {p["metadata"]["uid"] for p in self.pods("vote")}
        self.kubectl("delete", "pod", "-l",
                     f"app.kubernetes.io/instance={self.a.release},app.kubernetes.io/component=vote", timeout=90)
        self.ready_component("vote", 2)
        after = {p["metadata"]["uid"] for p in self.pods("vote")}
        self.write(f"r{run}-t3.json", {"before_uids": sorted(before), "after_uids": sorted(after)})
        if len(after) != 2 or before & after:
            raise TestFailure("Expected two replacement Vote pods")
        self.cast("test-heal-" + uuid.uuid4().hex[:12], "b")
        self.verify_function(f"r{run}-t3")

    def probe(self, pod, ip):
        script = """import socket,json,sys
try:
 s=socket.create_connection((sys.argv[1],5432),3); s.close(); state='CONNECTED'
except TimeoutError: state='TIMEOUT'
except ConnectionRefusedError: state='REFUSED'
except Exception as exc:
 print(json.dumps({'state':'ERROR','error':type(exc).__name__})); sys.exit(0)
print(json.dumps({'state':state}))
"""
        return classify_probe(json.loads(self.kubectl("exec", pod, "--", "python", "-c", script, ip)))

    def control_policies(self):
        labels = {"app.kubernetes.io/instance": self.a.release}
        def selector(component):
            return {"matchLabels": dict(labels, **{"app.kubernetes.io/component": component})}
        items = []
        for component, direction, peer in (("vote", "Egress", "postgres"), ("postgres", "Ingress", "vote")):
            ingress = direction == "Ingress"
            items.append({"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
                          "metadata": {"name": self.a.release + "-test-control-" + component,
                                       "namespace": self.a.namespace, "labels": {MARKER: "true"}},
                          "spec": {"podSelector": selector(component), "policyTypes": [direction],
                                   direction.lower(): [{("from" if ingress else "to"): [{"podSelector": selector(peer)}],
                                                        "ports": [{"port": 5432, "protocol": "TCP"}]}]}})
        return {"apiVersion": "v1", "kind": "List", "items": items}

    def t4(self, run):
        self.ready_component("postgres", 1)
        pg = self.get("pod", self.pg)
        ip = pg["status"]["podIP"]
        uid = pg["metadata"]["uid"]
        vote = self.pods("vote")[0]["metadata"]["name"]
        dns = self.kubectl("exec", vote, "--", "python", "-c",
                           "import socket,sys; print(socket.gethostbyname(sys.argv[1]))", self.base + "-postgres").strip()
        service = self.get("service", self.base + "-postgres")
        slices = self.get("endpointslices", "-l", "kubernetes.io/service-name=" + self.base + "-postgres")["items"]
        if dns != database_dns_target(service, pg, slices):
            raise ToolError("DNS did not resolve the expected PostgreSQL Service")
        policies = self.control_policies()
        for item in policies["items"]:
            existing = self.kubectl("get", "networkpolicy", item["metadata"]["name"], "--ignore-not-found", "-o", "name")
            if existing.strip():
                raise ToolError("A test control policy already exists; inspect before retrying")
        observations = []
        original = {p["metadata"]["name"]: p["spec"] for p in self.get("networkpolicy")["items"]}
        def observe(expected):
            self.ready_component("postgres", 1)
            current = self.get("pod", self.pg)
            if current["metadata"]["uid"] != uid or current["status"]["podIP"] != ip:
                raise ToolError("PostgreSQL endpoint changed during network experiment")
            self.sql("SELECT 1")
            state = self.probe(vote, ip)
            observations.append({"at": utc(), "expected": expected, "actual": state, "target_ip": ip})
            return state == "CONNECTED" if expected == "CONNECTED" else state in {"TIMEOUT", "REFUSED"}
        try:
            for state in ("CONNECTED", "BLOCKED", "CONNECTED", "BLOCKED"):
                if state == "CONNECTED":
                    self.kubectl("apply", "-f", "-", input_text=json.dumps(policies))
                else:
                    self.kubectl("delete", "-f", "-", "--ignore-not-found", input_text=json.dumps(policies))
                self.eventually(lambda: observe(state), 60)
        finally:
            self.kubectl("delete", "-f", "-", "--ignore-not-found", input_text=json.dumps(policies))
            self.write(f"r{run}-t4.json", {"service_dns": dns, "endpoint_uid": uid,
                                          "endpoint_slices": slices, "service": service,
                                          "observations": observations, "control_policies": policies})
        restored = {p["metadata"]["name"]: p["spec"] for p in self.get("networkpolicy")["items"]}
        if original != restored:
            raise TestFailure("Original network policies were not restored")

    def monitoring(self):
        if not self.a.prometheus_url or not self.a.grafana_url:
            return "NOT_RUN", "Prometheus/Grafana endpoints not supplied"
        query = f'sum(kube_pod_status_phase{{namespace="{self.a.namespace}",phase="Running"}})'
        observations = {}
        def query_matches(url, key, headers=None):
            data = json.loads(self.http(url + urllib.parse.urlencode({"query": query}), headers=headers))
            observations[key] = data
            values = data.get("data", {}).get("result", [])
            return data.get("status") == "success" and len(values) == 1 and float(values[0]["value"][1]) == 7
        self.eventually(lambda: query_matches(self.a.prometheus_url.rstrip("/") + "/api/v1/query?", "prometheus"), 90)
        user = os.environ.get("GRAFANA_USER", "admin")
        password = os.environ.get("GRAFANA_PASSWORD")
        if not password:
            return "NOT_RUN", "GRAFANA_PASSWORD not supplied externally"
        auth = base64.b64encode((user + ":" + password).encode()).decode()
        self.eventually(lambda: query_matches(self.a.grafana_url.rstrip("/") +
                        "/api/datasources/proxy/uid/Prometheus/api/v1/query?", "grafana_proxy",
                        {"Authorization": "Basic " + auth}), 90)
        self.write("monitoring.json", {"query": query, **observations})
        return "PASS", "Actual test-namespace metrics through both Prometheus and Grafana datasource"

    def execute(self):
        try:
            self.preflight()
            for run in range(1, 4):
                for name, test in (("T1", self.t1), ("T2", self.t2), ("T3", self.t3), ("T4", self.t4)):
                    started = time.monotonic()
                    record = {"repetition": run, "test": name, "started_utc": utc()}
                    try:
                        test(run)
                        record.update(status="PASS")
                    except TestFailure as exc:
                        record.update(status="FAIL", detail=str(exc))
                    except Exception as exc:
                        record.update(status="ERROR", detail=str(exc))
                    record["duration_seconds"] = round(time.monotonic() - started, 3)
                    self.tests.append(record)
                    self.write("summary.json", self.report)
                    print(json.dumps(record), flush=True)
                    if record["status"] != "PASS":
                        raise ToolError("Stopped after unsuccessful experiment; no success inferred")
            started = time.monotonic()
            try:
                status, detail = self.monitoring()
            except TestFailure as exc:
                status, detail = "FAIL", str(exc)
            except Exception as exc:
                status, detail = "ERROR", str(exc)
            self.tests.append({"test": "Monitoring", "status": status, "detail": detail,
                               "duration_seconds": round(time.monotonic() - started, 3)})
            self.write("runtime-after.json", self.snapshot())
            self.write("policies-after.json", self.get("networkpolicy"))
            self.report["status"] = status
        except Exception as exc:
            self.report.update(status="FAIL" if any(t["status"] == "FAIL" for t in self.tests) else "ERROR",
                               error=str(exc))
            print("ERROR: " + str(exc), file=sys.stderr)
        finally:
            performed = {(t.get("repetition"), t["test"]) for t in self.tests}
            for run in range(1, 4):
                for name in ("T1", "T2", "T3", "T4"):
                    if (run, name) not in performed:
                        self.tests.append({"repetition": run, "test": name, "status": "NOT_RUN"})
            if not any(t["test"] == "Monitoring" for t in self.tests):
                self.tests.append({"test": "Monitoring", "status": "NOT_RUN"})
            self.report["finished_utc"] = utc()
            self.write("summary.json", self.report)
            files = {str(p.relative_to(self.output)): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in self.output.rglob("*") if p.is_file() and p.name != "checksums.json"}
            self.write("checksums.json", files)
        return 0 if self.report["status"] == "PASS" else 1


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for field in ("context", "namespace", "release", "output", "source-commit", "build-record", "vote-url", "result-url"):
        p.add_argument("--" + field, required=True)
    p.add_argument("--mode", choices=("candidate", "final"), required=True)
    p.add_argument("--node", default="node")
    p.add_argument("--gke-approval")
    p.add_argument("--prometheus-url")
    p.add_argument("--grafana-url")
    args = p.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_commit):
        p.error("--source-commit requires the full 40-character commit")
    return Runner(args).execute()


if __name__ == "__main__":
    sys.exit(main())
