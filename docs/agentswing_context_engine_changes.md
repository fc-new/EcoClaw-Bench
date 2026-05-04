# AgentSwing Context Engine 修改与验证记录

本文档记录本轮围绕 OpenClaw AgentSwing 上下文管理插件完成的修改、设计思路、关键代码路径与验证结果。目标是让 `keep-last-n`、`summary`、`token-ratio` 触发机制在 PinchBench `continuous` 模式下真正可用、可审计、可复现。

## 背景与目标

本项目是针对 OpenClaw 的 baseline 实验框架。AgentSwing 插件用于复现论文中的两类上下文管理策略：

- `Keep-Last-N`：当上下文超过阈值时，仅保留最近 `N` 个 interaction turns。
- `Summary`：当上下文超过阈值时，将历史轨迹压缩为 `(q, Sum)`，即原始用户问题加摘要状态。

本轮重点验证和修复的不是任务分数，而是机制本身：

- PinchBench 必须运行在 `continuous` 模式，即所有任务共用同一个 OpenClaw session。
- `keep-last-n` 必须从插件自己的持久化 canonical state 中取最近 `N` 个真实轨迹，而不是只处理当前 `assemble` hook 传入的短上下文。
- `summary` 必须按 AgentSwing 论文要求输出 `(q, Sum)`，并复用 OpenClaw runtime 的模型鉴权配置。
- `token-ratio` 阈值必须按配置生效，低于阈值不触发，高于阈值触发对应策略。
- 插件实现需要参考 `scripts/openclaw-context-safe-plugin-main`，把上下文状态持久化到磁盘，避免只依赖运行时内存。

## 核心设计

### 1. Canonical Session State 作为插件真相源

之前插件更接近“只在 assemble 时处理当前 messages”的模式，这会带来一个问题：如果 OpenClaw 在某轮之后传入的是已经压缩过的短上下文，插件可能会丢失完整历史，无法真正实现 continuous session 上的上下文管理。

本轮改为类似 `context-safe` 插件的思路：插件维护自己的 canonical session state，并将完整轨迹单独落盘。运行时的 `assemble` / `compact` / `afterTurn` 都先同步 canonical state，再从 canonical state 生成给模型看的 managed context。

新增文件：

- `experiments/plugins/agentswing-context-engine/src/artifact-dir.ts`
- `experiments/plugins/agentswing-context-engine/src/canonical-session-state.ts`

落盘路径默认是：

```text
~/.openclaw/artifacts/agentswing-context-engine/session-state/<sessionId>.json
```

关键状态结构包括：

```ts
export type AgentSwingCanonicalSessionState = {
    version: 1;
    sessionId: string;
    sourceMessageCount: number;
    configSnapshot: AgentSwingConfig;
    messages: Msg[];
    updatedAt: string;
    messageCount: number;
    toolResultCount: number;
    originalPrompt?: string;
    cachedSummary?: AgentSwingSummaryCache;
    managedContext?: AgentSwingManagedContextMetadata;
    compactionCount: number;
};
```

其中 `managedContext` 是本轮新增的审计元数据，用于确认最近一次上下文管理到底保留/丢弃了多少轮：

```ts
export type AgentSwingManagedContextMetadata = {
    lastManagedAt: string;
    lastManagedSource: "assemble" | "compact";
    lastManagedMode: AgentSwingConfig["mode"];
    sourceTurnCount: number;
    keptTurnCount: number;
    droppedTurnCount: number;
    estimatedTokensBefore: number;
    estimatedTokensAfter: number;
};
```

这让我们可以直接从 state 文件中验证：

```json
{
  "sourceTurnCount": 185,
  "keptTurnCount": 5,
  "droppedTurnCount": 180,
  "estimatedTokensBefore": 25175,
  "estimatedTokensAfter": 832
}
```

### 2. Hook 生命周期对齐

主要修改文件：

- `experiments/plugins/agentswing-context-engine/src/engine.ts`

插件现在的生命周期是：

```ts
ingest()    // no-op，canonical state 由完整 transcript 同步
bootstrap() // 从 sessionFile 导入已有 transcript
assemble()  // 同步 canonical state，然后根据阈值应用策略
compact()   // 读取 sessionFile，强制生成 managed context
afterTurn() // 持久化 state；summary 模式下可提前生成摘要
```

`assemble` 核心流程：

