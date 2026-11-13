/**
 * Plugin web bundles (L3) for browser and webview hosts (Web, Tauri): the port methods that reach the engine's
 * `capability.plugin_bundle_*` routes, the session a host's frame runs on, the engine's bundle events, and the web
 * bundle runtime a host reports in its profile.
 *
 * The engine checks every bridge request (envelope, version, handshake, permission, operation, rate); a host only moves
 * envelopes and draws what the engine hands it. Envelopes travel to the engine as JSON text, as the routes take them.
 */

/** `capability.plugin_bundle_*` on the plugin port (the social SDK's `plugins` facade). Each resolves with Core's JSON. */
export interface PluginBundlePort {
  /** `{pluginId, contributionId, route?, arguments?, presentation?, conversation?, locale, theme, hostOrigin?}` → {@link PluginBundleOpened}. */
  pluginBundleOpen(request: PluginBundleOpenRequest): Promise<Record<string, unknown>>;
  /** `{sessionId, envelope, userGesture?}` → `{envelope}` or `{host: {id, method, params}}`. */
  pluginBundleBridge(request: { sessionId: string; envelope: string; userGesture?: boolean }): Promise<Record<string, unknown>>;
  /** `{sessionId, id, result? | error?}` → `{envelope}`. */
  pluginBundleHostResult(request: { sessionId: string; id: string; result?: Record<string, unknown>; error?: PluginBundleHostError }): Promise<Record<string, unknown>>;
  /** `{event, payload, sessionId?}` → `{deliveries: [{sessionId, envelope}]}`. */
  pluginBundleHostEvent(request: { event: string; payload: Record<string, unknown>; sessionId?: string }): Promise<Record<string, unknown>>;
  /** `{sessionId}` → `{closed}`. */
  pluginBundleClose(request: { sessionId: string }): Promise<Record<string, unknown>>;
  /** `{wifi, idle}` → `{fetched}`: entry bundles fetched ahead (native caches; the browser answers 0). */
  pluginBundlePrefetch?(request: { wifi: boolean; idle: boolean }): Promise<Record<string, unknown>>;
}

/** Where a bundle page shows (`BridgePresentation`). */
export type PluginBundlePresentation = "page" | "detail" | "composerForm";

/** The codes a host may answer a host request with. */
export type PluginBundleHostError = "cancelled" | "unavailable" | "gesture_required" | "timeout" | "not_found";

export interface PluginBundleOpenRequest {
  pluginId: string;
  /** The contribution whose bundle variant Core selected (a page's id, a card's or a "+" entry's contribution). */
  contributionId: string;
  /** A route inside the bundle; the contribution's own route otherwise. */
  route?: string;
  arguments?: Record<string, unknown>;
  presentation?: PluginBundlePresentation;
  conversation?: { id: string; type: string };
  locale: string;
  theme: { mode: "light" | "dark"; tokens: Record<string, string> };
  /** Web: the app's https origin, for the policy's `frame-ancestors`. */
  hostOrigin?: string;
}

/** `plugin_bundle_open`'s answer. */
export interface PluginBundleOpened {
  sessionId: string;
  /** `null` (Web, opaque), `flare-plugin://{key}` (Tauri, iOS) or `https://{key}.plugin.flare.invalid` (Android). */
  origin: string;
  /** Web: the https base of the unpacked copy; native: the cache directory of the verified files. */
  root: string;
  entry: string;
  csp: string;
  /** Native only: the files an interceptor may serve. */
  files?: Array<{ path: string; contentType: string; size: number }>;
  hello: Record<string, unknown>;
}

/** The SDK event channel of `plugin.bundle_event` (7004): `{sessionId, envelope?, close?}`. */
export const PLUGIN_BUNDLE_EVENT_CHANNEL = "im://plugin_bundle_event";

/** One `plugin.bundle_event`. */
export interface PluginBundleEventPayload {
  sessionId: string;
  envelope?: string;
  close?: string;
}

/** The engine's bundle events for the open pages: the host routes the SDK event into `announce`; sessions listen. */
export interface PluginBundleEventHub {
  /** Forwards one `im://plugin_bundle_event` payload; returns whether it named a session. */
  announce(payload: unknown): boolean;
  /** Listens to one session's events; returns the unsubscribe. */
  listen(sessionId: string, listener: (event: { envelope?: Record<string, unknown>; close?: string }) => void): () => void;
}

export function createPluginBundleEventHub(): PluginBundleEventHub {
  const listeners = new Map<string, Set<(event: { envelope?: Record<string, unknown>; close?: string }) => void>>();
  return {
    announce(payload) {
      const record = (payload ?? {}) as Partial<PluginBundleEventPayload>;
      if (typeof record.sessionId !== "string" || !record.sessionId) return false;
      const envelope = typeof record.envelope === "string" ? parseObject(record.envelope) : undefined;
      const close = typeof record.close === "string" && record.close ? record.close : undefined;
      const set = listeners.get(record.sessionId);
      if (!set?.size) return false;
      for (const listener of [...set]) listener({ ...(envelope ? { envelope } : {}), ...(close ? { close } : {}) });
      return true;
    },
    listen(sessionId, listener) {
      let set = listeners.get(sessionId);
      if (!set) listeners.set(sessionId, (set = new Set()));
      set.add(listener);
      return () => {
        set?.delete(listener);
        if (set && !set.size) listeners.delete(sessionId);
      };
    },
  };
}

