# Compaction — OpenClaw 内置历史压缩

OpenClaw 的 safeguard compaction 模式，当对话历史接近 token 上限时自动总结旧历史。

## 运行

```bash
# 单 Agent 模式
./experiments/scripts/run_pinchbench_methods.sh --label compaction

# 多智能体 (MAS) 模式
./experiments/scripts/run_pinchbench_methods_mas.sh --label compaction \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

## 配置

脚本会自动设置 `agents.defaults.compaction.mode=safeguard` 并禁用 lossless-claw，运行后恢复。

## 参数（在 ~/.openclaw/openclaw.json 中）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `reserveTokens` | `4000` | 为回复预留的 token |
| `keepRecentTokens` | `6000` | 保留最近的 token 数 |
| `maxHistoryShare` | `0.5` | 历史占总 context 的最大比例 |
| `recentTurnsPreserve` | `3` | 保留最近几轮完整对话 |