```ts
const synced = await this.synchronizeCanonicalState({
    sessionId: params.sessionId,
    rawMessages: params.messages,
});

if (synced.changed) {
    await this.persistCanonicalState(state);
}

const contextWindow = this.getContextWindow(params.tokenBudget);
const estimated = estimateTokens(state.messages);
const parsed = parseConversation(state.messages);

const usageRatio = estimated / contextWindow;
const shouldTrigger = usageRatio > this.config.triggerRatio;

if (!shouldTrigger) {
    return { messages: state.messages, estimatedTokens: estimated };
}

const result = await this.applyStrategy({
    state,
    parsed,
    model: params.model,
    source: "assemble",
});
```

这个流程确保触发判断基于 canonical state，而不是某次短上下文投影。

### 3. Keep-Last-N 对齐论文定义

论文中一个 interaction turn 是：

```text
(<thinking>, <tool call>, <tool response>)
```

本轮更新了：

- `experiments/plugins/agentswing-context-engine/src/turn-parser.ts`

解析规则：

- `preamble`：保留 system messages 和第一个 user prompt。
- 每个 assistant tool-call message 开始一个新的 interaction turn。
- 紧随其后的 `toolResult` 和 follow-up assistant text 归入同一个 turn。
- 中途新 user message 会开启新的 turn。

保留最近 N 轮的代码入口：

```ts
export function keepLastNTurns(parsed: ParsedConversation, n: number): Msg[] {
    const keptTurns = parsed.turns.slice(-n);
    const result: Msg[] = [...parsed.preamble];
    for (const turn of keptTurns) {
        result.push(...turn.messages);
    }
    return result;
}
```

`engine.ts` 中的策略执行：

```ts
private applyKeepLastN(parsed: ParsedConversation): AssembleResponse {
    const n = this.config.keepLastN;
    const truncated = keepLastNTurns(parsed, n);
    const estimatedTokens = estimateTokens(truncated);

    return {
        messages: truncated,
        estimatedTokens,
        systemPromptAddition:
            parsed.turns.length > n
                ? `[Context Management] Earlier conversation history (${parsed.turns.length - n} turns) has been truncated. Only the ${Math.min(n, parsed.turns.length)} most recent interaction turns are visible.`
                : undefined,
    };
}
```

### 4. 防止 managed projection 覆盖完整缓存

在 OpenClaw 中，后续 hook 可能把插件上一轮生成的短上下文再次传回来。如果直接用 `rawMessages.length < sourceMessageCount` 判断为 session reset，会错误覆盖完整 canonical state。

因此新增了 managed projection 识别逻辑：

```ts
function splitManagedProjection(
    candidate: Msg[],
    canonical: Msg[],
): { matchedCount: number } {
    if (candidate.length === 0 || canonical.length === 0) {
        return { matchedCount: 0 };
    }

    let canonicalIndex = 0;
    let matchedCount = 0;
    for (const message of candidate) {
        const matchIndex = findMessageIndex(canonical, message, canonicalIndex);
        if (matchIndex < 0) {
            break;
        }
        matchedCount++;
        canonicalIndex = matchIndex + 1;
    }

    return { matchedCount };
}
```

当传入的短上下文能匹配 canonical transcript 的子序列时，插件会认为它是 managed projection，而不是新会话或历史重置。

### 5. Summary 模式对齐 `(q, Sum)`

主要修改文件：

- `experiments/plugins/agentswing-context-engine/src/summarizer.ts`
- `experiments/plugins/agentswing-context-engine/src/engine.ts`

Summary 现在严格组装为：

```text
system messages + original user prompt + [Summarized Exploration State]
```

构造逻辑：

```ts
function buildSummaryMessages(parsed: ParsedConversation, summary: string): Msg[] {
    const systemMessages = parsed.preamble.filter((message) => message.role === "system");
    const originalUser = parsed.preamble.find((message) => message.role === "user");

    const summarySuffix =
        `[Summarized Exploration State]\n${summary}\n\n` +
        `[Continue from this compressed state using the preserved task prompt.]`;

    if (!originalUser) {
        return [
            ...systemMessages,
            {
                role: "user",
                content: summarySuffix,
            },
        ];
    }

    return [
        ...systemMessages,
        mergeUserPromptWithSummary(originalUser, summarySuffix),
    ];
}
```

摘要生成时，prompt 明确要求不要重复原始问题：

