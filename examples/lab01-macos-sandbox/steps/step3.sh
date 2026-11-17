#!/usr/bin/env bash
# Step 3: 写限制到工作区 —— Agent 沙箱的核心规则
# 改动：+file-write* (subpath WORKSPACE)，用 -D 传参
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_macos
require_cmd sandbox-exec

P="$LAB_DIR/profiles/step3-workspace-write.sb"
WS="$LAB_DIR/workspace"; mkdir -p "$WS"
SB=(sandbox-exec -D "WORKSPACE=$WS" -f "$P")

echo "== Step 3: 工作区可写，其余不可写 =="

expect_ok "工作区内 touch 成功" \
  "${SB[@]}" /usr/bin/touch "$WS/step3-ok.txt"
expect_fail "工作区外 (/tmp) touch 失败" \
  "${SB[@]}" /usr/bin/touch "/tmp/agent-sandbox-step3-should-fail.txt"
expect_fail "工作区外 (HOME) 写文件失败" \
  "${SB[@]}" /usr/bin/touch "$HOME/agent-sandbox-step3-should-fail.txt"
expect_ok "读不受影响：cat 工作区文件" \
  "${SB[@]}" /bin/cat "$WS/step3-ok.txt"

finish