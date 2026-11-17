#!/usr/bin/env bash
# Step 2: 只读根 + 可写工作区
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd bwrap

WS="$LAB_DIR/workspace"; mkdir -p "$WS"
BW=(bwrap --ro-bind / / --bind "$WS" /workspace --proc /proc --dev /dev
    --chdir /workspace --die-with-parent)

echo "== Step 2: 只读根 + 可写工作区 =="

expect_ok "工作区内可写" \
  "${BW[@]}" /bin/sh -c 'touch /workspace/step2-ok.txt'
expect_fail "系统目录不可写 (/etc)" \
  "${BW[@]}" /bin/sh -c 'touch /etc/agent-sandbox-should-fail'
expect_fail "宿主 HOME 不可写" \
  "${BW[@]}" /bin/sh -c 'touch "$HOME/agent-sandbox-should-fail"'

finish