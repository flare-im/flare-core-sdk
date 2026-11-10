import { pluginFormErrors, pluginViewExtras, type PluginActionOutcome, type PluginCardPresentation, type PluginDetailPage, type PluginDetailPresentation, type PluginPagePage, type PluginPagePresentation, type PluginPresentation, type UiFileReference } from "./view";
export * from "./view";
/** Runtime adaptation only. Rust owns schema evaluation, lease/permission
 * checks, action declaration and history fallback on every platform. */
export interface PluginUiPort {
  catalog(): Promise<unknown>;
  resolveMessage(payload: unknown): Promise<unknown>;
  action(payload: unknown): Promise<unknown>;
  /** `capability.plugin_ui_present`: Core reads the catalog itself and, given `messageId`,
   * resolves the card over the shared and local state layers stored on that message.
   * Request: `{message, messageId?, platform, locale, kind}`. */
  presentMessage(request: Record<string, unknown>): Promise<unknown>;
  /** `capability.plugin_ui_invoke`: given `messageId`, Core stores a successful result's
   * `data.sharedState` (this card's entity) and `data.messageState` on that message and emits a
   * message update. Request adds `actionId`, `userGesture`, `conversationId?`, `nativeAllowlist`,
   * `formValues?` and `selection?` to the present fields. */
  invokeAction(request: Record<string, unknown>): Promise<unknown>;
  /** `capability.plugin_detail`: the card's "view all" sheet. Request:
   * `{message, messageId?, conversationId?, platform, locale, userGesture, cursor?, previous?, refresh?}`; returns
   * the resolved view, with `nextCursor` while a paged detail has more. With `cursor` and `previous` Core
   * fetches the next page and returns it appended to `previous`; with `refresh: true` and `previous` it
   * re-reads the sheet from the first page, as many pages as `previous` had loaded. */
  pluginDetail?(request: Record<string, unknown>): Promise<unknown>;
  /** `capability.plugin_page`: a plugin page. Request: `{pluginId, page, platform, conversationId?, locale, arguments?,
   * filters?, cursor?, previous?, refresh?}`; returns the resolved view plus `data`, with `nextCursor`
   * while its source has more. Paging and refresh as for `pluginDetail`. A page action goes through
   * `invokePageAction`. */
  pluginPage?(request: Record<string, unknown>): Promise<unknown>;
  /** `capability.plugin_ui_invoke` for an action run on a plugin page: the host's plugin facade frames the request,
   * naming the page `{pluginId, page}` in place of a message, and returns Core's answer as `invokeAction` does. */
  invokePageAction(request: PluginPageActionRequest): Promise<unknown>;
  /** Core validates the real page declaration and owns private prepare/PUT/complete. */
  uploadFile(request: PluginFileUploadRequest): Promise<UiFileReference>;
  dispatch(request: { capabilityId: string; payload: unknown; conversationId?: string; tenantId?: string; userId?: string }): Promise<unknown>;
}
/**
 * An action run on a plugin page, as the port takes it: no message is named, so Core writes no card state. A document
 * action binds over the page's `data`; a rows action takes `row` as the view's rows gave it (`{key, input}`); `formValues`
 * and `selection` go to Core as for a card.
 */
export type PluginPageActionRequest = {
  pluginId: string; page: string; actionId: string; platform: PluginPlatform; userGesture: boolean;
  nativeAllowlist: readonly string[];
  data?: Record<string, unknown>; row?: { key: string; input: Record<string, unknown> }; conversationId?: string;
  formValues?: Record<string, unknown>; selection?: readonly number[];
};
/** `capability.plugin_file_upload` payload. Reuse commandId for an explicit
 * retry of this file/scope; grants and intermediate upload replies never leave
 * Core or enter the financial command journal. */
