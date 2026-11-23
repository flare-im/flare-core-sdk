// GENERATED. Do not edit by hand.
import { Conversation } from './conversation';
import { Message } from './message';
import { ViewDeltaOp } from './view_delta_op';

/** Typed delta emitted by core observable views. A timeline delta works by the message timelineKey (canonical server identity for confirmed rows; ACK migrates the local row identity): remove the keys in remove, replace the rows in upsert in place, put prepend first and append last, reorder by every key when reorder is present, then take the three state fields and conversation. A conversation-list delta is the indexed ops list. */
export interface ViewDelta {
  /** wire: `viewType`. Delta tag: timeline or conversationList. */
  viewType: string;
  /** wire: `prepend`. Timeline: older rows to put before the first row, in timeline order. */
  prepend?: Array<Message>;
  /** wire: `append`. Timeline: newer rows to put after the last row, in timeline order. */
  append?: Array<Message>;
  /** wire: `upsert`. Timeline: new content of rows already in the window, replaced in place by row key. */
  upsert?: Array<Message>;
  /** wire: `remove`. Timeline: row keys leaving the window. */
  remove?: Array<string>;
  /** wire: `reorder`. Timeline: every row key in the new order; only when the order changed in a way the other steps cannot express. */
  reorder?: Array<string>;
  /** wire: `hasOlder`. Timeline: whether more visible messages exist below the window. */
  hasOlder?: boolean;
  /** wire: `hasNewer`. Timeline: whether more messages exist above the window. */
  hasNewer?: boolean;
  /** wire: `attachedToLatest`. Timeline: whether the window is attached to the latest. */
  attachedToLatest?: boolean;
  /** wire: `conversation`. Timeline: the conversation header, only when it changed. */
  conversation?: Conversation;
  /** wire: `ops`. Conversation list: ordered indexed operations. */
  ops?: Array<ViewDeltaOp>;
  /** wire: `totalUnread`. Conversation list: latest total unread value. */
  totalUnread?: number;
  /** wire: `syncState`. Conversation list: latest sync state. */
  syncState?: string;
}
