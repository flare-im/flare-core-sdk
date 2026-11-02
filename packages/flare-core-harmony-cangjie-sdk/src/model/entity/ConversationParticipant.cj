package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// SDK 本地会话参与者快照。单聊不依赖该结构；群聊/频道/客服等非单聊用它支撑群通话、成员面板和后续设置页。
public class ConversationParticipant {
    // wire: `attributes`. 
    public let attributes: String
    // wire: `joinedAt`. 
    public let joinedAt: UInt64
    // wire: `muted`. 
    public let muted: Bool
    // wire: `name`. 成员在这个会话里显示成什么（成员列表、@ 选择用）：别名、会话内昵称、资料名， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的成员都带它。
    public let name: DisplayName
    // wire: `nickname`. 
    public let nickname: String
    // wire: `pinned`. 
    public let pinned: Bool
    // wire: `roles`. 
    public let roles: String
    // wire: `userId`. 
    public let userId: String

    public init(attributes!: String, joinedAt!: UInt64, muted!: Bool, name!: DisplayName, nickname!: String, pinned!: Bool, roles!: String, userId!: String) {
        this.attributes = attributes
        this.joinedAt = joinedAt
        this.muted = muted
        this.name = name
        this.nickname = nickname
        this.pinned = pinned
        this.roles = roles
        this.userId = userId
    }
}
