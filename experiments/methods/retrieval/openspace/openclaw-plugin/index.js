// @ts-nocheck
/**
 * OpenSpace Tools — OpenClaw Plugin
 *
 * Proxies OpenSpace's 4 MCP tools into OpenClaw via the plugin API.
 * Parameter schemas match the actual openspace-mcp tool signatures exactly
 * so that the host skills (delegate-task/skill-discovery SKILL.md) can guide
 * the agent to call these tools with the correct parameter names.
 *
 * Requires openspace-mcp running as a streamable-http server:
 *   openspace-mcp --transport streamable-http --host 127.0.0.1 --port 8081
 *
 * Config (plugins.entries.openspace-tools.config in openclaw.json):
 *   baseUrl  — openspace-mcp HTTP base URL (default: http://127.0.0.1:8081)
 *   timeout  — per-call timeout in seconds (default: 600)
 */

const PLUGIN_ID = "openspace-tools";

function getConfig(api) {
  const cfg = api?.getConfig?.() ?? {};
  return {
    baseUrl: (cfg.baseUrl ?? "http://127.0.0.1:8081").replace(/\/$/, ""),
    timeout: Number(cfg.timeout ?? 600),
  };
}

function createAbortSignal(timeoutSeconds) {
  return AbortSignal.timeout(timeoutSeconds * 1000);
}

// ── SSE / JSON response parser ───────────────────────────────────────────────
// MCP Streamable HTTP allows the server to respond with either plain JSON
// (Content-Type: application/json) or an SSE stream (Content-Type: text/event-stream).
// This helper handles both and returns the first JSON-RPC object from either format.
async function parseMcpResponse(resp) {
  const ct = resp.headers.get("content-type") ?? "";
  const text = await resp.text();
  if (ct.includes("text/event-stream")) {
    // Parse SSE: each event is "data: <json>\n\n"; take the first data line.
    for (const line of text.split("\n")) {
      const trimmed = line.trim();
      if (trimmed.startsWith("data:")) {
        const payload = trimmed.slice(5).trim();
        if (payload && payload !== "[DONE]") {
          return JSON.parse(payload);
        }
      }
    }
    throw new Error(`No data line found in SSE response: ${text.slice(0, 200)}`);
  }
  return JSON.parse(text);
}

// ── MCP session management ──────────────────────────────────────────────────

function getMcpState(api) {
  if (!api.__openspaceMcpState) {
    api.__openspaceMcpState = {};
  }
  return api.__openspaceMcpState;
}

async function ensureMcpInitialized(api, cfg) {
  const state = getMcpState(api);
  if (state.sessionId) {
    return state.sessionId;
  }

  const initResp = await fetch(`${cfg.baseUrl}/mcp`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json, text/event-stream",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: "init",
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: PLUGIN_ID, version: "1.0.0" },
      },
    }),
    signal: createAbortSignal(cfg.timeout),
  });

  if (!initResp.ok) {
    const body = await initResp.text();
    throw new Error(`[${PLUGIN_ID}] MCP initialize failed: HTTP ${initResp.status} ${body}`.trim());
  }

  await parseMcpResponse(initResp);

  const sessionId =
    initResp.headers.get("Mcp-Session-Id") ??
    initResp.headers.get("mcp-session-id");
  if (!sessionId) {
    throw new Error(`[${PLUGIN_ID}] MCP initialize did not return Mcp-Session-Id`);
  }

  // Send initialized notification
  const confirmResp = await fetch(`${cfg.baseUrl}/mcp`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json, text/event-stream",
      "Mcp-Session-Id": sessionId,
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "notifications/initialized",
      params: {},
    }),
    signal: createAbortSignal(cfg.timeout),
  });

  if (!confirmResp.ok) {
    const body = await confirmResp.text();
    throw new Error(
      `[${PLUGIN_ID}] MCP initialization confirmation failed: HTTP ${confirmResp.status} ${body}`.trim()
    );
  }

  state.sessionId = sessionId;
  api?.logger?.info?.(`[${PLUGIN_ID}] MCP session initialized: ${sessionId}`);
  return sessionId;
}

// ── Tool call helper ────────────────────────────────────────────────────────

