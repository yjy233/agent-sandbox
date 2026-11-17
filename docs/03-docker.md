# 03 容器沙箱：Docker

## 1. 容器 = 第 02 章原语的产品化

Docker 没有发明新的隔离机制。一个容器就是：

```
docker run
 ├─ namespaces（mount/pid/net/ipc/uts/user/cgroup）  → 视图隔离
 ├─ cgroups                                        → CPU/内存/IO/进程数配额
 ├─ capabilities 白名单（默认保留 ~14 个）          → 特权裁剪
 ├─ seccomp 默认 profile（禁 ~44 个 syscall）       → syscall 过滤
 ├─ AppArmor / SELinux（发行版相关）                → MAC 加固
 ├─ overlayfs 镜像分层                              → 文件系统打包与分发
 └─ runc（OCI runtime）                             → 按 config.json 拉起进程
```

调用链：`docker CLI → dockerd → containerd → containerd-shim → runc → 容器进程`。

与裸软沙箱相比，容器额外解决的是**环境一致性**（镜像）与**生命周期管理**，而不是更强的隔离。

## 2. 默认配置并不安全

`docker run ubuntu` 的默认状态：

- 容器内是 **root**（虽然被 capabilities/seccomp 限制，但容器内 root 对挂载进来的文件有完全权力）；
- 保留 `CAP_NET_RAW`（可抓包/ARP 欺骗）、`CAP_SETUID` 等；
- 网络默认 bridge，**可以访问外网和内网**；
- 可以读容器内全部文件，包括你挂载进去的任何东西；
- 与宿主**共享内核**。

对"跑自己写的服务"这够了；对"跑 LLM 生成的不可信代码"远远不够。

## 3. 面向不可信代码的加固模板

```bash
docker run --rm -it \
  --network none \                          # 完全断网（需要网络见下文）
  --read-only \                             # 根文件系统只读
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \  # 唯一可写区，且禁执行
  --cap-drop ALL \                          # 去掉全部 capabilities
  --security-opt no-new-privileges \        # 禁止 setuid 提权
  --security-opt seccomp=profile.json \     # 更严的自定义 seccomp（可选）
  --pids-limit 128 \                        # 防 fork 炸弹
  --memory 512m --memory-swap 512m \        # 内存上限（禁 swap 逃逸配额）
  --cpus 1.0 \                              # CPU 上限
  --user 1000:1000 \                        # 非 root 运行
  --workdir /workspace \
  -v "$PWD/workspace:/workspace:rw" \       # 只挂工作区，绝不挂 $HOME
  python:3.12-slim python /workspace/main.py
```

需要网络时，不要用默认 bridge，而是：

```bash
# 方案 A：内部网络 + 显式代理
docker network create --internal sandbox-net   # internal = 无默认出口
docker run --network sandbox-net \
  -e HTTPS_PROXY=http://proxy:8080 ...
# 代理容器做域名白名单（见第 06 章）

# 方案 B：独立 netns + iptables 出口白名单（自建编排时）
```

### 绝对禁止清单

| 配置 | 后果 |
|------|------|
| `-v /var/run/docker.sock:/var/run/docker.sock` | 等于给容器宿主 root：可再起一个 privileged 容器挂载宿主根目录 |
| `--privileged` | 关闭几乎所有隔离，设备全开 |
| `--pid=host` / `--network=host` | 共享宿主进程/网络空间 |
| `-v /:/host`、`-v ~/.ssh:...` | 把要保护的东西直接送进去 |
| `--cap-add SYS_ADMIN` | 允许 mount 等，大量逃逸路径的前提 |
| 透传宿主环境变量（`--env-file .env`） | 密钥直接泄露给不可信代码 |

## 4. 为什么"容器不是安全边界"

### 4.1 共享内核 = 共享攻击面

容器进程与宿主内核之间只隔着一层 seccomp/capability 过滤，**仍有 300 多个 syscall 直达宿主内核**。内核任何一个可达漏洞都可能被用来逃逸：

| 漏洞 | 说明 |
|------|------|
| CVE-2019-5736（runc） | 覆写宿主 runc 二进制，容器内获得宿主 root |
| CVE-2022-0185（fsconfig 堆溢出） | user namespace 内可触发，容器逃逸 |
| CVE-2022-0847（Dirty Pipe） | 覆写只读文件/page cache，容器内改宿主文件 |
| CVE-2024-21626（runc fd 泄漏） | 利用泄漏的宿主 fd 访问宿主文件系统 |

注意其中多个漏洞的触发前提恰恰是"容器默认开启的 user namespace / 默认保留的 syscall"。

### 4.2 默认 seccomp 是兼容性优先

Docker 默认 profile 的目标是"绝大多数软件能跑"，不是"最小攻击面"。它放行了 `clone`、`unshare`、`bpf` 之外的大量复杂 syscall（io_uring 近年就是逃逸漏洞高发区，新内核已默认禁）。

### 4.3 结论

- 对 **T1–T2**（防误操作、防普通不可信代码）：加固后的容器可用，且工程上最省事；
- 对 **T3**（多租户、敌意代码、合规要求）：共享内核方案不达标，需要 gVisor（第 04 章）或 VM（第 05 章）。

业界共识表述（Kubernetes 文档原话大意）：*容器提供的隔离不足以安全地运行来自不同信任域的负载。*

## 5. 降低风险的补充手段

- **Rootless Docker / Podman**：dockerd 本身以普通用户跑，daemon 被打穿也不是宿主 root。Podman 无 daemon、默认 rootless，跑不可信代码比 Docker 更合适；
- **userns-remap**：容器 root 映射为宿主无特权 UID（Docker 需显式开启；Podman rootless 天然如此）；
- **每会话一次性容器**：`--rm` + 不复用，限制驻留时间；
- **只读镜像 + 最小基础镜像**（distroless/slim）：减少沙箱内可用的攻击工具；
- **gVisor 作为 runtime**：`docker run --runtime=runsc`，容器体验不变，隔离升级——这正是下一章。

## 6. 动手实验建议

1. 用默认配置起容器，在容器内 `cat /proc/1/cgroup`、`ls /dev`、`ping 169.254.169.254`，观察默认暴露面；
2. 换成第 3 节加固模板，重复同样操作，记录差异；
3. 挂载一个含假密钥的目录，写一段"读取并外传"的脚本，验证 `--network none` + 不挂载敏感目录的效果；
4. （可选）对比 `docker` 与 `podman --rootless` 的 `/proc/self/uid_map`。

## 下一步

[04 用户态内核：gVisor](04-gvisor.md) —— 保持容器的使用方式，把内核攻击面缩小一个数量级。