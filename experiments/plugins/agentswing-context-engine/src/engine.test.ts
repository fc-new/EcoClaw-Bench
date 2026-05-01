import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, test } from "node:test";
import {
    buildCanonicalSessionStatePath,
} from "./canonical-session-state.js";
import { AgentSwingEngine } from "./engine.js";
import type { Msg } from "./turn-parser.js";

let artifactDir = "";
let originalFetch: typeof globalThis.fetch | undefined;

beforeEach(() => {
    artifactDir = fs.mkdtempSync(path.join(os.tmpdir(), "agentswing-engine-"));
    process.env.OPENCLAW_AGENTSWING_ARTIFACT_DIR = artifactDir;
    originalFetch = globalThis.fetch;
});

afterEach(() => {
    if (originalFetch) {
        globalThis.fetch = originalFetch;
    } else {
        delete (globalThis as { fetch?: typeof globalThis.fetch }).fetch;
    }
    delete process.env.OPENCLAW_AGENTSWING_ARTIFACT_DIR;

    if (artifactDir) {
        fs.rmSync(artifactDir, { recursive: true, force: true });
        artifactDir = "";
    }
});

test("summary mode assembles context in AgentSwing (q, Sum) form and persists cached summary", async () => {
    let fetchCalls = 0;
    globalThis.fetch = (async (input, init) => {
        fetchCalls++;
        assert.equal(String(input), "http://summary-provider.test/v1/chat/completions");
        const body = JSON.parse(String(init?.body ?? "{}")) as {
            messages?: Array<{ role?: string; content?: string }>;
        };
        assert.equal(body.messages?.[0]?.role, "system");
        assert.match(String(body.messages?.[1]?.content ?? ""), /Original User Prompt/);
        const authHeader = new Headers(init?.headers).get("Authorization");
        assert.equal(authHeader, "Bearer runtime-summary-key");

        return new Response(
            JSON.stringify({
                choices: [{ message: { content: "Condensed exploration state." } }],
            }),
            {
                status: 200,
                headers: { "Content-Type": "application/json" },
            },
        );
    }) as typeof globalThis.fetch;

    const engine = new AgentSwingEngine({
        mode: "summary",
        triggerMode: "turn-count",
        triggerTurnCount: 1,
        summaryProvider: "summary-provider",
        summaryModel: "summary-model",
    }, {
        runtime: {
            modelAuth: {
                resolveApiKeyForProvider: async ({ provider }) => {
                    assert.equal(provider, "summary-provider");
                    return { apiKey: "runtime-summary-key" };
                },
            },
        },
        openclawConfig: {
            models: {
                providers: {
                    "summary-provider": {
                        baseUrl: "http://summary-provider.test/v1",
                    },
                },
            },
        },
    });

    const messages: Msg[] = [
        { role: "system", content: "You are OpenClaw." },
        { role: "user", content: "Investigate the regression in parser.ts." },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Start from the stack trace." },
                { type: "toolCall", name: "read", arguments: { path: "parser.ts" } },
            ],
        },
        {
            role: "toolResult",
            content: [{ type: "text", text: "Stack trace from parser.ts:42" }],
        },
        {
            role: "assistant",
            content: [{ type: "text", text: "The trace points at a stale state transition." }],
        },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Check the latest reducer branch." },
                { type: "toolCall", name: "read", arguments: { path: "reducer.ts" } },
            ],
        },
        {
            role: "toolResult",
            content: [{ type: "text", text: "Reducer keeps the old branch alive." }],
        },
    ];

    const result = await engine.assemble({
        sessionId: "summary-session",
        messages,
        tokenBudget: 4096,
    });

    assert.equal(fetchCalls, 1);
    assert.equal(result.messages.length, 2);
    assert.equal(result.messages[0].role, "system");
    assert.equal(result.messages[1].role, "user");
    const mergedPrompt = messageText(result.messages[1]);
    assert.match(mergedPrompt, /Investigate the regression in parser\.ts\./);
    assert.match(mergedPrompt, /Condensed exploration state\./);
    assert.match(String(result.systemPromptAddition ?? ""), /\(q, Sum\)/);

    const savedState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath("summary-session"), "utf8"),
    ) as {
        cachedSummary?: { summary?: string };
        sourceMessageCount?: number;
    };
    assert.equal(savedState.cachedSummary?.summary, "Condensed exploration state.");
    assert.equal(savedState.sourceMessageCount, messages.length);
});

