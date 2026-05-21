#!/usr/bin/env bash
# Install GTKWave on CentOS / RHEL 7 (yum + EPEL).
#
#   bash scripts/install_gtkwave_centos7.sh
#
set -euo pipefail

if [[ ! -f /etc/redhat-release ]]; then
  echo "This script targets RHEL/CentOS 7 yum-based installs." >&2
  exit 2
fi

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Run as a normal user; the script uses sudo for yum." >&2
  exit 2
fi

echo "==> Installing EPEL (if needed) and gtkwave..."
sudo yum install -y epel-release
sudo yum install -y gtkwave

echo "==> Done:"
command -v gtkwave
gtkwave --version 2>&1 | head -3 || true
