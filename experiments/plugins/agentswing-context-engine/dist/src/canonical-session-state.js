import fs from "node:fs/promises";
import path from "node:path";
import { resolveAgentSwingArtifactBaseDir } from "./artifact-dir.js";
const CANONICAL_SESSION_STATE_VERSION = 1;
export async function loadCanonicalSessionState(sessionId) {
    const statePath = buildCanonicalSessionStatePath(sessionId);
    try {
        const raw = await fs.readFile(statePath, "utf8");
        const parsed = JSON.parse(raw);
        if (!isCanonicalSessionState(parsed) || parsed.sessionId !== sessionId) {
            return { path: statePath, needsRebuild: true };
        }
        return { path: statePath, needsRebuild: false, state: parsed };
    }
    catch (error) {
        const code = error.code;
        if (code === "ENOENT") {
            return { path: statePath, needsRebuild: true };
        }
        return { path: statePath, needsRebuild: true };
    }
}
export async function saveCanonicalSessionState(state) {
    const statePath = buildCanonicalSessionStatePath(state.sessionId);
    const directory = path.dirname(statePath);
    const tempPath = path.join(directory, `${path.basename(statePath, ".json")}.${process.pid}.${Date.now()}.tmp`);
    await fs.mkdir(directory, { recursive: true });
    await fs.writeFile(tempPath, JSON.stringify(state, null, 2), "utf8");
    await fs.rename(tempPath, statePath);
    return { path: statePath };
}
export function buildCanonicalSessionStatePath(sessionId) {
    return path.join(resolveAgentSwingArtifactBaseDir(), "session-state", `${sanitizeSessionId(sessionId)}.json`);
}
export function createCanonicalSessionState(params) {
    const messages = structuredClone(params.messages);
    return {
        version: CANONICAL_SESSION_STATE_VERSION,
        sessionId: params.sessionId,
        sourceMessageCount: params.sourceMessageCount,
        configSnapshot: structuredClone(params.configSnapshot),
        messages,
        updatedAt: new Date().toISOString(),
        messageCount: messages.length,
        toolResultCount: countToolResultMessages(messages),
        ...(typeof params.originalPrompt === "string"
            ? { originalPrompt: params.originalPrompt }
            : {}),
        ...(params.cachedSummary
            ? { cachedSummary: structuredClone(params.cachedSummary) }
            : {}),
        ...(params.managedContext
            ? { managedContext: structuredClone(params.managedContext) }
            : {}),
        compactionCount: params.compactionCount ?? 0,
    };
}
function sanitizeSessionId(value) {
    return value.replace(/[^a-zA-Z0-9._-]+/g, "_") || "session";
}
function isCanonicalSessionState(value) {
    if (!isRecord(value)) {
        return false;
    }
    return (value.version === CANONICAL_SESSION_STATE_VERSION &&
        typeof value.sessionId === "string" &&
        typeof value.sourceMessageCount === "number" &&
        Number.isInteger(value.sourceMessageCount) &&
        value.sourceMessageCount >= 0 &&
        isAgentSwingConfig(value.configSnapshot) &&
        Array.isArray(value.messages) &&
        value.messages.every(isMsg) &&
        typeof value.updatedAt === "string" &&
        typeof value.messageCount === "number" &&
        Number.isInteger(value.messageCount) &&
        value.messageCount >= 0 &&
        isOptionalNonNegativeInteger(value.toolResultCount) &&
        (value.originalPrompt === undefined || typeof value.originalPrompt === "string") &&
        (value.cachedSummary === undefined || isSummaryCache(value.cachedSummary)) &&
        (value.managedContext === undefined || isManagedContext(value.managedContext)) &&
        typeof value.compactionCount === "number" &&
        Number.isInteger(value.compactionCount) &&
        value.compactionCount >= 0);
}
function isAgentSwingConfig(value) {
    return (isRecord(value) &&
        (value.mode === "keep-last-n" || value.mode === "summary") &&
        (value.triggerMode === "token-ratio" || value.triggerMode === "turn-count") &&
        typeof value.triggerRatio === "number" &&
        value.triggerRatio > 0 &&
        value.triggerRatio < 1 &&
        typeof value.triggerTurnCount === "number" &&
        Number.isInteger(value.triggerTurnCount) &&
        value.triggerTurnCount >= 1 &&
        typeof value.keepLastN === "number" &&
        Number.isInteger(value.keepLastN) &&
        value.keepLastN >= 1 &&
        (value.contextWindow === null || typeof value.contextWindow === "number") &&
        (value.summaryProvider === null || typeof value.summaryProvider === "string") &&
        (value.summaryModel === null || typeof value.summaryModel === "string") &&
        (value.summaryApiBase === null || typeof value.summaryApiBase === "string"));
}
function isSummaryCache(value) {
    return (isRecord(value) &&
        typeof value.summary === "string" &&
        value.summary.length > 0 &&
        typeof value.sourceMessageCount === "number" &&
        Number.isInteger(value.sourceMessageCount) &&
        value.sourceMessageCount >= 0 &&
        typeof value.sourceTurnCount === "number" &&
        Number.isInteger(value.sourceTurnCount) &&
        value.sourceTurnCount >= 0 &&
        typeof value.generatedAt === "string" &&
        value.generatedAt.length > 0);
}
function isManagedContext(value) {
    return (isRecord(value) &&
        typeof value.lastManagedAt === "string" &&
        value.lastManagedAt.length > 0 &&
        (value.lastManagedSource === "assemble" || value.lastManagedSource === "compact") &&
        (value.lastManagedMode === "keep-last-n" || value.lastManagedMode === "summary") &&
        isNonNegativeInteger(value.sourceTurnCount) &&
        isNonNegativeInteger(value.keptTurnCount) &&
        isNonNegativeInteger(value.droppedTurnCount) &&
        isNonNegativeInteger(value.estimatedTokensBefore) &&
        isNonNegativeInteger(value.estimatedTokensAfter));
}
function countToolResultMessages(messages) {
    return messages.filter((message) => message.role === "toolResult").length;
}
function isNonNegativeInteger(value) {
    return typeof value === "number" && Number.isInteger(value) && value >= 0;
}
function isOptionalNonNegativeInteger(value) {
    return value === undefined || isNonNegativeInteger(value);
}
function isMsg(value) {
    return isRecord(value) && typeof value.role === "string";
}
function isRecord(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
}