```ts
const SUMMARY_SYSTEM_PROMPT = `You are a context summarization assistant...

Your summary MUST NOT:
- Include redundant tool call/response details
- Repeat the original task prompt (it will be provided separately)
- Include conversational filler or meta-commentary
- Exceed 2000 words

Output ONLY the summary text, no additional framing.`;
```

### 6. Summary 使用 OpenClaw runtime 鉴权

之前 summary API 配置容易依赖环境变量。现在插件会优先使用 OpenClaw runtime 的 provider 鉴权与 `models.providers.<provider>.baseUrl`。

入口文件：

- `experiments/plugins/agentswing-context-engine/index.ts`

注册 engine 时传入：

```ts
api.registerContextEngine("agentswing-context-engine", () => {
    return new AgentSwingEngine(pluginCfg, {
        runtime: api.runtime,
        openclawConfig: api.config,
    });
});
```

`engine.ts` 中解析 provider：

```ts
private async resolveSummaryRequestOptions(modelHint?: string): Promise<{
    apiBase: string;
    apiKey?: string;
    model: string;
}> {
    const provider =
        this.config.summaryProvider ??
        inferProviderFromModel(modelHint) ??
        "openai";

    const model = this.config.summaryModel ?? inferModelId(modelHint) ?? "gpt-5-mini";
    const apiBase =
        this.config.summaryApiBase ??
        resolveProviderBaseUrl(this.openclawConfig, provider);

    const authResolver = this.runtime?.modelAuth?.resolveApiKeyForProvider;
    const auth = await authResolver?.({ provider, cfg: this.openclawConfig });

    return {
        apiBase,
        model,
        ...(auth?.apiKey ? { apiKey: auth.apiKey } : {}),
    };
}
```

### 7. 持久化容错对齐 context-safe

参考 `scripts/openclaw-context-safe-plugin-main/src/context-engine.ts`，持久化失败不应该直接打断 benchmark 长跑。因此改为：

```ts
private async persistCanonicalState(
    state: AgentSwingCanonicalSessionState,
): Promise<void> {
    this.sessions.set(state.sessionId, state);
    try {
        await saveCanonicalSessionState(state);
    } catch (error) {
        console.error(`[AgentSwing] canonical state save failed: ${String(error)}`);
    }
}
```

这和 context-safe 的“内存继续、日志告警、不中断主流程”风格一致。

## Benchmark 脚本修改

修改文件：

- `experiments/scripts/run_pinchbench_agentswing.sh`
- `experiments/scripts/run_claw_eval_agentswing.sh`
- `experiments/scripts/run_frontierscience_agentswing.sh`

新增 `--session-mode` 参数，支持：

```text
isolated | continuous
```

核心逻辑：

```bash
SESSION_MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-mode) SESSION_MODE="${2:-}"; shift 2 ;;
  esac
done

RESOLVED_SESSION_MODE="${SESSION_MODE:-${ECOCLAW_SESSION_MODE:-isolated}}"

if [[ "${RESOLVED_SESSION_MODE}" != "isolated" ]] && [[ "${RESOLVED_SESSION_MODE}" != "continuous" ]]; then
  echo "ERROR: --session-mode must be 'isolated' or 'continuous', got: ${RESOLVED_SESSION_MODE}" >&2
  exit 1
fi

BENCH_ARGS=(
  --session-mode "${RESOLVED_SESSION_MODE}"
)
```

这点非常关键：AgentSwing 这类上下文管理策略只有在 `continuous` 模式下才真正有实验意义。

## Gitignore / Dist 相关修改

根 `.gitignore` 原本全局忽略 `dist/`，导致新增运行时文件：

- `dist/src/artifact-dir.js`
- `dist/src/canonical-session-state.js`

被忽略，但已跟踪的 `dist/src/engine.js` 会 import 它们。这样会出现“本地能跑，别人 clone 后 dist 缺文件”的问题。

因此增加了例外：

```gitignore
dist/
!experiments/plugins/agentswing-context-engine/dist/
!experiments/plugins/agentswing-context-engine/dist/src/
!experiments/plugins/agentswing-context-engine/dist/src/artifact-dir.d.ts
!experiments/plugins/agentswing-context-engine/dist/src/artifact-dir.js
!experiments/plugins/agentswing-context-engine/dist/src/canonical-session-state.d.ts
!experiments/plugins/agentswing-context-engine/dist/src/canonical-session-state.js
experiments/plugins/agentswing-context-engine/dist/src/*.test.*
```

