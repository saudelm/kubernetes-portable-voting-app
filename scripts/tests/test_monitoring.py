"""Offline regression checks for the two Terraform monitoring definitions."""
from pathlib import Path
import re
import json
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MonitoringTests(unittest.TestCase):
    def test_terraform_evaluates_custom_namespaces_for_both_targets(self):
        for target in ("onprem-k3d", "gke"):
            text = (ROOT / "infra" / target / "main.tf").read_text()
            dashboard = text.split('grafana_portable_dashboard = ', 1)[1].split('\n}\n', 1)[0]
            address = re.findall(r'url\s*= ("http://prometheus-server[^\n]+)', text)
            self.assertEqual(len(address), 1)
            # Evaluate the original expressions with Terraform in a provider-free temporary directory.
            config = ('variable "app_namespace" {}\nvariable "monitoring_namespace" {}\nlocals {\n'
                      + 'dashboard = ' + dashboard + '\naddress = ' + address[0] + '\n}\n')
            with tempfile.TemporaryDirectory() as directory:
                (Path(directory) / 'main.tf').write_text(config)
                output = subprocess.check_output(['terraform', '-chdir=' + directory, 'console',
                    '-var=app_namespace=voting-test-review', '-var=monitoring_namespace=metrics-test-review'],
                    input='jsonencode({dashboard=local.dashboard,address=local.address})\n', text=True, timeout=30)
            data = json.loads(json.loads(output))
            queries = [q['expr'] for p in data['dashboard']['panels'] for q in p.get('targets', [])
                       if 'namespace=' in q['expr']]
            self.assertEqual(len(queries), 5)
            self.assertTrue(all('namespace="voting-test-review"' in q for q in queries))
            self.assertEqual(data['address'], 'http://prometheus-server.metrics-test-review.svc.cluster.local')

    def test_all_application_queries_use_namespace_parameter(self):
        for target in ("onprem-k3d", "gke"):
            text = (ROOT / "infra" / target / "main.tf").read_text()
            queries = re.findall(r'^\s*expr\s*= (.+)$', text, re.M)
            application = [q for q in queries if "namespace=" in q]
            self.assertEqual(len(application), 5, target)
            self.assertTrue(all('${var.app_namespace}' in q for q in application), target)
            self.assertIn('http://prometheus-server.${var.monitoring_namespace}.svc.cluster.local', text)

    def test_dashboard_definitions_do_not_drift(self):
        dashboards = []
        for target in ("onprem-k3d", "gke"):
            text = (ROOT / "infra" / target / "main.tf").read_text()
            # Both existing locals finish with the dashboard object; retain all its settings.
            dashboards.append(text.split('grafana_portable_dashboard = ', 1)[1].split('\n}\n', 1)[0])
        self.assertEqual(*dashboards)


if __name__ == '__main__':
    unittest.main()
