/**
 * AgentSwingEngine — Core context engine implementing Keep-Last-N, Summary, and Adaptive Routing.
 *
 * Lifecycle:
 *   ingest()   — no-op (session manager handles persistence)
 *   assemble() — check token usage ratio → apply strategy if over threshold
 *   compact()  — called on overflow or /compact → apply strategy forcefully
 *   afterTurn()— (summary/adaptive-routing) pre-generate summary for next assemble
 *
 * ownsCompaction: true — we fully replace OpenClaw's built-in auto-compaction.
 */

import type { AgentSwingConfig } from "./config.js";
import {
    FALLBACK_CONTEXT_WINDOW,
    resolveConfig,
} from "./config.js";
import {
    parseConversation,
    keepLastNTurns,
    getMessagesToSummarize,
    messagesToText,
} from "./turn-parser.js";
import type { Msg } from "./turn-parser.js";
import {
    evaluateBranchRollout,
    generateSummary,
} from "./summarizer.js";
import type { RolloutEvaluation } from "./summarizer.js";

/** Simple char/4 token estimator (matches OpenClaw's heuristic). */
function estimateTokens(messages: Msg[]): number {
    let chars = 0;
    for (const msg of messages) {
        if (typeof msg.content === "string") {
            chars += msg.content.length;
        } else if (Array.isArray(msg.content)) {
            for (const block of msg.content as Record<string, unknown>[]) {
                if (typeof block.text === "string") {
                    chars += (block.text as string).length;
                }
                if (typeof block.content === "string") {
                    chars += (block.content as string).length;
                }
                if (block.arguments) {
                    chars += JSON.stringify(block.arguments).length;
                }
            }
        }
        // Add overhead per message for role/metadata
        chars += 20;
    }
    return Math.ceil(chars / 4);
}

/** Per-session state for the engine. */
interface SessionState {
    /** Cached summary from previous compaction (summary mode). */
    cachedSummary: string | null;
    /** Original user prompt (first user message). */
    originalPrompt: string | null;
    /** Compaction count for this session. */
    compactionCount: number;
}

interface BranchResult {
    name: "keep-last-n" | "summary" | "discard-all";
    messages: Msg[];
    estimatedTokens: number;
    systemPromptAddition?: string;
    rollout?: RolloutEvaluation;
    score?: number;
}

export class AgentSwingEngine {
    readonly info = {
        id: "agentswing-context-engine",
        name: "AgentSwing Context Engine",
        version: "0.1.0",
        ownsCompaction: true,
    };

    private config: AgentSwingConfig;
    private sessions: Map<string, SessionState> = new Map();

    constructor(pluginConfig: Record<string, unknown> = {}) {
        this.config = resolveConfig(pluginConfig);
        const triggerDesc =
            this.config.triggerMode === "turn-count"
                ? `triggerMode=turn-count, triggerTurnCount=${this.config.triggerTurnCount}`
                : `triggerMode=token-ratio, triggerRatio=${this.config.triggerRatio}`;
        console.error(
            `[AgentSwing] Initialized: mode=${this.config.mode}, ` +
            `${triggerDesc}, keepLastN=${this.config.keepLastN}`,
        );
    }

    private getSession(sessionId: string): SessionState {
        let s = this.sessions.get(sessionId);
        if (!s) {
            s = { cachedSummary: null, originalPrompt: null, compactionCount: 0 };
            this.sessions.set(sessionId, s);
        }
        return s;
    }

    private getContextWindow(tokenBudget?: number): number {
        if (this.config.contextWindow) return this.config.contextWindow;
        if (tokenBudget && tokenBudget > 0) return tokenBudget;
        return FALLBACK_CONTEXT_WINDOW;
    }

    // ─── Lifecycle methods ───────────────────────────────────────────

    async ingest(_params: {
        sessionId: string;
        sessionKey?: string;
        message: Msg;
        isHeartbeat?: boolean;
    }): Promise<{ ingested: boolean }> {
        return { ingested: true };
    }

