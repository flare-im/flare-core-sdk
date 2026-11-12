// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { NotificationApi } from '../../api/modules/notification';
import { BackgroundRefreshRequest, BackgroundRefreshResult, SetBackgroundPresenterRequest, SetNotificationFocusRequest, SetNotificationSnapshotDirectoryRequest, UpdateUserNotificationSettingsRequest, UserNotificationSettings } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { backgroundRefreshRequestToMap, conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap, setBackgroundPresenterRequestToMap, setNotificationFocusRequestToMap, setNotificationSnapshotDirectoryRequestToMap, updateUserNotificationSettingsRequestToMap } from '../codec/wireCodec';

export class DefaultNotificationApi implements NotificationApi {
  constructor(private readonly bridge: NativeBridge) {}

  async setFocus(request: SetNotificationFocusRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.notificationSetFocus, setNotificationFocusRequestToMap(request));
  }

  async getSettings(): Promise<UserNotificationSettings> {
    return await invokeMap(this.bridge, NativeCallMap.notificationGetSettings) as unknown as UserNotificationSettings;
  }

  async updateSettings(request: UpdateUserNotificationSettingsRequest): Promise<UserNotificationSettings> {
    return await invokeMap(this.bridge, NativeCallMap.notificationUpdateSettings, updateUserNotificationSettingsRequestToMap(request)) as unknown as UserNotificationSettings;
  }

  async setBackgroundPresenter(request: SetBackgroundPresenterRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.notificationSetBackgroundPresenter, setBackgroundPresenterRequestToMap(request));
  }

  async setSnapshotDirectory(request: SetNotificationSnapshotDirectoryRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.notificationSetSnapshotDirectory, setNotificationSnapshotDirectoryRequestToMap(request));
  }

  async backgroundRefresh(request: BackgroundRefreshRequest): Promise<BackgroundRefreshResult> {
    return await invokeMap(this.bridge, NativeCallMap.notificationBackgroundRefresh, backgroundRefreshRequestToMap(request)) as unknown as BackgroundRefreshResult;
  }
}
