# 01 · SWE-bench 评测集全貌

## 1. 背景与动机

### 1.1 早期代码评测的问题

在 SWE-bench 之前，代码能力评测的主流是：

- **HumanEval / MBPP**：给函数签名 + docstring，写一个独立小函数，跑几个单测。
- **竞赛题（APPS、CodeContests、LiveCodeBench）**：算法题，输入输出明确。

这些评测的共同缺陷：**与真实软件工程几乎不重叠**。真实开发是：

- 在几十万行的已有代码库里工作，而不是从零写函数；
- 需求是模糊的自然语言 bug 报告，而不是精确的规格说明；
- 要跨文件理解调用链、遵守项目惯例、不破坏已有功能；
- 修改量可能只有两行，但定位这两行需要大量探索。

### 1.2 SWE-bench 的核心思想

普林斯顿团队（John Yang、Carlos Jimenez 等，2023 年 10 月，ICLR 2024 oral）提出：

> **直接拿 GitHub 上真实的 issue + 真实的修复 PR 来考模型。**

给模型一个完整仓库（修复前的 commit）和一个 issue 描述，要求生成补丁。判分不靠人看、不靠 LLM 评，靠**执行真实项目的测试套件**。

这一定义后来成为 "Agentic Coding" 评测的范式：任务真实、环境可执行、结果可验证。

## 2. 数据集构建

### 2.1 来源

12 个热门 Python 开源仓库：

| 仓库 | 领域 | Full 中题数（约） |
|---|---|---|
| django | Web 框架 | 850 |
| sympy | 符号数学 | 386 |
| scikit-learn | 机器学习 | 229 |
| sphinx | 文档生成 | 187 |
| matplotlib | 绘图 | 184 |
| pytest / pylint / astropy / requests / xarray / seaborn / pandas 等 | 其他 | 其余 |

注意分布高度集中：**Django + SymPy 占约 54%**。这意味着 Full/Verified 的分数很大程度上是"在这两个代码库上修 bug 的能力"。

### 2.2 挖掘流程

一个 PR 要成为考题，必须满足：

1. **关联并关闭了某个 issue**（有自然语言的问题描述）；
2. **同时修改了源码和测试**（测试是判分的依据，没有测试的 PR 无法构造判据）；
3. 能在 base commit（PR 合并前的仓库状态）上重建可运行环境；
4. 测试行为符合"修复前红、修复后绿"：
   - 在 base commit 上应用 PR 的测试部分（test_patch）→ 新测试**失败**；
   - 再应用 PR 的源码部分（gold patch）→ 新测试**通过**；
   - 其余相关测试前后都通过。

最终得到 **2,294 个任务实例**。每个实例包含：

```
instance_id        如 django__django-11099
repo / base_commit 仓库与修复前快照
problem_statement  issue 原文（标题+正文）
patch              gold patch（官方修复，评分时不使用）
test_patch         官方 PR 附带的测试改动
FAIL_TO_PASS       修复前失败、修复后须通过的测试列表
PASS_TO_PASS       前后都须通过的测试列表（防回归）
environment_setup_commit  环境搭建参考
```

### 2.3 难度分布（以 Verified 为例）

数据集自带人工标注的难度字段：

- < 15 分钟：194 题
- 15 分钟 ~ 1 小时：261 题
- 1 ~ 4 小时：42 题
- > 4 小时：3 题

即 **455/500 的题人类专家 1 小时内可解**——这是"偏轻"批评的依据，也是后来 SWE-bench Pro 主打长时程复杂任务的原因。

## 3. 任务形式与评测流程

### 3.1 输入 / 输出

- **输入**：base commit 的完整仓库 + issue 文本。模型/Agent 可以自主浏览代码、检索、（部分设置下）执行命令。
- **输出**：一个 unified diff 补丁。评测只认这个补丁，不认过程。

### 3.2 评测流水线（官方 harness）

```
1. Docker 容器：检出 base commit，按该仓库当年的依赖版本搭环境
2. 应用模型生成的补丁（git apply / patch）
   - apply 失败 → 直接判 0（连编译/导入都过不了）
3. 应用官方 test_patch（强制覆盖测试文件，模型改/删测试无效）
4. 运行测试：
   - FAIL_TO_PASS：全部必须由红转绿
   - PASS_TO_PASS：全部必须保持绿
5. 两类全过 → resolved = 1；否则 0
```

### 3.3 指标

- **% Resolved（解决率）**：主指标，resolved 实例占比。
- 辅助报告：apply 成功率、平均成本（token/美元）、平均步数。
- 研究场景常用 **pass@k**（k 次采样至少一次成功）与 **pass^k**（k 次全部成功，衡量稳定性）。榜单一般报 pass@1。

### 3.4 关键性质：没有裁判

- 没有 LLM-as-judge，没有人工评审；
- **不和 gold patch 做文本/语义相似度比对**。gold patch 只在造数据集时用于验证题目有效性；
- 判据是**行为正确**：修法可以和官方完全不同，测试全绿即算对。

优点：客观、可复现、零评分成本、可规模化（这正是它能当 RL reward 的原因）。
缺点：测试不完备时可被钻空子（详见 02 文档的 reward hacking 部分）。

