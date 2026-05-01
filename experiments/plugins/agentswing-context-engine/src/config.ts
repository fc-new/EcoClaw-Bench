/**
 * AgentSwing Context Engine — Configuration types and defaults.
 *
 * Two modes from the AgentSwing paper:
 *   - keep-last-n: Truncate history, keep only the last N interaction turns
 *   - summary:     Compress history into a concise summary text
 */

export type ContextMode = "keep-last-n" | "summary";

/**
 * How to decide when to activate context management.
 *   - token-ratio:  fire when estimatedTokens / contextWindow > triggerRatio
 *   - turn-count:   fire when interaction turn count > triggerTurnCount
 */
export type TriggerMode = "token-ratio" | "turn-count";

export interface AgentSwingConfig {
    /** Context management strategy. */
    mode: ContextMode;

    /** Which metric triggers context management. Default: "token-ratio". */
    triggerMode: TriggerMode;

    /**
     * Trigger ratio r — activate context management when
     * estimatedTokens / contextWindow > r.
     * Paper defaults: 0.2 for GPT-OSS-120B, 0.4 for DeepSeek/Tongyi.
     * Only used when triggerMode is "token-ratio".
     */
    triggerRatio: number;

    /**
     * Trigger turn count — activate context management when
     * interaction turn count exceeds this value.
     * Only used when triggerMode is "turn-count". Default: 10.
     */
    triggerTurnCount: number;

    /** Number of recent interaction turns to keep (keep-last-n mode). Default: 5. */
    keepLastN: number;

    /** Override model context window in tokens. Default: inferred from tokenBudget. */
    contextWindow: number | null;

    /** Provider id used for summary generation auth/baseUrl resolution. */
    summaryProvider: string | null;

    /** Explicit summary model id. Defaults to the active model id when available. */
    summaryModel: string | null;

    /** Optional explicit OpenAI-compatible base URL for summary generation. */
    summaryApiBase: string | null;
}

/** Default configuration values. */
export const DEFAULT_CONFIG: AgentSwingConfig = {
    mode: "keep-last-n",
    triggerMode: "token-ratio",
    triggerRatio: 0.4,
    triggerTurnCount: 10,
    keepLastN: 5,
    contextWindow: null,
    summaryProvider: null,
    summaryModel: null,
    summaryApiBase: null,
};

/**
 * OpenClaw DEFAULT_CONTEXT_TOKENS fallback (from src/agents/defaults.ts).
 * Used when contextWindow is not explicitly configured and tokenBudget is unavailable.
 */
export const FALLBACK_CONTEXT_WINDOW = 200_000;

/** Resolve final config from plugin config (partial) + defaults. */
export function resolveConfig(raw: Record<string, unknown>): AgentSwingConfig {
    return {
        mode: (raw.mode as ContextMode) ?? DEFAULT_CONFIG.mode,
        triggerMode:
            (raw.triggerMode as TriggerMode) ?? DEFAULT_CONFIG.triggerMode,
        triggerRatio:
            typeof raw.triggerRatio === "number"
                ? Math.min(0.99, Math.max(0.01, raw.triggerRatio))
                : DEFAULT_CONFIG.triggerRatio,
        triggerTurnCount:
            typeof raw.triggerTurnCount === "number"
                ? Math.max(1, Math.floor(raw.triggerTurnCount))
                : DEFAULT_CONFIG.triggerTurnCount,
        keepLastN:
            typeof raw.keepLastN === "number"
                ? Math.max(1, Math.floor(raw.keepLastN))
                : DEFAULT_CONFIG.keepLastN,
        contextWindow:
            typeof raw.contextWindow === "number" ? raw.contextWindow : null,
        summaryProvider:
            typeof raw.summaryProvider === "string" && raw.summaryProvider.trim().length > 0
                ? raw.summaryProvider.trim()
                : DEFAULT_CONFIG.summaryProvider,
        summaryModel:
            typeof raw.summaryModel === "string" && raw.summaryModel.trim().length > 0
                ? raw.summaryModel.trim()
                : DEFAULT_CONFIG.summaryModel,
        summaryApiBase:
            typeof raw.summaryApiBase === "string" && raw.summaryApiBase.trim().length > 0
                ? raw.summaryApiBase.trim()
                : DEFAULT_CONFIG.summaryApiBase,
    };
}
