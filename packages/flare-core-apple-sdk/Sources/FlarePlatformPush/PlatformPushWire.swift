import Foundation

/// 引擎契约的 JSON（驼峰键）与本模块值类型之间的转换，与 Android 的 `PlatformPushWire` 同一套规则。
///
/// 经 JSON 透传的宿主（社交 SDK 的 IM 分发、Flutter 的方法通道）用它，免得各写一份；类型化的核心客户端不经过这里。
/// 写出的整数一律是有符号 64 位：Flutter 方法通道的编解码器不认无符号 64 位，JSON 两种都认。
public enum PlatformPushWire {
    /// `PushTokenInput` 的请求体；为 nil 的可选字段与空的能力列表不带。
    public static func tokenRequest(_ token: PlatformPushToken) -> [String: Any] {
        var wire: [String: Any] = [
            "provider": token.provider,
            "platform": token.platform,
            "token": token.token,
        ]
        if let appBundle = token.appBundle { wire["appBundle"] = appBundle }
        if let environment = token.environment { wire["environment"] = environment }
        if let locale = token.locale { wire["locale"] = locale }
        if let timeZone = token.timeZone { wire["timeZone"] = timeZone }
        if let appVersion = token.appVersion { wire["appVersion"] = appVersion }
        if !token.capabilities.isEmpty { wire["capabilities"] = token.capabilities }
        return wire
    }

    /// `RemoteMessageOutcome`。认不出的动作当作什么都不做：宁可不提示，也不按猜测提示。
    ///
    /// 不是 JSON 对象时抛 `PlatformPushWireError`：宿主据此按失败处理，平台模块改按载荷提示，提示不丢。
    public static func outcome(_ wire: Any?) throws -> PlatformPushOutcome {
        guard let row = object(wire) else {
            throw PlatformPushWireError(expected: "RemoteMessageOutcome")
        }
        let action = text(row["action"]).flatMap(PlatformPushOutcome.Action.init(rawValue:)) ?? .ignore
        return PlatformPushOutcome(
            action: action,
            presentation: presentation(row["presentation"]),
            clearCollapseIds: (row["clearCollapseIds"] as? [Any] ?? []).compactMap { text($0) },
            badge: unsigned(row["badge"]).map { UInt32(clamping: $0) },
            reason: text(row["reason"])
        )
    }

    /// `NotificationPresentation`；没有合并键的展示意图落不成通知，按缺失处理（nil）。
    public static func presentation(_ wire: Any?) -> PlatformNotificationPresentation? {
        guard let row = object(wire), let collapseId = text(row["collapseId"]) else { return nil }
        return PlatformNotificationPresentation(
            collapseId: collapseId,
            threadId: text(row["threadId"]) ?? collapseId,
            conversationId: string(row["conversationId"]),
            messageId: string(row["messageId"]),
            seq: unsigned(row["seq"]) ?? 0,
            title: string(row["title"]),
            body: string(row["body"]),
            count: max(unsigned(row["count"]).map { UInt32(clamping: $0) } ?? 1, 1),
            sound: bool(row["sound"]) ?? false,
            channel: text(row["channel"]).flatMap(PlatformNotificationPresentation.Channel.init(rawValue:))
                ?? .messages,
            surface: text(row["surface"]).flatMap(PlatformNotificationPresentation.Surface.init(rawValue:))
                ?? .system
        )
    }

    /// `NotificationTapResult`；没有会话（载荷不属于当前账号）或不是对象时为 nil。
    public static func tapRoute(_ wire: Any?) -> PlatformTapRoute? {
        guard let row = object(wire), let conversationId = text(row["conversationId"]) else { return nil }
        return PlatformTapRoute(
            conversationId: conversationId,
            messageId: text(row["messageId"]),
            seq: unsigned(row["seq"])
        )
    }

    /// `notification.clear` 的载荷 `{collapseIds, all}`。`all` 为真是全部撤掉；既不是全部、也没有合并键时为 nil。
    public static func clearCorrection(_ wire: Any?) -> PlatformNotificationCorrection? {
        guard let row = object(wire) else { return nil }
        if bool(row["all"]) == true { return .clearAll }
        let collapseIds = (row["collapseIds"] as? [Any] ?? []).compactMap { text($0) }
        return collapseIds.isEmpty ? nil : .clear(collapseIds: collapseIds)
    }

    /// `notification.badge` 的载荷 `{count}`；没有可读的角标数时为 nil。
    public static func badgeCorrection(_ wire: Any?) -> PlatformNotificationCorrection? {
        guard let row = object(wire), let count = unsigned(row["count"]) else { return nil }
        return .badge(UInt32(clamping: count))
    }

    /// `tapRoute(_:)` 的反向：`NotificationTapResult` 的形状。
    public static func tapResult(_ route: PlatformTapRoute) -> [String: Any] {
        var wire: [String: Any] = ["conversationId": route.conversationId]
        if let messageId = route.messageId { wire["messageId"] = messageId }
        if let seq = route.seq { wire["seq"] = Int64(clamping: seq) }
        return wire
    }

    // MARK: - 取值

    private static func object(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    /// 非空白的字符串。
    private static func text(_ value: Any?) -> String? {
        guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    private static func string(_ value: Any?) -> String {
        value as? String ?? ""
    }

    /// u64 可能以数字或字符串到达；负数与布尔不算。
    private static func unsigned(_ value: Any?) -> UInt64? {
        switch value {
        case let text as String:
            return UInt64(text.trimmingCharacters(in: .whitespacesAndNewlines))
        case let number as NSNumber:
            guard CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue >= 0 else { return nil }
            return number.uint64Value
        default:
            return nil
        }
    }

    private static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let flag as Bool:
            return flag
        case let number as NSNumber:
            return number.intValue != 0
        case let text as String:
            switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1": return true
            case "false", "0": return false
            default: return nil
            }
        default:
            return nil
        }
    }
}

/// 宿主的答复不是契约要的形状。
public struct PlatformPushWireError: Error, Equatable, CustomStringConvertible {
    /// 期待的契约类型，例如 `RemoteMessageOutcome`。
    public let expected: String

    public init(expected: String) {
        self.expected = expected
    }

    public var description: String { "push wire: expected a \(expected) object" }
}
