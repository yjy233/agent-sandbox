# Lab 04 · gVisor（需 Linux + Docker + runsc）

对应文档：[docs/04 用户态内核](../../docs/04-gvisor.md)。

## 目标

验证 gVisor 真的换掉了内核视图，实测它的兼容性边界与 IO 开销。

## 环境准备

```bash
# Debian/Ubuntu（裸机或支持嵌套虚拟化的 VM）
curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" \
  | sudo tee /etc/apt/sources.list.d/gvisor.list
sudo apt update && sudo apt install -y runsc
sudo runsc install && sudo systemctl restart docker
bash examples/lab04-gvisor/run.sh
```

> macOS 注意：gVisor 只能跑在 Linux 上。Lima VM 里可以装 docker+runsc 完成本 lab（systrap 平台不需要 KVM）。

## 步骤设计

| 步骤 | 内容 | 验证点 |
|------|------|--------|
| step1 | runc vs runsc 的 `uname -r` | 两者不同 = 用户态内核生效 |
| step2 | runsc 内 `dmesg` | 出现 gVisor 标识 |
| step3 | 兼容性探测报告 | unshare/mount/mknod 等在两边的 OK/FAIL 矩阵 |
| step4 | dd 256MB 写盘耗时对比 | 量化 IO 开销（报告型） |
| step5 | runsc + lab03 加固参数 | 工作区可写、断网、业务正常 |

## 思考题

- step3 中 `unshare -U` 在 runsc 下为什么失败？这对"沙箱内再套沙箱"意味着什么？
- 如果你的 Agent 要跑 PostgreSQL，gVisor 合适吗？（查 io_uring/AIO 支持现状）
- step4 的开销主要来自 Sentry 还是 Gofer？如何设计实验区分？