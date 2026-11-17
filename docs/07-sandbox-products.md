# 07 知名沙箱产品全景

本章盘点市面上主流的沙箱产品/基础设施：它们用什么隔离技术、主打什么能力、适合什么场景。事实以厂商公开资料为准（2026 年下半年口径），启动时间等数字均为**厂商自报**，测量口径不一，不能直接横向比较。

## 1. 托管沙箱云（Agent 执行层）

### 1.1 E2B —— "给每个 Agent 一台一次性电脑"

- **隔离**：每个 sandbox 一个 **Firecracker microVM**（AWS Lambda 同款），独立内核；
- **启动**：自报 ~150ms；支持 **pause/resume**（文件系统+内存状态快照），多轮会话间可保留运行中的进程；
- **形态**：Python/JS SDK，`Sandbox.create()` 一行起沙箱；核心 infra **Apache-2.0 开源可自托管**，托管云按秒计费；
- **生态**：预置模板（code-interpreter、codex、claude-code 等），Manus 公开采用 E2B 作为沙箱方案之一；
- **适合**：通用 Agent 代码执行、需要会话级状态保持、有私有化诉求的团队。

### 1.2 Modal —— gVisor 路线的高密度平台

- **隔离**：计算任务用 **gVisor 容器化并虚拟化**（官方表述）；另提供完整 VM 的 **VM Sandboxes**（Beta），供需要真实内核功能的负载；
- **特色**：自研镜像分发与快照调度，冷启动优化激进；**GPU 资源池**是几家沙箱云里最全的；
- **适合**：Agent 执行 + 模型推理/生图/科学计算混合负载。

### 1.3 Daytona —— 开发工作区出身，生命周期控制最细

- **隔离**：按 **Sandbox Class** 区分容器、Linux VM 等类别；
- **特色**：自报 <90ms 冷启动；主打**运行中状态 fork**（像 git 分支一样从一台跑着的 VM 分出多个副本）、暂停/恢复、死亡探测；
- **适合**：需要复杂环境生命周期（分支、并行试验）的 coding agent 平台。

### 1.4 Vercel Sandbox / Deno Sandbox —— 平台附属型

- 两者都是**每沙箱一个 Firecracker microVM**；
- Vercel：与 Vercel 部署工作流集成，外置出网凭据代理，活跃 CPU 计费；
- Deno：强调出站策略与凭证代理，可写 Volume + Snapshot；
- **适合**：已经 all-in 对应平台的团队，顺路获得沙箱能力。

### 1.5 Cloudflare Sandbox —— Workers 生态的执行层

- **隔离**：容器接口，官方描述为**每 sandbox 独立 VM**；实例生命周期由 Durable Objects 管理；
- **特色**：出网安全审计/鉴权与 Workers 生态（R2、KV、Queues）深度集成；
- **适合**：后端已在 Workers 上、长会话型 Agent。

### 1.6 Fly.io Machines —— 自建沙箱云的底座

- **隔离**：**Firecracker microVM**，跑在 Fly 自有物理机上；REST API 驱动启停；
- **特色**：停止的 Machine 启动通常 <1s；Sprites 产品 checkpoint+restore ~300ms；
- **适合**：想自己造 E2B 的团队，拿它当 VMM 编排底座。

### 1.7 其他值得知道的

| 产品 | 隔离 | 一句话 |
|------|------|--------|
| **Runloop** | 云端 devbox（VM 级） | 专做 coding agent 的 devbox，快照/分支 |
| **Morph** | VM + 快照 | "infinibranch"：从快照无限分支，主打 agent RL/评测 |
| **Blaxel** | Firecracker microVM | 自报毫秒级启动、~25ms resume |
| **Northflank** | Kata Containers 或 gVisor | 通用 PaaS 顺带提供强隔离 |
| **AWS Lambda / Fargate** | Firecracker | 多租户函数计算标杆，非 Agent 专用但技术同源 |
| **Google Cloud Run / GKE Sandbox** | gVisor | K8s 生态按 Pod 选 gVisor；GKE 另有 Agent Sandbox 项目 |

## 2. 开源沙箱运行时（自己造轮子的零件）

| 项目 | 隔离机制 | 说明 |
|------|---------|------|
| **Firecracker** | microVM（KVM） | AWS 开源，Rust，~125ms 启动，快照/恢复 + jailer |
| **gVisor (runsc)** | 用户态内核 | Google 开源，OCI runtime，GKE/Cloud Run/OpenAI/Anthropic 在用 |
| **Kata Containers** | 每 Pod 一 VM | OpenInfra 基金会，OCI/CRI 兼容，完整 Linux 兼容 |
| **Anthropic sandbox-runtime (srt)** | Seatbelt / bubblewrap | 2026-10 开源的 npm 包，把 Claude Code 的 OS 级沙箱独立出来：macOS 动态生成 SBPL，Linux bwrap+socat，Windows alpha（WFP+专用账户+NTFS ACL）；默认"读允许除非拒绝、写拒绝除非允许、网络拒绝除非域名白名单"，限制覆盖整个进程树，可包 MCP server/任意 CLI |
| **NVIDIA OpenShell** | Landlock + seccomp + 受限用户 | 2026-09 开源的 agent 安全运行时，声明式策略适配 Claude Code/Codex/OpenCode 等，带审计 |
| **阿里 OpenSandbox** | 容器/可插拔后端 | 多语言 agent 沙箱平台，SDK+CLI+MCP Server，Claude Code/Cursor 开箱集成 |
| **Docker Sandboxes** | microVM | Docker 官方 2026 年产品，"一条命令给任意 coding agent 套 microVM" |
| **bubblewrap / Landlock / seccomp** | OS 原语 | 见第 02 章，所有软沙箱的地基 |

## 3. 横向对比

| 产品 | 隔离层级 | 启动（自报） | 状态保持 | 开源 | 一句话定位 |
|------|---------|-------------|---------|------|-----------|
| E2B | microVM | ~150ms | pause/resume（内存+盘） | infra 开源 | Agent 执行层默认选项 |
| Modal | gVisor（+VM Beta） | 亚秒级 | 快照调度 | 否 | 高密度+GPU |
| Daytona | 容器/VM 分类 | <90ms | 运行中 fork | 部分 | 生命周期控制最细 |
| Vercel Sandbox | microVM | P99 ~1.1s（突发压测口径） | Volume | 否 | Vercel 生态附属 |
| Cloudflare Sandbox | VM（容器接口） | — | Durable Objects | 否 | Workers 生态附属 |
| Fly Machines | microVM | <1s（停止→启动） | checkpoint | VMM 开源 | 自建底座 |
| srt (Anthropic) | OS 软沙箱 | ~ms | 无 | 是 | 本地进程树隔离 |
| Firecracker/gVisor/Kata | 机制本身 | — | — | 是 | 自研零件 |

## 4. 选型提醒

1. **问清启动口径**：microVM 启动 ≠ 应用可用 ≠ 快照恢复。并发突发下的 P95/P99 TTI 才是产品体验；
2. **同款发动机 ≠ 同款车**：都用 Firecracker，网络策略、持久化语义、区域、最长运行时间可能天差地别；
3. **隔离不能静默降级**：需要 VM 隔离的任务，不能因节点缺 KVM 就回退普通容器；
4. **沙箱外的能力同样重要**：出网白名单/凭据代理、审计、快照生命周期，往往比隔离层级本身更影响安全水位（见第 06 章）。

## 下一步

[08 知名 Agent 产品的沙箱技术](08-agent-products.md) —— 反过来看：Claude Code、Codex、Devin、Manus 们各自怎么选。