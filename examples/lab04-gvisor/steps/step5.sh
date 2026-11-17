#!/usr/bin/env bash
# Step 5: runsc + 加固参数 —— 容器体验不变，隔离升级
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_linux
require_cmd docker

IMG=alpine:3.20
WS="$LAB_DIR/workspace"; mkdir -p "$WS"; chmod 777 "$WS"

HARDENED=(docker run --rm --runtime=runsc
  --network none --read-only
  --tmpfs /tmp:rw,noexec,nosuid,size=32m
  --cap-drop ALL --security-opt no-new-privileges
  --pids-limit 64 --memory 256m --cpus 1.0
  --user 1000:1000 --workdir /workspace
  -v "$WS:/workspace:rw"
  "$IMG")

echo "== Step 5: runsc 加固验收 =="

expect_ok "工作区可写" \
  "${HARDENED[@]}" sh -c 'touch /workspace/step5-ok.txt'
expect_fail "外网不可达" \
  "${HARDENED[@]}" sh -c 'wget -T 3 -q -O- http://1.1.1.1/'
expect_output "业务命令正常" "agent-ok" \
  "${HARDENED[@]}" sh -c 'echo agent-ok'

finish