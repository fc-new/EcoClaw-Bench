/**
 * AgentSwingEngine — Core context engine implementing Keep-Last-N and Summary strategies.
 *
 * Lifecycle:
 *   ingest()    — no-op; canonical state is synchronized from full transcripts
 *   bootstrap() — import an existing session transcript into plugin-owned state
 *   assemble()  — synchronize canonical state, then apply AgentSwing strategy
 *   compact()   — read sessionFile, synchronize, and force a managed context view
 *   afterTurn() — persist canonical state and pre-generate summary when useful
 *
 * ownsCompaction: true — we fully replace OpenClaw's built-in auto-compaction.
 */

import fs from "node:fs/promises";
import type { AgentSwingConfig } from "./config.js";
import {
    FALLBACK_CONTEXT_WINDOW,
    resolveConfig,
} from "./config.js";
import {
    createCanonicalSessionState,
    loadCanonicalSessionState,
    saveCanonicalSessionState,
    type AgentSwingCanonicalSessionState,
    type AgentSwingManagedContextMetadata,
    type AgentSwingManagedContextSource,
    type AgentSwingSummaryCache,
} from "./canonical-session-state.js";
import {
    parseConversation,
    keepLastNTurns,
    getMessagesToSummarize,
    isConversationMessage,
} from "./turn-parser.js";
import type { Msg, ParsedConversation } from "./turn-parser.js";
import { generateSummary } from "./summarizer.js";

type AssembleResponse = {
    messages: Msg[];
    estimatedTokens: number;
    systemPromptAddition?: string;
};

type StrategyResult = {
    state: AgentSwingCanonicalSessionState;
    stateChanged: boolean;
    response: AssembleResponse;
};

type RuntimeResolvedProviderAuth = {
    apiKey?: string;
};

type EngineRuntime = {
    modelAuth?: {
        resolveApiKeyForProvider?: (params: {
            provider: string;
            cfg?: Record<string, unknown>;
        }) => Promise<RuntimeResolvedProviderAuth>;
    };
};

type AgentSwingEngineRuntimeOptions = {
    runtime?: EngineRuntime;
    openclawConfig?: Record<string, unknown>;
};

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
        chars += 20;
    }
    return Math.ceil(chars / 4);
}

export class AgentSwingEngine {
    readonly info = {
        id: "agentswing-context-engine",
        name: "AgentSwing Context Engine",
        version: "0.2.0",
        ownsCompaction: true,
    };

    private config: AgentSwingConfig;
    private runtime?: EngineRuntime;
    private openclawConfig?: Record<string, unknown>;
    private sessions: Map<string, AgentSwingCanonicalSessionState> = new Map();

    constructor(
        pluginConfig: Record<string, unknown> = {},
        runtimeOptions: AgentSwingEngineRuntimeOptions = {},
    ) {
        this.config = resolveConfig(pluginConfig);
        this.runtime = runtimeOptions.runtime;
        this.openclawConfig = runtimeOptions.openclawConfig;
        const triggerDesc =
            this.config.triggerMode === "turn-count"
                ? `triggerMode=turn-count, triggerTurnCount=${this.config.triggerTurnCount}`
                : `triggerMode=token-ratio, triggerRatio=${this.config.triggerRatio}`;
        console.error(
            `[AgentSwing] Initialized: mode=${this.config.mode}, ` +
            `${triggerDesc}, keepLastN=${this.config.keepLastN}`,
        );
    }

    private getContextWindow(tokenBudget?: number): number {
        if (this.config.contextWindow) return this.config.contextWindow;
        if (tokenBudget && tokenBudget > 0) return tokenBudget;
        return FALLBACK_CONTEXT_WINDOW;
    }

