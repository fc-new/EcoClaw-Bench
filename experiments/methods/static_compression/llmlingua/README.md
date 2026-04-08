# LLMLingua-2 — Prompt Compression

微软的 LLMLingua-2，使用 xlm-roberta-large 模型对工具输出做 token 级压缩。

## 运行

```bash
# 单 Agent 模式
./experiments/scripts/run_pinchbench_methods.sh --label llmlingua-only

# 多智能体 (MAS) 模式
./experiments/scripts/run_pinchbench_methods_mas.sh --label llmlingua-only \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ECOCLAW_LLMLINGUA_RATE` | `0.5` | 压缩率（保留比例） |
| `ECOCLAW_LLMLINGUA_MIN_LENGTH` | `200` | 最小触发长度 |

## 前置条件

```bash
conda run -n cdm_env pip install llmlingua
# 模型已下载到 local_models/llmlingua-2-xlm-roberta-large-meetingbank/