function parseObject(text: string): Record<string, unknown> | undefined {
  try {
    const value: unknown = JSON.parse(text);
    return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : undefined;
  } catch {
    return undefined;
  }
}

/**
 * The engine's reason a bundle did not open (`sdk.plugin_bundle.<reason>`): `unsupported`, `not_offered`, `unavailable`,
 * `rejected`, `invalid_request`; undefined for any other failure.
 */
export function pluginBundleErrorReason(error: unknown): string | undefined {
  const texts: string[] = [];
  const record = error as { message?: unknown; messageKey?: unknown; code?: unknown; details?: unknown } | null;
  for (const value of [record?.messageKey, record?.message, record?.code, record?.details, error]) {
    if (typeof value === "string") texts.push(value);
    else if (value && typeof value === "object") { try { texts.push(JSON.stringify(value)); } catch { /* skip */ } }
  }
  for (const text of texts) {
    const match = /sdk\.plugin_bundle\.([a-z_]+)/.exec(text);
    if (match) return match[1];
  }
  return undefined;
}

/** A bundle the host should not show: the declarative variant draws instead. Any open failure falls back. */
export function pluginBundleFallsBack(error: unknown): boolean {
  const reason = pluginBundleErrorReason(error);
  return reason !== "invalid_request";
}

/** The opened page as the session reads it, or null when the answer is not one. */
export function pluginBundleOpened(value: unknown): PluginBundleOpened | null {
  const record = value as Partial<PluginBundleOpened> | null;
  if (!record || typeof record.sessionId !== "string" || !record.sessionId || typeof record.root !== "string"
      || typeof record.entry !== "string" || typeof record.origin !== "string") return null;
  return {
    sessionId: record.sessionId, origin: record.origin, root: record.root, entry: record.entry,
    csp: typeof record.csp === "string" ? record.csp : "",
    ...(Array.isArray(record.files) ? { files: record.files } : {}),
    hello: record.hello && typeof record.hello === "object" ? record.hello : {},
  };
}

/** What a bundle message's answer is: the envelope to post or the host request to draw. */
export type PluginBundleAnswer = { envelope: Record<string, unknown> } | { host: { id: string; method: string; params: Record<string, unknown> } } | null;

/**
 * One open bundle page over the port: the bridge a host's frame (the kit's FlarePluginBundleHost) runs on. Envelopes are
 * objects on the host side and JSON text towards the engine. `close` ends the session once; later calls answer nothing.
 */
export class PluginBundleSession {
  private ended = false;
  constructor(private readonly port: PluginBundlePort, readonly opened: PluginBundleOpened, private readonly events?: PluginBundleEventHub) {}
  get sessionId(): string { return this.opened.sessionId; }
  get isClosed(): boolean { return this.ended; }

  async request(envelope: Record<string, unknown>, context: { userGesture: boolean }): Promise<PluginBundleAnswer> {
    if (this.ended) return null;
    let text: string;
    try { text = JSON.stringify(envelope); } catch { return null; }
    const answer = await this.port.pluginBundleBridge({ sessionId: this.sessionId, envelope: text, userGesture: context.userGesture });
    return pluginBundleAnswer(answer);
  }

  async hostResult(id: string, outcome: { result?: Record<string, unknown>; error?: PluginBundleHostError }): Promise<PluginBundleAnswer> {
    if (this.ended) return null;
    const answer = await this.port.pluginBundleHostResult({ sessionId: this.sessionId, id,
      ...(outcome.error ? { error: outcome.error } : { result: outcome.result ?? {} }) });
    return pluginBundleAnswer(answer);
  }

  async hostEvent(event: string, payload: Record<string, unknown>): Promise<Record<string, unknown>[]> {
    if (this.ended) return [];
    const answer = await this.port.pluginBundleHostEvent({ event, payload, sessionId: this.sessionId });
    const deliveries = Array.isArray(answer?.deliveries) ? answer.deliveries as Array<{ sessionId?: unknown; envelope?: unknown }> : [];
    return deliveries
      .filter((delivery) => delivery.sessionId === this.sessionId && typeof delivery.envelope === "string")
      .map((delivery) => parseObject(delivery.envelope as string))
      .filter((envelope): envelope is Record<string, unknown> => Boolean(envelope));
  }

  subscribe(listener: (event: { envelope?: Record<string, unknown>; close?: string }) => void): () => void {
    if (!this.events) return () => undefined;
    return this.events.listen(this.sessionId, (event) => {
      if (event.close) this.ended = true;
      listener(event);
    });
  }

