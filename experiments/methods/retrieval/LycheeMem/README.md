# LycheeMem — Compact Long-Term Memory for LLM Agents

基于 [LycheeMem](https://github.com/LycheeMem/LycheeMem) 的结构化长期记忆框架，通过 Working Memory 的双阈值 token 管理和 Semantic Memory 的知识提取来减少 token 消耗。

## 运行实验

```bash
# 0. 安装依赖（需要 Python 3.11+）
cd /path/to/EcoClaw-Bench/experiments/methods/retrieval/LycheeMem
pip install -e .

# 1. 配置：复制 .env.example 为 .env，填写 LLM / Embedding（见下表）

# 2. 启动 LycheeMem 后端（保持该终端运行）
python main.py
# 看到类似：LycheeMem server starting on http://0.0.0.0:8000
# API 文档：http://127.0.0.1:8000/docs

# 3. （可选）注册并拿到 JWT，写入 OpenClaw 插件配置 —— 见下文「获取 Token」

# 4. 在仓库根目录另开终端跑 PinchBench（会启用 lycheemem-tools 插件）
cd /path/to/EcoClaw-Bench
./experiments/scripts/run_pinchbench_methods.sh --label lycheemem

# 多智能体 (MAS) 模式
./experiments/scripts/run_pinchbench_methods_mas.sh --label lycheemem \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

## 前置条件

- Python **3.11+**
- 已安装 [OpenClaw](https://github.com/openclaw/openclaw) CLI，且 gateway 可被 `openclaw config` 修改（`lycheemem` 标签会打开插件并 `gateway restart`）

## 配置

### LycheeMem 后端（`.env`）

| 变量 | 说明 |
|------|------|
| `LLM_MODEL` | litellm 格式的 LLM 模型 |
| `LLM_API_KEY` | LLM API key |
| `LLM_API_BASE` | LLM API endpoint |
| `EMBEDDING_MODEL` | litellm 格式的 embedding 模型 |
| `WM_MAX_TOKENS` | Working Memory 最大 token 数 |
| `WM_WARN_THRESHOLD` | 预压缩触发阈值（默认 0.7） |
| `WM_BLOCK_THRESHOLD` | 强制压缩触发阈值（默认 0.9） |

### OpenClaw 插件

插件配置在 `~/.openclaw/openclaw.json` 的 `plugins.entries.lycheemem-tools` 中：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `baseUrl` | `http://127.0.0.1:8000` | LycheeMem 后端地址 |
| `transport` | `mcp` | 通信协议 |
| `apiToken` | — | JWT Bearer Token |
| `enableAutoAppendTurns` | `true` | 自动镜像对话到 LycheeMem |
| `enableBoundaryConsolidation` | `true` | session 边界自动触发知识提取 |

## 获取 Token

```bash
# 注册
curl -s -X POST http://127.0.0.1:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "bench", "password": "bench123"}'

# 登录（token 过期后）
curl -s -X POST http://127.0.0.1:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "bench", "password": "bench123"}'
```

## 注意事项

- LycheeMem 后端需要**持续运行**
- JWT Token 有效期 7 天
- 跑完实验后脚本会自动禁用插件
