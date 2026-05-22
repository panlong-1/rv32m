#!/usr/bin/env bash
# Synopsys VCS — build rv32im_core simulation.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=rv32m_verdi_pli.inc.sh
source "$ROOT/scripts/rv32m_verdi_pli.inc.sh"
export RV32M_ROOT="${RV32M_ROOT:-$ROOT}"

VCS="${VCS:-vcs}"
VCS_BUILD_DIR="${VCS_BUILD_DIR:-$ROOT/build/sim/core/vcs}"
OUT="${OUT:-$VCS_BUILD_DIR/simv}"
OUT_NAME="$(basename "$OUT")"
OUT_PATH="$VCS_BUILD_DIR/$OUT_NAME"

mkdir -p "$VCS_BUILD_DIR"
rm -rf "$VCS_BUILD_DIR/csrc" "$VCS_BUILD_DIR/$OUT_NAME" "$VCS_BUILD_DIR/${OUT_NAME}.daidir"
cd "$VCS_BUILD_DIR"

RTL_FILES=()
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
while IFS= read -r file; do
  [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
  RTL_FILES+=("$(rv32m_resolve_filelist_path "$file")")
done < "$ROOT/rtl/filelist.f"
if [[ -f "$ROOT/ip/filelist.f" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
    RTL_FILES+=("$(rv32m_resolve_filelist_path "$file")")
  done < "$ROOT/ip/filelist.f"
fi

if ! rv32m_verdi_pli_detect; then
  :
fi
if [[ "${RV32M_NEED_FSDB:-}" == 1 ]] && (( ${#RV32M_FSDB_DEFINE[@]} == 0 )); then
  echo "ERROR: FSDB build requested (RV32M_NEED_FSDB=1) but Verdi PLI is not available. Set VERDI_HOME (or NOVAS_HOME) to a Verdi install with share/PLI/VCS/LINUX64/{novas.tab,pli.a}." >&2
  exit 1
fi

KDB_FLAGS=()
if [[ "${RV32M_VCS_KDB:-0}" == 1 ]]; then
  KDB_FLAGS=(-kdb -debug_access+all -LDFLAGS -rdynamic)
fi

# -full64: omit if your site uses 32-bit VCS
# -sverilog: SystemVerilog
# +lint=all,noVCDE: optional lint (remove if noisy at your site)
CMD=(
  "$VCS" -full64 -sverilog
  -timescale=1ns/1ps
  +incdir+"$ROOT/rtl"
  +incdir+"$ROOT/ip/third_party/socbus/include"
)
((${#RV32M_FSDB_DEFINE[@]} > 0)) && CMD+=("${RV32M_FSDB_DEFINE[@]}")
CMD+=("${RTL_FILES[@]}")
CMD+=("$ROOT/sim/tb_torv_soc.sv" -top tb_torv_soc)
((${#RV32M_VCS_PLI[@]} > 0)) && CMD+=("${RV32M_VCS_PLI[@]}")
((${#KDB_FLAGS[@]} > 0)) && CMD+=("${KDB_FLAGS[@]}")
CMD+=(-Mdir=csrc -o "$OUT_NAME" -l "$VCS_BUILD_DIR/compile.log")

echo "${CMD[*]}"
"${CMD[@]}"

if [[ "${RV32M_VCS_KDB:-0}" == 1 ]]; then
  touch "$VCS_BUILD_DIR/.rv32m_vcs_kdb"
fi

echo "Build OK: $OUT_PATH"
echo "Run:     $OUT_PATH -l <case>.sim.log"
