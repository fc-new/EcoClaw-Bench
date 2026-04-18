/**
 * AgentSwingEngine — Core context engine implementing Keep-Last-N and Summary strategies.
 *
 * Lifecycle:
 *   ingest()   — no-op (session manager handles persistence)
 *   assemble() — check token usage ratio → apply strategy if over threshold
 *   compact()  — called on overflow or /compact → apply strategy forcefully
 *   afterTurn()— (summary mode) pre-generate summary for next assemble
 *
 * ownsCompaction: true — we fully replace OpenClaw's built-in auto-compaction.
 */
import { FALLBACK_CONTEXT_WINDOW, resolveConfig, } from "./config.js";
import { parseConversation, keepLastNTurns, getMessagesToSummarize, messagesToText, } from "./turn-parser.js";
import { generateSummary } from "./summarizer.js";
/** Simple char/4 token estimator (matches OpenClaw's heuristic). */
function estimateTokens(messages) {
    let chars = 0;
    for (const msg of messages) {
        if (typeof msg.content === "string") {
            chars += msg.content.length;
        }
        else if (Array.isArray(msg.content)) {
            for (const block of msg.content) {
                if (typeof block.text === "string") {
                    chars += block.text.length;
                }
                if (typeof block.content === "string") {
                    chars += block.content.length;
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
export class AgentSwingEngine {
    info = {
        id: "agentswing-context-engine",
        name: "AgentSwing Context Engine",
        version: "0.1.0",
        ownsCompaction: true,
    };
    config;
    sessions = new Map();
    constructor(pluginConfig = {}) {
        this.config = resolveConfig(pluginConfig);
        const triggerDesc = this.config.triggerMode === "turn-count"
            ? `triggerMode=turn-count, triggerTurnCount=${this.config.triggerTurnCount}`
            : `triggerMode=token-ratio, triggerRatio=${this.config.triggerRatio}`;
        console.error(`[AgentSwing] Initialized: mode=${this.config.mode}, ` +
            `${triggerDesc}, keepLastN=${this.config.keepLastN}`);
    }
    getSession(sessionId) {
        let s = this.sessions.get(sessionId);
        if (!s) {
            s = { cachedSummary: null, originalPrompt: null, compactionCount: 0 };
            this.sessions.set(sessionId, s);
        }
        return s;
    }
    getContextWindow(tokenBudget) {
        if (this.config.contextWindow)
            return this.config.contextWindow;
        if (tokenBudget && tokenBudget > 0)
            return tokenBudget;
        return FALLBACK_CONTEXT_WINDOW;
    }
    // ─── Lifecycle methods ───────────────────────────────────────────
    async ingest(_params) {
        return { ingested: true };
    }
    async assemble(params) {
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
        let shouldTrigger;
        if (this.config.triggerMode === "turn-count") {
            shouldTrigger = turnCount > this.config.triggerTurnCount;
            console.error(`[AgentSwing] assemble: session=${sessionId.slice(0, 8)}… ` +
                `tokens≈${estimated}, turns=${turnCount}, ` +
                `threshold=${this.config.triggerTurnCount} (turn-count)`);
        }
        else {
            const usageRatio = estimated / contextWindow;
            shouldTrigger = usageRatio > this.config.triggerRatio;
            console.error(`[AgentSwing] assemble: session=${sessionId.slice(0, 8)}… ` +
                `tokens≈${estimated}, window=${contextWindow}, ` +
                `ratio=${usageRatio.toFixed(3)}, threshold=${this.config.triggerRatio} (token-ratio)`);
        }
        // Below threshold → pass through all messages
        if (!shouldTrigger) {
            return { messages, estimatedTokens: estimated };
        }
        // Above threshold → apply context management
        console.error(`[AgentSwing] TRIGGERED (${this.config.triggerMode}): ` +
            `turns=${turnCount}, tokens≈${estimated} — applying ${this.config.mode}`);
        return this.applyStrategy(messages, session, contextWindow, parsed);
    }
    async compact(params) {
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
        console.error(`[AgentSwing] compact: session=${params.sessionId.slice(0, 8)}… ` +
            `count=${session.compactionCount}, force=${params.force ?? false}`);
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
    async afterTurn(params) {
        // In summary mode, pre-generate summary after each turn if we're approaching threshold.
        // This avoids blocking assemble() with a synchronous LLM call.
        if (this.config.mode !== "summary")
            return;
        const { sessionId, messages, tokenBudget } = params;
        const contextWindow = this.getContextWindow(tokenBudget);
        const estimated = estimateTokens(messages);
        const usageRatio = estimated / contextWindow;
        // Pre-generate summary when we're approaching the trigger threshold
        const parsed = parseConversation(messages);
        let shouldPregen;
        if (this.config.triggerMode === "turn-count") {
            shouldPregen = parsed.turns.length > this.config.triggerTurnCount * 0.8;
        }
        else {
            shouldPregen = usageRatio > this.config.triggerRatio * 0.8;
        }
        if (shouldPregen) {
            const session = this.getSession(sessionId);
            if (!session.cachedSummary) {
                try {
                    console.error(`[AgentSwing] afterTurn: pre-generating summary for session ${sessionId.slice(0, 8)}…`);
                    const toSummarize = getMessagesToSummarize(parsed, this.config.keepLastN);
                    if (toSummarize.length > 0) {
                        session.cachedSummary = await generateSummary(toSummarize);
                        console.error(`[AgentSwing] afterTurn: summary cached (${session.cachedSummary.length} chars)`);
                    }
                }
                catch (err) {
                    console.error(`[AgentSwing] afterTurn: summary pre-generation failed:`, err);
                }
            }
        }
    }
    async dispose() {
        this.sessions.clear();
    }
    // ─── Strategy implementation ─────────────────────────────────────
    async applyStrategy(messages, session, contextWindow, parsed) {
        if (!parsed) {
            parsed = parseConversation(messages);
        }
        if (this.config.mode === "keep-last-n") {
            return this.applyKeepLastN(parsed);
        }
        else {
            return this.applySummary(parsed, session, contextWindow);
        }
    }
    applyKeepLastN(parsed) {
        const n = this.config.keepLastN;
        const truncated = keepLastNTurns(parsed, n);
        const est = estimateTokens(truncated);
        console.error(`[AgentSwing] keep-last-n: kept ${Math.min(n, parsed.turns.length)}/${parsed.turns.length} turns, ` +
            `tokens≈${est}`);
        return {
            messages: truncated,
            estimatedTokens: est,
            systemPromptAddition: parsed.turns.length > n
                ? `[Context Management] Earlier conversation history (${parsed.turns.length - n} turns) has been truncated. Only the ${Math.min(n, parsed.turns.length)} most recent interaction turns are visible.`
                : undefined,
        };
    }
    async applySummary(parsed, session, _contextWindow) {
        // AgentSwing format: (q, Sum) — original prompt + summary + recent N turns
        // Use keepLastN consistently (same value used in afterTurn pre-generation)
        const keepRecent = Math.min(this.config.keepLastN, parsed.turns.length);
        const toSummarize = getMessagesToSummarize(parsed, keepRecent);
        let summary = session.cachedSummary;
        if (!summary && toSummarize.length > 0) {
            try {
                console.error(`[AgentSwing] summary: generating summary for ${toSummarize.length} messages…`);
                summary = await generateSummary(toSummarize);
                session.cachedSummary = summary;
                console.error(`[AgentSwing] summary: generated (${summary.length} chars)`);
            }
            catch (err) {
                console.error(`[AgentSwing] summary: generation failed, falling back to keep-last-n:`, err);
                // Fallback to keep-last-n
                return this.applyKeepLastN(parsed);
            }
        }
        // Build assembled messages: preamble + summary as user msg + recent turns
        const assembled = [...parsed.preamble];
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
        console.error(`[AgentSwing] summary: assembled ${assembled.length} messages ` +
            `(preamble=${parsed.preamble.length}, summary=1, recent=${recentTurns.length} turns), ` +
            `tokens≈${est}`);
        return {
            messages: assembled,
            estimatedTokens: est,
            systemPromptAddition: `[Context Management] Earlier conversation history (${parsed.turns.length - keepRecent} turns) ` +
                `has been summarized. The summary and ${keepRecent} most recent turns are included above.`,
        };
    }
}