## 4. 版本家族

| 版本 | 时间 | 规模 | 说明 |
|---|---|---|---|
| **SWE-bench (Full)** | 2023.10 | 2,294 | 原始全集 |
| **SWE-bench Lite** | 2024.3 | 300 | 筛掉描述不清、含图片、超难实例；降低成本，曾是常用开发集 |
| **SWE-bench Verified** | 2024.8 | 500 | 与 OpenAI 合作，93 名人类标注员逐条校验：问题清晰、测试正确、任务可解。取代 Lite 成为**业界事实标准**，厂商发布会都报这个分 |
| **SWE-bench Multimodal** | 2024.10 | 517 | JS 可视化库（如 Chart.js 相关），issue 含截图/设计稿，考多模态理解 |
| **SWE-bench Multilingual** | 2025 | 300 | 9 种语言（C/C++/Java/Go/Rust/JS/TS/PHP/Ruby 等）、42 个仓库，打破 Python 独占 |
| **SWE-bench Pro** | 2025.9 (Scale AI) | 1,865（公开集 731） | 更难的企业级任务：41 个活跃维护仓库、多文件长时程修改、刻意选 copyleft 之外的许可以降低训练污染。发布时顶级模型 <25% |
| **SWE-bench Live / 衍生** | 2025~ | 持续 | 持续从新 PR 抽题防污染；另有 Bash Only、SWE-rebench 等变体 |

### Verified 的构成细节

500 题中 Django 231 题（46%）、SymPy 75 题，两者合计 61%。所以 Verified 高分 ≈ "Django/SymPy 修 bug 强"，外推要谨慎。

## 5. 成绩演进（2023 → 2026）

| 阶段 | 代表 | Verified 大致水平 |
|---|---|---|
| 2023 发布时 | Claude 2 + 简单检索脚手架 | ~2% |
| 2024 上半年 | SWE-agent、Agentless、OpenHands 等 Agent 化 | 20~40% |
| 2024 下半年~2025 | Claude 3.5/3.7、GPT-4o/o1 系 + 成熟脚手架 | 50~70% |
| 2025~2026 | Claude 4.x/5、GPT-5/6 系、Gemini 3 系 | 70~90%+ |
| 2026 | 头部模型（如 Claude Opus 5 自报 96%） | **接近饱和** |

2026 年的共识与争议：

- OpenAI Frontier Evals 团队公开指出 Verified "实际上已饱和且高度被污染"，并发现其中相当比例题目存在测试缺陷，宣布不再以其为核心评估标准；
- 出现过刷榜案例：某 Agent 在 Verified 拿高分，但真实任务解决 0 个（利用环境未隔离的漏洞）；
- 行业重心转向 **SWE-bench Pro**（2026 年顶级模型约 80~90%，开源最好约 67%）、Terminal-Bench 等更难/更防污染的基准。

**读榜注意事项**：分数多为厂商自报；脚手架、思考预算、工具配置不同，分数不可直接横比；同一模型换 Agent 框架分差可达十几个点。比较时先看"同脚手架同配置"的第三方复测。

## 6. 局限与争议（汇总）

1. **污染**：题目来自公开 GitHub，gold patch 大概率进了各家训练集。
2. **测试不完备**：通过测试 ≠ 正确修复，存在应试式/作弊式解法空间。
3. **语言/领域偏窄**：原始集纯 Python，一半是 Django/SymPy。
4. **任务类型偏 bug 修复**：新功能开发、重构、跨服务改动、代码评审覆盖不足。
5. **难度偏轻**：多数题人类 1 小时内可解，与真实企业级长时程任务有差距。
6. **环境脆弱**：老仓库依赖重建困难，Docker 镜像维护成本高；环境隔离不足会被利用。

这些局限正是 Multilingual / Pro / Live 等后续版本各自试图修补的方向。

## 7. 上手指南

### 7.1 获取数据

```python
from datasets import load_dataset
ds = load_dataset("princeton-nlp/SWE-bench_Verified", split="test")
print(ds[0].keys())
```

### 7.2 官方评测

```bash
pip install swebench

# 对预测文件跑评测（predictions 为 jsonl：instance_id + model_patch）
python -m swebench.harness.run_evaluation \
    --dataset_name princeton-nlp/SWE-bench_Verified \
    --predictions_path predictions.jsonl \
    --max_workers 4 \
    --run_id my-first-run
```

需要本机 Docker。每题一个容器，Full 集跑一遍的镜像/算力成本不小，开发期建议用 Lite 或自抽小子集。

### 7.3 常用脚手架

- **mini-SWE-agent**：极简 bash-only Agent，适合做研究基线；
- **SWE-agent**：ACI（Agent-Computer Interface）设计的代表作；
- **OpenHands**：功能完整的开源 Agent 平台；
- **Agentless**：固定流水线，无自主循环（见 04 文档）。

### 7.4 建议的最小实验

1. 抽 Lite 中 20~30 题；
2. 用一个开源脚手架 + 你能调用的模型跑一遍；
3. 人工归类失败轨迹（定位错/改错/回归/格式错/空转）；
4. 针对最大失败类别改一处设计，复测对比。

这就是"评测驱动优化"的最小闭环，详见 03 文档。