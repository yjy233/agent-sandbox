#!/usr/bin/env bash
# lab03 入口：需要 docker（Linux 原生，或 macOS 上的 Docker Desktop/Colima）。
set -eu
LAB_DIR=$(cd "$(dirname "$0")" && pwd)

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: 缺少 docker。安装建议："
  echo "  macOS: brew install --cask docker  （或 brew install colima docker && colima start）"
  echo "  Linux: 发行版 docker.io / docker-ce 包"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon 未运行（先启动 Docker Desktop / colima / dockerd）"
  exit 0
fi

for step in "$LAB_DIR"/steps/step*.sh; do
  echo
  bash "$step"
done

echo
echo "lab03 全部步骤通过 ✔"