#!/usr/bin/env bash
# open_rv32m environment — source this file before builds, sim, or regress.
#
# Usage (from repository root):
#   source scripts/open_rv.sh
#
# Path configuration (set *before* sourcing, or edit scripts/open_rv.local.sh):
#
#   RISC-V GNU toolchain
#     RV32M_RISCV_TOOLCHAIN_BIN   — directory containing ${PREFIX}gcc (default: ../riscv_toolchain/bin)
#     RV32M_RISCV_GNU_PREFIX      — triplet prefix, e.g. riscv64-unknown-elf- (default below)
#
#   Open-source / general EDA
#     RV32M_VERILATOR             — verilator executable or name on PATH (default: verilator)
#     RV32M_VERILATOR_BIN_DIR     — optional: prepend this bin dir (e.g. /usr/local/bin)
#     RV32M_GTKWAVE               — gtkwave executable (default: gtkwave)
#
#   Synopsys (optional; leave empty or unset to skip PATH injection)
#     RV32M_VCS_HOME
#     RV32M_VERDI_HOME
#     RV32M_DC_HOME
#     RV32M_SNPSLMD_LICENSE_FILE  — e.g. 27000@license-server
#
# Legacy names TOOLCHAIN, PREFIX, VCS_HOME, VERDI_HOME, DC_HOME are still exported
# for existing scripts.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "open_rv32m: source scripts/open_rv.sh from bash (required for path detection)." >&2
  return 2 2>/dev/null || exit 2
fi
_open_rv_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RV32M_ROOT="${RV32M_ROOT:-$(cd "${_open_rv_here}/.." && pwd)}"
export PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${RV32M_ROOT}/.." && pwd)}"

# Optional per-machine overrides (gitignored); copy from open_rv.local.sh.example
if [[ -f "${_open_rv_here}/open_rv.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "${_open_rv_here}/open_rv.local.sh"
fi

# ---------------------------------------------------------------------------
# RISC-V bare-metal GNU toolchain
# ---------------------------------------------------------------------------
export RV32M_RISCV_TOOLCHAIN_BIN="${RV32M_RISCV_TOOLCHAIN_BIN:-$PROJECT_ROOT/riscv_toolchain/bin}"
export RV32M_RISCV_GNU_PREFIX="${RV32M_RISCV_GNU_PREFIX:-riscv64-unknown-elf-}"

# ---------------------------------------------------------------------------
# EDA tools
# ---------------------------------------------------------------------------
export RV32M_VERILATOR="${RV32M_VERILATOR:-verilator}"
export RV32M_VERILATOR_BIN_DIR="${RV32M_VERILATOR_BIN_DIR:-}"
export RV32M_GTKWAVE="${RV32M_GTKWAVE:-gtkwave}"

export RV32M_VCS_HOME="${RV32M_VCS_HOME:-/opt/synopsys/vcs/Q-2020.03-SP2-7}"
export RV32M_VERDI_HOME="${RV32M_VERDI_HOME:-/opt/synopsys/verdi/R-2020.12-SP1}"
export RV32M_DC_HOME="${RV32M_DC_HOME:-/opt/synopsys/syn/R-2020.09-SP4}"
# export RV32M_SNPSLMD_LICENSE_FILE=27000@your-license-server

# Design Compiler PDK (optional)
export TSMC013_TARGET_LIB="${TSMC013_TARGET_LIB:-$HOME/PDK/TSMC_013/synopsys/slow.db}"

# --- Legacy / script-compatible exports ---
export TOOLCHAIN="$RV32M_RISCV_TOOLCHAIN_BIN"
export PREFIX="$RV32M_RISCV_GNU_PREFIX"
export VCS_HOME="$RV32M_VCS_HOME"
export VERDI_HOME="$RV32M_VERDI_HOME"
export NOVAS_HOME="${NOVAS_HOME:-$RV32M_VERDI_HOME}"
export DC_HOME="$RV32M_DC_HOME"
export VERILATOR="$RV32M_VERILATOR"
if [[ -n "${RV32M_SNPSLMD_LICENSE_FILE:-}" ]]; then
  export SNPSLMD_LICENSE_FILE="$RV32M_SNPSLMD_LICENSE_FILE"
fi

unset _open_rv_here

open_rv32m_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

open_rv32m_path_prepend "$RV32M_ROOT/scripts"
open_rv32m_path_prepend "$RV32M_RISCV_TOOLCHAIN_BIN"
[[ -n "$RV32M_VERILATOR_BIN_DIR" && -d "$RV32M_VERILATOR_BIN_DIR" ]] && open_rv32m_path_prepend "$RV32M_VERILATOR_BIN_DIR"
[[ -d "${RV32M_DC_HOME}/bin" ]] && open_rv32m_path_prepend "${RV32M_DC_HOME}/bin"
[[ -d "${RV32M_VERDI_HOME}/bin" ]] && open_rv32m_path_prepend "${RV32M_VERDI_HOME}/bin"
[[ -d "${RV32M_VCS_HOME}/bin" ]] && open_rv32m_path_prepend "${RV32M_VCS_HOME}/bin"

export RV32M_FILELIST_CORE="$RV32M_ROOT/sim/filelists/verdi_core.f"
export RV32M_FILELIST_AHB="$RV32M_ROOT/sim/filelists/verdi_ahb.f"
export RV32M_LAST_CASE_DIR_FILE="${RV32M_ROOT}/.open_rv32m_last_case_build_dir"

t() {
  local f="${RV32M_LAST_CASE_DIR_FILE:-$RV32M_ROOT/.open_rv32m_last_case_build_dir}"
  if [[ ! -f "$f" ]]; then
    echo "t: no last case directory file. Run run_case.sh first." >&2
    return 1
  fi
  local d
  d="$(tr -d '\r' <"$f")"
  if [[ -z "$d" || ! -d "$d" ]]; then
    echo "t: invalid or missing directory: ${d:-<empty>}" >&2
    return 1
  fi
  builtin cd "$d" || return 1
  echo "cd -> $PWD"
}

echo "open_rv32m env ready:"
echo "  RV32M_ROOT=$RV32M_ROOT"
echo "  PROJECT_ROOT=$PROJECT_ROOT"
echo "  RV32M_RISCV_TOOLCHAIN_BIN=$RV32M_RISCV_TOOLCHAIN_BIN"
echo "  RV32M_RISCV_GNU_PREFIX=$RV32M_RISCV_GNU_PREFIX"
echo "  RV32M_VERILATOR=$RV32M_VERILATOR ($(command -v "$RV32M_VERILATOR" 2>/dev/null || echo missing))"
echo "  RV32M_VCS_HOME=$RV32M_VCS_HOME (vcs: $(command -v vcs 2>/dev/null || echo missing))"
echo "  RV32M_VERDI_HOME=$RV32M_VERDI_HOME (verdi: $(command -v verdi 2>/dev/null || echo missing))"
echo "  RV32M_DC_HOME=$RV32M_DC_HOME"
echo "  After run_case.sh:  t  -> cd to last case build dir"
