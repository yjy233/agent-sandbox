#!/usr/bin/env bash
# 下载 Firecracker quickstart 资产（kernel + rootfs）
set -eu
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
ASSETS="$LAB_DIR/assets"; mkdir -p "$ASSETS"
ARCH=$(uname -m)
BASE="https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/$ARCH"

for f in vmlinux.bin rootfs.ext4; do
  if [[ ! -f "$ASSETS/$f" ]]; then
    echo "下载 $f ($ARCH)..."
    curl -fsSL "$BASE/$f" -o "$ASSETS/$f"
  fi
done
echo "资产就绪: $ASSETS"