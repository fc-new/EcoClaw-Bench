# EverMemOS Retrieval — 外部记忆检索（EcoClaw 集成）

本目录是 EverMemOS 的完整项目副本。本文档聚焦 EcoClaw-Bench 的接入与跑分方式。

## GitHub

- 上游仓库：`https://github.com/EverMind-AI/EverOS/tree/agent_memory`

## 开关

| 类型 | 值 |
|------|----|
| label | `evermemos` |
| 主要环境变量 | `ECOCLAW_EVERMEMOS_BASE_URL`（默认 `http://localhost:1995`） |

## 部署方式（重要）

这个方法**必须先用 Docker 部署依赖服务**（MongoDB / Elasticsearch / Milvus / Redis）。

> 注意：本目录的 `docker-compose.yaml` 主要负责依赖服务，应用本身仍用 `uv run` 本地启动。

## 启动步骤

```bash
cd experiments/methods/retrieval/EverMemOS-agent_memory

## 部署EverMemOS
参考上游仓库部署说明。

## 跑 PinchBench

```bash
# 单 Agent
bash experiments/scripts/run_pinchbench_methods.sh \
  --label evermemos \
  --suite task_04_weather \
  --runs 1

# 多 Agent（MAS）
bash experiments/scripts/run_pinchbench_methods_mas.sh \
  --label evermemos \
  --suite task_04_weather \
  --runs 1
```

## 机制

1. 方法脚本会临时补丁 `~/.openclaw/openclaw.json`：
   - 将 memory slot 指向 `evermemos-openclaw-plugin`
   - 注入插件路径与配置（`baseUrl/userId/groupId/topK/memoryTypes/retrieveMethod`）
2. 任务执行前检索记忆、执行后写回记忆。
3. 跑完会自动恢复 OpenClaw 配置。

## 常见问题

1. `fetch failed`：EverMemOS API 没启动或 `baseUrl` 错。
2. `localhost:27017 connect failed`：MongoDB 没启动（通常是 docker daemon 未就绪）。
3. `docker compose` 不可用：先确认 `docker info` 正常。

## 代码位置

- 插件：`experiments/methods/retrieval/EverMemOS-agent_memory/evermemos-openclaw-plugin`
- 方法脚本：`experiments/scripts/run_pinchbench_methods.sh` / `experiments/scripts/run_pinchbench_methods_mas.sh`
