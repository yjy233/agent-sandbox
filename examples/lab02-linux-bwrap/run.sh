#!/usr/bin/env bash
# lab02 入口：顺序执行 step1..step5，失败即停。需要 Linux + bubblewrap。
set -eu
LAB_DIR=$(cd "$(dirname "$0")" && pwd)

if [[ $(uname -s) != Linux ]]; then
  echo "SKIP: lab02 需要 Linux。macOS 上可先用 Lima 起一个 Linux VM："
  echo "  brew install lima && limactl start template://ubuntu-lts"
  echo "  limactl shell ubuntu-lts"
  echo "  sudo apt-get update && sudo apt-get install -y bubblewrap"
  exit 0
fi

for step in "$LAB_DIR"/steps/step*.sh; do
  echo
  bash "$step"
done

echo
echo "lab02 全部步骤通过 ✔"