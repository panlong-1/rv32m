#!/usr/bin/env bash
# Open GTKWave on a VCD from scripts/run_case.sh or sim/Makefile (core/AHB).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GTKWAVE="${GTKWAVE:-gtkwave}"

usage() {
  cat <<'EOF'
Usage:
  scripts/open_gtkwave.sh [options] [case-stem]

Options:
  --target core|ahb   Default: core (or RV32M_TARGET)
  --build-dir DIR     Case output directory (overrides default layout)
  --vcd FILE          Open this file directly
  -h, --help

Default VCD path (when --vcd is omitted):
  build/sim/<target>/<case>/<case>.vcd

Example:
  ./scripts/run_case.sh --vcd tests/core/asm/smoke.S
  ./scripts/open_gtkwave.sh smoke
EOF
}

TARGET="${RV32M_TARGET:-core}"
BUILD_DIR=""
VCD=""

while (($#)); do
  case "$1" in
    --target)
      TARGET="${2:?}"
      shift 2
      ;;
    --target=*)
      TARGET="${1#*=}"
      shift
      ;;
    --build-dir)
      BUILD_DIR="${2:?}"
      shift 2
      ;;
    --build-dir=*)
      BUILD_DIR="${1#*=}"
      shift
      ;;
    --vcd)
      VCD="${2:?}"
      shift 2
      ;;
    --vcd=*)
      VCD="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

STEM="${1:-smoke}"

if ! command -v "$GTKWAVE" >/dev/null 2>&1; then
  echo "ERROR: '$GTKWAVE' not in PATH. Install GTKWave (see scripts/install_gtkwave_centos7.sh)." >&2
  exit 127
fi

if [[ -n "$VCD" ]]; then
  if [[ ! -f "$VCD" ]]; then
    echo "ERROR: VCD not found: $VCD" >&2
    exit 1
  fi
else
  case_dir="${BUILD_DIR:-$ROOT/build/sim/$TARGET/$STEM}"
  VCD="$case_dir/${STEM}.vcd"
  if [[ ! -f "$VCD" ]]; then
    echo "ERROR: VCD not found: $VCD" >&2
    echo "Run the case with --vcd first, e.g.:" >&2
    echo "  ./scripts/run_case.sh --target $TARGET --vcd tests/core/asm/${STEM}.S" >&2
    exit 1
  fi
fi

echo "Opening: $VCD"
exec "$GTKWAVE" "$VCD"
