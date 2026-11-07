import { AppState } from "../model/app_state";
import type { NetworkChangeRequest } from "../model/network_change_request";
import { NetworkInterfaceKind } from "../model/network_interface_kind";
import type { SetAppStateRequest } from "../model/set_app_state_request";

/**
 * Platform lifecycle for TypeScript runtimes.
 *
 * Free of the wasm runtime and of every bridge: it only needs the two report functions it is
 * built with, so other SDKs with their own runtime (the social SDK) reuse it through
 * `@flare-im/sdk/lifecycle`. The core client's `init` installs one wired to its own
 * `connection.notifyNetworkChange` and `lifecycle.setAppState` (unless
 * `installPlatformLifecycle: false`); `dispose`, `uninit` and `hardReset` remove it. The core's
 * link supervisor alone decides what to do with the reports; apps add no wiring of their own.
 *
 * Where the reports come from is a pair of sources:
 * - browsers (web, the Tauri webview): `online` / `offline` and `navigator.connection` for the
 *   network, `visibilitychange` and `pagehide` / `pageshow` for foreground and background;
 * - other runtimes register their own when their adapter loads
 *   ({@link registerPlatformLifecycleSources}: React Native's `AppState`, uni-app's app and network
 *   events). A runtime with neither gets an inert binding. Installing never throws.
 */

/** The two reports the platform lifecycle makes; the core client wires them to its own API. */
export interface PlatformLifecycleReports {
  notifyNetworkChange(request: NetworkChangeRequest): Promise<void>;
  setAppState(request: SetAppStateRequest): Promise<void>;
}

/** What one network report says. */
export interface NetworkSnapshot {
  available: boolean;
  interface?: NetworkInterfaceKind;
  /** Coarse network identity, hashed locally into the network fingerprint. Never an SSID. */
  fingerprintHint?: string;
}

/** Foreground and background. `subscribe` returns its own removal. */
export interface AppStateSource {
  current(): AppState | undefined;
  subscribe(listener: (state: AppState) => void): () => void;
}

/** Network reachability. `subscribe` returns its own removal; `reason` is for diagnostics. */
export interface NetworkSource {
  current(): NetworkSnapshot | undefined | Promise<NetworkSnapshot | undefined>;
  subscribe(listener: (snapshot: NetworkSnapshot, reason: string) => void): () => void;
}

export interface PlatformLifecycleSources {
  appState?: AppStateSource;
  network?: NetworkSource;
}

export interface LifecycleEventTarget {
  addEventListener(type: string, listener: () => void): void;
  removeEventListener(type: string, listener: () => void): void;
}

export interface LifecycleDocument extends LifecycleEventTarget {
  readonly visibilityState?: string;
}

/** The parts of the Network Information API it reads (Chromium; absent in Safari and Firefox). */
export interface LifecycleNetworkInformation extends LifecycleEventTarget {
  readonly type?: string;
}

export interface LifecycleNavigator {
  readonly onLine?: boolean;
  readonly connection?: LifecycleNetworkInformation;
}

export interface PlatformLifecycleOptions {
  /** Browser event sources; default to the page's `window`, `document` and `navigator`. */
  window?: LifecycleEventTarget | null;
  document?: LifecycleDocument | null;
  navigator?: LifecycleNavigator | null;
  /** Explicit sources; default to the registered ones, else the browser's. */
  sources?: PlatformLifecycleSources;
  /** Report the current network and app state once when installed (default true). */
  emitInitialState?: boolean;
  /** Called when a source fails to install or the core rejects a report; nothing ever throws. */
  onError?: (error: unknown) => void;
}

export interface PlatformLifecycleBinding {
  /** Reports the current network and app state now. */
  sync(): Promise<void>;
  /** Removes every listener; later events are ignored. */
  dispose(): void;
}

let registeredSources: (() => PlatformLifecycleSources | null) | null = null;

/**
 * Sets the sources every PlatformLifecycle built without explicit `sources` uses. Runtime adapters
 * that are not browsers (React Native, uni-app) register theirs when they load; `null` restores the
 * browser sources.
 */
export function registerPlatformLifecycleSources(
  factory: (() => PlatformLifecycleSources | null) | null,
): void {
  registeredSources = factory;
}

function interfaceKind(type: string | undefined): NetworkInterfaceKind | undefined {
  switch (type) {
    case undefined:
    case "":
      return undefined;
    case "wifi":
      return NetworkInterfaceKind.Wifi;
    case "cellular":
      return NetworkInterfaceKind.Cellular;
    case "ethernet":
      return NetworkInterfaceKind.Ethernet;
    case "unknown":
    case "none":
      return NetworkInterfaceKind.Unknown;
    default:
      return NetworkInterfaceKind.Other;
  }
}

/** `value` when it can carry listeners; React Native's `window` is the global object without them. */
function eventTarget<T extends LifecycleEventTarget>(value: unknown): T | null {
  return value
    && typeof value === "object"
    && typeof (value as LifecycleEventTarget).addEventListener === "function"
    && typeof (value as LifecycleEventTarget).removeEventListener === "function"
    ? value as T
    : null;
}

function globalValue(name: "window" | "document" | "navigator"): unknown {
  return (globalThis as Record<string, unknown>)[name];
}

function listen(target: LifecycleEventTarget | null, type: string, listener: () => void): () => void {
  if (!target) return () => undefined;
  target.addEventListener(type, listener);
  return () => target.removeEventListener(type, listener);
}

