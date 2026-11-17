#!/usr/bin/env bash
# Step 1: PID namespace —— 沙箱内看不到宿主进程
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd bwrap

echo "== Step 1: PID namespace =="
echo "演示: 沙箱内 echo \$\$（自己的 PID）"
bwrap --ro-bind / / --proc /proc --dev /dev --unshare-pid --die-with-parent \
  /bin/sh -c 'echo $$' 2>&1 | sed 's/^/  /'

PID=$(bwrap --ro-bind / / --proc /proc --dev /dev --unshare-pid --die-with-parent \
  /bin/sh -c 'echo $$' 2>/dev/null)
if [[ "$PID" =~ ^[0-9]+$ ]] && (( PID <= 5 )); then
  _ok "沙箱内 shell 的 PID=$PID（新 PID 空间，而非宿主的大 PID）"
else
  _fail "沙箱内 PID=$PID，期望 <=5"
fi

expect_ok "沙箱内 /proc 已挂载" \
  bwrap --ro-bind / / --proc /proc --dev /dev --unshare-pid --die-with-parent \
  /bin/sh -c 'test -d /proc/1'

finish