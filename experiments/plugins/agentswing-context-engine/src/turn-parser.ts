/**
 * Turn Parser — Parse flat message arrays into interaction turns.
 *
 * An interaction turn (from the AgentSwing paper) is centered on a local
 * environment interaction:
 *   (thinking, tool_call, tool_response)
 *
 * In OpenClaw's message format:
 *   - An assistant message may contain thinking blocks + toolCall blocks
 *   - Matching toolResult messages follow
 *   - Follow-up assistant text belongs to the same local interaction
 *
 * We split messages into:
 *   - preamble: system messages + first user message (original task prompt)
 *   - turns: sequential interaction turns after the prompt
 */

/** Minimal message shape we depend on (subset of AgentMessage). */
export interface Msg {
    role: string;
    content?: unknown;
    [key: string]: unknown;
}

export interface InteractionTurn {
    /** All messages belonging to this turn. */
    messages: Msg[];
}

export interface ParsedConversation {
    /** System messages + first user message — always preserved. */
    preamble: Msg[];
    /** Sequential interaction turns after the preamble. */
    turns: InteractionTurn[];
}

/**
 * OpenClaw session files also contain runtime metadata records such as
 * session/model changes and bootstrap markers. They are useful for replay, but
 * they are not part of the model-visible AgentSwing trajectory.
 */
export function isConversationMessage(msg: Msg): boolean {
    return (
        msg.role === "system" ||
        msg.role === "user" ||
        msg.role === "assistant" ||
        msg.role === "toolResult"
    );
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
 * Parse a flat message array into preamble + interaction turns.
 *
 * Strategy:
 * 1. Collect preamble (all leading system messages + first user message)
 * 2. For the remaining transcript:
 *    - an assistant tool-call message starts a new interaction turn
 *    - tool results and follow-up assistant text stay in that turn
 *    - a mid-session user message starts a fresh turn and stays grouped with
 *      the next assistant reply
 */
export function parseConversation(messages: Msg[]): ParsedConversation {
    const conversationMessages = messages.filter(isConversationMessage);
    const preamble: Msg[] = [];
    const turns: InteractionTurn[] = [];

    let i = 0;

    while (i < conversationMessages.length) {
        const msg = conversationMessages[i];
        if (msg.role === "system") {
            preamble.push(msg);
            i++;
            continue;
        }
        if (msg.role === "user") {
            preamble.push(msg);
            i++;
            break;
        }
        break;
    }

    let currentTurnMsgs: Msg[] = [];

    const flushTurn = () => {
        if (currentTurnMsgs.length === 0) {
            return;
        }
        turns.push({ messages: [...currentTurnMsgs] });
        currentTurnMsgs = [];
    };

    const currentTurnHasAssistantActivity = () =>
        currentTurnMsgs.some(
            (msg) => msg.role === "assistant" || msg.role === "toolResult",
        );

    while (i < conversationMessages.length) {
        const msg = conversationMessages[i];

        if (msg.role === "assistant") {
            if (hasToolCalls(msg) && currentTurnHasAssistantActivity()) {
                flushTurn();
            }
            currentTurnMsgs.push(msg);
            i++;
            continue;
        }

        if (msg.role === "user") {
            flushTurn();
            currentTurnMsgs.push(msg);
            i++;
            continue;
        }

        currentTurnMsgs.push(msg);
        i++;
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
                } else if (
                    block.type === "thinking" &&
                    (typeof block.text === "string" || typeof block.thinking === "string")
                ) {
                    parts.push(`[thinking] ${String(block.text ?? block.thinking)}`);
                } else if (block.type === "toolCall") {
                    parts.push(
                        `[tool_call: ${block.name}(${JSON.stringify(block.arguments).slice(0, 200)})]`,
                    );
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