/** The browser sources (web, the Tauri webview); empty where the globals cannot carry listeners. */
export function browserLifecycleSources(options: PlatformLifecycleOptions = {}): PlatformLifecycleSources {
  const window = eventTarget<LifecycleEventTarget>(options.window === undefined ? globalValue("window") : options.window);
  const document = eventTarget<LifecycleDocument>(
    options.document === undefined ? globalValue("document") : options.document,
  );
  const rawNavigator = options.navigator === undefined ? globalValue("navigator") : options.navigator;
  const navigator = rawNavigator && typeof rawNavigator === "object" ? rawNavigator as LifecycleNavigator : null;
  const connection = eventTarget<LifecycleNetworkInformation>(navigator?.connection);

  const visibleState = (): AppState =>
    document?.visibilityState === "hidden" ? AppState.Background : AppState.Foreground;
  const appState: AppStateSource | undefined = window || document
    ? {
        current: visibleState,
        subscribe(listener) {
          const removals = [
            listen(document, "visibilitychange", () => listener(visibleState())),
            listen(window, "pagehide", () => listener(AppState.Background)),
            listen(window, "pageshow", () => listener(visibleState())),
          ];
          return () => removals.forEach((remove) => remove());
        },
      }
    : undefined;

  const snapshot = (offline = false): NetworkSnapshot => {
    const type = connection?.type || undefined;
    const kind = interfaceKind(type);
    return {
      available: offline ? false : navigator?.onLine !== false,
      ...(kind !== undefined ? { interface: kind } : {}),
      // The connection type is all a browser can say about the network it is on.
      ...(type !== undefined ? { fingerprintHint: type } : {}),
    };
  };
  const network: NetworkSource | undefined = window || connection
    ? {
        current: () => snapshot(),
        subscribe(listener) {
          const removals = [
            listen(window, "online", () => listener(snapshot(), "online")),
            listen(window, "offline", () => listener(snapshot(true), "offline")),
            listen(connection, "change", () => listener(snapshot(), "connection_change")),
          ];
          return () => removals.forEach((remove) => remove());
        },
      }
    : undefined;

  return { ...(appState ? { appState } : {}), ...(network ? { network } : {}) };
}

/**
 * `new PlatformLifecycle(reports, options).install()`; the core client does this itself at init.
 */
export class PlatformLifecycle implements PlatformLifecycleBinding {
  private readonly sources: PlatformLifecycleSources;
  private readonly cleanups: Array<() => void> = [];
  private lastAppState: AppState | null = null;
  private lastNetwork: string | null = null;
  private disposed = false;

  constructor(
    private readonly reports: PlatformLifecycleReports,
    private readonly options: PlatformLifecycleOptions = {},
  ) {
    this.sources = this.resolveSources();
  }

  /** Whether this runtime offers anything to listen to. */
  get active(): boolean {
    return this.sources.appState !== undefined || this.sources.network !== undefined;
  }

  install(): this {
    const { appState, network } = this.sources;
    this.subscribe(() => appState?.subscribe((state) => void this.reportAppState(state)));
    this.subscribe(() => network?.subscribe((snapshot, reason) => void this.reportNetwork(snapshot, reason)));
    if (this.options.emitInitialState !== false && this.active) {
      void this.sync();
    }
    return this;
  }

  setForeground(): Promise<void> {
    return this.reportAppState(AppState.Foreground);
  }

  setBackground(): Promise<void> {
    return this.reportAppState(AppState.Background);
  }

  async sync(): Promise<void> {
    try {
      const snapshot = await this.sources.network?.current();
      if (snapshot) await this.reportNetwork(snapshot, "initial");
      const state = this.sources.appState?.current();
      if (state !== undefined) await this.reportAppState(state);
    } catch (error) {
      this.options.onError?.(error);
    }
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    for (const cleanup of this.cleanups.splice(0)) {
      try {
        cleanup();
      } catch (error) {
        this.options.onError?.(error);
      }
    }
  }

  private resolveSources(): PlatformLifecycleSources {
    try {
      if (this.options.sources) return this.options.sources;
      const registered = registeredSources?.();
      return registered ?? browserLifecycleSources(this.options);
    } catch (error) {
      this.options.onError?.(error);
      return {};
    }
  }

  /** A source that fails to install is reported and skipped; the rest still install. */
  private subscribe(install: () => (() => void) | undefined): void {
    try {
      const removal = install();
      if (removal) this.cleanups.push(removal);
    } catch (error) {
      this.options.onError?.(error);
    }
  }

  private async reportAppState(appState: AppState): Promise<void> {
    if (this.disposed || appState === this.lastAppState) return;
    this.lastAppState = appState;
    try {
      await this.reports.setAppState({ appState });
    } catch (error) {
      this.options.onError?.(error);
    }
  }

  private async reportNetwork(snapshot: NetworkSnapshot, reason: string): Promise<void> {
    if (this.disposed) return;
    const request: NetworkChangeRequest = { available: snapshot.available, reason };
    if (snapshot.interface !== undefined) request.interface = snapshot.interface;
    if (snapshot.fingerprintHint !== undefined) request.fingerprintHint = snapshot.fingerprintHint;
    const key = `${request.available}|${request.interface ?? ""}|${request.fingerprintHint ?? ""}`;
    if (key === this.lastNetwork) return;
    this.lastNetwork = key;
    try {
      await this.reports.notifyNetworkChange(request);
    } catch (error) {
      this.options.onError?.(error);
    }
  }
}
