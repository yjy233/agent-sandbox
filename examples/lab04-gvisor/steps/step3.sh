#!/usr/bin/env bash
# Step 3: 兼容性探测 —— 哪些操作在 gVisor 下行为不同（报告型，不强制断言）
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd docker

IMG=alpine:3.20

echo "== Step 3: 兼容性探测（runc vs runsc）=="
printf '  %-28s %-12s %-12s\n' "probe" "runc" "runsc"

probe() {
  local name=$1 cmd=$2
  local a b
  if docker run --rm "$IMG" sh -c "$cmd" >/dev/null 2>&1; then a=OK; else a=FAIL; fi
  if docker run --rm --runtime=runsc "$IMG" sh -c "$cmd" >/dev/null 2>&1; then b=OK; else b=FAIL; fi
  printf '  %-28s %-12s %-12s\n' "$name" "$a" "$b"
}

probe "basic shell"        'echo ok'
probe "read /proc/cpuinfo" 'cat /proc/cpuinfo >/dev/null'
probe "unshare( userns )"  'unshare -U true'
probe "mount tmpfs"        'mount -t tmpfs none /mnt'
probe "mknod"              'mknod /tmp/x c 1 3'
probe "ptrace self"        'strace -f true'   # alpine 无 strace 时两边都 FAIL，属预期

echo "  （FAIL/FAIL 通常是工具缺失；OK/FAIL 才是 gVisor 兼容性差异）"
_ok "兼容性报告已生成（人工审阅差异项）"

finish