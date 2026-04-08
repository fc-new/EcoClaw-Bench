# Compaction + Lossless-Claw

OpenClaw safeguard compaction + @martian-engineering/lossless-claw context engine 插件。

lossless-claw 在 compaction 时做"无损"压缩：移出大 tool result、压缩 oversized details、budget pass。

## 运行

```bash
# 单 Agent 模式
./experiments/scripts/run_pinchbench_methods.sh --label compaction-lcm

# 多智能体 (MAS) 模式
./experiments/scripts/run_pinchbench_methods_mas.sh --label compaction-lcm \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

## 前置条件

```bash
# 安装 lossless-claw 插件
openclaw plugins install @martian-engineering/lossless-claw
```

## 配置

脚本会自动设置 `compaction.mode=safeguard` + `lossless-claw.enabled=true`，运行后恢复。