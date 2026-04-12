# OpenSpace — Self-Evolving Skill Engine

基于 [OpenSpace](https://github.com/HKUDS/OpenSpace) 的自进化技能引擎。本仓库通过 **OpenClaw 插件**（`openclaw-plugin/`）把 OpenSpace 的 MCP 工具挂到 PinchBench 使用的 `openclaw agent` 上：代理 `execute_task` / `search_skills` / `fix_skill` / `upload_skill`，并在 `before_prompt_build` 中注入冷/热两阶段的工作流说明。

**论文中的核心指标（GDPVal，50 个真实专业任务）可作参考：**

- Phase 2 warm start 相对 Phase 1 cold start 的 token 变化等（见上游文档）
- 本仓库的 PinchBench 使用独立任务集与脚本；**两阶段评估**通过 label `openspace-cold` 与 `openspace-hot` 体现（见下文）

**省钱原理：** 不依赖单次对话压缩（与 LLMLingua / slim-prompt 不同），而是跨任务复用成功执行模式；`execute_task` 在 OpenSpace 内部执行并沉淀技能，`search_skills` 可在本地注册表与 open-space.cloud 上检索。

---

## 架构（本仓库实际部署方式）

1. **后台进程**：`openspace-mcp --transport streamable-http --host 127.0.0.1 --port <PORT>`（默认端口见 `OPENSPACE_PORT`）。
2. **OpenClaw 插件**：`experiments/methods/retrieval/openspace/openclaw-plugin` 在网关内注册工具，通过 HTTP 调用上述 MCP 端点（Streamable HTTP + SSE）。
3. **与 `openclaw mcp set` 的关系**：当前使用的 OpenClaw 版本通过 **插件 + `plugins.entries`** 集成即可；**不需要**在 README 里手写 `openclaw mcp set`（旧文档已废弃）。
4. **工具可见性**：若全局使用 `tools.profile`（如 `coding`），仅包含核心工具；脚本会在注册 OpenSpace 时写入 `tools.alsoAllow: ["group:plugins"]`，否则插件工具不会出现在 LLM 工具列表中。

---

## 两阶段评估（Cold / Hot）

与「先建技能库、再复用」的流程对应：

| 阶段 | Label | 意图 |
|------|--------|------|
| **Phase 1 — 冷启动** | `openspace-cold` 或 `openspace` | 倾向让 agent 通过 **`execute_task`** 把任务交给 OpenSpace 内部 grounding agent，在 `OPENSPACE_WORKSPACE` 中积累本地技能与记录。 |
| **Phase 2 — 热重跑** | `openspace-hot` | 在同一持久化 workspace 上再跑同一套任务；倾向先 **`search_skills`** 再执行或再委托。 |

**推荐顺序：** 先完整跑 `openspace-cold`（或 `openspace`），再跑 `openspace-hot`，并**保持 `OPENSPACE_WORKSPACE` 路径不变**，这样热跑才能读到冷跑产生的技能。

**Hook 与 `OPENSPACE_MODE`：** 插件里冷/热文案由 Node 进程中的 `process.env.OPENSPACE_MODE` 决定（`cold` / `hot`）。`start_openspace_server` 会给 **openspace-mcp** 子进程设置该变量；若你希望网关侧 hook 与 label 严格一致，可在运行 benchmark **之前**在同一 shell 中执行 `export OPENSPACE_MODE=cold` 或 `export OPENSPACE_MODE=hot`，再执行 `run_pinchbench_methods.sh`。

---

## 运行实验

```bash
# 1. 安装 OpenSpace（Python 版本需满足上游要求，见官方仓库）
pip install git+https://github.com/HKUDS/OpenSpace.git

# 2. （可选）下载上游 host skills 到 OpenClaw skills 目录
SKILL_DIR="${HOME}/.openclaw/skills"
mkdir -p "${SKILL_DIR}/delegate-task" "${SKILL_DIR}/skill-discovery"
BASE="https://ghfast.top/https://raw.githubusercontent.com/HKUDS/OpenSpace/main/openspace/host_skills"
curl -sSfL "${BASE}/delegate-task/SKILL.md"  -o "${SKILL_DIR}/delegate-task/SKILL.md"
curl -sSfL "${BASE}/skill-discovery/SKILL.md" -o "${SKILL_DIR}/skill-discovery/SKILL.md"

# 3. 配置项目根目录 .env（见下表，尤其是 OPENSPACE_WORKSPACE 与内部 LLM）

# 4a. 单 Agent — Phase 1 冷启动
./experiments/scripts/run_pinchbench_methods.sh --label openspace-cold
# 与 openspace-cold 等价：
# ./experiments/scripts/run_pinchbench_methods.sh --label openspace

# 4b. 单 Agent — Phase 2 热重跑（建议与 4a 共用同一 OPENSPACE_WORKSPACE）
./experiments/scripts/run_pinchbench_methods.sh --label openspace-hot

# 4c. 单 Agent — OpenSpace + Compaction
./experiments/scripts/run_pinchbench_methods.sh --label openspace-compaction

# 4d. 多智能体 (MAS)
./experiments/scripts/run_pinchbench_methods_mas.sh --label openspace-cold \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

脚本会在每次 run 中：`start_openspace_server` → `register_openspace_plugin` → `openclaw gateway restart`；结束后 `reset_openspace` 会关闭 MCP 并关闭插件条目（并 `unset tools.alsoAllow`，避免影响其它实验）。

---

## 前置条件

```bash
openspace-mcp --help
```

若系统 Python 过旧，在 `.env` 中指定另一环境中的二进制，例如：

```bash
ECOCLAW_OPENSPACE_MCP_CMD=/path/to/conda/env/bin/openspace-mcp
```

---

## 配置（项目根 `.env`）

| 变量 | 必填 | 说明 |
|------|------|------|
| `OPENSPACE_WORKSPACE` | **是** | OpenSpace 工作目录（技能库、日志、录音等），建议**固定路径**以便冷/热共享。 |
| `OPENSPACE_MODEL` | **execute_task 强烈建议** | 内部 grounding agent 使用的 **litellm** 模型 id，例如与网关一致的 OpenAI 兼容模型：`openai/gpt-5.4-mini`。 |
| `OPENSPACE_LLM_API_KEY` | **execute_task 强烈建议** | 上述模型所用 API Key（可与 `ECOCLAW_API_KEY` 相同，若走同一供应商）。 |
| `OPENSPACE_LLM_API_BASE` | **execute_task 强烈建议** | 兼容 OpenAI 的 API Base（例如与 `ECOCLAW_BASE_URL` 一致）。 |
| `OPENSPACE_API_KEY` | 可选 | [open-space.cloud](https://open-space.cloud) 社区密钥；不填时 `search_skills` 仍可搜本地，云端部分会跳过。 |
| `OPENSPACE_HOST_SKILL_DIRS` | 可选 | 逗号分隔的目录列表，用于注册/检索本机技能（常设为 `~/.openclaw/skills`）。 |
| `OPENSPACE_PORT` | 可选 | MCP HTTP 端口，默认 `8081`。 |
| `ECOCLAW_OPENSPACE_MCP_CMD` | 可选 | `openspace-mcp` 可执行文件绝对路径。 |

**说明：**

- **`execute_task` 与 PinchBench 主 agent 是两套调用链**：主 agent 用 OpenClaw 配置的模型；OpenSpace **内部** agent 只读 `OPENSPACE_*` / `OPENSPACE_LLM_*`，若未配置会出现 litellm 401 等问题。
- **`search_skills` 与云端**：配置 `OPENSPACE_API_KEY` 后，混合检索（`source=all`）可命中社区技能；仅本地时可不填或搜 `source=local`。

---

## 插件与 OpenClaw（脚本自动完成）

每次启用 OpenSpace label 时，脚本会：

1. 启动 `openspace-mcp`（streamable-http），并传入 workspace、技能目录、**内部 LLM**、以及 `OPENSPACE_MODE`（cold/hot）等环境变量。
2. 在 `openclaw.json` 中注册插件目录、`plugins.entries.openspace-tools`（含 `hooks.allowPromptInjection`）、以及 **`tools.alsoAllow: ["group:plugins"]`**。
3. 重启 gateway。

无需手动执行已废弃的 `openclaw mcp set openspace ...`。

---

## 技能进化（上游语义）

OpenSpace 常见的进化类型包括：修复失败技能（FIX）、派生优化（DERIVED）、从成功轨迹捕获新模式（CAPTURED）。技能与元数据落在 `OPENSPACE_WORKSPACE` 下（如 SQLite 等，以上游版本为准）；可用 `openspace-dashboard` 等工具浏览（若已安装）。

---

## 注意事项与排错

- **后台进程**：PID 写在 `/tmp/openspace_mcp_bench.pid`；异常退出时可查看 `/tmp/openspace_mcp_bench.log`。
- **`execute_task` 全失败、401**：检查 `OPENSPACE_MODEL` / `OPENSPACE_LLM_API_KEY` / `OPENSPACE_LLM_API_BASE` 是否与你的供应商一致。
- **插件工具不出现**：确认本次 run 已执行 `register_openspace_plugin`（含 `group:plugins`）；不要在同一次实验里手动删掉 `tools.alsoAllow` 除非你知道后果。
- **冷/热对比**：务必固定同一 `OPENSPACE_WORKSPACE`；热跑前不要清空该目录（除非你要刻意对比「无库」基线）。
- 与 **compaction** 组合时使用 label `openspace-compaction`（脚本内会对 `start_openspace_server` 使用默认 cold 模式并打开 safeguard compaction）。
