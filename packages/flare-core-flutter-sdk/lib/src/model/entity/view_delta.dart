// GENERATED. Do not edit by hand.
import 'conversation.dart';
import 'message.dart';
import 'view_delta_op.dart';

/// Typed delta emitted by core observable views. A timeline delta works by the message timelineKey (canonical server identity for confirmed rows; ACK migrates the local row identity): remove the keys in remove, replace the rows in upsert in place, put prepend first and append last, reorder by every key when reorder is present, then take the three state fields and conversation. A conversation-list delta is the indexed ops list.
final class ViewDelta {
  /// wire: `viewType`. Delta tag: timeline or conversationList.
  final String viewType;
  /// wire: `prepend`. Timeline: older rows to put before the first row, in timeline order.
  final List<Message>? prepend;
  /// wire: `append`. Timeline: newer rows to put after the last row, in timeline order.
  final List<Message>? append;
  /// wire: `upsert`. Timeline: new content of rows already in the window, replaced in place by row key.
  final List<Message>? upsert;
  /// wire: `remove`. Timeline: row keys leaving the window.
  final List<String>? remove;
  /// wire: `reorder`. Timeline: every row key in the new order; only when the order changed in a way the other steps cannot express.
  final List<String>? reorder;
  /// wire: `hasOlder`. Timeline: whether more visible messages exist below the window.
  final bool? hasOlder;
  /// wire: `hasNewer`. Timeline: whether more messages exist above the window.
  final bool? hasNewer;
  /// wire: `attachedToLatest`. Timeline: whether the window is attached to the latest.
  final bool? attachedToLatest;
  /// wire: `conversation`. Timeline: the conversation header, only when it changed.
  final Conversation? conversation;
  /// wire: `ops`. Conversation list: ordered indexed operations.
  final List<ViewDeltaOp>? ops;
  /// wire: `totalUnread`. Conversation list: latest total unread value.
  final int? totalUnread;
  /// wire: `syncState`. Conversation list: latest sync state.
  final String? syncState;

  const ViewDelta({
    this.viewType = '',
    this.prepend,
    this.append,
    this.upsert,
    this.remove,
    this.reorder,
    this.hasOlder,
    this.hasNewer,
    this.attachedToLatest,
    this.conversation,
    this.ops,
    this.totalUnread,
    this.syncState,
  });
}
