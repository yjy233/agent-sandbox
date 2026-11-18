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

---

## 具体例子：一道题从作答到评分

### 1. 数据长什么样（knowledge-update 题，按官方字段简化）

```json
{
  "question_id": "e47becba",
  "question_type": "knowledge-update",
  "question": "What car do I currently drive?",
  "answer": "A Tesla Model 3",
  "question_date": "2023/05/30 (Tue) 14:20",
  "haystack_dates": ["2023/01/10 (Tue) 09:15", "2023/04/02 (Sun) 16:40", "...共约40个会话"],
  "haystack_sessions": [
    [{"role": "user", "content": "I just bought a Honda Civic, so excited!"},
     {"role": "assistant", "content": "Congrats! The Civic is a great choice..."}],
    [{"role": "user", "content": "I traded in my Civic for a Tesla Model 3 last week.", "has_answer": true},
     {"role": "assistant", "content": "Welcome to the EV world!..."}],
    ["...其余为无关填充会话"]
  ],
  "answer_session_ids": ["session_20230402"]
}
```

关键点：旧信息（Civic）和新信息（Model 3）都在历史里，系统必须以**最新值**作答。`has_answer: true` 标记证据 turn，`answer_session_ids` 标记证据会话——这两个字段用来单独评检索。

### 2. 被测系统输出（jsonl，每行两字段）

```json
{"question_id": "e47becba", "hypothesis": "You currently drive a Tesla Model 3, which you got in April 2023 after trading in your Honda Civic."}
```

### 3. 官方 judge 怎么打分

`src/evaluation/evaluate_qa.py` 按题型选 prompt，交给 GPT-4o（temperature=0，max_tokens=10），输出含 "yes" 即记 1 分，否则 0 分。knowledge-update 题的实际 prompt（官方原文）：

```text
I will give you a question, a correct answer, and a response from a model.
Please answer yes if the response contains the correct answer. Otherwise,
answer no. If the response contains some previous information along with an
updated answer, the response should be considered as correct as long as the
updated answer is the required answer.

Question: What car do I currently drive?
Correct Answer: A Tesla Model 3
Model Response: You currently drive a Tesla Model 3, ... after trading in your Honda Civic.

Is the model response correct? Answer yes or no only.
```

→ judge 输出 `yes`（提到旧车 Civic 不扣分，只要最新答案在）。若系统答 "You drive a Honda Civic" → `no`，典型的知识更新失败。

各题型 judge 规则差异（都来自官方脚本）：

| 题型 | 判分规则 |
| --- | --- |
| single-session-user / assistant / multi-session | 答案完整包含才 yes；只答出子集算 no；等价表述或含完整中间步骤算 yes |
| temporal-reasoning | 同上，但天数/周数差 1（off-by-one）不扣分 |
| knowledge-update | 只要更新后的答案在就算对，允许同时提及旧值 |
| single-session-preference | answer 是 rubric 而非标准答案；不要求覆盖全部要点，正确利用了用户偏好即 yes |
| abstention（`question_id` 带 `_abs`） | 单独 prompt：模型是否正确识别"该问题无法回答"（说信息不足即可） |

运行方式：

```bash
export OPENAI_API_KEY=...
python3 src/evaluation/evaluate_qa.py gpt-4o your_hypothesis.jsonl data/longmemeval_s_cleaned.json
# 输出总准确率 + 按题型准确率，逐题判定写入 *.eval-results-gpt-4o
```

### 4. 检索单独评分（定位问题在哪一层）

QA 分数低有两种可能：**没检索到证据**（检索问题）或**检索到了但答错**（阅读/推理问题）。数据集自带的标注可以把两层拆开：

- **会话级 Recall@k**：检索出的 top-k 会话是否覆盖 `answer_session_ids`；
- **Turn 级 Recall@k**：是否覆盖 `has_answer: true` 的 turn；
- 30 道拒答题没有证据位置，评检索时跳过（官方脚本如此处理）。

