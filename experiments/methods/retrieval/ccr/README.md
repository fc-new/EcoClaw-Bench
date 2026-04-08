# CCR — ContextualCompressionRetriever

基于 LangChain 的 ContextualCompressionRetriever，使用 FAISS 向量检索 + LLM 压缩提取。

## 运行

```bash
# 单 Agent 模式
./experiments/scripts/run_pinchbench_methods.sh --label ccr-only

# 多智能体 (MAS) 模式
./experiments/scripts/run_pinchbench_methods_mas.sh --label ccr-only \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

## 前置条件

```bash
# 安装依赖
conda run -n cdm_env pip install langchain langchain-community langchain-openai faiss-cpu langchain-classic

# 构建 FAISS 索引
conda run -n cdm_env python experiments/methods/ccr/ccr_search.py index --docs-dir /path/to/Baseline/skill/tasks
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ECOCLAW_CCR_TOPN` | `3` | 返回结果数 |
| `ECOCLAW_CCR_CONDA_ENV` | `cdm_env` | Python 环境 |