    async assemble(params: {
        sessionId: string;
        sessionKey?: string;
        messages: Msg[];
        tokenBudget?: number;
        availableTools?: Set<string>;
        citationsMode?: string;
        model?: string;
        prompt?: string;
    }): Promise<{
        messages: Msg[];
        estimatedTokens: number;
        systemPromptAddition?: string;
    }> {
        const { sessionId, messages, tokenBudget } = params;
        const session = this.getSession(sessionId);
        const contextWindow = this.getContextWindow(tokenBudget);

        // Extract and cache original prompt
        if (!session.originalPrompt) {
            const firstUser = messages.find((m) => m.role === "user");
            if (firstUser) {
                session.originalPrompt =
                    typeof firstUser.content === "string"
                        ? firstUser.content
                        : messagesToText([firstUser]);
            }
        }

        const estimated = estimateTokens(messages);
        const parsed = parseConversation(messages);
        const turnCount = parsed.turns.length;

        // Determine whether to trigger based on configured mode
        let shouldTrigger: boolean;
        if (this.config.triggerMode === "turn-count") {
            shouldTrigger = turnCount > this.config.triggerTurnCount;
            console.error(
                `[AgentSwing] assemble: session=${sessionId.slice(0, 8)}… ` +
                `tokens≈${estimated}, turns=${turnCount}, ` +
                `threshold=${this.config.triggerTurnCount} (turn-count)`,
            );
        } else {
            const usageRatio = estimated / contextWindow;
            shouldTrigger = usageRatio > this.config.triggerRatio;
            console.error(
                `[AgentSwing] assemble: session=${sessionId.slice(0, 8)}… ` +
                `tokens≈${estimated}, window=${contextWindow}, ` +
                `ratio=${usageRatio.toFixed(3)}, threshold=${this.config.triggerRatio} (token-ratio)`,
            );
        }

        // Below threshold → pass through all messages
        if (!shouldTrigger) {
            return { messages, estimatedTokens: estimated };
        }

        // Above threshold → apply context management
        console.error(
            `[AgentSwing] TRIGGERED (${this.config.triggerMode}): ` +
            `turns=${turnCount}, tokens≈${estimated} — applying ${this.config.mode}`,
        );

        return this.applyStrategy(messages, session, contextWindow, parsed);
    }

    async compact(params: {
        sessionId: string;
        sessionKey?: string;
        sessionFile: string;
        tokenBudget?: number;
        force?: boolean;
        currentTokenCount?: number;
        compactionTarget?: "budget" | "threshold";
        customInstructions?: string;
        runtimeContext?: Record<string, unknown>;
    }): Promise<{
        ok: boolean;
        compacted: boolean;
        reason?: string;
        result?: {
            summary?: string;
            firstKeptEntryId?: string;
            tokensBefore: number;
            tokensAfter?: number;
        };
    }> {
        // compact() is called by OpenClaw for overflow recovery or /compact command.
        // Since we own compaction, we need to handle it. However, compact() doesn't
        // receive the messages array directly — it receives a sessionFile path.
        // For our implementation, the main work happens in assemble().
        // In compact() we signal success and let the next assemble() apply the strategy.

        const session = this.getSession(params.sessionId);
        session.compactionCount++;

        // Clear cached summary to force re-generation on next assemble
        if (this.config.mode === "summary") {
            session.cachedSummary = null;
        }

        const tokensBefore = params.currentTokenCount ?? 0;

        console.error(
            `[AgentSwing] compact: session=${params.sessionId.slice(0, 8)}… ` +
            `count=${session.compactionCount}, force=${params.force ?? false}`,
        );

        return {
            ok: true,
            compacted: true,
            reason: `AgentSwing ${this.config.mode} compaction triggered`,
            result: {
                summary: session.cachedSummary ?? undefined,
                tokensBefore,
            },
        };
    }

    async afterTurn(params: {
        sessionId: string;
        sessionKey?: string;
        sessionFile: string;
        messages: Msg[];
        prePromptMessageCount: number;
        autoCompactionSummary?: string;
        isHeartbeat?: boolean;
        tokenBudget?: number;
        runtimeContext?: Record<string, unknown>;
    }): Promise<void> {
        // In summary/adaptive-routing mode, pre-generate summary after each turn
        // if we're approaching threshold. This avoids blocking assemble().
        if (this.config.mode !== "summary" && this.config.mode !== "adaptive-routing") return;

        const { sessionId, messages, tokenBudget } = params;
        const contextWindow = this.getContextWindow(tokenBudget);
        const estimated = estimateTokens(messages);
        const usageRatio = estimated / contextWindow;

        // Pre-generate summary when we're approaching the trigger threshold
        const parsed = parseConversation(messages);
        let shouldPregen: boolean;
        if (this.config.triggerMode === "turn-count") {
            shouldPregen = parsed.turns.length > this.config.triggerTurnCount * 0.8;
        } else {
            shouldPregen = usageRatio > this.config.triggerRatio * 0.8;
        }
        if (shouldPregen) {
            const session = this.getSession(sessionId);
            if (!session.cachedSummary) {
                try {
                    console.error(
                        `[AgentSwing] afterTurn: pre-generating summary for session ${sessionId.slice(0, 8)}…`,
                    );
                    const toSummarize = getMessagesToSummarize(parsed, this.config.keepLastN);
                    if (toSummarize.length > 0) {
                        session.cachedSummary = await generateSummary(toSummarize);
                        console.error(
                            `[AgentSwing] afterTurn: summary cached (${session.cachedSummary.length} chars)`,
                        );
                    }
                } catch (err) {
                    console.error(`[AgentSwing] afterTurn: summary pre-generation failed:`, err);
                }
            }
        }
    }

