#!/usr/bin/env bash
# lab04 入口：需要 Linux + docker + runsc（gVisor）。
set -eu
LAB_DIR=$(cd "$(dirname "$0")" && pwd)

if [[ $(uname -s) != Linux ]]; then
  echo "SKIP: lab04 需要 Linux（gVisor 不支持 macOS）。可在 Lima VM 内做 lab02/03，"
  echo "      但 runsc 需要 VM 内再装 docker + runsc，见 README。"
  exit 0
fi
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: 需要运行中的 docker"
  exit 0
fi
if ! docker info 2>/dev/null | grep -q runsc; then
  echo "SKIP: docker 未注册 runsc runtime。安装："
  echo "  curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg"
  echo "  echo 'deb [signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main' | sudo tee /etc/apt/sources.list.d/gvisor.list"
  echo "  sudo apt update && sudo apt install -y runsc"
  echo "  sudo runsc install && sudo systemctl restart docker"
  exit 0
fi

for step in "$LAB_DIR"/steps/step*.sh; do
  echo
  bash "$step"
done

echo
echo "lab04 全部步骤通过 ✔"