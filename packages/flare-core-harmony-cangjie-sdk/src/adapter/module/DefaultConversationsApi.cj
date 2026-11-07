package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.listener.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.

public class DefaultConversationsApi <: ConversationsApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func listConversations(): ListConversationsResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationList, requestJson: wireEncodeRequest("{}"))
        return listConversationsResponseFromJson(raw)
    }

    public func listConversationsByQuery(request: ConversationListQuery): ListConversationsResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationListByQuery, requestJson: wireEncodeRequest(conversationListQueryToJson(request)))
        return listConversationsResponseFromJson(raw)
    }

    public func listConversationsIncludingArchived(): ListConversationsResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationListIncludingArchived, requestJson: wireEncodeRequest("{}"))
        return listConversationsResponseFromJson(raw)
    }

    public func getConversation(requestJson: String): Conversation {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationGet, requestJson: wireEncodeRequest(requestJson))
        return conversationFromJson(raw)
    }

    public func getOneConversation(requestJson: String): Conversation {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationGetOne, requestJson: wireEncodeRequest(requestJson))
        return conversationFromJson(raw)
    }

    public func getGroupConversationByUserIds(requestJson: String): Conversation {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationGetGroupByUserIds, requestJson: wireEncodeRequest(requestJson))
        return conversationFromJson(raw)
    }

    public func getMultipleConversations(requestJson: String): ListConversationsResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationGetMultiple, requestJson: wireEncodeRequest(requestJson))
        return listConversationsResponseFromJson(raw)
    }

    public func listConversationsPaginated(requestJson: String): ListConversationsResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationListPaginated, requestJson: wireEncodeRequest(requestJson))
        return listConversationsResponseFromJson(raw)
    }

    public func listRawConversations(): ListConversationsResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationListRaw, requestJson: wireEncodeRequest("{}"))
        return listConversationsResponseFromJson(raw)
    }

    public func getTotalUnread(): ConversationTotalUnreadResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationTotalUnread, requestJson: wireEncodeRequest("{}"))
        let object = wireDecodeResponseObject(jsonObjectFromRaw(raw))
        return ConversationTotalUnreadResponse(totalUnread: UInt64(jsonIntField(object, "totalUnread", 0)))
    }

    public func bootstrapHomeTimeline(request: BootstrapHomeTimelineRequest): HomeTimelineSnapshot {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationBootstrapHome, requestJson: wireEncodeRequest(bootstrapHomeTimelineRequestToJson(request)))
        return homeTimelineSnapshotFromJson(raw)
    }

    public func openConversationTimeline(request: OpenConversationTimelineRequest): ConversationTimelineSnapshot {
        let raw = bridge.invoke(descriptor: NativeCallMap.conversationOpenTimeline, requestJson: wireEncodeRequest(openConversationTimelineRequestToJson(request)))
        return conversationTimelineSnapshotFromJson(raw)
    }

    public func markConversationRead(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.conversationMarkRead, requestJson: wireEncodeRequest(requestJson))
    }

    public func setConversationPinned(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.conversationSetPinned, requestJson: wireEncodeRequest(requestJson))
    }

    public func setConversationMuted(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.conversationSetMuted, requestJson: wireEncodeRequest(requestJson))
    }

    public func setConversationArchived(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.conversationSetArchived, requestJson: wireEncodeRequest(requestJson))
    }

    public func markConversationUnread(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.conversationMarkUnread, requestJson: wireEncodeRequest(requestJson))
    }

    public func deleteConversation(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.conversationDelete, requestJson: wireEncodeRequest(requestJson))
    }

    public func updateConversationDraft(request: UpdateConversationDraftRequest): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.conversationUpdateDraft, requestJson: wireEncodeRequest(updateConversationDraftRequestToJson(request)))
    }

    public func clearLocalChatHistory(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.conversationClearLocalChatHistory, requestJson: wireEncodeRequest(requestJson))
    }

    public func clearChatHistoryForSelf(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.conversationClearChatHistoryForSelf, requestJson: wireEncodeRequest(requestJson))
    }

}
