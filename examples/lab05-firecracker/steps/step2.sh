#!/usr/bin/env bash
# Step 2: 通过 API 启动一个最小 microVM
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
source "$LAB_DIR/scripts/fc-lib.sh"
require_linux

ASSETS="$LAB_DIR/assets"
export FC_SOCK=/tmp/fc-lab05.sock

echo "== Step 2: 启动 microVM =="

firecracker --api-sock "$FC_SOCK" --log-path "$LAB_DIR/fc.log" --level Info &
FC_PID=$!
sleep 0.5

fc_api PUT /boot-source "{\"kernel_image_path\":\"$ASSETS/vmlinux.bin\",\"boot_args\":\"console=ttyS0 reboot=k panic=1 pci=off\"}" >/dev/null
fc_api PUT /drives/rootfs "{\"drive_id\":\"rootfs\",\"path_on_host\":\"$ASSETS/rootfs.ext4\",\"is_root_device\":true,\"is_read_only\":false}" >/dev/null
fc_api PUT /machine-config '{"vcpu_count":2,"mem_size_mib":256}' >/dev/null
fc_api PUT /actions '{"action_type":"InstanceStart"}' >/dev/null
sleep 1

expect_ok "VM 进程存活" kill -0 "$FC_PID"
CFG=$(fc_api GET /machine-config)
expect_output "API 返回 vcpu 配置" '"vcpu_count":2' echo "$CFG"
expect_output "VM 状态为 Running" 'Running' fc_api GET /

echo "$FC_PID" > "$LAB_DIR/fc.pid"
finish