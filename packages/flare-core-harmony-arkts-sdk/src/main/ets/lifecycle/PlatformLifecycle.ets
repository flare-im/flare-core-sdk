import { connection } from '@kit.NetworkKit';
import { application, appManager, ApplicationStateChangeCallback, common } from '@kit.AbilityKit';
import { data, sim } from '@kit.TelephonyKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { process } from '@kit.ArkTS';
import type { FlareImClient } from '../api/client';
import { AppState, NetworkChangeRequest, NetworkInterfaceKind } from '../model';

/**
 * The default network as the platform sees it. `fingerprintHint` is coarse on purpose: a Wi-Fi or
 * Ethernet gateway prefix, or a cellular MCC-MNC; never an SSID or BSSID.
 */
export interface NetworkSnapshot {
  available: boolean;
  interface?: NetworkInterfaceKind;
  expensive?: boolean;
  metered?: boolean;
  fingerprintHint?: string;
}

/** Where network changes come from (`@kit.NetworkKit` on device). */
export interface PlatformNetworkSource {
  /**
   * Starts watching; `onChange` runs on every platform network callback, with a reason for
   * diagnostics. Failures after start (a registration the platform refused) go to `onError`.
   */
  start(onChange: (reason: string) => void, onError: (error: Object) => void): void;
  /** The default network now. */
  current(): Promise<NetworkSnapshot>;
  stop(): void;
}

/** Where foreground and background come from (the application state of `@kit.AbilityKit` on device). */
export interface PlatformAppStateSource {
  start(onChange: (state: AppState) => void, onError: (error: Object) => void): void;
  /** The application state now. */
  current(): Promise<AppState>;
  stop(): void;
}

export interface PlatformLifecycleOptions {
  /** Defaults to the HarmonyOS default-network watcher. */
  network?: PlatformNetworkSource;
  /** Defaults to the HarmonyOS application foreground and background callbacks. */
  appState?: PlatformAppStateSource;
  /** Called when a source cannot start or the core rejects a report; reports never throw. */
  onError?: (error: Object) => void;
}

/**
 * Platform lifecycle for HarmonyOS. `client.init` installs it unless the init request says
 * `installPlatformLifecycle: false`; `dispose`, `uninit` and `hardReset` remove it.
 *
 * The default network (`@kit.NetworkKit`, `connection.on('netAvailable' …)` and its siblings)
 * goes to `connection.notifyNetworkChange`, and the application state
 * (`applicationStateChange`) goes to `lifecycle.setAppState`. Right after install it reports the
 * current network and state once; afterwards it reports only changes: a network report repeats
 * only when availability, interface, cost or fingerprint hint changed. The core's link
 * supervisor alone decides what to do with them; apps add no wiring of their own.
 *
 * Construct and `install()` it directly only to drive a client by hand (tests, or a host that
 * turned the automatic install off to pass its own sources).
 */
export class PlatformLifecycle {
  private readonly client: FlareImClient;
  private readonly network: PlatformNetworkSource;
  private readonly appState: PlatformAppStateSource;
  private readonly onError: (error: Object) => void;
  private lastNetworkKey: string | null = null;
  private lastAppState: AppState | null = null;
  private appStateSeen: boolean = false;
  private networkQueue: Promise<void> = Promise.resolve();
  private installed: boolean = false;
  private disposed: boolean = false;

  constructor(client: FlareImClient, options?: PlatformLifecycleOptions) {
    this.client = client;
    this.network = options?.network ?? new HarmonyNetworkSource();
    this.appState = options?.appState ?? new HarmonyAppStateSource();
    this.onError = options?.onError ?? ((error: Object) => {
      console.warn(`flare-core platform lifecycle: ${error}`);
    });
  }

  /** Starts both sources and reports the current network and application state once. */
  install(): PlatformLifecycle {
    if (this.installed || this.disposed) {
      return this;
    }
    this.installed = true;
    try {
      this.network.start((reason: string) => {
        this.refreshNetwork(reason);
      }, this.onError);
    } catch (error) {
      this.onError(error as Object);
    }
    try {
      this.appState.start((state: AppState) => {
        this.appStateSeen = true;
        this.reportAppState(state);
      }, this.onError);
    } catch (error) {
      this.onError(error as Object);
    }
    this.syncNow(true);
    return this;
  }

