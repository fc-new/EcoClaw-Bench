# Concise Output — 减少 Output Token

通过 system prompt 注入简洁回复指令，减少 agent 的 output token（$15/M，最贵）。

## 运行

```bash
# 单 Agent 模式
./experiments/scripts/run_pinchbench_methods.sh --label concise-only

# 多智能体 (MAS) 模式
./experiments/scripts/run_pinchbench_methods_mas.sh --label concise-only \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

## 无额外依赖

纯 baseline-hooks 模块，通过 `ECOCLAW_ENABLE_CONCISE=1` 启用。

## 注入的指令

- 用最少的词完成任务
- 不解释推理过程
- 不重复用户请求
- 不加寒暄和签名
- 跳过确认消息