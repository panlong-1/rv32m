#!/usr/bin/env bash
# Run LibreLane synthesis for rv32im_ahb_top on IHP SG13G2 (see librelane/Makefile)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec make -C "$ROOT/librelane" synth "$@"
