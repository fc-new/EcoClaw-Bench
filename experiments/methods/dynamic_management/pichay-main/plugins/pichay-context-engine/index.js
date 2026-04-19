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

function toBool(value, fallback) {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const v = value.toLowerCase();
    if (v === "true") return true;
    if (v === "false") return false;
  }
  return fallback;
}

function readConfig(pluginConfig = {}) {
  return {
    adapterBaseUrl: toString(
      process.env.ECOCLAW_PICHAY_ADAPTER_BASE_URL ?? pluginConfig.adapterBaseUrl,
      "http://127.0.0.1:19012",
    ),
    triggerMode: toString(
      process.env.ECOCLAW_PICHAY_TRIGGER_MODE ?? pluginConfig.triggerMode,
      "token-ratio",
    ),
    triggerRatio: toFloat(
      process.env.ECOCLAW_PICHAY_TRIGGER_RATIO ?? pluginConfig.triggerRatio,
      0.4,
    ),
    triggerTurnCount: toInt(
      process.env.ECOCLAW_PICHAY_TRIGGER_TURN_COUNT ?? pluginConfig.triggerTurnCount,
      10,
    ),
    ageThreshold: toInt(
      process.env.ECOCLAW_PICHAY_AGE_THRESHOLD ?? pluginConfig.ageThreshold,
      4,
    ),
    minEvictSize: toInt(
      process.env.ECOCLAW_PICHAY_MIN_EVICT_SIZE ?? pluginConfig.minEvictSize,
      500,
    ),
    preserveRecent: toInt(
      process.env.ECOCLAW_PICHAY_PRESERVE_RECENT ?? pluginConfig.preserveRecent,
      12,
    ),
    minTextChars: toInt(
      process.env.ECOCLAW_PICHAY_MIN_TEXT_CHARS ?? pluginConfig.minTextChars,
      2000,
    ),
    maxSummaryChars: toInt(
      process.env.ECOCLAW_PICHAY_MAX_SUMMARY_CHARS ?? pluginConfig.maxSummaryChars,
      300,
    ),
    enableModelSummary: toBool(
      process.env.ECOCLAW_PICHAY_ENABLE_MODEL_SUMMARY ?? pluginConfig.enableModelSummary,
      false,
    ),
    requestTimeoutMs: toInt(
      process.env.ECOCLAW_PICHAY_REQUEST_TIMEOUT_MS ?? pluginConfig.requestTimeoutMs,
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
  if (role === "assistant" || role === "user" || role === "system" || role === "tool") return role;
  return "user";
}

function toPichayMessages(messages) {
  return (messages || []).map((m) => ({
    role: normalizeRole(m?.role),
    content: typeof m?.content === "string" || Array.isArray(m?.content) ? m.content : normalizeContent(m?.content),
  }));
}

function estimateTokens(messages) {
  let chars = 0;
  for (const msg of messages || []) {
    chars += normalizeContent(msg.content).length + 20;
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

class PichayEngine {
  constructor(config, logger) {
    this.config = config;
    this.logger = logger ?? console;
    this.sessions = new Map();
    this.info = {
      id: "pichay-context-engine",
      name: "Pichay Context Engine",
      version: "0.1.0",
      ownsCompaction: true,
    };
  }

  _state(sessionId) {
    if (!this.sessions.has(sessionId)) {
      this.sessions.set(sessionId, {
        initialized: false,
        lastSyncedCount: 0,
        compactCount: 0,
      });
    }
    return this.sessions.get(sessionId);
  }

  async _ensureInit(sessionId, prompt, messages) {
    const state = this._state(sessionId);
    if (state.initialized) return;
    const firstUser = messages.find((m) => m.role === "user")?.content;
    const task = (prompt && String(prompt).trim()) || normalizeContent(firstUser) || "OpenClaw task";
    await postJson(
      this.config.adapterBaseUrl,
      "/session/init",
      { session_id: sessionId, task, reset_if_exists: false },
      this.config.requestTimeoutMs,
    );
    state.initialized = true;
  }

  async _syncMessages(sessionId, messages, prompt) {
    const state = this._state(sessionId);
    const all = toPichayMessages(messages);
    const delta = all.slice(state.lastSyncedCount);
    if (delta.length === 0) return;
    await postJson(
      this.config.adapterBaseUrl,
      "/session/memorize",
      { session_id: sessionId, task: prompt || "OpenClaw task", messages: delta },
      this.config.requestTimeoutMs,
    );
    state.lastSyncedCount = all.length;
  }

  _shouldTrigger(messages, tokenBudget) {
    if (this.config.triggerMode === "turn-count") {
      return countTurns(messages) > this.config.triggerTurnCount;
    }
    const budget = tokenBudget && tokenBudget > 0 ? tokenBudget : 32768;
    return estimateTokens(messages) / Math.max(1, budget) > this.config.triggerRatio;
  }

  async ingest() {
    return { ingested: true };
  }

  async assemble(params) {
    const sessionId = params?.sessionId ?? "default";
    const messages = toPichayMessages(params?.messages ?? []);
    const tokenBudget = params?.tokenBudget ?? 32768;

    try {
      await this._ensureInit(sessionId, params?.prompt, messages);
      await this._syncMessages(sessionId, messages, params?.prompt);
      if (!this._shouldTrigger(messages, tokenBudget)) {
        return { messages, estimatedTokens: estimateTokens(messages) };
      }

      const compacted = await postJson(
        this.config.adapterBaseUrl,
        "/session/compact",
        {
          session_id: sessionId,
          age_threshold: this.config.ageThreshold,
          min_evict_size: this.config.minEvictSize,
          preserve_recent: this.config.preserveRecent,
          min_text_chars: this.config.minTextChars,
          max_summary_chars: this.config.maxSummaryChars,
          use_model_summary: this.config.enableModelSummary,
        },
        this.config.requestTimeoutMs,
      );

      const compactedMessages = toPichayMessages(compacted?.messages ?? messages);
      const state = this._state(sessionId);
      state.compactCount += 1;
      state.lastSyncedCount = compactedMessages.length;

      this.logger?.warn?.(
        `[Pichay] compact triggered: session=${sessionId.slice(0, 8)}..., compactCount=${state.compactCount}, before=${estimateTokens(messages)}, after=${estimateTokens(compactedMessages)}`
      );

      return {
        messages: compactedMessages,
        estimatedTokens: estimateTokens(compactedMessages),
        systemPromptAddition: "[Context Management] Pichay paging/trim compaction applied.",
      };
    } catch (err) {
      this.logger?.warn?.(`[Pichay] assemble fallback due to error: ${String(err)}`);
      return { messages, estimatedTokens: estimateTokens(messages) };
    }
  }

  async compact(params) {
    const sessionId = params?.sessionId ?? "default";
    this.logger?.warn?.(`[Pichay] compact requested for session=${sessionId.slice(0, 8)}...`);
    return {
      ok: true,
      compacted: true,
      reason: "Pichay compaction delegated to assemble",
      result: { tokensBefore: params?.currentTokenCount ?? 0 },
    };
  }

  async afterTurn(params) {
    const sessionId = params?.sessionId ?? "default";
    const messages = toPichayMessages(params?.messages ?? []);
    try {
      await this._ensureInit(sessionId, "", messages);
      await this._syncMessages(sessionId, messages, "");
    } catch (err) {
      this.logger?.warn?.(`[Pichay] afterTurn sync skipped: ${String(err)}`);
    }
  }

  async dispose() {
    this.sessions.clear();
  }
}

const plugin = {
  id: "pichay-context-engine",
  name: "Pichay Context Engine",
  description: "Pichay paging and conversation compaction for OpenClaw",
  kind: "context-engine",
  register(api) {
    const config = readConfig(api.pluginConfig ?? {});
    api.registerContextEngine("pichay-context-engine", () => new PichayEngine(config, api.logger));
  },
};

export default plugin;
