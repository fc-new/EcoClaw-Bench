# Selective Context — Self-Information Based Compression

基于 GPT-2 self-information 的 prompt 压缩，移除低信息量的内容单元。

## 运行

```bash
./experiments/scripts/run_pinchbench_methods.sh --label selctx-only
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ECOCLAW_SELCTX_RATIO` | `0.4` | 移除比例（0.4 = 移除 40%） |
| `ECOCLAW_SELCTX_UNIT` | `sentence` | 粒度：`sentence` / `phrase` / `token` |
| `ECOCLAW_SELCTX_MIN_LENGTH` | `200` | 最小触发长度 |

## 前置条件

```bash
# GPT-2 模型会在首次运行时自动下载（需要 HF_ENDPOINT=https://hf-mirror.com）