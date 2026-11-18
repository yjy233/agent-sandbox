# SWE-bench 学习笔记

Agentic Coding 领域最主流的真实软件工程评测基准。本目录是完整的学习资料，从评测集本身到如何用它驱动 Agent 优化。

## 目录

| 文档 | 内容 |
|---|---|
| [01-benchmark-overview.md](01-benchmark-overview.md) | 评测集全貌：动机、数据构建、任务形式、评分机制、版本家族、榜单演进、局限 |
| [02-instance-and-scoring.md](02-instance-and-scoring.md) | 一条真实实例的完整解剖（django__django-11099），评分流水线细节，"没有裁判"的含义 |
| [03-eval-driven-optimization.md](03-eval-driven-optimization.md) | 如何用评测驱动 Agent 优化与进化：脚手架迭代、推理时搜索、RFT/RLVR、数据飞轮、防坑 |
| [04-agentless-and-scaffold.md](04-agentless-and-scaffold.md) | Agent vs Agentless：控制流归谁、ACI 设计、为什么死板流水线能打赢自主 Agent |

## 30 秒速览

- **是什么**：拿真实 GitHub issue + 修复前的仓库快照考模型，要求生成补丁让测试通过。2,294 题，12 个 Python 仓库，普林斯顿 2023.10 发布。
- **怎么判分**：纯执行式。Docker 里 apply 模型补丁 → 跑 FAIL_TO_PASS（修好 bug）+ PASS_TO_PASS（没改坏别的）→ 全过才算解决。**没有 LLM 裁判，没有人工评审，不和标准答案比对文本**。
- **常用版本**：SWE-bench Verified（500 题，OpenAI 合作人工校验，业界事实标准）；2026 年已趋饱和（头部模型 90%+），前沿转向 SWE-bench Pro。
- **核心价值**：单测通过与否是免费、客观、可规模化的信号，可以接到三个飞轮上——改脚手架（天级）、微调/RL（周级）、自动造题（持续供给）——驱动 Agent 持续进化。
- **最大的坑**：reward hacking（骗过测试 ≠ 修好 bug）、基准过拟合、数据污染。必须用隔离环境 + 留出集。

## 关键资源

- 论文：SWE-bench: Can Language Models Resolve Real-World GitHub Issues? (arXiv:2310.06770)
- 代码/评测框架：https://github.com/SWE-bench/SWE-bench （pip 包 `swebench`）
- 数据集：Hugging Face `princeton-nlp/SWE-bench`、`princeton-nlp/SWE-bench_Verified`
- 排行榜：https://www.swebench.com
- 相关脚手架：SWE-agent、OpenHands、Agentless、mini-SWE-agent
- 相关训练工作：SWE-Gym、SWE-smith、R2E-Gym、SWE-RL、DeepSWE