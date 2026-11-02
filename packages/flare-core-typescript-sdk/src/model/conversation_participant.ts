/** GENERATED. Do not edit by hand. */
import type { DisplayName } from './display_name';

/** SDK 本地会话参与者快照。单聊不依赖该结构；群聊/频道/客服等非单聊用它支撑群通话、成员面板和后续设置页。 */
export interface ConversationParticipant {
  /** wire: `attributes`.  */
  attributes: Record<string, string>;
  /** wire: `joinedAt`.  */
  joinedAt: number;
  /** wire: `muted`.  */
  muted: boolean;
  /** wire: `name`. 成员在这个会话里显示成什么（成员列表、@ 选择用）：别名、会话内昵称、资料名， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的成员都带它。 */
  name: DisplayName;
  /** wire: `nickname`.  */
  nickname: string;
  /** wire: `pinned`.  */
  pinned: boolean;
  /** wire: `roles`.  */
  roles: string[];
  /** wire: `userId`.  */
  userId: string;
}
