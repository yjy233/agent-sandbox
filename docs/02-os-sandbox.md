# 02 OS 级软沙箱

"软沙箱"指不引入新内核、不做虚拟化，直接利用操作系统自带的访问控制机制，把某个进程及其子进程限制在规则允许的资源范围内。优点是**启动快（毫秒级）、零额外内存、syscall 完全兼容**；缺点是**与宿主共享内核，内核漏洞即逃逸**。

本章分 macOS 和 Linux 两部分。

---

## 1. macOS：Seatbelt 与 sandbox-exec

### 1.1 机制概览

macOS 的沙箱机制代号 **Seatbelt**，内核组件是 `Sandbox.kext`（现代版本并入 `com.apple.security.sandbox`）。工作方式：

```
进程发起操作（open / connect / fork ...）
        │
        ▼
内核 MAC (Mandatory Access Control) 钩子
        │
        ▼
Sandbox 引擎按 profile 规则求值 ──► allow / deny
```

- 规则用 **SBPL**（Sandbox Profile Language）编写，是一种 Scheme 风格的 DSL；
- profile 在进程启动时加载，**之后不可放宽**（只能更严），且自动继承给子进程；
- App Store 应用的 App Sandbox、Safari 渲染进程隔离都用同一套机制；
- 命令行入口是 `/usr/bin/sandbox-exec`。注意：它的 man page 标注了 deprecated，但至今（macOS 15/26）仍是系统自带且被 Claude Code、Codex CLI 等实际使用的方案。Apple 没有提供公开替代品。

### 1.2 SBPL 快速上手

一个最小 profile：默认全拒绝，只放行读系统目录 + 读写工作区：

```scheme
(version 1)
(deny default)                      ; 默认拒绝一切操作

;; 允许读取系统库与运行时（程序能跑起来的底线）
(allow file-read*
  (subpath "/usr/lib")
  (subpath "/usr/share")
  (subpath "/System")
  (subpath "/Library/Frameworks")
  (subpath "/private/var/db/timezone"))

;; 允许 exec 解释器/工具链
(allow process-exec
  (subpath "/usr/bin")
  (subpath "/bin")
  (subpath "/usr/local/bin"))
(allow process-fork)

;; 工作区可读写
(allow file-read* file-write*
  (subpath "/Users/bill/code/agent-sandbox/workspace"))

;; 必要的设备节点
(allow file-read* file-write*
  (literal "/dev/null")
  (literal "/dev/urandom")
  (literal "/dev/dtracehelper"))

;; 允许基本的进程信息 syscall
(allow sysctl-read)
(allow mach-lookup (global-name "com.apple.system.logger"))
```

运行：

```bash
sandbox-exec -f profile.sb /bin/bash
# 或内联
sandbox-exec -p '(version 1)(deny default)(allow file-read*)(allow process*)(deny network*)' python3 app.py
```

验证效果：

```bash
# 在沙箱内尝试读密钥 —— 应报 Operation not permitted
sandbox-exec -p '(version 1)(deny default)(allow file-read* (subpath "/usr"))(allow process*)' \
  cat ~/.ssh/id_rsa
```

### 1.3 常用操作类别

| 类别 | 控制内容 |
|------|---------|
| `file-read*` / `file-write*` | 文件读/写（含元数据），支持 `subpath` / `literal` / `regex` 匹配 |
| `process-exec` / `process-fork` | 执行新程序 / fork |
| `network*` / `network-outbound` / `network-inbound` | 网络，可按 `remote ip`、端口过滤 |
| `mach-lookup` / `mach-register` | Mach IPC 服务（macOS 的"进程间通信总线"） |
| `sysctl-read` / `sysctl-write` | 内核参数读写 |
| `signal` | 向其他进程发信号（可限制只能 signal 自己） |
| `iokit-open` | 访问 IOKit 设备（USB、GPU 等） |

### 1.4 关键限制（Agent 场景必须知道）

