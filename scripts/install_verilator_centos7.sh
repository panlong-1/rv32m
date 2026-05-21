#!/usr/bin/env bash
# Install Verilator 5.x on CentOS / RHEL 7 (outside nix-shell).
#
# System GCC 4.8 cannot build Verilator 5. This script installs SCL
# devtoolset-11 (newer g++), build deps, then builds Verilator from a
# GitHub source tag (autoconf + configure + make).
#
# Run in a real TTY (sudo password):
#   bash scripts/install_verilator_centos7.sh
#
# Optional:
#   VERILATOR_VERSION=5.028 bash scripts/install_verilator_centos7.sh
#   VERILATOR_PREFIX=/opt/verilator bash scripts/install_verilator_centos7.sh
#   VERILATOR_PREFIX="$HOME/.local" bash scripts/install_verilator_centos7.sh   # no sudo for install
#
set -euo pipefail

VERILATOR_VERSION="${VERILATOR_VERSION:-5.028}"
VERILATOR_PREFIX="${VERILATOR_PREFIX:-/usr/local}"
WORKDIR="${WORKDIR:-/tmp/verilator-build-$$}"

if [[ ! -f /etc/redhat-release ]]; then
  echo "This script targets RHEL/CentOS family. For other distros, use the distro package or build from source." >&2
  exit 2
fi

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Do not run this script as root for the whole run; it will use sudo only where needed." >&2
  exit 2
fi

need_sudo() {
  if [[ "$VERILATOR_PREFIX" != "$HOME"/* && "$VERILATOR_PREFIX" != /tmp/* ]]; then
    return 0
  fi
  return 1
}

echo "==> OS:"
cat /etc/redhat-release

echo "==> Installing packages (sudo)..."
sudo yum install -y \
  centos-release-scl \
  centos-release-scl-rh \
  scl-utils \
  git wget curl tar patch \
  autoconf automake libtool \
  flex bison \
  perl perl-Data-Dumper \
  zlib-devel \
  help2man

# devtoolset-11 is preferred for Verilator 5; fall back if mirror lacks it.
if ! sudo yum install -y devtoolset-11-gcc devtoolset-11-gcc-c++ devtoolset-11-binutils devtoolset-11-make; then
  echo "WARN: devtoolset-11 not available; trying devtoolset-9..." >&2
  sudo yum install -y devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-binutils devtoolset-9-make
  DTS_VER=9
else
  DTS_VER=11
fi

# shellcheck source=/dev/null
source "/opt/rh/devtoolset-${DTS_VER}/enable"

echo "==> Compiler for build:"
which gcc g++
gcc --version | head -1

mkdir -p "$WORKDIR"
cd "$WORKDIR"
TAG="v${VERILATOR_VERSION}"
TGZ="verilator-${VERILATOR_VERSION}.tar.gz"
URL="https://github.com/verilator/verilator/archive/refs/tags/${TAG}.tar.gz"

echo "==> Downloading ${URL}"
rm -rf "verilator-${VERILATOR_VERSION}"
wget -q -O "$TGZ" "$URL"
tar xf "$TGZ"
cd "verilator-${VERILATOR_VERSION}"

echo "==> autoconf + configure (prefix=$VERILATOR_PREFIX)"
autoconf
./configure --prefix="$VERILATOR_PREFIX"

echo "==> make (parallel)"
make -j"$(nproc)"

if [[ ! -x "./bin/verilator" ]]; then
  echo "ERROR: build did not produce ./bin/verilator (see errors above)." >&2
  echo "Build tree kept at: $(pwd)" >&2
  exit 1
fi

if need_sudo; then
  echo "==> sudo make install (you may be prompted for password)"
  sudo make install
else
  echo "==> make install (user prefix, no sudo)"
  make install
fi

if [[ ! -x "$VERILATOR_PREFIX/bin/verilator" ]]; then
  echo "ERROR: $VERILATOR_PREFIX/bin/verilator missing after make install." >&2
  echo "If sudo was skipped or failed, run manually:" >&2
  echo "  source /opt/rh/devtoolset-${DTS_VER}/enable" >&2
  echo "  cd $(pwd)" >&2
  echo "  sudo make install" >&2
  echo "Build tree kept at: $WORKDIR (not removed due to error)." >&2
  exit 1
fi

echo
echo "Installed Verilator under: $VERILATOR_PREFIX"
echo "Add to ~/.bashrc (adjust if you used a custom prefix):"
echo "  export PATH=$VERILATOR_PREFIX/bin:\$PATH"
echo
"$VERILATOR_PREFIX/bin/verilator" --version

rm -rf "$WORKDIR"
echo "Done."
