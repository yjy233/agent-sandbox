# Lab 05 · Firecracker microVM（需 Linux + KVM）

对应文档：[docs/05 虚拟机与 MicroVM](../../docs/05-vm.md)。

## 目标

亲手走一遍 E2B/Lambda 的底层流程：**API 启动 microVM → 暂停打快照 → 从快照毫秒级恢复**。

## 环境要求

- Linux 且 `/dev/kvm` 可用（裸机，或支持嵌套虚拟化的云实例；macOS 不行）
- `firecracker` 二进制（[官方 release](https://github.com/firecracker-microvm/firecracker/releases) 下载后放入 PATH）
- kernel + rootfs 资产：

```bash
bash examples/lab05-firecracker/scripts/fetch-assets.sh   # 从官方 quickstart S3 下载
bash examples/lab05-firecracker/run.sh
```

## 步骤设计

| 步骤 | 内容 | 验证点 |
|------|------|--------|
| step1 | 环境检查 | /dev/kvm、firecracker、资产齐备（缺则 SKIP） |
| step2 | REST API 配置并启动 VM | 进程存活；GET / 返回 Running |
| step3 | Paused + Full 快照 | vmstate 与 mem 文件非空 |
| step4 | 杀旧 VM，从快照 load+resume | 恢复耗时（毫秒级）；状态 Running |

结束自动 kill VM、清理 socket（trap EXIT）。

## 安全提醒

- quickstart rootfs 是演示镜像，**不要**放任何真实凭据；
- 快照文件包含 Guest 内存 = 包含秘密，按敏感数据管理（docs/05 第 5 节）；
- 生产使用必须配 jailer + 网络隔离，本 lab 只演示生命周期。

## 思考题

- 从同一快照恢复 100 个 VM，它们的 `/dev/urandom` 初态相同，有什么风险？
- 如何把"工作区注入"接进来？（virtio-fs / 第二块 drive / vsock）
- 对比 lab01：这里的隔离边界多了哪几层？