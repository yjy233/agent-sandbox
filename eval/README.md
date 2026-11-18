# eval

Agent 评测相关实验目录。当前收录：LongMemEval 数据集介绍。

## LongMemEval 数据集

**LongMemEval: Benchmarking Chat Assistants on Long-Term Interactive Memory**（Wu et al., ICLR 2025，UCLA + 腾讯 AI Lab）是评估聊天助手**长期交互记忆**能力的标准基准：给定用户与助手跨多个会话的历史对话，考察系统能否正确记录、召回、更新和推理其中的信息。

- 论文：<https://arxiv.org/abs/2410.10813>
- 代码：<https://github.com/xiaowu0162/LongMemEval>
- 数据：<https://huggingface.co/datasets/xiaowu0162/longmemeval>（另有 `longmemeval-cleaned` 清洗版）

### 核心设定

- **500 道人工精修问题**，每题附带证据会话（evidence sessions）与标准答案。
- 测试时把证据会话埋入大量无关会话组成的"干草堆"历史中，长度可配置：
  - **LongMemEval_S**：约 115K tokens（约 40~50 个会话/题）
  - **LongMemEval_M**：约 500 个会话、1.5M tokens/题
- 每个会话带时间戳，支持时序类问题。

### 五大能力 × 七种题型

| 题型 | 能力 | 考察点 |
| --- | --- | --- |
| single-session-user | 信息抽取 | 回忆单个会话中用户说过的事实 |
| single-session-assistant | 信息抽取 | 回忆助手自己之前的回复内容 |
| single-session-preference | 信息抽取 | 从会话中推断用户隐性偏好 |
| multi-session | 多会话推理 | 跨多个会话连接、综合事实 |
| knowledge-update | 知识更新 | 信息随时间变化时以最新值为准 |
| temporal-reasoning | 时间推理 | 基于时间戳做时序推断 |
| abstention（各题型的 `_abs` 变体） | 拒答 | 信息从未出现时应回答"不知道"而非编造 |

### 评分方式

主要用 **LLM-as-judge** 按题型判定答案正确性（官方仓库提供逐题型的 judge prompt），拒答题单独统计。注意：不同系统的 judge 模型与评测协议不同，分数不能直接横比。

### 关键结论

- 商业聊天助手和长上下文 LLM 在持续交互中准确率下降约 **30%**——长上下文不能替代记忆系统。
- 论文提出记忆设计三阶段框架：**索引（indexing）→ 检索（retrieval）→ 阅读（reading）**，并给出优化手段：值粒度的会话分解、事实增强的键扩展、时间感知的查询扩展。

### 快速上手

```bash
git clone https://github.com/xiaowu0162/LongMemEval.git
cd LongMemEval
# 数据从 HuggingFace 下载（longmemeval_s_cleaned.json 等）
# 每条样本字段：question / answer / question_type / question_date
#              haystack_sessions（含时间戳的会话列表）/ answer_session_ids（证据指针）
```

典型评测流程：对每题的历史做索引与检索 → 拼 prompt 让被测模型作答 → 用官方 judge prompt 打分，按题型汇总准确率。