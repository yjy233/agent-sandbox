#!/usr/bin/env bash
# Step 4: 断网 —— 验证 socket 被 Seatbelt 拒绝
# 改动：显式 (deny network*)
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_macos
require_cmd sandbox-exec python3

P="$LAB_DIR/profiles/step4-no-network.sb"
WS="$LAB_DIR/workspace"; mkdir -p "$WS"
SB=(sandbox-exec -D "WORKSPACE=$WS" -f "$P")

NET_PY='import socket; socket.create_connection(("1.1.1.1", 443), timeout=3); print("CONNECTED")'

echo "== Step 4: 断网 =="

expect_fail "沙箱内 TCP 连接 1.1.1.1:443 失败" \
  "${SB[@]}" /usr/bin/python3 -c "$NET_PY"
expect_no_output "失败时绝不能出现 CONNECTED" "CONNECTED" \
  "${SB[@]}" /usr/bin/python3 -c "$NET_PY"
expect_ok "本地计算不受影响 (python3 print)" \
  "${SB[@]}" /usr/bin/python3 -c 'print(1+1)'

finish