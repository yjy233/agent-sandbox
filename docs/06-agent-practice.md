# 06 Agent 沙箱工程实践与选型

前五章讲了"隔离机制"，本章讲"怎么把它变成一个真正可用的 Agent 沙箱"。核心观点：**隔离层级只是地基，文件/网络/资源/审计的策略层才决定实际安全水位。**

## 1. 四个管控维度

### 1.1 文件系统

原则：**默认不可见，工作区可写，密钥零透传。**

- 只挂载/暴露任务工作区；系统目录只读；`$HOME`、`~/.ssh`、`~/.aws`、浏览器数据一律不进沙箱；
- 沙箱内使用**独立的低权限身份**（容器非 root / VM 内普通用户）；
- 环境变量白名单：绝不把宿主的 `API_KEY`、`GITHUB_TOKEN` 原样传入。需要凭据时走"代理代签"模式（见 1.2）；
- 磁盘配额 + 会话结束即销毁，防持久化驻留；
- 注意"合法写入"也是攻击面：Agent 往工作区写的代码会被用户带走执行——沙箱外还要有 review/审批。

### 1.2 网络

原则：**默认拒绝，按需白名单，全部过代理。**

```
沙箱（netns 内无默认路由）
   │ 唯一出口
   ▼
本地/旁路代理（mitmproxy / envoy / 自研）
   ├─ 域名白名单：pypi.org、github.com、registry.npmjs.org ...
   ├─ 拒绝：169.254.169.254（云元数据）、内网段、localhost 宿主服务
   ├─ 凭据代注入：沙箱不带 token，代理校验目标后附加 Authorization
   └─ 全量日志：谁在什么时候请求了什么域名
```

要点：

- **DNS 也要管**：沙箱内 DNS 指向受控解析器，防 DNS 隧道外传；
- macOS Seatbelt 只能按 IP 过滤 → 必须"沙箱强制走代理 + 代理做域名白名单"两段配合（Claude Code 即此模式）；
- Linux netns / VM tap 设备天然支持"无默认路由，只有代理一条路"；
- 白名单本身要评估：允许 `github.com` 就意味着允许把数据 push 到攻击者仓库——高敏场景用"只读镜像源 + 禁上传"的更细策略。

### 1.3 资源与生命周期

- CPU/内存/磁盘/PID 数上限（cgroups、rlimit、VM 配额）；
- **墙钟超时**：任务级 timeout，到点强杀整个进程组/容器/VM；
- 输出截断：stdout/stderr 限制大小，防日志爆炸与上下文投毒；
- 会话隔离：一个任务一个沙箱实例，不复用；
- 并发上限与队列：防 Agent 自我复制式开沙箱。

### 1.4 审计与审批

- 记录：每条执行的命令、每次网络请求、每次文件越权尝试（deny 日志）；
- **沙箱外操作走审批**：git push、发消息、部署、花钱——这些沙箱管不到，必须 human-in-the-loop 或策略引擎；
- 提示注入防线：对 Agent 读取的外部内容做标记/隔离，敏感操作要求二次确认。

## 2. 产品与开源方案速览

| 方案 | 底层隔离 | 形态 | 适合 |
|------|---------|------|------|
| **Claude Code sandbox** | Seatbelt / bwrap+Landlock | CLI 内置 | 本地开发，T1–T2 |
| **OpenAI Codex CLI sandbox** | Seatbelt / Landlock+seccomp | CLI 内置 | 本地开发，T1–T2 |
| **E2B** | Firecracker + 快照 | 云 SDK / 可自托管 | Agent 代码执行，T3 |
| **Modal** | gVisor + 自研调度 | 云函数/沙箱 | 高密度代码执行 |
| **Daytona** | 容器/VM（可配） | 开发环境沙箱平台 | Agent 开发工作区 |
| **Fly.io Machines** | Firecracker | REST API 驱动 VM | 自建沙箱云的底座 |
| **Cloudflare Workers/Sandbox** | V8 isolate / 容器 | 边缘运行时 | JS 为主的轻量执行 |
| **gVisor (runsc)** | 用户态内核 | 自托管 runtime | 自建容器平台加固 |
| **Kata Containers** | 每 Pod 一 VM | K8s RuntimeClass | K8s 多租户 |
| **一次性云 VM** | 完整 VM | 自建编排 | 极端不可信任务 |

