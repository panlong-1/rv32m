#!/usr/bin/env bash
# Verilator — build TORV SoC simulation (tb_torv_soc).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export RV32M_ROOT="${RV32M_ROOT:-$ROOT}"

# RHEL/CentOS 7: Verilator-emitted C++ needs a recent g++. Try SCL devtoolset if
# the default compiler fails a trivial -std=c++17 compile. Override with
# RV32M_VERILATOR_NO_DEVTOOLSET=1 or set CXX explicitly.
rv32m_verilator_pick_cxx() {
  if [[ "${RV32M_VERILATOR_NO_DEVTOOLSET:-0}" == 1 ]]; then
    return 0
  fi
  local try="${CXX:-g++}"
  if echo 'int main(){}' | "$try" -std=c++17 -x c++ - -o /dev/null 2>/dev/null; then
    return 0
  fi
  for dts in devtoolset-11 devtoolset-10 devtoolset-9; do
    local en="/opt/rh/${dts}/enable"
    if [[ -f "$en" ]]; then
      # shellcheck source=/dev/null
      source "$en"
      echo "open_rv32m: using ${dts} for Verilator C++ build (host g++ too old)." >&2
      return 0
    fi
  done
  echo "open_rv32m: WARNING: g++ may be too old for Verilator; install devtoolset-9+ or set CXX." >&2
}
rv32m_verilator_pick_cxx

VERILATOR="${VERILATOR:-verilator}"
VERILATOR_BUILD_DIR="${VERILATOR_BUILD_DIR:-$ROOT/build/sim/core/verilator}"
TOP="${RV32M_VERILATOR_TOP:-tb_torv_soc}"

mkdir -p "$VERILATOR_BUILD_DIR"
rm -rf "$VERILATOR_BUILD_DIR/obj_dir"

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

RTL_FILES=()
while IFS= read -r file; do
  [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
  RTL_FILES+=("$(rv32m_resolve_filelist_path "$file")")
done < "$ROOT/rtl/filelist.f"

IP_FILES=()
if [[ -f "$ROOT/ip/filelist.f" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
    IP_FILES+=("$(rv32m_resolve_filelist_path "$file")")
  done < "$ROOT/ip/filelist.f"
fi

EXTRA_SV=("$ROOT/sim/tb_torv_soc.sv")
if [[ "$TOP" != "tb_torv_soc" ]]; then
  echo "ERROR: RV32M_VERILATOR_TOP must be tb_torv_soc (got $TOP)" >&2
  exit 2
fi

cd "$VERILATOR_BUILD_DIR"

: >verilator.log
VL_CMD=(
  "$VERILATOR" --binary --timing --trace
  -Wno-fatal
  -Wno-TIMESCALEMOD
  -Mdir obj_dir
  -CFLAGS "-std=c++17"
  --top-module "$TOP"
  -I"$ROOT/rtl"
  -I"$ROOT/ip/third_party/socbus/include"
  -O1
  "${RTL_FILES[@]}"
  "${IP_FILES[@]}"
  "${EXTRA_SV[@]}"
  -o "V${TOP}"
  -MAKEFLAGS "CXX=${CXX:-g++}"
)

echo "${VL_CMD[*]}" >>verilator.log
"${VL_CMD[@]}" >>verilator.log 2>&1

echo "Build OK: $VERILATOR_BUILD_DIR/obj_dir/V${TOP}"
