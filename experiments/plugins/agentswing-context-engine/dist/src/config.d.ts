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
export declare const DEFAULT_CONFIG: AgentSwingConfig;
/**
 * OpenClaw DEFAULT_CONTEXT_TOKENS fallback (from src/agents/defaults.ts).
 * Used when contextWindow is not explicitly configured and tokenBudget is unavailable.
 */
export declare const FALLBACK_CONTEXT_WINDOW = 200000;
/** Resolve final config from plugin config (partial) + defaults. */
export declare function resolveConfig(raw: Record<string, unknown>): AgentSwingConfig;
