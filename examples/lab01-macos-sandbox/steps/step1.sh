#!/usr/bin/env bash
# Step 1: deny default —— 体会"默认拒绝一切"
# 知识点：Seatbelt 规则在 exec 之前就生效，连程序加载都被拒绝。
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_macos
require_cmd sandbox-exec

P="$LAB_DIR/profiles/step1-deny-all.sb"

echo "== Step 1: deny default =="
echo "演示: sandbox-exec -f step1-deny-all.sb /usr/bin/true"
sandbox-exec -f "$P" /usr/bin/true 2>&1 | sed 's/^/  /'

expect_fail "deny default 下连 /usr/bin/true 都无法执行" \
  sandbox-exec -f "$P" /usr/bin/true
expect_output "失败原因是 Operation not permitted" "Operation not permitted" \
  sandbox-exec -f "$P" /usr/bin/true

finish