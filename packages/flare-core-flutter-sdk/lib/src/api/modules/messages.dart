// GENERATED. Do not edit by hand.
// Module API: `messages` — Message build, send, query and mutation.
import '../../model/model.dart';
import '../../callback/callback.dart';

/// Message build, send, query and mutation.
abstract interface class MessagesApi {
  /// createTextMessage maps to `flare_message_create_text` via `ffi-symbol`. Operation: `message.create_text`.
  Future<Message> createTextMessage(CreateTextMessageRequest request);
  /// dispatchMessage maps to `flare_message_dispatch_json` via `dispatch-json`. Operation: `message.dispatch`.
  Future<Map<String, Object?>> dispatchMessage(Map<String, Object?> request);
  /// sendMessageNoOss maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `send_no_oss`. Operation: `message.send_no_oss`.
  Future<SendMessageResponse> sendMessageNoOss(SendMessageRequest request);
  /// sendMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `send`. Operation: `message.send`.
  Future<SendMessageResponse> sendMessage(SendMessageRequest request, [MessageSendCallback? callback]);
  /// listMessages maps to `flare_message_list` via `ffi-symbol`. Operation: `message.list`.
  Future<ListMessagesResponse> listMessages(ListMessagesRequest request);
  /// recallMessage maps to `flare_message_recall` via `ffi-symbol`. Operation: `message.recall`.
  Future<void> recallMessage(Map<String, Object?> request);
  /// editTextByMessageId maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `edit_text_by_message_id`. Operation: `message.edit_text_by_message_id`.
  Future<void> editTextByMessageId(Map<String, Object?> request);
  /// deleteMessage maps to `flare_message_delete` via `ffi-symbol`. Operation: `message.delete`.
  Future<void> deleteMessage(Map<String, Object?> request);
  /// deleteMessageForSelf maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `delete_for_self`. Operation: `message.delete_for_self`.
  Future<void> deleteMessageForSelf(Map<String, Object?> request);
  /// deleteMessageForEveryone maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `delete_for_everyone`. Operation: `message.delete_for_everyone`.
  Future<void> deleteMessageForEveryone(Map<String, Object?> request);
  /// markMessageReadAndBurn maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_read_and_burn`. Operation: `message.mark_read_and_burn`.
  Future<void> markMessageReadAndBurn(Map<String, Object?> request);
  /// addReaction maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `add_reaction`. Operation: `message.add_reaction`.
  Future<void> addReaction(Map<String, Object?> request);
  /// removeReaction maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `remove_reaction`. Operation: `message.remove_reaction`.
  Future<void> removeReaction(Map<String, Object?> request);
  /// pinMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `pin`. Operation: `message.pin`.
  Future<void> pinMessage(Map<String, Object?> request);
  /// unpinMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unpin`. Operation: `message.unpin`.
  Future<void> unpinMessage(Map<String, Object?> request);
  /// pinMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `pin_by_message_id`. Operation: `message.pin_by_message_id`.
  Future<void> pinMessageById(Map<String, Object?> request);
  /// unpinMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unpin_by_message_id`. Operation: `message.unpin_by_message_id`.
  Future<void> unpinMessageById(Map<String, Object?> request);
  /// markMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark`. Operation: `message.mark`.
  Future<void> markMessage(Map<String, Object?> request);
  /// markMessageWithColor maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_with_color`. Operation: `message.mark_with_color`.
  Future<void> markMessageWithColor(Map<String, Object?> request);
  /// unmarkMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unmark`. Operation: `message.unmark`.
  Future<void> unmarkMessage(Map<String, Object?> request);
  /// markMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_by_message_id`. Operation: `message.mark_by_message_id`.
  Future<void> markMessageById(Map<String, Object?> request);
  /// unmarkMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unmark_by_message_id`. Operation: `message.unmark_by_message_id`.
  Future<void> unmarkMessageById(Map<String, Object?> request);
  /// getMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `get`. Operation: `message.get`.
  Future<Message> getMessage(Map<String, Object?> request);
  /// getMessageByKey maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `get_by_key`. Operation: `message.get_by_key`.
  Future<MessageByKeyResponse> getMessageByKey(MessageKey request);
  /// awaitMessageConfirmation maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `await_confirmation`. Operation: `message.await_confirmation`.
  Future<Map<String, Object?>> awaitMessageConfirmation(Map<String, Object?> request);
  /// getRawMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `get_raw`. Operation: `message.get_raw`.
  Future<Map<String, Object?>> getRawMessage(Map<String, Object?> request);
  /// searchMessages maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search`. Operation: `message.search`.
  Future<ListMessagesResponse> searchMessages(MessageSearchQuery request);
  /// searchMessagesByQuery maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search_by_query`. Operation: `message.search_by_query`.
  Future<ListMessagesResponse> searchMessagesByQuery(MessageSearchQuery request);
  /// searchMessagesInConversation maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search_in_conversation`. Operation: `message.search_in_conversation`.
  Future<ListMessagesResponse> searchMessagesInConversation(MessageSearchQuery request);
  /// readReceiptMembers maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `read_receipt_members`. Operation: `message.read_receipt_members`.
  Future<Map<String, Object?>> readReceiptMembers(MessageReadReceiptMembersRequest request);
  /// editRichDocByMessageId maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `edit_rich_doc_by_message_id`. Operation: `message.edit_rich_doc_by_message_id`.
  Future<void> editRichDocByMessageId(Map<String, Object?> request);
  /// setTyping maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `typing`. Operation: `message.typing`.
  Future<void> setTyping(Map<String, Object?> request);
}