    private async resolveSummaryRequestOptions(modelHint?: string): Promise<{
        apiBase: string;
        apiKey?: string;
        model: string;
    }> {
        const provider =
            this.config.summaryProvider ??
            inferProviderFromModel(modelHint) ??
            "openai";
        const model = this.config.summaryModel ?? inferModelId(modelHint) ?? "gpt-5-mini";
        const apiBase =
            this.config.summaryApiBase ??
            resolveProviderBaseUrl(this.openclawConfig, provider);

        if (!apiBase) {
            throw new Error(
                `AgentSwing summarizer: no baseUrl resolved for provider "${provider}". ` +
                "Set summaryApiBase or configure models.providers.<provider>.baseUrl.",
            );
        }

        const authResolver = this.runtime?.modelAuth?.resolveApiKeyForProvider;
        if (!authResolver) {
            return { apiBase, model };
        }

        const auth = await authResolver({
            provider,
            cfg: this.openclawConfig,
        });
        return {
            apiBase,
            model,
            ...(typeof auth?.apiKey === "string" && auth.apiKey.length > 0
                ? { apiKey: auth.apiKey }
                : {}),
        };
    }

    async bootstrap(params: {
        sessionId: string;
        sessionKey?: string;
        sessionFile: string;
    }): Promise<{
        bootstrapped: boolean;
        importedMessages?: number;
        reason?: string;
    }> {
        const rawMessages = await readMessagesFromSessionFile(params.sessionFile);
        if (rawMessages.length === 0) {
            return {
                bootstrapped: false,
                reason: "no transcript messages found for bootstrap",
            };
        }

        const synced = await this.synchronizeCanonicalState({
            sessionId: params.sessionId,
            rawMessages,
        });
        await this.persistCanonicalState(synced.state);

        console.error(
            `[AgentSwing] bootstrap: session=${params.sessionId.slice(0, 8)}… imported=${synced.state.messageCount}`,
        );

        return {
            bootstrapped: true,
            importedMessages: synced.state.messageCount,
        };
    }

