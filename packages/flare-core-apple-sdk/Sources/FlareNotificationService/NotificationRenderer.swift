import Foundation

/// 通知的标题与正文。
struct NotificationText: Equatable {
    var title: String
    var body: String
}

/// 按通知快照重渲染一条提示推送的标题与正文。纯函数：不读文件、不看时钟。
///
/// 服务端不知道本地的会话标题与联系人备注，也可能还没拿到刚改的预览设置；快照补上这两样：
/// - 标题取会话在本地显示的标题（`conversations[c].t`）；服务端标题前的条数（`[3条] `）保留。
/// - 预览设置按快照：
///   - `hidden`：标题 `genericTitle`，正文 `genericBody`；
///   - `sender_only`：正文 `sentMessage`，群聊里前面接上发送者的本地名字，点名到自己时加 `mentionMarker`；
///     通知类内容没有发送者可说，正文用 `genericBody`；
///   - `full`：服务端正文，其中的 `sender_name` 换成 `names[sender_id]`。
/// - 撤回替换的正文用 `recalled`；摘要只由条数生成，原样不动。
/// 其余（声音、角标、分组、载荷）一概不碰。
enum NotificationRenderer {
    /// 重渲染后的文案；没有快照、快照属于别的账号、或是摘要时为 nil：载荷原样送出。
    static func render(
        title: String,
        body: String,
        payload: NotificationPayload,
        snapshot: NotificationSnapshot?
    ) -> NotificationText? {
        guard let snapshot,
              !payload.uid.isEmpty,
              snapshot.uid == payload.uid,
              snapshot.tenant == payload.tenantId,
              payload.disposition != "digest" else {
            return nil
        }
        let prefix = countPrefix(of: title, count: payload.count)
        let serverTitle = String(title.dropFirst(prefix.count))
        let conversation = snapshot.conversation(payload.conversationId)
        let localName = snapshot.name(payload.senderId)
        let recall = payload.disposition == "recall_replace"

        if snapshot.preview == .hidden {
            return NotificationText(
                title: prefix + (snapshot.string("genericTitle") ?? serverTitle),
                body: recall ? snapshot.string("recalled") ?? body : snapshot.string("genericBody") ?? body
            )
        }

        // 会话标题优先；快照里没有这个会话时，服务端标题里的发送者名字换成本地名字
        let shownTitle = conversation.map(\.title).flatMap { $0.isEmpty ? nil : $0 }
            ?? substitute(payload.senderName, with: localName, in: serverTitle)
        let shownBody: String
        if recall {
            shownBody = snapshot.string("recalled") ?? body
        } else if snapshot.preview == .senderOnly {
            shownBody = senderOnlyBody(
                payload: payload,
                snapshot: snapshot,
                group: conversation?.group ?? (payload.kind == "group"),
                senderName: localName ?? nonEmpty(payload.senderName),
                fallback: body
            )
        } else {
            shownBody = substitute(payload.senderName, with: localName, in: body)
        }
        return NotificationText(title: prefix + shownTitle, body: shownBody)
    }

    /// 只露出发送者时的正文。「发来一条消息」接在标题后面读：单聊的标题就是对方；群聊的标题是群，
    /// 所以把发送者写在正文前面。
    private static func senderOnlyBody(
        payload: NotificationPayload,
        snapshot: NotificationSnapshot,
        group: Bool,
        senderName: String?,
        fallback: String
    ) -> String {
        if payload.kind == "notice" {
            return snapshot.string("genericBody") ?? fallback
        }
        guard let sentMessage = snapshot.string("sentMessage") else {
            return snapshot.string("genericBody") ?? fallback
        }
        var text = sentMessage
        if group, let senderName {
            text = "\(senderName) \(text)"
        }
        if payload.alertClass == "mention", let marker = snapshot.string("mentionMarker") {
            text = "\(marker) \(text)"
        }
        return text
    }

    /// 服务端标题前的条数前缀（`[3条] `、`[99+ messages] `），一条通知代表两条以上未读时才有；没有时为空串。
    static func countPrefix(of title: String, count: UInt32) -> String {
        guard count >= 2,
              title.hasPrefix("["),
              title.dropFirst().first?.isNumber == true,
              let close = title.range(of: "] ") else {
            return ""
        }
        return String(title[..<close.upperBound])
    }

    /// 把 `text` 里第一次出现的 `serverName` 换成 `localName`；任何一个为空时原样返回。
    /// 只换第一处：名字之后是消息本身，里面碰巧出现的同样文字不动。
    static func substitute(_ serverName: String, with localName: String?, in text: String) -> String {
        guard !serverName.isEmpty,
              let localName, !localName.isEmpty, localName != serverName,
              let range = text.range(of: serverName) else {
            return text
        }
        return text.replacingCharacters(in: range, with: localName)
    }

    private static func nonEmpty(_ text: String) -> String? {
        text.isEmpty ? nil : text
    }
}
