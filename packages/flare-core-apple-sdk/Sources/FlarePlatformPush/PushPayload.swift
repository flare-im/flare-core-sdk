import Foundation

/// 推送载荷的读法。所有通道带同一组 snake_case 键（`uid`、`conversation_id`、`collapse_id`、`disposition`……），
/// 交给引擎的是全部取值为字符串的平面字典。
public enum PlatformPushPayload {
    /// 把 `userInfo` 的顶层自定义键转成字符串字典。
    ///
    /// APNs 的自定义键可能是数字，写成十进制；`aps` 不进字典，只把 `aps.alert` 的标题正文抄成 `title`、`body`
    /// （APNs 的服务端文案只在那里）。数组、字典这类嵌套值丢弃。
    public static func flatten(_ userInfo: [AnyHashable: Any]) -> [String: String] {
        var payload: [String: String] = [:]
        for (key, value) in userInfo {
            guard let key = key.base as? String, key != "aps", let text = scalarText(value) else { continue }
            payload[key] = text
        }
        if let aps = userInfo["aps"] as? [String: Any] {
            switch aps["alert"] {
            case let alert as [String: Any]:
                if let title = alert["title"] as? String { payload["title"] = title }
                if let body = alert["body"] as? String { payload["body"] = body }
            case let body as String:
                payload["body"] = body
            default:
                break
            }
        }
        return payload
    }

    /// 是否为本 SDK 的推送。应用自己当系统通知中心的代理时，用它决定要不要转给 `PlatformPush`。
    public static func isFlare(userInfo: [AnyHashable: Any]) -> Bool {
        isFlare(payload: flatten(userInfo))
    }

    static func isFlare(payload: [String: String]) -> Bool {
        !(payload["collapse_id"] ?? "").isEmpty || !(payload["conversation_id"] ?? "").isEmpty
    }

    /// 带 `aps.alert` 的推送由系统展示（或在前台交给 willPresent 决定），应用代码不再补一条。
    static func carriesAlert(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let aps = userInfo["aps"] as? [String: Any], let alert = aps["alert"] else { return false }
        return !(alert is NSNull)
    }

    /// 没有宿主可问时（推送把进程冷启动起来、会话还没恢复）按载荷原样得出的结果，保证提示不丢。
    static func outcome(fromPayload payload: [String: String]) -> PlatformPushOutcome {
        let collapseId = payload["collapse_id"] ?? ""
        let badge = payload["badge"].flatMap { UInt32($0) }
        let disposition = payload["disposition"] ?? ""
        let action: PlatformPushOutcome.Action
        switch disposition {
        case "quiet", "recall_replace":
            action = .update
        case "clear":
            return PlatformPushOutcome(action: .clear, clearCollapseIds: collapseId.isEmpty ? [] : [collapseId], badge: badge)
        case "badge_only":
            return PlatformPushOutcome(action: .badgeOnly, badge: badge)
        default:
            // `loud`、`digest`，以及认不出的处置：宁可多提示一次
            action = .present
        }
        let title = payload["title"] ?? ""
        let body = payload["body"] ?? ""
        guard !title.isEmpty || !body.isEmpty else {
            return PlatformPushOutcome(action: badge == nil ? .ignore : .badgeOnly, badge: badge, reason: "malformed")
        }
        let channel: PlatformNotificationPresentation.Channel
        switch payload["alert_class"] {
        case "mention": channel = .mentions
        case "urgent": channel = .urgent
        default: channel = disposition == "quiet" ? .quiet : .messages
        }
        let presentation = PlatformNotificationPresentation(
            collapseId: collapseId,
            threadId: payload["thread_id"].flatMap { $0.isEmpty ? nil : $0 } ?? collapseId,
            conversationId: payload["conversation_id"] ?? "",
            messageId: payload["message_id"] ?? "",
            seq: payload["seq"].flatMap { UInt64($0) } ?? 0,
            title: title,
            body: body,
            count: payload["count"].flatMap { UInt32($0) } ?? 1,
            sound: action == .present && payload["sound"] == "1",
            channel: channel,
            surface: .system
        )
        return PlatformPushOutcome(action: action, presentation: presentation, badge: badge)
    }

    /// 字符串原样；数字写成十进制（整数值的浮点数也写成整数）；布尔写成 `1` / `0`；其余为 nil。
    private static func scalarText(_ value: Any) -> String? {
        switch value {
        case let text as String:
            return text
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "1" : "0"
            }
            if CFNumberIsFloatType(number as CFNumber) {
                let double = number.doubleValue
                if double.isFinite, double.rounded() == double, abs(double) < 9_007_199_254_740_992 {
                    return String(Int64(double))
                }
            }
            return number.stringValue
        default:
            return nil
        }
    }
}
