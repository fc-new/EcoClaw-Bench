# Prefix Cache — OpenAI Prompt Caching

注入固定 padding（≥1024 tokens）触发 OpenAI 自动 prompt 缓存，缓存命中后 token 半价。

## 运行

```bash
# 单 Agent 模式
./experiments/scripts/run_pinchbench_methods.sh --label prefix-cache

# 多智能体 (MAS) 模式
./experiments/scripts/run_pinchbench_methods_mas.sh --label prefix-cache \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

## 无额外依赖

纯 baseline-hooks 模块，通过 `ECOCLAW_ENABLE_PREFIX_CACHE=1` 启用。