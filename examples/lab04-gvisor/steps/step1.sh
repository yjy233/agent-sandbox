#!/usr/bin/env bash
# Step 1: runsc vs runc —— 内核版本不一样了
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd docker

IMG=alpine:3.20

echo "== Step 1: 两个 runtime 的内核视图 =="
K_RUNC=$(docker run --rm "$IMG" uname -r)
K_RUNSC=$(docker run --rm --runtime=runsc "$IMG" uname -r)
echo "  runc  uname -r: $K_RUNC"
echo "  runsc uname -r: $K_RUNSC"

if [[ "$K_RUNC" != "$K_RUNSC" ]]; then
  _ok "runsc 报告的内核与宿主不同（用户态内核生效）"
else
  _fail "runsc 与 runc 内核版本相同（runsc 未生效？）"
fi

finish