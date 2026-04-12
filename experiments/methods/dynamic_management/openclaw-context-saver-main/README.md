# Context Saver — 动态上下文管理（EcoClaw 集成）

基于 `openclaw-context-saver-main` 的核心思想，在 EcoClaw-Bench 中实现“长工具输出外置化 + 引用化”，降低上下文膨胀。

> 说明：本 README 为基准集成说明。原项目的完整文档仍可参考本目录下 `docs/`。

## GitHub

- 可确认的核心上游（MCP 基座）：`https://github.com/mksglu/context-mode`
- 说明：当前目录快照未携带独立远端仓库元数据（无 `.git` remote 信息）。

## 开关

| 类型 | 值 |
|------|----|
| label | `context-saver-only` |
| 环境变量 | `ECOCLAW_ENABLE_CONTEXT_SAVER=1` |

## 运行

```bash
# 单 Agent
bash experiments/scripts/run_pinchbench_methods.sh \
  --label context-saver-only \
  --suite task_00_sanity \
  --runs 1

# 多 Agent（MAS）
bash experiments/scripts/run_pinchbench_methods_mas.sh \
  --label context-saver-only \
  --suite task_00_sanity \
  --runs 1
```

## 前置条件

无额外服务依赖。默认会在本地写入状态文件：`~/.baseline-state/context-saver/`。

## 机制

1. 对超长工具输出做 JSON 感知压缩（或通用 head/highlights/tail 压缩）。
2. 原始内容外置保存到本地 `raw/`，会话中仅保留短摘要 + `ref`。
3. 注入 `CONTEXT SAVER MODE` 指令，鼓励后续请求只拉取“最小必要片段”。

## 可调参数

- `ECOCLAW_CONTEXT_SAVER_MIN_LENGTH`（默认 500）
- `ECOCLAW_CONTEXT_SAVER_MAX_CHARS`（默认 420）
- `ECOCLAW_CONTEXT_SAVER_MAX_STORE_CHARS`（默认 120000）

## 代码位置

`experiments/tools/baseline-hooks/index.js`
