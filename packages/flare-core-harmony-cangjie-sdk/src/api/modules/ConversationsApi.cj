package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Conversation query and local conversation state.
public interface ConversationsApi {
    func listConversations(): ListConversationsResponse
    func listConversationsByQuery(request: ConversationListQuery): ListConversationsResponse
    func listConversationsIncludingArchived(): ListConversationsResponse
    func getConversation(requestJson: String): Conversation
    func getOneConversation(requestJson: String): Conversation
    func getGroupConversationByUserIds(requestJson: String): Conversation
    func getMultipleConversations(requestJson: String): ListConversationsResponse
    func listConversationsPaginated(requestJson: String): ListConversationsResponse
    func listRawConversations(): ListConversationsResponse
    func getTotalUnread(): ConversationTotalUnreadResponse
    func bootstrapHomeTimeline(request: BootstrapHomeTimelineRequest): HomeTimelineSnapshot
    func openConversationTimeline(request: OpenConversationTimelineRequest): ConversationTimelineSnapshot
    func markConversationRead(requestJson: String): Unit
    func setConversationPinned(requestJson: String): Unit
    func setConversationMuted(requestJson: String): Unit
    func setConversationArchived(requestJson: String): Unit
    func markConversationUnread(requestJson: String): Unit
    func deleteConversation(requestJson: String): Unit
    func updateConversationDraft(request: UpdateConversationDraftRequest): Unit
    func clearLocalChatHistory(requestJson: String): Unit
    func clearChatHistoryForSelf(requestJson: String): Unit
}
