# I-Lang — 指令压缩（EcoClaw 集成）

基于 `ilang-openclaw-main` 思路，在 EcoClaw-Bench 中通过 `baseline-hooks` 注入轻量压缩协议，减少提示词冗余并尽量保持任务正确性。

## GitHub

- 上游仓库：`https://github.com/ilang-ai/ilang-openclaw`
- I-Lang 字典：`https://github.com/ilang-ai/ilang-dict`

## 开关

| 类型 | 值 |
|------|----|
| label | `ilang-only` |
| 环境变量 | `ECOCLAW_ENABLE_ILANG=1` |

## 运行

```bash
# 单 Agent
bash experiments/scripts/run_pinchbench_methods.sh \
  --label ilang-only \
  --suite task_00_sanity \
  --runs 1

# 多 Agent（MAS）
bash experiments/scripts/run_pinchbench_methods_mas.sh \
  --label ilang-only \
  --suite task_00_sanity \
  --runs 1
```

## 前置条件

无额外依赖。该方法是纯提示层优化。

## 机制

1. 在 `before_prompt_build` 阶段注入 `I-Lang COMPRESSION MODE` 指令。
2. 要求规划与表达更紧凑，减少 filler 文本与重复改写。
3. 默认不强制输出 I-Lang 语法，除非用户明确要求。
4. 优先保证任务完成与正确性，再追求短输出。

## 代码位置

`experiments/tools/baseline-hooks/index.js`
