#!/usr/bin/env bash
# lab05 入口：需要 Linux + /dev/kvm + firecracker + 资产。结束自动清理 VM。
set -eu
LAB_DIR=$(cd "$(dirname "$0")" && pwd)

cleanup() {
  if [[ -f "$LAB_DIR/fc.pid" ]]; then
    kill "$(cat "$LAB_DIR/fc.pid")" 2>/dev/null || true
    rm -f "$LAB_DIR/fc.pid"
  fi
  rm -f /tmp/fc-lab05.sock
}
trap cleanup EXIT

if [[ $(uname -s) != Linux ]]; then
  echo "SKIP: lab05 需要 Linux + KVM（macOS 不支持 Firecracker，见 docs/05 第 4 节）"
  exit 0
fi

for step in "$LAB_DIR"/steps/step*.sh; do
  echo
  bash "$step"
done

echo
echo "lab05 全部步骤通过 ✔（VM 已清理）"