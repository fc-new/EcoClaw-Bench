/**
 * Minimal type stubs for openclaw plugin-sdk.
 * These are resolved at runtime by the OpenClaw gateway; we only need
 * enough type information to compile the plugin.
 *
 * Based on OpenClaw v2026.4.15 types.
 */

declare module "openclaw/plugin-sdk/plugin-entry" {
    /** Minimal message shape (AgentMessage from pi-agent-core). */
    export interface AgentMessage {
        role: string;
        content?: unknown;
        [key: string]: unknown;
    }

    export type ContextEngineInfo = {
        id: string;
        name: string;
        version?: string;
        ownsCompaction?: boolean;
        turnMaintenanceMode?: "foreground" | "background";
    };

    export type AssembleResult = {
        messages: AgentMessage[];
        estimatedTokens: number;
        systemPromptAddition?: string;
    };

    export type CompactResult = {
        ok: boolean;
        compacted: boolean;
        reason?: string;
        result?: {
            summary?: string;
            firstKeptEntryId?: string;
            tokensBefore: number;
            tokensAfter?: number;
            details?: unknown;
        };
    };

    export type IngestResult = { ingested: boolean };
    export type BootstrapResult = {
        bootstrapped: boolean;
        importedMessages?: number;
        reason?: string;
    };

    export type ContextEngineRuntimeContext = Record<string, unknown> & {
        allowDeferredCompactionExecution?: boolean;
        tokenBudget?: number;
        currentTokenCount?: number;
    };

    export interface ContextEngine {
        readonly info: ContextEngineInfo;

        bootstrap?(params: {
            sessionId: string;
            sessionKey?: string;
            sessionFile: string;
        }): Promise<BootstrapResult>;

        ingest(params: {
            sessionId: string;
            sessionKey?: string;
            message: AgentMessage;
            isHeartbeat?: boolean;
        }): Promise<IngestResult>;

        assemble(params: {
            sessionId: string;
            sessionKey?: string;
            messages: AgentMessage[];
            tokenBudget?: number;
            availableTools?: Set<string>;
            citationsMode?: string;
            model?: string;
            prompt?: string;
        }): Promise<AssembleResult>;

        compact(params: {
            sessionId: string;
            sessionKey?: string;
            sessionFile: string;
            tokenBudget?: number;
            force?: boolean;
            currentTokenCount?: number;
            compactionTarget?: "budget" | "threshold";
            customInstructions?: string;
            runtimeContext?: ContextEngineRuntimeContext;
        }): Promise<CompactResult>;

        afterTurn?(params: {
            sessionId: string;
            sessionKey?: string;
            sessionFile: string;
            messages: AgentMessage[];
            prePromptMessageCount: number;
            autoCompactionSummary?: string;
            isHeartbeat?: boolean;
            tokenBudget?: number;
            runtimeContext?: ContextEngineRuntimeContext;
        }): Promise<void>;

        dispose?(): Promise<void>;
    }

    export type ContextEngineFactory = () => ContextEngine | Promise<ContextEngine>;

    export interface PluginRuntime {
        modelAuth?: {
            resolveApiKeyForProvider: (params: {
                provider: string;
                cfg?: Record<string, unknown>;
            }) => Promise<{
                apiKey?: string;
                source?: string;
                mode?: string;
                profileId?: string;
            }>;
        };
        [key: string]: unknown;
    }

    /**
     * OpenClawPluginApi — the registration API injected into plugin modules.
     * Only the subset we need is typed here.
     */
    export interface OpenClawPluginApi {
        id: string;
        name: string;
        config?: Record<string, unknown>;
        pluginConfig?: Record<string, unknown>;
        runtime: PluginRuntime;
        registerContextEngine: (id: string, factory: ContextEngineFactory) => void;
        [key: string]: unknown;
    }

    /**
     * OpenClawPluginDefinition — module-level plugin definition.
     * The plugin module's default export must be this shape (or a function).
     */
    export interface OpenClawPluginDefinition {
        id?: string;
        name?: string;
        description?: string;
        version?: string;
        kind?: string | string[];
        configSchema?: unknown;
        register?: (api: OpenClawPluginApi) => void | Promise<void>;
        activate?: (api: OpenClawPluginApi) => void | Promise<void>;
    }
}

declare module "openclaw/plugin-sdk" {
    export type {
        AgentMessage,
        ContextEngine,
        ContextEngineFactory,
        PluginRuntime,
        OpenClawPluginApi,
        OpenClawPluginDefinition,
    } from "openclaw/plugin-sdk/plugin-entry";
}