## 测试补充

新增测试文件：

- `experiments/plugins/agentswing-context-engine/src/engine.test.ts`

覆盖内容：

### Summary `(q, Sum)` 与 runtime auth

验证点：

- summary 模式触发后只返回 system + user。
- user 中包含原始 prompt 和 summary。
- summary API 请求使用 runtime auth 返回的 API key。
- state 文件写入 `cachedSummary`。

### `compact` 从 transcript 导入持久化状态

验证点：

- `compact()` 可从 sessionFile 导入完整 transcript。
- 新 engine 在 `messages: []` 时仍能从磁盘 state 恢复 canonical transcript。

### Keep-Last-N 从缓存拿 N 个真实轨迹

验证点：

- 写入 3 个真实 interaction turns。
- `keepLastN=2` 后只保留最近 2 个 turn。
- 保留内容包含 `thinking`、`toolCall`、`toolResult`。
- 第一个旧 turn 被丢弃。
- 再次传入 managed projection 不会覆盖完整 canonical state。

### Token-ratio 正反触发

验证点：

- 低于阈值：不触发，不写 `managedContext`。
- 高于阈值：触发 keep-last-n，写入 `managedContext`。

### Summary 由 token-ratio 触发

验证点：

- `summary` 模式可由 `token-ratio` 触发。
- 输出 `(q, Sum)`。
- 写入 `cachedSummary`。
- `managedContext.lastManagedMode === "summary"`。

运行命令：

```bash
cd experiments/plugins/agentswing-context-engine
npm test
```

结果：

```text
TAP version 13
ok 1 - dist/src/engine.test.js
1..1
pass 1
fail 0
```

## PinchBench Full Continuous 验证

本轮运行命令：

```bash
ECOCLAW_OPENCLAW_HOME=/home/jiangchen \
bash experiments/scripts/run_pinchbench_agentswing.sh \
  --suite all \
  --runs 1 \
  --parallel 1 \
  --session-mode continuous \
  --context-mode keep-last-n \
  --trigger-mode token-ratio \
  --trigger-ratio 0.01 \
  --keep-last-n 5 \
  --context-window 1000
```

注意：这里故意把 token 阈值调得非常低，目的是压测触发机制，不是追求任务分数。

### Continuous 证据

日志文件：

```text
log/pinchbench_agentswing_keep_last_n_20260426_130749.log
```

关键证据：

```text
Session mode: continuous
Creating OpenClaw agent bench-dmxapi-gpt-5-mini-0020-serial
Task 1/23 ... Agent [bench-dmxapi-gpt-5-mini-0020-serial]
...
Task 23/23 ... Agent [bench-dmxapi-gpt-5-mini-0020-serial]
```

此外日志中出现：

```text
Waiting for continual session unlock on bench-dmxapi-gpt-5-mini-0020-serial
```

说明 PinchBench 正在用同一个 continuous session 串行执行任务。

### Keep-Last-N 证据

最终 state 文件：

```text
/home/jiangchen/.openclaw/artifacts/agentswing-context-engine/session-state/bench-dmxapi-gpt-5-mini-0020-continuous-s1-1777180106440.json
```

最终状态：

```json
{
  "sessionId": "bench-dmxapi-gpt-5-mini-0020-continuous-s1-1777180106440",
  "sourceMessageCount": 884,
  "messageCount": 884,
  "toolResultCount": 3,
  "configSnapshot": {
    "mode": "keep-last-n",
    "triggerMode": "token-ratio",
    "triggerRatio": 0.01,
    "triggerTurnCount": 10,
    "keepLastN": 5,
    "contextWindow": 1000
  },
  "managedContext": {
    "lastManagedSource": "assemble",
    "lastManagedMode": "keep-last-n",
    "sourceTurnCount": 185,
    "keptTurnCount": 5,
    "droppedTurnCount": 180,
    "estimatedTokensBefore": 25175,
    "estimatedTokensAfter": 832
  }
}
```

从 OpenClaw 日志统计：

```text
triggered=728
keep_logs=728
max_source_turns=185
max_tokens_before=25175
min_tokens_after=25
max_tokens_after=8533
```

典型日志：