1. **网络过滤粒度粗**：只能按 IP/端口/协议过滤，**不能按域名过滤**。"只允许访问 pypi.org"这种需求要靠本地代理 + 沙箱强制走代理实现（见第 06 章）；
2. **不做文件系统虚拟化**：沙箱内看到的还是真实文件系统，只是访问被拒。程序可能因"文件存在但读不了"而行为异常；
3. **profile 调试痛苦**：deny 日志在 `log stream --predicate 'sender == "Sandbox"'` 里看，规则缺一条程序就莫名失败，需要迭代补规则；
4. **deprecated 风险**：Apple 随时可能移除 `sandbox-exec`（API `sandbox_init` 同样 deprecated）。教学与生产都要有心理预期；
5. **防不了内核漏洞**：Seatbelt 规则本身跑在内核里，内核 0day 可绕过。

### 1.5 真实用法参考

- **Claude Code** 的 sandbox 模式：Seatbelt profile 限制文件写入到工作区 + 网络走本地代理做域名白名单；
- **OpenAI Codex CLI** macOS 模式：`sandbox-exec` + 按审批策略动态生成 profile；
- **Bazel** 的 darwin sandbox：每个编译 action 一个 Seatbelt 沙箱。

---

## 2. Linux：隔离原语工具箱

Linux 没有单一"沙箱命令"，而是一组可组合的内核原语。理解它们就理解了 Docker 的全部底层。

### 2.1 chroot —— 不是安全边界

```bash
sudo chroot /path/to/rootfs /bin/sh
```

只改变进程的根目录视图。**有 root 权限的进程可以轻易逃逸**（经典手法：`mkdir foo; chroot foo; cd ../../..`）。它的正确用途是构建/修复环境，不是隔离不可信代码。

### 2.2 Namespaces —— 视图隔离

把进程看到的某类系统资源"换一份"：

| Namespace | 隔离内容 | Agent 场景意义 |
|-----------|---------|---------------|
| `mount` | 挂载点/文件系统树 | 给沙箱一个独立的 rootfs 视图 |
| `pid` | 进程号空间 | 沙箱内看不到/杀不了宿主进程 |
| `net` | 网卡、IP、端口、路由 | 断网或强制走代理 |
| `user` | UID/GID 映射 | 沙箱内 root = 宿主普通用户（关键！） |
| `ipc` | System V IPC / POSIX 消息队列 | 防共享内存通道 |
| `uts` | 主机名 | 次要 |
| `cgroup` | cgroup 视图 | 隐藏宿主资源拓扑 |
| `time` | 系统时钟偏移 | 次要 |

手动体验（`unshare`）：

```bash
# 新 PID + mount + net namespace，fork 后 PID 1 是新空间里的 init
sudo unshare --pid --mount --net --fork --map-root-user /bin/bash
# 沙箱内：ps aux 只有自己；ip a 只有 lo（且 down）
```

**user namespace 是软沙箱安全性的基石**：它让"沙箱内的 root"映射为宿主上的无特权用户，即使沙箱内提权成功，对宿主也只是普通用户。

### 2.3 seccomp-bpf —— 系统调用过滤

用 BPF 程序对每个 syscall 做裁决：`ALLOW` / `ERRNO(x)` / `KILL` / `TRAP`。

```
进程 syscall ──► seccomp BPF 过滤器 ──► 放行 / 返回错误 / 杀进程
```

- Docker 默认 profile 禁用约 44 个危险 syscall（`mount`、`ptrace`、`kexec_load`、`bpf` 等）；
- 过滤器一旦安装不可移除，且继承给子进程；
- 粒度到 syscall 号 + 参数（如只允许 `socket(AF_INET, ...)`）。

最小 C 示例（禁止一切网络）：

```c
// 伪代码骨架：用 libseccomp
scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_ALLOW);
seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(socket), 0);
seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(connect), 0);
seccomp_load(ctx);
execvp(...);  // 之后所有 socket() 返回 EPERM
```

命令行体验可以用 `bwrap --seccomp` 或现成工具，手写 BPF 较繁琐，实践中一般交给 bubblewrap/Docker。

### 2.4 Capabilities —— 拆分 root

传统 Unix 是"root 全能 / 非 root 全不能"。Linux 把 root 拆成 ~40 个 capability：

- `CAP_SYS_ADMIN`：mount、很多杂项（"新 root"，尽量不给）
- `CAP_NET_ADMIN`：改网络配置
- `CAP_SYS_PTRACE`：调试/注入其他进程
- `CAP_DAC_OVERRIDE`：绕过文件权限检查

