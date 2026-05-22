#!/usr/bin/env bash
# Download third-party IP tarballs (git https may be unavailable on some hosts).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="$ROOT/ip/third_party"

fetch_tar() {
  local name="$1"
  local url="$2"
  local topdir="$3"
  local dest="$TP/$name"
  if [[ -d "$dest" && -f "$dest/LICENSE" ]]; then
    echo "OK: $dest already present"
    return 0
  fi
  echo "Fetching $url ..."
  mkdir -p "$TP"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/src.tar.gz" "$url"
  tar xzf "$tmp/src.tar.gz" -C "$tmp"
  rm -rf "$dest"
  mv "$tmp/$topdir" "$dest"
  rm -rf "$tmp"
  echo "Installed: $dest"
}

fetch_tar apb_uart_sv \
  "https://github.com/pulp-platform/apb_uart_sv/archive/refs/heads/pulpinov1.tar.gz" \
  "apb_uart_sv-pulpinov1"

fetch_tar socbus \
  "https://github.com/shalan/SoCBUS/archive/refs/heads/main.tar.gz" \
  "SoCBUS-main"

# SoCBUS includes use paths relative to repo root; normalize for -I include/.
if [[ -f "$TP/socbus/rtl/AHB_APB_BRIDGE.v" ]]; then
  sed -i 's|`include[[:space:]]*"./include/|`include "|g' "$TP/socbus/rtl/AHB_APB_BRIDGE.v"
fi
# Verilator cannot parse the incomplete AHB_SYS_EPILOGUE tail in upstream ahb_util.vh;
# the bridge only needs macros through AHB_SLAVE_EPILOGUE.
if [[ -f "$TP/socbus/include/ahb_util.vh" ]]; then
  sed -i '159,$d' "$TP/socbus/include/ahb_util.vh"
fi
# Verilator: internal regs must not collide with APB_MASTER_IFC output ports.
if [[ -f "$TP/socbus/rtl/AHB_APB_BRIDGE.v" ]] && ! grep -q penable_r "$TP/socbus/rtl/AHB_APB_BRIDGE.v"; then
  sed -i 's/reg         PENABLE;/reg         penable_r;/' "$TP/socbus/rtl/AHB_APB_BRIDGE.v"
  sed -i 's/reg \[31:0\]  PADDR;/reg [31:0]  paddr_r;/' "$TP/socbus/rtl/AHB_APB_BRIDGE.v"
  sed -i 's/reg         PWRITE;/reg         pwrite_r;/' "$TP/socbus/rtl/AHB_APB_BRIDGE.v"
  sed -i '/reg         pwrite_r;/a\
\
    assign PENABLE = penable_r;\
    assign PADDR   = paddr_r;\
    assign PWRITE  = pwrite_r;
' "$TP/socbus/rtl/AHB_APB_BRIDGE.v"
  sed -i 's/PADDR <=/paddr_r <=/g' "$TP/socbus/rtl/AHB_APB_BRIDGE.v"
  sed -i 's/PENABLE <=/penable_r <=/g' "$TP/socbus/rtl/AHB_APB_BRIDGE.v"
  sed -i 's/PWRITE <=/pwrite_r <=/g' "$TP/socbus/rtl/AHB_APB_BRIDGE.v"
fi

echo "Third-party IP ready under $TP"
