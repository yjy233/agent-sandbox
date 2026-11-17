#!/usr/bin/env bash
# Step 1: 环境检查 —— KVM / firecracker / 资产
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux

echo "== Step 1: 环境检查 =="

if [[ ! -e /dev/kvm ]]; then
  echo "SKIP: 无 /dev/kvm。需要裸机 Linux 或支持嵌套虚拟化的云 VM。"
  echo "      macOS 无法直接运行 Firecracker（见 docs/05 第 4 节）。"
  exit 0
fi
require_cmd firecracker curl

ASSETS="$LAB_DIR/assets"
if [[ ! -f "$ASSETS/vmlinux.bin" || ! -f "$ASSETS/rootfs.ext4" ]]; then
  echo "资产缺失，先运行: bash scripts/fetch-assets.sh"
  exit 1
fi

_ok "/dev/kvm 可用"
_ok "firecracker 已安装"
_ok "kernel + rootfs 资产就绪"

finish