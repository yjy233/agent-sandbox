# 08 知名 Agent 产品的沙箱技术

本章反向拆解：主流 Agent 产品各自用什么沙箱、边界画在哪里。资料来自厂商官方文档/博客与公开逆向分析（2026 年下半年口径），关键结论附来源。

## 1. 两种组织模式

先看架构分野，再看产品：

```
模式 A：Agent 在沙箱外，只把"执行"关进去
┌─────────────┐      ┌──────────────────┐
│ Agent 循环   │ ───► │ 沙箱（bash/代码） │
│ 宿主/云端    │ ◄─── │ 文件/网络受限     │
└─────────────┘      └──────────────────┘
代表：Claude Code、Codex CLI、Copilot coding agent
优点：密钥不进沙箱、权限可分层；缺点：每条命令跨边界

模式 B：整个 Agent 跑在沙箱里（agent-in-sandbox）
┌──────────────────────────────┐
│ 沙箱 VM：Agent 循环 + 工具 +  │
│ 文件系统 + 浏览器，root 权限  │
└──────────────────────────────┘
代表：Devin、Manus
优点：环境即产品、体验完整；缺点：API key 必须进沙箱，
     隔离一旦被破或注入外传，密钥一起暴露
```

## 2. 本地 CLI 系：OS 软沙箱是标准答案

### 2.1 Claude Code（Anthropic）

- **机制**：macOS 用 **Seatbelt**（`sandbox-exec` 动态生成 SBPL）；Linux/WSL2 用 **bubblewrap**（+socat 做网络代理通道）；不支持原生 Windows；
- **边界**：沙箱化的是 **Bash 工具（按命令）**；工作区内可读写，**网络默认拒绝、走域名白名单代理**；v2.1.219 起 `sandbox.network.strictAllowlist` 直接拒绝白名单外主机；
- **注意盲区**：Read/Edit/WebFetch 等内置工具在 Claude Code 进程内运行，不受 Bash 沙箱约束；MCP server 与 hooks 默认在宿主无约束运行——要全量隔离需用 **sandbox-runtime（srt）** 包住整个进程，或干脆跑在 devcontainer/VM 里；
- **效果**：Anthropic 自报沙箱化后权限弹窗减少 **84%**（此前用户批准了约 93% 的权限请求，审批疲劳使人工确认形同虚设）；
- **配套**：31 个 hook 事件做应用层治理 + 信任目录机制（修复过"未信任目录即解析 `.claude/settings.json` 自动执行 hook"的漏洞）。
- 来源：Claude Code 官方 sandboxing/sandbox-environments 文档、Anthropic 安全架构披露。

### 2.2 OpenAI Codex CLI

- **机制**：macOS **Seatbelt**（自带 base policy）；Linux **Landlock + seccomp-bpf**（部分版本叠加 bubblewrap）；
- **三档沙箱模式**：`read-only` / `workspace-write`（默认推荐）/ `danger-full-access`；
- **审批策略**：`untrusted` / `on-request` / `never` 三档，与沙箱模式正交组合；
- **网络**：workspace-write 默认禁网，需要时显式放开；
- **特点**：内核级沙箱**默认开启**，"隔离是构造出来的，不靠模型自觉"。
- 来源：Codex CLI 开源仓库与官方文档。

### 2.3 Codex 云端（ChatGPT 里的 Codex）

与 CLI 完全不同的路线：**Docker 容器 + 双阶段**——

1. **Setup 阶段**：有网络、可装依赖、可访问 Secrets；
2. **Agent 阶段**：默认**离线**、Secrets 已清除；容器缓存最长 12h；
3. 基础镜像 **codex-universal 已开源**。

这是"用时间换安全"的典型：把需要特权的动作收敛到受控阶段。

### 2.4 Gemini CLI / 其他

- **Gemini CLI**：`--sandbox` 支持 Docker/Podman，macOS 上走 Seatbelt profile；
- **GitHub Copilot CLI / coding agent 本地沙箱**：2026-10 本地沙箱 GA，隔离文件/网络/凭证；
- **反面参照**：Aider、Cline 等默认**无沙箱**直接在宿主执行，安全完全依赖审批与模型自觉——选型时要清楚这条默认值。

## 3. 云端托管系：VM/gVisor 是标准答案

### 3.1 ChatGPT Code Interpreter（Advanced Data Analysis）

公开逆向分析确认：

- **gVisor（runsc）跑在 Kubernetes/Azure 上**：沙箱 hostname 为 `runsc`，`uname -a` 返回 gVisor 标志性的 `4.4.0` 内核签名；
- **网络完全锁死**：除官方 RPC 通道外无任何出网路径；
- 每沙箱约 9GB 内存/4 vCPU，内部 FastAPI 管理 Jupyter Kernel（ZeroMQ 执行）；镜像 ~7GB 预装 ffmpeg/LaTeX/Playwright 等；
- 冷启动藏在 LLM 推理延迟里，用户感知 ~500ms。

### 3.2 Claude.ai 代码执行 / Anthropic Managed Agents

- Anthropic 官方披露：claude.ai 的代码执行跑在**隔离基础设施上的临时 gVisor 容器**，不触碰用户本地文件；
- gVisor 官方使用者名单同时包含 **OpenAI 与 Anthropic**——两大模型厂在云端代码执行上殊途同归；
- Managed Agents 架构：**brain（模型+harness）与 hands（sandbox+tools）解耦**，默认 Anthropic 托管云沙箱，也可换自托管沙箱。

### 3.3 Devin（Cognition）

