#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=rv32m_verdi_pli.inc.sh
source "$ROOT/scripts/rv32m_verdi_pli.inc.sh"
TOOLCHAIN="${TOOLCHAIN:-/home/ic/project/riscv_toolchain/bin}"
PREFIX="${PREFIX:-riscv64-unknown-elf-}"
SRC="${1:-$ROOT/tests/core/asm/smoke.S}"
NAME="$(basename "$SRC")"
NAME="${NAME%.*}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build/sim/core/$NAME}"
SIMV="$BUILD_DIR/vcs/simv"
MAX_CYCLES="${MAX_CYCLES:-5000}"

if [[ -d "$BUILD_DIR" && "${RV32M_KEEP_BUILD:-0}" != 1 ]]; then
  rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
export PATH="$TOOLCHAIN:$PATH"

"${PREFIX}gcc" \
  -march=rv32im -mabi=ilp32 \
  -nostdlib -nostartfiles -ffreestanding \
  -Wl,-T,"$ROOT/tests/core/link.ld" \
  "$SRC" -o "$BUILD_DIR/${NAME}.elf"

"${PREFIX}objdump" -d "$BUILD_DIR/${NAME}.elf" > "$BUILD_DIR/${NAME}.dump"
"${PREFIX}objcopy" -O verilog "$BUILD_DIR/${NAME}.elf" "$BUILD_DIR/${NAME}.hex"

if ! rv32m_verdi_pli_detect; then
  if [[ "${RUN_FSDB:-}" == 1 ]]; then
    echo "ERROR: RUN_FSDB=1 but Verdi PLI not found. Set VERDI_HOME (or NOVAS_HOME)." >&2
    exit 1
  fi
fi

export RV32M_NEED_FSDB="${RUN_FSDB:-0}"
export RV32M_VCS_KDB="${RV32M_VCS_KDB:-0}"
VCS_BUILD_DIR="$BUILD_DIR/vcs" OUT="$SIMV" "$ROOT/scripts/vcs_build.sh"

PLUSARGS=(+imem="$BUILD_DIR/${NAME}.hex" +max_cycles="$MAX_CYCLES")
if [[ "${RUN_FSDB:-}" == 1 ]]; then
  PLUSARGS+=(+fsdb +fsdbfile="$BUILD_DIR/${NAME}.fsdb")
fi
if [[ "${RV32M_WAVE_VCD:-0}" == 1 ]]; then
  PLUSARGS+=(+vcd +vcdfile="$BUILD_DIR/${NAME}.vcd")
fi
if [[ "${RV32M_TRACE:-0}" == 1 ]]; then
  PLUSARGS+=(+trace)
fi
if [[ "${RV32M_PC_TRACE:-0}" == 1 ]]; then
  PC_TRACE_FILE="${RV32M_PC_TRACE_FILE:-$BUILD_DIR/pc_trace.tsv}"
  PLUSARGS+=(+pc_trace +pc_trace_file="$PC_TRACE_FILE")
  if [[ "${RV32M_PC_TRACE_EACH_CYCLE:-0}" == 1 ]]; then
    PLUSARGS+=(+pc_trace_each_cycle)
  fi
fi

cd "$BUILD_DIR"
"$SIMV" "${PLUSARGS[@]}" -l "$BUILD_DIR/${NAME}.sim.log"

if grep -Eq 'TIMEOUT|\[FAIL\]|Error:' "$BUILD_DIR/${NAME}.sim.log"; then
  echo "Toolchain test failed; see $BUILD_DIR/${NAME}.sim.log" >&2
  exit 1
fi

if ! grep -q '\[PASS\] tohost signalled success' "$BUILD_DIR/${NAME}.sim.log"; then
  echo "Toolchain test did not report PASS; see $BUILD_DIR/${NAME}.sim.log" >&2
  exit 1
fi

echo "Toolchain test passed: $NAME"
echo "ELF:  $BUILD_DIR/${NAME}.elf"
echo "HEX:  $BUILD_DIR/${NAME}.hex"
echo "DUMP: $BUILD_DIR/${NAME}.dump"
echo "LOG:  $BUILD_DIR/${NAME}.sim.log"
if [[ "${RUN_FSDB:-}" == 1 ]]; then
  echo "FSDB: $BUILD_DIR/${NAME}.fsdb"
fi
if [[ "${RV32M_WAVE_VCD:-0}" == 1 ]]; then
  echo "VCD:  $BUILD_DIR/${NAME}.vcd"
fi
if [[ "${RV32M_PC_TRACE:-0}" == 1 ]]; then
  echo "PC_TRACE: ${PC_TRACE_FILE:-$BUILD_DIR/pc_trace.tsv}"
fi
if [[ "${RV32M_EMIT_VERDI:-1}" == 1 ]]; then
  "$ROOT/scripts/rv32m_emit_open_verdi.sh" "$BUILD_DIR" "$NAME" "$ROOT" tb_rv32im_top sim/filelists/verdi_core.f
fi
