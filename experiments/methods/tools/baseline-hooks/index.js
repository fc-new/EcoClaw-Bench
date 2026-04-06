// @ts-nocheck
/**
 * EcoClaw Optimization Hooks — OpenClaw Plugin
 *
 * Reads ECOCLAW_ENABLE_* environment variables and registers the corresponding
 * OpenClaw lifecycle hooks. Each module is independently toggleable so that
 * PinchBench ablation runs can isolate the effect of each optimization.
 *
 * Environment variables (set to "1" to enable):
 *   ECOCLAW_ENABLE_PREFIX_CACHE — OpenAI-style prefix-based prompt caching (baseline method)
 *   ECOCLAW_ENABLE_CACHE        — prompt cache orchestration
 *   ECOCLAW_ENABLE_SUMMARY      — idle summarization & context rehydration
 *   ECOCLAW_ENABLE_COMPRESSION  — tool output compression
 *   ECOCLAW_ENABLE_RETRIEVAL    — retrieval hooks (QMD-style keyword search)
 *   ECOCLAW_ENABLE_ROUTER       — task-aware subagent routing
 *   ECOCLAW_ENABLE_QMD          — QMD full-text search retrieval (requires @tobilu/qmd)
 *   ECOCLAW_ENABLE_CCR          — LangChain ContextualCompressionRetriever
 *   ECOCLAW_ENABLE_LLMLINGUA    — LLMLingua-2 prompt compression (reduces tool output tokens)
 *   ECOCLAW_ENABLE_SELCTX       — Selective Context compression (self-information based)
 *   ECOCLAW_ENABLE_CONCISE      — Concise output mode (reduces output tokens via system prompt)
 *   ECOCLAW_ENABLE_SLIM_PROMPT  — Slim prompt mode (reduces input tokens by trimming system context)
 */

import { readFile, writeFile, mkdir, readdir } from "node:fs/promises";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

// ── Helpers ────────────���───────────────────────────────────────────────────

/**
 * @param {string} key
 * @returns {boolean}
 */
const env = (key) => process.env[key] === "1";

const STATE_DIR = process.env.ECOCLAW_STATE_DIR || join(
    process.env.HOME || "/tmp",
    ".ecoclaw-state",
);

/**
 * @param {string} text
 * @returns {string}
 */
function sha256(text) {
    return createHash("sha256").update(text).digest("hex");
}

/**
 * @param {string} dir
 * @returns {Promise<void>}
 */
async function ensureDir(dir) {
    await mkdir(dir, { recursive: true });
}

/**
 * @param {string} filePath
 * @returns {Promise<unknown>}
 */
async function readJson(filePath) {
    try {
        return JSON.parse(await readFile(filePath, "utf8"));
    } catch {
        return null;
    }
}

/**
 * @param {string} filePath
 * @param {unknown} value
 * @returns {Promise<void>}
 */
async function writeJson(filePath, value) {
    await ensureDir(join(filePath, ".."));
    await writeFile(filePath, JSON.stringify(value, null, 2));
}

// ── Compression helpers ─────────────────��──────────────────────────────────

const MAX_TOOL_CHARS = Number(process.env.ECOCLAW_MAX_TOOL_CHARS || "1200");

/**
 * @param {string} text
 * @param {number} max
 * @returns {string}
 */
function compressRule(text, max) {
    if (text.length <= max) return text;
    const head = text.slice(0, Math.floor(max * 0.55));
    const tail = text.slice(-Math.floor(max * 0.25));
    const highlights = text
        .split("\n")
        .map(/** @param {string} l */(l) => l.trim())
        .filter(
            /** @param {string} l */
            (l) =>
                l.length > 0 &&
                (/^[A-Z][A-Za-z0-9 _-]{1,40}:/.test(l) ||
                    /^\s*[-*]/.test(l) ||
                    /^\d+[).\s]/.test(l)),
        )
        .slice(0, 12)
        .join("\n");
    return [head, "...", highlights ? `[highlights]\n${highlights}` : "", "...", tail, "...[compressed:rule]"]
        .filter(Boolean)
        .join("\n");
}

// ── Retrieval helpers ───────────────────────────────────────────────────────

const RETRIEVAL_TOP_K = Number(process.env.ECOCLAW_RETRIEVAL_TOPK || "4");

