// GENERATED. Do not edit by hand.

/** One remote push the platform push module received. */
export interface HandleRemoteMessageRequest {
  /** wire: `budgetMs`. Background execution time the platform holds for this push, in milliseconds. Above zero the engine also wakes the link for one incremental sync within it; the answer never waits for that. */
  budgetMs?: number;
  /** wire: `payload`. The push payload flattened to strings (snake_case keys): uid, tenant_id, conversation_id, message_id, seq, collapse_id, thread_id, disposition, alert_class, count, badge, title, body, sound. Keys the engine does not know are ignored. */
  payload: Record<string, string>;
  /** wire: `provider`. Push channel that delivered it: apns, fcm or getui. */
  provider: string;
}
