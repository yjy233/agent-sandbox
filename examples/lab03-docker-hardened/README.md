# Lab 03 · Docker 加固（需 Docker）

对应文档：[docs/03 容器沙箱](../../docs/03-docker.md)。

## 目标

亲眼看到"默认容器"与"加固容器"的差距，并验证资源限制真的生效。

## 运行

```bash
bash examples/lab03-docker-hardened/run.sh
```

需要 docker daemon 运行中。macOS：Docker Desktop 或 `brew install colima docker && colima start`。

## 步骤设计

| 步骤 | 内容 | 验证点 |
|------|------|--------|
| step1 | 默认容器暴露面 | 容器内是 root；有 eth0 路由（可出网） |
| step2 | 加固模板（docs/03 第 3 节） | 非 root；/etc 只读；工作区可写；断网 |
| step3 | 资源限制 | pids-limit 触发 fork 失败；tmpfs 限额阻止 100MB 写入 |
| step4 | 完整验收 | 密钥/docker.sock 不可见；断网；可正常干活 |

## 思考题

- step2 的加固能防住内核 0day 逃逸吗？（不能——这正是 lab04/lab05 的动机）
- 为什么 `--memory-swap` 要设成和 `--memory` 一样？
- 把 `-v "$WS:/workspace"` 换成 `-v "$HOME:/workspace"` 会发生什么？（别在真机上试）