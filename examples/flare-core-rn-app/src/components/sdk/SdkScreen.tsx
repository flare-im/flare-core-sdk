import React from 'react';
import { Text, View } from 'react-native';
import Button from '@ant-design/react-native/lib/button';
import InputItem from '@ant-design/react-native/lib/input-item';
import List from '@ant-design/react-native/lib/list';
import Tag from '@ant-design/react-native/lib/tag';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import type { MessageBuildCatalogEntry } from '@flare-im/sdk/model';
import { MessageBuildOp } from '@flare-im/sdk/model';
import { styles } from '../../styles';
import { colors } from '../../theme/tokens';
import {
  RN_CAPABILITY_OPERATIONS,
  RN_CONNECTION_OPERATIONS,
  RN_MEDIA_LAB_OPERATIONS,
  RN_MESSAGE_DISPATCH_OPERATIONS,
  RN_SDK_LAB_TABS,
  RN_SESSION_OPERATIONS,
  type RnCapabilityOperation,
  type RnConnectionOperation,
  type RnMediaLabOperation,
  type RnMessageDispatchOperation,
  type RnSessionOperation,
} from '../../application/workbench/h5Parity';
import type { ConversationItem, SdkLabInputs, SdkStatus } from '../../types';
import { connectionText, statusColor } from '../../utils';
import { KeyValue } from '../common';

const BUILDER_OPS = [
  MessageBuildOp.CreateText,
  MessageBuildOp.CreateQuote,
  MessageBuildOp.CreateEmoji,
  MessageBuildOp.CreateSticker,
  MessageBuildOp.CreateImage,
  MessageBuildOp.CreateImageGroup,
  MessageBuildOp.CreateVideo,
  MessageBuildOp.CreateAudio,
  MessageBuildOp.CreateFile,
  MessageBuildOp.CreateRichDoc,
  MessageBuildOp.CreateLocation,
  MessageBuildOp.CreateLinkCard,
  MessageBuildOp.CreateCard,
  MessageBuildOp.CreateMiniProgram,
  MessageBuildOp.CreateSystem,
  MessageBuildOp.CreateNotification,
  MessageBuildOp.CreateAnnouncement,
  MessageBuildOp.CreateVote,
  MessageBuildOp.CreateTask,
  MessageBuildOp.CreateSchedule,
  MessageBuildOp.CreateCustom,
  MessageBuildOp.CreatePlaceholder,
];

const dispatchLabels: Record<RnMessageDispatchOperation, string> = {
  search: '全局搜索',
  search_in_conversation: '会话搜索',
  get: '读取消息',
  get_raw: '原始消息',
  edit_text_by_message_id: '编辑文本',
  edit_rich_doc_by_message_id: '编辑富文本',
  delete_for_self: '仅自己删除',
  delete_for_everyone: '所有人删除',
  add_reaction: '添加反应',
  remove_reaction: '移除反应',
  pin_by_message_id: '置顶消息',
  unpin_by_message_id: '取消置顶',
  mark_by_message_id: '标记消息',
  mark_with_color: '彩色标记',
  unmark_by_message_id: '取消标记',
  typing: '输入中',
  mark_read: '标记已读',
  mark_read_and_burn: '已读即焚',
};

const mediaLabels: Record<RnMediaLabOperation, string> = {
  stats: '缓存统计',
  upload_file: '上传文件',
  upload_image: '上传图片',
  upload_video: '上传视频',
  upload_bytes: '上传字节',
  delete_file: '删除文件',
  url: '访问 URL',
  temp_url: '临时 URL',
  resolve: '解析访问',
  display_url: '展示 URL',
  cache_remote: '缓存远端',
  set_root: '设置缓存根',
  set_max: '设置缓存上限',
  download_subfolder: '下载目录',
  download_file: '下载文件',
  cancel_download: '取消下载',
  saved_path: '保存路径',
  delete_download: '删除下载',
  clear: '清理缓存',
};

