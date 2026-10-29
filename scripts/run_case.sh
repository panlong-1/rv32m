#!/usr/bin/env bash
# Unified single-case simulation — TORV SoC (tb_torv_soc + torv_soc_top).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/run_case.sh [options] <asm-file>

Options:
  --target soc|core|ahb Simulation target (default: soc). core/ahb are aliases for soc.
  --sim verilator       HDL simulator (Verilator is the only supported one; the
                        option is kept for compatibility). On CentOS 7 use
                        devtoolset (scripts/verilator_build.sh tries it) or set CXX.
  --vcd                 Dump VCD waveform (open with scripts/open_gtkwave.sh)
  --trace               Enable testbench trace plusarg
  --pc-trace            Dump PC trace TSV from the testbench
  --pc-trace-file FILE  Override PC trace output path
  --pc-trace-each-cycle Write one PC trace row every clock
  --max-cycles N        Override max cycle count
  --build-dir DIR       Override output directory
  -h, --help            Show this help

Output:
  build/sim/soc/<case>/ by default, containing ELF/HEX/DUMP,
  the Verilator build (verilator/), simulation log (*.sim.log) and
  optional VCD / pc_trace.tsv.

  Asm may live under tests/core/asm/ or tests/periph/<ip>/; plusargs are picked from
  the same directory as the .S file, then tests/core/asm/<case>.plusargs.
EOF
}

TARGET="${TORV_TARGET:-soc}"
SIMULATOR=verilator
SRC=""

while (($#)); do
  case "$1" in
    --target)
      TARGET="${2:?missing value for --target}"
      shift 2
      ;;
    --target=*)
      TARGET="${1#*=}"
      shift
      ;;
    --sim)
      SIMULATOR="${2:?missing value for --sim}"
      shift 2
      ;;
    --sim=*)
      SIMULATOR="${1#*=}"
      shift
      ;;
    --vcd|--waves)
      export TORV_WAVE_VCD=1
      shift
      ;;
    --trace)
      export TORV_TRACE=1
      shift
      ;;
    --pc-trace)
      export TORV_PC_TRACE=1
      shift
      ;;
    --pc-trace-file)
      export TORV_PC_TRACE_FILE="${2:?missing value for --pc-trace-file}"
      shift 2
      ;;
    --pc-trace-file=*)
      export TORV_PC_TRACE_FILE="${1#*=}"
      shift
      ;;
    --pc-trace-each-cycle)
      export TORV_PC_TRACE=1
      export TORV_PC_TRACE_EACH_CYCLE=1
      shift
      ;;
    --max-cycles)
      export MAX_CYCLES="${2:?missing value for --max-cycles}"
      shift 2
      ;;
    --max-cycles=*)
      export MAX_CYCLES="${1#*=}"
      shift
      ;;
    --build-dir)
      export BUILD_DIR="${2:?missing value for --build-dir}"
      shift 2
      ;;
    --build-dir=*)
      export BUILD_DIR="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      SRC="$1"
      shift
      ;;
  esac
done

if [[ -z "$SRC" && $# -gt 0 ]]; then
  SRC="$1"
fi
SRC="${SRC:-$ROOT/tests/core/asm/smoke.S}"

if [[ "$SIMULATOR" != "verilator" ]]; then
  echo "ERROR: --sim must be verilator (the only supported simulator), got: $SIMULATOR" >&2
  exit 2
fi

export TORV_TARGET="$TARGET"

case "$TARGET" in
  core|ahb)
    echo "NOTE: --target $TARGET is deprecated; using TORV SoC (soc)." >&2
    TARGET=soc
    ;;
  soc)
    ;;
  *)
    echo "ERROR: --target must be soc (or deprecated core/ahb), got: $TARGET" >&2
    exit 2
    ;;
esac
export TORV_TARGET=soc
exec "$ROOT/scripts/internal/run_soc_sim.sh" "$SRC"
