# 04 用户态内核：gVisor

## 1. 核心思想

容器的问题在于：不可信代码的 syscall 直接打到宿主内核。gVisor 的答案是——**在用户态重新实现一个 Linux 内核**，让不可信代码的 syscall 先打到这个"假内核"，由它审查、模拟，只有极少数经过收敛的操作才真正触碰宿主内核。

```
普通容器:                        gVisor:
┌──────────────┐                ┌──────────────┐
│ 应用 syscall │                │ 应用 syscall │
└──────┬───────┘                └──────┬───────┘
       │ 300+ syscall 直达             │ 全部被拦截
       ▼                               ▼
┌──────────────┐                ┌──────────────┐
│   宿主内核    │                │ Sentry       │ 用户态内核(Go)
│  (攻击面大)   │                │ 重新实现 Linux│
└──────────────┘                │ ABI ~200+    │
                                └──────┬───────┘
                                       │ 仅 ~几十个受限 syscall
                                       ▼
                                ┌──────────────┐
                                │   宿主内核    │ (攻击面小)
                                └──────────────┘
```

gVisor 由 Google 开源，生产上用于 **GKE Sandbox、Cloud Run、App Engine**；Agent 领域 **Modal** 的沙箱基于 gVisor。

## 2. 架构组件

### 2.1 Sentry —— 用户态内核

- 用 **Go** 写的内核（内存安全，避免 C 内核常见的内存漏洞类别）；
- 实现 Linux ABI：文件、内存管理、信号、进程、网络 socket 等 ~200+ syscall 的语义；
- 每个沙箱一个 Sentry 进程，**沙箱之间互不共享内核状态**；
- Sentry 自身被 seccomp 严格限制：它对宿主内核只能使用约几十个白名单 syscall，且没有文件系统直接访问权。

### 2.2 Gofer —— 文件系统代理

- Sentry 不直接 open 宿主文件。所有文件操作经 9P（新版为 LISAFS）协议发给独立的 **Gofer 进程**；
- Gofer 只持有被授权目录的 fd，跑在独立的受限环境里；
- 意义：即使 Sentry 被攻破，攻击者还要再攻破 Gofer 才能碰到宿主文件，且只能碰到挂载进来的那部分。

### 2.3 Netstack —— 用户态网络栈

- TCP/IP 协议栈也在 Sentry 内用 Go 实现（netstack）；
- 沙箱发出的包由 Sentry 生成，经受限通道送到宿主网络；
- 宿主内核的网络协议栈不再直接暴露给不可信代码。

### 2.4 平台层（Platform）—— syscall 怎么被拦截

| 平台 | 机制 | 说明 |
|------|------|------|
| **systrap**（当前默认） | 注入信号 + seccomp trap 拦截 syscall | 无需特权、无需 KVM，性能较好 |
| ptrace（旧默认） | ptrace 逐 syscall 拦截 | 兼容性好但慢，已退居备选 |
| KVM | Sentry 跑在 guest ring，用硬件虚拟化拦截 | 需要 `/dev/kvm`，裸金属/支持嵌套虚拟化的云可用 |

## 3. 使用方式：runsc

gVisor 提供 OCI 兼容 runtime `runsc`，与 Docker/containerd 无缝集成：

```bash
# 安装（Linux x86_64/arm64）
curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" \
  | sudo tee /etc/apt/sources.list.d/gvisor.list
sudo apt update && sudo apt install runsc

# 注册到 Docker
sudo runsc install
sudo systemctl restart docker

# 像普通容器一样用，只是换了 runtime
docker run --runtime=runsc --rm -it ubuntu uname -a
docker run --runtime=runsc --rm -it ubuntu dmesg | head   # 看到的是 gVisor 的"内核"日志
```

Kubernetes 侧通过 `RuntimeClass`（`handler: runsc`）按 Pod 选择 gVisor，GKE Sandbox 即此模式。

验证隔离效果：

```bash
# runsc 容器内：内核版本是 gVisor 虚拟的
docker run --runtime=runsc --rm ubuntu uname -r        # 4.x 假版本 / gVisor 标识
# 许多 /proc、ioctl、冷门 syscall 行为与真实 Linux 不同
```

## 4. 代价：兼容性与性能

### 4.1 兼容性

- syscall 覆盖是"常用子集"：未实现的返回 `ENOSYS`。数据库（某些 io_uring/AIO 路径）、需要特殊 ioctl 的程序、依赖 `/proc` 细节的工具可能跑不了或行为异常；
- 不支持内核模块、eBPF（沙箱内）、部分设备访问；
- **GPU 支持有限**（nvproxy 方案在推进中），AI 训练类负载要单独评估；
- 经验法则：普通 Python/Node/编译工具链/常见服务基本没问题；越贴近内核的程序越容易踩坑。

### 4.2 性能

- **syscall 密集型负载开销明显**：每次 syscall 要经拦截 + 用户态内核处理，文件 IO 还要过 Gofer 一跳；
- 典型量级：文件密集型 benchmark 可能慢 20%–2x；纯计算（用户态 CPU 指令直接执行）几乎无损；网络经 netstack 有额外拷贝与调度开销；
- 内存：每个沙箱一个 Sentry + Gofer，底噪十几 MB 起，比 VM 小得多，比裸容器大。

### 4.3 安全性定位

- 把宿主内核攻击面从 300+ syscall 收敛到几十个，且 Sentry 用 Go 写、无直接文件访问——**逃逸需要"攻破 Sentry + 绕过其 seccomp + 利用宿主内核剩余接口"的漏洞链**，难度显著高于普通容器；
- 但注意：gVisor 不是硬件边界。Sentry 与宿主仍在同一内核上，理论上宿主内核漏洞仍可能影响它（KVM 平台可部分缓解）；
- 定位：**介于容器与 VM 之间，偏 VM 一侧**。比 VM 轻、比容器强，兼容性是主要短板。

## 5. gVisor vs Kata（预告第 05 章）

两者都常被归为"安全容器"，但路线完全不同：

| | gVisor | Kata Containers |
|---|---|---|
| 思路 | 用户态**重实现**内核 | 每 Pod 起一个**真 VM**，跑真 Linux 内核 |
| 兼容性 | 部分 syscall | 完整（就是 Linux） |
| 隔离边界 | 软件（Sentry） | 硬件虚拟化 |
| 开销 | 中 | 较高（VM 底噪） |
| 适合 | 高密度、syscall 行为可控的负载 | 需要完整兼容 + 强隔离的负载 |

## 6. 动手实验建议

1. 同一镜像分别用 `runc` 与 `runsc` 跑，对比 `uname -a`、`/proc/cpuinfo`、可用 syscall；
2. 跑一个 syscall 密集 benchmark（如 `fio` 小文件随机读写、`redis-benchmark`），量化开销；
3. 故意跑一个用 io_uring 的程序，观察 gVisor 下的失败模式；
4. 阅读 `runsc --help` 与 `/etc/docker/daemon.json` 中的 runtime 配置。

## 下一步

[05 虚拟机与 MicroVM](05-vm.md) —— 当软件边界不够时，回到硬件虚拟化。