/**
 * @param {string} query
 * @param {string} text
 * @returns {number}
 */
function keywordScore(query, text) {
    const tokens = new Set(query.toLowerCase().split(/\W+/).filter(Boolean));
    const lower = text.toLowerCase();
    let s = 0;
    for (const t of tokens) if (lower.includes(t)) s += 1;
    return s;
}

// ── QMD helpers ─────────────────────────────────────────────────────────────

const QMD_TOP_N = Number(process.env.ECOCLAW_QMD_TOPN || "3");
const QMD_MIN_SCORE = Number(process.env.ECOCLAW_QMD_MIN_SCORE || "0.3");
const QMD_COLLECTION = process.env.ECOCLAW_QMD_COLLECTION || "";

/**
 * Run `qmd search` and return parsed JSON results.
 * Falls back gracefully if qmd is not installed or returns no results.
 * @param {string} query
 * @param {number} topN
 * @param {number} minScore
 * @returns {Promise<Array<{docid: string, score: number, file: string, title: string, snippet: string, context: string}>>}
 */
const QMD_MODE = process.env.ECOCLAW_QMD_MODE || "search"; // "search" | "vsearch" | "query"

async function qmdSearch(query, topN = QMD_TOP_N, minScore = QMD_MIN_SCORE) {
    try {
        const mode = QMD_MODE;
        const args = [mode, query, "--json", "-n", String(topN), "--min-score", String(minScore)];
        if (QMD_COLLECTION) {
            args.push("-c", QMD_COLLECTION);
        }
        // Use HF mirror + much longer timeout for vsearch/query (first run loads GGUF models ~1-2min)
        const timeout = mode === "search" ? 10_000 : 300_000;
        const { stdout } = await execFileAsync("qmd", args, {
            timeout,
            env: { ...process.env, NO_COLOR: "1", HF_ENDPOINT: process.env.HF_ENDPOINT || "https://hf-mirror.com" },
        });
        const results = JSON.parse(stdout.trim() || "[]");
        return Array.isArray(results) ? results : [];
    } catch {
        return [];
    }
}

// ── CCR helpers ─────────────────────────────────────────────────────────────

const CCR_TOP_N = Number(process.env.ECOCLAW_CCR_TOPN || "3");
const CCR_SCRIPT = process.env.ECOCLAW_CCR_SCRIPT || join(
    process.env.HOME || "/tmp",
    "cdm_program/EcoClaw-Bench/experiments/methods/retrieval/ccr/ccr_search.py",  // retrieval/ccr — unchanged
);
const CCR_PYTHON = process.env.ECOCLAW_CCR_PYTHON || "python";

/**
 * Run `ccr_search.py search` and return parsed JSON results.
 * Falls back gracefully if the script or dependencies are not available.
 * @param {string} query
 * @param {number} topN
 * @returns {Promise<Array<{rank: number, content: string, source: string, score: number}>>}
 */
async function ccrSearch(query, topN = CCR_TOP_N) {
    try {
        // Use conda run to ensure correct Python environment with langchain deps
        const condaEnv = process.env.ECOCLAW_CCR_CONDA_ENV || "cdm_env";
        const { stdout } = await execFileAsync("conda", [
            "run", "-n", condaEnv, CCR_PYTHON, CCR_SCRIPT, "search", query, "-n", String(topN),
        ], {
            timeout: 30_000,
            env: { ...process.env, NO_COLOR: "1" },
        });
        const results = JSON.parse(stdout.trim() || "[]");
        return Array.isArray(results) ? results : [];
    } catch (err) {
        // Log but don't fail — CCR is optional
        return [];
    }
}

// ── LLMLingua helpers ───────────────────────────────────────────────────────

const LLMLINGUA_SCRIPT = process.env.ECOCLAW_LLMLINGUA_SCRIPT || join(
    process.env.HOME || "/tmp",
    "cdm_program/EcoClaw-Bench/experiments/methods/static_compression/llmlingua/llmlingua_compress.py",
);
const LLMLINGUA_RATE = process.env.ECOCLAW_LLMLINGUA_RATE || "0.5";
const LLMLINGUA_MIN_LENGTH = Number(process.env.ECOCLAW_LLMLINGUA_MIN_LENGTH || "200");