```bash
python3 src/retrieval/run_retrieval.sh data/longmemeval_s_cleaned.json flat-stella session
python3 src/evaluation/print_retrieval_metrics.py retrieval_logs/xxx.log
```

另一个关键对照：**oracle 版数据**（`longmemeval_oracle.json`）只含证据会话。先在 oracle 上跑 QA——这是"检索满分"时系统能力的上界；oracle 与 S 版的分差就是检索层造成的损失。

## 根据评分迭代优化

推荐的循环：**先分层定位 → 按题型找短板 → 改一个变量 → 重跑对照**。

### 第一步：三层归因

```text
oracle QA 分低                → 阅读/推理层问题（检索无关）
oracle 高、S 版低、Recall@k 低 → 检索层问题
oracle 高、S 版低、Recall@k 高 → 阅读层被无关上下文干扰（噪声鲁棒性）
```

### 第二步：按题型对症下药（手段均为官方仓库自带）

| 短板信号 | 优化手段 | 对应代码/参数 |
| --- | --- | --- |
| Recall@k 低（会话粒度漏证据） | 索引粒度从 session 改 turn（值粒度分解） | `run_retrieval.sh ... turn` |
| Recall@k 低（用户口语化表述检索不中） | 键扩展：给索引追加用户事实/关键短语/摘要作为 key | `src/index_expansion/batch_expansion_session_userfact.py` 等，`EXPANSION_TYPE=turn-userfact`，`JOIN_MODE=separate/merge/replace` |
| temporal-reasoning 准确率低 | 时间感知查询扩展：抽取带时间戳事件，从问题推断时间范围，剪枝搜索空间 | `src/index_expansion/temp_query_search_pruning.py` |
| knowledge-update 准确率低 | 检索结果保留时间戳并在 prompt 中按时间排序；指示"以最新信息为准"；避免摘要式记忆把旧值固化 | 阅读 prompt 设计 |
| abstention 准确率低（瞎编） | prompt 明确"记忆中没有就说不知道"；检索相似度低于阈值时直接走拒答分支 | 阅读 prompt + 检索阈值 |
| Recall 高但 QA 低 | 阅读方式改 `con`（先抽取有用信息再推理），优于 `direct`；或换更强 reader 模型 | `run_generation.sh ... con` |
| single-session-assistant 低 | 别只索引 user 消息（`USERONLY=false`），助手回复也要进记忆 | `run_generation.sh` |

### 第三步：一次迭代长什么样（示意数字）

```text
v0  flat-bm25 + session 粒度 + direct 阅读
    S 版总分 0.42 | Recall@5 0.55 | oracle 0.71
    归因：检索损失 0.29，是主要矛盾；temporal 类 Recall 尤其低

v1  换 dense 检索（flat-stella）+ turn 粒度        ← 只改索引层
    Recall@5 0.55 → 0.78，总分 0.42 → 0.58
    剩余短板：temporal-reasoning 0.35，knowledge-update 0.50

v2  加 turn-userfact 键扩展 + 时间感知查询剪枝      ← 只改检索扩展
    temporal 0.35 → 0.62，总分 0.58 → 0.66

v3  阅读改 con + prompt 声明"以最新信息为准/无据则拒答" ← 只改阅读层
    knowledge-update 0.50 → 0.74，abstention 0.40 → 0.80，总分 → 0.73
```

迭代纪律：

1. **每次只改一层**（索引/检索/阅读），否则分数变化无法归因；
2. 固定 judge 模型和版本（官方用 `gpt-4o-2024-08-06`），换 judge 分数不可比；
3. 每轮同时记录 QA 分 + Recall@k + oracle 分三条曲线，防止"检索涨了 QA 没涨"这类假优化；
4. 难题型（knowledge-update、abstention）样本少，波动大，看逐题 log（`*.eval-results-*`）里的具体失败案例比只看均值更有用；
5. 用 `longmemeval-cleaned` 版数据（2025/09 更新，修掉了填充会话干扰答案的问题），旧版分数与新版不可比。