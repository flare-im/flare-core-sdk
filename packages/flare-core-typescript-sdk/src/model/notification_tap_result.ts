/** GENERATED. Do not edit by hand. */

/** Where a tapped notification leads; every field is absent when the payload is not for the current account. */
export interface NotificationTapResult {
  /** wire: `conversationId`. Conversation to open. */
  conversationId?: string;
  /** wire: `messageId`. Message to scroll to, when the payload named one. */
  messageId?: string;
  /** wire: `seq`. Conversation seq of that message. */
  seq?: number;
}
