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
export declare function isConversationMessage(msg: Msg): boolean;
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