```text
[AgentSwing] keep-last-n: kept 5/182 turns, tokens≈858
[AgentSwing] keep-last-n: kept 5/183 turns, tokens≈837
[AgentSwing] keep-last-n: kept 5/184 turns, tokens≈844
[AgentSwing] keep-last-n: kept 5/185 turns, tokens≈832
```

结论：

- 所有任务确实在一个 continuous session 中累积。
- canonical state 持续增长到 884 条 messages / 185 个 turns。
- keep-last-n 按 `N=5` 从同一个长 session 中投影最近 5 个 turns。
- token-ratio 触发持续生效。

### 关于分数

这次 full run 不用于评估任务分数，原因如下：

- `triggerRatio=0.01` 和 `contextWindow=1000` 是极端压测配置，会频繁丢弃远程上下文。
- `keep-last-n` 本身会牺牲长程记忆任务，因此 memory 类任务低分是预期现象。
- 日志中还出现了大量模型侧错误，例如：

```text
429 令牌达到并发限制
401 无效的令牌
403 用户额度不足
```

这些会影响任务输出和 judge 评分，但不影响本轮机制验证结论。

## 当前环境注意事项

因为 full run 被中断在 judge 阶段，`~/.openclaw/openclaw.json` 仍残留这次压测配置：

```json
{
  "mode": "keep-last-n",
  "triggerMode": "token-ratio",
  "triggerRatio": 0.01,
  "triggerTurnCount": 10,
  "keepLastN": 5,
  "contextWindow": 1000
}
```

这对后续正式实验是不安全的，因为它会极端频繁触发上下文管理。建议正式跑分前显式设置为实验需要的参数，例如：

```bash
--session-mode continuous \
--context-mode keep-last-n \
--trigger-mode token-ratio \
--trigger-ratio 0.2 \
--keep-last-n 5 \
--context-window 128000
```

或根据论文设置：

- GPT-OSS-120B：`r = 0.2`
- DeepSeek-v3.2 / Tongyi-DR：`r = 0.4`
- `keepLastN = 5`
- `contextWindow = 128000`

## 真实 Keep-Last-N 产物复查与修正

在后续 Kuaipao full PinchBench continuous run 中，实验配置调整为：

```text
model = kuaipao/gpt-5-mini
session-mode = continuous
context-mode = keep-last-n
trigger-mode = token-ratio
trigger-ratio = 0.05
keep-last-n = 5
context-window = 200000
```

本次 full run 完成后，结果摘要如下：

```text
Overall Score: 65.5% (15.1 / 23.0)
Total tokens used: 2,086,657
Total API requests: 118
Run log: log/pinchbench_agentswing_keep_last_n_20260426_151838.log
Result JSON: results/raw/pinchbench/agentswing_keep_last_n/0021_kuaipao-gpt-5-mini.json
Canonical state:
~/.openclaw/artifacts/agentswing-context-engine/session-state/bench-kuaipao-gpt-5-mini-0021-continuous-s1-1777187952837.json
```

这次复查不是只看 `managedContext` 统计值，而是从真实 canonical state 中重放 parser 和 keep-last-n 逻辑，抽取最终会送入模型的上下文。旧实现重放结果显示：

```text
sourceMessageCount = 2376
sourceTurnCount = 347
keptTurnCount = 5
droppedTurnCount = 342
estimatedTokensAfter = 1308
```

旧实现的核心切片是正确的：最后 5 个 turn 确实来自完整持久化轨迹末尾，而且离线重放的 `estimatedKept = 1308` 与运行时保存的 `managedContext.estimatedTokensAfter = 1308` 完全一致。最后 5 个 turn 是 `task_08_memory` 末尾的真实轨迹，包括读取/写入 `memory/MEMORY.md`、`memory_search`、tool result 和最终回答。

但是复查也暴露出一个实现瑕疵：OpenClaw session 文件中包含 `session`、`model_change`、`thinking_level_change`、`openclaw:bootstrap-context:full` 等 runtime metadata。旧 parser 会把这些非模型可见记录混入 AgentSwing 轨迹，导致最终 keep-last-n 产物里出现 custom bootstrap marker，并且因为 transcript 开头不是 `system/user`，`preambleMessages = 0`。

为此新增了模型可见消息过滤：

```ts
export function isConversationMessage(msg: Msg): boolean {
    return (
        msg.role === "system" ||
        msg.role === "user" ||
        msg.role === "assistant" ||
        msg.role === "toolResult"
    );
}
```

