# EcoClaw-Bench 上下文管理引擎 (Context Engine) 适配文档

本文档描述 EcoClaw-Bench 中 **AgentSwing Context Engine** 的完整适配方案。
Context Engine 通过 OpenClaw 的插件系统实现 **Keep-Last-N** 和 **Summary** 两种上下文管理策略，
来源于 AgentSwing 论文中提出的对话历史压缩方法，支持在 PinchBench、Claw-Eval、FrontierScience 三个数据集上运行。

---

## 目录

1. [架构概览](#1-架构概览)
2. [目录结构](#2-目录结构)
3. [环境准备](#3-环境准备)
4. [两种上下文管理模式](#4-两种上下文管理模式)
5. [两种触发机制](#5-两种触发机制)
6. [配置参数详解](#6-配置参数详解)
7. [运行方式](#7-运行方式)
8. [代码变更总览](#8-代码变更总览)
9. [核心模块说明](#9-核心模块说明)
10. [关键代码逻辑详解](#10-关键代码逻辑详解)
11. [测试验证](#11-测试验证)
12. [常见问题](#12-常见问题)
13. [代码审查记录](#13-代码审查记录)
14. [Session-Mode Continuous（串行持续会话）](#14-session-mode-continuous串行持续会话)

---

## 1. 架构概览

AgentSwing Context Engine 作为 OpenClaw 的 **context-engine 插件** 运行，拦截 Agent 与 LLM
之间的对话流，在上下文窗口即将溢出时自动裁剪或压缩历史消息。

```
                       ┌──────────────────┐
                       │   Benchmark.py   │
                       │  (CLI 入口)       │
                       └────────┬─────────┘
                                │ 发送任务 prompt
                       ┌────────▼─────────┐
                       │   OpenClaw Agent  │
                       │  (执行 task)      │
                       └────────┬─────────┘
                                │ 每轮对话
              ┌─────────────────▼─────────────────┐
              │    AgentSwing Context Engine       │
              │  (OpenClaw context-engine 插件)     │
              │                                    │
              │  1. bootstrap() — 导入历史 transcript│
              │  2. assemble() — 同步 canonical state│
              │     ├─ 未触发 → 透传 canonical 消息   │
              │     └─ 已触发 → 应用策略裁剪/压缩    │
              │        ├─ keep-last-n: 保留最近N轮   │
              │        └─ summary: 组装为 (q, Sum)   │
              │  3. afterTurn() — 落盘并预生成摘要    │
              │  4. compact() — 基于 sessionFile 恢复 │
              └─────────────────┬─────────────────┘
                                │ 裁剪后的消息
                       ┌────────▼─────────┐
                       │    LLM Provider   │
                       │  (GPT-5-mini 等)  │
                       └──────────────────┘
```

**核心流程：**

1. Shell 脚本启动 OpenClaw Gateway，注入插件配置到 `openclaw.json`
2. Gateway 加载 `agentswing-context-engine` 插件并替换内置的上下文管理
3. 每次 Agent 向 LLM 发送请求前，`assemble()` 检查触发条件
4. 满足条件时，根据配置的模式（keep-last-n / summary）裁剪消息列表
5. 裁剪后的消息传递给 LLM，减少 token 消耗
6. `ownsCompaction: true` — 完全接管 OpenClaw 的内置自动压缩逻辑

**与 MAS 的关系：** Context Engine 是 **SAS（单 Agent 系统）** 模式下的优化手段，与 MAS（多 Agent 系统）互为正交。两者可以独立使用，也可以组合使用。

---

## 2. 目录结构

```
EcoClaw-Bench/
├── experiments/
│   ├── plugins/
│   │   └── agentswing-context-engine/       # 插件源码根目录
│   │       ├── index.ts                     # 插件入口（读取环境变量，注册引擎）
│   │       ├── openclaw.plugin.json         # 插件元数据和配置 Schema
│   │       ├── package.json                 # npm 包信息
│   │       ├── tsconfig.json                # TypeScript 编译配置
│   │       ├── src/
│   │       │   ├── config.ts                # 配置类型、默认值、解析器
│   │       │   ├── engine.ts                # 核心引擎（AgentSwingEngine 类）
│   │       │   ├── turn-parser.ts           # 对话轮次解析器
│   │       │   └── summarizer.ts            # LLM 摘要生成器
│   │       ├── typings/
│   │       │   └── openclaw.d.ts            # OpenClaw plugin-sdk 类型声明
│   │       └── dist/                        # 编译输出（tsc → JavaScript）
│   ├── scripts/
│   │   ├── common.sh                        # 公共函数（含 inject_context_engine_config）
│   │   ├── run_pinchbench_agentswing.sh     # PinchBench AgentSwing 运行脚本
│   │   ├── run_claw_eval_agentswing.sh      # Claw-Eval AgentSwing 运行脚本
│   │   ├── run_frontierscience_agentswing.sh # FrontierScience AgentSwing 运行脚本
│   │   └── install_agentswing_plugin.sh     # 插件安装辅助脚本
│   └── dataset/
│       ├── pinchbench/scripts/benchmark.py  # 支持 --context-mode 参数
│       ├── claw_eval/scripts/benchmark.py
│       └── frontierscience/scripts/benchmark.py
└── docs/
    └── context_memory.md                    # 本文档
```

---

## 3. 环境准备

### 3.1 基础环境

```bash
# 确保 OpenClaw CLI 已安装（v2026.4.15+）
which openclaw
openclaw --version

# 确保 Node.js + TypeScript 可用
node --version        # >= 18.x
npx tsc --version     # >= 5.7
```

### 3.2 编译插件

```bash
cd experiments/plugins/agentswing-context-engine

# 安装依赖（使用 npmmirror 加速）
npm install

# 编译 TypeScript → JavaScript
npx tsc

# 安装插件到 OpenClaw
openclaw plugins install . --force --dangerously-force-unsafe-install
```

安装成功后插件位于 `~/.openclaw/extensions/agentswing-context-engine/`。

### 3.3 验证插件加载

```bash
# 启动 Gateway（需设置环境变量）
AGENTSWING_MODE=keep-last-n openclaw gateway --port 18789

# 在日志中应看到类似输出：
# [gateway] ready (6 plugins: ..., agentswing-context-engine, ...; 4.5s)
# [AgentSwing] Initialized: mode=keep-last-n, triggerMode=token-ratio, ...
```

### 3.4 配置 .env

```bash
cp .env.example .env
```

编辑 `.env`，填入以下关键配置：

```bash
# 必填：API 配置
ECOCLAW_BASE_URL=https://your-api-endpoint.com/llm
ECOCLAW_API_KEY=sk-your-key-here

# 必填：模型配置
ECOCLAW_MODEL=dmxapi/gpt-5-mini
ECOCLAW_JUDGE=dmxapi/gpt-5-mini

# AgentSwing 配置（可选，也可通过 CLI 参数传入）
AGENTSWING_MODE=keep-last-n
AGENTSWING_TRIGGER_MODE=token-ratio
AGENTSWING_TRIGGER_RATIO=0.4
AGENTSWING_KEEP_LAST_N=5

# Summary 模式可选覆盖 provider / baseUrl / model
# 鉴权默认走 OpenClaw 的 provider 配置与 auth profile，不再单独读取 API key 环境变量
AGENTSWING_SUMMARY_PROVIDER=dica
AGENTSWING_SUMMARY_API_BASE=https://your-api-endpoint.com/v1
AGENTSWING_SUMMARY_MODEL=gpt-5-mini
```

---

## 4. 两种上下文管理模式

### 4.1 Keep-Last-N 模式

**策略：** 保留对话历史中最近的 N 个交互轮次，截断更早的历史。

```
原始对话：[Preamble] [Turn 1] [Turn 2] [Turn 3] [Turn 4] [Turn 5]
裁剪后 (N=3)：[Preamble] [Turn 3] [Turn 4] [Turn 5]
```

**特点：**
- 实现简单、延迟低、无额外 LLM 调用
- 完全丢弃早期历史，可能丢失关键上下文
- 适合任务较短或上下文窗口较小的场景

**注入提示：** 当发生截断时，会向系统提示追加：
```
[Context Management] Earlier conversation history (2 turns) has been truncated.
Only the 3 most recent interaction turns are visible.
```

### 4.2 Summary 模式

**策略：** 将早期对话历史压缩为一段摘要文本，保留最近 N 轮完整对话。

```
原始对话：[Preamble] [Turn 1] [Turn 2] [Turn 3] [Turn 4] [Turn 5]
压缩后 (N=3)：[Preamble] [Summary of Turn 1-2] [Turn 3] [Turn 4] [Turn 5]
```

**特点：**
- 保留早期探索的关键信息（发现、假设、错误路径等）
- 需要额外的 LLM 调用生成摘要（约 120s 超时）
- 通过 `afterTurn()` 预生成摘要缓存，避免阻塞 `assemble()`
- 摘要生成失败时自动降级为 keep-last-n

**AgentSwing (q, Sum) 格式：**
```
[Preamble]                        ← 系统消息 + 原始用户 prompt (q)
[Previous Exploration Summary]    ← 压缩摘要 (Sum)
[Recent Turn N-2]                 ← 最近 N 轮完整对话
[Recent Turn N-1]
[Recent Turn N]
```

---

## 5. 两种触发机制

触发机制决定 **何时** 启动上下文管理策略。

### 5.1 Token-Ratio 触发（默认）

**条件：** `estimatedTokens / contextWindow > triggerRatio`

```
estimatedTokens = Σ (message.content.length / 4)   // chars/4 估算
contextWindow   = 配置值 | tokenBudget | 200,000 (fallback)
triggerRatio    = 0.4 (默认)
```

**适用场景：** 当需要精确控制 token 使用率时使用。阈值 0.4 来自 AgentSwing 论文中
DeepSeek/Tongyi 模型的推荐值（GPT-OSS-120B 推荐 0.2）。

**日志示例：**
```
[AgentSwing] assemble: tokens≈342, window=500, ratio=0.684, threshold=0.4 (token-ratio)
[AgentSwing] TRIGGERED (token-ratio): turns=5, tokens≈342 — applying keep-last-n
[AgentSwing] keep-last-n: kept 3/5 turns, tokens≈223
```

### 5.2 Turn-Count 触发

**条件：** `turnCount > triggerTurnCount`

```
turnCount         = parseConversation(messages).turns.length
triggerTurnCount  = 10 (默认)
```

**适用场景：** 当希望按交互轮次固定裁剪时使用。不依赖 token 估算，逻辑更简单。

**日志示例：**
```
[AgentSwing] assemble: tokens≈342, turns=5, threshold=2 (turn-count)
[AgentSwing] TRIGGERED (turn-count): turns=5, tokens≈342 — applying keep-last-n
[AgentSwing] keep-last-n: kept 3/5 turns, tokens≈223
```

---

## 6. 配置参数详解

### 6.1 环境变量

| 环境变量 | 类型 | 默认值 | 说明 |
|---------|------|--------|------|
| `AGENTSWING_MODE` | string | `keep-last-n` | 上下文管理策略：`keep-last-n` 或 `summary` |
| `AGENTSWING_TRIGGER_MODE` | string | `token-ratio` | 触发机制：`token-ratio` 或 `turn-count` |
| `AGENTSWING_TRIGGER_RATIO` | float | `0.4` | token-ratio 模式的触发阈值 |
| `AGENTSWING_TRIGGER_TURN_COUNT` | int | `10` | turn-count 模式的触发阈值 |
| `AGENTSWING_KEEP_LAST_N` | int | `5` | 保留最近 N 个交互轮次 |
| `AGENTSWING_CONTEXT_WINDOW` | int | 自动推断 | 覆盖模型上下文窗口大小（token 数） |
| `AGENTSWING_SUMMARY_PROVIDER` | string | 当前模型 provider / `openai` | Summary 模式用于解析 auth/baseUrl 的 provider |
| `AGENTSWING_SUMMARY_API_BASE` | string | provider 的 `baseUrl` | Summary 模式可选显式覆盖 API 地址 |
| `AGENTSWING_SUMMARY_MODEL` | string | 当前模型 id / `gpt-5-mini` | Summary 模式使用的模型 |

### 6.2 openclaw.plugin.json Schema

插件在 `openclaw.plugin.json` 中声明了完整的配置 Schema：

```jsonc
{
    "id": "agentswing-context-engine",
    "kind": "context-engine",
    "configSchema": {
        "type": "object",
        "properties": {
            "mode": {
                "type": "string",
                "enum": ["keep-last-n", "summary"]
            },
            "triggerMode": {
                "type": "string",
                "enum": ["token-ratio", "turn-count"]
            },
            "triggerRatio": {
                "type": "number",
                "minimum": 0.01,
                "maximum": 0.99
            },
            "triggerTurnCount": {
                "type": "integer",
                "minimum": 1,
                "maximum": 200
            },
            "keepLastN": {
                "type": "integer",
                "minimum": 1,
                "maximum": 50
            },
            "contextWindow": {
                "type": "integer",
                "minimum": 1000
            }
        }
    }
}
```

### 6.3 CLI 参数

所有运行脚本支持以下参数：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--context-mode` | 上下文管理策略 | `keep-last-n` |
| `--trigger-mode` | 触发机制 | `token-ratio` |
| `--trigger-ratio` | token-ratio 触发阈值 | `0.4` |
| `--trigger-turn-count` | turn-count 触发阈值 | `10` |
| `--keep-last-n` | 保留轮次数 | `5` |
| `--context-window` | 上下文窗口大小 | 自动推断 |
| `--model` | 主模型 ID | `dmxapi/gpt-5-mini` |
| `--judge` | 评分模型 ID | `dmxapi/gpt-5-mini` |
| `--suite` | 任务子集 | `all` |
| `--runs` | 每个 task 重复次数 | `1` |
| `--parallel` | 并行 task 数 | `1` |
| `--timeout-multiplier` | 超时倍数 | `1.0` |

### 6.4 配置优先级

配置值的优先级（从高到低）：

```
CLI 参数  >  环境变量  >  openclaw.json 中的 plugin config  >  DEFAULT_CONFIG
```

在 `index.ts` 中实现为：
```typescript
const envConfig = readConfigFromEnv();                    // 环境变量
const pluginCfg = { ...(api.pluginConfig ?? {}), ...envConfig };  // 合并
return new AgentSwingEngine(pluginCfg);                   // resolveConfig() 填充默认值
```

---

## 7. 运行方式

### 7.1 PinchBench

```bash
# Keep-Last-N + Token-Ratio 触发（推荐默认配置）
bash experiments/scripts/run_pinchbench_agentswing.sh \
  --context-mode keep-last-n \
  --trigger-mode token-ratio \
  --trigger-ratio 0.4 \
  --keep-last-n 5 \
  --runs 1 \
  --suite "automated-only"

# Keep-Last-N + Turn-Count 触发
bash experiments/scripts/run_pinchbench_agentswing.sh \
  --context-mode keep-last-n \
  --trigger-mode turn-count \
  --trigger-turn-count 10 \
  --keep-last-n 5

# Summary + Token-Ratio 触发
bash experiments/scripts/run_pinchbench_agentswing.sh \
  --context-mode summary \
  --trigger-mode token-ratio \
  --trigger-ratio 0.3 \
  --keep-last-n 3
```

### 7.2 Claw-Eval

```bash
bash experiments/scripts/run_claw_eval_agentswing.sh \
  --context-mode keep-last-n \
  --trigger-mode token-ratio \
  --trigger-ratio 0.4 \
  --keep-last-n 5 \
  --runs 1
```

### 7.3 FrontierScience

```bash
bash experiments/scripts/run_frontierscience_agentswing.sh \
  --context-mode keep-last-n \
  --trigger-mode token-ratio \
  --trigger-ratio 0.4 \
  --keep-last-n 5 \
  --runs 1
```

### 7.4 手动测试（不通过脚本）

如果需要手动控制 Gateway 启动和测试，可直接使用环境变量：

```bash
# 1. 启动 Gateway（export 环境变量）
export AGENTSWING_MODE=keep-last-n
export AGENTSWING_TRIGGER_MODE=turn-count
export AGENTSWING_TRIGGER_TURN_COUNT=2
export AGENTSWING_KEEP_LAST_N=3
nohup openclaw gateway --port 18789 > /tmp/openclaw-gw.log 2>&1 &

# 2. 等待 Gateway 就绪
sleep 8 && curl -s http://127.0.0.1:18789/health

# 3. 运行 benchmark（直接调用 Python）
cd experiments/dataset/pinchbench
uv run scripts/benchmark.py \
  --model dmxapi/gpt-5-mini \
  --judge dmxapi/gpt-5-mini \
  --suite "task_00_sanity,task_01_calendar,task_02_stock" \
  --runs 1 --parallel 1 \
  --timeout-multiplier 2.0 \
  --output-dir /tmp/agentswing-test \
  --no-upload \
  --context-mode keep-last-n

# 4. 检查触发日志
grep "AgentSwing" /tmp/openclaw-gw.log | grep -E "TRIGGERED|keep-last-n:"
```

---

## 8. 代码变更总览

本次适配共涉及以下文件：

### 8.1 插件源码（新增）

| 文件 | 行数 | 说明 |
|------|------|------|
| `experiments/plugins/agentswing-context-engine/index.ts` | ~75 | 插件入口：环境变量读取、引擎注册 |
| `experiments/plugins/agentswing-context-engine/src/config.ts` | ~85 | 配置类型定义、默认值、解析器 |
| `experiments/plugins/agentswing-context-engine/src/engine.ts` | ~400 | 核心引擎：AgentSwingEngine 类 |
| `experiments/plugins/agentswing-context-engine/src/turn-parser.ts` | ~200 | 对话解析器：消息 → 轮次 |
| `experiments/plugins/agentswing-context-engine/src/summarizer.ts` | ~120 | LLM 摘要生成器 |
| `experiments/plugins/agentswing-context-engine/openclaw.plugin.json` | ~50 | 插件元数据和 Schema |
| `experiments/plugins/agentswing-context-engine/typings/openclaw.d.ts` | ~100 | OpenClaw SDK 类型声明 |
| `experiments/plugins/agentswing-context-engine/package.json` | ~25 | npm 包配置 |
| `experiments/plugins/agentswing-context-engine/tsconfig.json` | ~20 | TypeScript 编译选项 |

### 8.2 Shell 基础设施（新增 + 修改）

| 文件 | 变更内容 |
|------|---------|
| `experiments/scripts/common.sh` | **+50 行**：`inject_context_engine_config()` 函数 — 将 AgentSwing 插件配置注入 `openclaw.json` |
| `experiments/scripts/run_pinchbench_agentswing.sh` | **新增 ~200 行**：PinchBench AgentSwing 运行脚本 |
| `experiments/scripts/run_claw_eval_agentswing.sh` | **新增 ~200 行**：Claw-Eval AgentSwing 运行脚本 |
| `experiments/scripts/run_frontierscience_agentswing.sh` | **新增 ~200 行**：FrontierScience AgentSwing 运行脚本 |

### 8.3 配置文件

| 文件 | 说明 |
|------|------|
| `experiments/plugins/agentswing-context-engine/openclaw.plugin.json` | 插件声明，含 `configSchema` 定义所有可配置字段 |

---

## 9. 核心模块说明

### 9.1 index.ts — 插件入口

**职责：** 读取环境变量，注册 AgentSwingEngine 到 OpenClaw 插件系统。

```typescript
const plugin: OpenClawPluginDefinition = {
    id: "agentswing-context-engine",
    kind: "context-engine",
    register(api: OpenClawPluginApi) {
        const envConfig = readConfigFromEnv();
        const pluginCfg = { ...(api.pluginConfig ?? {}), ...envConfig };
        api.registerContextEngine("agentswing-context-engine", () => {
            return new AgentSwingEngine(pluginCfg);
        });
    },
};
```

**环境变量映射：**
- `AGENTSWING_MODE` → `config.mode`
- `AGENTSWING_TRIGGER_MODE` → `config.triggerMode`
- `AGENTSWING_TRIGGER_RATIO` → `config.triggerRatio`（parseFloat）
- `AGENTSWING_TRIGGER_TURN_COUNT` → `config.triggerTurnCount`（parseInt）
- `AGENTSWING_KEEP_LAST_N` → `config.keepLastN`（parseInt）
- `AGENTSWING_CONTEXT_WINDOW` → `config.contextWindow`（parseInt）

### 9.2 config.ts — 配置系统

**类型定义：**

```typescript
export type ContextMode = "keep-last-n" | "summary";
export type TriggerMode = "token-ratio" | "turn-count";

export interface AgentSwingConfig {
    mode: ContextMode;
    triggerMode: TriggerMode;
    triggerRatio: number;       // token-ratio 阈值
    triggerTurnCount: number;   // turn-count 阈值
    keepLastN: number;          // 保留轮次数
    contextWindow: number | null; // null = 从 tokenBudget 推断
}
```

**默认值：**

```typescript
export const DEFAULT_CONFIG: AgentSwingConfig = {
    mode: "keep-last-n",
    triggerMode: "token-ratio",
    triggerRatio: 0.4,
    triggerTurnCount: 10,
    keepLastN: 5,
    contextWindow: null,
};
```

**解析器：** `resolveConfig(raw)` 将 partial 配置与默认值合并，对整数字段执行 `Math.max(1, Math.floor(v))` 确保至少为 1。

### 9.3 engine.ts — 核心引擎

**AgentSwingEngine 类** 实现 OpenClaw 的 `ContextEngine` 接口，包含以下生命周期方法：

| 方法 | 调用时机 | 说明 |
|------|---------|------|
| `bootstrap()` | session 初次加载时 | 从 `sessionFile` 导入历史消息并初始化 canonical state |
| `ingest()` | 每条消息入库时 | 透传（no-op）；真正的状态同步在 `assemble/afterTurn/compact` 中完成 |
| `assemble()` | LLM 请求前 | **核心方法**：同步磁盘 canonical state、检查触发条件、应用策略 |
| `afterTurn()` | 每轮对话结束后 | 持久化 canonical state；Summary 模式预生成摘要缓存 |
| `compact()` | 溢出恢复或 /compact 命令 | 读取 `sessionFile`，强制生成当前策略下的 managed context |
| `dispose()` | 插件卸载时 | 清理 session 状态 |

**关键属性：**
- `ownsCompaction: true` — 完全替代 OpenClaw 内置压缩
- `sessions: Map<sessionId, CanonicalSessionState>` — 每 session 的内存缓存，磁盘为真实来源

**SessionState 结构：**
```typescript
interface SessionState {
    cachedSummary: string | null;     // 缓存的摘要文本
    originalPrompt: string | null;    // 首条用户消息
    compactionCount: number;          // 压缩次数计数
}
```

### 9.4 turn-parser.ts — 对话解析器

**核心概念：** 将扁平的消息数组解析为结构化的交互轮次。

```typescript
interface ParsedConversation {
    preamble: Msg[];          // 系统消息 + 首条用户消息（始终保留）
    turns: InteractionTurn[]; // 后续交互轮次
}

interface InteractionTurn {
    messages: Msg[];          // 一轮交互的所有消息（assistant + toolResult）
}
```

**解析策略：**
1. 收集 preamble：所有前导 system 消息 + 第一条 user 消息
2. 剩余消息按 assistant 消息边界分组：
   - 每个 assistant 消息开始新的 turn
   - 后续的 toolResult 消息归入同一 turn（按 toolCall 数量匹配）
   - 中间的 user 消息刷新当前 turn，附加到下一个 turn

**导出函数：**
- `parseConversation(messages)` → `ParsedConversation`
- `keepLastNTurns(parsed, n)` → 保留最后 N 轮，返回扁平消息数组
- `getMessagesToSummarize(parsed, keepRecent)` → 获取需要摘要的消息
- `messagesToText(messages)` → 消息数组转文本（供摘要器使用）

### 9.5 summarizer.ts — 摘要生成器

**职责：** 调用 OpenAI 兼容 API 将对话历史压缩为摘要文本。

**摘要系统提示要求保留：**
1. 关键发现和已验证的事实
2. 当前假设及其状态（确认/否定/待验证）
3. 进度状态（已完成/待完成）
4. 重要错误信息或失败路径
5. 文件路径、变量名、URL 等具体标识符
6. 部分结果或中间输出

**API 调用参数：**
- `temperature: 0.3`（低随机性，确保摘要稳定）
- `max_tokens: 4096`
- `timeout: 120s`（AbortSignal）

---

## 10. 关键代码逻辑详解

### 10.1 assemble() — 核心触发与裁剪逻辑

```typescript
async assemble(params): Promise<AssembleResult> {
    // 1. 获取/创建 session 状态
    const session = this.getSession(sessionId);

    // 2. 缓存首条用户消息（原始 prompt）
    if (!session.originalPrompt) { ... }

    // 3. Token 估算 + 对话解析（只做一次！）
    const estimated = estimateTokens(messages);
    const parsed = parseConversation(messages);
    const turnCount = parsed.turns.length;

    // 4. 根据 triggerMode 判断是否触发
    if (this.config.triggerMode === "turn-count") {
        shouldTrigger = turnCount > this.config.triggerTurnCount;
    } else {
        shouldTrigger = (estimated / contextWindow) > this.config.triggerRatio;
    }

    // 5. 未触发 → 透传
    if (!shouldTrigger) return { messages, estimatedTokens: estimated };

    // 6. 已触发 → 应用策略（复用已解析的 parsed 结果）
    return this.applyStrategy(messages, session, contextWindow, parsed);
}
```

**设计要点：**
- `parseConversation()` 只在 `assemble()` 中调用一次，结果传递给 `applyStrategy()`
- 两种触发模式共用同一个解析结果，避免重复解析
- `estimateTokens()` 使用 `chars/4` 启发式估算，与 OpenClaw 内部一致

### 10.2 afterTurn() — 持久化与 Summary 预生成

```typescript
async afterTurn(params): Promise<void> {
    // 1. 先把完整 transcript 同步进插件自有 canonical state
    const synced = await this.synchronizeCanonicalState({
        sessionId: params.sessionId,
        rawMessages: params.messages,
    });

    // 2. summary 模式下，在接近阈值 80% 时预生成摘要
    if (this.config.mode === "summary" && shouldPregen) {
        state = await this.ensureSummaryState(state, parsed);
    }

    // 3. 状态变化后落盘到 ~/.openclaw/artifacts/agentswing-context-engine/session-state/
    await this.persistCanonicalState(state);
}
```

**设计要点：**
- 插件维护一份独立于 OpenClaw transcript 的 canonical session state
- 预生成阈值为触发阈值的 80%，提前缓存摘要
- 摘要缓存后在下次 `assemble()` 中直接使用，避免阻塞
- 生成失败不影响主流程（catch + log）

### 10.3 applySummary() — Summary 模式组装

```typescript
private async applySummary(state, parsed) {
    // Summary 严格对齐论文中的 (q, Sum)
    state = await this.ensureSummaryState(state, parsed);
    const summary = state.cachedSummary?.summary;

    // 摘要生成失败 → 降级为 keep-last-n
    if (!summary) return this.applyKeepLastN(parsed);

    // 组装：system preamble + 合并后的 user prompt(q + Sum)
    const assembled = buildSummaryMessages(parsed, summary);
    return { messages: assembled, estimatedTokens: est, systemPromptAddition: "..." };
}
```

### 10.4 Shell 层：inject_context_engine_config()

此函数将插件配置注入 `openclaw.json`，核心逻辑：

```python
# 1. 设置活跃的 context engine 插槽
cfg["plugins"]["slots"]["contextEngine"] = "agentswing-context-engine"

# 2. 配置插件入口
entries["agentswing-context-engine"] = {
    "enabled": True,
    "config": {
        "mode": mode,
        "triggerMode": trigger_mode,
        "triggerRatio": trigger_ratio,
        "triggerTurnCount": trigger_turn_count,
        "keepLastN": keep_last_n,
        "contextWindow": context_window,  # 可选
    }
}
```

**与 MAS 注入的隔离：** Context Engine 配置写入 `plugins.slots.contextEngine` 和 `plugins.entries`，
不会影响 `agents.list` 或 `agents.defaults.subagents` 等 MAS 配置字段。

### 10.5 运行脚本生命周期

```
┌─ Script Start ───────────────────────────┐
│  1. import_dotenv()                       │
│  2. apply_ecoclaw_env()                   │
│  3. ensure_openclaw_gateway_running()     │
│  4. recover_stale_openclaw_config_backup()│
│  5. resolve CLI params + env vars         │
│  6. validate context-mode, trigger-mode   │
│  7. disable ecoclaw plugin (if active)    │
│  8. backup_openclaw_config()              │
│  9. export AGENTSWING_* env vars          │
│ 10. inject_context_engine_config()        │
│ 11. restart gateway (pickup new config)   │
│ 12. trap cleanup EXIT                     │
│ 13. run benchmark.py                      │
│ 14. generate cost report                  │
└──────────────────────────────────────────┘
         │ EXIT (正常/异常/SIGINT)
         ▼
┌─ Cleanup ───────────────────────────────┐
│  1. restore_openclaw_config()            │
│  2. re-enable ecoclaw plugin (if was on) │
│  3. restart gateway (original config)    │
└─────────────────────────────────────────┘
```

---

## 11. 测试验证

### 11.1 小规模冒烟测试（3 个任务）

#### Token-Ratio 触发

**配置：** `triggerRatio=0.4, contextWindow=500, keepLastN=3`

**测试任务：** PinchBench task_00_sanity, task_01_calendar, task_02_stock

| 任务 | 得分 | 判定方式 |
|------|------|---------|
| task_00_sanity | 100% | automated |
| task_01_calendar | 83% | automated |
| task_02_stock | 0% | automated |
| **Overall** | **61.1%** | |

**触发日志：**
```
[AgentSwing] TRIGGERED (token-ratio): turns=5, tokens≈342 — applying keep-last-n
[AgentSwing] keep-last-n: kept 3/5 turns, tokens≈223
```

#### Turn-Count 触发

**配置：** `triggerTurnCount=2, keepLastN=3`

| 任务 | 得分 | 判定方式 |
|------|------|---------|
| task_00_sanity | 100% | automated |
| task_01_calendar | 100% | automated |
| task_02_stock | 0% | automated |
| **Overall** | **66.7%** | |

**触发日志：**
```
[AgentSwing] TRIGGERED (turn-count): turns=5, tokens≈342 — applying keep-last-n
[AgentSwing] keep-last-n: kept 3/5 turns, tokens≈223
```

---

### 11.2 全量验证（23 个任务，continuous session 模式）

使用 `--session-mode continuous` 在单个 Agent 中串行运行 23 个任务，
对话历史在任务间持续累积，真实验证触发条件在长对话中的表现。

#### Token-Ratio 模式

**配置：** `triggerRatio=0.2, contextWindow=200000, keepLastN=5`

**结果：**
- **assemble() 调用：** 229 次
- **TRIGGERED 次数：** 0 次
- **最高 ratio：** 0.198（差 0.002 未达 0.2 阈值）
- **总分：** 38.0%（8.7/23.0）

**Token 累积趋势（证明 continuous 模式下跨任务累积）：**

| Session | Max Tokens | Max Ratio |
|---------|-----------|-----------|
| task_01 | 1,444 | 0.007 |
| task_05 | 6,772 | 0.034 |
| task_10 | 9,971 | 0.050 |
| task_15 | 17,943 | 0.090 |
| task_18 | 27,713 | 0.139 |
| task_22 | **39,554** | **0.198** |

**分析：** 23 个任务累积 ~40k tokens，在 200k 窗口下 ratio 最高仅 0.198。
插件逻辑完全正确（ratio 持续增长），只是当前工作负载不足以超越阈值。
若 `contextWindow=100000` 或任务更多则一定触发。

#### Turn-Count 模式

**配置：** `triggerTurnCount=5, keepLastN=5`

**结果：**
- **assemble() 调用：** 225 次
- **TRIGGERED 次数：** **185 次**
- **触发率：** **82.2%**
- **最高 turns：** 358（task_21）
- **总分：** 35.4%（8.1/23.0）

**Turn 累积趋势：**

| Session | Max Turns | Max Tokens |
|---------|----------|-----------|
| task_01 | 26 | 1,476 |
| task_05 | 92 | 8,268 |
| task_10 | 168 | 12,374 |
| task_15 | 258 | 20,335 |
| task_18 | 323 | 30,925 |
| task_21 | **358** | **42,263** |

**裁剪效果（锯齿形模式）：**
```
turns=37 → TRIGGERED → keep-last-5 → turns=6
turns=40 → TRIGGERED → keep-last-5 → turns=6
turns=42 → TRIGGERED → keep-last-5 → turns=6
```

每次超过阈值触发后，裁剪为最近 5 轮，然后重新累积。

---

### 11.3 两种模式效率对比

| 指标 | Token-Ratio | Turn-Count | 变化 |
|------|------------|-----------|------|
| TRIGGERED 次数 | 0 | **185** | — |
| 触发率 | 0% | **82.2%** | — |
| 总 tokens | 1,199,316 | **681,870** | **-43%** |
| 平均 tokens/task | 52,144 | **29,646** | **-43%** |
| Score | 38.0% | 35.4% | -2.6pp |
| Score/1K tokens | 0.0073 | **0.0119** | **+63%** |

**结论：** Turn-count 模式在 continuous session 下大幅触发裁剪，节省 43% token、
效率提升 63%，分数仅下降 2.6 个百分点。

---

### 11.4 机制验证清单

| 验证项 | 状态 | 证据 |
|--------|------|------|
| 插件初始化 | ✅ | 每次请求正确读取环境变量并初始化 |
| assemble() 钩子 | ✅ | 229/225 次调用（每次 LLM 请求前） |
| Token 估算 (chars/4) | ✅ | 跨任务累积 1k → 40k，与实际 token 数一致 |
| Ratio 计算 | ✅ | `tokens/window` 精确计算并与阈值对比 |
| Turn 计数 | ✅ | turns 在 continuous 模式下跨任务累积（1 → 358） |
| 触发判定 (token-ratio) | ✅ | `ratio > threshold` 严格比较（0.198 < 0.2 未触发） |
| 触发判定 (turn-count) | ✅ | `turns > threshold` 严格大于时触发（82.2% 触发率） |
| Keep-Last-N 裁剪 | ✅ | 触发后裁剪到 ≤5 turns 的"锯齿形"模式 |
| Token 节省效果 | ✅ | turn-count 模式节省 43% token |
| systemPromptAddition | ✅ | 裁剪时追加截断提示到系统消息 |
| ownsCompaction | ✅ | 完全替代 OpenClaw 内置压缩 |

---

## 12. 常见问题

### Q1: 插件没有加载？

检查 Gateway 日志是否包含 `agentswing-context-engine`：
```bash
grep "agentswing" /tmp/openclaw-gw.log
```

常见原因：
- 未执行 `openclaw plugins install`
- TypeScript 编译失败（`npx tsc` 检查错误）
- Gateway 启动时未 export `AGENTSWING_MODE` 等环境变量

### Q2: 触发条件不满足？

对于 **token-ratio** 模式：
- 如果 `contextWindow` 很大（如默认 200,000），短对话很难达到阈值
- 全量测试（23 个任务，continuous session）中 ratio 最高仅 0.198（200k 窗口）
- 解决方案：显式设置较小的 `AGENTSWING_CONTEXT_WINDOW`（如 100000），或降低 `triggerRatio`

对于 **turn-count** 模式：
- 简单任务（如 sanity）可能只有 1-2 轮交互，不会超过默认的 10
- 在 continuous session 模式下，turns 会跨任务累积，更容易触发
- 解决方案：降低 `AGENTSWING_TRIGGER_TURN_COUNT`（如 5）

### Q3: Summary 模式报错？

确保 Summary provider 的 `baseUrl` 和 auth profile 可用；必要时可显式覆盖 provider/baseUrl/model：
```bash
export AGENTSWING_SUMMARY_API_BASE="https://your-api.com/v1"
export AGENTSWING_SUMMARY_PROVIDER="dica"
export AGENTSWING_SUMMARY_MODEL="gpt-5-mini"
```

Summary 生成失败时会自动降级为 keep-last-n，不会导致任务失败。

### Q4: 如何查看详细的触发日志？

```bash
# 查看所有 AgentSwing 日志
grep "AgentSwing" /tmp/openclaw-gw.log

# 只看触发事件
grep "AgentSwing" /tmp/openclaw-gw.log | grep "TRIGGERED"

# 看裁剪结果
grep "AgentSwing" /tmp/openclaw-gw.log | grep "keep-last-n:\|summary:"
```

### Q5: 与 proxy 冲突？

OpenClaw Gateway 需要直连 LLM API。如果环境中设置了 `http_proxy` 等变量，
需要在启动 Gateway 前 unset：

```bash
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
```

运行脚本中 `common.sh` 已在开头自动执行此操作。

### Q6: 如何同时使用 Context Engine + MAS？

两个系统可以组合使用。Context Engine 作用于每个 Agent（包括 coordinator 和 worker）的对话历史，
MAS 控制多 Agent 间的协调调度。使用时需要分别配置：

```bash
bash experiments/scripts/run_pinchbench_agentswing.sh \
  --context-mode keep-last-n \
  --trigger-mode token-ratio \
  --trigger-ratio 0.4 \
  --keep-last-n 5 \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

> **注意：** 目前 AgentSwing 运行脚本默认为 SAS 模式，组合 MAS 需要手动将 agent-config
> 注入逻辑添加到脚本中，或直接修改 `openclaw.json`。

---

## 13. 代码审查记录

### 13.1 审查范围

| 文件 | 行数 | 审查结论 |
|------|------|---------|
| `index.ts` | 80 | ✅ 无问题 |
| `src/config.ts` | 90 | 已修复：triggerRatio 范围校验 |
| `src/engine.ts` | 400 | ✅ 无问题 |
| `src/turn-parser.ts` | 205 | ✅ 无问题 |
| `src/summarizer.ts` | 120 | ✅ 无问题 |
| `openclaw.plugin.json` | 55 | ✅ 无问题 |
| `typings/openclaw.d.ts` | 150 | ✅ 无问题 |
| `benchmark.py` (context_engine) | ~10 | 已修复：元数据字段补全 |
| `common.sh` (inject) | ~75 | ✅ 无问题 |

### 13.2 修复项

**Fix 1: benchmark.py — `context_engine` 输出元数据不完整**

原始代码仅记录 `mode`、`trigger_ratio`、`keep_last_n`，缺少 `trigger_mode`、`trigger_turn_count`、`context_window`，导致输出 JSON 无法完整追溯运行配置。

修复后新增字段：
```python
"context_engine": {
    "mode": args.context_mode,
    "trigger_mode": os.environ.get("AGENTSWING_TRIGGER_MODE", "token-ratio"),
    "trigger_ratio": float(os.environ.get("AGENTSWING_TRIGGER_RATIO", "0.4")),
    "trigger_turn_count": int(os.environ.get("AGENTSWING_TRIGGER_TURN_COUNT", "10")),
    "keep_last_n": int(os.environ.get("AGENTSWING_KEEP_LAST_N", "5")),
    "context_window": int(os.environ.get("AGENTSWING_CONTEXT_WINDOW", "0")) or None,
}
```

**Fix 2: config.ts — `triggerRatio` 缺少范围校验**

环境变量传入的 `triggerRatio` 绕过 JSON Schema 校验，可能为 0 或 >1 等非法值。

修复：添加 `Math.min(0.99, Math.max(0.01, raw.triggerRatio))` 范围钳位。

### 13.3 已确认无需修改的设计

| 项目 | 说明 |
|------|------|
| sessions Map 无自动清理 | benchmark 运行时间有限，dispose() 时全量清理。长期运行场景可后续加 LRU |
| estimateTokens chars/4 估算 | 与 OpenClaw 内部启发式一致，精度足够 |
| parseConversation 每次调用 | 解析为 O(n)，n 为消息数，单次 <1ms，无需缓存 |
| summary 模式 fetch 无重试 | 失败自动降级 keep-last-n，重试增加延迟无必要 |
| getContextWindow truthy 检查 | contextWindow=0 被视为未设置，但 schema 限制 minimum=1000，不会出现 |

---

## 14. Session-Mode Continuous（串行持续会话）

### 14.1 功能概述

`--session-mode continuous` 在单个 OpenClaw Agent 中串行执行所有 task，**不清理** Agent 的
session transcript，使对话历史在 task 间持续累积。通过 `transcript_cursor` 追踪每个 task
在累积 transcript 中的起止位置，输出 `transcript_span` 字段供后续分析。

```
┌─────────────────────────────────────────────────┐
│  Agent: bench-model-0017-serial                 │
│                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │ Task 0   │ │ Task 1   │ │ Task 2   │ ...    │
│  │ span 0→7 │ │ span 7→15│ │ span 15→22│       │
│  └──────────┘ └──────────┘ └──────────┘        │
│  ← 累积 transcript 持续增长                      →│
└─────────────────────────────────────────────────┘
```

**与 Context Engine 的协同：** continuous 模式使 transcript 不断增长，正是 Context Engine
（keep-last-n / summary）发挥作用的理想场景。两者结合可以在长对话中控制 token 消耗。

### 14.2 CLI 参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `--session-mode` | string | `isolated` | `isolated`：每个 task 独立（清理 session）；`continuous`：复用 agent、保留 transcript |

**约束条件（continuous 模式）：**
- 必须 `--parallel 1`（串行执行）
- 不兼容 multi-agent 模式（`--enable-multi-agent`）

违反约束时 benchmark 报错退出。

### 14.3 实现要点

#### 14.3.1 串行 Agent 创建（benchmark.py）

continuous 模式下，所有 task 复用同一个 agent：

```python
if session_mode == "continuous":
    agent_id_override = f"bench-{model_slug}-{run_id:04d}-serial"
    _ensure_single_agent(agent_id_override, model, workspace_path)
```

`agent_id_override` 传入每次 `_run_task_job()` 调用，确保复用同一 agent。

#### 14.3.2 Cleanup 控制（lib_agent.py）

`execute_openclaw_task()` 接受 `cleanup_sessions` 参数：

```python
def execute_openclaw_task(agent_id, prompt, ..., cleanup_sessions=True):
    if cleanup_sessions:
        cleanup_agent_sessions(agent_id)
```

continuous 模式传入 `cleanup_sessions=False`，保留累积 transcript。

**重要：** retry 路径（空 transcript 重试、transient error 重试）中的 cleanup 也受此参数保护：

```python
# 空 transcript 重试
if cleanup_sessions:
    cleanup_agent_sessions(agent_id)

# transient provider error 重试
if cleanup_sessions:
    cleanup_agent_sessions(agent_id)
```

#### 14.3.3 Transcript Span 追踪（benchmark.py）

```python
transcript_cursor = 0  # 全局游标

for job in task_jobs:
    job["transcript_start_index"] = transcript_cursor
    result = _run_task_job(**job)
    # result 包含 transcript_span = {start, end, length}
    transcript_cursor = result["transcript_span"]["end"]
```

#### 14.3.4 输出 JSON 结构

每个 task entry 包含：

```json
{
    "task_id": "task_000_xxx",
    "transcript_span": {
        "mode": "continuous",
        "start": 24,
        "end": 45,
        "length": 21
    },
    "call_counts": {
        "llm_calls": 8,
        "tool_calls": 1
    },
    "agent_id": "bench-dmxapi-gpt-5-mini-0007-serial"
}
```

顶层输出包含：

```json
{
    "session_mode": "continuous",
    "parallel": 1,
    "context_engine": null
}
```

### 14.4 三数据集适配状态

| 数据集 | `--session-mode` | 串行 Agent | cleanup 守卫 | transcript_span | 测试验证 |
|--------|-----------------|-----------|-------------|----------------|---------|
| pinchbench | ✅ | ✅ `-serial` | ✅ 3处守卫 | ✅ 单调递增 | ✅ 5-task 通过 |
| claw_eval | ✅ | ✅ `-serial` | ✅ 3处守卫 | ✅ 单调递增 | ✅ 5-task 通过 |
| frontierscience | ✅ | ✅ `-serial` | ✅ 3处守卫 | ✅ 单调递增 | ✅ 5-task 通过 |

### 14.5 代码变更清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `pinchbench/scripts/benchmark.py` | 修改 | 新增 `--session-mode` 参数，串行 agent 创建，transcript cursor 追踪，task_entries 含 span/counts/agent_id，输出元数据 |
| `pinchbench/scripts/lib_agent.py` | 修改 | `execute_openclaw_task` 增加 `cleanup_sessions` 参数，3处 cleanup 路径加守卫 |
| `claw_eval/scripts/benchmark.py` | 修改 | 同 pinchbench |
| `claw_eval/scripts/lib_agent.py` | 修改 | 同 pinchbench |
| `frontierscience/scripts/benchmark.py` | 修改 | 同 pinchbench |
| `frontierscience/scripts/lib_agent.py` | 修改 | 同 pinchbench |

### 14.6 代码审查记录（2026-04-18）

#### 审查范围

6 个文件（3 × benchmark.py + 3 × lib_agent.py），聚焦 session-mode continuous 相关变更。

#### 审查结论

| 检查项 | 状态 | 说明 |
|--------|------|------|
| `--session-mode` 参数定义 | ✅ | `choices=["isolated","continuous"]`, `default="isolated"` |
| continuous 模式约束校验 | ✅ | 要求 `parallel==1` 且非 multi-agent |
| 串行 agent 命名 | ✅ | `bench-{model_slug}-{run_id}-serial` |
| `cleanup_sessions` 传递 | ✅ | `session_mode != "continuous"` → continuous 时为 False |
| lib_agent.py 初始 cleanup 守卫 | ✅ | `if cleanup_sessions: cleanup_agent_sessions(agent_id)` |
| lib_agent.py 空 transcript retry 守卫 | ✅ | `if cleanup_sessions:` 保护 |
| lib_agent.py transient error retry 守卫 | ✅ | `if cleanup_sessions:` 保护 |
| `transcript_cursor` 追踪 | ✅ | 从 `transcript_span["end"]` 更新，传入下次 task |
| `transcript_span` 字段完整性 | ✅ | `mode`, `start`, `end`, `length` 四字段 |
| `call_counts` 字段 | ✅ | `llm_calls`, `tool_calls`（pinchbench 额外有 `guard_triggered`） |
| `agent_id` 输出 | ✅ | 从 `completed_jobs` 提取 |
| 输出 JSON 顶层元数据 | ✅ | `session_mode`, `parallel`, `context_engine` |
| 三数据集 task keys 一致性 | ✅ | 17 个字段完全一致 |
| 死代码清理 | ✅ | 移除 claw_eval/frontierscience 中未使用的 `results` 变量 |

#### 预期差异（不需对齐）

| 差异 | 原因 |
|------|------|
| pinchbench `call_counts` 含 `guard_triggered` | pinchbench 独有的 guard rail 机制 |
| pinchbench 含 `--max-llm-calls-per-task` 参数 | pinchbench 独有的调用次数限制功能 |
| frontierscience 无 multi-session task 支持 | frontierscience task 均为单 prompt，无需 session plan |

#### 5-task 验证测试结果

| 数据集 | Score | Agent | Span 范围 | Monotonic |
|--------|-------|-------|----------|-----------|
| pinchbench | 20.0% | `bench-dmxapi-gpt-5-mini-0017-serial` | 0 → 69 | ✅ |
| claw_eval | 11.0% | `bench-dmxapi-gpt-5-mini-0007-serial` | 0 → 68 | ✅ |
| frontierscience | 0.0% | `bench-dmxapi-gpt-5-mini-0008-serial` | 0 → 22 | ✅ |

所有数据集的 `transcript_span.start` 和上一个 task 的 `transcript_span.end` 严格相等，
证明 transcript cursor 追踪正确。
