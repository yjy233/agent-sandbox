# 动手实验（examples）

与 [docs](../docs/README.md) 各章一一对应，**每个 lab 拆成递进步骤，每步都有自动断言——做一点测一点**。

## 一键运行

```bash
bash examples/run-all.sh                 # 全部 lab，环境不满足自动 SKIP
bash examples/lab01-macos-sandbox/run.sh # 单独跑某个 lab
```

## Lab 一览

| Lab | 对应文档 | 环境要求 | 本机(macOS)状态 |
|-----|---------|---------|----------------|
| [lab01 macOS sandbox-exec](lab01-macos-sandbox/README.md) | docs/02 §1 | macOS 自带 | ✔ 已实测通过（19 断言） |
| [lab02 Linux bwrap](lab02-linux-bwrap/README.md) | docs/02 §2 | Linux + bubblewrap（可用 Lima） | SKIP，脚本就绪 |
| [lab03 Docker 加固](lab03-docker-hardened/README.md) | docs/03 | Docker daemon | SKIP，脚本就绪 |
| [lab04 gVisor](lab04-gvisor/README.md) | docs/04 | Linux + Docker + runsc | SKIP，脚本就绪 |
| [lab05 Firecracker](lab05-firecracker/README.md) | docs/05 | Linux + /dev/kvm + firecracker | SKIP，脚本就绪 |
| [lab06 统一封装 mini-sandbox](lab06-mini-sandbox/README.md) | docs/06 | python3（macOS/Linux） | ✔ 已实测通过（9 用例） |

## 设计约定

- **步骤脚本** `steps/stepN.sh`：先演示一条命令，再跑 `expect_*` 断言；任何断言失败该步退出非 0；
- **lab 入口** `run.sh`：顺序执行各步，失败即停；环境不满足打印 SKIP + 安装指引，退出 0；
- **断言库** [lib/assert.sh](lib/assert.sh)：`expect_ok / expect_fail / expect_output / expect_no_output / require_cmd / require_linux / require_macos`；
- **运行时产物**（workspace/、快照、日志）都在各 lab 的 .gitignore 中，不入库。

## 推荐学习路径

1. macOS 用户：lab01 → lab06（本机即可完成闭环）；
2. 装 Lima 起 Ubuntu VM：lab02 → lab03（VM 内装 docker）；
3. 有 Linux 裸机/嵌套虚拟化云主机：lab04 → lab05；
4. 回到 lab06 做扩展练习：网络白名单、资源限额、审计、docker/firecracker 后端。