#!/usr/bin/env bash
# Step 4: 杀掉旧 VM，从快照恢复一个新 VM —— 体会毫秒级冷启动
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
source "$LAB_DIR/scripts/fc-lib.sh"
require_linux

SNAP="$LAB_DIR/snapshot"
export FC_SOCK=/tmp/fc-lab05.sock

echo "== Step 4: 快照恢复 =="

# 清理旧实例
[[ -f "$LAB_DIR/fc.pid" ]] && kill "$(cat "$LAB_DIR/fc.pid")" 2>/dev/null
rm -f "$FC_SOCK"
sleep 0.3

firecracker --api-sock "$FC_SOCK" --log-path "$LAB_DIR/fc-restore.log" --level Info &
FC_PID=$!
sleep 0.5

T0=$(date +%s%N)
fc_api PUT /snapshot/load "{\"snapshot_path\":\"$SNAP/vmstate\",\"mem_backend\":{\"backend_type\":\"File\",\"backend_path\":\"$SNAP/mem\"},\"enable_diff_snapshots\":false}" >/dev/null
fc_api PATCH /vm '{"state":"Resumed"}' >/dev/null
T1=$(date +%s%N)
echo "  快照恢复+resume 耗时: $(( (T1 - T0) / 1000000 )) ms"

expect_output "恢复后 VM 状态 Running" 'Running' fc_api GET /
expect_ok "新 VM 进程存活" kill -0 "$FC_PID"

echo "$FC_PID" > "$LAB_DIR/fc.pid"
finish