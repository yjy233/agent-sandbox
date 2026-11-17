# Agent 沙箱技术教学文档

本系列文档自上而下介绍 AI Agent 场景下的沙箱（Sandbox）技术：从最轻量的操作系统级"软沙箱"，到容器、用户态内核，再到虚拟机级别的强隔离，最后落到 Agent 工程实践与选型。

## 阅读顺序

| 章节 | 内容 | 关键词 |
|------|------|--------|
| [01 总览：Agent 为什么需要沙箱](01-overview.md) | 威胁模型、隔离技术光谱、安全与开销的权衡 | 威胁模型、隔离层级 |
| [02 OS 级软沙箱](02-os-sandbox.md) | macOS `sandbox-exec`/Seatbelt、Linux namespaces/seccomp/Landlock/bubblewrap | SBPL、seccomp-bpf、Landlock |
| [03 容器沙箱：Docker](03-docker.md) | 容器原理、加固配置、容器逃逸与"容器不是安全边界" | namespaces、cgroups、capabilities |
| [04 用户态内核：gVisor](04-gvisor.md) | Sentry/Gofer 架构、syscall 拦截、兼容性与性能 | runsc、netstack、GKE Sandbox |
| [05 虚拟机与 MicroVM](05-vm.md) | QEMU/KVM、Firecracker、Kata Containers、macOS 虚拟化 | 硬件虚拟化、快照恢复 |
| [06 Agent 沙箱工程实践](06-agent-practice.md) | 文件/网络/资源管控、E2B/Modal 等产品、选型指南 | 出口网络白名单、纵深防御 |

## 一句话总结各层隔离

```
弱隔离/低开销 ──────────────────────────────────────► 强隔离/高开销

 进程内限制      OS 软沙箱        容器          用户态内核      MicroVM/VM
 (rlimit/chroot) (Seatbelt/       (Docker)      (gVisor)        (Firecracker/
                 seccomp/bwrap)                                 KVM/QEMU)
      │              │              │              │               │
   同一内核       同一内核       同一内核      独立用户态内核    独立 Guest 内核
   无系统调用过滤  系统调用过滤    系统调用过滤   系统调用重实现    硬件虚拟化边界
```

## 适合谁读

- 想给 Coding Agent / 代码执行 Agent 加安全边界的工程师
- 想系统理解 Linux/macOS 隔离原语与容器/VM 差异的开发者
- 需要在"启动速度、资源开销、隔离强度、兼容性"之间做技术选型的人

## 后续计划（本仓库）

文档之后会补充可动手运行的 demo：

- `examples/macos-sandbox/`：`sandbox-exec` profile 实例
- `examples/linux-bwrap/`：bubblewrap + seccomp 最小沙箱
- `examples/docker-hardened/`：加固版 Docker 运行脚本
- `examples/gvisor/`：runsc 安装与对比测试
- `examples/firecracker/`：microVM 启动与快照实验