test("compact imports transcript state from disk and a fresh engine can reuse the persisted canonical transcript", async () => {
    const sessionId = "compact-session";
    const sessionFile = path.join(artifactDir, "compact-session.jsonl");
    const messages: Msg[] = [
        { role: "user", content: "Find the bug and keep the latest branch only." },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Inspect parser." },
                { type: "toolCall", name: "read", arguments: { path: "parser.ts" } },
            ],
        },
        {
            role: "toolResult",
            content: [{ type: "text", text: "parser.ts keeps an outdated branch." }],
        },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Inspect reducer." },
                { type: "toolCall", name: "read", arguments: { path: "reducer.ts" } },
            ],
        },
        {
            role: "toolResult",
            content: [{ type: "text", text: "reducer.ts still references the stale branch." }],
        },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Inspect tests." },
                { type: "toolCall", name: "read", arguments: { path: "parser.test.ts" } },
            ],
        },
        {
            role: "toolResult",
            content: [{ type: "text", text: "Tests only cover the new branch path." }],
        },
    ];

    writeTranscript(sessionFile, messages);

    const compactEngine = new AgentSwingEngine({
        mode: "keep-last-n",
        keepLastN: 1,
        triggerMode: "turn-count",
        triggerTurnCount: 99,
    });

    const compactResult = await compactEngine.compact({
        sessionId,
        sessionFile,
        tokenBudget: 4096,
        currentTokenCount: 500,
        force: true,
    });

    assert.equal(compactResult.ok, true);
    assert.equal(compactResult.compacted, true);
    assert.ok((compactResult.result?.tokensAfter ?? 0) < 500);

    const savedState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath(sessionId), "utf8"),
    ) as {
        messageCount?: number;
        compactionCount?: number;
    };
    assert.equal(savedState.messageCount, messages.length);
    assert.equal(savedState.compactionCount, 1);

    const freshEngine = new AgentSwingEngine({
        mode: "keep-last-n",
        keepLastN: 1,
        triggerMode: "turn-count",
        triggerTurnCount: 1,
    });

    const assembled = await freshEngine.assemble({
        sessionId,
        messages: [],
        tokenBudget: 4096,
    });

    assert.equal(assembled.messages.length, 3);
    assert.equal(assembled.messages[0].role, "user");
    assert.match(messageText(assembled.messages[2]), /Tests only cover the new branch path\./);
});

