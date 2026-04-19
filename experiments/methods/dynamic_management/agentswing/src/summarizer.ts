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
    /** LLM API base URL. Read from env AGENTSWING_SUMMARY_API_BASE or OpenClaw config. */
    apiBase?: string;
    /** API key. Read from env AGENTSWING_SUMMARY_API_KEY or OpenClaw config. */
    apiKey?: string;
    /** Model ID for summarization. Uses agent's own model by default. */
    model?: string;
    /** Max tokens for the summary response. */
    maxTokens?: number;
}

export interface RolloutEvaluation {
    score: number;
    progress: number;
    evidence: number;
    health: number;
    rationale: string;
    projectedTrajectory: string;
}

/**
 * Call an OpenAI-compatible chat completion API to generate a summary.
 */
export async function generateSummary(
    messagesToSummarize: Msg[],
    options: SummarizerOptions = {},
): Promise<string> {
    const apiBase =
        options.apiBase ??
        process.env.AGENTSWING_SUMMARY_API_BASE ??
        process.env.OPENCLAW_API_BASE ??
        "";
    const apiKey =
        options.apiKey ??
        process.env.AGENTSWING_SUMMARY_API_KEY ??
        process.env.OPENCLAW_API_KEY ??
        "";
    const model =
        options.model ?? process.env.AGENTSWING_SUMMARY_MODEL ?? "gpt-5-mini";
    const maxTokens = options.maxTokens ?? 4096;

    if (!apiBase) {
        throw new Error(
            "AgentSwing summarizer: no API base URL configured. " +
            "Set AGENTSWING_SUMMARY_API_BASE or provide apiBase in options.",
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
                content: `Please summarize the following interaction history:\n\n${historyText}`,
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

export async function evaluateBranchRollout(params: {
    branchName: string;
    messages: Msg[];
    lookaheadSteps: number;
}): Promise<RolloutEvaluation> {
    const apiBase =
        process.env.AGENTSWING_ROUTER_API_BASE ??
        process.env.AGENTSWING_SUMMARY_API_BASE ??
        process.env.OPENCLAW_API_BASE ??
        "";
    const apiKey =
        process.env.AGENTSWING_ROUTER_API_KEY ??
        process.env.AGENTSWING_SUMMARY_API_KEY ??
        process.env.OPENCLAW_API_KEY ??
        "";
    const model =
        process.env.AGENTSWING_ROUTER_MODEL ??
        process.env.AGENTSWING_SUMMARY_MODEL ??
        "gpt-5-mini";

    if (!apiBase) {
        throw new Error("AgentSwing router: missing AGENTSWING_ROUTER_API_BASE/OPENCLAW_API_BASE");
    }

    const contextText = messagesToText(params.messages).slice(0, 24_000);
    const system = "You are an AgentSwing router. Simulate the next k steps for a branch and score it.";
    const user = `Branch=${params.branchName}\nLookaheadSteps=${params.lookaheadSteps}\n\nContext:\n${contextText}\n\nReturn JSON only with fields: score, progress, evidence, health, rationale, projectedTrajectory. Each numeric field in [0,1].`;

    const response = await fetch(`${apiBase.replace(/\/+$/, "")}/chat/completions`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
        },
        body: JSON.stringify({
            model,
            messages: [
                { role: "system", content: system },
                { role: "user", content: user },
            ],
            max_tokens: 1400,
            temperature: 0.1,
            response_format: { type: "json_object" },
        }),
        signal: AbortSignal.timeout(90_000),
    });

    if (!response.ok) {
        const err = await response.text().catch(() => "");
        throw new Error(`AgentSwing router API ${response.status}: ${err.slice(0, 300)}`);
    }

    const json = (await response.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
    };
    const raw = json.choices?.[0]?.message?.content?.trim();
    if (!raw) throw new Error("AgentSwing router returned empty content");

    const parsed = JSON.parse(raw) as Partial<RolloutEvaluation>;
    const score = Math.min(1, Math.max(0, Number(parsed.score ?? 0)));
    const progress = Math.min(1, Math.max(0, Number(parsed.progress ?? score)));
    const evidence = Math.min(1, Math.max(0, Number(parsed.evidence ?? score)));
    const health = Math.min(1, Math.max(0, Number(parsed.health ?? score)));

    return {
        score,
        progress,
        evidence,
        health,
        rationale: String(parsed.rationale ?? ""),
        projectedTrajectory: String(parsed.projectedTrajectory ?? ""),
    };
}