  /** Reports the current network and application state now (each only if it changed). */
  sync(): Promise<void> {
    return this.syncNow(false);
  }

  /** Stops both sources; later callbacks are ignored. */
  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    if (!this.installed) {
      return;
    }
    try {
      this.network.stop();
    } catch (error) {
      this.onError(error as Object);
    }
    try {
      this.appState.stop();
    } catch (error) {
      this.onError(error as Object);
    }
  }

  /** Resolves once every network report queued so far has gone out. */
  idle(): Promise<void> {
    return this.networkQueue;
  }

  /**
   * The first report after install reads the application state but lets a live callback that
   * already arrived win (it is newer); when the state cannot be read it assumes foreground, since
   * init runs from a visible app.
   */
  private async syncNow(initial: boolean): Promise<void> {
    this.refreshNetwork('initial');
    const network = this.networkQueue;
    let state: AppState | null = null;
    try {
      state = await this.appState.current();
    } catch (error) {
      this.onError(error as Object);
      state = initial ? AppState.Foreground : null;
    }
    if (state !== null && !(initial && this.appStateSeen)) {
      this.reportAppState(state);
    }
    await network;
  }

  /** Reads the default network after every callback, one read at a time so reports keep their order. */
  private refreshNetwork(reason: string): void {
    if (this.disposed) {
      return;
    }
    this.networkQueue = this.networkQueue.then(async () => {
      if (this.disposed) {
        return;
      }
      let snapshot: NetworkSnapshot;
      try {
        snapshot = await this.network.current();
      } catch (error) {
        this.onError(error as Object);
        return;
      }
      await this.reportNetwork(snapshot, reason);
    });
  }

  private async reportNetwork(snapshot: NetworkSnapshot, reason: string): Promise<void> {
    const key = networkSnapshotKey(snapshot);
    if (this.disposed || key === this.lastNetworkKey) {
      return;
    }
    this.lastNetworkKey = key;
    try {
      await this.client.connection.notifyNetworkChange(networkChangeRequest(snapshot, reason));
    } catch (error) {
      this.onError(error as Object);
    }
  }

  private reportAppState(state: AppState): void {
    if (this.disposed || state === this.lastAppState) {
      return;
    }
    this.lastAppState = state;
    this.client.lifecycle.setAppState({ appState: state }).catch((error: Object) => {
      this.onError(error);
    });
  }
}

/**
 * Watches the default network with `@kit.NetworkKit` (`ohos.permission.GET_NETWORK_INFO`, a
 * system_grant permission this module declares). The fingerprint hint is the default gateway's
 * /24 (IPv4) or /64 (IPv6) prefix on Wi-Fi and Ethernet, and the SIM operator's MCC-MNC on
 * cellular when it can be read without a permission. No SSID, BSSID or location.
 */
export class HarmonyNetworkSource implements PlatformNetworkSource {
  private netConnection: connection.NetConnection | null = null;

  start(onChange: (reason: string) => void, onError: (error: Object) => void): void {
    if (this.netConnection !== null) {
      return;
    }
    const netConnection = connection.createNetConnection();
    netConnection.on('netAvailable', (_handle: connection.NetHandle) => {
      onChange('net_available');
    });
    netConnection.on('netCapabilitiesChange', (_info: connection.NetCapabilityInfo) => {
      onChange('capabilities_changed');
    });
    netConnection.on('netConnectionPropertiesChange', (_info: connection.NetConnectionPropertyInfo) => {
      onChange('properties_changed');
    });
    netConnection.on('netLost', (_handle: connection.NetHandle) => {
      onChange('net_lost');
    });
    netConnection.on('netUnavailable', () => {
      onChange('net_unavailable');
    });
    netConnection.register((error: BusinessError) => {
      if (error !== undefined && error !== null && error.code !== 0) {
        onError(error);
      }
    });
    this.netConnection = netConnection;
  }

