/**
 * AgentSwing Context Engine — Configuration types and defaults.
 *
 * Two modes from the AgentSwing paper:
 *   - keep-last-n: Truncate history, keep only the last N interaction turns
 *   - summary:     Compress history into a concise summary text
 */
/** Default configuration values. */
export const DEFAULT_CONFIG = {
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
export function resolveConfig(raw) {
    return {
        mode: raw.mode ?? DEFAULT_CONFIG.mode,
        triggerMode: raw.triggerMode ?? DEFAULT_CONFIG.triggerMode,
        triggerRatio: typeof raw.triggerRatio === "number"
            ? Math.min(0.99, Math.max(0.01, raw.triggerRatio))
            : DEFAULT_CONFIG.triggerRatio,
        triggerTurnCount: typeof raw.triggerTurnCount === "number"
            ? Math.max(1, Math.floor(raw.triggerTurnCount))
            : DEFAULT_CONFIG.triggerTurnCount,
        keepLastN: typeof raw.keepLastN === "number"
            ? Math.max(1, Math.floor(raw.keepLastN))
            : DEFAULT_CONFIG.keepLastN,
        contextWindow: typeof raw.contextWindow === "number" ? raw.contextWindow : null,
        summaryProvider: typeof raw.summaryProvider === "string" && raw.summaryProvider.trim().length > 0
            ? raw.summaryProvider.trim()
            : DEFAULT_CONFIG.summaryProvider,
        summaryModel: typeof raw.summaryModel === "string" && raw.summaryModel.trim().length > 0
            ? raw.summaryModel.trim()
            : DEFAULT_CONFIG.summaryModel,
        summaryApiBase: typeof raw.summaryApiBase === "string" && raw.summaryApiBase.trim().length > 0
            ? raw.summaryApiBase.trim()
            : DEFAULT_CONFIG.summaryApiBase,
    };
}
