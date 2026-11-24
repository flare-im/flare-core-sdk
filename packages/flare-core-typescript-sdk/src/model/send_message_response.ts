/** GENERATED. Do not edit by hand. */
import type { MessageSendStage } from './message_send_stage';

/** Send acknowledgement returned by core-sdk. */
export interface SendMessageResponse {
  /** wire: `ackId`. ACK id assigned by the transport layer, if present. */
  ackId: string;
  /** wire: `serverId`. Server-assigned message id. */
  serverId: string;
  /** wire: `clientMsgId`. Client message id acknowledged by the server. */
  clientMsgId: string;
  /** wire: `conversationId`. Conversation id. */
  conversationId: string;
  /** wire: `seq`. Assigned conversation sequence. */
  seq: number;
  /** wire: `timestamp`. Server send time in milliseconds. */
  timestamp: number;
  /** wire: `success`. Whether the SDK queued the message locally or the server accepted it. Check stage for persistence. */
  success: boolean;
  /** wire: `stage`. Queued locally, accepted by the server, persisted by the server, or failed. Older engines omit this field. */
  stage?: MessageSendStage;
  /** wire: `errorCode`. Core ACK error code when success is false. */
  errorCode: number;
  /** wire: `errorMessage`. Core ACK error message when success is false. */
  errorMessage: string;
}
