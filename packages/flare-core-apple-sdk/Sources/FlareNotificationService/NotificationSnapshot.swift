import Foundation

/// 推送载荷里扩展要读的部分：`userInfo` 的顶层自定义键，取值一律转成字符串（APNs 的自定义键可能是数字）。
///
/// 与 `FlarePlatformPush` 的 `PlatformPushPayload` 同一套键；扩展不链接那个模块，这里只读用得到的几个。
struct NotificationPayload: Equatable {
    var uid: String
    var tenantId: String
    var conversationId: String
    var messageId: String
    var seq: UInt64
    var collapseId: String
    var disposition: String
    var alertClass: String
    /// 这条通知代表的未读条数；没有时为 1。
    var count: UInt32
    /// 最新那条消息的发送者；摘要、通知类与系统消息为空。
    var senderId: String
    /// 服务端正文里用的发送者名字，原样：本地据此换成自己的显示名。正文里没有发送者时为空。
    var senderName: String
    /// `direct`、`group` 或 `notice`。
    var kind: String

    init(fields: [String: String]) {
        uid = fields["uid"] ?? ""
        tenantId = fields["tenant_id"] ?? ""
        conversationId = fields["conversation_id"] ?? ""
        messageId = fields["message_id"] ?? ""
        seq = fields["seq"].flatMap { UInt64($0.trimmingCharacters(in: .whitespaces)) } ?? 0
        collapseId = fields["collapse_id"] ?? ""
        disposition = fields["disposition"] ?? ""
        alertClass = fields["alert_class"] ?? ""
        count = fields["count"].flatMap { UInt32($0.trimmingCharacters(in: .whitespaces)) } ?? 1
        senderId = fields["sender_id"] ?? ""
        senderName = fields["sender_name"] ?? ""
        kind = fields["kind"] ?? ""
    }

    init(userInfo: [AnyHashable: Any]) {
        var fields: [String: String] = [:]
        for (key, value) in userInfo {
            guard let key = key.base as? String, key != "aps", let text = Self.scalarText(value) else { continue }
            fields[key] = text
        }
        self.init(fields: fields)
    }

    /// 本 SDK 的推送带合并键或会话；应用自己的推送扩展不碰，也不记回执。
    var isFlare: Bool {
        !collapseId.isEmpty || !conversationId.isEmpty
    }

    /// 字符串原样；整数写成十进制（整数值的浮点数也写成整数）；布尔写成 `1` / `0`；其余为 nil。
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

/// 主应用的引擎写在 App Group 里的通知快照（`<目录>/snapshot.json`，版本 1）。
///
/// 扩展只读一次文件；会话与名字两张表保持解析出来的原样，用到哪一项才取哪一项，不整表转换。
struct NotificationSnapshot {
    /// 用户级的预览设置。
    enum Preview: Equatable {
        /// 发送者与内容。
        case full
        /// 只露出发送者。
        case senderOnly
        /// 发送者与内容都不露出。
        case hidden
    }

    /// 快照里的一个会话。
    struct Conversation: Equatable {
        /// 本地显示的标题。
        var title: String
        var muted: Bool
        var mentionOnly: Bool
        var group: Bool
    }

    /// 快照文件名。
    static let fileName = "snapshot.json"
    /// 引擎写的快照不超过 256 KiB；大得离谱的文件不读，扩展的内存上限只有几 MiB。
    static let maxBytes = 1024 * 1024

    var uid: String
    var tenant: String
    var locale: String
    var preview: Preview
    /// 引擎按快照语言渲染好的固定文案：`genericTitle`、`genericBody`、`sentMessage`、`mentionMarker`、`recalled`。
    var strings: [String: String]
    private var conversations: [String: Any]
    private var names: [String: Any]

    /// 读 `directory` 里的快照。文件不在、过大、坏掉或版本不认时为 nil。
    static func read(directory: URL) -> NotificationSnapshot? {
        let file = directory.appendingPathComponent(fileName, isDirectory: false)
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        // 多读一个字节：读满上限加一就是超了
        guard let data = try? handle.read(upToCount: maxBytes + 1), data.count <= maxBytes else { return nil }
        return parse(data)
    }

    /// 解析快照。不是对象、版本不是 1、没有用户或租户时为 nil。
    static func parse(_ data: Data) -> NotificationSnapshot? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              (root["v"] as? NSNumber)?.intValue == 1,
              let uid = root["uid"] as? String, !uid.isEmpty,
              let tenant = root["tenant"] as? String else {
            return nil
        }
        var strings: [String: String] = [:]
        for (key, value) in root["strings"] as? [String: Any] ?? [:] {
            if let text = value as? String { strings[key] = text }
        }
        return NotificationSnapshot(
            uid: uid,
            tenant: tenant,
            locale: root["locale"] as? String ?? "",
            preview: preview(root["preview"]),
            strings: strings,
            conversations: root["conversations"] as? [String: Any] ?? [:],
            names: root["names"] as? [String: Any] ?? [:]
        )
    }

    /// 没写按完整处理；认不出的取值按隐藏：宁可少露，不可多露。
    private static func preview(_ value: Any?) -> Preview {
        guard let text = value as? String else { return .full }
        switch text {
        case "full": return .full
        case "sender_only": return .senderOnly
        default: return .hidden
        }
    }

    /// 会话的本地信息；快照里没有时为 nil。
    func conversation(_ conversationId: String) -> Conversation? {
        guard !conversationId.isEmpty, let row = conversations[conversationId] as? [String: Any] else { return nil }
        return Conversation(
            title: row["t"] as? String ?? "",
            muted: (row["m"] as? NSNumber)?.boolValue ?? false,
            mentionOnly: (row["o"] as? NSNumber)?.boolValue ?? false,
            group: (row["g"] as? NSNumber)?.boolValue ?? false
        )
    }

    /// 用户的本地显示名（备注优先）；没有或为空时为 nil。
    func name(_ userId: String) -> String? {
        guard !userId.isEmpty, let name = names[userId] as? String, !name.isEmpty else { return nil }
        return name
    }

    /// 非空的固定文案；快照里没有时为 nil。
    func string(_ key: String) -> String? {
        guard let text = strings[key], !text.isEmpty else { return nil }
        return text
    }
}