    async dispose(): Promise<void> {
        this.sessions.clear();
    }

    // ─── Strategy implementation ─────────────────────────────────────

    private async applyStrategy(
        messages: Msg[],
        session: SessionState,
        contextWindow: number,
        parsed?: ReturnType<typeof parseConversation>,
    ): Promise<{
        messages: Msg[];
        estimatedTokens: number;
        systemPromptAddition?: string;
    }> {
        if (!parsed) {
            parsed = parseConversation(messages);
        }

        if (this.config.mode === "keep-last-n") {
            return this.applyKeepLastN(parsed);
        }
        if (this.config.mode === "summary") {
            return this.applySummary(parsed, session, contextWindow);
        }
        return this.applyAdaptiveRouting(parsed, session, contextWindow);
    }

    private applyKeepLastN(
        parsed: ReturnType<typeof parseConversation>,
    ): {
        messages: Msg[];
        estimatedTokens: number;
        systemPromptAddition?: string;
    } {
        const n = this.config.keepLastN;
        const truncated = keepLastNTurns(parsed, n);
        const est = estimateTokens(truncated);

        console.error(
            `[AgentSwing] keep-last-n: kept ${Math.min(n, parsed.turns.length)}/${parsed.turns.length} turns, ` +
            `tokens≈${est}`,
        );

        return {
            messages: truncated,
            estimatedTokens: est,
            systemPromptAddition:
                parsed.turns.length > n
                    ? `[Context Management] Earlier conversation history (${parsed.turns.length - n} turns) has been truncated. Only the ${Math.min(n, parsed.turns.length)} most recent interaction turns are visible.`
                    : undefined,
        };
    }

    private async applySummary(
        parsed: ReturnType<typeof parseConversation>,
        session: SessionState,
        _contextWindow: number,
    ): Promise<{
        messages: Msg[];
        estimatedTokens: number;
        systemPromptAddition?: string;
    }> {
        // AgentSwing format: (q, Sum) — original prompt + summary + recent N turns
        // Use keepLastN consistently (same value used in afterTurn pre-generation)
        const keepRecent = Math.min(this.config.keepLastN, parsed.turns.length);
        const toSummarize = getMessagesToSummarize(parsed, keepRecent);

        let summary = session.cachedSummary;

        if (!summary && toSummarize.length > 0) {
            try {
                console.error(
                    `[AgentSwing] summary: generating summary for ${toSummarize.length} messages…`,
                );
                summary = await generateSummary(toSummarize);
                session.cachedSummary = summary;
                console.error(
                    `[AgentSwing] summary: generated (${summary.length} chars)`,
                );
            } catch (err) {
                console.error(`[AgentSwing] summary: generation failed, falling back to keep-last-n:`, err);
                // Fallback to keep-last-n
                return this.applyKeepLastN(parsed);
            }
        }

        // Build assembled messages: preamble + summary as user msg + recent turns
        const assembled: Msg[] = [...parsed.preamble];

        if (summary) {
            assembled.push({
                role: "user",
                content: `[Previous Exploration Summary]\n${summary}\n\n[End of Summary — Continue from where you left off]`,
            });
        }

        // Add recent turns
        const recentTurns = parsed.turns.slice(-keepRecent);
        for (const turn of recentTurns) {
            assembled.push(...turn.messages);
        }

        const est = estimateTokens(assembled);

        console.error(
            `[AgentSwing] summary: assembled ${assembled.length} messages ` +
            `(preamble=${parsed.preamble.length}, summary=1, recent=${recentTurns.length} turns), ` +
            `tokens≈${est}`,
        );

        return {
            messages: assembled,
            estimatedTokens: est,
            systemPromptAddition:
                `[Context Management] Earlier conversation history (${parsed.turns.length - keepRecent} turns) ` +
                `has been summarized. The summary and ${keepRecent} most recent turns are included above.`,
        };
    }

