# agent-sandbox

AI Agent 沙箱技术教学项目：自上而下讲清楚从 OS 软沙箱到虚拟机的隔离技术，并提供可动手的实验。

## 文档

从 [docs/README.md](docs/README.md) 开始，按顺序阅读：

1. [总览：Agent 为什么需要沙箱](docs/01-overview.md)
2. [OS 级软沙箱（macOS sandbox-exec / Linux seccomp、Landlock、bwrap）](docs/02-os-sandbox.md)
3. [容器沙箱：Docker](docs/03-docker.md)
4. [用户态内核：gVisor](docs/04-gvisor.md)
5. [虚拟机与 MicroVM（Firecracker / Kata / QEMU）](docs/05-vm.md)
6. [Agent 沙箱工程实践与选型](docs/06-agent-practice.md)

## 实验（规划中）

`examples/` 目录将按文档顺序提供可运行 demo，见 [docs/06 第 5 节](docs/06-agent-practice.md) 的动手路线。