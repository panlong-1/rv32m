#!/usr/bin/env bash
# Unified single-case simulation entry point for core and AHB targets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/run_case.sh [options] <asm-file>

Options:
  --target core|ahb     Simulation target (default: core)
  --sim vcs|verilator   HDL simulator (default: verilator). On CentOS 7 use
                        devtoolset (scripts/verilator_build.sh tries it) or set CXX.
  --fsdb                Dump FSDB waveform
  --vcd                 Dump VCD waveform
  --trace               Enable testbench trace plusarg
  --pc-trace            Dump PC trace TSV from the testbench
  --pc-trace-file FILE  Override PC trace output path
  --pc-trace-each-cycle Write one PC trace row every clock
  --kdb                 Build VCS KDB for Verdi source navigation
  --max-cycles N        Override max cycle count
  --build-dir DIR       Override output directory
  -h, --help            Show this help

Output:
  build/sim/<target>/<case>/ by default, containing ELF/HEX/DUMP, simulator
  build (verilator/ or vcs/), simulation log, optional FSDB/VCD, and open_verdi.sh
  when using VCS.
EOF
}

TARGET="${RV32M_TARGET:-core}"
SIMULATOR="${RV32M_SIMULATOR:-verilator}"
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
    --fsdb)
      export RUN_FSDB=1
      shift
      ;;
    --vcd|--waves)
      export RV32M_WAVE_VCD=1
      shift
      ;;
    --trace)
      export RV32M_TRACE=1
      shift
      ;;
    --pc-trace)
      export RV32M_PC_TRACE=1
      shift
      ;;
    --pc-trace-file)
      export RV32M_PC_TRACE_FILE="${2:?missing value for --pc-trace-file}"
      shift 2
      ;;
    --pc-trace-file=*)
      export RV32M_PC_TRACE_FILE="${1#*=}"
      shift
      ;;
    --pc-trace-each-cycle)
      export RV32M_PC_TRACE=1
      export RV32M_PC_TRACE_EACH_CYCLE=1
      shift
      ;;
    --kdb)
      export RV32M_VCS_KDB=1
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

case "$TARGET" in
  core)
    export RV32M_SIMULATOR="$SIMULATOR"
    exec "$ROOT/scripts/internal/run_core_sim.sh" "$SRC"
    ;;
  ahb)
    export RV32M_SIMULATOR="$SIMULATOR"
    exec "$ROOT/scripts/internal/run_ahb_sim.sh" "$SRC"
    ;;
  *)
    echo "ERROR: --target must be core or ahb, got: $TARGET" >&2
    exit 2
    ;;
esac
