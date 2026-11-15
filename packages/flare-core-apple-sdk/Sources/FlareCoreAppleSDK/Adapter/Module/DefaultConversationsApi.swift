import Foundation

/// GENERATED. Do not edit by hand.
// Models: BootstrapHomeTimelineRequest, Conversation, ConversationListQuery, ConversationTimelineSnapshot, ConversationTotalUnreadResponse, HomeTimelineSnapshot, ListConversationsResponse, OpenConversationTimelineRequest
public final class DefaultConversationsApi: ConversationsApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func listConversations() async throws -> ListConversationsResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationList, request: nil)
        return try listConversationsResponseFromJson(raw)
    }

    public func listConversationsByQuery(_ request: ConversationListQuery) async throws -> ListConversationsResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationListByQuery, request: unwrapRequest(AnySendable(conversationListQueryToMap(request))))
        return try listConversationsResponseFromJson(raw)
    }

    public func listConversationsIncludingArchived() async throws -> ListConversationsResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationListIncludingArchived, request: nil)
        return try listConversationsResponseFromJson(raw)
    }

    public func getConversation(_ request: [String: AnySendable]) async throws -> Conversation {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationGet, request: unwrapRequest(AnySendable(request)))
        if let first = listOfMaps(plainMap(raw)["conversations"]).first {
            return try conversationFromJson(first)
        }
        return try conversationFromJson(raw)
    }

    public func getOneConversation(_ request: [String: AnySendable]) async throws -> Conversation {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationGetOne, request: unwrapRequest(AnySendable(request)))
        if let first = listOfMaps(plainMap(raw)["conversations"]).first {
            return try conversationFromJson(first)
        }
        return try conversationFromJson(raw)
    }

    public func getGroupConversationByUserIds(_ request: [String: AnySendable]) async throws -> Conversation {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationGetGroupByUserIds, request: unwrapRequest(AnySendable(request)))
        if let first = listOfMaps(plainMap(raw)["conversations"]).first {
            return try conversationFromJson(first)
        }
        return try conversationFromJson(raw)
    }

    public func getMultipleConversations(_ request: [String: AnySendable]) async throws -> ListConversationsResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationGetMultiple, request: unwrapRequest(AnySendable(request)))
        return try listConversationsResponseFromJson(raw)
    }

    public func listConversationsPaginated(_ request: [String: AnySendable]) async throws -> ListConversationsResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationListPaginated, request: unwrapRequest(AnySendable(request)))
        return try listConversationsResponseFromJson(raw)
    }

    public func listRawConversations() async throws -> ListConversationsResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationListRaw, request: nil)
        return try listConversationsResponseFromJson(raw)
    }

    public func getTotalUnread() async throws -> ConversationTotalUnreadResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationTotalUnread, request: nil)
        return ConversationTotalUnreadResponse(totalUnread: try intValue(plainMap(raw)["totalUnread"]))
    }

    public func bootstrapHomeTimeline(_ request: BootstrapHomeTimelineRequest) async throws -> HomeTimelineSnapshot {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationBootstrapHome, request: unwrapRequest(AnySendable(bootstrapHomeTimelineRequestToMap(request))))
        return try homeTimelineSnapshotFromJson(raw)
    }

    public func openConversationTimeline(_ request: OpenConversationTimelineRequest) async throws -> ConversationTimelineSnapshot {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.conversationOpenTimeline, request: unwrapRequest(AnySendable(openConversationTimelineRequestToMap(request))))
        return try conversationTimelineSnapshotFromJson(raw)
    }

    public func markConversationRead(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationMarkRead, request: AnySendable(request))
    }

    public func setConversationPinned(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationSetPinned, request: AnySendable(request))
    }

    public func setConversationMuted(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationSetMuted, request: AnySendable(request))
    }

    public func setConversationNotifyAll(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationSetNotifyAll, request: AnySendable(request))
    }

    public func setConversationArchived(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationSetArchived, request: AnySendable(request))
    }

    public func markConversationUnread(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationMarkUnread, request: AnySendable(request))
    }

    public func deleteConversation(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationDelete, request: AnySendable(request))
    }

    public func updateConversationDraft(_ request: UpdateConversationDraftRequest) async throws -> Void {
        try await invokeVoid(
            bridge,
            descriptor: NativeCallMap.conversationUpdateDraft,
            request: AnySendable(updateConversationDraftRequestToMap(request).mapValues { $0.value })
        )
    }

    public func clearLocalChatHistory(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationClearLocalChatHistory, request: AnySendable(request))
    }

    public func clearChatHistoryForSelf(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.conversationClearChatHistoryForSelf, request: AnySendable(request))
    }

}
