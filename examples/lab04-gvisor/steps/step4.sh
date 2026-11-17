#!/usr/bin/env bash
# Step 4: 性能对比 —— 文件 IO 密集负载的开销（报告型）
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd docker

IMG=alpine:3.20
CMD='time dd if=/dev/zero of=/tmp/f bs=1M count=256 2>&1; rm -f /tmp/f'

echo "== Step 4: dd 256MB 写 /tmp 耗时对比 =="
echo "  --- runc ---"
docker run --rm "$IMG" sh -c "$CMD" 2>&1 | sed 's/^/  /'
echo "  --- runsc ---"
docker run --rm --runtime=runsc "$IMG" sh -c "$CMD" 2>&1 | sed 's/^/  /'

_ok "性能数据已输出（runsc 通常更慢，差距即用户态内核+Gofer 的代价）"

finish