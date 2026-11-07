// GENERATED. Do not edit by hand.
import { MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, ReactionChangedEvent, ReadReceiptEvent, TypingAggregateEvent, TypingEvent } from '../model';

/** Message listener callbacks. */
export interface MessageEventListener {
  /** A single message was received. */
  onMessageReceived?(event: MessageReceivedEvent): void;
  /** A batch of messages was received. */
  onMessageReceivedBatch?(event: MessageReceivedBatchEvent): void;
  /** A message send operation was acknowledged. */
  onMessageSendAck?(event: MessageSendAckEvent): void;
  /** A message send operation failed. */
  onMessageSendFailed?(event: MessageSendFailedEvent): void;
  /** A message was recalled. */
  onMessageRecalled?(event: MessageMutationEvent): void;
  /** A message was edited. */
  onMessageEdited?(event: MessageMutationEvent): void;
  /** A message was deleted. */
  onMessageDeleted?(event: MessageMutationEvent): void;
  /** A message read receipt changed. */
  onMessageReadReceipt?(event: ReadReceiptEvent): void;
  /** A message reaction changed. */
  onMessageReactionChanged?(event: ReactionChangedEvent): void;
  /** A conversation input or typing status changed. */
  onInputStatusChanged?(event: TypingEvent): void;
  /** Aggregated typing status changed for a large conversation. */
  onTypingAggregateChanged?(event: TypingAggregateEvent): void;
  /** A burn-after-read message was burned. */
  onMessageBurned?(event: MessageMutationEvent): void;
  /** A message was pinned. */
  onMessagePinned?(event: MessageMutationEvent): void;
  /** A message was unpinned. */
  onMessageUnpinned?(event: MessageMutationEvent): void;
  /** Plugin card state on a local message changed: the shared layer Core publishes for the card's entity (events, sync, the caller's own result) or the viewer's local layer. Re-present that message with its messageId; version is the local layer's when that changed, the shared layer's otherwise. */
  onMessagePluginStateChanged?(event: MessageMutationEvent): void;
}

/** Direct callback for `messages.sendMessage(request, callback)` progress and terminal states. */
export interface MessageSendCallback {
  /** Message upload or send progress changed. */
  onProgress?(event: ProgressEvent): void;
  /** Message send completed successfully. */
  onSuccess?(event: MessageSendAckEvent): void;
  /** Message send failed. */
  onFailure?(event: MessageSendFailedEvent): void;
}
