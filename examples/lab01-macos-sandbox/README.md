# Lab 01 · macOS sandbox-exec（本机可跑）

对应文档：[docs/02 OS 级软沙箱](../../docs/02-os-sandbox.md) 第 1 节。

## 目标

用 5 个递进步骤，亲手把一个"默认拒绝一切"的 Seatbelt profile 演进成可用的 Agent 沙箱，**每一步都有自动断言验证**。

## 运行

```bash
bash examples/lab01-macos-sandbox/run.sh        # 顺序跑全部步骤，失败即停
bash examples/lab01-macos-sandbox/steps/step3.sh  # 单独跑某一步
```

要求：macOS（自带 `/usr/bin/sandbox-exec`），无需安装任何东西。

## 步骤设计（做一点测一点）

| 步骤 | profile 改动 | 验证点 |
|------|-------------|--------|
| step1 | `(deny default)` | 连 `/usr/bin/true` 都无法执行，报 Operation not permitted |
| step2 | +`process-exec/fork` +`file-read*` +`sysctl-read` | echo/cat 能跑；写仍被拒 |
| step3 | +`file-write* (subpath WORKSPACE)`，`-D` 传参 | 工作区内可写；`/tmp`、`$HOME` 不可写 |
| step4 | +显式 `(deny network*)` | TCP 连 1.1.1.1:443 失败；本地计算正常 |
| step5 | 读收紧到系统目录+工作区；+信号限制 | 完整验收：可干活、密钥不可读、外网不可达 |

## 文件说明

```
profiles/step1-deny-all.sb        最小拒绝
profiles/step2-can-run.sb         能跑起来
profiles/step3-workspace-write.sb 工作区可写（param WORKSPACE）
profiles/step4-no-network.sb      断网
profiles/step5-agent.sb           完整 Agent profile
steps/stepN.sh                    每步的演示 + 断言
workspace/                        沙箱唯一可写目录（运行时生成内容）
```

## 调试技巧

profile 缺规则时进程会莫名失败甚至 Abort trap。看内核 deny 日志定位：

```bash
/usr/bin/log show --last 2m --predicate 'sender == "Sandbox"' --style compact | grep deny
# 或实时：
/usr/bin/log stream --predicate 'sender == "Sandbox"' --style compact
```

本 lab 实测踩过的两个坑（已写进 step5 profile 注释）：

1. 路径解析需要读根目录与目录元数据 → `(allow file-read-metadata)` + `(allow file-read* (literal "/"))`；
2. `/usr/bin/python3` 是 CommandLineTools 的 shim → 必须放行 `/Library/Developer` 读。

## 思考题

- step5 允许读 `/private/etc`，里面有什么敏感内容？该怎么收紧？
- 为什么"断网"还不够防数据外传？（提示：DNS、允许的代理出口，见 docs/06）
- 把 step5 的 `file-read*` 改成只放行工作区，`/bin/echo` 还能跑吗？为什么？