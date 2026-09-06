import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock
import tempfile
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location("runner", Path(__file__).parents[1] / "evidence_runner.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class EvidenceRunnerTests(unittest.TestCase):
    def outage_runner(self, directory):
        args = SimpleNamespace(output=str(Path(directory) / "run"), release="test",
                               context="k3d-voting-test-new", namespace="voting-test-new",
                               mode="candidate", source_commit="a" * 40)
        r = m.Runner(args)
        r.get = Mock(return_value={"spec": {"replicas": 1}})
        r.pods = Mock(side_effect=lambda c: [] if c == "postgres" else
                      [{"metadata": {"name": n}} for n in
                       (["result-1", "result-2"] if c == "result" else ["worker-1"])])
        r.cast = Mock()
        r.result_readiness = Mock(return_value=503)
        r.kubectl = Mock(return_value="Database unavailable: ECONNREFUSED\nDatabase interrupted; reconnecting:")
        def once(predicate, timeout):
            if not predicate():
                raise m.TestFailure("No observed database exposure")
        r.eventually = once
        return r

    def test_outage_requires_observed_errors_and_restores_replica(self):
        with tempfile.TemporaryDirectory() as directory:
            r = self.outage_runner(directory)
            data = r.database_outage(1)
            self.assertIn("exposure_confirmed_utc", data)
            self.assertEqual(r.cast.call_count, 1)
            self.assertEqual(r.kubectl.call_args.args[-1], "--replicas=1")

    def test_missing_exposure_never_passes_and_still_restores(self):
        with tempfile.TemporaryDirectory() as directory:
            r = self.outage_runner(directory)
            r.result_readiness.return_value = 200
            with self.assertRaises(m.TestFailure):
                r.database_outage(1)
            self.assertEqual(r.kubectl.call_args.args[-1], "--replicas=1")
            self.assertTrue((r.output / "r1-t2-outage.json").exists())

    def test_outage_tool_error_still_restores(self):
        with tempfile.TemporaryDirectory() as directory:
            r = self.outage_runner(directory)
            r.result_readiness.side_effect = m.ToolError("exec failed")
            with self.assertRaises(m.ToolError):
                r.database_outage(1)
            self.assertEqual(r.kubectl.call_args.args[-1], "--replicas=1")

    def test_headless_postgres_dns_is_pod_ip_not_literal_none(self):
        pod = {"metadata": {"uid": "pg-uid"}, "status": {"podIP": "10.1.2.3"}}
        slices = [{"endpoints": [{"conditions": {"ready": True}, "targetRef": {"uid": "pg-uid"},
                                   "addresses": ["10.1.2.3"]}]}]
        self.assertEqual(m.database_dns_target({"spec": {"clusterIP": "None"}}, pod, slices), "10.1.2.3")
        self.assertEqual(m.database_dns_target({"spec": {"clusterIP": "10.4.5.6"}}, pod, slices), "10.4.5.6")

    def test_unready_or_wrong_database_endpoint_is_tool_error(self):
        pod = {"metadata": {"uid": "pg-uid"}, "status": {"podIP": "10.1.2.3"}}
        for slices in ([], [{"endpoints": [{"conditions": {"ready": False}, "targetRef": {"uid": "pg-uid"},
                                             "addresses": ["10.1.2.3"]}]}]):
            with self.assertRaises(m.ToolError):
                m.database_dns_target({"spec": {"clusterIP": "None"}}, pod, slices)

    def run_mocked(self, fault=None, monitoring=None):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(output=str(Path(directory) / "run"), release="test", context="k3d-voting-test-new",
                                   namespace="voting-test-new", mode="candidate", source_commit="a" * 40)
            runner = m.Runner(args)
            runner.preflight = Mock()
            for name in ("t1", "t2", "t3", "t4"):
                setattr(runner, name, Mock())
            if fault:
                runner.t4.side_effect = fault
            runner.monitoring = Mock(return_value=("PASS", "metrics"), side_effect=monitoring)
            runner.snapshot = Mock(return_value=[])
            runner.get = Mock(return_value={})
            code = runner.execute()
            return code, runner.report

    def test_tool_failure_stops_run_and_never_counts_as_security_pass(self):
        code, report = self.run_mocked(fault=m.ToolError("kubectl exec failed"))
        self.assertEqual(code, 1)
        self.assertEqual(report["status"], "ERROR")
        t4 = [t for t in report["tests"] if t["test"] == "T4"]
        self.assertEqual([t["status"] for t in t4], ["ERROR", "NOT_RUN", "NOT_RUN"])

    def test_assertion_failure_is_fail_not_error(self):
        _, report = self.run_mocked(fault=m.TestFailure("unexpected connection"))
        self.assertEqual(report["status"], "FAIL")

    def test_monitoring_failure_is_recorded_as_performed_fail(self):
        _, report = self.run_mocked(monitoring=m.TestFailure("wrong metric"))
        self.assertEqual(report["status"], "FAIL")
        self.assertEqual(report["tests"][-1]["status"], "FAIL")

    def test_complete_mock_run_has_three_repetitions_and_monitoring(self):
        code, report = self.run_mocked()
        self.assertEqual(code, 0)
        self.assertEqual(len(report["tests"]), 13)
        self.assertTrue(all(t["status"] == "PASS" for t in report["tests"]))

    def test_demo_context_rejected_even_if_marked(self):
        with self.assertRaises(m.ToolError):
            m.validate_target("k3d-portable-voting", "voting-test-new", "test",
                              {"labels": {m.MARKER: "true"}, "annotations": {m.RELEASE: "test"}})

    def test_demo_namespace_rejected(self):
        with self.assertRaises(m.ToolError):
            m.validate_target("k3d-voting-test-new", "voting", "voting", {})

    def test_unmarked_namespace_rejected(self):
        with self.assertRaises(m.ToolError):
            m.validate_target("gke_example", "voting-test-new", "test", {})

    def test_other_release_rejected(self):
        with self.assertRaises(m.ToolError):
            m.validate_target("k3d-voting-test-new", "voting-test-new", "test",
                              {"labels": {m.MARKER: "true"}, "annotations": {m.RELEASE: "wrong"}})

    def test_marked_namespace_accepted(self):
        m.validate_target("k3d-voting-test-new", "voting-test-new", "test",
                          {"labels": {m.MARKER: "true"}, "annotations": {m.RELEASE: "test"}})

    def test_tool_and_dns_errors_never_pass_as_blocked(self):
        for result in ({"state": "ERROR"}, {"state": "DNS_ERROR"}, {}, None, {"state": "exec failed"}):
            with self.assertRaises(m.ToolError):
                m.classify_probe(result)

    def test_expected_socket_outcomes_are_distinct(self):
        for state in ("CONNECTED", "REFUSED", "TIMEOUT"):
            self.assertEqual(m.classify_probe({"state": state}), state)

    def test_equal_tally_does_not_mean_equal_rows(self):
        self.assertFalse(m.same_rows([{"id": "other", "vote": "a"}], {"voter": "a"}))
        self.assertFalse(m.same_rows([{"id": "voter", "vote": "b"}], {"voter": "a"}))
        self.assertTrue(m.same_rows([{"id": "voter", "vote": "a"}], {"voter": "a"}))


if __name__ == "__main__":
    unittest.main()
