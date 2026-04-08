# QMD — Query Markup Documents

基于 [tobi/qmd](https://github.com/tobi/qmd) 的本地搜索引擎，在 agent 执行前检索知识库并注入上下文。

## 三种搜索模式

| 模式 | label | 环境变量 |
|------|-------|---------|
| BM25 全文搜索 | `qmd-only` | `ECOCLAW_QMD_MODE=search` |
| 向量语义搜索 | `qmd-vsearch` | `ECOCLAW_QMD_MODE=vsearch` |
| 混合搜索 (BM25+向量+重排序) | `qmd-query` | `ECOCLAW_QMD_MODE=query` |

## 运行

```bash
./experiments/scripts/run_pinchbench_methods.sh --label qmd-only
./experiments/scripts/run_pinchbench_methods.sh --label qmd-vsearch
./experiments/scripts/run_pinchbench_methods.sh --label qmd-query
```

## 前置条件

```bash
# 安装 QMD
npm install -g @tobilu/qmd

# 索引 task 文件
qmd collection add /path/to/Baseline/skill/tasks --name pinchbench-tasks
HF_ENDPOINT=https://hf-mirror.com qmd embed