沙箱做法：`--cap-drop ALL`，按需加回。注意 user namespace 内的 capability 只对该 namespace 拥有的资源有效。

### 2.5 Landlock —— 非特权文件系统沙箱（Linux 5.13+）

seccomp 管 syscall，但**没法表达"只允许写 /workspace"**（`open` 的参数是路径字符串，BPF 不能解引用指针）。历史上这只能靠 mount namespace + bind mount 或 SELinux/AppArmor。Landlock 补上了这块：

- **非特权进程可以给自己加文件系统访问规则**，无需 root；
- 规则按路径层级（inode）表达：`LANDLOCK_ACCESS_FS_READ_FILE`、`WRITE_FILE`、`EXECUTE`、`MAKE_DIR` 等；
- 可叠加（stackable），只能越来越严；
- 后续内核版本扩展了网络规则（TCP bind/connect，6.7+）与 IPC 隔离。

Codex CLI 的 Linux 沙箱就是 **Landlock（文件）+ seccomp（网络 syscall）** 的组合：不需要 root、不需要 mount namespace，启动开销极小。

### 2.6 bubblewrap —— 原语的打包器

`bwrap`（Flatpak 的底层）把 namespaces + bind mount + seccomp 封装成一条命令：

```bash
bwrap \
  --ro-bind /usr /usr \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --ro-bind /bin /bin \
  --symlink usr/lib /lib64 \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --bind "$PWD/workspace" /workspace \
  --chdir /workspace \
  --unshare-all \
  --share-net \          # 需要网络时保留；断网则去掉并 --unshare-net
  --die-with-parent \
  --new-session \
  /bin/bash
```

效果：独立 mount/pid/net/user namespace，只读系统目录，可写工作区，宿主其余文件不可见。这就是"Linux 版 sandbox-exec"，也是 Claude Code Linux 沙箱的实现基础。

### 2.7 组合拳 = 软沙箱的完整形态

```
bubblewrap / 自研 launcher
 ├─ user namespace      → 沙箱 root ≠ 宿主 root
 ├─ mount namespace     → 独立文件系统视图（只读系统 + 可写工作区）
 ├─ pid namespace       → 看不见宿主进程
 ├─ net namespace       → 断网 / veth + 代理
 ├─ seccomp-bpf         → 禁危险 syscall
 ├─ Landlock            → 细粒度路径规则（可选，与 mount 方案二选一或叠加）
 ├─ capabilities drop   → 去掉全部特权
 └─ cgroups / rlimit    → CPU/内存/进程数上限
```

**这正是 Docker 在做的事**——下一章会看到，容器只是这套组合加上镜像分发和生命周期管理。

---

## 3. Windows 简述

- **AppContainer**：低完整性级别 + capability SID 的访问控制，Edge/UWP 沙箱的基础；
- **Job Object**：资源限制 + 进程组管理；
- **Restricted Token**：剥离 SID/特权。

Agent 生态在 Windows 上通常直接走 WSL2（本质是 Hyper-V 轻量 VM，见第 05 章）或 Docker Desktop，原生软沙箱方案较少。

---

## 4. 软沙箱小结

| | macOS Seatbelt | Linux 原语组合 |
|---|---|---|
| 入口 | `sandbox-exec -f profile.sb` | `bwrap` / 自研 launcher |
| 文件控制 | SBPL 路径规则 | mount ns + bind / Landlock |
| 网络控制 | IP/端口级 | net ns（可完全断网）+ seccomp |
| syscall 过滤 | 按操作类别 | seccomp-bpf，精确到 syscall+参数 |
| 需要 root | 否 | bwrap 用 user ns 则否 |
| 启动开销 | ~ms | ~ms |
| 逃逸条件 | 内核漏洞 | 内核漏洞（user ns 本身也扩大过攻击面） |

**适用判断**：单用户开发机、威胁模型 T1–T2、要求零开销与完整兼容性 → 软沙箱是正确答案。多租户、跑真正敌意的代码 → 继续往第 03/04/05 章走。

## 下一步

[03 容器沙箱：Docker](03-docker.md) —— 同样的原语，为什么"容器不是安全边界"？