#!/usr/bin/env bash
# 顺序运行所有 lab。环境不满足的 lab 自动 SKIP，不算失败。
set -eu
EXAMPLES_DIR=$(cd "$(dirname "$0")" && pwd)

for lab in "$EXAMPLES_DIR"/lab*/run.sh; do
  echo
  echo "============================================================"
  echo ">>> $(basename "$(dirname "$lab")")"
  echo "============================================================"
  bash "$lab"
done

echo
echo "全部 lab 执行完毕（SKIP 的 lab 见各自 README 的环境准备）"