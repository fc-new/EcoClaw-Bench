/**
 * AgentSwing Context Engine Plugin — Entry point.
 *
 * Implements Keep-Last-N and Summary context management strategies
 * from the AgentSwing paper as an OpenClaw context engine plugin.
 *
 * The module default-exports an OpenClawPluginDefinition object.
 * OpenClaw loads this via dynamic import and calls register(api).
 */
import type { OpenClawPluginDefinition } from "openclaw/plugin-sdk/plugin-entry";
declare const plugin: OpenClawPluginDefinition;
export default plugin;
