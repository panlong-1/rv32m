#!/usr/bin/env bash
# Verilator lint of the hardened block (DESIGN_NAME in librelane/config.yaml), same file
# list as LibreLane. Fails on any error, or if the warning count grows past MAX_WARNINGS
# (the known warnings at v0.8.0; lower it as they are fixed).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MAX_WARNINGS="${MAX_WARNINGS:-16}"
CONFIG=librelane/config.yaml
TOP="$(awk '/^DESIGN_NAME:/{print $2}' "$CONFIG")"
mapfile -t FILES < <(grep -oE 'rtl/[A-Za-z0-9_]+\.sv' "$CONFIG")

set +e
OUT="$(verilator --lint-only -Wall -Wno-fatal -Irtl --top-module "$TOP" "${FILES[@]}" 2>&1)"
RC=$?
set -e
printf '%s\n' "$OUT" | grep -E '^%(Warning|Error)' || true

ERRORS="$(printf '%s\n' "$OUT" | grep -cE '^%Error' || true)"
WARNINGS="$(printf '%s\n' "$OUT" | grep -cE '^%Warning-' || true)"
echo "lint $TOP: $ERRORS error(s), $WARNINGS warning(s) (max $MAX_WARNINGS)"

if [[ $RC -ne 0 || $ERRORS -ne 0 ]]; then
  echo "lint: FAIL (errors)" >&2
  exit 1
fi
if [[ $WARNINGS -gt $MAX_WARNINGS ]]; then
  echo "lint: FAIL (new warnings)" >&2
  exit 1
fi
echo "lint: PASS"