## 3. 选型决策树

```
要跑任意 shell/任意程序吗？
├─ 否（只跑 JS/计算）→ V8 isolate / WASM（本系列未展开）
└─ 是
   ├─ 本地单用户开发机？
   │   ├─ macOS → sandbox-exec + 代理白名单
   │   └─ Linux → bwrap/Landlock+seccomp（或 rootless podman 加固）
   └─ 服务端 / 多租户 / 不可信用户？
       ├─ 需要完整 Linux 兼容（数据库、GPU、冷门 syscall）？
       │   ├─ 是 → Firecracker/Kata（快照加速冷启动）
       │   └─ 否 → gVisor（密度高、开销小）
       └─ 极端敏感/合规 → 一次性完整 VM，用完即毁
```

再叠加三个问题校准：

1. **冷启动预算**：<200ms 且要强隔离 → 只有"microVM+快照"或 gVisor 能满足；
2. **负载形态**：syscall/IO 密集 → gVisor 开销要实测；纯计算 → 各层差异小；
3. **运维能力**：没有 KVM 运维经验 → 优先托管方案（E2B/Modal/Fly），别裸写 Firecracker 编排。

## 4. 常见误区

| 误区 | 事实 |
|------|------|
| "用了 Docker 就安全了" | 默认 Docker 共享内核且配置宽松，见第 03 章 |
| "沙箱里就能随便跑" | 沙箱内数据仍可经允许的出口外传；供应链攻击在沙箱内照样生效 |
| "VM 就绝对安全" | VMM/hypervisor 也有 CVE（如 VENOM CVE-2015-3456）；快照含秘密 |
| "Mac 上 Docker 没有 VM 边界" | 有 VM，但共享目录/凭据转发常常把边界打穿 |
| "隔离越强越好" | 兼容性/延迟/成本都是真实代价，按威胁模型选 |
| "沙箱能防提示注入" | 不能。注入发生在 LLM 决策层，沙箱只限制执行后果 |

## 5. 本仓库的动手路线（建议顺序）

1. **macOS**：写一个 SBPL profile，跑通"工作区可写、`~/.ssh` 不可读、断网"，用 `log stream` 看 deny 日志；
2. **Linux（或 Mac 上的 Lima VM）**：bwrap 复刻同样策略；再加 Landlock 版本对比；
3. **Docker**：默认 vs 加固模板对比实验（第 03 章第 6 节）；
4. **代理白名单**：mitmproxy 做域名白名单 + 凭据代注入，沙箱强制走代理；
5. **gVisor**：runsc 跑同一负载，实测兼容性与性能差异；
6. **Firecracker（需 Linux+KVM）**：最小 VM 启动 → 打快照 → 毫秒恢复，体会 E2B 的底层；
7. **组装**：把 1–6 封装成统一 `sandbox.run(cmd, policy)` 接口，policy 描述文件/网络/资源/超时。

完成这条路线，你就拥有了从内核原语到产品级沙箱云的完整手感。

## 参考方向

- macOS：`man sandbox-exec`、Apple Platform Security（Sandbox 章节）、Chromium/Bazel 的 SBPL 实例
- Linux：`man 7 namespaces`、`man 2 seccomp`、Landlock 内核文档、bubblewrap README
- Docker：官方 security 文档、seccomp default profile（moby/moby 仓库）
- gVisor：gvisor.dev 文档与 design guide、runsc 源码
- Firecracker：firecracker-microvm.github.io、snapshotting 文档、jailer 文档
- 产品：E2B 开源仓库（infra）、Modal 博客（gVisor/冷启动系列）、Fly.io Machines 文档