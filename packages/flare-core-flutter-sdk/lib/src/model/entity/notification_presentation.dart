// GENERATED. Do not edit by hand.

/// One notification to show (or to replace in place).
final class NotificationPresentation {
  /// wire: `body`. Body, already rendered in the app's language.
  final String body;
  /// wire: `channel`. messages, quiet, mentions or urgent (Android channel flare.<channel>).
  final String channel;
  /// wire: `collapseId`. Notification identity: one per conversation. Used as the iOS notification identifier and the Android notification tag, so a later notification for the same conversation replaces it.
  final String collapseId;
  /// wire: `conversationId`. Conversation the notification belongs to; empty for the digest notification.
  final String conversationId;
  /// wire: `count`. Unread messages the notification stands for, at least 1.
  final int count;
  /// wire: `messageId`. Server id of the newest message it stands for; empty for a catch-up without a loaded message and for the digest notification.
  final String messageId;
  /// wire: `seq`. Conversation seq of the newest message it stands for; 0 for the digest notification.
  final int seq;
  /// wire: `sound`. Whether to play a sound; a silent replacement never sounds.
  final bool sound;
  /// wire: `surface`. system (an OS notification) or inApp (a banner inside the running app).
  final String surface;
  /// wire: `threadId`. Grouping key in the notification centre.
  final String threadId;
  /// wire: `title`. Title, already rendered in the app's language.
  final String title;

  const NotificationPresentation({
    this.body = '',
    this.channel = '',
    this.collapseId = '',
    this.conversationId = '',
    this.count = 0,
    this.messageId = '',
    this.seq = 0,
    this.sound = false,
    this.surface = '',
    this.threadId = '',
    this.title = '',
  });
}
