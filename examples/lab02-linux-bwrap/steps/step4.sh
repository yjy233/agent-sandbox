#!/usr/bin/env bash
# Step 4: 网络隔离 —— --unshare-net 后只有 down 的 lo
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd bwrap

WS="$LAB_DIR/workspace"; mkdir -p "$WS"
BW=(bwrap
    --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /sbin /sbin
    --ro-bind /lib /lib --symlink usr/lib /lib64 --ro-bind /etc /etc
    --bind "$WS" /workspace
    --proc /proc --dev /dev --tmpfs /tmp
    --chdir /workspace --unshare-pid --unshare-net --die-with-parent)

echo "== Step 4: 断网 =="

# bash 内建 /dev/tcp，无需 python/curl
expect_fail "TCP 连接 1.1.1.1:443 失败" \
  "${BW[@]}" /bin/bash -c 'exec 3<>/dev/tcp/1.1.1.1/443'
expect_ok "本地计算正常" \
  "${BW[@]}" /bin/bash -c 'echo $((40+2))'

finish