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
import type { Msg } from "./turn-parser.js";
export declare class AgentSwingEngine {
    readonly info: {
        id: string;
        name: string;
        version: string;
        ownsCompaction: boolean;
    };
    private config;
    private sessions;
    constructor(pluginConfig?: Record<string, unknown>);
    private getSession;
    private getContextWindow;
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
    }): Promise<{
        messages: Msg[];
        estimatedTokens: number;
        systemPromptAddition?: string;
    }>;
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
}