/**
 * Compress text using LLMLingua-2 via Python subprocess.
 * Returns compressed text, or original text if compression fails.
 * @param {string} text
 * @returns {Promise<string>}
 */
async function llmlinguaCompress(text) {
    if (text.length < LLMLINGUA_MIN_LENGTH) return text;
    try {
        const condaEnv = process.env.ECOCLAW_LLMLINGUA_CONDA_ENV || "cdm_env";
        const { stdout } = await execFileAsync("conda", [
            "run", "-n", condaEnv, "python", LLMLINGUA_SCRIPT,
            "--rate", LLMLINGUA_RATE, text,
        ], {
            timeout: 30_000,
            env: { ...process.env, NO_COLOR: "1" },
        });
        return stdout || text;
    } catch {
        return text;
    }
}

// ── Selective Context helpers ───────────────────────────────────────────────

const SELCTX_SCRIPT = process.env.ECOCLAW_SELCTX_SCRIPT || join(
    process.env.HOME || "/tmp",
    "cdm_program/EcoClaw-Bench/experiments/methods/static_compression/selective-context/selective_context.py",
);
const SELCTX_RATIO = process.env.ECOCLAW_SELCTX_RATIO || "0.4";
const SELCTX_UNIT = process.env.ECOCLAW_SELCTX_UNIT || "sentence"; // "sentence" | "phrase" | "token"
const SELCTX_MIN_LENGTH = Number(process.env.ECOCLAW_SELCTX_MIN_LENGTH || "200");

/**
 * Compress text using Selective Context via Python subprocess.
 * @param {string} text
 * @returns {Promise<string>}
 */
async function selectiveContextCompress(text) {
    if (text.length < SELCTX_MIN_LENGTH) return text;
    try {
        const condaEnv = process.env.ECOCLAW_SELCTX_CONDA_ENV || "cdm_env";
        const { stdout } = await execFileAsync("conda", [
            "run", "-n", condaEnv, "python", SELCTX_SCRIPT,
            "--ratio", SELCTX_RATIO, "--unit", SELCTX_UNIT, text,
        ], {
            timeout: 30_000,
            env: { ...process.env, NO_COLOR: "1", HF_ENDPOINT: process.env.HF_ENDPOINT || "https://hf-mirror.com" },
        });
        return stdout || text;
    } catch {
        return text;
    }
}

// ── Prefix Cache helpers (OpenAI-style baseline) ────────────────────────────

/**
 * Generate a fixed padding block for OpenAI prompt caching.
 * The block is deterministic and ≥1024 tokens to trigger automatic caching.
 * @returns {string}
 */
function generatePrefixPadding() {
    const block = [
        "[SYSTEM CONTEXT — STABLE PREFIX FOR PROMPT CACHING]",
        "",
        "This section enables OpenAI's automatic prompt caching mechanism.",
        "By maintaining a consistent prefix of at least 1024 tokens,",
        "subsequent agent turns benefit from cached prompt tokens.",
        "",
        "Key principles for agent operation:",
        "1. Be helpful, harmless, and honest in all interactions",
        "2. Decompose complex tasks into manageable steps",
        "3. Verify facts before presenting them as truth",
        "4. Ask clarifying questions when task intent is ambiguous",
        "5. Explain your reasoning and decision-making process",
        "6. Respect user privacy and security constraints",
        "7. Acknowledge limitations and uncertainties",
        "8. Provide actionable recommendations when appropriate",
        "9. Document assumptions made during task execution",
        "10. Adapt to feedback and course-correct as needed",
        "",
        "Decision-making framework:",
        "- For research tasks: prioritize accuracy and source verification",
        "- For creative tasks: prioritize originality and user intent alignment",
        "- For technical tasks: prioritize correctness and safety",
        "- For analytical tasks: prioritize clarity and logical consistency",
        "- For writing tasks: prioritize coherence and readability",
        "",
        "Tool usage patterns:",
        "- Check tool availability before attempting to use them",
        "- Provide context about what each tool call accomplishes",
        "- Handle errors gracefully with informative fallbacks",
        "- Chain tool results logically to build toward task completion",
        "- Verify tool outputs match expected formats",
        "",
        "Communication standards:",
        "- Use clear, professional language appropriate to context",
        "- Break down complex information into understandable parts",
        "- Provide examples when explaining abstract concepts",
        "- Summarize key findings at appropriate intervals",
        "- Maintain consistent formatting for structured data",
        "- Use markdown formatting for readability where applicable",
        "",
        "Memory and context management:",
        "- Maintain awareness of conversation history",
        "- Reference previous context when relevant",
        "- Build incrementally on established information",
        "- Acknowledge when information from prior turns is being reused",
        "- Flag significant context transitions explicitly",
        "",
        "Error handling and recovery:",
        "- Acknowledge errors and explain what went wrong",
        "- Suggest alternative approaches when initial attempts fail",
        "- Learn from failures and adapt subsequent attempts",
        "- Maintain operation even with partial failures",
        "- Escalate appropriately when resolution is not possible",
        "",
        "Performance considerations:",
        "- Prioritize efficiency without sacrificing quality",
        "- Batch related operations when possible",
        "- Avoid redundant processing of information",
        "- Cache important findings for rapid reference",
        "- Consider computational limits of tools",
        "",
        "Quality assurance:",
        "- Double-check critical information before delivery",
        "- Validate outputs against stated requirements",
        "- Ensure consistency across multiple related items",
        "- Test edge cases in complex solutions",
        "- Document any deviations from standard procedures",
    ].join("\n");
    // Repeat to ensure ≥1024 tokens (~4000 chars)
    return (block + "\n\n" + block).slice(0, 4500);
}

