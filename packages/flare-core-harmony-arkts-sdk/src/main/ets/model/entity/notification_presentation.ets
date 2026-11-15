// GENERATED. Do not edit by hand.

/** One notification to show (or to replace in place). */
export interface NotificationPresentation {
  /** wire: `body`. Body, already rendered in the app's language. */
  body: string;
  /** wire: `channel`. messages, quiet, mentions or urgent (Android channel flare.<channel>). */
  channel: string;
  /** wire: `collapseId`. Notification identity: one per conversation. Used as the iOS notification identifier and the Android notification tag, so a later notification for the same conversation replaces it. */
  collapseId: string;
  /** wire: `conversationId`. Conversation the notification belongs to; empty for the digest notification. */
  conversationId: string;
  /** wire: `count`. Unread messages the notification stands for, at least 1. */
  count: number;
  /** wire: `messageId`. Server id of the newest message it stands for; empty for a catch-up without a loaded message and for the digest notification. */
  messageId: string;
  /** wire: `seq`. Conversation seq of the newest message it stands for; 0 for the digest notification. */
  seq: number;
  /** wire: `sound`. Whether to play a sound; a silent replacement never sounds. */
  sound: boolean;
  /** wire: `surface`. system (an OS notification) or inApp (a banner inside the running app). */
  surface: string;
  /** wire: `threadId`. Grouping key in the notification centre. */
  threadId: string;
  /** wire: `title`. Title, already rendered in the app's language. */
  title: string;
}
