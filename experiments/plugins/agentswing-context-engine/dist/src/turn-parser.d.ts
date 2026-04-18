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
 * Parse a flat message array into preamble + interaction turns.
 *
 * Strategy:
 * 1. Collect preamble (system msgs + first user msg)
 * 2. For remaining messages, group by assistant turn boundaries:
 *    - Each assistant message starts a new turn
 *    - Subsequent toolResult messages belong to the same turn
 *    - User messages between turns are attached to the next turn
 */
export declare function parseConversation(messages: Msg[]): ParsedConversation;
/**
 * Keep only the last N turns, always preserving the preamble.
 * Returns a flat message array ready for the model.
 */
export declare function keepLastNTurns(parsed: ParsedConversation, n: number): Msg[];
/**
 * Extract all messages that should be summarized (everything except preamble and last N turns).
 */
export declare function getMessagesToSummarize(parsed: ParsedConversation, keepRecent?: number): Msg[];
/**
 * Build a flat text representation of messages for summarization input.
 */
export declare function messagesToText(messages: Msg[]): string;
