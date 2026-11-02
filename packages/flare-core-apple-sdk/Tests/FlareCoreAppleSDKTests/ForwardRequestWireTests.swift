import XCTest
@testable import FlareCoreAppleSDK

/// 转发请求必须把**完整消息**编进线上，而不是 id 存根。
///
/// 核心侧的 forward_item_from_source 会读 content / senderId / conversationId；
/// 早先契约传 { sourceMessageId }，反序列化成 IMMessage 时缺必填字段直接
/// INVALID_PARAMETER，转发每次都失败，所以契约改成了 Message。
///
/// 但 Swift 编解码器没跟着改，仍在调 forwardSourceMessageToMap —— 类型对不上，
/// 整个 FlareCoreAppleSDK 编译不过，iOS app 根本构建不起来。
/// 这条用例锁住「编的是完整消息」，编译不过时也会第一时间指向这里。
final class ForwardRequestWireTests: XCTestCase {

    func testForwardRequestCarriesFullMessagesNotIdStubs() {
        let source = Message(
            clientMsgId: "c-1",
            conversationId: "conv-1",
            sender: DisplayName(kind: .unnamed, entity: .person, idTail: "u-1"),
            senderId: "u-1",
            serverId: "s-1"
        )
        let request = BuildForwardMessageRequest(
            conversationId: "conv-2",
            merge: false,
            title: "t",
            sourceMessages: [source]
        )

        let wire = buildForwardMessageRequestToMap(request)
        guard let list = wire["sourceMessages"]?.value as? [[String: Any]], let first = list.first else {
            return XCTFail("sourceMessages 应当编成一组 map")
        }

        // 核心要靠这几个字段还原原文，缺一个转发就会 INVALID_PARAMETER
        XCTAssertNotNil(first["conversationId"], "缺 conversationId：核心无法定位原会话")
        XCTAssertNotNil(first["senderId"], "缺 senderId：核心无法还原原发送者")
        XCTAssertNil(first["sourceMessageId"], "这是 id 存根的字段，说明编错了编码器")
    }
}