const capabilityLabels: Record<RnCapabilityOperation, string> = {
  list: '全部能力',
  list_user: '用户能力',
  dispatch: '能力派发',
  grant: '授权能力',
  revoke: '撤销能力',
};

const connectionLabels: Record<RnConnectionOperation, string> = {
  status: '连接状态',
  reconnect_now: '立即重连',
  disconnect: '断开连接',
  access_status: '接入状态',
  access_points: '接入点',
  access_diagnostics: '导出诊断',
};

const sessionLabels: Record<RnSessionOperation, string> = {
  current_user: '当前用户',
  session_active: '会话活跃',
  runtime_health: '运行健康',
  heartbeat_interval: '心跳间隔',
  heartbeat_nat_timeout: 'NAT 超时',
  update_access_token: '刷新 Token',
};

export function SdkScreen(props: {
  sdkStatus: SdkStatus;
  sdkMessage: string;
  sdkDiagnostics: Record<string, string>;
  activeConversation?: ConversationItem;
  messageCount: number;
  latestMessageId: string;
  onInitialize: () => void;
  sdkLabInputs: SdkLabInputs;
  sdkLabResult: string;
  messageBuildCatalog: MessageBuildCatalogEntry[];
  onUpdateSdkLabInputs: (patch: Partial<SdkLabInputs>) => void;
  onRunBuilderOp: (op: MessageBuildOp | string) => void;
  onRunMessageDispatch: (op: RnMessageDispatchOperation) => void;
  onRunMediaOperation: (op: RnMediaLabOperation) => void;
  onRunCapabilityOperation: (op: RnCapabilityOperation) => void;
  onRunConnectionOperation: (op: RnConnectionOperation) => void;
  onRunSessionOperation: (op: RnSessionOperation) => void;
  onRunEventOperation: () => void;
}) {
  const supportedBuilderOps = props.messageBuildCatalog.length
    ? BUILDER_OPS.filter((op) => props.messageBuildCatalog.some((entry) => entry.op === op))
    : BUILDER_OPS;

  return (
    <>
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.sectionTitle}>SDK 运行状态</Text>
          <Tag selected>{connectionText(props.sdkStatus)}</Tag>
        </View>
        <Text style={[styles.statusLine, { color: statusColor(props.sdkStatus) }]}>{props.sdkMessage}</Text>
        <Button type="primary" size="small" onPress={props.onInitialize}>
          初始化 SDK Client
        </Button>
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>诊断快照</Text>
        <KeyValue label="conversationId" value={props.activeConversation?.id ?? '-'} />
        <KeyValue label="channel" value={props.activeConversation?.channelId ?? '-'} />
        <KeyValue label="messages" value={String(props.messageCount)} />
        <KeyValue label="latestMessage" value={props.latestMessageId || '-'} />
        <KeyValue label="sdkVersion" value={props.sdkDiagnostics.sdkVersion ?? '-'} />
        <KeyValue label="ffiContract" value={props.sdkDiagnostics.ffiContract ?? '-'} />
        <KeyValue label="dataRoot" value={props.sdkDiagnostics.dataRoot ?? '-'} />
        <KeyValue label="runtimeHealth" value={props.sdkDiagnostics.runtimeHealth ?? '-'} />
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>SDK Lab 输入</Text>
        <List styles={{ Body: styles.inputListBody }}>
          <InputItem
            clear
            value={props.sdkLabInputs.messageText}
            placeholder="消息正文 / 构建参数"
            onChange={(messageText) => props.onUpdateSdkLabInputs({ messageText })}
          >
            Text
          </InputItem>
          <InputItem
            clear
            value={props.sdkLabInputs.query}
            placeholder="搜索关键词"
            onChange={(query) => props.onUpdateSdkLabInputs({ query })}
          >
            Query
          </InputItem>
          <InputItem
            clear
            value={props.sdkLabInputs.messageId || props.latestMessageId}
            placeholder="messageId"
            onChange={(messageId) => props.onUpdateSdkLabInputs({ messageId })}
          >
            MsgId
          </InputItem>
          <InputItem
            clear
            value={props.sdkLabInputs.reaction}
            placeholder="👍"
            onChange={(reaction) => props.onUpdateSdkLabInputs({ reaction })}
          >
            Emoji
          </InputItem>
          <InputItem
            clear
            value={props.sdkLabInputs.fileId}
            placeholder="fileId"
            onChange={(fileId) => props.onUpdateSdkLabInputs({ fileId })}
          >
            File
          </InputItem>
          <InputItem
            clear
            value={props.sdkLabInputs.mediaUrl}
            placeholder="mediaUrl"
            onChange={(mediaUrl) => props.onUpdateSdkLabInputs({ mediaUrl })}
          >
            URL
          </InputItem>
          <InputItem
            clear
            value={props.sdkLabInputs.capability}
            placeholder="rtc.call"
            onChange={(capability) => props.onUpdateSdkLabInputs({ capability })}
          >
            Cap
          </InputItem>
          <InputItem
            clear
            value={props.sdkLabInputs.jsonParams}
            placeholder='{"key":"value"}'
            onChange={(jsonParams) => props.onUpdateSdkLabInputs({ jsonParams })}
          >
            JSON
          </InputItem>
        </List>
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>H5 SDK Lab 对齐 · {RN_SDK_LAB_TABS.length} 组</Text>
        <Text style={[styles.statusLine, { color: colors.textMuted }]}>
          diagnostics / connection-session / builder / message-dispatch / sync-presence / capability / media / events
        </Text>
        <LabButtonGrid
          items={supportedBuilderOps.map((op) => ({ key: op, label: op.replace('Create', '') }))}
          onPress={(op) => props.onRunBuilderOp(op)}
        />
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>消息分发</Text>
        <LabButtonGrid
          items={RN_MESSAGE_DISPATCH_OPERATIONS.map((op) => ({ key: op, label: dispatchLabels[op] }))}
          onPress={(op) => props.onRunMessageDispatch(op as RnMessageDispatchOperation)}
        />
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>连接 / 会话</Text>
        <LabButtonGrid
          items={RN_CONNECTION_OPERATIONS.map((op) => ({ key: op, label: connectionLabels[op] }))}
          onPress={(op) => props.onRunConnectionOperation(op as RnConnectionOperation)}
        />
        <WhiteSpace size="md" />
        <LabButtonGrid
          items={RN_SESSION_OPERATIONS.map((op) => ({ key: op, label: sessionLabels[op] }))}
          onPress={(op) => props.onRunSessionOperation(op as RnSessionOperation)}
        />
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>能力 / 媒体 / 事件</Text>
        <LabButtonGrid
          items={RN_CAPABILITY_OPERATIONS.map((op) => ({ key: op, label: capabilityLabels[op] }))}
          onPress={(op) => props.onRunCapabilityOperation(op as RnCapabilityOperation)}
        />
        <WhiteSpace size="md" />
        <LabButtonGrid
          items={RN_MEDIA_LAB_OPERATIONS.map((op) => ({ key: op, label: mediaLabels[op] }))}
          onPress={(op) => props.onRunMediaOperation(op as RnMediaLabOperation)}
        />
        <WhiteSpace size="md" />
        <Button size="small" onPress={props.onRunEventOperation}>
          订阅事件流
        </Button>
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>Lab 结果</Text>
        <Text style={styles.labResultText} selectable>
          {props.sdkLabResult || '选择上方操作查看 SDK 返回'}
        </Text>
      </View>
    </>
  );
}

function LabButtonGrid(props: {
  items: Array<{ key: string; label: string }>;
  onPress: (key: string) => void;
}) {
  return (
    <View style={styles.labButtonGrid}>
      {props.items.map((item) => (
        <View key={item.key} style={styles.labButtonCell}>
          <Button size="small" onPress={() => props.onPress(item.key)}>
            {item.label}
          </Button>
        </View>
      ))}
    </View>
  );
}
