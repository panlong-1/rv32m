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
# Open-source tools only: RISC-V GNU toolchain, Verilator, GTKWave, the IHP
# SG13G2 PDK (SRAM models) and LibreLane. Downstream scripts use TOOLCHAIN,
# PREFIX, VERILATOR and PDK_ROOT — do not rename those exports.

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
# Distro package (Ubuntu: gcc-riscv64-unknown-elf) installs into /usr/bin.
if [[ -z "${RV32M_RISCV_TOOLCHAIN_BIN:-}" && ! -x "${PROJECT_ROOT}/riscv_toolchain/bin/riscv64-unknown-elf-gcc" \
      && -x /usr/bin/riscv64-unknown-elf-gcc ]]; then
  RV32M_RISCV_TOOLCHAIN_BIN=/usr/bin
fi
: "${RV32M_RISCV_TOOLCHAIN_BIN:=${PROJECT_ROOT}/riscv_toolchain/bin}"
# : "${RV32M_RISCV_TOOLCHAIN_BIN:=/absolute/path/to/riscv/bin}"
: "${RV32M_RISCV_GNU_PREFIX:=riscv64-unknown-elf-}"

# --- Verilator / GTKWave (simulation & waves) ---
: "${RV32M_VERILATOR:=verilator}"
: "${RV32M_VERILATOR_BIN_DIR:=}"
: "${RV32M_GTKWAVE:=gtkwave}"

# --- IHP SG13G2 PDK (SRAM macro models for simulation; LibreLane PDK_ROOT) ---
: "${PDK_ROOT:=${HOME}/.ciel}"

# --- LibreLane (Python venv; runs the flow in its Docker image) ---
: "${LIBRELANE_VENV:=${HOME}/.venv/librelane}"

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
export PDK_ROOT
export LIBRELANE_VENV

export RV32M_VERILATOR="${RV32M_VERILATOR:-verilator}"
export RV32M_VERILATOR_BIN_DIR="${RV32M_VERILATOR_BIN_DIR:-}"
export RV32M_GTKWAVE="${RV32M_GTKWAVE:-gtkwave}"

# Short names used by scripts/internal/*.sh, verilator_build.sh and sim/Makefile
export TOOLCHAIN="$RV32M_RISCV_TOOLCHAIN_BIN"
export PREFIX="$RV32M_RISCV_GNU_PREFIX"
export VERILATOR="$RV32M_VERILATOR"

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
echo "  RV32M_GTKWAVE=$RV32M_GTKWAVE ($(command -v "$RV32M_GTKWAVE" 2>/dev/null || echo missing))"
if [[ -d "$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_sram/verilog" ]]; then
  echo "  PDK_ROOT=$PDK_ROOT (IHP SRAM models: ok)"
else
  echo "  PDK_ROOT=$PDK_ROOT (IHP SRAM models: MISSING — install ihp-sg13g2 or set PDK_ROOT)"
fi
if [[ -x "$LIBRELANE_VENV/bin/python" ]]; then
  echo "  LIBRELANE_VENV=$LIBRELANE_VENV (ok; only needed for make -C librelane)"
else
  echo "  LIBRELANE_VENV=$LIBRELANE_VENV (missing; only needed for make -C librelane)"
fi
echo "  After run_case.sh:  t  -> cd to last case build dir"
