// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../contract/bridge_contract';
import type { FlareImClient } from '../api';
import type { ConnectionApi } from '../api/modules/connection';
import type { AccessApi } from '../api/modules/access';
import type { UpdateApi } from '../api/modules/update';
import type { LifecycleApi } from '../api/modules/lifecycle';
import type { ConversationsApi } from '../api/modules/conversations';
import type { MessageBuilderApi } from '../api/modules/message_builder';
import type { MessagesApi } from '../api/modules/messages';
import type { SyncApi } from '../api/modules/sync';
import type { UserApi } from '../api/modules/user';
import type { PresenceApi } from '../api/modules/presence';
import type { MediaApi } from '../api/modules/media';
import type { CapabilitiesApi } from '../api/modules/capabilities';
import type { ViewsApi } from '../api/modules/views';
import type { EventsApi } from '../api/modules/events';
import type { DiagnosticsApi } from '../api/modules/diagnostics';
import type { CreateClientRequest, CreateClientResponse, CurrentUserIdResponse, LoginRequest, SdkConfig, UpdateAccessTokenRequest } from '../api/types';
import type { ClearPushTokenRequest, HeartbeatEffectiveIntervalResponse, PushLifecycleStatus, PushTokenInput, SetHeartbeatNatTimeoutRequest, SetPushPermissionRequest } from '../model';
import { LifecycleEventName } from '../model';
import { emitLifecycleEvent, invokeBool, invokeMap, invokeVoid, sdkErrorPayloadFromError, userIdFromRequest } from './codec/nativeInvoke';
import { clearPushTokenRequestToMap, pushTokenInputToMap, setHeartbeatNatTimeoutRequestToMap, setPushPermissionRequestToMap } from './codec/wireCodec';
import type { ConnectTokenRefresher } from '../contract/bridge_contract';
import { FlareSdkException } from '../bridge/flareSdkException';
import { PlatformLifecycle } from '../lifecycle/platformLifecycle';
import { DefaultEventsApi } from './module/DefaultEventsApi';
import { DefaultConnectionApi } from './module/DefaultConnectionApi';
import { DefaultAccessApi } from './module/DefaultAccessApi';
import { DefaultUpdateApi } from './module/DefaultUpdateApi';
import { DefaultLifecycleApi } from './module/DefaultLifecycleApi';
import { DefaultConversationsApi } from './module/DefaultConversationsApi';
import { DefaultMessagesApi } from './module/DefaultMessagesApi';
import { DefaultSyncApi } from './module/DefaultSyncApi';
import { DefaultUserApi } from './module/DefaultUserApi';
import { DefaultPresenceApi } from './module/DefaultPresenceApi';
import { DefaultMediaApi } from './module/DefaultMediaApi';
import { DefaultCapabilitiesApi } from './module/DefaultCapabilitiesApi';
import { DefaultViewsApi } from './module/DefaultViewsApi';
import { DefaultDiagnosticsApi } from './module/DefaultDiagnosticsApi';
import { DefaultMessageBuilderApi } from './module/DefaultMessageBuilderApi';

export class DefaultFlareImClient implements FlareImClient {
  readonly connection: ConnectionApi;
  readonly access: AccessApi;
  readonly update: UpdateApi;
  readonly lifecycle: LifecycleApi;
  readonly conversations: ConversationsApi;
  readonly messageBuilder: MessageBuilderApi;
  readonly messages: MessagesApi;
  readonly sync: SyncApi;
  readonly user: UserApi;
  readonly presence: PresenceApi;
  readonly media: MediaApi;
  readonly capabilities: CapabilitiesApi;
  readonly views: ViewsApi;
  readonly events: EventsApi;
  readonly diagnostics: DiagnosticsApi;
  private readonly bridge: NativeBridge;
  private platformLifecycle: PlatformLifecycle | null = null;

  constructor(bridge: NativeBridge) {
    this.bridge = bridge;
    this.connection = new DefaultConnectionApi(bridge);
    this.access = new DefaultAccessApi(bridge);
    this.update = new DefaultUpdateApi(bridge);
    this.lifecycle = new DefaultLifecycleApi(bridge);
    this.conversations = new DefaultConversationsApi(bridge);
    this.messageBuilder = new DefaultMessageBuilderApi(bridge);
    this.messages = new DefaultMessagesApi(bridge);
    this.sync = new DefaultSyncApi(bridge);
    this.user = new DefaultUserApi(bridge);
    this.presence = new DefaultPresenceApi(bridge);
    this.media = new DefaultMediaApi(bridge);
    this.capabilities = new DefaultCapabilitiesApi(bridge);
    this.views = new DefaultViewsApi(bridge);
    this.events = new DefaultEventsApi(bridge);
    this.diagnostics = new DefaultDiagnosticsApi(bridge);
  }

