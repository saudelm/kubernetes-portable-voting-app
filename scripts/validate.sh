#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ruby_bin="${RUBY_BIN:-ruby}"

helm lint "$root/charts/voting-app"
helm template voting "$root/charts/voting-app" \
  --namespace voting \
  --values "$root/charts/voting-app/values.yaml" >/dev/null
helm template voting "$root/charts/voting-app" \
  --namespace voting \
  --values "$root/charts/voting-app/values-gke.yaml" \
  --set-string vote.image.tag=abcdef1 \
  --set-string result.image.tag=abcdef1 \
  --set-string worker.image.tag=abcdef1 \
  --set-string vote.ingress.host=vote.192.0.2.1.nip.io \
  --set-string result.ingress.host=result.192.0.2.1.nip.io >/dev/null

terraform -chdir="$root/infra" fmt -check -recursive
for target in onprem-k3d gke; do
  terraform -chdir="$root/infra/$target" init -backend=false
  terraform -chdir="$root/infra/$target" validate
done

python_venv="$root/.local/python-venv"
python3 -m venv "$python_venv"
"$python_venv/bin/python" -m pip install -r "$root/vote/requirements.txt"
"$python_venv/bin/python" -m py_compile "$root/vote/app.py"
PYTHONPATH="$root/vote" "$python_venv/bin/python" -m unittest discover \
  -s "$root/vote/tests" -p 'test_*.py'
"$ruby_bin" -c "$root/scripts/compare-portability.rb"
"$ruby_bin" "$root/scripts/compare-portability.rb"

(
  cd "$root/result"
  npm ci --ignore-scripts
  npm test
  npm audit --omit=dev
)

printf 'Static validation completed successfully.\n'
