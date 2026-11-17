#!/usr/bin/env bash
# lab01 入口：按顺序执行 step1..step5，任何一步测试失败立即停止（做一点测一点）
set -eu
LAB_DIR=$(cd "$(dirname "$0")" && pwd)

for step in "$LAB_DIR"/steps/step*.sh; do
  echo
  bash "$step"
done

echo
echo "lab01 全部步骤通过 ✔"