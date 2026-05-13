#!/usr/bin/env bash
# Compatibility wrapper. New regression framework lives under regress/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec ./regress/bin/run_regress.py "$@"