async function callOpenSpaceTool(api, toolName, args) {
  const cfg = getConfig(api);
  let sessionId;
  try {
    sessionId = await ensureMcpInitialized(api, cfg);
  } catch (err) {
    return {
      content: [{ type: "text", text: `OpenSpace MCP not reachable: ${err.message}` }],
      isError: true,
    };
  }

  const resp = await fetch(`${cfg.baseUrl}/mcp`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json, text/event-stream",
      "Mcp-Session-Id": sessionId,
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: `${toolName}-${Date.now()}`,
      method: "tools/call",
      params: { name: toolName, arguments: args },
    }),
    signal: createAbortSignal(cfg.timeout),
  });

  if (!resp.ok) {
    const body = await resp.text();
    return {
      content: [{ type: "text", text: `OpenSpace tool call failed: HTTP ${resp.status} ${body}` }],
      isError: true,
    };
  }

  const data = await parseMcpResponse(resp);

  // JSON-RPC error
  if (data.error) {
    return {
      content: [{ type: "text", text: `OpenSpace error: ${JSON.stringify(data.error)}` }],
      isError: true,
    };
  }

  // MCP tools/call result shape: { result: { content: [...] } }
  const result = data.result ?? data;
  if (Array.isArray(result.content)) {
    return { content: result.content, isError: result.isError ?? false };
  }

  return {
    content: [{ type: "text", text: typeof result === "string" ? result : JSON.stringify(result) }],
  };
}

function registerTool(api, name, description, parameters, handler) {
  api.registerTool({
    name,
    description,
    parameters,
    async execute(id, params) {
      try {
        return await handler(params);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        api?.logger?.error?.(`[${PLUGIN_ID}] ${name} failed: ${msg}`);
        return { content: [{ type: "text", text: msg }], isError: true };
      }
    },
  });
}

// ── Plugin entry point ──────────────────────────────────────────────────────

