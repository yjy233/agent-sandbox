# Lab 06 · 统一沙箱封装 mini-sandbox（macOS 本机可跑）

对应文档：[docs/06 Agent 沙箱工程实践](../../docs/06-agent-practice.md)。

## 目标

把 lab01–05 的知识收敛成一个最小可用的统一接口：

```
policy（意图：工作区在哪、额外读哪些路径）
   │
   ▼
sandbox.run(cmd, policy)
   ├─ macOS → 生成 SBPL profile → sandbox-exec
   └─ Linux → 组装 bwrap 参数
```

这就是 E2B/Modal 这类产品 SDK 的"婴儿版"：**调用方只声明策略，不关心底层隔离机制**。

## 运行

```bash
bash examples/lab06-mini-sandbox/run.sh          # 跑全部测试（平台不符自动 skip）

# CLI 体验：
cd examples/lab06-mini-sandbox
python3 sandbox.py --policy policy.json -- /bin/echo hello
python3 sandbox.py --policy policy.json -- /bin/cat ~/.ssh/id_rsa   # 应失败
```

## 测试分层（做一点测一点）

| 层 | 用例 | 平台 |
|----|------|------|
| step1 纯逻辑 | policy → profile：deny default / 工作区规则 / 断网 / extra_read_paths | 全平台 |
| step2 能跑 | echo 正常输出 | macOS / Linux |
| step3 写限制 | 工作区内可写、外不可写 | macOS / Linux |
| step4 读+网 | 密钥不可读、外网不可达 | macOS / Linux |

## 文件

```
sandbox.py        封装本体（~130 行）：build_profile / build_command / run / CLI
policy.json       示例策略
test_sandbox.py   unittest，按平台 skip
```

## 扩展练习（朝生产形态演进）

1. **网络白名单**：policy 加 `network: {allow_domains: [...]}`，macOS 后端改为"强制走本地代理"，Linux 后端用 netns+veth；
2. **资源限额**：policy 加 `timeout/memory/pids`，macOS 用 `ulimit` 包装，Linux 用 `bwrap --unshare-cgroup` + systemd-run；
3. **审计**：run() 记录命令、退出码、耗时到 JSONL；
4. **后端扩展**：加 docker/runsc/firecracker 后端，policy 不变——体会"策略与机制分离"。