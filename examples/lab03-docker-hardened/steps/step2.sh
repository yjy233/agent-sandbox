#!/usr/bin/env bash
# Step 2: 加固模板 —— 非 root + 只读根 + 断网 + 去 capabilities
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_cmd docker

IMG=alpine:3.20
WS="$LAB_DIR/workspace"; mkdir -p "$WS"; chmod 777 "$WS"

HARDENED=(docker run --rm
  --network none
  --read-only
  --tmpfs /tmp:rw,noexec,nosuid,size=32m
  --cap-drop ALL
  --security-opt no-new-privileges
  --pids-limit 64
  --memory 128m --memory-swap 128m
  --cpus 1.0
  --user 1000:1000
  --workdir /workspace
  -v "$WS:/workspace:rw"
  "$IMG")

echo "== Step 2: 加固容器 =="

expect_output "容器内不再是 root" "uid=1000" \
  "${HARDENED[@]}" id
expect_ok "工作区可写" \
  "${HARDENED[@]}" sh -c 'touch /workspace/step2-ok.txt'
expect_fail "根文件系统只读 (/etc 不可写)" \
  "${HARDENED[@]}" sh -c 'touch /etc/should-fail'
expect_fail "断网：wget 1.1.1.1 失败" \
  "${HARDENED[@]}" sh -c 'wget -T 3 -q -O- http://1.1.1.1/'

finish