  close(): void {
    if (this.ended) return;
    this.ended = true;
    void this.port.pluginBundleClose({ sessionId: this.sessionId }).catch(() => undefined);
  }
}

/** `plugin_bundle_bridge` / `plugin_bundle_host_result` answers as the host reads them. */
export function pluginBundleAnswer(value: unknown): PluginBundleAnswer {
  const record = value as { envelope?: unknown; host?: { id?: unknown; method?: unknown; params?: unknown } } | null;
  if (record?.host && typeof record.host.id === "string" && typeof record.host.method === "string") {
    const params = record.host.params && typeof record.host.params === "object" && !Array.isArray(record.host.params)
      ? record.host.params as Record<string, unknown> : {};
    return { host: { id: record.host.id, method: record.host.method, params } };
  }
  if (typeof record?.envelope === "string") {
    const envelope = parseObject(record.envelope);
    return envelope ? { envelope } : null;
  }
  return null;
}

/**
 * Opens a bundle page. Resolves with its session, or null when the declarative variant should draw instead (the
 * catalog offers no bundle for the contribution, the host reports no runtime, the bundle is unavailable or refused).
 * Other failures reject.
 */
export async function openPluginBundle(port: PluginBundlePort, request: PluginBundleOpenRequest, events?: PluginBundleEventHub): Promise<PluginBundleSession | null> {
  let value: unknown;
  try {
    value = await port.pluginBundleOpen(request);
  } catch (error) {
    if (pluginBundleFallsBack(error)) return null;
    throw error;
  }
  const opened = pluginBundleOpened(value);
  if (!opened) return null;
  return new PluginBundleSession(port, opened, events);
}

/** Whether the port reaches the bundle routes. */
export function isPluginBundlePort(port: unknown): port is PluginBundlePort {
  const candidate = port as Partial<PluginBundlePort> | null;
  return Boolean(candidate && typeof candidate.pluginBundleOpen === "function" && typeof candidate.pluginBundleBridge === "function"
    && typeof candidate.pluginBundleHostResult === "function" && typeof candidate.pluginBundleClose === "function"
    && typeof candidate.pluginBundleHostEvent === "function");
}

/** The web bundle runtime a host reports in `plugin.set_host_profile` (`bundleRuntime`). */
export interface PluginBundleRuntime {
  bridge: number;
  engine: string;
  engineMajor: number;
}

/** The bridge version this SDK's hosts speak. */
export const PLUGIN_BUNDLE_BRIDGE_VERSION = 1;

/**
 * The floors a browser engine must meet before a host reports a runtime: sandboxed frames with opaque origins, module
 * scripts, CSP level 3 (`style-src-attr`) and `navigator.userActivation`.
 */
export const PLUGIN_BUNDLE_ENGINE_FLOORS: Readonly<Record<string, number>> = { chromium: 111, gecko: 115, webkit: 16 };

/** What the runtime reads of the browser. */
export interface PluginBundleNavigator {
  userAgent: string;
  userAgentData?: { brands?: ReadonlyArray<{ brand: string; version: string }> };
}

/**
 * The browser's engine as `bundleRuntime`, or undefined when it is below the floor or unknown (the host then reports no
 * runtime and Core never selects a bundle variant for it). Chromium (Chrome, Edge, WebView2) by its brands or `Chrome/`,
 * Firefox by `Firefox/`, Safari by `Version/`; a WebKit view without `Version/` (WKWebView, WebKitGTK) by its
 * `AppleWebKit/` build, which must be 605 or later and is reported as major 16.
 */
export function browserBundleRuntime(nav: PluginBundleNavigator | undefined = typeof navigator === "undefined" ? undefined : navigator): PluginBundleRuntime | undefined {
  if (!nav) return undefined;
  const runtime = (engine: string, major: number): PluginBundleRuntime | undefined =>
    Number.isFinite(major) && major >= (PLUGIN_BUNDLE_ENGINE_FLOORS[engine] ?? Infinity)
      ? { bridge: PLUGIN_BUNDLE_BRIDGE_VERSION, engine, engineMajor: Math.floor(major) } : undefined;
  const brand = nav.userAgentData?.brands?.find((entry) => entry.brand === "Chromium");
  if (brand) return runtime("chromium", Number.parseInt(brand.version, 10));
  const ua = nav.userAgent ?? "";
  const firefox = /Firefox\/(\d+)/.exec(ua);
  if (firefox) return runtime("gecko", Number(firefox[1]));
  const chrome = /(?:Chrome|Chromium|CriOS|Edg)\/(\d+)/.exec(ua);
  if (chrome) return runtime("chromium", Number(chrome[1]));
  const webkit = /AppleWebKit\/(\d+)/.exec(ua);
  if (webkit) {
    const version = /Version\/(\d+)/.exec(ua);
    if (version) return runtime("webkit", Number(version[1]));
    return Number(webkit[1]) >= 605 ? runtime("webkit", 16) : undefined;
  }
  return undefined;
}
