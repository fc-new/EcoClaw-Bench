# LycheeMem — Compact Long-Term Memory for LLM Agents

基于 [LycheeMem](https://github.com/LycheeMem/LycheeMem) 的结构化长期记忆框架，通过 Working Memory 的双阈值 token 管理和 Semantic Memory 的知识提取来减少 token 消耗。

## 运行实验

```bash
# 1. 启动 LycheeMem 后端（在另一个终端）
cd /home/user/cdm_program/Baseline-Bench/experiments/methods/LycheeMem
PYTHONPATH=/home/user/cdm_program/Baseline-Bench python main.py
# 等待显示 Uvicorn running on http://127.0.0.1:8000

# 2a. 单 Agent 模式
./experiments/scripts/run_pinchbench_methods.sh --label lycheemem

# 2b. 多智能体 (MAS) 模式
./experiments/scripts/run_pinchbench_methods_mas.sh --label lycheemem \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

## 前置条件

```bash
# 安装依赖（需要 Python 3.11+，在 base 环境）
cd experiments/methods/LycheeMem
pip install -e .
```

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
