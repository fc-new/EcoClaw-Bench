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
import type { Msg } from "./turn-parser.js";
type AssembleResponse = {
    messages: Msg[];
    estimatedTokens: number;
    systemPromptAddition?: string;
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
export declare class AgentSwingEngine {
    readonly info: {
        id: string;
        name: string;
        version: string;
        ownsCompaction: boolean;
    };
    private config;
    private runtime?;
    private openclawConfig?;
    private sessions;
    constructor(pluginConfig?: Record<string, unknown>, runtimeOptions?: AgentSwingEngineRuntimeOptions);
    private getContextWindow;
    private resolveSummaryRequestOptions;
    bootstrap(params: {
        sessionId: string;
        sessionKey?: string;
        sessionFile: string;
    }): Promise<{
        bootstrapped: boolean;
        importedMessages?: number;
        reason?: string;
    }>;
    ingest(_params: {
        sessionId: string;
        sessionKey?: string;
        message: Msg;
        isHeartbeat?: boolean;
    }): Promise<{
        ingested: boolean;
    }>;
    assemble(params: {
        sessionId: string;
        sessionKey?: string;
        messages: Msg[];
        tokenBudget?: number;
        availableTools?: Set<string>;
        citationsMode?: string;
        model?: string;
        prompt?: string;
    }): Promise<AssembleResponse>;
    compact(params: {
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
    }>;
    afterTurn(params: {
        sessionId: string;
        sessionKey?: string;
        sessionFile: string;
        messages: Msg[];
        prePromptMessageCount: number;
        autoCompactionSummary?: string;
        isHeartbeat?: boolean;
        tokenBudget?: number;
        runtimeContext?: Record<string, unknown>;
    }): Promise<void>;
    dispose(): Promise<void>;
    private applyStrategy;
    private applyKeepLastN;
    private applySummary;
    private withManagedContext;
    private ensureSummaryState;
    private synchronizeCanonicalState;
    private loadCanonicalState;
    private persistCanonicalState;
}
export {};
