#!/usr/bin/env bash
# Run Design Compiler for rv32im_core (TSMC_013 .db via TSMC013_TARGET_LIB)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec make -C "$ROOT/dc" synth
