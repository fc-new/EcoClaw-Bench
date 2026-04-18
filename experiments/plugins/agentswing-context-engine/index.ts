/**
 * AgentSwing Context Engine Plugin — Entry point.
 *
 * Implements Keep-Last-N and Summary context management strategies
 * from the AgentSwing paper as an OpenClaw context engine plugin.
 *
 * The module default-exports an OpenClawPluginDefinition object.
 * OpenClaw loads this via dynamic import and calls register(api).
 */

import type { OpenClawPluginDefinition, OpenClawPluginApi } from "openclaw/plugin-sdk/plugin-entry";
import { AgentSwingEngine } from "./src/engine.js";

/**
 * Read plugin configuration from environment variables.
 * This is the primary config channel since shell scripts export these
 * before starting the gateway.
 *
 * Environment variables:
 *   AGENTSWING_MODE              — "keep-last-n" | "summary"
 *   AGENTSWING_TRIGGER_MODE      — "token-ratio" | "turn-count" (default: "token-ratio")
 *   AGENTSWING_TRIGGER_RATIO     — float (default: 0.4)
 *   AGENTSWING_TRIGGER_TURN_COUNT — integer (default: 10)
 *   AGENTSWING_KEEP_LAST_N       — integer (default: 5)
 *   AGENTSWING_CONTEXT_WINDOW    — integer (optional)
 *   AGENTSWING_SUMMARY_API_BASE  — LLM API base URL (for summary mode)
 *   AGENTSWING_SUMMARY_API_KEY   — LLM API key (for summary mode)
 *   AGENTSWING_SUMMARY_MODEL     — model ID for summarization
 */
function readConfigFromEnv(): Record<string, unknown> {
    const config: Record<string, unknown> = {};

    if (process.env.AGENTSWING_MODE) {
        config.mode = process.env.AGENTSWING_MODE;
    }
    if (process.env.AGENTSWING_TRIGGER_MODE) {
        config.triggerMode = process.env.AGENTSWING_TRIGGER_MODE;
    }
    if (process.env.AGENTSWING_TRIGGER_RATIO) {
        config.triggerRatio = parseFloat(process.env.AGENTSWING_TRIGGER_RATIO);
    }
    if (process.env.AGENTSWING_TRIGGER_TURN_COUNT) {
        config.triggerTurnCount = parseInt(process.env.AGENTSWING_TRIGGER_TURN_COUNT, 10);
    }
    if (process.env.AGENTSWING_KEEP_LAST_N) {
        config.keepLastN = parseInt(process.env.AGENTSWING_KEEP_LAST_N, 10);
    }
    if (process.env.AGENTSWING_CONTEXT_WINDOW) {
        config.contextWindow = parseInt(process.env.AGENTSWING_CONTEXT_WINDOW, 10);
    }

    return config;
}

const plugin: OpenClawPluginDefinition = {
    id: "agentswing-context-engine",
    name: "AgentSwing Context Engine",
    description:
        "Keep-Last-N and Summary context management strategies from the AgentSwing paper",
    kind: "context-engine",

    register(api: OpenClawPluginApi) {
        // Merge plugin config from openclaw.json with env overrides
        const envConfig = readConfigFromEnv();
        const pluginCfg = { ...(api.pluginConfig ?? {}), ...envConfig };

        api.registerContextEngine("agentswing-context-engine", () => {
            return new AgentSwingEngine(pluginCfg);
        });
    },
};

export default plugin;