  async current(): Promise<NetworkSnapshot> {
    const handle = await connection.getDefaultNet();
    if (handle.netId === 0) {
      const none: NetworkSnapshot = { available: false };
      return none;
    }
    const capabilities = await connection.getNetCapabilities(handle);
    const kind = interfaceKind(capabilities.bearerTypes);
    const networkCap = capabilities.networkCap ?? [];
    const metered = networkCap.indexOf(connection.NetCap.NET_CAPABILITY_NOT_METERED) < 0;
    const snapshot: NetworkSnapshot = {
      available: true,
      interface: kind,
      expensive: kind === NetworkInterfaceKind.Cellular || metered,
      metered: metered,
    };
    const hint = await fingerprintHint(handle, kind);
    if (hint !== undefined) {
      snapshot.fingerprintHint = hint;
    }
    return snapshot;
  }

  stop(): void {
    const netConnection = this.netConnection;
    this.netConnection = null;
    if (netConnection !== null) {
      netConnection.unregister((_error: BusinessError) => {});
    }
  }
}

/**
 * Foreground and background from the application context's `applicationStateChange` (all of the
 * app's abilities together, not one UIAbility). The context comes from the host when it passes
 * one, else from `application.getApplicationContext()`.
 */
export class HarmonyAppStateSource implements PlatformAppStateSource {
  private readonly hostContext?: common.Context;
  private context: common.ApplicationContext | null = null;
  private callback: ApplicationStateChangeCallback | null = null;

  constructor(context?: common.Context) {
    this.hostContext = context;
  }

  start(onChange: (state: AppState) => void, _onError: (error: Object) => void): void {
    if (this.callback !== null) {
      return;
    }
    const context = this.applicationContext();
    const callback: ApplicationStateChangeCallback = {
      onApplicationForeground() {
        onChange(AppState.Foreground);
      },
      onApplicationBackground() {
        onChange(AppState.Background);
      },
    };
    context.on('applicationStateChange', callback);
    this.context = context;
    this.callback = callback;
  }

  async current(): Promise<AppState> {
    const processes = await this.applicationContext().getRunningProcessInformation();
    let own: appManager.ProcessInformation | undefined = undefined;
    for (const info of processes) {
      if (info.pid === process.pid) {
        own = info;
        break;
      }
    }
    if (own === undefined) {
      return AppState.Foreground;
    }
    return own.state === appManager.ProcessState.STATE_BACKGROUND ? AppState.Background : AppState.Foreground;
  }

  stop(): void {
    const context = this.context;
    const callback = this.callback;
    this.context = null;
    this.callback = null;
    if (context !== null && callback !== null) {
      context.off('applicationStateChange', callback);
    }
  }

  private applicationContext(): common.ApplicationContext {
    if (this.hostContext !== undefined) {
      return this.hostContext.getApplicationContext();
    }
    return application.getApplicationContext();
  }
}

/** Two snapshots with the same key are the same network to the core; only a new key is reported. */
export function networkSnapshotKey(snapshot: NetworkSnapshot): string {
  return [
    snapshot.available ? '1' : '0',
    snapshot.interface ?? '',
    snapshot.expensive === undefined ? '' : (snapshot.expensive ? '1' : '0'),
    snapshot.metered === undefined ? '' : (snapshot.metered ? '1' : '0'),
    snapshot.fingerprintHint ?? '',
  ].join('|');
}

export function networkChangeRequest(snapshot: NetworkSnapshot, reason: string): NetworkChangeRequest {
  const request: NetworkChangeRequest = { available: snapshot.available, reason: reason };
  if (snapshot.interface !== undefined) {
    request.interface = snapshot.interface;
  }
  if (snapshot.expensive !== undefined) {
    request.expensive = snapshot.expensive;
  }
  if (snapshot.metered !== undefined) {
    request.metered = snapshot.metered;
  }
  if (snapshot.fingerprintHint !== undefined && snapshot.fingerprintHint.length > 0) {
    request.fingerprintHint = snapshot.fingerprintHint;
  }
  return request;
}