修正点包括：

- `parseConversation()` 在解析前过滤 runtime metadata。
- `synchronizeCanonicalState()` 在写入 canonical state 前过滤 runtime metadata。
- `messagesToText()` 兼容 OpenClaw 实际使用的 `thinking` 字段，避免 summary 输入遗漏 reasoning 文本。
- 新增单测 `keep-last-n ignores OpenClaw runtime metadata and keeps only model-visible turns`，模拟真实 session/model/custom bootstrap 事件，验证输出上下文只包含真实对话消息。

修正后，用同一份 Kuaipao canonical state 通过完整 `AgentSwingEngine.assemble()` 离线重放，结果变为：

```text
tokensBefore ≈ 498016
ratio = 2.490 > 0.05
sourceTurnCount = 346
keptTurnCount = 5
droppedTurnCount = 341
returnedMessages = 16
toolCalls = 5
toolResults = 5
metadataMessagesInReturnedContext = 0
estimatedTokensAfter = 1323
```

这说明修正后的 keep-last-n 结果是干净的：只保留模型可见的真实对话轨迹，且最后 5 个 turn 中每个 tool call 都有对应 tool result。由于 runtime metadata 被过滤，canonical `messageCount` 从旧状态的 2376 变为 2340，差值 36 条对应 OpenClaw 运行元数据，不再参与 token 估算或上下文管理。

随后又从真实 OpenClaw session file 入口验证：

```text
sessionFile:
~/.openclaw/agents/bench-kuaipao-gpt-5-mini-0021-serial/sessions/dd46c56f-43c7-4cc0-9404-31ca473101cd.jsonl

bootstrap importedMessages = 2341
tokensBefore ≈ 498094
sourceTurnCount = 346
keptTurnCount = 5
droppedTurnCount = 341
returnedMessages = 17
metadataMessagesInReturnedContext = 0
estimatedTokensAfter = 1400
```

这个验证覆盖了插件真实入口：`bootstrap()` 从 OpenClaw `.jsonl` 读磁盘 transcript，`assemble()` 再从插件 canonical state 触发 keep-last-n。结果同样没有 runtime metadata 混入 returned context。

## Summary 模式真实验证与二次修复

在 keep-last-n 验证后，又对 summary 模式做了真实 PinchBench continuous 小规模验证。测试配置为：

```text
model = kuaipao/gpt-5-mini
judge = kuaipao/gpt-5-mini
suite = task_00_sanity ... task_09_files
session-mode = continuous
context-mode = summary
trigger-mode = token-ratio
trigger-ratio = 0.02
context-window = 200000
```

第一次运行中，summary 的预生成和首次触发都正常：

```text
cachedSummary.sourceMessageCount = 42
cachedSummary.sourceTurnCount = 16
estimatedTokensBefore = 5086
estimatedTokensAfter = 1129
managedContext.lastManagedMode = summary
```

但这次真实运行暴露出一个 keep-last-n 没有覆盖到的问题：summary 模式的 `assemble()` 返回的是 `(q, Sum)` projection，通常只有 1 到 2 条消息。下一轮 OpenClaw 把这段短 projection 连同新任务消息传回插件时，旧的 `synchronizeCanonicalState()` 只会识别 keep-last-n 那种“原始历史子序列”投影，无法识别 summary projection。结果是 canonical state 会被 `(q, Sum)` 短上下文覆盖，出现：

```text
messageCount = 2
originalPrompt 包含 [Summarized Exploration State]
```

这会破坏 summary 模式最重要的设计目标：磁盘 canonical state 必须始终保留完整模型可见轨迹，而不是被 managed context 覆盖。

为此新增 summary projection 识别逻辑：

```ts
function splitSummaryManagedProjection(
    candidate: Msg[],
): {
    isProjection: boolean;
    projectionMessageCount: number;
} {
    const summaryIndex = candidate.findIndex(messageContainsSummaryMarker);
    if (summaryIndex < 0) {
        return { isProjection: false, projectionMessageCount: 0 };
    }
    return {
        isProjection: true,
        projectionMessageCount: summaryIndex + 1,
    };
}

function messageContainsSummaryMarker(message: Msg): boolean {
    return messageContentToText(message).includes("[Summarized Exploration State]");
}
```

同步逻辑现在会：

