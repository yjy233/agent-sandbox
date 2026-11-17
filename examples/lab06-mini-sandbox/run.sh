#!/usr/bin/env bash
# lab06 入口：python3 -m unittest。平台不符的后端用例自动 skip。
set -eu
LAB_DIR=$(cd "$(dirname "$0")" && pwd)

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: 缺少 python3"
  exit 0
fi

cd "$LAB_DIR"
python3 -m unittest test_sandbox -v
echo
echo "lab06 测试完成 ✔"