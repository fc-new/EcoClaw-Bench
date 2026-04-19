/**
 * Turn Parser — Parse flat message arrays into interaction turns.
 *
 * An interaction turn (from AgentSwing paper) is a triple:
 *   (thinking, tool_call, tool_response)
 *
 * In OpenClaw's message format:
 *   - An assistant message may contain thinking blocks + toolCall blocks
 *   - Followed by toolResult messages matching those calls
 *   - A "pure text" assistant message (no tool calls) is also a turn boundary
 *
 * We split messages into:
 *   - preamble: system messages + first user message (original task prompt)
 *   - turns: sequential interaction turns
 */

/** Minimal message shape we depend on (subset of AgentMessage). */
export interface Msg {
    role: string;
    content?: unknown;
    [key: string]: unknown;
}

export interface InteractionTurn {
    /** All messages belonging to this turn (assistant + tool results). */
    messages: Msg[];
}

export interface ParsedConversation {
    /** System messages + first user message — always preserved. */
    preamble: Msg[];
    /** Sequential interaction turns after the preamble. */
    turns: InteractionTurn[];
}

/**
 * Check if an assistant message contains tool calls.
 */
function hasToolCalls(msg: Msg): boolean {
    const content = msg.content;
    if (!Array.isArray(content)) return false;
    return content.some(
        (block: Record<string, unknown>) => block.type === "toolCall",
    );
}

/**
 * Count tool calls in an assistant message.
 */
function countToolCalls(msg: Msg): number {
    const content = msg.content;
    if (!Array.isArray(content)) return 0;
    return content.filter(
        (block: Record<string, unknown>) => block.type === "toolCall",
    ).length;
}

/**
 * Parse a flat message array into preamble + interaction turns.
 *
 * Strategy:
 * 1. Collect preamble (system msgs + first user msg)
 * 2. For remaining messages, group by assistant turn boundaries:
 *    - Each assistant message starts a new turn
 *    - Subsequent toolResult messages belong to the same turn
 *    - User messages between turns are attached to the next turn
 */
export function parseConversation(messages: Msg[]): ParsedConversation {
    const preamble: Msg[] = [];
    const turns: InteractionTurn[] = [];

    let i = 0;

    // Collect preamble: all leading system messages + first user message
    while (i < messages.length) {
        const msg = messages[i];
        if (msg.role === "system") {
            preamble.push(msg);
            i++;
        } else if (msg.role === "user") {
            preamble.push(msg);
            i++;
            break;
        } else {
            // Non-system, non-user at start (e.g., stale assistant) — stop preamble collection
            break;
        }
    }

    // Parse remaining messages into turns
    let currentTurnMsgs: Msg[] = [];

    const flushTurn = () => {
        if (currentTurnMsgs.length > 0) {
            turns.push({ messages: [...currentTurnMsgs] });
            currentTurnMsgs = [];
        }
    };

    while (i < messages.length) {
        const msg = messages[i];

        if (msg.role === "assistant") {
            // New assistant message = new turn boundary
            flushTurn();
            currentTurnMsgs.push(msg);

            // Collect subsequent toolResult messages belonging to this assistant's tool calls
            const expectedResults = hasToolCalls(msg) ? countToolCalls(msg) : 0;
            let collectedResults = 0;
            let j = i + 1;
            while (j < messages.length && collectedResults < expectedResults) {
                if (messages[j].role === "toolResult") {
                    currentTurnMsgs.push(messages[j]);
                    collectedResults++;
                    j++;
                } else {
                    break;
                }
            }
            i = j;
        } else if (msg.role === "user") {
            // User message in the middle — flush previous turn, attach to next
            flushTurn();
            currentTurnMsgs.push(msg);
            i++;
        } else if (msg.role === "toolResult") {
            // Orphaned tool result — attach to current turn
            currentTurnMsgs.push(msg);
            i++;
        } else {
            // Unknown role — attach to current turn
            currentTurnMsgs.push(msg);
            i++;
        }
    }
    flushTurn();

    return { preamble, turns };
}

/**
 * Keep only the last N turns, always preserving the preamble.
 * Returns a flat message array ready for the model.
 */
export function keepLastNTurns(parsed: ParsedConversation, n: number): Msg[] {
    const keptTurns = parsed.turns.slice(-n);
    const result: Msg[] = [...parsed.preamble];
    for (const turn of keptTurns) {
        result.push(...turn.messages);
    }
    return result;
}

/**
 * Extract all messages that should be summarized (everything except preamble and last N turns).
 */
export function getMessagesToSummarize(
    parsed: ParsedConversation,
    keepRecent: number = 0,
): Msg[] {
    const toSummarize = parsed.turns.slice(
        0,
        Math.max(0, parsed.turns.length - keepRecent),
    );
    const result: Msg[] = [];
    for (const turn of toSummarize) {
        result.push(...turn.messages);
    }
    return result;
}

/**
 * Build a flat text representation of messages for summarization input.
 */
export function messagesToText(messages: Msg[]): string {
    const lines: string[] = [];
    for (const msg of messages) {
        const role = msg.role;
        let text = "";
        if (typeof msg.content === "string") {
            text = msg.content;
        } else if (Array.isArray(msg.content)) {
            const parts: string[] = [];
            for (const block of msg.content as Record<string, unknown>[]) {
                if (block.type === "text" && typeof block.text === "string") {
                    parts.push(block.text);
                } else if (block.type === "thinking" && typeof block.text === "string") {
                    parts.push(`[thinking] ${block.text}`);
                } else if (block.type === "toolCall") {
                    parts.push(`[tool_call: ${block.name}(${JSON.stringify(block.arguments).slice(0, 200)})]`);
                } else if (block.type === "toolResult" && typeof block.content === "string") {
                    parts.push(`[tool_result] ${block.content.slice(0, 500)}`);
                }
            }
            text = parts.join("\n");
        }
        if (text) {
            lines.push(`[${role}] ${text}`);
        }
    }
    return lines.join("\n\n");
}
