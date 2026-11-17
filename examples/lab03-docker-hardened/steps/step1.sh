#!/usr/bin/env bash
# Step 1: 默认容器的暴露面 —— 看看"裸 docker run"给了什么
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_cmd docker

IMG=alpine:3.20

echo "== Step 1: 默认容器暴露面 =="
echo "演示: 默认容器内 id / 设备数 / 路由"
docker run --rm "$IMG" sh -c 'id; echo "dev entries: $(ls /dev | wc -l)"; cat /proc/net/route' 2>&1 | sed 's/^/  /'

expect_output "默认容器内是 root" "uid=0(root)" \
  docker run --rm "$IMG" id
expect_output "默认有非 lo 路由（可出网）" "eth0" \
  docker run --rm "$IMG" cat /proc/net/route

finish