    private applyDiscardAll(parsed: ReturnType<typeof parseConversation>): {
        messages: Msg[];
        estimatedTokens: number;
        systemPromptAddition?: string;
    } {
        const messages = [...parsed.preamble];
        const estimatedTokens = estimateTokens(messages);
        return {
            messages,
            estimatedTokens,
            systemPromptAddition:
                "[Context Management] Full interaction trajectory has been reset to original prompt (discard-all).",
        };
    }

    private scoreBranchHeuristic(
        branch: BranchResult,
        parsed: ReturnType<typeof parseConversation>,
        contextWindow: number,
    ): number {
        const tokenRatio = branch.estimatedTokens / Math.max(1, contextWindow);
        const compactness = 1 - Math.min(1, tokenRatio);
        const totalTurns = Math.max(1, parsed.turns.length);
        const keptTurns =
            branch.name === "discard-all" ? 0 : Math.min(this.config.keepLastN, parsed.turns.length);
        const continuity = keptTurns / totalTurns;
        const evidence = branch.name === "summary" ? 0.9 : branch.name === "keep-last-n" ? 0.8 : 0.45;
        const discardPenalty = branch.name === "discard-all" ? 0.35 : 0;
        return compactness * 0.45 + continuity * 0.25 + evidence * 0.30 - discardPenalty;
    }

    private scoreBranchFinal(
        branch: BranchResult,
        parsed: ReturnType<typeof parseConversation>,
        contextWindow: number,
    ): number {
        const heuristic = this.scoreBranchHeuristic(branch, parsed, contextWindow);
        const rollout = branch.rollout?.score;
        if (typeof rollout !== "number") return heuristic;
        return heuristic * 0.35 + rollout * 0.65;
    }

    private async applyAdaptiveRouting(
        parsed: ReturnType<typeof parseConversation>,
        session: SessionState,
        contextWindow: number,
    ): Promise<{
        messages: Msg[];
        estimatedTokens: number;
        systemPromptAddition?: string;
    }> {
        const keep = this.applyKeepLastN(parsed);
        const summary = await this.applySummary(parsed, session, contextWindow);
        const discard = this.applyDiscardAll(parsed);

        const baseBranches: BranchResult[] = [
            { name: "keep-last-n", ...keep },
            { name: "summary", ...summary },
            { name: "discard-all", ...discard },
        ];

        const branches = await Promise.all(
            baseBranches.map(async (branch) => {
                try {
                    const rollout = await evaluateBranchRollout({
                        branchName: branch.name,
                        messages: branch.messages,
                        lookaheadSteps: this.config.lookaheadSteps,
                    });
                    return { ...branch, rollout };
                } catch (err) {
                    console.error(`[AgentSwing] rollout failed for ${branch.name}:`, err);
                    return branch;
                }
            }),
        );

        let best = branches[0];
        best.score = this.scoreBranchFinal(best, parsed, contextWindow);
        const scoreText: string[] = [
            `${best.name}=final:${best.score.toFixed(3)}${best.rollout ? `/rollout:${best.rollout.score.toFixed(3)}` : ""}`,
        ];

        for (let i = 1; i < branches.length; i++) {
            const b = branches[i];
            b.score = this.scoreBranchFinal(b, parsed, contextWindow);
            scoreText.push(`${b.name}=final:${b.score.toFixed(3)}${b.rollout ? `/rollout:${b.rollout.score.toFixed(3)}` : ""}`);
            if ((b.score ?? -1) > (best.score ?? -1)) {
                best = b;
            }
        }

        console.error(
            `[AgentSwing] adaptive-routing: k=${this.config.lookaheadSteps}, scores=[${scoreText.join(", ")}], selected=${best.name}`,
        );

        return {
            messages: best.messages,
            estimatedTokens: best.estimatedTokens,
            systemPromptAddition:
                `[Context Management] Adaptive routing selected '${best.name}' with lookahead k=${this.config.lookaheadSteps}. ` +
                `Branch scores: ${scoreText.join(", ")}.`,
        };
    }
}
