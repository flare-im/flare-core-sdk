// GENERATED. Do not edit by hand.
import 'display_name.dart';

/// SDK 本地会话参与者快照。单聊不依赖该结构；群聊/频道/客服等非单聊用它支撑群通话、成员面板和后续设置页。
final class ConversationParticipant {
  /// wire: `attributes`. 
  final Map<String, String> attributes;
  /// wire: `joinedAt`. 
  final int joinedAt;
  /// wire: `muted`. 
  final bool muted;
  /// wire: `name`. 成员在这个会话里显示成什么（成员列表、@ 选择用）：别名、会话内昵称、资料名， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的成员都带它。
  final DisplayName name;
  /// wire: `nickname`. 
  final String nickname;
  /// wire: `pinned`. 
  final bool pinned;
  /// wire: `roles`. 
  final List<String> roles;
  /// wire: `userId`. 
  final String userId;

  const ConversationParticipant({
    this.attributes = const {},
    this.joinedAt = 0,
    this.muted = false,
    required this.name,
    this.nickname = '',
    this.pinned = false,
    this.roles = const [],
    this.userId = '',
  });
}