test("keep-last-n assembles N real interaction turns from the persisted canonical transcript", async () => {
    const sessionId = "keep-last-n-cache-session";
    const sessionFile = path.join(artifactDir, "keep-last-n-cache-session.jsonl");
    const messages: Msg[] = [
        { role: "user", content: "Find the bug and preserve real tool trajectories." },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Inspect parser first." },
                { type: "toolCall", name: "read", arguments: { path: "parser.ts" } },
            ],
        },
        {
            role: "toolResult",
            content: [{ type: "text", text: "parser.ts contains an older false lead." }],
        },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Inspect reducer second." },
                { type: "toolCall", name: "read", arguments: { path: "reducer.ts" } },
            ],
        },
        {
            role: "toolResult",
            content: [{ type: "text", text: "reducer.ts contains the live failing branch." }],
        },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Inspect tests third." },
                { type: "toolCall", name: "read", arguments: { path: "parser.test.ts" } },
            ],
        },
        {
            role: "toolResult",
            content: [{ type: "text", text: "parser.test.ts proves the live failing branch." }],
        },
    ];

    writeTranscript(sessionFile, messages);

    const importEngine = new AgentSwingEngine({
        mode: "keep-last-n",
        keepLastN: 2,
        triggerMode: "turn-count",
        triggerTurnCount: 99,
    });
    await importEngine.compact({
        sessionId,
        sessionFile,
        tokenBudget: 4096,
        currentTokenCount: 1000,
        force: true,
    });

    const freshEngine = new AgentSwingEngine({
        mode: "keep-last-n",
        keepLastN: 2,
        triggerMode: "turn-count",
        triggerTurnCount: 1,
    });
    const assembled = await freshEngine.assemble({
        sessionId,
        messages: [],
        tokenBudget: 4096,
    });

    assert.deepEqual(
        assembled.messages.map((message) => message.role),
        ["user", "assistant", "toolResult", "assistant", "toolResult"],
    );
    const assembledJson = JSON.stringify(assembled.messages);
    assert.doesNotMatch(assembledJson, /Inspect parser first/);
    assert.doesNotMatch(assembledJson, /older false lead/);
    assert.match(assembledJson, /Inspect reducer second/);
    assert.match(assembledJson, /"toolCall"/);
    assert.match(assembledJson, /"path":"reducer\.ts"/);
    assert.match(assembledJson, /reducer\.ts contains the live failing branch/);
    assert.match(assembledJson, /Inspect tests third/);
    assert.match(assembledJson, /"path":"parser\.test\.ts"/);
    assert.match(assembledJson, /parser\.test\.ts proves the live failing branch/);

    const savedState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath(sessionId), "utf8"),
    ) as {
        messageCount?: number;
        toolResultCount?: number;
        managedContext?: {
            lastManagedSource?: string;
            lastManagedMode?: string;
            sourceTurnCount?: number;
            keptTurnCount?: number;
            droppedTurnCount?: number;
        };
    };
    assert.equal(savedState.messageCount, messages.length);
    assert.equal(savedState.toolResultCount, 3);
    assert.equal(savedState.managedContext?.lastManagedSource, "assemble");
    assert.equal(savedState.managedContext?.lastManagedMode, "keep-last-n");
    assert.equal(savedState.managedContext?.sourceTurnCount, 3);
    assert.equal(savedState.managedContext?.keptTurnCount, 2);
    assert.equal(savedState.managedContext?.droppedTurnCount, 1);

    const projectionEngine = new AgentSwingEngine({
        mode: "keep-last-n",
        keepLastN: 2,
        triggerMode: "turn-count",
        triggerTurnCount: 1,
    });
    const projected = await projectionEngine.assemble({
        sessionId,
        messages: assembled.messages,
        tokenBudget: 4096,
    });
    assert.deepEqual(projected.messages, assembled.messages);

    const projectedState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath(sessionId), "utf8"),
    ) as {
        messageCount?: number;
        toolResultCount?: number;
    };
    assert.equal(projectedState.messageCount, messages.length);
    assert.equal(projectedState.toolResultCount, 3);
});

test("keep-last-n ignores OpenClaw runtime metadata and keeps only model-visible turns", async () => {
    const messages = [
        { type: "session", id: "session-metadata" },
        { type: "model_change", provider: "kuaipao", modelId: "gpt-5-mini" },
        { role: "user", content: "Preserve only the visible conversation." },
        {
            role: "assistant",
            content: [
                { type: "thinking", thinking: "Inspect the first branch." },
                { type: "toolCall", name: "read", arguments: { path: "first.txt" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "first branch result" }] },
        {
            type: "custom",
            customType: "openclaw:bootstrap-context:full",
            data: { sessionId: "runtime-marker" },
        },
        {
            role: "assistant",
            content: [
                { type: "thinking", thinking: "Inspect the second branch." },
                { type: "toolCall", name: "read", arguments: { path: "second.txt" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "second branch result" }] },
    ] as Msg[];

    const engine = new AgentSwingEngine({
        mode: "keep-last-n",
        keepLastN: 1,
        triggerMode: "turn-count",
        triggerTurnCount: 1,
    });

    const assembled = await engine.assemble({
        sessionId: "metadata-filter-session",
        messages,
        tokenBudget: 4096,
    });

    assert.deepEqual(
        assembled.messages.map((message) => message.role),
        ["user", "assistant", "toolResult"],
    );
    const assembledJson = JSON.stringify(assembled.messages);
    assert.doesNotMatch(assembledJson, /session-metadata/);
    assert.doesNotMatch(assembledJson, /openclaw:bootstrap-context:full/);
    assert.doesNotMatch(assembledJson, /first branch result/);
    assert.match(assembledJson, /second branch result/);

    const savedState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath("metadata-filter-session"), "utf8"),
    ) as {
        messageCount?: number;
        toolResultCount?: number;
        managedContext?: {
            sourceTurnCount?: number;
            keptTurnCount?: number;
            droppedTurnCount?: number;
        };
    };
    assert.equal(savedState.messageCount, 5);
    assert.equal(savedState.toolResultCount, 2);
    assert.equal(savedState.managedContext?.sourceTurnCount, 2);
    assert.equal(savedState.managedContext?.keptTurnCount, 1);
    assert.equal(savedState.managedContext?.droppedTurnCount, 1);
});

