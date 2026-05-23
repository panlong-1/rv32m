#!/usr/bin/env bash
# open_rv32m environment — source this file before builds, sim, or regress.
#
# Usage (from repository root):
#   source scripts/open_rv.sh
#
# Path priority (highest first):
#   1. Variables already exported in your shell before sourcing
#   2. scripts/open_rv.local.sh (gitignored, optional)
#   3. Site defaults block below (edit paths for your machine)
#   4. Generic fallbacks ($PROJECT_ROOT/riscv_toolchain/bin, etc.)
#
# Downstream scripts still use TOOLCHAIN, PREFIX, VCS_HOME, VERDI_HOME, DC_HOME,
# VERILATOR — do not rename those exports.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "open_rv32m: source scripts/open_rv.sh from bash (required for path detection)." >&2
  return 2 2>/dev/null || exit 2
fi
# Use builtin cd: a user cd() that runs ls (e.g. auto-list after cd) breaks $(cd ... && pwd).
_open_rv_here="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RV32M_ROOT="${RV32M_ROOT:-$(builtin cd "${_open_rv_here}/.." && pwd)}"
_open_rv_project_root="$(builtin cd "${RV32M_ROOT}/.." && pwd)"
# Ignore a non-absolute PROJECT_ROOT from the parent shell (e.g. accidental "bin").
if [[ "${PROJECT_ROOT:-}" != /* ]]; then
  PROJECT_ROOT="$_open_rv_project_root"
fi
export PROJECT_ROOT
unset _open_rv_project_root

# Drop stale relative toolchain paths (e.g. PROJECT_ROOT=bin from a broken prior source).
if [[ "${RV32M_RISCV_TOOLCHAIN_BIN:-}" != /* ]] \
   || [[ ! -x "${RV32M_RISCV_TOOLCHAIN_BIN}/${RV32M_RISCV_GNU_PREFIX:-riscv64-unknown-elf-}gcc" ]]; then
  unset RV32M_RISCV_TOOLCHAIN_BIN TOOLCHAIN
fi

# =============================================================================
# Site defaults — edit here for your machine (no manual export before source).
# Only fills variables that are not already set in the environment.
# PROJECT_ROOT defaults to the parent of this repo (e.g. .../project).
# =============================================================================

# --- RISC-V bare-metal GNU toolchain (directory must contain ${PREFIX}gcc) ---
: "${RV32M_RISCV_TOOLCHAIN_BIN:=${PROJECT_ROOT}/riscv_toolchain/bin}"
# : "${RV32M_RISCV_TOOLCHAIN_BIN:=/absolute/path/to/riscv/bin}"
: "${RV32M_RISCV_GNU_PREFIX:=riscv64-unknown-elf-}"

# --- Verilator / GTKWave (open-source sim & waves) ---
: "${RV32M_VERILATOR:=verilator}"
: "${RV32M_VERILATOR_BIN_DIR:=/usr/local/bin}"
: "${RV32M_GTKWAVE:=gtkwave}"

# --- Synopsys (optional; leave empty to skip adding to PATH) ---
: "${RV32M_VCS_HOME:=/opt/synopsys/vcs/Q-2020.03-SP2-7}"
: "${RV32M_VERDI_HOME:=/opt/synopsys/verdi/R-2020.12-SP1}"
: "${RV32M_DC_HOME:=/opt/synopsys/syn/R-2020.09-SP4}"
# : "${RV32M_SNPSLMD_LICENSE_FILE:=27000@your-license-server}"

# --- Design Compiler PDK (optional) ---
: "${TSMC013_TARGET_LIB:=${HOME}/PDK/TSMC_013/synopsys/slow.db}"

# CentOS 7 / RHEL: Verilator C++ link often needs a newer g++ (uncomment if needed)
# if [[ -f /opt/rh/devtoolset-11/enable ]]; then
#   # shellcheck source=/dev/null
#   source /opt/rh/devtoolset-11/enable
# fi

# Optional per-machine overrides (gitignored); copy from open_rv.local.sh.example
if [[ -f "${_open_rv_here}/open_rv.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "${_open_rv_here}/open_rv.local.sh"
fi

# ---------------------------------------------------------------------------
# Export (names unchanged — run_case.sh / regress / Makefile rely on these)
# ---------------------------------------------------------------------------
export RV32M_RISCV_TOOLCHAIN_BIN="${RV32M_RISCV_TOOLCHAIN_BIN:-${PROJECT_ROOT}/riscv_toolchain/bin}"
export RV32M_RISCV_GNU_PREFIX="${RV32M_RISCV_GNU_PREFIX:-riscv64-unknown-elf-}"

export RV32M_VERILATOR="${RV32M_VERILATOR:-verilator}"
export RV32M_VERILATOR_BIN_DIR="${RV32M_VERILATOR_BIN_DIR:-}"
export RV32M_GTKWAVE="${RV32M_GTKWAVE:-gtkwave}"

export RV32M_VCS_HOME="${RV32M_VCS_HOME:-}"
export RV32M_VERDI_HOME="${RV32M_VERDI_HOME:-}"
export RV32M_DC_HOME="${RV32M_DC_HOME:-}"

export TSMC013_TARGET_LIB="${TSMC013_TARGET_LIB:-}"

# Legacy aliases used by scripts/internal/*.sh and sim/Makefile shortcuts
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
[[ -n "${RV32M_DC_HOME}" && -d "${RV32M_DC_HOME}/bin" ]] && open_rv32m_path_prepend "${RV32M_DC_HOME}/bin"
[[ -n "${RV32M_VERDI_HOME}" && -d "${RV32M_VERDI_HOME}/bin" ]] && open_rv32m_path_prepend "${RV32M_VERDI_HOME}/bin"
[[ -n "${RV32M_VCS_HOME}" && -d "${RV32M_VCS_HOME}/bin" ]] && open_rv32m_path_prepend "${RV32M_VCS_HOME}/bin"

export RV32M_FILELIST_SOC="$RV32M_ROOT/sim/filelists/verdi_soc.f"
export RV32M_FILELIST_CORE="$RV32M_FILELIST_SOC"
export RV32M_FILELIST_AHB="$RV32M_FILELIST_SOC"
export RV32M_TARGET="${RV32M_TARGET:-soc}"
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
echo "  RV32M_VCS_HOME=${RV32M_VCS_HOME:-<unset>} (vcs: $(command -v vcs 2>/dev/null || echo missing))"
echo "  RV32M_VERDI_HOME=${RV32M_VERDI_HOME:-<unset>} (verdi: $(command -v verdi 2>/dev/null || echo missing))"
echo "  RV32M_DC_HOME=${RV32M_DC_HOME:-<unset>}"
echo "  After run_case.sh:  t  -> cd to last case build dir"
