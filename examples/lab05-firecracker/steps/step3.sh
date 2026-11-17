#!/usr/bin/env bash
# Step 3: 暂停 + 打快照（E2B 式"秒开沙箱"的核心）
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
source "$LAB_DIR/scripts/fc-lib.sh"
require_linux

export FC_SOCK=/tmp/fc-lab05.sock
SNAP="$LAB_DIR/snapshot"; mkdir -p "$SNAP"

echo "== Step 3: 快照 =="

fc_api PATCH /vm '{"state":"Paused"}' >/dev/null
expect_output "VM 已暂停" 'Paused' fc_api GET /

fc_api PUT /snapshot/create "{\"snapshot_type\":\"Full\",\"snapshot_path\":\"$SNAP/vmstate\",\"mem_file_path\":\"$SNAP/mem\"}" >/dev/null

expect_ok "vmstate 文件已生成" test -s "$SNAP/vmstate"
expect_ok "内存快照文件已生成" test -s "$SNAP/mem"

finish