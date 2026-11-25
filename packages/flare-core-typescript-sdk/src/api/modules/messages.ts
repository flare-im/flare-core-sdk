/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `messages` — Message build, send, query and mutation.
 */
import type { MessageSendCallback } from '../../callback';
import type { CreateTextMessageRequest, ListMessagesRequest, ListMessagesResponse, Message, MessageByKeyResponse, MessageKey, MessageReadReceiptMembersRequest, MessageSearchQuery, SendMessageRequest, SendMessageResponse } from '../../model';
import type { ConfirmationRequest, DeleteMessageRequest, EditRichDocByMessageIdRequest, EditTextByMessageIdRequest, GetMessageRequest, JsonObject, MarkMessageReadAndBurnRequest, MessageDispatchRequest, MessageMutationRequest, ReactionMutationRequest, RecallMessageRequest, SetTypingRequest } from '../types';

/** Message build, send, query and mutation. */
export interface MessagesApi {
  /** createTextMessage maps to `flare_message_create_text` via `ffi-symbol`. Operation: `message.create_text`. */
  createTextMessage(request: CreateTextMessageRequest): Promise<Message>;
  /** dispatchMessage maps to `flare_message_dispatch_json` via `dispatch-json`. Operation: `message.dispatch`. */
  dispatchMessage(request: MessageDispatchRequest): Promise<unknown>;
  /** sendMessageNoOss maps to `flare_message_dispatch_json`, dispatch op `send_no_oss`. Operation: `message.send_no_oss`. */
  sendMessageNoOss(request: SendMessageRequest): Promise<SendMessageResponse>;
  /** sendMessage maps to `flare_message_dispatch_json`, dispatch op `send`. Operation: `message.send`. */
  sendMessage(request: SendMessageRequest, callback?: MessageSendCallback): Promise<SendMessageResponse>;
  /** listMessages maps to `flare_message_list` via `ffi-symbol`. Operation: `message.list`. */
  listMessages(request: ListMessagesRequest): Promise<ListMessagesResponse>;
  /** recallMessage maps to `flare_message_recall` via `ffi-symbol`. Operation: `message.recall`. */
  recallMessage(request: RecallMessageRequest): Promise<void>;
  /** editTextByMessageId maps to `flare_message_dispatch_json`, dispatch op `edit_text_by_message_id`. Operation: `message.edit_text_by_message_id`. */
  editTextByMessageId(request: EditTextByMessageIdRequest): Promise<void>;
  /** deleteMessage maps to `flare_message_delete` via `ffi-symbol`. Operation: `message.delete`. */
  deleteMessage(request: DeleteMessageRequest): Promise<void>;
  /** deleteMessageForSelf maps to `flare_message_dispatch_json`, dispatch op `delete_for_self`. Operation: `message.delete_for_self`. */
  deleteMessageForSelf(request: DeleteMessageRequest): Promise<void>;
  /** deleteMessageForEveryone maps to `flare_message_dispatch_json`, dispatch op `delete_for_everyone`. Operation: `message.delete_for_everyone`. */
  deleteMessageForEveryone(request: DeleteMessageRequest): Promise<void>;
  /** markMessageReadAndBurn maps to `flare_message_dispatch_json`, dispatch op `mark_read_and_burn`. Operation: `message.mark_read_and_burn`. */
  markMessageReadAndBurn(request: MarkMessageReadAndBurnRequest): Promise<void>;
  /** addReaction maps to `flare_message_dispatch_json`, dispatch op `add_reaction`. Operation: `message.add_reaction`. */
  addReaction(request: ReactionMutationRequest): Promise<void>;
  /** removeReaction maps to `flare_message_dispatch_json`, dispatch op `remove_reaction`. Operation: `message.remove_reaction`. */
  removeReaction(request: ReactionMutationRequest): Promise<void>;
  /** pinMessage maps to `flare_message_dispatch_json`, dispatch op `pin`. Operation: `message.pin`. */
  pinMessage(request: MessageMutationRequest): Promise<void>;
  /** unpinMessage maps to `flare_message_dispatch_json`, dispatch op `unpin`. Operation: `message.unpin`. */
  unpinMessage(request: MessageMutationRequest): Promise<void>;
  /** pinMessageById maps to `flare_message_dispatch_json`, dispatch op `pin_by_message_id`. Operation: `message.pin_by_message_id`. */
  pinMessageById(request: MessageMutationRequest): Promise<void>;
  /** unpinMessageById maps to `flare_message_dispatch_json`, dispatch op `unpin_by_message_id`. Operation: `message.unpin_by_message_id`. */
  unpinMessageById(request: MessageMutationRequest): Promise<void>;
  /** markMessage maps to `flare_message_dispatch_json`, dispatch op `mark`. Operation: `message.mark`. */
  markMessage(request: MessageMutationRequest): Promise<void>;
  /** markMessageWithColor maps to `flare_message_dispatch_json`, dispatch op `mark_with_color`. Operation: `message.mark_with_color`. */
  markMessageWithColor(request: MessageMutationRequest): Promise<void>;
  /** unmarkMessage maps to `flare_message_dispatch_json`, dispatch op `unmark`. Operation: `message.unmark`. */
  unmarkMessage(request: MessageMutationRequest): Promise<void>;
  /** markMessageById maps to `flare_message_dispatch_json`, dispatch op `mark_by_message_id`. Operation: `message.mark_by_message_id`. */
  markMessageById(request: MessageMutationRequest): Promise<void>;
  /** unmarkMessageById maps to `flare_message_dispatch_json`, dispatch op `unmark_by_message_id`. Operation: `message.unmark_by_message_id`. */
  unmarkMessageById(request: MessageMutationRequest): Promise<void>;
  /** getMessage maps to `flare_message_dispatch_json`, dispatch op `get`. Operation: `message.get`. */
  getMessage(request: GetMessageRequest): Promise<Message>;
  /** getMessageByKey maps to `flare_message_dispatch_json`, dispatch op `get_by_key`. Operation: `message.get_by_key`. */
  getMessageByKey(request: MessageKey): Promise<MessageByKeyResponse>;
  /** awaitMessageConfirmation maps to `flare_message_dispatch_json`, dispatch op `await_confirmation`. Operation: `message.await_confirmation`. */
  awaitMessageConfirmation(request: ConfirmationRequest): Promise<unknown>;
  /** getRawMessage maps to `flare_message_dispatch_json`, dispatch op `get_raw`. Operation: `message.get_raw`. */
  getRawMessage(request: GetMessageRequest): Promise<unknown>;
  /** searchMessages maps to `flare_message_dispatch_json`, dispatch op `search`. Operation: `message.search`. */
  searchMessages(request: MessageSearchQuery): Promise<ListMessagesResponse>;
  /** searchMessagesByQuery maps to `flare_message_dispatch_json`, dispatch op `search_by_query`. Operation: `message.search_by_query`. */
  searchMessagesByQuery(request: MessageSearchQuery): Promise<ListMessagesResponse>;
  /** searchMessagesInConversation maps to `flare_message_dispatch_json`, dispatch op `search_in_conversation`. Operation: `message.search_in_conversation`. */
  searchMessagesInConversation(request: MessageSearchQuery): Promise<ListMessagesResponse>;
  /** readReceiptMembers maps to `flare_message_dispatch_json`, dispatch op `read_receipt_members`. Operation: `message.read_receipt_members`. */
  readReceiptMembers(request: MessageReadReceiptMembersRequest): Promise<JsonObject>;
  /** editRichDocByMessageId maps to `flare_message_dispatch_json`, dispatch op `edit_rich_doc_by_message_id`. Operation: `message.edit_rich_doc_by_message_id`. */
  editRichDocByMessageId(request: EditRichDocByMessageIdRequest): Promise<void>;
  /** setTyping maps to `flare_message_dispatch_json`, dispatch op `typing`. Operation: `message.typing`. */
  setTyping(request: SetTypingRequest): Promise<void>;
}
