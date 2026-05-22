#!/usr/bin/env bash
# Emit work/<case>/open_verdi.sh for Verdi: RTL filelist + optional VCD/FSDB + optional KDB dbdir.
set -euo pipefail
BUILD_DIR="${1:?}"
NAME="${2:?}"
ROOT="${3:?}"
TOP="${4:-tb_torv_soc}"
FLIST_REL="${5:-sim/filelists/verdi_soc.f}"

OUT="$BUILD_DIR/open_verdi.sh"
cat >"$OUT" <<EOF
#!/usr/bin/env bash
set -euo pipefail
HERE="\$(cd "\$(dirname "\$0")" && pwd)"
ROOT="$ROOT"
cd "\$ROOT"
if [[ -f "\$ROOT/regress/env.sh" ]]; then
  # shellcheck disable=SC1091
  source "\$ROOT/regress/env.sh" >/dev/null 2>&1 || true
fi
ARGS=(verdi -nologo -sv -f "\$ROOT/$FLIST_REL" -top "$TOP")
if [[ -d "\$HERE/vcs/simv.daidir" ]]; then
  ARGS+=(-dbdir "\$HERE/vcs/simv.daidir")
fi
if [[ -f "\$HERE/${NAME}.fsdb" ]]; then
  ARGS+=(-ssf "\$HERE/${NAME}.fsdb")
elif [[ -f "\$HERE/${NAME}.vcd" ]]; then
  ARGS+=(-vcd "\$HERE/${NAME}.vcd")
fi
exec "\${ARGS[@]}"
EOF
chmod +x "$OUT"
echo "Wrote $OUT (cd $BUILD_DIR && ./open_verdi.sh)"
