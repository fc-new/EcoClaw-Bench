import type { AgentSwingConfig } from "./config.js";
import type { Msg } from "./turn-parser.js";
export type AgentSwingManagedContextSource = "assemble" | "compact";
export type AgentSwingManagedContextMetadata = {
    lastManagedAt: string;
    lastManagedSource: AgentSwingManagedContextSource;
    lastManagedMode: AgentSwingConfig["mode"];
    sourceTurnCount: number;
    keptTurnCount: number;
    droppedTurnCount: number;
    estimatedTokensBefore: number;
    estimatedTokensAfter: number;
};
export type AgentSwingSummaryCache = {
    summary: string;
    sourceMessageCount: number;
    sourceTurnCount: number;
    generatedAt: string;
};
export type AgentSwingCanonicalSessionState = {
    version: 1;
    sessionId: string;
    sourceMessageCount: number;
    configSnapshot: AgentSwingConfig;
    messages: Msg[];
    updatedAt: string;
    messageCount: number;
    toolResultCount: number;
    originalPrompt?: string;
    cachedSummary?: AgentSwingSummaryCache;
    managedContext?: AgentSwingManagedContextMetadata;
    compactionCount: number;
};
export declare function loadCanonicalSessionState(sessionId: string): Promise<{
    path: string;
    needsRebuild: boolean;
    state?: AgentSwingCanonicalSessionState;
}>;
export declare function saveCanonicalSessionState(state: AgentSwingCanonicalSessionState): Promise<{
    path: string;
}>;
export declare function buildCanonicalSessionStatePath(sessionId: string): string;
export declare function createCanonicalSessionState(params: {
    sessionId: string;
    sourceMessageCount: number;
    configSnapshot: AgentSwingConfig;
    messages: Msg[];
    originalPrompt?: string;
    cachedSummary?: AgentSwingSummaryCache;
    managedContext?: AgentSwingManagedContextMetadata;
    compactionCount?: number;
}): AgentSwingCanonicalSessionState;
