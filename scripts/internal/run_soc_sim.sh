#!/usr/bin/env bash
# Internal: single TORV SoC case (compile + Verilator/VCS). Do not run directly;
# use:  scripts/run_case.sh [options] <asm.S>
set -euo pipefail

ROOT="$(builtin cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=rv32m_verdi_pli.inc.sh
source "$ROOT/scripts/rv32m_verdi_pli.inc.sh"
export RV32M_ROOT="${RV32M_ROOT:-$ROOT}"

if [[ ! -f "$ROOT/ip/third_party/socbus/rtl/AHB_APB_BRIDGE.v" ]]; then
  "$ROOT/scripts/fetch_ip.sh"
fi

PROJECT_ROOT="${PROJECT_ROOT:-$(builtin cd "$ROOT/.." && pwd)}"
if [[ "${PROJECT_ROOT:-}" != /* ]]; then
  PROJECT_ROOT="$(builtin cd "$ROOT/.." && pwd)"
fi
TOOLCHAIN="${TOOLCHAIN:-$PROJECT_ROOT/riscv_toolchain/bin}"
if [[ "${TOOLCHAIN:-}" != /* ]] \
   || [[ ! -x "${TOOLCHAIN}/${PREFIX:-riscv64-unknown-elf-}gcc" ]]; then
  TOOLCHAIN="$PROJECT_ROOT/riscv_toolchain/bin"
fi
PREFIX="${PREFIX:-riscv64-unknown-elf-}"
SRC="${1:-$ROOT/tests/core/asm/smoke.S}"
NAME="$(basename "$SRC")"
NAME="${NAME%.*}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build/sim/soc/$NAME}"
SIMULATOR="${RV32M_SIMULATOR:-verilator}"
SIMV="$BUILD_DIR/vcs/simv"
VL_SIM="$BUILD_DIR/verilator/obj_dir/Vtb_torv_soc"
MAX_CYCLES="${MAX_CYCLES:-20000}"
VCS="${VCS:-vcs}"

if [[ -d "$BUILD_DIR" && "${RV32M_KEEP_BUILD:-0}" != 1 ]]; then
  rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR/vcs"
printf '%s\n' "$BUILD_DIR" >"${RV32M_ROOT:-$ROOT}/.open_rv32m_last_case_build_dir"
export PATH="$TOOLCHAIN:$PATH"

"${PREFIX}gcc" \
  -march=rv32im -mabi=ilp32 \
  -nostdlib -nostartfiles -ffreestanding \
  -Wl,-T,"$ROOT/tests/core/link.ld" \
  "$SRC" -o "$BUILD_DIR/${NAME}.elf"

"${PREFIX}objdump" -d "$BUILD_DIR/${NAME}.elf" > "$BUILD_DIR/${NAME}.dump"
"${PREFIX}objcopy" -O verilog "$BUILD_DIR/${NAME}.elf" "$BUILD_DIR/${NAME}.hex"

rv32m_resolve_filelist_path() {
  local file="$1"
  file="${file//\$\{RV32M_ROOT\}/$RV32M_ROOT}"
  file="${file//\$RV32M_ROOT/$RV32M_ROOT}"
  if [[ "$file" = /* ]]; then
    printf '%s\n' "$file"
  else
    printf '%s\n' "$ROOT/$file"
  fi
}

mapfile -t RTL_FILES < <(
  while IFS= read -r file; do
    [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
    rv32m_resolve_filelist_path "$file"
  done < "$ROOT/rtl/filelist.f"
  if [[ -f "$ROOT/ip/filelist.f" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
      rv32m_resolve_filelist_path "$file"
    done < "$ROOT/ip/filelist.f"
  fi
)

if [[ "$SIMULATOR" == "verilator" ]]; then
  if [[ "${RUN_FSDB:-}" == 1 ]]; then
    echo "ERROR: FSDB is not supported with Verilator; use VCS or omit --fsdb." >&2
    exit 1
  fi
  if [[ "${RV32M_VCS_KDB:-0}" == 1 ]]; then
    echo "ERROR: --kdb is only for VCS." >&2
    exit 1
  fi
elif ! rv32m_verdi_pli_detect; then
  if [[ "${RUN_FSDB:-}" == 1 ]]; then
    echo "ERROR: RUN_FSDB=1 but Verdi PLI not found." >&2
    exit 1
  fi
fi

export RV32M_VCS_KDB="${RV32M_VCS_KDB:-0}"

CASE_PLUSARGS="$(dirname "$SRC")/${NAME}.plusargs"
if [[ ! -f "$CASE_PLUSARGS" ]]; then
  CASE_PLUSARGS="$ROOT/tests/core/asm/${NAME}.plusargs"
fi
PLUSARGS_EXTRA=()
if [[ -f "$CASE_PLUSARGS" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^\+max_cycles=([0-9]+)$ ]]; then
      MAX_CYCLES="${BASH_REMATCH[1]}"
      continue
    fi
    PLUSARGS_EXTRA+=("$line")
  done <"$CASE_PLUSARGS"
fi
PLUSARGS=(+imem="$BUILD_DIR/${NAME}.hex" +max_cycles="$MAX_CYCLES")
if [[ ${#PLUSARGS_EXTRA[@]} -gt 0 ]]; then
  PLUSARGS+=("${PLUSARGS_EXTRA[@]}")
fi
if [[ "${RUN_FSDB:-}" == 1 && "$SIMULATOR" == "vcs" ]]; then
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

if [[ "$SIMULATOR" == "verilator" ]]; then
  export RV32M_VERILATOR_TOP=tb_torv_soc
  VERILATOR_BUILD_DIR="$BUILD_DIR/verilator" "$ROOT/scripts/verilator_build.sh"
  cd "$BUILD_DIR"
  "$VL_SIM" "${PLUSARGS[@]}" >"$BUILD_DIR/${NAME}.sim.log" 2>&1
else
  KDB_FLAGS=()
  if [[ "${RV32M_VCS_KDB:-0}" == 1 ]]; then
    KDB_FLAGS=(-kdb -debug_access+all -LDFLAGS -rdynamic)
  fi

  cd "$BUILD_DIR/vcs"
  rm -rf csrc simv simv.daidir
  VCS_CMD=(
    "$VCS" -full64 -sverilog
    -timescale=1ns/1ps
    +incdir+"$ROOT/rtl"
    +incdir+"$ROOT/ip/third_party/socbus/include"
  )
  ((${#RV32M_FSDB_DEFINE[@]} > 0)) && VCS_CMD+=("${RV32M_FSDB_DEFINE[@]}")
  VCS_CMD+=("${RTL_FILES[@]}")
  VCS_CMD+=(
    "$ROOT/sim/tb_torv_soc.sv"
    -top tb_torv_soc
  )
  ((${#RV32M_VCS_PLI[@]} > 0)) && VCS_CMD+=("${RV32M_VCS_PLI[@]}")
  ((${#KDB_FLAGS[@]} > 0)) && VCS_CMD+=("${KDB_FLAGS[@]}")
  VCS_CMD+=(-Mdir=csrc -o simv -l "$BUILD_DIR/vcs/compile.log")
  "${VCS_CMD[@]}"

  if [[ "${RV32M_VCS_KDB:-0}" == 1 ]]; then
    touch "$BUILD_DIR/vcs/.rv32m_vcs_kdb"
  fi

  cd "$BUILD_DIR"
  "$SIMV" "${PLUSARGS[@]}" -l "$BUILD_DIR/${NAME}.sim.log"
fi

if grep -Eq 'TIMEOUT|\[FAIL\]|Error:' "$BUILD_DIR/${NAME}.sim.log"; then
  echo "TORV SoC test failed; see $BUILD_DIR/${NAME}.sim.log" >&2
  exit 1
fi

if ! grep -q '\[PASS\] TORV' "$BUILD_DIR/${NAME}.sim.log"; then
  echo "TORV SoC test did not report PASS; see $BUILD_DIR/${NAME}.sim.log" >&2
  exit 1
fi

echo "TORV SoC test passed: $NAME"
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
if [[ "${RV32M_EMIT_VERDI:-1}" == 1 && "$SIMULATOR" != "verilator" ]]; then
  "$ROOT/scripts/rv32m_emit_open_verdi.sh" "$BUILD_DIR" "$NAME" "$ROOT" "tb_torv_soc" "sim/filelists/verdi_soc.f"
fi