test("token-ratio trigger stays inactive below threshold and applies keep-last-n above threshold", async () => {
    const messages: Msg[] = [
        { role: "user", content: "Track threshold behavior." },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "First turn." },
                { type: "toolCall", name: "read", arguments: { path: "first.txt" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "first result" }] },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Second turn." },
                { type: "toolCall", name: "read", arguments: { path: "second.txt" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "second result" }] },
    ];

    const belowThreshold = new AgentSwingEngine({
        mode: "keep-last-n",
        keepLastN: 1,
        triggerMode: "token-ratio",
        triggerRatio: 0.9,
        contextWindow: 100_000,
    });
    const passThrough = await belowThreshold.assemble({
        sessionId: "token-ratio-below",
        messages,
        tokenBudget: 100_000,
    });

    assert.equal(passThrough.messages.length, messages.length);
    assert.equal(passThrough.systemPromptAddition, undefined);
    const belowState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath("token-ratio-below"), "utf8"),
    ) as { managedContext?: unknown };
    assert.equal(belowState.managedContext, undefined);

    const aboveThreshold = new AgentSwingEngine({
        mode: "keep-last-n",
        keepLastN: 1,
        triggerMode: "token-ratio",
        triggerRatio: 0.01,
        contextWindow: 100,
    });
    const managed = await aboveThreshold.assemble({
        sessionId: "token-ratio-above",
        messages,
        tokenBudget: 100,
    });

    assert.deepEqual(
        managed.messages.map((message) => message.role),
        ["user", "assistant", "toolResult"],
    );
    const managedJson = JSON.stringify(managed.messages);
    assert.doesNotMatch(managedJson, /first result/);
    assert.match(managedJson, /second result/);
    const aboveState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath("token-ratio-above"), "utf8"),
    ) as {
        managedContext?: {
            lastManagedMode?: string;
            sourceTurnCount?: number;
            keptTurnCount?: number;
            droppedTurnCount?: number;
        };
    };
    assert.equal(aboveState.managedContext?.lastManagedMode, "keep-last-n");
    assert.equal(aboveState.managedContext?.sourceTurnCount, 2);
    assert.equal(aboveState.managedContext?.keptTurnCount, 1);
    assert.equal(aboveState.managedContext?.droppedTurnCount, 1);
});

test("summary mode can be triggered by token-ratio and records managed context metadata", async () => {
    let fetchCalls = 0;
    globalThis.fetch = (async (input, init) => {
        fetchCalls++;
        assert.equal(String(input), "http://summary-token.test/v1/chat/completions");
        const body = JSON.parse(String(init?.body ?? "{}")) as {
            messages?: Array<{ role?: string; content?: string }>;
        };
        assert.match(String(body.messages?.[1]?.content ?? ""), /Original User Prompt/);
        return new Response(
            JSON.stringify({
                choices: [{ message: { content: "Token-ratio summary state." } }],
            }),
            {
                status: 200,
                headers: { "Content-Type": "application/json" },
            },
        );
    }) as typeof globalThis.fetch;

    const messages: Msg[] = [
        { role: "system", content: "You are OpenClaw." },
        { role: "user", content: "Summarize this long investigation when threshold is crossed." },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Investigate the first branch." },
                { type: "toolCall", name: "read", arguments: { path: "first.md" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "first branch details" }] },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Investigate the second branch." },
                { type: "toolCall", name: "read", arguments: { path: "second.md" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "second branch details" }] },
    ];

    const engine = new AgentSwingEngine({
        mode: "summary",
        triggerMode: "token-ratio",
        triggerRatio: 0.01,
        contextWindow: 100,
        summaryApiBase: "http://summary-token.test/v1",
        summaryModel: "summary-token-model",
    });

    const result = await engine.assemble({
        sessionId: "summary-token-ratio",
        messages,
        tokenBudget: 100,
    });

    assert.equal(fetchCalls, 1);
    assert.equal(result.messages.length, 2);
    assert.match(messageText(result.messages[1]), /Token-ratio summary state\./);
    assert.match(String(result.systemPromptAddition ?? ""), /\(q, Sum\)/);

    const savedState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath("summary-token-ratio"), "utf8"),
    ) as {
        cachedSummary?: { summary?: string };
        managedContext?: {
            lastManagedMode?: string;
            sourceTurnCount?: number;
            keptTurnCount?: number;
            droppedTurnCount?: number;
        };
    };
    assert.equal(savedState.cachedSummary?.summary, "Token-ratio summary state.");
    assert.equal(savedState.managedContext?.lastManagedMode, "summary");
    assert.equal(savedState.managedContext?.sourceTurnCount, 2);
    assert.equal(savedState.managedContext?.keptTurnCount, 0);
    assert.equal(savedState.managedContext?.droppedTurnCount, 2);
});

