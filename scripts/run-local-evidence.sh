#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# No implicit context, namespace, or demo mutation. The common runner validates all targets.
exec "${PYTHON_BIN:-python3}" "$root/scripts/evidence_runner.py" "$@"
