import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// 一条到达回执：扩展收到了这条提示推送。引擎下次会话接上、回到前台或后台刷新之后读走，按 `extension` 路径上报。
/// 每行带推送发给的账号（载荷的 `uid` 与 `tenant_id`）：引擎只收当前会话这个账号的，别的账号的丢掉，不记到
/// 正好登录着的人头上。
struct NotificationReceipt: Equatable {
    /// 推送发给的用户（载荷 `uid`）。
    var userId: String
    /// 推送发给的租户（载荷 `tenant_id`）。
    var tenantId: String
    var conversationId: String
    var messageId: String
    var seq: UInt64
    var collapseId: String
    var disposition: String
    /// 扩展只收 APNs，固定为 `apns`。
    var provider: String
    /// 设备时钟的毫秒时间戳。
    var receivedAtMs: Int64

    init(payload: NotificationPayload, provider: String = "apns", receivedAtMs: Int64) {
        userId = payload.uid
        tenantId = payload.tenantId
        conversationId = payload.conversationId
        messageId = payload.messageId
        seq = payload.seq
        collapseId = payload.collapseId
        disposition = payload.disposition
        self.provider = provider
        self.receivedAtMs = receivedAtMs
    }

    /// 回执日志的一行（含换行）：`{"u":..,"n":..,"c":..,"m":..,"s":..,"k":..,"d":..,"p":..,"t":..}`。
    var line: String {
        "{\"u\":\(json(userId)),\"n\":\(json(tenantId)),"
            + "\"c\":\(json(conversationId)),\"m\":\(json(messageId)),\"s\":\(seq),\"k\":\(json(collapseId)),"
            + "\"d\":\(json(disposition)),\"p\":\(json(provider)),\"t\":\(receivedAtMs)}\n"
    }

    /// JSON 字符串字面量：引号、反斜杠与控制字符转义，其余原样（JSON 允许 UTF-8）。
    private func json(_ text: String) -> String {
        var out = "\""
        out.reserveCapacity(text.utf8.count + 2)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

/// 回执日志：`<目录>/receipts.log`，一行一个 JSON 对象，只追加。
///
/// 引擎读的时候先把它改名成 `receipts.log.reading` 再读、再删，扩展这边只管 `O_APPEND` 追加一行；
/// 文件到 64 KiB 就不再追加（引擎很久没读走时，宁可少记，不让它无限长）。
enum NotificationReceiptLog {
    static let fileName = "receipts.log"
    static let maxBytes = 64 * 1024

    /// 追加一行；目录不在、文件打不开（设备首次解锁之前）或已到上限时什么也不写，返回 false。
    @discardableResult
    static func append(_ receipt: NotificationReceipt, directory: URL) -> Bool {
        let bytes = Array(receipt.line.utf8)
        let path = directory.appendingPathComponent(fileName, isDirectory: false).path
        let descriptor = open(path, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        var status = stat()
        guard fstat(descriptor, &status) == 0, Int(status.st_size) + bytes.count <= maxBytes else { return false }
        // 一次写完整行：O_APPEND 下一次 write 落在文件末尾，不会和另一个写入者交错
        var written = 0
        while written < bytes.count {
            let result = bytes[written...].withUnsafeBytes { buffer in
                write(descriptor, buffer.baseAddress, buffer.count)
            }
            if result < 0 {
                if errno == EINTR { continue }
                return false
            }
            written += result
        }
        return true
    }
}
