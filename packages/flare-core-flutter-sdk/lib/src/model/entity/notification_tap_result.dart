// GENERATED. Do not edit by hand.

/// Where a tapped notification leads; every field is absent when the payload is not for the current account.
final class NotificationTapResult {
  /// wire: `conversationId`. Conversation to open.
  final String? conversationId;
  /// wire: `messageId`. Message to scroll to, when the payload named one.
  final String? messageId;
  /// wire: `seq`. Conversation seq of that message.
  final int? seq;

  const NotificationTapResult({
    this.conversationId,
    this.messageId,
    this.seq,
  });
}
