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
import { messagesToText } from "./turn-parser.js";

const SUMMARY_SYSTEM_PROMPT = `You are a context summarization assistant. Your task is to compress a long interaction history into a concise summary that preserves all critical information for continuing the task.

Your summary MUST preserve:
1. Key findings and verified facts discovered during exploration
2. Current hypotheses and their status (confirmed/rejected/pending)
3. Progress state — what has been completed, what remains
4. Important error messages or failed approaches (to avoid repeating them)
5. File paths, variable names, URLs, or other specific identifiers that were relevant
6. Any partial results or intermediate outputs

Your summary MUST NOT:
- Include redundant tool call/response details
- Repeat the original task prompt (it will be provided separately)
- Include conversational filler or meta-commentary
- Exceed 2000 words

Output ONLY the summary text, no additional framing.`;

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
export async function generateSummary(
    messagesToSummarize: Msg[],
    options: SummarizerOptions = {},
): Promise<string> {
    const apiBase = options.apiBase ?? "";
    const apiKey = options.apiKey ?? "";
    const model = options.model ?? "gpt-5-mini";
    const maxTokens = options.maxTokens ?? 4096;

    if (!apiBase) {
        throw new Error(
            "AgentSwing summarizer: no API base URL configured.",
        );
    }

    const historyText = messagesToText(messagesToSummarize);

    const url = `${apiBase.replace(/\/+$/, "")}/chat/completions`;
    const body = {
        model,
        messages: [
            { role: "system", content: SUMMARY_SYSTEM_PROMPT },
            {
                role: "user",
                content: [
                    options.originalPrompt
                        ? `The original user prompt below will remain in context separately. Do not restate it verbatim.\n\n[Original User Prompt]\n${options.originalPrompt}`
                        : "",
                    `Please summarize the following interaction history:\n\n${historyText}`,
                ]
                    .filter((part) => part.length > 0)
                    .join("\n\n"),
            },
        ],
        max_tokens: maxTokens,
        temperature: 0.3,
    };

    const headers: Record<string, string> = {
        "Content-Type": "application/json",
    };
    if (apiKey) {
        headers["Authorization"] = `Bearer ${apiKey}`;
    }

    const response = await fetch(url, {
        method: "POST",
        headers,
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(120_000),
    });

    if (!response.ok) {
        const errText = await response.text().catch(() => "");
        throw new Error(
            `AgentSwing summarizer: LLM API returned ${response.status}: ${errText.slice(0, 500)}`,
        );
    }

    const json = (await response.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
    };
    const content = json.choices?.[0]?.message?.content;
    if (!content) {
        throw new Error(
            "AgentSwing summarizer: LLM API returned empty content in response.",
        );
    }

    return content.trim();
}