test("summary managed projection does not overwrite the persisted canonical transcript", async () => {
    let fetchCalls = 0;
    globalThis.fetch = (async () => {
        fetchCalls++;
        return new Response(
            JSON.stringify({
                choices: [{ message: { content: `Compressed state ${fetchCalls}.` } }],
            }),
            {
                status: 200,
                headers: { "Content-Type": "application/json" },
            },
        );
    }) as typeof globalThis.fetch;

    const sessionId = "summary-projection-session";
    const originalMessages: Msg[] = [
        { role: "system", content: "You are OpenClaw." },
        { role: "user", content: "Investigate the project history." },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Read the first file." },
                { type: "toolCall", name: "read", arguments: { path: "first.md" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "first file contents" }] },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Read the second file." },
                { type: "toolCall", name: "read", arguments: { path: "second.md" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "second file contents" }] },
    ];

    const engine = new AgentSwingEngine({
        mode: "summary",
        triggerMode: "turn-count",
        triggerTurnCount: 1,
        summaryApiBase: "http://summary-projection.test/v1",
        summaryModel: "summary-model",
    });

    const summarized = await engine.assemble({
        sessionId,
        messages: originalMessages,
        tokenBudget: 4096,
    });

    assert.equal(summarized.messages.length, 2);
    assert.match(messageText(summarized.messages[1]), /Compressed state 1\./);

    const nextTurn: Msg[] = [
        { role: "user", content: "Now inspect the third file." },
        {
            role: "assistant",
            content: [
                { type: "thinking", text: "Read the third file." },
                { type: "toolCall", name: "read", arguments: { path: "third.md" } },
            ],
        },
        { role: "toolResult", content: [{ type: "text", text: "third file contents" }] },
    ];

    const freshEngine = new AgentSwingEngine({
        mode: "summary",
        triggerMode: "turn-count",
        triggerTurnCount: 1,
        summaryApiBase: "http://summary-projection.test/v1",
        summaryModel: "summary-model",
    });
    await freshEngine.assemble({
        sessionId,
        messages: [...summarized.messages, ...nextTurn],
        tokenBudget: 4096,
    });

    const savedState = JSON.parse(
        fs.readFileSync(buildCanonicalSessionStatePath(sessionId), "utf8"),
    ) as {
        messageCount?: number;
        toolResultCount?: number;
        originalPrompt?: string;
        messages?: Msg[];
        managedContext?: {
            lastManagedMode?: string;
            sourceTurnCount?: number;
            droppedTurnCount?: number;
        };
    };

    assert.equal(fetchCalls, 2);
    assert.equal(savedState.messageCount, originalMessages.length + nextTurn.length);
    assert.equal(savedState.toolResultCount, 3);
    assert.equal(savedState.originalPrompt, "Investigate the project history.");
    assert.doesNotMatch(String(savedState.originalPrompt), /Summarized Exploration State/);
    const savedJson = JSON.stringify(savedState.messages);
    assert.match(savedJson, /first file contents/);
    assert.match(savedJson, /second file contents/);
    assert.match(savedJson, /third file contents/);
    assert.doesNotMatch(savedJson, /Compressed state 1/);
    assert.equal(savedState.managedContext?.lastManagedMode, "summary");
    assert.equal(savedState.managedContext?.sourceTurnCount, 3);
    assert.equal(savedState.managedContext?.droppedTurnCount, 3);
});

function writeTranscript(sessionFile: string, messages: Msg[]): void {
    fs.mkdirSync(path.dirname(sessionFile), { recursive: true });
    fs.writeFileSync(
        sessionFile,
        messages
            .map((message) => JSON.stringify({ type: "message", message }))
            .join("\n"),
        "utf8",
    );
}

function messageText(message: Msg): string {
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
