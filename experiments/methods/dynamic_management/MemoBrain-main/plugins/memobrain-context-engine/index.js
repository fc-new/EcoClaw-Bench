function toInt(value, fallback) {
  const n = Number.parseInt(String(value), 10);
  return Number.isFinite(n) ? n : fallback;
}

function toFloat(value, fallback) {
  const n = Number.parseFloat(String(value));
  return Number.isFinite(n) ? n : fallback;
}

function toString(value, fallback) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function readConfig(pluginConfig = {}) {
  return {
    adapterBaseUrl: toString(
      process.env.ECOCLAW_MEMOBRAIN_ADAPTER_BASE_URL ?? pluginConfig.adapterBaseUrl,
      "http://127.0.0.1:19002",
    ),
    triggerMode: toString(
      process.env.ECOCLAW_MEMOBRAIN_TRIGGER_MODE ?? pluginConfig.triggerMode,
      "token-ratio",
    ),
    triggerRatio: toFloat(
      process.env.ECOCLAW_MEMOBRAIN_TRIGGER_RATIO ?? pluginConfig.triggerRatio,
      0.4,
    ),
    triggerTurnCount: toInt(
      process.env.ECOCLAW_MEMOBRAIN_TRIGGER_TURN_COUNT ?? pluginConfig.triggerTurnCount,
      10,
    ),
    maxMemorySize: toInt(
      process.env.ECOCLAW_MEMOBRAIN_MAX_MEMORY_SIZE ?? pluginConfig.maxMemorySize,
      32768,
    ),
    requestTimeoutMs: toInt(
      process.env.ECOCLAW_MEMOBRAIN_REQUEST_TIMEOUT_MS ?? pluginConfig.requestTimeoutMs,
      30000,
    ),
  };
}

function normalizeContent(content) {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    const parts = [];
    for (const block of content) {
      if (block && typeof block === "object") {
        if (typeof block.text === "string") parts.push(block.text);
        else if (typeof block.content === "string") parts.push(block.content);
        else if (block.arguments != null) parts.push(JSON.stringify(block.arguments));
        else parts.push(JSON.stringify(block));
      } else {
        parts.push(String(block));
      }
    }
    return parts.join("\n").trim();
  }
  if (content == null) return "";
  return String(content);
}

function normalizeRole(role) {
  if (role === "assistant" || role === "user" || role === "system") return role;
  return "user";
}

function toMemoMessages(messages) {
  return (messages || []).map((m) => ({
    role: normalizeRole(m?.role),
    content: normalizeContent(m?.content),
  }));
}

function estimateTokens(messages) {
  let chars = 0;
  for (const msg of messages || []) {
    chars += (msg.content || "").length + 20;
  }
  return Math.ceil(chars / 4);
}

function countTurns(messages) {
  let turns = 0;
  let hasUser = false;
  for (const msg of messages || []) {
    if (msg.role === "user") hasUser = true;
    if (msg.role === "assistant" && hasUser) {
      turns += 1;
      hasUser = false;
    }
  }
  return turns;
}

