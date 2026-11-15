import type { FlarePluginFileAction, FlarePluginFileState, FlarePluginInput } from "@flare-im/vue-ui";
import type { PluginActionOutcome, PluginFileUploadRequest, PluginUiPort } from "@flare-im/sdk/plugin-ui";

export interface PluginFileContext {
  /** Changes with the authenticated viewer, page or presentation lifetime. */
  identity: unknown;
  port: PluginUiPort;
  page: PluginFileUploadRequest["page"];
  platform: PluginFileUploadRequest["platform"];
  locale?: string;
  conversationId?: string;
  arguments?: Record<string, unknown>;
  data?: Record<string, unknown>;
}

interface Selection {
  scope: string;
  generation: number;
  file?: File;
  commandId: string;
  previewUrl?: string;
  picker?: AbortController;
}

export interface PluginFileUploadOptions {
  context(): PluginFileContext | null;
  changed(states: Record<string, FlarePluginFileState>): void;
  choose(input: FlarePluginInput, signal?: AbortSignal): Promise<File | null>;
  failure(kind: "policy" | "transport"): string;
  preview(url: string, fileName: string): void;
  commandId?: () => string;
  createUrl?: (file: File) => string;
  revokeUrl?: (url: string) => void;
}

/** Snapshot only the immutable viewer fence, not balances or account lists. */
export function pluginFileSessionData(data: unknown): Record<string, unknown> {
  const session = data && typeof data === "object" ? (data as Record<string, unknown>)._session : null;
  const value = session && typeof session === "object" ? session as Record<string, unknown> : null;
  return { _session: value ? {
    tenantId: typeof value.tenantId === "string" ? value.tenantId : null,
    userId: typeof value.userId === "string" ? value.userId : null,
  } : null };
}

/** Host adaptation only. Rust owns authorization, material intents and transfer. */
export class PluginFileUploads {
  private readonly selections = new Map<string, Selection>();
  private states: Record<string, FlarePluginFileState> = {};
  constructor(private readonly options: PluginFileUploadOptions) {}

  clear(): void {
    for (const selection of this.selections.values()) this.release(selection);
    this.selections.clear();
    this.seen.clear();
    this.states = {};
    this.publish();
  }

  private release(selection?: Selection): void {
    selection?.picker?.abort();
    if (selection?.previewUrl) (this.options.revokeUrl ?? URL.revokeObjectURL)(selection.previewUrl);
    if (selection) selection.previewUrl = undefined;
  }

  private publish(): void { this.options.changed({ ...this.states }); }

  /**
   * A document input (or any upload input a host capability fills): the engine captures and uploads it
   * (`documentCapture` with `into`), so the host only shows the input uploading and then the reference the engine
   * wrote. A refusal or a cancel leaves the input as it was; a failure marks it failed.
   */
  async captured(event: FlarePluginFileAction, run: () => Promise<PluginActionOutcome>, fileName?: string): Promise<void> {
    const { inputId, scope, generation } = event;
    this.seen.set(inputId, { scope, generation });
    const previous = this.selections.get(inputId);
    if (previous?.scope === scope && previous.generation > generation) return;
    const context = this.options.context();
    if (!context) return;
    const oldState = this.states[inputId];
    this.release(previous);
    const selected: Selection = { scope, generation, commandId: "" };
    this.selections.set(inputId, selected);
    const current = () => {
      const now = this.options.context();
      return now !== null && this.selections.get(inputId) === selected && now.identity === context.identity && now.port === context.port;
    };
    const state = (value: Omit<FlarePluginFileState, "scope" | "generation">) => {
      if (!current()) return;
      this.states[inputId] = { scope, generation, ...value };
      this.publish();
    };
    state({ phase: "uploading", ...(fileName ? { fileName } : {}) });
    try {
      const outcome = await run();
      if (!current()) return;
      if (outcome.kind === "input" && outcome.input === inputId && pluginFileReference(outcome.value)) {
        state({ phase: "uploaded", value: { fileId: outcome.value.fileId }, ...(fileName ? { fileName } : {}) });
      } else if (outcome.kind === "declined" && outcome.reason !== "unavailable") {
        if (oldState && oldState.scope === scope) this.states[inputId] = { ...oldState, generation };
        else this.states[inputId] = { scope, generation, phase: "empty" };
        this.publish();
      } else {
        state({ phase: "failed", error: this.options.failure("transport"), ...(fileName ? { fileName } : {}) });
      }
    } catch {
      state({ phase: "failed", error: this.options.failure("transport"), ...(fileName ? { fileName } : {}) });
    }
  }