- 如果 raw messages 中包含 `[Summarized Exploration State]`，将其识别为 summary managed projection。
- 跳过 projection 前缀，只把 projection 之后的新 user/assistant/toolResult 追加到 canonical transcript。
- 保持 `originalPrompt` 使用已有 canonical prompt，避免被 `(q, Sum)` 污染。
- 保留已有 `cachedSummary` 与 `managedContext`，继续按完整历史生成后续 summary。

新增单测：

```text
summary managed projection does not overwrite the persisted canonical transcript
```

该测试先触发 summary，得到 `(q, Sum)`；再模拟下一轮 OpenClaw 传回 `(q, Sum) + 新 user/assistant/toolResult`。断言：

```text
messageCount = originalMessages.length + nextTurn.length
toolResultCount = 3
originalPrompt 不包含 [Summarized Exploration State]
canonical messages 不包含 Compressed state projection
canonical messages 仍包含 first/second/third file contents
managedContext.lastManagedMode = summary
```

修复后重新安装插件，并用同样的前 10 个 PinchBench task 重新运行。最终结果文件：

```text
results/raw/pinchbench/agentswing_summary/0023_kuaipao-gpt-5-mini.json
log/pinchbench_agentswing_summary_20260426_184354.log
log/pinchbench_agentswing_summary_20260426_184354_benchmark.log
results/reports/agentswing_summary_20260426_184354_cost.json
```

最终机制核验：

```text
session_mode = continuous
context_engine.mode = summary
trigger_ratio = 0.02
context_window = 200000
task_count = 10

canonical sourceMessageCount = 71
canonical messageCount = 71
toolResultCount = 22
sourceTurnCount = 35
estimatedTokensBefore = 7097
estimatedTokensAfter = 896
cachedSummary.sourceMessageCount = 71
cachedSummary.sourceTurnCount = 35
originalPromptHasSummary = false
canonicalMessagesContainSummaryMarker = false
```

这说明 summary 模式现在完成了真实 continuous 链路验证：预生成、token-ratio 触发、`(q, Sum)` 输出、后续投影回流、canonical 持久化都能正常工作。

## 修改文件总览

主要新增：

- `experiments/plugins/agentswing-context-engine/src/artifact-dir.ts`
- `experiments/plugins/agentswing-context-engine/src/canonical-session-state.ts`
- `experiments/plugins/agentswing-context-engine/src/engine.test.ts`
- `experiments/plugins/agentswing-context-engine/dist/src/artifact-dir.js`
- `experiments/plugins/agentswing-context-engine/dist/src/canonical-session-state.js`
- `docs/agentswing_context_engine_changes.md`

主要修改：

- `experiments/plugins/agentswing-context-engine/src/engine.ts`
- `experiments/plugins/agentswing-context-engine/src/turn-parser.ts`
- `experiments/plugins/agentswing-context-engine/src/summarizer.ts`
- `experiments/plugins/agentswing-context-engine/src/config.ts`
- `experiments/plugins/agentswing-context-engine/index.ts`
- `experiments/plugins/agentswing-context-engine/openclaw.plugin.json`
- `experiments/plugins/agentswing-context-engine/package.json`
- `experiments/plugins/agentswing-context-engine/typings/openclaw.d.ts`
- `experiments/scripts/run_pinchbench_agentswing.sh`
- `experiments/scripts/run_claw_eval_agentswing.sh`
- `experiments/scripts/run_frontierscience_agentswing.sh`
- `.gitignore`
- `docs/context_memory.md`

## 最终结论

本轮修改后，AgentSwing 插件已经具备以下能力：

- 在 OpenClaw `continuous` session 中维护插件自有 canonical transcript。
- 基于 canonical transcript 进行 token-ratio 判断。
- 超阈值后应用 keep-last-n，并可审计保留/丢弃 turns。
- 从磁盘缓存恢复完整历史，避免 managed projection 覆盖 canonical state。
- summary 模式按 `(q, Sum)` 输出，并支持 OpenClaw runtime 鉴权。
- PinchBench / ClawEval / FrontierScience wrapper 都支持显式 `--session-mode continuous`。

这意味着后续可以把 AgentSwing 作为一个可复现 baseline 方法纳入实验矩阵，重点比较不同上下文管理策略在 continuous benchmark 下的 token 使用、任务成功率和长程记忆能力。