export default {
  id: PLUGIN_ID,
  name: "OpenSpace Tools",
  register(api) {
    api?.logger?.info?.(`[${PLUGIN_ID}] Registering OpenSpace tools`);

    // 1. execute_task — delegate a task to OpenSpace's grounding agent
    // Parameters match openspace/mcp_server.py::execute_task exactly.
    registerTool(
      api,
      "execute_task",
      "Delegate a task to OpenSpace — a full-stack autonomous worker backed by a self-evolving skill library. " +
        "OpenSpace executes multi-step tasks (coding, file ops, web research, data analysis) and automatically " +
        "captures reusable patterns as skills, cutting token cost on similar future tasks. " +
        "Use this when the current task matches a pattern OpenSpace may have already solved, or when you want " +
        "the task result WITHOUT consuming your own context window for the execution. " +
        "This call may take several minutes for complex tasks.",
      {
        type: "object",
        additionalProperties: false,
        required: ["task"],
        properties: {
          task: {
            type: "string",
            description: "Full natural-language description of the task to execute.",
          },
          workspace_dir: {
            type: "string",
            description: "Working directory for the task (default: OpenSpace's configured workspace).",
          },
          max_iterations: {
            type: "integer",
            description: "Max agent iterations (default: 20). Increase for complex tasks.",
          },
          skill_dirs: {
            type: "array",
            items: { type: "string" },
            description: "Additional skill directories to register before execution.",
          },
          search_scope: {
            type: "string",
            enum: ["all", "local", "cloud"],
            default: "all",
            description: "Skill search scope: 'all' (local + cloud), 'local', or 'cloud'. Default: 'all'.",
          },
        },
      },
      (params) => callOpenSpaceTool(api, "execute_task", params)
    );

    // 2. search_skills — discover reusable skills before starting a task
    // Parameters match openspace/mcp_server.py::search_skills exactly.
    registerTool(
      api,
      "search_skills",
      "Search OpenSpace's local skill registry and cloud community for reusable execution patterns. " +
        "Call this BEFORE attempting a complex task to check if a proven skill already exists — " +
        "following an existing skill avoids redundant reasoning and saves tokens. " +
        "Returns skill descriptions and local paths so you can decide whether to follow a skill yourself " +
        "or delegate via execute_task.",
      {
        type: "object",
        additionalProperties: false,
        required: ["query"],
        properties: {
          query: {
            type: "string",
            description: "Natural language description of the capability you need.",
          },
          source: {
            type: "string",
            enum: ["all", "local", "cloud"],
            default: "all",
            description: "Search scope: 'all' (local + cloud), 'local', or 'cloud'. Default: 'all'.",
          },
          limit: {
            type: "integer",
            default: 20,
            description: "Maximum number of results to return (default: 20).",
          },
          auto_import: {
            type: "boolean",
            default: true,
            description: "Auto-download top public cloud skills locally (default: true).",
          },
        },
      },
      (params) => callOpenSpaceTool(api, "search_skills", params)
    );

    // 3. fix_skill — repair a broken skill in-place
    // Parameters match openspace/mcp_server.py::fix_skill exactly.
    registerTool(
      api,
      "fix_skill",
      "Repair a broken or outdated OpenSpace skill. OpenSpace will diagnose the failure, apply a targeted fix, " +
        "and store the new version in the skill DAG. Use when a skill you retrieved is failing or producing wrong results.",
      {
        type: "object",
        additionalProperties: false,
        required: ["skill_dir", "direction"],
        properties: {
          skill_dir: {
            type: "string",
            description: "Absolute path to the skill directory (must contain SKILL.md).",
          },
          direction: {
            type: "string",
            description: "What is broken and how to fix it — be specific about the failure and the desired fix.",
          },
        },
      },
      (params) => callOpenSpaceTool(api, "fix_skill", params)
    );

    // 4. upload_skill — share an evolved skill to the cloud community
    // Parameters match openspace/mcp_server.py::upload_skill exactly.
    registerTool(
      api,
      "upload_skill",
      "Upload a locally evolved OpenSpace skill to the cloud community at open-space.cloud, " +
        "making it available to other agents. Only call when you have successfully used or evolved a skill " +
        "and want to share it. For evolved/fixed skills, metadata is pre-saved — just provide skill_dir and visibility.",
      {
        type: "object",
        additionalProperties: false,
        required: ["skill_dir"],
        properties: {
          skill_dir: {
            type: "string",
            description: "Absolute path to the skill directory to upload (must contain SKILL.md).",
          },
          visibility: {
            type: "string",
            enum: ["public", "private"],
            default: "public",
            description: "Sharing visibility: 'public' or 'private' (default: 'public').",
          },
        },
      },
      (params) => callOpenSpaceTool(api, "upload_skill", params)
    );

    api?.logger?.info?.(`[${PLUGIN_ID}] 4 tools registered: execute_task, search_skills, fix_skill, upload_skill`);

    // ── Workflow hook — cold-start vs hot-rerun ──────────────────────────────
    // OPENSPACE_MODE controls which phase of the two-phase evaluation is active:
    //
    //   cold (default) — Phase 1: delegate EVERY task to execute_task so that
    //     OpenSpace's internal agent handles execution and automatically captures
    //     successful patterns as skills in the local registry.  The agent should
    //     NOT solve tasks itself; its only job is to call execute_task and report
    //     the result.
    //
    //   hot — Phase 2: skill library is already populated from the cold run.
    //     The agent searches first (search_skills), then either:
    //       a) follows the returned SKILL.md directly with its own tools, or
    //       b) delegates via execute_task which will now find and reuse the skill.
    //     This phase measures the token/time savings from skill reuse.
    //
    // Set OPENSPACE_MODE in the environment before starting the openspace-mcp
    // server (or pass it through the benchmark launch script).
    const mode = (typeof process !== "undefined" && process.env?.OPENSPACE_MODE) || "cold";

    if (mode === "hot") {
      api?.on?.("before_prompt_build", (_event, _ctx) => {
        return {
          appendSystemContext: [
            "",
            "## OpenSpace Skill Engine — Hot Rerun (Phase 2)",
            "The OpenSpace skill library has been pre-populated from a previous cold-start run.",
            "Your workflow for EVERY task:",
            "1. **`search_skills`** — call `search_skills(query=\"<one-line task description>\")` first.",
            "2. **Skill found (score ≥ 0.4)** → read the SKILL.md at `local_path` and follow its",
            "   step-by-step instructions exactly using your own tools.",
            "   If the skill is complex or requires a sandboxed environment, use `execute_task` instead.",
            "3. **No skill / low score** → use `execute_task(task=\"<full task description>\")` to",
            "   delegate to OpenSpace, which will search its registry internally and execute.",
            "Always prefer reusing a skill over reasoning from scratch — it saves tokens and is faster.",
          ].join("\n"),
        };
      }, { priority: 50 });
    } else {
      // cold mode (default)
      api?.on?.("before_prompt_build", (_event, _ctx) => {
        return {
          appendSystemContext: [
            "",
            "## OpenSpace Skill Engine — Cold Start (Phase 1)",
            "OpenSpace is a full-stack autonomous worker that executes tasks AND captures reusable",
            "patterns as skills for future runs. Your workflow for EVERY task:",
            "1. **Always call `execute_task`** — delegate the ENTIRE task to OpenSpace:",
            "   `execute_task(task=\"<complete task description, including all details and file paths>\")`",
            "   Do NOT attempt to solve the task yourself first.",
            "2. **Report the result** returned by execute_task to the user.",
            "3. If execute_task fails or times out, THEN fall back to your own tools.",
            "This is Phase 1 of a two-phase evaluation: OpenSpace is building its skill library.",
            "Every successful execute_task call adds a reusable skill for the hot-rerun phase.",
          ].join("\n"),
        };
      }, { priority: 50 });
    }
  },
};
