#!/usr/bin/env bash
# open_rv32m environment — source this file before builds, sim, or regress.
#
# Usage (from anywhere):
#   source /path/to/open_rv32m/scripts/open_rv.sh
#
# From the repository root:
#   source scripts/open_rv.sh
#
# Override any variable *before* sourcing (e.g. export VCS_HOME=/opt/...).
# RV32M_ROOT defaults to the directory that contains this scripts/ folder.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "open_rv32m: source scripts/open_rv.sh from bash (required for path detection)." >&2
  return 2 2>/dev/null || exit 2
fi
_open_rv_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RV32M_ROOT="${RV32M_ROOT:-$(cd "${_open_rv_here}/.." && pwd)}"
export PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${RV32M_ROOT}/.." && pwd)}"
unset _open_rv_here

# Synopsys / DC site layout (optional). Unset or override if not installed.
export VCS_HOME="${VCS_HOME:-/opt/synopsys/vcs/Q-2020.03-SP2-7}"
export VERDI_HOME="${VERDI_HOME:-/opt/synopsys/verdi/R-2020.12-SP1}"
export NOVAS_HOME="${NOVAS_HOME:-$VERDI_HOME}"
export DC_HOME="${DC_HOME:-/opt/synopsys/syn/R-2020.09-SP4}"
# Synopsys license (required only for VCS/Verdi/DC). Set before sourcing, e.g.:
#   export SNPSLMD_LICENSE_FILE=27000@your-license-server

# Bare-metal RISC-V GNU toolchain (sibling to this repo by default).
export TOOLCHAIN="${TOOLCHAIN:-$PROJECT_ROOT/riscv_toolchain/bin}"
export PREFIX="${PREFIX:-riscv64-unknown-elf-}"

# TSMC 0.13um library for Design Compiler (optional).
export TSMC013_TARGET_LIB="${TSMC013_TARGET_LIB:-$HOME/PDK/TSMC_013/synopsys/slow.db}"

open_rv32m_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

open_rv32m_path_prepend "$RV32M_ROOT/scripts"
open_rv32m_path_prepend "$TOOLCHAIN"
[[ -d "${DC_HOME}/bin" ]] && open_rv32m_path_prepend "$DC_HOME/bin"
[[ -d "${VERDI_HOME}/bin" ]] && open_rv32m_path_prepend "$VERDI_HOME/bin"
[[ -d "${VCS_HOME}/bin" ]] && open_rv32m_path_prepend "$VCS_HOME/bin"

export RV32M_FILELIST_CORE="$RV32M_ROOT/sim/filelists/verdi_core.f"
export RV32M_FILELIST_AHB="$RV32M_ROOT/sim/filelists/verdi_ahb.f"
export RV32M_LAST_CASE_DIR_FILE="${RV32M_ROOT}/.open_rv32m_last_case_build_dir"

# Jump to last run_case.sh output directory (written by scripts/internal/*_sim.sh).
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
echo "  PATH: run_case.sh, regress.sh, open_gtkwave.sh, … (see: command -v run_case.sh)"
echo "  After run_case.sh:  t  -> cd to last case build dir"
echo "  VCS=$(command -v vcs 2>/dev/null || echo missing)"
echo "  VERDI=$(command -v verdi 2>/dev/null || echo missing)"
echo "  TOOLCHAIN=$TOOLCHAIN"