  /**
   * A reference a host capability wrote into `inputId` outside the input's own key (a page's native action with
   * `into`): shown as uploaded in the input's current form, when the form has told us which one it is.
   */
  settle(inputId: string, value: unknown, fileName?: string): boolean {
    const known = this.selections.get(inputId) ?? this.seen.get(inputId);
    if (!known || !pluginFileReference(value)) return false;
    this.states[inputId] = { scope: known.scope, generation: known.generation, phase: "uploaded", value: { fileId: value.fileId },
      ...(fileName ? { fileName } : {}) };
    this.publish();
    return true;
  }

  /** The form an input was last seen in (every file action names it). */
  private readonly seen = new Map<string, { scope: string; generation: number }>();

  async action(event: FlarePluginFileAction): Promise<void> {
    const { inputId, scope, generation } = event;
    this.seen.set(inputId, { scope, generation });
    const previous = this.selections.get(inputId);
    const oldState = this.states[inputId];
    if (event.action === "preview") {
      if (previous?.scope === scope && previous.generation === generation && previous.previewUrl)
        this.options.preview(previous.previewUrl, previous.file?.name ?? "");
      return;
    }
    if (["cancel", "remove", "invalidate"].includes(event.action)) {
      if (previous && (previous.scope !== scope || previous.generation > generation)) return;
      this.release(previous);
      this.selections.delete(inputId);
      this.states[inputId] = { scope, generation, phase: "empty" };
      this.publish();
      return;
    }
    const context = this.options.context();
    if (!context || event.input.kind !== "file" || !event.input.file) return;
    if (previous?.scope === scope && previous.generation > generation) return;
    const retry = event.action === "retry";
    const selected: Selection = {
      scope, generation,
      commandId: retry && previous?.scope === scope
        ? previous.commandId : (this.options.commandId ?? (() => crypto.randomUUID()))(),
      ...(retry && previous?.scope === scope ? { file: previous.file, previewUrl: previous.previewUrl } : {}),
    };
    this.selections.set(inputId, selected);
    const current = () => {
      const now = this.options.context();
      return now !== null && this.selections.get(inputId) === selected && now.identity === context.identity && now.port === context.port;
    };
    const state = (value: Omit<FlarePluginFileState, "scope" | "generation">) => {
      if (!current()) return;
      this.states[inputId] = { scope, generation, ...value };
      this.publish();
    };
    try {
      if (!retry) {
        this.release(previous);
        selected.picker = new AbortController();
        const file = await this.options.choose(event.input, selected.picker.signal);
        selected.picker = undefined;
        if (!current()) return;
        if (!file) {
          // Dismissing the system picker is not a replacement or deletion.
          if (previous?.scope === scope && oldState) {
            if (previous.file && pluginFileContentType(previous.file).startsWith("image/"))
              previous.previewUrl = (this.options.createUrl ?? URL.createObjectURL)(previous.file);
            this.selections.set(inputId, { ...previous, scope, generation });
            const interrupted = oldState.phase === "selected" || oldState.phase === "uploading";
            this.states[inputId] = { ...oldState, scope, generation, preview: !!previous.previewUrl,
              ...(interrupted ? { phase: "failed", error: this.options.failure("transport") } : {}) };
          } else {
            this.selections.delete(inputId);
            this.states[inputId] = { scope, generation, phase: "empty" };
          }
          this.publish();
          return;
        }
        selected.file = file;
      }
      const file = selected.file;
      if (!file) throw new PluginFilePolicyError();
      const policy = event.input.file;
      const contentType = pluginFileContentType(file);
      if (!file.size || file.size > policy.maxBytes || !policy.accept.includes(contentType))
        throw new PluginFilePolicyError();
      if (!selected.previewUrl && contentType.startsWith("image/"))
        selected.previewUrl = (this.options.createUrl ?? URL.createObjectURL)(file);
      state({ phase: "selected", fileName: file.name, preview: !!selected.previewUrl });
      const bytes = new Uint8Array(await file.arrayBuffer());
      if (!current()) return;
      if (!bytes.length || bytes.length > policy.maxBytes || bytes.length !== file.size)
        throw new PluginFilePolicyError();
      state({ phase: "uploading", fileName: file.name, preview: !!selected.previewUrl });
      const value = await context.port.uploadFile({
        page: context.page, inputId, platform: context.platform,
        ...(context.locale ? { locale: context.locale } : {}),
        ...(context.conversationId ? { conversationId: context.conversationId } : {}),
        ...(context.arguments ? { arguments: context.arguments } : {}),
        ...(context.data ? { data: context.data } : {}),
        formValues: event.formValues, fileName: file.name, contentType,
        bytes: Array.from(bytes), commandId: selected.commandId,
      });
      if (!current()) return;
      if (!value || Object.keys(value).length !== 1 || typeof value.fileId !== "string" ||
          !/^[A-Za-z0-9_:-]{1,128}$/.test(value.fileId))
        throw new Error("FILE_UPLOAD_RESPONSE_INVALID");
      state({ phase: "uploaded", value: { fileId: value.fileId }, fileName: file.name, preview: !!selected.previewUrl });
    } catch (cause) {
      state({ phase: "failed", fileName: selected.file?.name,
        error: this.options.failure(cause instanceof PluginFilePolicyError ? "policy" : "transport"), preview: !!selected.previewUrl });
    }
  }
}

