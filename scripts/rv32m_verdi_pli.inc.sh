# Source from vcs_build.sh / ahb_toolchain_test.sh (bash).
# Detects Synopsys Verdi / Novas VCS PLI for FSDB ($fsdbDump*).
# On success sets: RV32M_VCS_PLI=( -P <novas.tab> <pli.a> ) and RV32M_FSDB_DEFINE=( +define+RV32M_FSDB )

rv32m_verdi_pli_reset() {
  RV32M_VCS_PLI=()
  RV32M_FSDB_DEFINE=()
}

# Returns 0 if PLI found, 1 if VERDI_HOME set but PLI missing, 0 if unset (no PLI).
rv32m_verdi_pli_detect() {
  rv32m_verdi_pli_reset
  local vh="${VERDI_HOME:-${NOVAS_HOME:-}}"
  if [[ -z "$vh" ]]; then
    return 0
  fi
  local arch tab pli
  for arch in LINUX64 LINUXAMD64; do
    tab="$vh/share/PLI/VCS/$arch/novas.tab"
    pli="$vh/share/PLI/VCS/$arch/pli.a"
    if [[ -f "$tab" && -f "$pli" ]]; then
      RV32M_VCS_PLI=(-P "$tab" "$pli")
      RV32M_FSDB_DEFINE=(+define+RV32M_FSDB)
      echo "rv32m: Verdi FSDB PLI enabled ($vh, $arch)" >&2
      return 0
    fi
  done
  echo "rv32m: VERDI_HOME=$vh but novas.tab/pli.a not found under share/PLI/VCS" >&2
  return 1
}
