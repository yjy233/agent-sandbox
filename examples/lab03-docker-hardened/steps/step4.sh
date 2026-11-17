#!/usr/bin/env bash
# Step 4: 完整验收 + 危险配置检查
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_cmd docker

IMG=alpine:3.20
WS="$LAB_DIR/workspace"; mkdir -p "$WS"; chmod 777 "$WS"
SECRET="$LAB_DIR/fake-secret.txt"
printf 'FAKE-SECRET-DO-NOT-LEAK\n' > "$SECRET"

HARDENED=(docker run --rm
  --network none --read-only
  --tmpfs /tmp:rw,noexec,nosuid,size=32m
  --cap-drop ALL --security-opt no-new-privileges
  --pids-limit 64 --memory 128m --memory-swap 128m --cpus 1.0
  --user 1000:1000 --workdir /workspace
  -v "$WS:/workspace:rw"
  "$IMG")

echo "== Step 4: 完整验收 =="

expect_ok "工作区可写" \
  "${HARDENED[@]}" sh -c 'touch /workspace/step4-ok.txt'
expect_fail "宿主密钥文件不在容器内（未挂载）" \
  "${HARDENED[@]}" sh -c "test -e '$SECRET'"
expect_fail "docker.sock 不可见（绝不能挂载！）" \
  "${HARDENED[@]}" sh -c 'test -e /var/run/docker.sock'
expect_fail "外网不可达" \
  "${HARDENED[@]}" sh -c 'wget -T 3 -q -O- http://1.1.1.1/'
expect_output "本地计算正常" "agent-ok" \
  "${HARDENED[@]}" sh -c 'echo agent-ok'

finish