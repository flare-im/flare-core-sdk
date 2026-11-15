// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, CreateTextMessageRequest, LifecycleEvent, ListMessagesRequest, ListMessagesResponse, Message, MessageMutationEvent, MessageReadReceiptMembersRequest, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSearchQuery, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SendMessageRequest, SendMessageResponse, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';
import { EventCallback, EventSubscription, FlareImEventListener, MessageSendCallback } from '../../listener';

/** Message build, send, query and mutation. */
export interface MessagesApi {
  createTextMessage(request: CreateTextMessageRequest): Promise<Message>;
  dispatchMessage(request: Record<string, Object>): Promise<Record<string, Object>>;
  sendMessageNoOss(request: SendMessageRequest): Promise<SendMessageResponse>;
  sendMessage(request: SendMessageRequest, callback?: MessageSendCallback): Promise<SendMessageResponse>;
  listMessages(request: ListMessagesRequest): Promise<ListMessagesResponse>;
  recallMessage(request: Record<string, Object>): Promise<void>;
  editTextByMessageId(request: Record<string, Object>): Promise<void>;
  deleteMessage(request: Record<string, Object>): Promise<void>;
  deleteMessageForSelf(request: Record<string, Object>): Promise<void>;
  deleteMessageForEveryone(request: Record<string, Object>): Promise<void>;
  markMessageReadAndBurn(request: Record<string, Object>): Promise<void>;
  addReaction(request: Record<string, Object>): Promise<void>;
  removeReaction(request: Record<string, Object>): Promise<void>;
  pinMessage(request: Record<string, Object>): Promise<void>;
  unpinMessage(request: Record<string, Object>): Promise<void>;
  pinMessageById(request: Record<string, Object>): Promise<void>;
  unpinMessageById(request: Record<string, Object>): Promise<void>;
  markMessage(request: Record<string, Object>): Promise<void>;
  markMessageWithColor(request: Record<string, Object>): Promise<void>;
  unmarkMessage(request: Record<string, Object>): Promise<void>;
  markMessageById(request: Record<string, Object>): Promise<void>;
  unmarkMessageById(request: Record<string, Object>): Promise<void>;
  getMessage(request: Record<string, Object>): Promise<Message>;
  getRawMessage(request: Record<string, Object>): Promise<Record<string, Object>>;
  searchMessages(request: MessageSearchQuery): Promise<ListMessagesResponse>;
  searchMessagesByQuery(request: MessageSearchQuery): Promise<ListMessagesResponse>;
  searchMessagesInConversation(request: MessageSearchQuery): Promise<ListMessagesResponse>;
  readReceiptMembers(request: MessageReadReceiptMembersRequest): Promise<Record<string, Object>>;
  editRichDocByMessageId(request: Record<string, Object>): Promise<void>;
  setTyping(request: Record<string, Object>): Promise<void>;
}
