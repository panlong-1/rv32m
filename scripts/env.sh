#!/usr/bin/env bash
# TORV environment — source this file before builds, sim, or regress.
#
# Usage (from repository root):
#   source scripts/env.sh
#
# Path priority (highest first):
#   1. Variables already exported in your shell before sourcing
#   2. scripts/env.local.sh (gitignored, optional)
#   3. Site defaults block below (edit paths for your machine)
#   4. Generic fallbacks ($PROJECT_ROOT/riscv_toolchain/bin, etc.)
#
# Open-source tools only: RISC-V GNU toolchain, Verilator, GTKWave, the IHP
# SG13G2 PDK (SRAM models) and LibreLane. Downstream scripts use TOOLCHAIN,
# PREFIX, VERILATOR and PDK_ROOT — do not rename those exports.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "torv: source scripts/env.sh from bash (required for path detection)." >&2
  return 2 2>/dev/null || exit 2
fi
# Deprecated RV32M_* names (before v0.8.0): copy them to TORV_* unless already set.
# Remove in v0.9.0.
for _torv_env_old in $(compgen -v RV32M_ || true); do
  _torv_env_new="TORV_${_torv_env_old#RV32M_}"
  if [[ -z "${!_torv_env_new+x}" ]]; then
    export "$_torv_env_new=${!_torv_env_old}"
    echo "torv: $_torv_env_old is deprecated, use $_torv_env_new" >&2
  fi
done
unset _torv_env_old _torv_env_new