// ── Router helpers ─────────────────────────────────────────────────────────

const SMALL_MODEL = process.env.ECOCLAW_SMALL_MODEL || "gpt-4o-mini";
const SMALL_BUDGET = Number(process.env.ECOCLAW_SMALL_TASK_TOKEN_BUDGET || "2000");

// ── Plugin definition ──────────────────────────────────────────────────────

/** @type {import("openclaw/plugin-sdk").OpenClawPluginDefinition} */
const plugin = {
    id: "ecoclaw-hooks",
    name: "EcoClaw Optimization Hooks",
    version: "0.1.0",

    /**
     * @param {import("openclaw/plugin-sdk").OpenClawPluginApi} api
     * @returns {Promise<void>}
     */
    async register(api) {
        const flags = {
            prefixCache: env("ECOCLAW_ENABLE_PREFIX_CACHE"),
            cache: env("ECOCLAW_ENABLE_CACHE"),
            summary: env("ECOCLAW_ENABLE_SUMMARY"),
            compression: env("ECOCLAW_ENABLE_COMPRESSION"),
            retrieval: env("ECOCLAW_ENABLE_RETRIEVAL"),
            router: env("ECOCLAW_ENABLE_ROUTER"),
            qmd: env("ECOCLAW_ENABLE_QMD"),
            ccr: env("ECOCLAW_ENABLE_CCR"),
            llmlingua: env("ECOCLAW_ENABLE_LLMLINGUA"),
            selctx: env("ECOCLAW_ENABLE_SELCTX"),
            concise: env("ECOCLAW_ENABLE_CONCISE"),
            slimPrompt: env("ECOCLAW_ENABLE_SLIM_PROMPT"),
        };

        const active = Object.entries(flags)
            .filter(([, v]) => v)
            .map(([k]) => k);

        if (active.length === 0) {
            api.logger.info("[ecoclaw] All modules disabled — running as baseline.");
        } else {
            api.logger.info(`[ecoclaw] Active modules: ${active.join(", ")}`);
        }

        const summaryDir = join(STATE_DIR, "summaries");
        const cacheDir = join(STATE_DIR, "cache");
        const usageDir = join(STATE_DIR, "usage");
        const prefixPadding = generatePrefixPadding();

        // ── Usage Collection (runs always, regardless of module flags) ──────────
        // Capture LLM usage data from the provider to work around cases where
        // OpenClaw's transcript recording shows zeros due to provider integration issues.
        //
        // Supports:
        // - OpenAI format: usage.prompt_tokens, usage.completion_tokens, usage.total_tokens
        // - MiniMax (兼容 OpenAI 格式): same as OpenAI
        // - Anthropic format: usage_metadata with input_tokens, output_tokens

        api.on("llm_output", async (event) => {
            api.logger.debug("[ecoclaw] llm_output event: provider=%s eventKeys=%s",
                event.provider, Object.keys(event).join(","));

            // Try to extract usage data (compatible with multiple formats)
            let extractedUsage = null;

            if (event.usage) {
                extractedUsage = _extractUsageFromEvent(event, api.logger);
            }

            if (!extractedUsage || extractedUsage.total === 0) {
                api.logger.debug("[ecoclaw] No valid usage data extracted from event");
                return;
            }

            try {
                await ensureDir(usageDir);
                const filename = `usage_${event.runId || event.sessionId || Date.now()}.json`;
                await writeJson(join(usageDir, filename), {
                    runId: event.runId,
                    sessionId: event.sessionId,
                    provider: event.provider,
                    model: event.model,
                    ...extractedUsage,
                    ts: new Date().toISOString(),
                });
                api.logger.info(
                    "[ecoclaw] Captured usage: provider=%s input=%d output=%d total=%d",
                    event.provider,
                    extractedUsage.input || 0,
                    extractedUsage.output || 0,
                    extractedUsage.total || 0
                );
            } catch (e) {
                api.logger.warn("Failed to save usage data: %s", e.message);
            }
        });

        /**
         * Extract usage data from llm_output event, supporting multiple formats
         * @param {any} event
         * @param {any} logger
         * @returns {{input: number, output: number, cacheRead: number, cacheWrite: number, total: number, cost: any} | null}
         */
        function _extractUsageFromEvent(event, logger) {
            if (!event.usage) return null;

            const usage = event.usage;

            // OpenAI / MiniMax compatible format (兼容 OpenAI 格式)
            // MiniMax API 返回: prompt_tokens, completion_tokens, total_tokens
            const input = usage.prompt_tokens || usage.input_tokens || 0;
            const output = usage.completion_tokens || usage.output_tokens || 0;
            const total = usage.total_tokens || (input + output) || 0;

            // MiniMax might also use these field names
            const cacheRead = usage.cache_read_tokens || usage.cacheRead || 0;
            const cacheWrite = usage.cache_write_tokens || usage.cacheWrite || 0;

            if (total === 0) {
                logger.debug("[ecoclaw] Extracted usage is zero: input=%d output=%d", input, output);
                return null;
            }

            return {
                input,
                output,
                cacheRead,
                cacheWrite,
                total,
                cost: usage.cost || { total: 0 },
            };
        }

        // ── 0. OpenAI-style prefix caching (baseline method) ──────────────────
        if (flags.prefixCache) {
            api.on("before_prompt_build", (event, ctx) => {
                // Inject a fixed, stable padding block before the system prompt.
                // This enables OpenAI's automatic prompt caching when the prefix
                // is ≥1024 tokens and identical across agent turns.
                return {
                    prependSystemContext: prefixPadding,
                };
            }, { priority: 100 }); // Highest priority — prepend first
        }

        // ── 1. Prompt cache orchestration ────────────────────────────────────
        if (flags.cache) {
            api.on("before_prompt_build", async (event, ctx) => {
                // Tag stable system prompt content for provider-level caching.
                // We hash the system prompt so the provider can detect prefix stability.
                const systemText = event.messages
                    .filter((m) => /** @type {any} */(m).role === "system")
                    .map((m) => /** @type {any} */(m).content || "")
                    .join("\n");

                if (systemText.length < 500) return;

                const prefixHash = sha256(systemText);
                await ensureDir(cacheDir);
                await writeJson(join(cacheDir, `${prefixHash}.json`), {
                    prefixHash,
                    sessionId: ctx.sessionId,
                    updatedAt: new Date().toISOString(),
                });

                // Use prependSystemContext to keep stable prefix for provider caching
                return {
                    prependSystemContext: `[cache-hint:${prefixHash.slice(0, 12)}]`,
                };
            });

        }

        // ── 2. Idle summarization & context rehydration ──────────────────────
        if (flags.summary) {
            // Rehydrate: inject previous session summary into prompt context
            api.on("before_prompt_build", async (event, ctx) => {
                const sid = ctx.sessionId || ctx.sessionKey || "default";
                const saved = await readJson(join(summaryDir, `${sid}.json`));
                if (!saved?.summary) return;

                return {
                    prependContext: `[Session summary from previous context]\n${saved.summary}`,
                };
            }, { priority: 10 }); // Run early so other hooks see the context

            // Persist: save a summary after each agent run
            api.on("agent_end", async (event, ctx) => {
                if (!event.success) return;

                const sid = ctx.sessionId || ctx.sessionKey || "default";
                const assistantTexts = event.messages
                    .filter((m) => /** @type {any} */(m).role === "assistant")
                    .map((m) => /** @type {any} */(m).content || "")
                    .slice(-3);

                if (assistantTexts.length === 0) return;

                const summary = assistantTexts
                    .join("\n")
                    .replace(/\s+/g, " ")
                    .trim()
                    .slice(0, 800);

                await ensureDir(summaryDir);
                await writeJson(join(summaryDir, `${sid}.json`), {
                    sessionId: sid,
                    summary,
                    updatedAt: new Date().toISOString(),
                });
            });
        }

        // ── 3. Tool output compression ───────────���───────────────────────────
        if (flags.compression) {
            api.on("tool_result_persist", (event) => {
                const msg = event.message;
                if (!msg) return;

                const content = /** @type {any} */ (msg).content;
                if (typeof content !== "string" || content.length <= MAX_TOOL_CHARS) return;

                const compressed = compressRule(content, MAX_TOOL_CHARS);
                return {
                    message: { ...msg, content: compressed },
                };
            });
        }

        // ── 4. Retrieval hooks (QMD-style keyword search) ────────────────────
        if (flags.retrieval) {
            api.on("before_prompt_build", async (event) => {
                /** @type {Array<{id: string, text: string}>} */
                let docs = [];
                try {
                    const files = await readdir(summaryDir);
                    for (const f of files.filter((x) => x.endsWith(".json"))) {
                        const raw = await readJson(join(summaryDir, f));
                        if (raw?.summary) docs.push({ id: raw.sessionId || f, text: raw.summary });
                    }
                } catch {
                    // No summaries yet
                }

                if (docs.length === 0) return;

                const ranked = docs
                    .map((d) => ({ ...d, score: keywordScore(event.prompt, d.text) }))
                    .filter((d) => d.score > 0)
                    .sort((a, b) => b.score - a.score)
                    .slice(0, RETRIEVAL_TOP_K);

                if (ranked.length === 0) return;

                const context = ranked
                    .map((d) => `[Retrieved memory: ${d.id}]\n${d.text}`)
                    .join("\n\n");

                return { prependContext: context };
            }, { priority: 5 }); // Run before summary rehydration
        }

        // ── 5. QMD full-text search retrieval ──────────────────────────────────
        if (flags.qmd) {
            api.on("before_prompt_build", async (event) => {
                const prompt = event.prompt || "";
                if (prompt.length < 10) return;

                const results = await qmdSearch(prompt);
                if (results.length === 0) return;

                const context = results
                    .map((r) => {
                        const parts = [`[QMD Result: ${r.file || r.docid} (score: ${(r.score * 100).toFixed(0)}%)]`];
                        if (r.title) parts.push(`Title: ${r.title}`);
                        if (r.context) parts.push(`Context: ${r.context}`);
                        if (r.snippet) parts.push(r.snippet);
                        return parts.join("\n");
                    })
                    .join("\n\n");

                api.logger.info(
                    "[ecoclaw] QMD retrieved %d results for prompt (top score: %s%%)",
                    results.length,
                    results[0] ? (results[0].score * 100).toFixed(0) : "0",
                );

                return {
                    prependContext: `[QMD Knowledge Base Results — use these to inform your approach]\n\n${context}`,
                };
            }, { priority: 3 }); // Run before other retrieval hooks
        }

        // ── 6. LangChain ContextualCompressionRetriever ────────────────────────
        if (flags.ccr) {
            api.on("before_prompt_build", async (event) => {
                const prompt = event.prompt || "";
                if (prompt.length < 10) return;

                const results = await ccrSearch(prompt);
                if (results.length === 0) return;

                const context = results
                    .map((r) => {
                        const parts = [`[CCR Result #${r.rank} from ${r.source || "unknown"}]`];
                        parts.push(r.content);
                        return parts.join("\n");
                    })
                    .join("\n\n");

                api.logger.info(
                    "[ecoclaw] CCR retrieved %d compressed results for prompt",
                    results.length,
                );

                return {
                    prependContext: `[Contextual Compression Results — relevant extracted content]\n\n${context}`,
                };
            }, { priority: 2 }); // Lower priority than QMD
        }

        // ── 7. LLMLingua-2 tool output compression ────────────────────────────
        if (flags.llmlingua) {
            api.on("tool_result_persist", async (event) => {
                const msg = event.message;
                if (!msg) return;

                const content = /** @type {any} */ (msg).content;
                if (typeof content !== "string" || content.length < LLMLINGUA_MIN_LENGTH) return;

                const compressed = await llmlinguaCompress(content);
                if (compressed !== content && compressed.length < content.length) {
                    api.logger.info(
                        "[ecoclaw] LLMLingua compressed tool output: %d → %d chars (%.0f%% reduction)",
                        content.length,
                        compressed.length,
                        (1 - compressed.length / content.length) * 100,
                    );
                    return {
                        message: { ...msg, content: compressed },
                    };
                }
            });
        }

        // ── 8. Selective Context tool output compression ──────────────────────
        if (flags.selctx) {
            api.on("tool_result_persist", async (event) => {
                const msg = event.message;
                if (!msg) return;

                const content = /** @type {any} */ (msg).content;
                if (typeof content !== "string" || content.length < SELCTX_MIN_LENGTH) return;

                const compressed = await selectiveContextCompress(content);
                if (compressed !== content && compressed.length < content.length) {
                    api.logger.info(
                        "[ecoclaw] SelectiveContext compressed tool output: %d → %d chars (%.0f%% reduction)",
                        content.length,
                        compressed.length,
                        (1 - compressed.length / content.length) * 100,
                    );
                    return {
                        message: { ...msg, content: compressed },
                    };
                }
            });
        }

        // ── 9. Concise output mode ─────────────────────────────────────────────
        if (flags.concise) {
            api.on("before_prompt_build", (event) => {
                return {
                    appendSystemContext: [
                        "",
                        "IMPORTANT: Be extremely concise in all responses.",
                        "- Use the fewest words possible while preserving accuracy.",
                        "- Do NOT explain your reasoning unless explicitly asked.",
                        "- Do NOT repeat the user's request back to them.",
                        "- Do NOT add pleasantries, greetings, or sign-offs.",
                        "- When writing files, write ONLY the required content.",
                        "- When answering questions, give ONLY the direct answer.",
                        "- Prefer single tool calls over multiple when possible.",
                        "- Skip confirmation messages — just do the task.",
                    ].join("\n"),
                };
            }, { priority: 90 });
        }

        // ── 10. Slim prompt mode ───────────────────────────────────────────────
        if (flags.slimPrompt) {
            // Compress tool result content more aggressively (lower threshold)
            api.on("tool_result_persist", (event) => {
                const msg = event.message;
                if (!msg) return;
                const content = /** @type {any} */ (msg).content;
                if (typeof content !== "string" || content.length <= 300) return;
                // Aggressive truncation: keep first 200 chars + last 100 chars
                const compressed = content.slice(0, 200) + "\n...[truncated]...\n" + content.slice(-100);
                return { message: { ...msg, content: compressed } };
            });

            // Also inject a directive to minimize tool usage
            api.on("before_prompt_build", (event) => {
                return {
                    appendSystemContext: [
                        "",
                        "EFFICIENCY DIRECTIVE: Minimize API calls and tool usage.",
                        "- Read multiple files in a single tool call when possible.",
                        "- Batch related operations together.",
                        "- Avoid re-reading files you have already read.",
                        "- Do not list directories before reading known files.",
                    ].join("\n"),
                };
            }, { priority: 85 });
        }

        // ── 11. Task-aware subagent routing ─────────────────────────────────────
        if (flags.router) {
            api.on("before_model_resolve", (event) => {
                const prompt = (event.prompt || "").toLowerCase();
                const simple =
                    prompt.length < 400 &&
                    !/(analy|compare|plan|research|tool|code|pdf|spreadsheet)/.test(prompt);

                if (simple) {
                    return {
                        modelOverride: SMALL_MODEL,
                    };
                }
            });
        }
    },
};

export default plugin;