    async ingest(_params: {
        sessionId: string;
        sessionKey?: string;
        message: Msg;
        isHeartbeat?: boolean;
    }): Promise<{ ingested: boolean }> {
        return { ingested: false };
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
    }): Promise<AssembleResponse> {
        const synced = await this.synchronizeCanonicalState({
            sessionId: params.sessionId,
            rawMessages: params.messages,
        });
        let state = synced.state;

        if (synced.changed) {
            await this.persistCanonicalState(state);
        }

        const contextWindow = this.getContextWindow(params.tokenBudget);
        const estimated = estimateTokens(state.messages);
        const parsed = parseConversation(state.messages);
        const turnCount = parsed.turns.length;

        let shouldTrigger: boolean;
        if (this.config.triggerMode === "turn-count") {
            shouldTrigger = turnCount > this.config.triggerTurnCount;
            console.error(
                `[AgentSwing] assemble: session=${params.sessionId.slice(0, 8)}… ` +
                `tokens≈${estimated}, turns=${turnCount}, ` +
                `threshold=${this.config.triggerTurnCount} (turn-count)`,
            );
        } else {
            const usageRatio = estimated / contextWindow;
            shouldTrigger = usageRatio > this.config.triggerRatio;
            console.error(
                `[AgentSwing] assemble: session=${params.sessionId.slice(0, 8)}… ` +
                `tokens≈${estimated}, window=${contextWindow}, ` +
                `ratio=${usageRatio.toFixed(3)}, threshold=${this.config.triggerRatio} (token-ratio)`,
            );
        }

        if (!shouldTrigger) {
            return { messages: state.messages, estimatedTokens: estimated };
        }

        console.error(
            `[AgentSwing] TRIGGERED (${this.config.triggerMode}): ` +
            `turns=${turnCount}, tokens≈${estimated} — applying ${this.config.mode}`,
        );

        const result = await this.applyStrategy({
            state,
            parsed,
            model: params.model,
            source: "assemble",
        });
        state = result.state;
        if (result.stateChanged) {
            await this.persistCanonicalState(state);
        }
        return result.response;
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
        const rawMessages = await readMessagesFromSessionFile(params.sessionFile);
        const synced = await this.synchronizeCanonicalState({
            sessionId: params.sessionId,
            rawMessages,
        });
        let state = bumpCompactionCount(synced.state, this.config);
        const parsed = parseConversation(state.messages);
        const tokensBefore = params.currentTokenCount ?? estimateTokens(state.messages);

        const result = await this.applyStrategy({
            state,
            parsed,
            source: "compact",
        });
        state = result.state;

        await this.persistCanonicalState(state);

        const tokensAfter = result.response.estimatedTokens;
        const compacted = tokensAfter < tokensBefore;

        console.error(
            `[AgentSwing] compact: session=${params.sessionId.slice(0, 8)}… ` +
            `count=${state.compactionCount}, tokens≈${tokensBefore}→${tokensAfter}`,
        );

        return {
            ok: true,
            compacted,
            reason: compacted
                ? `AgentSwing ${this.config.mode} compaction applied`
                : `AgentSwing ${this.config.mode} produced no additional reduction`,
            result: {
                summary: state.cachedSummary?.summary,
                tokensBefore,
                tokensAfter,
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
        const synced = await this.synchronizeCanonicalState({
            sessionId: params.sessionId,
            rawMessages: params.messages,
        });
        let state = synced.state;
        let changed = synced.changed;

        if (this.config.mode !== "summary") {
            if (changed) {
                await this.persistCanonicalState(state);
            }
            return;
        }

        const contextWindow = this.getContextWindow(params.tokenBudget);
        const estimated = estimateTokens(state.messages);
        const usageRatio = estimated / contextWindow;
        const parsed = parseConversation(state.messages);

        let shouldPregen: boolean;
        if (this.config.triggerMode === "turn-count") {
            shouldPregen = parsed.turns.length > this.config.triggerTurnCount * 0.8;
        } else {
            shouldPregen = usageRatio > this.config.triggerRatio * 0.8;
        }

        if (shouldPregen && !hasFreshSummary(state, parsed.turns.length)) {
            try {
                console.error(
                    `[AgentSwing] afterTurn: pre-generating summary for session ${params.sessionId.slice(0, 8)}…`,
                );
                const ensured = await this.ensureSummaryState(state, parsed);
                state = ensured.state;
                changed = changed || ensured.stateChanged;
                if (state.cachedSummary) {
                    console.error(
                        `[AgentSwing] afterTurn: summary cached (${state.cachedSummary.summary.length} chars)`,
                    );
                }
            } catch (error) {
                console.error(`[AgentSwing] afterTurn: summary pre-generation failed:`, error);
            }
        }

        if (changed) {
            await this.persistCanonicalState(state);
        }
    }

    async dispose(): Promise<void> {
        this.sessions.clear();
    }

    private async applyStrategy(params: {
        state: AgentSwingCanonicalSessionState;
        parsed?: ParsedConversation;
        model?: string;
        source: AgentSwingManagedContextSource;
    }): Promise<StrategyResult> {
        const parsed = params.parsed ?? parseConversation(params.state.messages);
        if (this.config.mode === "keep-last-n") {
            const response = this.applyKeepLastN(parsed);
            return {
                state: this.withManagedContext({
                    state: params.state,
                    parsed,
                    response,
                    source: params.source,
                    keptTurnCount: Math.min(this.config.keepLastN, parsed.turns.length),
                }),
                stateChanged: true,
                response,
            };
        }
        return this.applySummary(params.state, parsed, params.source, params.model);
    }

    private applyKeepLastN(parsed: ParsedConversation): AssembleResponse {
        const n = this.config.keepLastN;
        const truncated = keepLastNTurns(parsed, n);
        const estimatedTokens = estimateTokens(truncated);

        console.error(
            `[AgentSwing] keep-last-n: kept ${Math.min(n, parsed.turns.length)}/${parsed.turns.length} turns, ` +
            `tokens≈${estimatedTokens}`,
        );

        return {
            messages: truncated,
            estimatedTokens,
            systemPromptAddition:
                parsed.turns.length > n
                    ? `[Context Management] Earlier conversation history (${parsed.turns.length - n} turns) has been truncated. Only the ${Math.min(n, parsed.turns.length)} most recent interaction turns are visible.`
                    : undefined,
        };
    }

    private async applySummary(
        state: AgentSwingCanonicalSessionState,
        parsed: ParsedConversation,
        source: AgentSwingManagedContextSource,
        model?: string,
    ): Promise<StrategyResult> {
        try {
            const ensured = await this.ensureSummaryState(state, parsed, model);
            const summary = ensured.state.cachedSummary?.summary;
            if (!summary) {
                return {
                    state: ensured.state,
                    stateChanged: ensured.stateChanged,
                    response: this.applyKeepLastN(parsed),
                };
            }

            const assembled = buildSummaryMessages(parsed, summary);
            const estimatedTokens = estimateTokens(assembled);

            console.error(
                `[AgentSwing] summary: assembled ${assembled.length} messages ` +
                `(preamble=${parsed.preamble.length}, turns=${parsed.turns.length}), ` +
                `tokens≈${estimatedTokens}`,
            );

            return {
                state: this.withManagedContext({
                    state: ensured.state,
                    parsed,
                    response: {
                        messages: assembled,
                        estimatedTokens,
                    },
                    source,
                    keptTurnCount: 0,
                }),
                stateChanged: true,
                response: {
                    messages: assembled,
                    estimatedTokens,
                    systemPromptAddition:
                        parsed.turns.length > 0
                            ? `[Context Management] Earlier conversation history (${parsed.turns.length} turns) has been summarized into the AgentSwing (q, Sum) format.`
                            : undefined,
                },
            };
        } catch (error) {
            console.error(
                `[AgentSwing] summary: generation failed, falling back to keep-last-n:`,
                error,
            );
            return {
                state,
                stateChanged: false,
                response: this.applyKeepLastN(parsed),
            };
        }
    }

    private withManagedContext(params: {
        state: AgentSwingCanonicalSessionState;
        parsed: ParsedConversation;
        response: AssembleResponse;
        source: AgentSwingManagedContextSource;
        keptTurnCount: number;
    }): AgentSwingCanonicalSessionState {
        const sourceTurnCount = params.parsed.turns.length;
        const estimatedTokensBefore = estimateTokens(params.state.messages);
        return recreateState(params.state, this.config, {
            managedContext: {
                lastManagedAt: new Date().toISOString(),
                lastManagedSource: params.source,
                lastManagedMode: this.config.mode,
                sourceTurnCount,
                keptTurnCount: params.keptTurnCount,
                droppedTurnCount: Math.max(0, sourceTurnCount - params.keptTurnCount),
                estimatedTokensBefore,
                estimatedTokensAfter: params.response.estimatedTokens,
            },
        });
    }

    private async ensureSummaryState(
        state: AgentSwingCanonicalSessionState,
        parsed: ParsedConversation,
        model?: string,
    ): Promise<{
        state: AgentSwingCanonicalSessionState;
        stateChanged: boolean;
    }> {
        if (hasFreshSummary(state, parsed.turns.length)) {
            return { state, stateChanged: false };
        }

        const toSummarize = getMessagesToSummarize(parsed);
        if (toSummarize.length === 0) {
            return { state, stateChanged: false };
        }

        console.error(
            `[AgentSwing] summary: generating summary for ${toSummarize.length} messages…`,
        );
        const requestOptions = await this.resolveSummaryRequestOptions(model);
        const summary = await generateSummary(toSummarize, {
            ...requestOptions,
            originalPrompt: state.originalPrompt,
        });
        console.error(
            `[AgentSwing] summary: generated (${summary.length} chars)`,
        );

        return {
            state: recreateState(state, this.config, {
                cachedSummary: {
                    summary,
                    sourceMessageCount: state.sourceMessageCount,
                    sourceTurnCount: parsed.turns.length,
                    generatedAt: new Date().toISOString(),
                },
            }),
            stateChanged: true,
        };
    }

    private async synchronizeCanonicalState(params: {
        sessionId: string;
        rawMessages: Msg[];
    }): Promise<{
        state: AgentSwingCanonicalSessionState;
        changed: boolean;
    }> {
        const loaded = await this.loadCanonicalState(params.sessionId);
        const rawMessages = structuredClone(params.rawMessages).filter(isConversationMessage);

        if (rawMessages.length === 0 && loaded.state && !loaded.needsRebuild) {
            return { state: loaded.state, changed: false };
        }

        const summaryProjection = splitSummaryManagedProjection(rawMessages);
        const originalPrompt = summaryProjection.isProjection
            ? loaded.state?.originalPrompt
            : extractOriginalPrompt(rawMessages) ?? loaded.state?.originalPrompt;

        if (loaded.state && loaded.state.sourceMessageCount > rawMessages.length) {
            const projection = summaryProjection.isProjection
                ? { matchedCount: summaryProjection.projectionMessageCount }
                : splitManagedProjection(rawMessages, loaded.state.messages);
            if (rawMessages.length === 0 || projection.matchedCount > 0) {
                const appendedMessages =
                    projection.matchedCount >= Math.max(1, rawMessages.length - 3)
                        ? rawMessages.slice(projection.matchedCount)
                        : [];
                const messages = [
                    ...loaded.state.messages,
                    ...structuredClone(appendedMessages),
                ];
                const changed =
                    appendedMessages.length > 0 ||
                    !sameConfig(loaded.state.configSnapshot, this.config) ||
                    loaded.state.messageCount !== messages.length ||
                    loaded.state.originalPrompt !== originalPrompt;

                return {
                    state: createCanonicalSessionState({
                        sessionId: loaded.state.sessionId,
                        sourceMessageCount: loaded.state.sourceMessageCount + appendedMessages.length,
                        configSnapshot: this.config,
                        messages,
                        originalPrompt,
                        cachedSummary: loaded.state.cachedSummary,
                        managedContext: loaded.state.managedContext,
                        compactionCount: loaded.state.compactionCount,
                    }),
                    changed,
                };
            }
        }

        if (
            loaded.needsRebuild ||
            !loaded.state ||
            loaded.state.sourceMessageCount > rawMessages.length
        ) {
            return {
                state: createCanonicalSessionState({
                    sessionId: params.sessionId,
                    sourceMessageCount: rawMessages.length,
                    configSnapshot: this.config,
                    messages: rawMessages,
                    originalPrompt,
                    cachedSummary: loaded.state?.cachedSummary,
                    managedContext: loaded.state?.managedContext,
                    compactionCount: loaded.state?.compactionCount ?? 0,
                }),
                changed: true,
            };
        }

        let messages = loaded.state.messages;
        let changed = false;

        if (loaded.state.sourceMessageCount < rawMessages.length) {
            messages = [
                ...messages,
                ...structuredClone(rawMessages.slice(loaded.state.sourceMessageCount)),
            ];
            changed = true;
        }

        if (!sameConfig(loaded.state.configSnapshot, this.config)) {
            changed = true;
        }
        if (loaded.state.messageCount !== messages.length) {
            changed = true;
        }
        if (loaded.state.originalPrompt !== originalPrompt) {
            changed = true;
        }

        return {
            state: createCanonicalSessionState({
                sessionId: loaded.state.sessionId,
                sourceMessageCount: rawMessages.length,
                configSnapshot: this.config,
                messages,
                originalPrompt,
                cachedSummary: loaded.state.cachedSummary,
                managedContext: loaded.state.managedContext,
                compactionCount: loaded.state.compactionCount,
            }),
            changed,
        };
    }

    private async loadCanonicalState(sessionId: string): Promise<{
        needsRebuild: boolean;
        state?: AgentSwingCanonicalSessionState;
    }> {
        const cached = this.sessions.get(sessionId);
        if (cached) {
            return { needsRebuild: false, state: cached };
        }
        const loaded = await loadCanonicalSessionState(sessionId);
        if (loaded.state) {
            this.sessions.set(sessionId, loaded.state);
        }
        return { needsRebuild: loaded.needsRebuild, state: loaded.state };
    }

    private async persistCanonicalState(
        state: AgentSwingCanonicalSessionState,
    ): Promise<void> {
        this.sessions.set(state.sessionId, state);
        try {
            await saveCanonicalSessionState(state);
        } catch (error) {
            console.error(`[AgentSwing] canonical state save failed: ${String(error)}`);
        }
    }
}

function sameConfig(left: AgentSwingConfig, right: AgentSwingConfig): boolean {
    return (
        left.mode === right.mode &&
        left.triggerMode === right.triggerMode &&
        left.triggerRatio === right.triggerRatio &&
        left.triggerTurnCount === right.triggerTurnCount &&
        left.keepLastN === right.keepLastN &&
        left.contextWindow === right.contextWindow &&
        left.summaryProvider === right.summaryProvider &&
        left.summaryModel === right.summaryModel &&
        left.summaryApiBase === right.summaryApiBase
    );
}

function splitManagedProjection(
    candidate: Msg[],
    canonical: Msg[],
): { matchedCount: number } {
    if (candidate.length === 0 || canonical.length === 0) {
        return { matchedCount: 0 };
    }

    let canonicalIndex = 0;
    let matchedCount = 0;
    for (const message of candidate) {
        const matchIndex = findMessageIndex(canonical, message, canonicalIndex);
        if (matchIndex < 0) {
            break;
        }
        matchedCount++;
        canonicalIndex = matchIndex + 1;
    }

    return { matchedCount };
}

function splitSummaryManagedProjection(
    candidate: Msg[],
): {
    isProjection: boolean;
    projectionMessageCount: number;
} {
    const summaryIndex = candidate.findIndex(messageContainsSummaryMarker);
    if (summaryIndex < 0) {
        return { isProjection: false, projectionMessageCount: 0 };
    }
    return {
        isProjection: true,
        projectionMessageCount: summaryIndex + 1,
    };
}

function messageContainsSummaryMarker(message: Msg): boolean {
    return messageContentToText(message).includes("[Summarized Exploration State]");
}

function findMessageIndex(messages: Msg[], target: Msg, startIndex: number): number {
    const targetKey = stableMessageKey(target);
    for (let i = startIndex; i < messages.length; i++) {
        if (stableMessageKey(messages[i]) === targetKey) {
            return i;
        }
    }
    return -1;
}

function stableMessageKey(message: Msg): string {
    return JSON.stringify(message);
}

function hasFreshSummary(
    state: AgentSwingCanonicalSessionState,
    turnCount: number,
): boolean {
    return (
        !!state.cachedSummary &&
        state.cachedSummary.sourceMessageCount === state.sourceMessageCount &&
        state.cachedSummary.sourceTurnCount === turnCount
    );
}

function recreateState(
    state: AgentSwingCanonicalSessionState,
    config: AgentSwingConfig,
    overrides: {
        cachedSummary?: AgentSwingSummaryCache;
        managedContext?: AgentSwingManagedContextMetadata;
        compactionCount?: number;
    } = {},
): AgentSwingCanonicalSessionState {
    return createCanonicalSessionState({
        sessionId: state.sessionId,
        sourceMessageCount: state.sourceMessageCount,
        configSnapshot: config,
        messages: state.messages,
        originalPrompt: state.originalPrompt,
        cachedSummary: overrides.cachedSummary ?? state.cachedSummary,
        managedContext: overrides.managedContext ?? state.managedContext,
        compactionCount: overrides.compactionCount ?? state.compactionCount,
    });
}

function bumpCompactionCount(
    state: AgentSwingCanonicalSessionState,
    config: AgentSwingConfig,
): AgentSwingCanonicalSessionState {
    return recreateState(state, config, {
        compactionCount: state.compactionCount + 1,
    });
}

function extractOriginalPrompt(messages: Msg[]): string | undefined {
    const firstUser = messages.find((message) => message.role === "user");
    if (!firstUser) {
        return undefined;
    }
    return messageContentToText(firstUser);
}

function buildSummaryMessages(parsed: ParsedConversation, summary: string): Msg[] {
    const systemMessages = parsed.preamble.filter((message) => message.role === "system");
    const originalUser = parsed.preamble.find((message) => message.role === "user");

    const summarySuffix =
        `[Summarized Exploration State]\n${summary}\n\n` +
        `[Continue from this compressed state using the preserved task prompt.]`;

    if (!originalUser) {
        return [
            ...systemMessages,
            {
                role: "user",
                content: summarySuffix,
            },
        ];
    }

    return [
        ...systemMessages,
        mergeUserPromptWithSummary(originalUser, summarySuffix),
    ];
}

function mergeUserPromptWithSummary(originalUser: Msg, summarySuffix: string): Msg {
    if (typeof originalUser.content === "string") {
        return {
            ...originalUser,
            content: `${originalUser.content}\n\n${summarySuffix}`,
        };
    }

    if (Array.isArray(originalUser.content)) {
        return {
            ...originalUser,
            content: [
                ...structuredClone(originalUser.content as unknown[]),
                { type: "text", text: `\n\n${summarySuffix}` },
            ],
        };
    }

    return {
        ...originalUser,
        content: summarySuffix,
    };
}

function messageContentToText(message: Msg): string {
    if (typeof message.content === "string") {
        return message.content;
    }
    if (!Array.isArray(message.content)) {
        return "";
    }

    return message.content
        .map((block) => {
            if (!block || typeof block !== "object") {
                return "";
            }
            const record = block as Record<string, unknown>;
            if (typeof record.text === "string") {
                return record.text;
            }
            if (typeof record.content === "string") {
                return record.content;
            }
            return "";
        })
        .filter((text) => text.length > 0)
        .join("\n");
}

async function readMessagesFromSessionFile(sessionFile: string): Promise<Msg[]> {
    try {
        const raw = await fs.readFile(sessionFile, "utf8");
        return raw
            .split(/\r?\n/)
            .filter((line) => line.trim().length > 0)
            .map((line) => {
                const parsed = JSON.parse(line) as Record<string, unknown>;
                if (parsed.type === "message" && isRecord(parsed.message)) {
                    return parsed.message as Msg;
                }
                return isRecord(parsed) ? (parsed as Msg) : undefined;
            })
            .filter((message): message is Msg => !!message);
    } catch {
        return [];
    }
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return !!value && typeof value === "object" && !Array.isArray(value);
}

function inferProviderFromModel(modelHint?: string): string | undefined {
    if (typeof modelHint !== "string") {
        return undefined;
    }
    const slash = modelHint.indexOf("/");
    if (slash <= 0) {
        return undefined;
    }
    return modelHint.slice(0, slash);
}

function inferModelId(modelHint?: string): string | undefined {
    if (typeof modelHint !== "string" || modelHint.trim().length === 0) {
        return undefined;
    }
    const slash = modelHint.indexOf("/");
    return slash >= 0 ? modelHint.slice(slash + 1) : modelHint;
}

function resolveProviderBaseUrl(
    config: Record<string, unknown> | undefined,
    provider: string,
): string | undefined {
    const models = asRecord(config?.models);
    const providers = asRecord(models?.providers);
    const providerConfig = asRecord(providers?.[provider]);
    const baseUrl = providerConfig?.baseUrl;
    return typeof baseUrl === "string" && baseUrl.trim().length > 0
        ? baseUrl.trim()
        : undefined;
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
    return isRecord(value) ? value : undefined;
}