/**
 * The fingerprint hint of a gateway address: the /24 prefix of an IPv4 address (`192.168.1`) or the
 * /64 prefix of an IPv6 address (`fe80:0:0:0`). Undefined for anything else.
 */
export function gatewayPrefix(address: string): string | undefined {
  const trimmed = address.trim();
  if (trimmed.length === 0) {
    return undefined;
  }
  if (trimmed.indexOf(':') < 0) {
    const octets = trimmed.split('.');
    if (octets.length !== 4 || !octets.every((octet: string) => /^\d{1,3}$/.test(octet) && Number(octet) <= 255)) {
      return undefined;
    }
    return `${octets[0]}.${octets[1]}.${octets[2]}`;
  }
  const scopeless = trimmed.split('%')[0];
  const halves = scopeless.split('::');
  if (halves.length > 2) {
    return undefined;
  }
  const head = halves[0].length > 0 ? halves[0].split(':') : [];
  const tail = halves.length === 2 && halves[1].length > 0 ? halves[1].split(':') : [];
  const groups: string[] = [];
  head.forEach((group: string) => {
    groups.push(group);
  });
  if (halves.length === 2) {
    for (let i = head.length + tail.length; i < 8; i++) {
      groups.push('0');
    }
  }
  tail.forEach((group: string) => {
    groups.push(group);
  });
  if (groups.length !== 8 || !groups.every((group: string) => /^[0-9a-fA-F]{1,4}$/.test(group))) {
    return undefined;
  }
  return groups.slice(0, 4).map((group: string) => parseInt(group, 16).toString(16)).join(':');
}

function interfaceKind(bearers: Array<connection.NetBearType>): NetworkInterfaceKind {
  if (bearers.indexOf(connection.NetBearType.BEARER_WIFI) >= 0) {
    return NetworkInterfaceKind.Wifi;
  }
  if (bearers.indexOf(connection.NetBearType.BEARER_CELLULAR) >= 0) {
    return NetworkInterfaceKind.Cellular;
  }
  if (bearers.indexOf(connection.NetBearType.BEARER_ETHERNET) >= 0) {
    return NetworkInterfaceKind.Ethernet;
  }
  return bearers.length === 0 ? NetworkInterfaceKind.Unknown : NetworkInterfaceKind.Other;
}

async function fingerprintHint(handle: connection.NetHandle, kind: NetworkInterfaceKind): Promise<string | undefined> {
  if (kind === NetworkInterfaceKind.Cellular) {
    return cellularOperator();
  }
  if (kind !== NetworkInterfaceKind.Wifi && kind !== NetworkInterfaceKind.Ethernet) {
    return undefined;
  }
  try {
    const properties = await connection.getConnectionProperties(handle);
    return defaultGatewayPrefix(properties.routes);
  } catch (error) {
    return undefined;
  }
}

/** The default route's gateway prefix, IPv4 first. */
function defaultGatewayPrefix(routes: Array<connection.RouteInfo>): string | undefined {
  let ipv6: string | undefined = undefined;
  for (const route of routes) {
    if (!route.isDefaultRoute || !route.hasGateway) {
      continue;
    }
    const prefix = gatewayPrefix(route.gateway.address);
    if (prefix === undefined) {
      continue;
    }
    if (route.gateway.address.indexOf(':') < 0) {
      return prefix;
    }
    if (ipv6 === undefined) {
      ipv6 = prefix;
    }
  }
  return ipv6;
}

/** MCC-MNC of the SIM that carries cellular data; both reads need no permission. Undefined without a SIM. */
function cellularOperator(): string | undefined {
  try {
    const slotId = data.getDefaultCellularDataSlotIdSync();
    if (slotId < 0) {
      return undefined;
    }
    const numeric = sim.getSimOperatorNumericSync(slotId);
    if (!/^\d{5,6}$/.test(numeric)) {
      return undefined;
    }
    return `${numeric.substring(0, 3)}-${numeric.substring(3)}`;
  } catch (error) {
    return undefined;
  }
}