# Use builtin cd: a user cd() that runs ls (e.g. auto-list after cd) breaks $(cd ... && pwd).
_torv_env_here="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TORV_ROOT="${TORV_ROOT:-$(builtin cd "${_torv_env_here}/.." && pwd)}"
_torv_env_project_root="$(builtin cd "${TORV_ROOT}/.." && pwd)"
# Ignore a non-absolute PROJECT_ROOT from the parent shell (e.g. accidental "bin").
if [[ "${PROJECT_ROOT:-}" != /* ]]; then
  PROJECT_ROOT="$_torv_env_project_root"
fi
export PROJECT_ROOT
unset _torv_env_project_root

# Drop stale relative toolchain paths (e.g. PROJECT_ROOT=bin from a broken prior source).
if [[ "${TORV_RISCV_TOOLCHAIN_BIN:-}" != /* ]] \
   || [[ ! -x "${TORV_RISCV_TOOLCHAIN_BIN}/${TORV_RISCV_GNU_PREFIX:-riscv64-unknown-elf-}gcc" ]]; then
  unset TORV_RISCV_TOOLCHAIN_BIN TOOLCHAIN
fi

# =============================================================================
# Site defaults — edit here for your machine (no manual export before source).
# Only fills variables that are not already set in the environment.
# PROJECT_ROOT defaults to the parent of this repo (e.g. .../project).
# =============================================================================

# --- RISC-V bare-metal GNU toolchain (directory must contain ${PREFIX}gcc) ---
# Distro package (Ubuntu: gcc-riscv64-unknown-elf) installs into /usr/bin.
if [[ -z "${TORV_RISCV_TOOLCHAIN_BIN:-}" && ! -x "${PROJECT_ROOT}/riscv_toolchain/bin/riscv64-unknown-elf-gcc" \
      && -x /usr/bin/riscv64-unknown-elf-gcc ]]; then
  TORV_RISCV_TOOLCHAIN_BIN=/usr/bin
fi
: "${TORV_RISCV_TOOLCHAIN_BIN:=${PROJECT_ROOT}/riscv_toolchain/bin}"
# : "${TORV_RISCV_TOOLCHAIN_BIN:=/absolute/path/to/riscv/bin}"
: "${TORV_RISCV_GNU_PREFIX:=riscv64-unknown-elf-}"

# --- Verilator / GTKWave (simulation & waves) ---
: "${TORV_VERILATOR:=verilator}"
: "${TORV_VERILATOR_BIN_DIR:=}"
: "${TORV_GTKWAVE:=gtkwave}"

# --- IHP SG13G2 PDK (SRAM macro models for simulation; LibreLane PDK_ROOT) ---
: "${PDK_ROOT:=${HOME}/.ciel}"

# --- LibreLane (Python venv; runs the flow in its Docker image) ---
: "${LIBRELANE_VENV:=${HOME}/.venv/librelane}"

# CentOS 7 / RHEL: Verilator C++ link often needs a newer g++ (uncomment if needed)
# if [[ -f /opt/rh/devtoolset-11/enable ]]; then
#   # shellcheck source=/dev/null
#   source /opt/rh/devtoolset-11/enable
# fi

# Optional per-machine overrides (gitignored); copy from env.local.sh.example
if [[ -f "${_torv_env_here}/env.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "${_torv_env_here}/env.local.sh"
elif [[ -f "${_torv_env_here}/open_rv.local.sh" ]]; then
  # Pre-v0.8.0 name; remove in v0.9.0
  echo "torv: scripts/open_rv.local.sh is deprecated, rename it to scripts/env.local.sh (TORV_* names)" >&2
  # shellcheck source=/dev/null
  source "${_torv_env_here}/open_rv.local.sh"
  for _torv_env_old in $(compgen -v RV32M_ || true); do
    export "TORV_${_torv_env_old#RV32M_}=${!_torv_env_old}"
  done
  unset _torv_env_old
fi

# ---------------------------------------------------------------------------
# Export (names unchanged — run_case.sh / regress / Makefile rely on these)
# ---------------------------------------------------------------------------
export TORV_RISCV_TOOLCHAIN_BIN="${TORV_RISCV_TOOLCHAIN_BIN:-${PROJECT_ROOT}/riscv_toolchain/bin}"
export TORV_RISCV_GNU_PREFIX="${TORV_RISCV_GNU_PREFIX:-riscv64-unknown-elf-}"
export PDK_ROOT
export LIBRELANE_VENV

export TORV_VERILATOR="${TORV_VERILATOR:-verilator}"
export TORV_VERILATOR_BIN_DIR="${TORV_VERILATOR_BIN_DIR:-}"
export TORV_GTKWAVE="${TORV_GTKWAVE:-gtkwave}"

# Short names used by scripts/internal/*.sh, verilator_build.sh and sim/Makefile
export TOOLCHAIN="$TORV_RISCV_TOOLCHAIN_BIN"
export PREFIX="$TORV_RISCV_GNU_PREFIX"
export VERILATOR="$TORV_VERILATOR"

unset _torv_env_here

torv_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

torv_path_prepend "$TORV_ROOT/scripts"
torv_path_prepend "$TORV_RISCV_TOOLCHAIN_BIN"
[[ -n "$TORV_VERILATOR_BIN_DIR" && -d "$TORV_VERILATOR_BIN_DIR" ]] && torv_path_prepend "$TORV_VERILATOR_BIN_DIR"

export TORV_TARGET="${TORV_TARGET:-soc}"
export TORV_LAST_CASE_DIR_FILE="${TORV_ROOT}/.torv_last_case_build_dir"

t() {
  local f="${TORV_LAST_CASE_DIR_FILE:-$TORV_ROOT/.torv_last_case_build_dir}"
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

echo "TORV env ready:"
echo "  TORV_ROOT=$TORV_ROOT"
echo "  PROJECT_ROOT=$PROJECT_ROOT"
echo "  TORV_RISCV_TOOLCHAIN_BIN=$TORV_RISCV_TOOLCHAIN_BIN"
echo "  TORV_RISCV_GNU_PREFIX=$TORV_RISCV_GNU_PREFIX"
echo "  TORV_VERILATOR=$TORV_VERILATOR ($(command -v "$TORV_VERILATOR" 2>/dev/null || echo missing))"
echo "  TORV_GTKWAVE=$TORV_GTKWAVE ($(command -v "$TORV_GTKWAVE" 2>/dev/null || echo missing))"
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