class PluginFilePolicyError extends Error {}

/** A stored file reference `{fileId}` as Core returns it, nothing else. */
export function pluginFileReference(value: unknown): value is { fileId: string } {
  return !!value && typeof value === "object" && !Array.isArray(value) && Object.keys(value).length === 1
    && typeof (value as { fileId?: unknown }).fileId === "string" && /^[A-Za-z0-9_:-]{1,128}$/.test((value as { fileId: string }).fileId);
}

export function pluginFileContentType(file: Pick<File, "type" | "name">): string {
  if (file.type) return file.type.toLowerCase();
  const extension = file.name.split(".").pop()?.toLowerCase();
  return extension === "png" ? "image/png" : extension === "jpg" || extension === "jpeg" ? "image/jpeg"
    : extension === "pdf" ? "application/pdf" : "application/octet-stream";
}

/** Native browser picker, not a product control or an upload transport. */
export function choosePluginFile(input: FlarePluginInput, signal?: AbortSignal): Promise<File | null> {
  return new Promise((resolve) => {
    const picker = document.createElement("input");
    picker.type = "file";
    picker.accept = input.file?.accept.join(",") ?? "";
    picker.multiple = false;
    picker.hidden = true;
    let done = false;
    const finish = (file: File | null) => {
      if (done) return;
      done = true;
      signal?.removeEventListener("abort", abort);
      picker.remove();
      resolve(file);
    };
    const abort = () => finish(null);
    picker.addEventListener("change", () => finish(picker.files?.[0] ?? null), { once: true });
    picker.addEventListener("cancel", () => finish(null), { once: true });
    if (signal?.aborted) { finish(null); return; }
    signal?.addEventListener("abort", abort, { once: true });
    document.body.appendChild(picker);
    picker.click();
  });
}
