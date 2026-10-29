#!/usr/bin/env bash
# Open GTKWave on a VCD from scripts/run_case.sh or sim/Makefile (TORV SoC).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GTKWAVE="${GTKWAVE:-${TORV_GTKWAVE:-gtkwave}}"

usage() {
  cat <<'EOF'
Usage:
  scripts/open_gtkwave.sh [options] [case-stem]

Options:
  --target soc        Default: soc (core/ahb are deprecated aliases)
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

TARGET="${TORV_TARGET:-soc}"
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
# run_case.sh always builds the TORV SoC under build/sim/soc/.
[[ "$TARGET" == core || "$TARGET" == ahb ]] && TARGET=soc

if ! command -v "$GTKWAVE" >/dev/null 2>&1; then
  echo "ERROR: '$GTKWAVE' not in PATH. Install GTKWave (distro package or set TORV_GTKWAVE)." >&2
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
    echo "  ./scripts/run_case.sh --vcd tests/core/asm/${STEM}.S" >&2
    exit 1
  fi
fi

echo "Opening: $VCD"
exec "$GTKWAVE" "$VCD"
