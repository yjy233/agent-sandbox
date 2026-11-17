# Lab 02 · Linux bubblewrap（需 Linux）

对应文档：[docs/02 OS 级软沙箱](../../docs/02-os-sandbox.md) 第 2 节。

## 目标

用 bwrap 复刻 lab01 的演进路线，理解 Linux 沙箱 = namespaces + bind mount 的组合。

## 环境准备

需要 Linux + `bubblewrap`。macOS 上用 Lima：

```bash
brew install lima
limactl start template://ubuntu-lts     # 首次会下载镜像，几分钟
limactl shell ubuntu-lts
sudo apt-get update && sudo apt-get install -y bubblewrap
# 把仓库拷进 VM 或 git clone，然后：
bash examples/lab02-linux-bwrap/run.sh
```

> 注意：Lima 默认把宿主 HOME 共享进 VM，这不影响实验——沙箱的边界在 bwrap 这一层，不在 VM 层。

## 步骤设计

| 步骤 | 改动 | 验证点 |
|------|------|--------|
| step1 | `--unshare-pid` | 沙箱内 shell PID ≤ 5；/proc 是新空间 |
| step2 | `--ro-bind / /` + `--bind WS /workspace` | 工作区可写；/etc、HOME 不可写 |
| step3 | 只 bind 系统目录（视图裁剪） | /home、/root 直接不存在 |
| step4 | `--unshare-net` | /dev/tcp 外连失败；本地计算正常 |
| step5 | `--unshare-all --new-session --die-with-parent` | 完整验收：可干活、密钥不可见、断网 |

## 与 lab01 的关键差异

- macOS Seatbelt：**文件都在，访问被拒**（deny 日志可见）；
- Linux bwrap：**文件直接不可见**（mount namespace 换了视图）。
  后者对不可信代码更友好——程序不会因为"文件存在但读不了"而行为异常。

## 进阶练习（未含在自动测试中）

1. 加 seccomp：`bwrap --seccomp <fd>` 需要传 BPF 程序 fd，参考 Flatpak 源码或用 `bwrap --json-status-fd` 观察；
2. 加 Landlock：写一个 C/Python launcher，在 bwrap 之外叠加路径级规则（对照 Codex CLI 的做法）；
3. 用 `--share-net` + 代理环境变量复刻 docs/06 的"强制走代理"模式。