- **每 session 一台 Linux VM**（模式 B）：仓库、工具链、依赖打进 snapshot，会话从镜像开机；
- Agent 全程在 VM 内，密钥以环境变量注入 blueprint——因此**密钥撤不掉、权限拆不了层**，这是模式 B 的固有代价；
- 产品上配 shell/编辑器/浏览器/planner，沙箱即"Devin 的电脑"。

### 3.4 Manus

- **每任务一台完全隔离的云 VM**（模式 B），官方定位"你的云计算机"：完整网络/文件系统/浏览器/工具链；
- **VM 内宽权限**：用户和 Agent 有 root，可改系统文件甚至格式化磁盘——"sandbox"指**隔离域**而非细粒度权限；Zero Trust 指 VM 间互不影响；
- **生命周期**：create → active → sleep → awake → recycle（免费 7 天 / Pro 21 天闲置回收）；重建时只恢复产物/附件/重要项目文件，不恢复中间代码与已装包；
- 基础设施公开采用 **E2B**（Firecracker microVM），官方博客有专文。

### 3.5 Cursor Background/Cloud Agents

- 每个 cloud agent 一台**厂商托管的隔离 VM**：clone 仓库、有互联网、自动执行终端命令；Cursor 管理 VM 配置/隔离/快照/启动；
- 本地 Agent 模式 2026 年初也加了 OS 级沙箱（自报权限提示减少 ~40%）；
- 安全提醒：有网+自动执行+处理不可信仓库内容 = 数据外传与供应链风险面，官方文档明确要求审阅 Privacy Mode 与数据流。

### 3.6 GitHub Copilot coding agent

- **每任务一台 GitHub Actions 临时 runner（托管 VM）**，用完即毁；
- `copilot-setup-steps.yml` 定制开工前环境；**只能改触发任务的那个仓库**；
- 网络出口有防火墙/allowlist 控制；PR 必须人工 review + Copilot code review 双审。

### 3.7 开源 Agent 框架

| 框架 | 默认运行时 | 备注 |
|------|-----------|------|
| **OpenHands** | Docker 容器（runtime 内跑 action-execution server） | 支持 E2B/Modal 等远程 runtime |
| **SWE-agent / mini-swe-agent** | 每实例一个 Docker 容器 | 评测场景标准做法 |
| **Anthropic Computer Use 参考实现** | Docker 内跑 Linux 桌面 | GUI agent 的隔离样板 |
| **smolagents（本地执行器）** | 解释器级 AST 白名单 | 最弱一档，仅防误操作 |

## 4. 汇总矩阵

| 产品 | 形态 | 隔离技术 | 网络默认 | 模式 |
|------|------|---------|---------|------|
| Claude Code | 本地 CLI | Seatbelt / bwrap | 拒绝+域名白名单 | A |
| Codex CLI | 本地 CLI | Seatbelt / Landlock+seccomp | 拒绝 | A |
| Codex 云端 | 托管 | Docker 双阶段（setup 有网/agent 离线） | Agent 阶段离线 | A |
| Gemini CLI | 本地 CLI | Docker/Podman / Seatbelt | 依配置 | A |
| ChatGPT Code Interpreter | 托管 | gVisor on K8s | 全锁死 | A |
| Claude.ai 代码执行 | 托管 | 临时 gVisor 容器 | 受控 | A |
| Copilot coding agent | 托管 | Actions 一次性 VM | 防火墙白名单 | A |
| Cursor cloud agent | 托管 | 托管 VM+快照 | 有网 | A |
| Devin | 托管 | 每 session Linux VM | 有网 | B |
| Manus | 托管 | 每任务云 VM（E2B/Firecracker） | 有网 | B |
| OpenHands | 自托管 | Docker（可换 E2B/Modal） | 依配置 | A |

## 5. 规律与启示

1. **本地 → OS 软沙箱，云端 → gVisor/microVM**：与第 01 章的威胁模型推导完全一致，工业界用脚投票验证了这条光谱；
2. **审批疲劳是真实问题**：93% 批准率说明"每步都问"不是安全方案；正确答案是"沙箱兜底 + 少数关键操作审批"（Anthropic 84% 弹窗下降）；
3. **网络是最难的一维**：全锁死（Code Interpreter）最安全但限制能力；域名白名单+代理（Claude Code）是主流折中；有网（Devin/Manus/Cursor）靠 VM 边界+审计兜底；
4. **模式 B 的密钥困境**：agent-in-sandbox 体验好，但 API key 与不可信代码同处一室，是提示注入外传的高价值目标——这也是 E2B 们推"凭据代理/代签"的原因；
5. **沙箱 ≠ 全部**：信任目录、hook 治理、PR 双审、出网审计，都是沙箱之外的必要防线。

## 主要来源

- Claude Code 官方文档：sandboxing / sandbox-environments / settings-reference（code.claude.com/docs）
- Anthropic 安全架构披露（2026-08）：claude.ai gVisor 临时容器、84%/93% 数据、信任目录修复
- Anthropic sandbox-runtime 开源发布（2026-10，npm @anthropic-ai/sandbox-runtime）
- OpenAI Codex CLI 仓库/文档；codex-universal 镜像仓库；Codex 云端双阶段容器分析
- Code Interpreter 逆向分析（runsc hostname/4.4.0 内核签名/网络锁死），见 langchain.cn 社区综述转引
- Manus 官方博客《Understanding Manus Sandbox》与 E2B 合作博文（e2b.dev/blog/how-manus-uses-e2b...）
- Cursor 官方文档（background agents 隔离 VM）；GitHub Copilot coding agent 文档（Actions runner/防火墙）
- wincent《List of coding agent sandboxes》（2026-05 起持续更新）；NVIDIA OpenShell 发布资料