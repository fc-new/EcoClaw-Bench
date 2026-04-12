# OpenClaw Token Optimization — 配置预设（EcoClaw 集成）

该方法通过 `apply-preset.js` 临时修改 `~/.openclaw/openclaw.json`，启用一组偏向低 token 消耗的默认参数。

## GitHub

- 上游仓库：`https://github.com/oneles/openclaw-token-optimization`
- OpenClaw 官方：`https://github.com/openclaw/openclaw`

## 开关

| 类型 | 值 |
|------|----|
| label | `token-opt` |
| 环境变量 | 无（通过脚本补丁配置） |

## 运行

```bash
# 单 Agent
bash experiments/scripts/run_pinchbench_methods.sh \
  --label token-opt \
  --suite task_00_sanity \
  --runs 1

# 多 Agent（MAS）
bash experiments/scripts/run_pinchbench_methods_mas.sh \
  --label token-opt \
  --suite task_00_sanity \
  --runs 1
```

## 前置条件

1. 本机已安装 `node`。
2. `~/.openclaw/openclaw.json` 可读写。
3. OpenClaw gateway 可重启。

## 机制

`apply-preset.js` 会合并以下默认项：

1. `contextPruning`（更积极的上下文清理）
2. `compaction`（safeguard + memoryFlush）
3. `heartbeat`（缓存保活）
4. `memorySearch`（local + cache）

> 说明：基准脚本会在运行前备份配置、运行后恢复配置，并自动重启 gateway。

## 代码位置

- `experiments/methods/static_tuning/openclaw-token-optimization-main/apply-preset.js`
- `experiments/scripts/run_pinchbench_methods.sh`
- `experiments/scripts/run_pinchbench_methods_mas.sh`
