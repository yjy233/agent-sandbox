#!/usr/bin/env bash
# Step 2: dmesg 暴露身份 —— gVisor 的"内核日志"
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd docker

IMG=alpine:3.20

echo "== Step 2: runsc 内的 dmesg =="
docker run --rm --runtime=runsc "$IMG" dmesg 2>&1 | head -5 | sed 's/^/  /'

expect_output "dmesg 中出现 gVisor 标识" "gVisor" \
  docker run --rm --runtime=runsc "$IMG" dmesg

finish