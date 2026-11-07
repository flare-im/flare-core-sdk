import Foundation

/// GENERATED. Do not edit by hand.
/// Conversation query and local conversation state.
public protocol ConversationsApiProtocol: AnyObject {
    func listConversations() async throws -> ListConversationsResponse
    func listConversationsByQuery(_ request: ConversationListQuery) async throws -> ListConversationsResponse
    func listConversationsIncludingArchived() async throws -> ListConversationsResponse
    func getConversation(_ request: [String: AnySendable]) async throws -> Conversation
    func getOneConversation(_ request: [String: AnySendable]) async throws -> Conversation
    func getGroupConversationByUserIds(_ request: [String: AnySendable]) async throws -> Conversation
    func getMultipleConversations(_ request: [String: AnySendable]) async throws -> ListConversationsResponse
    func listConversationsPaginated(_ request: [String: AnySendable]) async throws -> ListConversationsResponse
    func listRawConversations() async throws -> ListConversationsResponse
    func getTotalUnread() async throws -> ConversationTotalUnreadResponse
    func bootstrapHomeTimeline(_ request: BootstrapHomeTimelineRequest) async throws -> HomeTimelineSnapshot
    func openConversationTimeline(_ request: OpenConversationTimelineRequest) async throws -> ConversationTimelineSnapshot
    func markConversationRead(_ request: [String: AnySendable]) async throws -> Void
    func setConversationPinned(_ request: [String: AnySendable]) async throws -> Void
    func setConversationMuted(_ request: [String: AnySendable]) async throws -> Void
    func setConversationArchived(_ request: [String: AnySendable]) async throws -> Void
    func markConversationUnread(_ request: [String: AnySendable]) async throws -> Void
    func deleteConversation(_ request: [String: AnySendable]) async throws -> Void
    func updateConversationDraft(_ request: UpdateConversationDraftRequest) async throws -> Void
    func clearLocalChatHistory(_ request: [String: AnySendable]) async throws -> Void
    func clearChatHistoryForSelf(_ request: [String: AnySendable]) async throws -> Void
}
