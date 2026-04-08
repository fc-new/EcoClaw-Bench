# Token Saver — 工具结果压缩（EcoClaw 集成）

基于 `token-saver-master` 思路，在 EcoClaw-Bench 中实现“工具输出压缩 + 持续紧凑写作指令”，用于降低上下文与 token 消耗。

## GitHub

- 上游仓库：`https://github.com/RubenAQuispe/token-saver`

## 开关

| 类型 | 值 |
|------|----|
| label | `token-saver-only` |
| 环境变量 | `ECOCLAW_ENABLE_TOKEN_SAVER=1` |

## 运行

```bash
# 单 Agent
bash experiments/scripts/run_pinchbench_methods.sh \
  --label token-saver-only \
  --suite task_00_sanity \
  --runs 1

# 多 Agent（MAS）
bash experiments/scripts/run_pinchbench_methods_mas.sh \
  --label token-saver-only \
  --suite task_00_sanity \
  --runs 1
```

## 前置条件

无额外依赖。该方法由 `baseline-hooks` 直接实现。

## 机制

1. 在 `tool_result_persist` 阶段，对较长工具输出做结构化压缩（保留语义、减少冗词）。
2. 在 `before_prompt_build` 注入 `TOKEN SAVER MODE (PERSISTENT)`，引导后续内容保持紧凑。
3. 目标是“含义不变、表达更短”，降低后续轮次输入 token。

## 代码位置

`experiments/tools/baseline-hooks/index.js`
