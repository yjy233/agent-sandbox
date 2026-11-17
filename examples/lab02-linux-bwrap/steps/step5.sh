#!/usr/bin/env bash
# Step 5: 完整 Agent 沙箱 —— unshare-all + 视图裁剪 + 工作区 + 会话隔离
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd bwrap

WS="$LAB_DIR/workspace"; mkdir -p "$WS"
SECRET="$LAB_DIR/fake-secret.txt"
printf 'FAKE-SECRET-DO-NOT-LEAK\n' > "$SECRET"

BW=(bwrap
    --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /sbin /sbin
    --ro-bind /lib /lib --symlink usr/lib /lib64
    --ro-bind /etc /etc
    --bind "$WS" /workspace
    --proc /proc --dev /dev --tmpfs /tmp
    --chdir /workspace
    --unshare-all --die-with-parent --new-session)

echo "== Step 5: 完整 Agent 沙箱验收 =="

expect_ok "工作区可写" \
  "${BW[@]}" /bin/sh -c 'touch /workspace/step5-ok.txt'
expect_fail "宿主密钥文件不可见（lab 目录未 bind）" \
  "${BW[@]}" /bin/sh -c "test -e '$SECRET'"
expect_fail "外网不可达" \
  "${BW[@]}" /bin/bash -c 'exec 3<>/dev/tcp/1.1.1.1/443'
expect_fail "/home 不可见" \
  "${BW[@]}" /bin/sh -c 'test -e /home'
expect_ok "沙箱内可正常执行计算" \
  "${BW[@]}" /bin/sh -c 'echo agent-ok'

finish