export interface PluginFileUploadRequest {
  page: { pluginId: string; page: string };
  inputId: string;
  platform: PluginPlatform;
  locale?: string;
  conversationId?: string;
  arguments?: Record<string, unknown>;
  data?: Record<string, unknown>;
  formValues?: Record<string, unknown>;
  fileName: string;
  contentType: string;
  bytes: readonly number[];
  commandId: string;
}
export interface PluginMessageEnvelope {
  pluginId: string; contributionId: string; schemaVersion: number;
  summary: string; payload: Record<string, unknown>;
  /** The plugin's name, written by the platform when it posts the card; for inert cards to name their plugin. */
  displayName?: string;
}
export type PluginPlatform = "web" | "tauri" | "android" | "ios" | "flutter" | "harmonyos";
/** The locales plugin manifests translate into: `zh-CN` (the base text) and `en-US`. */
export type PluginManifestLocale = "zh-CN" | "en-US";
/**
 * The manifest locale for the host's UI language tag (BCP-47): any English tag is `en-US`, everything else the base
 * `zh-CN`, the way the kit falls back. Pass it as the `locale` of plugin calls.
 */
export function pluginManifestLocale(tag: string | null | undefined): PluginManifestLocale {
  return String(tag ?? "").trim().toLowerCase().startsWith("en") ? "en-US" : "zh-CN";
}
/** A page target: the plugin page an action opens, always of the plugin that declared the action. */
export interface PluginPageTarget { pluginId: string; page: string; /** Host route context; never read from business payload. */ conversationId?: string }
/** Core's rule for a card's `messageId`: non-empty, at most 256 bytes, no whitespace or control characters. */
export function validPluginMessageId(id: string): boolean {
  return id.length > 0 && new TextEncoder().encode(id).length <= 256 && !/[\s\p{Cc}]/u.test(id);
}
export interface NativePluginBridge {
  capabilities: ReadonlyArray<"selectImage" | "selectFile" | "camera" | "microphone" | "clipboardWrite">;
  invoke(capability: string, payload: Record<string, unknown>): Promise<unknown>;
}
export class PluginUiSession {
  private generation = 0;
  private catalogInFlight: Promise<unknown> | null = null;
  constructor(private readonly port: PluginUiPort, readonly platform: PluginPlatform,
    private readonly locale: () => string = () => "en-US", private readonly native?: NativePluginBridge,
    /** Opens a plugin page (of the plugin whose card or page ran the action) with its arguments (the payload the
     * opening action bound). */
    private readonly navigate?: (target: PluginPageTarget, args?: Record<string, unknown>) => void) {}
  reset(): void { this.generation++; this.catalogInFlight = null; }
  async uploadFile(request: Omit<PluginFileUploadRequest, "platform" | "locale">): Promise<UiFileReference> {
    const generation = this.generation;
    const value = await this.port.uploadFile({ ...request, platform: this.platform, locale: this.locale() });
    if (generation !== this.generation) throw new Error("Plugin file upload session changed");
    if (!value || typeof value !== "object" || Object.keys(value).length !== 1
        || typeof value.fileId !== "string" || !/^[A-Za-z0-9_:-]{1,128}$/.test(value.fileId)) {
      throw new Error("Invalid plugin file upload reference");
    }
    return value;
  }
  private catalogForView(): Promise<unknown> {
    if (this.catalogInFlight) return this.catalogInFlight;
    const pending = this.port.catalog();
    this.catalogInFlight = pending;
    const clear = () => { if (this.catalogInFlight === pending) this.catalogInFlight = null; };
    void pending.then(clear, clear);
    return pending;
  }
  /** Source serialization uses UTF-8 byte arrays for CustomElem.payload. */
  envelope(content: Record<string, unknown>): PluginMessageEnvelope | null {
    const bytes = content.payload;
    if (!Array.isArray(bytes) || bytes.length > 65536 || bytes.some((v) => !Number.isInteger(v) || v < 0 || v > 255)) return null;
    try {
      const value: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(bytes)));
      if (!value || typeof value !== "object") return null;
      const message = value as PluginMessageEnvelope;
      return typeof message.pluginId === "string" && typeof message.contributionId === "string" && typeof message.summary === "string" && message.payload && typeof message.payload === "object" ? message : null;
    } catch { return null; }
  }
  async resolve(message: PluginMessageEnvelope, kind: "message-content" | "message-action" | "conversation-menu" | "composer-action" | "page" = "message-content"): Promise<PluginPresentation> {
    const generation = this.generation;
    try {
      // A timeline can mount hundreds of cards together. Coalesce concurrent
      // reads only; retain no positive authorization cache after completion.
      const catalog = await this.catalogForView();
      if (generation !== this.generation) return this.fallback(message.summary);
      const result = await this.port.resolveMessage({ catalog, message, platform: this.platform, kind, locale: this.locale() });
      if (generation !== this.generation) return this.fallback(message.summary);
      const view = result as PluginPresentation;
      if (!view || typeof view.available !== "boolean" || typeof view.title !== "string" || !Array.isArray(view.fields) || !Array.isArray(view.actions)) return this.fallback(message.summary);
      return view;
    } catch { return this.fallback(message.summary); }
  }
  fallback(summary: string): PluginPresentation { return { available: false, title: summary.slice(0, 256), fields: [], actions: [] }; }
  /**
   * Present a stored message's card through Core. With a valid `messageId`, Core resolves the card
   * over the state layers stored on that message (payload, then the shared layer Core publishes,
   * then the viewer's local layer), so `data` and the view (fields, blocks, `hiddenWhen`) see them.
   * The v2 members (`blocks`, `inputs`, `detail`, `sharedStateVersion`) are present only when set.
   * A message id Core would refuse is left out rather than failing the whole card.
   */
  async present(message: PluginMessageEnvelope, messageId?: string,
    kind: "message-content" | "message-action" | "conversation-menu" | "composer-action" | "page" = "message-content"): Promise<PluginCardPresentation> {
    const generation = this.generation;
    const fallback = (): PluginCardPresentation => ({ ...this.fallback(message.summary), stateVersion: 0 });
    try {
      const value = await this.port.presentMessage({ message, ...(messageId && validPluginMessageId(messageId) ? { messageId } : {}),
        platform: this.platform, locale: this.locale(), kind });
      if (generation !== this.generation) return fallback();
      const view = value as PluginCardPresentation | null;
      if (!view || typeof view.available !== "boolean" || typeof view.title !== "string" || !Array.isArray(view.fields) || !Array.isArray(view.actions)) return fallback();
      const stateVersion = Number.isSafeInteger(view.stateVersion) && view.stateVersion >= 0 ? view.stateVersion : 0;
      const shared = view.sharedStateVersion;
      const sharedStateVersion = typeof shared === "number" && Number.isSafeInteger(shared) && shared > 0 ? shared : undefined;
      const data = view.available && view.data && typeof view.data === "object" && !Array.isArray(view.data) ? view.data : undefined;
      return { available: view.available, title: view.title, fields: view.fields, actions: view.actions,
        ...pluginViewExtras(view as unknown as Record<string, unknown>), stateVersion,
        ...(sharedStateVersion ? { sharedStateVersion } : {}), ...(data ? { data } : {}) };
    } catch { return fallback(); }
  }
  /**
   * Run a card action through Core, which refreshes the grant and binds the declared input over the
   * merged card data. An action with a `form` takes `formValues` ({inputId: value}); Core validates
   * them first and returns `formErrors` without sending anything. A choices action takes
   * `selection` (option indices). With `messageId` Core persists the result's `data.sharedState`
   * and `data.messageState` on that message. Operation targets return the capability response;
   * page and native targets run here, as `invoke` does.
   */
  async invokeAction(message: PluginMessageEnvelope, actionId: string,
    options: { messageId?: string; conversationId?: string; userGesture: boolean; formValues?: Record<string, unknown>; selection?: number[] }): Promise<PluginActionOutcome> {
    const generation = this.generation;
    const { messageId, conversationId, userGesture, formValues, selection } = options;
    const value = await this.port.invokeAction({ message, ...(messageId && validPluginMessageId(messageId) ? { messageId } : {}),
      ...(conversationId ? { conversationId } : {}), platform: this.platform, actionId, userGesture, nativeAllowlist: this.native?.capabilities ?? [],
      ...(formValues ? { formValues } : {}), ...(selection ? { selection } : {}) });
    if (generation !== this.generation) throw new Error("Plugin session changed");
    return this.actionOutcome(value, message.pluginId, conversationId);
  }
  /**
   * A plugin page (a `page` contribution, such as a wallet) through Core: its source query is called
   * with the input bound from `args` (the payload of the action that opened it, `{}` from an account
   * entry) plus validated `filters`, and the page document is resolved against the result. Paging and
   * refresh work as for `detail`. An unavailable plugin (disabled, uninstalled, not permitted, catalog
   * unreachable) gives an inert page with `unavailableReason` on the first page and on a refresh; a
   * next page throws instead. Throws when the port has no page call or the session changed meanwhile.
   */
  async page(pluginId: string, page: string, options: { conversationId?: string; args?: Record<string, unknown>; filters?: Record<string, unknown>; page?: PluginPagePage; refresh?: PluginPagePresentation } = {}): Promise<PluginPagePresentation> {
    const generation = this.generation;
    if (!this.port.pluginPage) throw new Error("Plugin page unavailable");
    const { args, filters, page: next, refresh } = options;
    const conversationId = options.conversationId ?? next?.previous.conversationId ?? refresh?.conversationId;
    if (next && refresh) throw new Error("Plugin page: page and refresh exclude each other");
    const value = await this.port.pluginPage({ pluginId, page, platform: this.platform, locale: this.locale(),
      ...(conversationId ? { conversationId } : {}), ...(args ? { arguments: args } : {}), ...(filters ? { filters } : {}),
      ...(next ? { cursor: next.cursor, previous: next.previous } : {}), ...(refresh ? { refresh: true, previous: refresh } : {}) });
    if (generation !== this.generation) throw new Error("Plugin session changed");
    const view = value as PluginPagePresentation | null;
    if (!view || typeof view.available !== "boolean" || typeof view.title !== "string" || !Array.isArray(view.fields) || !Array.isArray(view.actions)) {
      throw new Error("Plugin page unavailable");
    }
    const nextCursor = typeof view.nextCursor === "string" && view.nextCursor ? view.nextCursor : undefined;
    const data = view.available && view.data && typeof view.data === "object" && !Array.isArray(view.data) ? view.data : undefined;
    return { available: view.available, title: view.title, fields: view.fields, actions: view.actions,
      ...pluginViewExtras(view as unknown as Record<string, unknown>), ...(nextCursor ? { nextCursor } : {}), ...(typeof view.conversationId === "string" ? { conversationId: view.conversationId } : conversationId ? { conversationId } : {}), ...(data ? { data } : {}) };
  }
  /**
   * Run a page action through Core: a document action binds over the page's `data`, a row action
   * takes `row` as the view's rows gave it (`{key, input}`), with `formValues` and `selection` as for
   * a card. No message is named. The port's `invokePageAction` frames the request. Page targets open
   * through `navigate` with the bound payload as the next page's arguments; native targets run here.
   */
  async invokePageAction(pluginId: string, page: string, actionId: string,
    options: { data?: Record<string, unknown>; row?: { key: string; input: Record<string, unknown> }; conversationId?: string; userGesture: boolean; formValues?: Record<string, unknown>; selection?: number[] }): Promise<PluginActionOutcome> {
    const generation = this.generation;
    const { data, row, conversationId, userGesture, formValues, selection } = options;
    const value = await this.port.invokePageAction({ pluginId, page, actionId, platform: this.platform, userGesture,
      nativeAllowlist: this.native?.capabilities ?? [], ...(data ? { data } : {}), ...(row ? { row } : {}),
      ...(conversationId ? { conversationId } : {}), ...(formValues ? { formValues } : {}), ...(selection ? { selection } : {}) });
    if (generation !== this.generation) throw new Error("Plugin session changed");
    return this.actionOutcome(value, pluginId, conversationId);
  }
  /** Core's answer to a card or page action: an operation's response, form problems, or a host target run here (a
   * page target of the plugin that declared the action, unless it names another, or an allowed native capability). */
  private async actionOutcome(value: unknown, pluginId: string, conversationId?: string): Promise<PluginActionOutcome> {
    const result = value as { kind?: unknown; response?: unknown; errors?: unknown; conversationId?: unknown; target?: { kind: string; page?: string; pluginId?: string; capability?: string }; payload?: Record<string, unknown> } | null;
    if (result?.kind === "operation" && result.response && typeof result.response === "object") {
      return { kind: "operation", response: result.response as Extract<PluginActionOutcome, { kind: "operation" }>["response"] };
    }
    if (result?.kind === "formErrors") return { kind: "formErrors", errors: pluginFormErrors(result.errors) };
    const target = result?.kind === "host" ? result.target : undefined;
    if (target?.kind === "page" && typeof target.page === "string" && this.navigate) {
      const context = conversationId ?? (typeof result?.conversationId === "string" ? result.conversationId : undefined);
      if (conversationId && typeof result?.conversationId === "string" && conversationId !== result.conversationId) throw new Error("Plugin page conversation changed");
      return { kind: "host", result: this.navigate({ pluginId: typeof target.pluginId === "string" ? target.pluginId : pluginId, page: target.page, ...(context ? { conversationId: context } : {}) }, result?.payload ?? {}) };
    }
    if (target?.kind === "native" && typeof target.capability === "string" && this.native?.capabilities.includes(target.capability as never)) {
      return { kind: "host", result: await this.native.invoke(target.capability, result?.payload ?? {}) };
    }
    throw new Error("Plugin target unavailable");
  }
  /**
   * The card's "view all" sheet: Core runs the contribution's detail operation with the input bound
   * over the merged card data and resolves the detail document against its result. A paged detail
   * carries `nextCursor` while it has more; pass `page: { cursor: sheet.nextCursor, previous: sheet }`
   * to load the next page: Core appends it to `previous` (entries continue in order, the rest stays
   * as on the first page) and returns the merged sheet, so hosts never merge pages.
   *
   * To re-read the sheet on show (after a state change, say), pass `refresh: sheet`: Core reads the
   * first page again and as many more as the sheet had loaded (at most 10 pages), and the result
   * replaces the sheet wholesale, with `nextCursor` while more remain. `page` and `refresh` exclude
   * each other. Throws when the port has no detail call, the plugin fails (on a refresh: keep showing
   * the sheet), or the session changed meanwhile.
   */
  async detail(message: PluginMessageEnvelope, options: { messageId?: string; conversationId?: string; userGesture: boolean; page?: PluginDetailPage; refresh?: PluginDetailPresentation }): Promise<PluginDetailPresentation> {
    const generation = this.generation;
    if (!this.port.pluginDetail) throw new Error("Plugin detail unavailable");
    const { messageId, conversationId, userGesture, page, refresh } = options;
    if (page && refresh) throw new Error("Plugin detail: page and refresh exclude each other");
    const value = await this.port.pluginDetail({ message, ...(messageId && validPluginMessageId(messageId) ? { messageId } : {}),
      ...(conversationId ? { conversationId } : {}), platform: this.platform, locale: this.locale(), userGesture,
      ...(page ? { cursor: page.cursor, previous: page.previous } : {}), ...(refresh ? { refresh: true, previous: refresh } : {}) });
    if (generation !== this.generation) throw new Error("Plugin session changed");
    const view = value as PluginDetailPresentation | null;
    if (!view || typeof view.available !== "boolean" || typeof view.title !== "string" || !Array.isArray(view.fields) || !Array.isArray(view.actions)) {
      throw new Error("Plugin detail unavailable");
    }
    const nextCursor = typeof view.nextCursor === "string" && view.nextCursor ? view.nextCursor : undefined;
    return { available: view.available, title: view.title, fields: view.fields, actions: view.actions,
      ...pluginViewExtras(view as unknown as Record<string, unknown>), ...(nextCursor ? { nextCursor } : {}) };
  }
  async invoke(message: PluginMessageEnvelope, actionId: string, userGesture: boolean): Promise<unknown> {
    const generation = this.generation;
    const catalog = await this.port.catalog(); // Recheck latest grant before each action.
    const value = await this.port.action({ catalog, platform: this.platform, pluginId: message.pluginId,
      contributionId: message.contributionId, actionId, userGesture, payload: message.payload, nativeAllowlist: this.native?.capabilities ?? [] });
    if (generation !== this.generation) throw new Error("Plugin session changed");
    const prepared = value as { target: { kind: string; operation?: string; page?: string; pluginId?: string; capability?: string }; payload: Record<string, unknown> };
    const target = prepared.target;
    switch (target.kind) {
      case "operation":
        if (typeof target.operation !== "string") break;
        return this.port.dispatch({ capabilityId: target.operation, payload: prepared.payload });
      case "page":
        if (typeof target.page !== "string" || !this.navigate) break;
        return this.navigate({ pluginId: typeof target.pluginId === "string" ? target.pluginId : message.pluginId, page: target.page });
      case "native":
        if (typeof target.capability !== "string" || !this.native || !this.native.capabilities.includes(target.capability as never)) break;
        return this.native.invoke(target.capability, prepared.payload);
    }
    throw new Error("Plugin target unavailable");
  }
}
