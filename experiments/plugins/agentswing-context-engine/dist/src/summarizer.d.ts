/**
 * Summarizer — Generate context summaries for the Summary strategy.
 *
 * Per AgentSwing paper: compress interaction trajectory into (q, Sum) format
 * where q = original user prompt and Sum = concise summary of exploration history.
 *
 * Uses a direct HTTP call to the LLM provider (the agent's own model by default)
 * since plugin-sdk does not expose internal LLM call APIs.
 */
import type { Msg } from "./turn-parser.js";
export interface SummarizerOptions {
    /** LLM API base URL. */
    apiBase?: string;
    /** API key resolved by OpenClaw runtime auth helpers. */
    apiKey?: string;
    /** Model ID for summarization. */
    model?: string;
    /** Max tokens for the summary response. */
    maxTokens?: number;
    /** Original user prompt kept outside the summary, when available. */
    originalPrompt?: string;
}
/**
 * Call an OpenAI-compatible chat completion API to generate a summary.
 */
export declare function generateSummary(messagesToSummarize: Msg[], options?: SummarizerOptions): Promise<string>;