  async create(request: CreateClientRequest): Promise<CreateClientResponse> {
    return await this.bridge.invoke<CreateClientResponse>(NativeCallMap.sdkCreate, request);
  }
  async init(request: SdkConfig): Promise<void> {
    emitLifecycleEvent(this.events as unknown as DefaultEventsApi, LifecycleEventName.Initializing, "sdk.init");
    const { installPlatformLifecycle, ...config } = request;
    try {
      await invokeVoid(this.bridge, NativeCallMap.sdkInit, config);
      this.replacePlatformLifecycle(installPlatformLifecycle !== false);
      emitLifecycleEvent(this.events as unknown as DefaultEventsApi, LifecycleEventName.Initialized, "sdk.init");
    } catch (error) {
      emitLifecycleEvent(
        this.events as unknown as DefaultEventsApi,
        LifecycleEventName.InitFailed,
        "sdk.init",
        undefined,
        sdkErrorPayloadFromError(error as unknown, "sdk.init"),
      );
      throw error;
    }
  }
  async uninit(): Promise<void> {
    this.uninstallPlatformLifecycle();
    await invokeVoid(this.bridge, NativeCallMap.sdkUninit);
  }
  async login(request: LoginRequest): Promise<void> {
    const userId = userIdFromRequest(request);
    try {
      await invokeVoid(this.bridge, NativeCallMap.sdkLogin, request);
      emitLifecycleEvent(this.events as unknown as DefaultEventsApi, LifecycleEventName.LoginSucceeded, "sdk.login", userId);
    } catch (error) {
      emitLifecycleEvent(
        this.events as unknown as DefaultEventsApi,
        LifecycleEventName.LoginFailed,
        "sdk.login",
        userId,
        sdkErrorPayloadFromError(error as unknown, "sdk.login"),
      );
      throw error;
    }
  }
  async prepare(request: LoginRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.sdkPrepare, request);
  }
  async connect(request: LoginRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.sdkConnect, request);
  }
  async updateAccessToken(request: UpdateAccessTokenRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.sdkUpdateAccessToken, request);
  }
  async setConnectTokenRefresher(refresher: ConnectTokenRefresher | null): Promise<void> {
    if (!this.bridge.setConnectTokenRefresher) {
      throw new FlareSdkException('capabilityUnavailable', 'this runtime cannot call back for a connect token', 'sdk.set_connect_token_refresher');
    }
    await this.bridge.setConnectTokenRefresher(refresher);
  }
  async setHeartbeatNatTimeout(request: SetHeartbeatNatTimeoutRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.sdkSetHeartbeatNatTimeout, setHeartbeatNatTimeoutRequestToMap(request));
  }
  async heartbeatEffectiveInterval(): Promise<HeartbeatEffectiveIntervalResponse> {
    return await invokeMap(this.bridge, NativeCallMap.sdkHeartbeatEffectiveInterval) as unknown as HeartbeatEffectiveIntervalResponse;
  }
  async logout(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.sdkLogout);
    emitLifecycleEvent(this.events as unknown as DefaultEventsApi, LifecycleEventName.LoggedOut, "sdk.logout");
  }
  async dispose(): Promise<void> {
    this.uninstallPlatformLifecycle();
    await this.events.unsubscribeAll();
    await invokeVoid(this.bridge, NativeCallMap.sdkDispose);
    emitLifecycleEvent(this.events as unknown as DefaultEventsApi, LifecycleEventName.Disposed, "sdk.dispose");
  }
  async hardReset(): Promise<void> {
    this.uninstallPlatformLifecycle();
    await invokeVoid(this.bridge, NativeCallMap.sdkHardReset);
  }
  async currentUserId(): Promise<CurrentUserIdResponse> {
    return await this.bridge.invoke<CurrentUserIdResponse>(NativeCallMap.sdkCurrentUserId);
  }
  async isConnected(): Promise<boolean> {
    return await invokeBool(this.bridge, NativeCallMap.sdkIsConnected);
  }
  async sessionActive(): Promise<boolean> {
    return await invokeBool(this.bridge, NativeCallMap.sdkSessionActive);
  }
  async updatePushToken(request: PushTokenInput): Promise<PushLifecycleStatus> {
    return await invokeMap(this.bridge, NativeCallMap.sdkUpdatePushToken, pushTokenInputToMap(request)) as unknown as PushLifecycleStatus;
  }
  async clearPushToken(request: ClearPushTokenRequest): Promise<PushLifecycleStatus> {
    return await invokeMap(this.bridge, NativeCallMap.sdkClearPushToken, clearPushTokenRequestToMap(request)) as unknown as PushLifecycleStatus;
  }
  async setPushPermission(request: SetPushPermissionRequest): Promise<PushLifecycleStatus> {
    return await invokeMap(this.bridge, NativeCallMap.sdkSetPushPermission, setPushPermissionRequestToMap(request)) as unknown as PushLifecycleStatus;
  }
  async reconcilePush(): Promise<PushLifecycleStatus> {
    return await invokeMap(this.bridge, NativeCallMap.sdkReconcilePush) as unknown as PushLifecycleStatus;
  }
  async pushStatus(): Promise<PushLifecycleStatus> {
    return await invokeMap(this.bridge, NativeCallMap.sdkPushStatus) as unknown as PushLifecycleStatus;
  }

  /**
   * Installs the PlatformLifecycle (replacing a previous one) unless init turned it off. Never
   * throws: init has already succeeded in the core, so a runtime whose globals cannot carry
   * listeners only loses the automatic reports.
   */
  private replacePlatformLifecycle(install: boolean): void {
    this.uninstallPlatformLifecycle();
    if (!install) return;
    const reportFailure = (error: unknown) => console.warn('[flare-core] platform lifecycle', error);
    try {
      this.platformLifecycle = new PlatformLifecycle({
        notifyNetworkChange: (request) => this.connection.notifyNetworkChange(request),
        setAppState: (request) => this.lifecycle.setAppState(request),
      }, { onError: reportFailure }).install();
    } catch (error) {
      this.platformLifecycle = null;
      reportFailure(error);
    }
  }

  private uninstallPlatformLifecycle(): void {
    this.platformLifecycle?.dispose();
    this.platformLifecycle = null;
  }
}
