# EcoClaw-Bench 多智能体系统 (MAS) 适配文档

本文档描述 EcoClaw-Bench 中 **Multi-Agent System (MAS)** 的完整适配方案。
MAS 模式通过 OpenClaw 的 `sessions_spawn` 工具实现 **coordinator → worker** 调度架构，
支持在 PinchBench、Claw-Eval、FrontierScience 三个数据集上运行。

---

## 目录

1. [架构概览](#1-架构概览)
2. [目录结构](#2-目录结构)
3. [环境准备](#3-环境准备)
4. [两种 MAS 模式](#4-两种-mas-模式)
5. [Agent Config 配置详解](#5-agent-config-配置详解)
6. [Skills 系统](#6-skills-系统)
7. [运行方式](#7-运行方式)
8. [代码变更总览](#8-代码变更总览)
9. [关键代码修改逻辑详解](#9-关键代码修改逻辑详解)
10. [核心模块说明](#10-核心模块说明)
11. [常见问题](#11-常见问题)

---

## 1. 架构概览

```
                    ┌─────────────────┐
                    │   Benchmark.py  │
                    │  (CLI 入口)      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  lib_agent.py   │
                    │  (执行层)        │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───┐  ┌──────▼─────┐  ┌─────▼──────┐
     │ Coordinator │  │   Worker   │  │   Worker   │
     │ (调度者)     │  │  (coder)   │  │(researcher)│
     └──────┬──────┘  └────────────┘  └────────────┘
            │
            │  sessions_spawn (OpenClaw 工具)
            ├──────► Worker A: 执行子任务
            └──────► Worker B: 执行子任务
```

**核心流程：**

1. `benchmark.py` 解析 CLI 参数，判断是否启用 MAS
2. `lib_agent.py` 中 `ensure_multi_agent_exists()` 创建 coordinator + worker agents
3. `_wrap_prompt_for_multi_agent()` 将原始任务 prompt 包装为 coordinator 指令
4. Coordinator 通过 `sessions_spawn` 调度 worker 执行子任务
5. Worker 在共享 workspace 中写入结果文件
6. Coordinator 收集结果，合成最终答案
7. `lib_grading.py` 对 transcript 进行评分（支持 MAS transcript 格式）

---

## 2. 目录结构

```
EcoClaw-Bench/
├── .env.example                         # 环境变量模板
├── experiments/
│   ├── agent-config/                    # Agent 拓扑配置（JSON）
│   │   ├── pinchbench_agents.json
│   │   ├── claw_eval_agents.json
│   │   └── frontierscience_agents.json
│   ├── skills/                          # Agent skills（需从 Google Drive 下载）
│   │   └── README.md                    # 下载说明
│   ├── dataset/
│   │   ├── pinchbench/scripts/
│   │   │   ├── benchmark.py             # CLI 入口
│   │   │   ├── lib_agent.py             # 执行层（含 MAS 逻辑）
│   │   │   ├── lib_grading.py           # 评分层（含 MAS 评分）
│   │   │   └── lib_tasks.py             # 任务加载
│   │   ├── claw_eval/scripts/           # 同上结构
│   │   └── frontierscience/scripts/     # 同上结构
│   └── scripts/
│       ├── common.sh                    # 公共函数（含 MAS 注入逻辑）
│       ├── run_pinchbench_ecoclaw.sh    # PinchBench EcoClaw 运行脚本
│       ├── run_pinchbench_baseline.sh   # PinchBench Baseline 运行脚本
│       ├── run_claw_eval.sh             # Claw-Eval 运行脚本
│       ├── run_frontierscience.sh       # FrontierScience 运行脚本
│       ├── run_pinchbench_methods.sh    # 单 Agent 方法消融实验
│       └── run_pinchbench_methods_mas.sh # 方法×MAS 联合消融实验 ⭐
```

---

## 3. 环境准备

### 3.1 基础环境

```bash
# 确保 OpenClaw CLI 已安装
which openclaw

# 确保 OpenClaw Gateway 运行中（脚本会自动检测并启动）
openclaw status
```

### 3.2 配置 .env

```bash
cp .env.example .env
```

编辑 `.env`，填入以下关键配置：

```bash
# 必填：API 配置
ECOCLAW_BASE_URL=https://your-api-endpoint.com/llm
ECOCLAW_API_KEY=sk-your-key-here

# 必填：模型配置
ECOCLAW_MODEL=tuzi/gpt-5.4
ECOCLAW_JUDGE=tuzi/gpt-5.4

# MAS 配置（可选，也可通过 CLI 参数传入）
ECOCLAW_ENABLE_MULTI_AGENT=false
ECOCLAW_AGENT_CONFIG=experiments/agent-config/pinchbench_agents.json
ECOCLAW_PARALLEL=1
```

### 3.3 下载 Skills

Skills 文件未包含在仓库中，需要从 Google Drive 下载：

```bash
# 下载后解压到 experiments/skills/
cd experiments/skills/
# 将下载的压缩包解压到此目录
# 解压后应有 coding-agent/, tavily/, summarize/ 等子目录
```

下载地址见 [experiments/skills/README.md](../experiments/skills/README.md)。

### 3.4 下载 Tasks

各数据集的 task 文件同样需要从 Google Drive 下载，详见各 `tasks/README.md`：

- `experiments/dataset/claw_eval/tasks/README.md`
- `experiments/dataset/pinchbench/tasks/README.md`
- `experiments/dataset/frontierscience/tasks/README.md`

---

## 4. 两种 MAS 模式

本适配支持两种 MAS 注入模式，通过是否传入 `--agent-config` 参数区分。

### 4.1 轻量模式（inject_multi_agent_config）

**触发条件：** `--enable-multi-agent` 但不传 `--agent-config`

```bash
bash experiments/scripts/run_pinchbench_ecoclaw.sh \
  --enable-multi-agent \
  --multi-agent-roles "researcher,coder"
```

**特点：**
- 所有 agent（coordinator + workers）使用同一个模型
- 不加载 skills
- 适合快速测试或模型不支持差异化配置的场景

**注入行为：** 修改 `~/.openclaw/openclaw.json` 的 `agents.defaults.subagents` 字段。

### 4.2 完整模式（inject_agent_config_from_file）⭐ 推荐

**触发条件：** 传入 `--agent-config`（自动开启 MAS）

```bash
bash experiments/scripts/run_pinchbench_ecoclaw.sh \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

**特点：**
- 每个 agent 可配置独立的模型（如 coordinator 用 gpt-5.4、coder 用 gpt-5.3-codex）
- 每个 agent 可配置独立的 skills
- 支持自定义 allowAgents 和并发数
- 自动加载 `experiments/skills/` 目录

**注入行为：**
1. 将 agent config JSON 的 `agents.list` 写入 `openclaw.json`
2. 将 `experiments/skills/` 添加到 `skills.load.extraDirs`
3. 在运行时通过 `_patch_runtime_agent_config()` 将配置应用到实际的 bench agent

---

## 5. Agent Config 配置详解

Agent config 文件位于 `experiments/agent-config/`，每个数据集一份。

### 5.1 文件结构

```jsonc
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "tuzi/gpt-5.4",      // 全局默认模型
        "fallbacks": [...]                // 降级模型列表
      },
      "subagents": {
        "model": "tuzi/gpt-5.4",         // 子 agent 默认模型
        "thinking": "medium",             // 思考级别: off/low/medium/high
        "maxConcurrent": 3,               // 最大并发子 agent 数
        "archiveAfterMinutes": 30         // 子会话归档超时
      }
    },
    "list": [
      {
        "id": "coordinator",              // 固定 ID
        "default": true,                  // 标记为协调者
        "model": "tuzi/gpt-5.4",
        "skills": ["workflow-orchestration-patterns", ...],
        "subagents": {
          "allowAgents": ["coder", "researcher"]  // 允许调度的 worker
        }
      },
      {
        "id": "coder",                    // Worker ID
        "model": "tuzi/gpt-5.3-codex",   // 可与 coordinator 不同
        "skills": ["coding-agent", ...]
      },
      ...
    ]
  },
  "tools": {
    "subagents": {
      "tools": { "deny": ["browser"] }   // 禁止 worker 使用的工具
    }
  }
}
```

### 5.2 三个数据集的配置差异

| 配置项 | PinchBench | Claw-Eval | FrontierScience |
|--------|-----------|-----------|-----------------|
| **Workers** | coder, researcher | coder, researcher, reviewer | researcher, reviewer |
| **Thinking** | medium | medium | high |
| **maxConcurrent** | 3 | 4 | 2 |
| **Coordinator skills** | orchestration, summarize, session-logs, data-analyst | orchestration, summarize, session-logs, saga | orchestration, summarize, session-logs, deep-research |
| **特色 Worker** | coder (gpt-5.3-codex) | reviewer (gpt-5.2) | researcher (含 hypothesis-generation, math-olympiad) |

### 5.3 自定义 Agent Config

你可以基于现有配置创建自己的：

```bash
cp experiments/agent-config/pinchbench_agents.json experiments/agent-config/my_config.json
# 编辑 my_config.json...
bash experiments/scripts/run_pinchbench_ecoclaw.sh --agent-config experiments/agent-config/my_config.json
```

> **注意：** `allowAgents` 中的 ID 必须与 `list` 中其他 agent 的 `id` 字段一致。运行时脚本会自动将这些配置级 ID 映射为实际的 `bench-*` 前缀 ID。

---

## 6. Skills 系统

Skills 为每个 agent 提供领域特定能力。完整模式下，脚本自动将 `experiments/skills/` 注入 OpenClaw 的 `skills.load.extraDirs`。

**Skills 路径解析逻辑：**

```bash
# 从 agent-config 文件位置推断 skills 目录
AGENT_CONFIG_DIR="$(dirname "${RESOLVED_AGENT_CONFIG}")"
SKILLS_DIR="${AGENT_CONFIG_DIR}/../skills"
# 即 experiments/agent-config/../skills → experiments/skills/
```

**常用 skills 对照：**

| Skill | 用途 | 典型角色 |
|-------|------|---------|
| `coding-agent` | 代码编写和修改 | coder |
| `tavily` | 网络搜索 | researcher |
| `deep-research` | 深度研究 | researcher |
| `workflow-orchestration-patterns` | 任务编排 | coordinator |
| `summarize` | 内容总结 | coordinator, reviewer |
| `debugger` | 调试分析 | coder |
| `hypothesis-generation` | 假设生成 | researcher (frontierscience) |

---

## 7. 运行方式

### 7.1 方法×MAS 联合消融实验 ⭐

当你需要在多智能体模式下测试各种节省 token 的方法时，使用 `run_pinchbench_methods_mas.sh`：

```bash
# 单个方法 + MAS（完整模式，推荐）
bash experiments/scripts/run_pinchbench_methods_mas.sh \
  --label ccr-only \
  --agent-config experiments/agent-config/pinchbench_agents.json

# 单个方法 + MAS（轻量模式）
bash experiments/scripts/run_pinchbench_methods_mas.sh \
  --label ccr-only

# 所有方法 + MAS（批量运行）
bash experiments/scripts/run_pinchbench_methods_mas.sh --all \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

**可用的方法标签：**

| 标签 | 方法 | 说明 |
|------|------|------|
| `baseline` | 无方法 | 纯 MAS 基线 |
| `prefix-cache` | OpenAI Prefix Cache | 稳定前缀触发 provider 缓存 |
| `cache-only` | Prompt Cache | 缓存编排 |
| `summary-only` | Session Summary | 空闲摘要 + context 注入 |
| `compression-only` | Tool Compression | 规则压缩工具输出 |
| `retrieval-only` | Keyword Retrieval | 关键词检索 |
| `router-only` | Model Router | 简单任务路由到小模型 |
| `qmd-only` | QMD Search | 全文检索 |
| `qmd-vsearch` | QMD VSearch | 向量检索 |
| `qmd-query` | QMD Query | LLM 查询 |
| `ccr-only` | CCR | LangChain 上下文压缩检索 |
| `llmlingua-only` | LLMLingua-2 | Token 级压缩 |
| `selctx-only` | Selective Context | 自信息压缩 |
| `concise-only` | Concise Output | 简洁输出指令 |
| `slim-prompt` | Slim Prompt | 精简系统提示 |
| `concise-slim` | Concise + Slim | 组合方法 |
| `lycheemem` | LycheeMem | 结构化长期记忆 |
| `compaction` | Compaction | OpenClaw 历史压缩 |
| `compaction-lcm` | Compaction + LCM | 历史压缩 + 无损上下文引擎 |

**结果目录：**
- MAS 模式: `results/raw/pinchbench/mas-<label>/`
- 单 Agent 模式: `results/raw/pinchbench/<label>/`

> **提示：** 对比单 Agent 和 MAS 下同一方法的效果，可以分别运行：
> ```bash
> # 单 Agent
> bash experiments/scripts/run_pinchbench_methods.sh --label ccr-only
> # MAS
> bash experiments/scripts/run_pinchbench_methods_mas.sh --label ccr-only \
>   --agent-config experiments/agent-config/pinchbench_agents.json
> ```

### 7.2 PinchBench

```bash
# EcoClaw + MAS（完整模式，推荐）
bash experiments/scripts/run_pinchbench_ecoclaw.sh \
  --agent-config experiments/agent-config/pinchbench_agents.json \
  --runs 1 \
  --suite "automated-only"

# EcoClaw + MAS（轻量模式）
bash experiments/scripts/run_pinchbench_ecoclaw.sh \
  --enable-multi-agent \
  --multi-agent-roles "researcher,coder"

# Baseline（禁用 EcoClaw plugin，对照实验）
bash experiments/scripts/run_pinchbench_baseline.sh \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

### 7.2 Claw-Eval

```bash
# MAS 完整模式
bash experiments/scripts/run_claw_eval.sh \
  --agent-config experiments/agent-config/claw_eval_agents.json \
  --runs 1

# 指定子集运行
bash experiments/scripts/run_claw_eval.sh \
  --agent-config experiments/agent-config/claw_eval_agents.json \
  --runs 1 \
  --suite "task_000_t01zh_email_triage,task_001_t02_email_triage"
```

### 7.3 FrontierScience

```bash
# MAS 完整模式
bash experiments/scripts/run_frontierscience.sh \
  --agent-config experiments/agent-config/frontierscience_agents.json \
  --runs 1
```

### 7.4 通用 CLI 参数

所有运行脚本支持以下参数：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--model` | 主模型 ID | `tuzi/gpt-5.4` |
| `--judge` | 评分模型 ID | `tuzi/gpt-5.4` |
| `--suite` | 任务子集（逗号分隔 task id 或 `all`/`automated-only`） | 按数据集不同 |
| `--runs` | 每个 task 重复次数 | 按数据集不同 |
| `--parallel` | 并行 task 数 | `1` |
| `--timeout-multiplier` | 超时倍数 | `1.0` |
| `--enable-multi-agent` | 启用 MAS（无需参数） | 关闭 |
| `--multi-agent-roles` | Worker 角色列表 | `researcher,coder` |
| `--agent-config` | Agent config JSON 路径（传入即开启 MAS） | 无 |

> **建议：** MAS 模式下 `--parallel` 保持为 1，因为每个 task 已经会创建多个 agent 并发工作。

---

## 8. 代码变更总览

本次适配共修改 **16 个文件**，新增约 **3093 行**，修改约 **193 行**。

### 8.1 Shell 基础设施

| 文件 | 变更内容 |
|------|---------|
| `common.sh` | +181 行：`backup/restore_openclaw_config`、`ensure_openclaw_gateway_running`、`inject_multi_agent_config`、`inject_agent_config_from_file` |
| `run_pinchbench_ecoclaw.sh` | +81 行：MAS CLI 参数、config 注入、SKILL_DIR fallback |
| `run_pinchbench_baseline.sh` | +85 行：同上（baseline 模式额外处理 EcoClaw plugin 禁用/恢复） |
| `run_claw_eval.sh` | +76 行：同上 |
| `run_frontierscience.sh` | +76 行：同上 |

### 8.2 Python 执行层（lib_agent.py × 3）

每个数据集的 `lib_agent.py` 新增以下核心函数：

| 函数 | 说明 |
|------|------|
| `ensure_multi_agent_exists()` | 创建 coordinator + workers，支持 config-driven 和 role-based 两种路径 |
| `_patch_runtime_agent_config()` | 将静态 config 模板（model/skills/allowAgents）注入到运行时 bench agent |
| `_patch_agent_allow_agents()` | 设置 coordinator 的 `subagents.allowAgents` |
| `_wrap_prompt_for_multi_agent()` | 将 task prompt 包装为 coordinator 调度指令（含 18 条规则） |
| `_build_workspace_fixture_manifest()` | 生成 workspace fixture 清单供 coordinator 参考 |
| `_build_worker_output_contract()` | 生成 worker → output file 映射 |
| `_collect_all_session_transcripts()` | 从 coordinator + 所有 worker 收集 transcript |
| `cleanup_multi_agent_sessions()` | 清理所有 agent 的历史 session |

`execute_openclaw_task()` 函数新增 `enable_multi_agent` 和 `multi_agent_ids` 参数。

### 8.3 Python 评分层（lib_grading.py × 3）

| 变更 | 说明 |
|------|------|
| `DEFAULT_JUDGE_MODEL` | 统一为 `"tuzi/gpt-5.4"` |
| `_is_mas_transcript()` | 检测 transcript 是否包含 MAS 特征 |
| `_summarize_mas_transcript()` | MAS transcript 专用摘要（区分 coordinator/worker 消息） |
| `_extract_scorecard_from_text()` | 从 judge 原始文本中提取评分卡（+3 个辅助函数） |
| `_parse_judge_response()` | 统一为 scorecard-first fallback 顺序 |
| `_normalize_judge_response()` | 统一为 try/except 模式，增加 `feedback`/`explanation` fallback keys |
| `_build_judge_prompt()` | 强化 sessions_spawn/sub-agent 禁止规则 |

### 8.4 Python 入口（benchmark.py × 3）

新增 `--enable-multi-agent`、`--multi-agent-roles`、`--agent-config` 三个 CLI 参数。
`_run_task_job()` 函数新增 MAS agent 创建和调度逻辑。

### 8.5 配置文件

| 文件 | 说明 |
|------|------|
| `.env.example` | +34 行：MAS 相关环境变量模板 |
| `.gitignore` | +5 行：排除 skills 子目录和 task 文件 |
| `experiments/agent-config/*.json` | 新增 3 个 agent 拓扑配置文件 |
| `experiments/skills/README.md` | 新增 skills 下载说明 |

---

## 9. 关键代码修改逻辑详解

本节详细说明各模块中最关键的代码修改逻辑，帮助协作者快速理解实现细节。

### 9.1 Shell 层：MAS Config 注入（common.sh）

#### 9.1.1 `inject_multi_agent_config()` — 轻量模式注入

此函数用于**不传 agent-config** 时的 MAS 注入。通过内嵌 Python 脚本直接修改 `openclaw.json`：

```python
# 核心注入逻辑（简化）
agents.defaults.model.primary = subagent_model      # 设置全局默认模型
agents.defaults.subagents.model = subagent_model     # 设置子 agent 模型
agents.defaults.subagents.thinking = "medium"        # 思考级别
agents.defaults.subagents.maxConcurrent = 4          # 最大并发
tools.subagents.tools.deny = ["browser"]             # 禁止 browser 工具
```

**设计考量：** 采用 deep-merge 策略，只覆盖 MAS 相关字段，保留用户的其他 OpenClaw 配置。

#### 9.1.2 `inject_agent_config_from_file()` — 完整模式注入

此函数用于**传入 agent-config JSON** 时的注入，逻辑更复杂：

```
Step 1: 读取当前 openclaw.json 和 agent-config JSON
Step 2: 从 agent-config 中识别 coordinator（default=true 或 id="coordinator"）
Step 3: Deep-merge agents.defaults（模型、subagents 配置）
Step 4: 用 coordinator 的 model 覆盖 defaults.model.primary
Step 5: 整体替换 agents.list（完全使用 config 中的 agent 列表）
Step 6: Deep-merge tools 配置（保留已有的 deny 列表，追加新项）
Step 7: 合并 commands 配置
Step 8: 将 skills_dir 追加到 skills.load.extraDirs 数组（去重）
Step 9: 写回 openclaw.json
```

**与轻量模式的关键区别：**
- 轻量模式只改 `defaults`，完整模式**替换整个 `agents.list`**
- 完整模式额外注入 `skills.load.extraDirs`，使 OpenClaw 能加载自定义 skills
- 完整模式的 `tools` 配置采用递归 deep-merge，不会覆盖用户已有的工具设置

#### 9.1.3 备份恢复机制

```bash
# 运行脚本中的生命周期
backup_openclaw_config          # 拷贝 openclaw.json → openclaw.json.bak.bench
inject_*                        # 注入 MAS 配置
trap 'restore_openclaw_config || true' EXIT  # 无论正常退出还是异常，都恢复
```

**防护设计：**
- `backup_openclaw_config()` 检测到已有备份时**拒绝覆盖**并报错，防止嵌套运行导致备份丢失
- `recover_stale_openclaw_config_backup()` 在每次运行开始时自动检测遗留备份并恢复
- 使用 `trap EXIT` 而非 `trap ERR`，确保 SIGTERM/SIGINT 等信号也能触发恢复

### 9.2 Python 执行层：Agent 创建与调度（lib_agent.py）

#### 9.2.1 `ensure_multi_agent_exists()` — Agent 创建核心

此函数有两条路径，由是否传入 `agent_config` 决定。

**Config-driven 路径**（推荐，传入 agent-config）：

```
1. _resolve_agent_config_roles(agent_config)  → 提取 agents.list
2. 遍历 list，识别 coordinator（default=true 或 id="coordinator"）
3. 为每个 agent 生成运行时 ID：
   bench-{config_id}-{model_slug}-{run_id}-j{job_index:04d}
   例: bench-coder-tuzi-gpt-5-4-run0001-j0000
4. 调用 ensure_agent_exists() 通过 openclaw agents add 创建每个 agent
5. 对每个 worker 调用 _patch_runtime_agent_config()：
   ├── 将 config 中的 model 写入运行时 agent entry
   ├── 将 config 中的 skills 写入运行时 agent entry
   └── 将 subagents.model 设为与 agent model 一致（避免降级到全局默认）
6. 对 coordinator 调用 _patch_runtime_agent_config()：
   ├── 同上 model/skills
   └── 将 allowAgents 从配置 ID 映射为运行时 bench-* ID
```

**Role-based 路径**（不传 agent-config）：

```
1. 为 coordinator 生成 ID: bench-coord-{model_slug}-{run_id}-j{job_index:04d}
2. 为每个 role 生成 worker ID: bench-{role}-{model_slug}-...
3. 所有 agent 使用同一模型
4. 调用 _patch_agent_allow_agents() 设置 coordinator 的 allowAgents
```

#### 9.2.2 `_patch_runtime_agent_config()` — 运行时配置注入

**问题背景：** `openclaw agents add` 创建的 agent 只有 `id`、`model`、`workspace`。但 agent-config JSON 中定义了额外的 `skills`、`name`、`subagents` 等字段。这些不会自动继承。

**解决方案：** 此函数直接修改 `openclaw.json` 中对应 agent entry 的字段：

```python
# 核心逻辑（简化）
target_entry["model"] = template["model"]              # 覆盖模型
target_entry["skills"] = template["skills"]            # 覆盖 skills 列表
target_entry["name"] = template["name"]                # 设置显示名（仅首次）
target_entry["subagents"] = template["subagents"]      # 覆盖子 agent 配置
target_entry["subagents"]["allowAgents"] = [...]       # 设置允许调度的 worker
target_entry["subagents"]["model"] = target_entry["model"]  # 子会话继承父模型
```

**并发安全：** 所有 openclaw.json 写操作都使用文件锁 `_openclaw_agent_lock()`（基于 `fcntl.flock`），防止并行 job 产生竞态。

#### 9.2.3 `execute_openclaw_task()` — MAS 执行流程改造

此函数是执行入口，MAS 模式下的完整流程：

```
┌─ MAS 模式 ──────────────────────────────────────────────────────────┐
│  1. cleanup_multi_agent_sessions()：清理所有 agent 的历史 session     │
│  2. prepare_task_workspace()：准备共享 workspace                     │
│  3. 设置超时: timeout × timeout_multiplier × MULTI_AGENT_MULTIPLIER │
│                                                   (默认 ×2.0)       │
│  4. _build_task_session_plan()：解析 task frontmatter 中的 sessions  │
│  5. 遍历 session plan:                                              │
│     ├── _wrap_prompt_for_multi_agent()：包装 prompt                  │
│     └── _run_once()：通过 openclaw agent 命令执行                    │
│  6. time.sleep(2.0)：等待 worker session 写入                       │
│  7. _collect_all_session_transcripts()：                            │
│     ├── main_transcript = coordinator 的 session（用于评分）         │
│     └── all_transcripts = coordinator + 所有 worker（用于 cost）     │
│  8. 返回结果（使用 all_transcripts 计算 usage/llm_calls）            │
└──────────────────────────────────────────────────────────────────────┘

┌─ 单 Agent 模式 ─────────────────────────────────────────────────────┐
│  1. cleanup_agent_sessions()                                        │
│  2. prepare_task_workspace()                                        │
│  3. 遍历 session plan → _run_once()                                 │
│  4. _load_transcripts_for_session_ids()                             │
│  5. 空 transcript / transient error 时自动重试一次                   │
│  6. 返回结果                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

**关键设计决策：**
- MAS 模式下**不做空 transcript 重试**：coordinator 有自己的 fallback 规则，重试只会创造新 session
- MAS 模式下 timeout 乘以 2.0 倍：因为 coordinator 需要等待 worker 完成
- 使用共享 workspace：所有 agent 的 `workspace_dir` 相同，worker 通过文件系统与 coordinator 通信

#### 9.2.4 `_wrap_prompt_for_multi_agent()` — Coordinator Prompt 构建

此函数将原始 task prompt 包装为 coordinator 可理解的调度指令：

```
原始 prompt: "请分析以下数据..."

包装后 prompt:
┌──────────────────────────────────────────────────┐
│ "You are a coordinator agent..."                 │
│                                                  │
│ ## Available Worker Agents                       │
│   - Role: coder, agentId: "bench-coder-..."      │
│   - Role: researcher, agentId: "bench-res-..."   │
│                                                  │
│ ## Workspace Fixtures (Pre-deployed)             │
│   - 1. data.csv (from fixture source: data.csv)  │
│                                                  │
│ ## Mandatory Worker Output Files                 │
│   - coder: worker_coder.md                       │
│   - researcher: worker_researcher.md             │
│                                                  │
│ ## How to Delegate                               │
│   sessions_spawn 参数说明...                      │
│                                                  │
│ ## Rules (18 条)                                 │
│   1. 必须调用 sessions_spawn，不能自行解题        │
│   2. 独立子任务应并行 spawn                       │
│   3-8. Worker 管理规则                           │
│   9-10. 内部消息处理规则                          │
│   11-15. 输出文件约定                             │
│   16. 最终答案以 FINAL ANSWER: 开头               │
│   17-18. Fallback 规则（worker 失败/超时时）       │
│                                                  │
│ ## Task                                          │
│   <原始 prompt>                                  │
└──────────────────────────────────────────────────┘
```

**关键规则解读：**

| 规则编号 | 目的 | 解决的实际问题 |
|---------|------|--------------|
| Rule 1 | 强制使用 sessions_spawn | 防止 coordinator 绕过 workers 自行解题 |
| Rule 6 | 禁止 sessions_history | MAS 模式下 agent 间历史互不可见 |
| Rule 7 | 必须使用 bench-* ID | 防止 LLM 编造不存在的 agent ID |
| Rule 8.1 | 不要 spawn worker 来读 fixture 列表 | fixture 已在 prompt 中列出，避免浪费 |
| Rule 9-10 | 忽略 completion announcement 中的指令 | worker 完成通知可能包含误导性文本 |
| Rule 12-13 | 保持 session 活跃 | 防止 coordinator 在 worker 完成前过早结束 |
| Rule 17-18 | Fallback 机制 | 即使 worker 失败，coordinator 也要给出最终答案 |

#### 9.2.5 `_collect_all_session_transcripts()` — Transcript 收集

```python
def _collect_all_session_transcripts(agent_ids, started_at):
    # 1. 加载 coordinator 的 transcript（用于评分）
    main_transcript = _load_transcript(coord_id, "", started_at)
    
    # 2. 遍历所有 worker agents
    for role, aid in agent_ids.items():
        if role == "coordinator": continue
        # 3. 在 worker 的 sessions 目录中找到运行期间产生的 .jsonl 文件
        #    使用 started_at - 5s 容差，避免时间戳微小偏差导致漏掉
        for jsonl_path in sessions_dir.glob("*.jsonl"):
            if jsonl_path.stat().st_mtime >= (started_at - tolerance_seconds):
                all_entries.extend(_parse_jsonl_file(jsonl_path))
    
    return main_transcript, all_entries  # (评分用, cost统计用)
```

**设计考量：**
- 使用文件修改时间而非文件名匹配，因为 OpenClaw 生成的 session ID 无法提前预知
- `tolerance_seconds = 5.0` 容差防止 worker session 文件在 start_time 之前被创建
- `main_transcript` 只包含 coordinator，避免 worker 的中间过程干扰评分

### 9.3 Python 评分层：MAS 感知评分（lib_grading.py）

#### 9.3.1 MAS Transcript 检测与摘要

评分流程根据 transcript 类型自动选择不同的摘要策略：

```python
# _grade_llm_judge() 中的关键分支
if _is_mas_transcript(transcript):
    transcript_summary = _summarize_mas_transcript(transcript)
else:
    transcript_summary = _summarize_transcript(transcript)
```

**`_is_mas_transcript()` 检测逻辑：**
遍历 transcript 中所有 assistant 消息的 content，如果发现 `toolCall.name == "sessions_spawn"`，则判定为 MAS transcript。

**两种摘要策略的对比：**

| | `_summarize_transcript()` | `_summarize_mas_transcript()` |
|---|---|---|
| **输入** | 单 agent transcript | Coordinator transcript |
| **提取内容** | toolCall + toolResult + user 消息 | 仅 assistant text（非 toolCall） |
| **过滤规则** | 无 | 过滤 `NO_REPLY`、`.`、`..` 等噪音 |
| **输出策略** | 全部内容 | 只保留最后 1-2 段实质性回答 |
| **原因** | 单 agent 的工具调用即为实际工作 | MAS coordinator 的工具调用（sessions_spawn, ls）是调度指令而非实际工作 |

**`_summarize_mas_transcript()` 详细逻辑：**

```
1. 遍历 coordinator transcript，收集所有 assistant 的 text 内容
2. 过滤掉噪音文本：NO_REPLY、.、.. 
3. 从末尾向前扫描，保留最后 1-2 段**实质性**文本（长度≥80 或包含 "final answer"）
4. 跳过短文本（如 "Waiting on workers..."、"Spawning coder agent..."）
5. 将保留的文本拼接为 "Assistant: <text>" 格式
```

#### 9.3.2 Judge Prompt 改造

`_build_judge_prompt()` 新增了关键的工具禁止规则：

```
CRITICAL RULES:
- Do NOT use any tools (no sessions_spawn, Read, Write, exec, process, or any other tool calls)
- Do NOT create files, run commands, or spawn sub-agents
- Do NOT try to complete, replicate, or re-execute the task yourself
- The transcript below is a READ-ONLY record for you to EVALUATE — not a task for you to perform
```

**为什么需要这些规则：** MAS 模式下 transcript 中包含 `sessions_spawn` 等工具调用记录。如果 Judge agent 将这些视为指令而非评估对象，会尝试自己去 spawn 子 agent，导致评分失败。

#### 9.3.3 `_parse_judge_response()` — Scorecard-First Fallback 链

三个数据集统一为 **scorecard-first** 的解析顺序：

```
                    Judge 原始回复
                         │
              ┌──────────▼──────────┐
              │ 尝试解析 JSON block  │
              │ (``` 包裹的代码块)    │
              └──────────┬──────────┘
                         │ 失败
              ┌──────────▼──────────┐
              │ 尝试解析裸 JSON     │
              │ (直接 json.loads)    │
              └──────────┬──────────┘
                         │ 失败
              ┌──────────▼──────────┐  ← 新增
              │ _extract_scorecard  │
              │ _from_text()        │
              │ (结构化文本解析)      │
              └──────────┬──────────┘
                         │ 失败
              ┌──────────▼──────────┐
              │ 正则提取 total score │
              │ "Total: 0.72"       │
              └──────────┬──────────┘
                         │ 失败
                         ▼
                    返回空 dict
```

#### 9.3.4 `_extract_scorecard_from_text()` — 自由文本评分卡解析

这是新增的最复杂的函数（~120 行），用于从 judge 的非 JSON 回复中提取评分。当 judge 模型不严格遵守 JSON 输出要求时，作为 fallback 生效。

**解析策略：**

```
输入示例:
  "Task Completion - 0.8
   Code Quality - 0.7
   Total: 0.75
   Notes: Good overall performance"

解析流程:
1. 清除 markdown 代码块标记
2. 逐行扫描，使用 4 种正则模式匹配:
   ├── total_re:          匹配 "Total/Overall/Final: 0.75" → 提取 total
   ├── inline_score_re:   匹配 "Task Completion - 0.8" → 提取 criterion + score
   ├── criterion_header_re: 匹配独立的 criterion 名称行 → 设置 pending_label
   └── score_only_re:     匹配 "Score: 0.8" → 与 pending_label 配对
3. 辅助函数过滤噪音:
   ├── _normalize_label(): 去除前缀符号，标准化空格
   ├── _looks_like_total_label(): 排除 "total/overall/final" 标签被当作 criterion
   └── _is_generic_score_label(): 排除 "score/notes/feedback" 等通用标签

输出:
  {"scores": {"Task Completion": 0.8, "Code Quality": 0.7}, "total": 0.75, "notes": "..."}
```

#### 9.3.5 `_normalize_judge_response()` — 响应格式统一化

不同 judge 模型返回的 JSON 结构可能不同。此函数将各种格式统一为 `{scores, total, notes}`：

```python
# 统一使用 try/except 而非 isinstance 检查
# 已知的各种 judge 输出格式:

# 格式 1（标准）: {"scores": {...}, "total": 0.7, "notes": "..."}
# 格式 2:        {"criteria_scores": {...}, "score": 0.7}
# 格式 3:        {"breakdown": {...}, "total_score": 0.7}
# 格式 4:        {"justification": "...", "total": 0.7}

# 归一化逻辑:
scores = parsed.get("scores")
        or parsed.get("criteria_scores")
        or parsed.get("breakdown")
        or parsed.get("criteria")

total = parsed.get("total")
       or parsed.get("score")
       or parsed.get("total_score")
       or parsed.get("overall_score")

notes = parsed.get("notes")
       or parsed.get("justification")
       or parsed.get("feedback")       # 新增
       or parsed.get("explanation")     # 新增

# 如果 total 缺失但 scores 非空 → 自动计算 average
if total is None and scores:
    total = sum(scores.values()) / len(scores)
```

### 9.4 Python 入口层：MAS 参数传递（benchmark.py）

#### 9.4.1 CLI 参数新增

```python
parser.add_argument("--enable-multi-agent", action="store_true")
parser.add_argument("--multi-agent-roles", type=str)
parser.add_argument("--agent-config", type=str)
```

**优先级链：** CLI 参数 > 环境变量 > 默认值

```
--agent-config → ECOCLAW_AGENT_CONFIG → None
--enable-multi-agent → ECOCLAW_ENABLE_MULTI_AGENT → false
--multi-agent-roles → ECOCLAW_MULTI_AGENT_ROLES → "researcher,coder"
```

**自动开启规则：** 传入 `--agent-config` 会自动设置 `enable_multi_agent = True`。

#### 9.4.2 `_run_task_job()` 改造

```python
# 原始流程（单 agent）:
agent_id = f"bench-{model_slug}-{run_id}-j{job_index:04d}"
ensure_agent_exists(agent_id, model, agent_workspace)
execute_openclaw_task(agent_id=agent_id, ...)

# MAS 流程:
multi_agent_ids = ensure_multi_agent_exists(
    model_id=model,
    run_id=run_id,
    job_index=job_index,
    workspace_dir=agent_workspace,
    roles=multi_agent_roles,
    agent_config=agent_config,  # 传入完整 config dict
)
agent_id = multi_agent_ids["coordinator"]  # coordinator 作为主 agent
execute_openclaw_task(
    agent_id=agent_id,
    enable_multi_agent=True,
    multi_agent_ids=multi_agent_ids,  # 传入所有 agent ID 映射
    ...
)
```

### 9.5 三个数据集间的实现差异

虽然三个数据集的 MAS 逻辑高度统一，但存在以下针对数据集特性的差异：

| 差异点 | PinchBench | Claw-Eval | FrontierScience |
|--------|-----------|-----------|-----------------|
| **Multi-session 支持** | ✅ `_build_task_session_plan()` 解析 task frontmatter 中的 `sessions` 列表 | ✅ 同左 | ❌ 不需要（无多轮 task） |
| **Session 循环** | 循环执行 session plan | 循环执行 session plan | 单次执行 |
| **Transcript 加载** | `_load_transcripts_for_session_ids()` 聚合多 session | 同左 | `_load_transcript()` 单 session |
| **默认 Worker 角色** | researcher, coder | coder, researcher, reviewer | researcher, reviewer |
| **轻量模式 subagent thinking** | medium | medium | high |
| **轻量模式 maxConcurrent** | — | 4 | 2 |
| **Baseline 脚本** | ✅ 禁用 EcoClaw plugin | ❌ | ❌ |

---

## 10. 核心模块说明

### 10.1 OpenClaw Config 生命周期

MAS 运行期间会修改 `~/.openclaw/openclaw.json`。为安全起见，采用 **备份-恢复** 机制：

```
运行开始 → backup_openclaw_config()    → 备份到 .bak.bench
         → inject_*()                  → 注入 MAS 配置
         → 执行 benchmark
运行结束 → restore_openclaw_config()   → 恢复原始配置（通过 trap EXIT）
异常恢复 → recover_stale_openclaw_config_backup()  → 下次运行前自动恢复
```

### 10.2 Coordinator Prompt 工程

`_wrap_prompt_for_multi_agent()` 生成的 coordinator 指令包含以下关键部分：

1. **Worker Agent 列表** — 包含 role 和精确的 `bench-*` agentId
2. **Workspace Fixtures** — 预部署的文件清单
3. **Output Contract** — 每个 worker 对应的输出文件名
4. **18 条执行规则** — 确保 coordinator 正确使用 `sessions_spawn`，不自行解题，等待 worker 完成后合成答案

### 10.3 Transcript 收集与评分

MAS 模式下 transcript 处理与单 agent 不同：

- **主 transcript**：coordinator 的 session（用于评分）
- **全量 transcript**：coordinator + 所有 worker sessions（用于 token/cost 统计）
- **MAS 检测**：`_is_mas_transcript()` 检查是否存在 `sessions_spawn` tool call
- **MAS 摘要**：`_summarize_mas_transcript()` 只提取 toolCall 信息（不包含 assistant 文本），避免 coordinator 指令噪音干扰 judge

### 10.4 Agent ID 映射

Config 中的 agent ID（如 `coder`）在运行时会被映射为全局唯一的 bench ID：

```
配置 ID:  coder
运行时 ID: bench-coder-tuzi-gpt-5-4-run0001-j0000
```

`_patch_runtime_agent_config()` 负责将配置中的 model/skills 应用到这个运行时 ID 上。
coordinator 的 `allowAgents` 也会自动从配置 ID 映射到运行时 ID。

---

## 11. 常见问题

### Q: 运行后 openclaw.json 被改坏了怎么办？

脚本启动时会自动检测并恢复上次遗留的备份（`recover_stale_openclaw_config_backup`）。
如果仍有问题，手动恢复：

```bash
cp ~/.openclaw/openclaw.json.bak.bench ~/.openclaw/openclaw.json
rm ~/.openclaw/openclaw.json.bak.bench
```

### Q: Worker 没有执行任何操作 / Coordinator 自己解题了？

检查 coordinator 的 `allowAgents` 配置是否正确，确保 worker ID 在列表中。
查看 log 中是否有 `"Patched allowAgents"` 日志。

### Q: 评分全是 0 分？

MAS 模式下 LLM 输出存在较大随机性，单次运行 0 分不一定是代码问题。建议：
- 增加 `--runs` 次数（如 3 次）取平均
- 检查 transcript 是否有内容（非空）

### Q: skills 没有加载？

确认 `experiments/skills/` 目录下有实际的 skill 子目录（非空的 README.md）。
查看 log 中是否有 `"Added skills extraDir"` 日志。

### Q: 如何只运行单 agent（不启用 MAS）？

不传 `--enable-multi-agent` 和 `--agent-config` 即可：

```bash
bash experiments/scripts/run_pinchbench_ecoclaw.sh --runs 1
```

### Q: Baseline 脚本和 EcoClaw 脚本有什么区别？

`run_pinchbench_baseline.sh` 在运行前会 **禁用 EcoClaw plugin**（`openclaw plugins disable ecoclaw`），运行结束后恢复。用于与 EcoClaw 模式做对照实验。其余数据集只有 EcoClaw 脚本。
