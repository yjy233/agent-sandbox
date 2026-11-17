#!/usr/bin/env bash
# Step 2: 放行最小执行集合 —— 程序能跑，但写仍被拒绝
# 改动：+process-exec/fork +file-read* +sysctl-read
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_macos
require_cmd sandbox-exec

P="$LAB_DIR/profiles/step2-can-run.sb"
WS="$LAB_DIR/workspace"; mkdir -p "$WS"

echo "== Step 2: 最小执行集合 =="
echo "演示: 沙箱内 echo hello"
sandbox-exec -f "$P" /bin/echo hello 2>&1 | sed 's/^/  /'

expect_output "沙箱内 echo 正常输出" "hello" \
  sandbox-exec -f "$P" /bin/echo hello
expect_ok "沙箱内可以读系统文件 (cat /etc/hosts)" \
  sandbox-exec -f "$P" /bin/cat /etc/hosts
expect_fail "写仍被拒绝：touch 工作区文件失败" \
  sandbox-exec -f "$P" /usr/bin/touch "$WS/step2-should-fail.txt"

finish