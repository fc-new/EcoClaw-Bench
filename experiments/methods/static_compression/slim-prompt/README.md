# Slim Prompt — 减少 Input Token

通过截断工具输出 + 注入效率指令，减少 agent 的 input token（$2.50/M）。

## 运行

```bash
./experiments/scripts/run_pinchbench_methods.sh --label slim-prompt
```

## 也可与 concise 组合

```bash
./experiments/scripts/run_pinchbench_methods.sh --label concise-slim
```

## 无额外依赖

纯 baseline-hooks 模块，通过 `ECOCLAW_ENABLE_SLIM_PROMPT=1` 启用。

## 机制

1. 超过 300 字符的工具输出截断为 head(200) + tail(100)
2. 注入效率指令：减少 tool call 次数、批量操作、避免重复读取