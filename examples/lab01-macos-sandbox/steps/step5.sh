#!/usr/bin/env bash
# Step 5: 完整 Agent profile —— 读收紧 + 写收紧 + 断网 + 信号限制
# 验收：工作区内正常干活；密钥文件不可读；外网不可达；工作区外不可写。
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_macos
require_cmd sandbox-exec python3

P="$LAB_DIR/profiles/step5-agent.sb"
WS="$LAB_DIR/workspace"; mkdir -p "$WS"
SB=(sandbox-exec -D "WORKSPACE=$WS" -f "$P")

# 工作区之外的"假密钥"，模拟 ~/.ssh/id_rsa
SECRET="$LAB_DIR/fake-secret.txt"
printf 'FAKE-SECRET-DO-NOT-LEAK\n' > "$SECRET"

NET_PY='import socket; socket.create_connection(("1.1.1.1", 443), timeout=3); print("CONNECTED")'

echo "== Step 5: 完整 Agent profile 验收 =="

expect_ok "工作区内可写 (touch)" \
  "${SB[@]}" /usr/bin/touch "$WS/step5-ok.txt"
expect_ok "工作区内可读写 (python 写文件)" \
  "${SB[@]}" /usr/bin/python3 -c "open('$WS/step5-py.txt','w').write('ok')"
expect_fail "工作区外不可写 (/tmp)" \
  "${SB[@]}" /usr/bin/touch "/tmp/agent-sandbox-step5-should-fail.txt"
expect_fail "工作区外的密钥文件不可读" \
  "${SB[@]}" /bin/cat "$SECRET"
expect_no_output "密钥内容绝不出现在沙箱输出中" "FAKE-SECRET" \
  "${SB[@]}" /bin/cat "$SECRET"
expect_fail "外网不可达" \
  "${SB[@]}" /usr/bin/python3 -c "$NET_PY"
expect_ok "沙箱内 python 正常运行" \
  "${SB[@]}" /usr/bin/python3 -c 'print("agent-ok")'

finish