async function postJson(baseUrl, path, payload, timeoutMs) {
  const url = `${baseUrl.replace(/\/+$/, "")}${path}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || data?.ok === false) {
      throw new Error(`HTTP ${resp.status}: ${JSON.stringify(data)}`);
    }
    return data;
  } finally {
    clearTimeout(timer);
  }
}

class MemoBrainEngine {
  constructor(config, logger) {
    this.config = config;
    this.logger = logger ?? console;
    this.sessions = new Map();
    this.info = {
      id: "memobrain-context-engine",
      name: "MemoBrain Context Engine",
      version: "0.1.0",
      ownsCompaction: true,
    };
  }

  async ingest() {
    return { ingested: true };
  }

  _state(sessionId) {
    if (!this.sessions.has(sessionId)) {
      this.sessions.set(sessionId, {
        initialized: false,
        lastMemorizedCount: 0,
        recallCount: 0,
      });
    }
    return this.sessions.get(sessionId);
  }

  async _ensureInit(sessionId, prompt, messages) {
    const state = this._state(sessionId);
    if (state.initialized) return;
    const firstUser = messages.find((m) => m.role === "user")?.content ?? "";
    const task = (prompt && String(prompt).trim()) || firstUser || "OpenClaw task";
    await postJson(
      this.config.adapterBaseUrl,
      "/session/init",
      { session_id: sessionId, task, reset_if_exists: false },
      this.config.requestTimeoutMs,
    );
    state.initialized = true;
  }

  async _memorizeDelta(sessionId, messages, prompt) {
    const state = this._state(sessionId);
    const all = toMemoMessages(messages);
    const delta = all.slice(state.lastMemorizedCount);
    if (delta.length === 0) return;
    await postJson(
      this.config.adapterBaseUrl,
      "/session/memorize",
      { session_id: sessionId, task: prompt || "OpenClaw task", messages: delta },
      this.config.requestTimeoutMs,
    );
    state.lastMemorizedCount = all.length;
  }

  _shouldTrigger(messages, tokenBudget) {
    if (this.config.triggerMode === "turn-count") {
      return countTurns(messages) > this.config.triggerTurnCount;
    }
    const estimated = estimateTokens(messages);
    const budget = tokenBudget && tokenBudget > 0 ? tokenBudget : this.config.maxMemorySize;
    return estimated / Math.max(1, budget) > this.config.triggerRatio;
  }

  async assemble(params) {
    const sessionId = params?.sessionId ?? "default";
    const messages = toMemoMessages(params?.messages ?? []);
    const tokenBudget = params?.tokenBudget ?? this.config.maxMemorySize;

    try {
      await this._ensureInit(sessionId, params?.prompt, messages);
      await this._memorizeDelta(sessionId, messages, params?.prompt);

      if (!this._shouldTrigger(messages, tokenBudget)) {
        return { messages, estimatedTokens: estimateTokens(messages) };
      }

      const recalled = await postJson(
        this.config.adapterBaseUrl,
        "/session/recall",
        { session_id: sessionId },
        this.config.requestTimeoutMs,
      );
      const recalledMessages = toMemoMessages(recalled?.messages ?? messages);
      const state = this._state(sessionId);
      state.recallCount += 1;
      state.lastMemorizedCount = recalledMessages.length;

      this.logger?.warn?.(
        `[MemoBrain] recall triggered: session=${sessionId.slice(0, 8)}..., recallCount=${state.recallCount}, before=${estimateTokens(messages)}, after=${estimateTokens(recalledMessages)}`,
      );

      return {
        messages: recalledMessages,
        estimatedTokens: estimateTokens(recalledMessages),
        systemPromptAddition: "[Context Management] MemoBrain recall applied to compress reasoning context.",
      };
    } catch (err) {
      this.logger?.warn?.(`[MemoBrain] assemble fallback due to error: ${String(err)}`);
      return { messages, estimatedTokens: estimateTokens(messages) };
    }
  }

  async compact(params) {
    const sessionId = params?.sessionId ?? "default";
    this.logger?.warn?.(`[MemoBrain] compact requested for session=${sessionId.slice(0, 8)}...`);
    return {
      ok: true,
      compacted: true,
      reason: "MemoBrain compaction delegated to assemble/recall",
      result: { tokensBefore: params?.currentTokenCount ?? 0 },
    };
  }

  async afterTurn(params) {
    const sessionId = params?.sessionId ?? "default";
    const messages = toMemoMessages(params?.messages ?? []);
    try {
      await this._ensureInit(sessionId, "", messages);
      await this._memorizeDelta(sessionId, messages, "");
    } catch (err) {
      this.logger?.warn?.(`[MemoBrain] afterTurn memorize skipped: ${String(err)}`);
    }
  }

  async dispose() {
    this.sessions.clear();
  }
}

const plugin = {
  id: "memobrain-context-engine",
  name: "MemoBrain Context Engine",
  description: "MemoBrain executive memory for long-horizon reasoning in OpenClaw",
  kind: "context-engine",
  register(api) {
    const config = readConfig(api.pluginConfig ?? {});
    api.registerContextEngine("memobrain-context-engine", () => new MemoBrainEngine(config, api.logger));
  },
};

export default plugin;
