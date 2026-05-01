import os from "node:os";
import path from "node:path";

export function resolveAgentSwingArtifactBaseDir(): string {
    const override =
        asTrimmedString(process.env.OPENCLAW_AGENTSWING_ARTIFACT_DIR) ??
        asTrimmedString(process.env.AGENTSWING_ARTIFACT_DIR);
    if (override) {
        return override;
    }

    const homeDir = os.homedir();
    if (homeDir) {
        return path.join(homeDir, ".openclaw", "artifacts", "agentswing-context-engine");
    }
    return path.join(os.tmpdir(), "openclaw", "artifacts", "agentswing-context-engine");
}

function asTrimmedString(value: unknown): string | undefined {
    if (typeof value !== "string") {
        return undefined;
    }
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
}
