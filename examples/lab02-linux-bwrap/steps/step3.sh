#!/usr/bin/env bash
# Step 3: 文件系统视图裁剪 —— 宿主目录直接"不可见"（比拒绝更强）
# 改动：不再 ro-bind /，只 bind 系统目录
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd bwrap

WS="$LAB_DIR/workspace"; mkdir -p "$WS"
BW=(bwrap
    --ro-bind /usr /usr
    --ro-bind /bin /bin
    --ro-bind /sbin /sbin
    --ro-bind /lib /lib
    --symlink usr/lib /lib64
    --ro-bind /etc /etc
    --bind "$WS" /workspace
    --proc /proc --dev /dev --tmpfs /tmp
    --chdir /workspace --unshare-pid --die-with-parent)

echo "== Step 3: 宿主目录不可见 =="

expect_fail "/home 在沙箱内不存在" \
  "${BW[@]}" /bin/sh -c 'test -e /home'
expect_fail "/root 在沙箱内不存在" \
  "${BW[@]}" /bin/sh -c 'test -e /root'
expect_ok "工作区仍然可写" \
  "${BW[@]}" /bin/sh -c 'touch /workspace/step3-ok.txt'
expect_ok "系统工具仍可用 (ls /usr)" \
  "${BW[@]}" /bin/sh -c 'ls /usr >/dev/null'

finish