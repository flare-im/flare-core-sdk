/**
 * CorePluginPage: a plugin page over the core's `pluginPage` with its own stack. The first page, a next page with the
 * cursor and the shown page, a filter as the first page again, a refresh with the shown page; page actions through
 * the core's invoke with the page, its data and the row, never a message; a page target pushed with its own plugin and
 * the bound payload as arguments, popped by back, and `back` out of the root.
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { defineComponent, h, nextTick, shallowRef, type Component } from "vue";
import { flushPromises, mount } from "@vue/test-utils";
import { FlarePluginPage, type FlarePluginPageKind } from "@flare-im/vue-ui";
import { useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import type { NativePluginBridge, PluginNativeContext, PluginUiPort } from "@flare-im/sdk/plugin-ui";
import { CorePluginPage, corePluginPageEntry, provideCorePluginNativeBridge, type CorePluginPageEntry } from "../src/index";
import { fakePort } from "./support";

const root: CorePluginPageEntry = { pluginId: "flare.redpacket", page: "flare.redpacket.wallet", title: "Wallet" };
/** The wallet page as the core resolves it: its view, the data a page action binds over, and a next page. */
const page = (extra: Record<string, unknown> = {}) => ({
  available: true, title: "Wallet", fields: [{ label: "Balance", value: "¥12.30" }], actions: [{ id: "history", label: "History" }],
  data: { balanceText: "¥12.30" }, nextCursor: "c2", ...extra,
});

function pagePort(pluginPage: (request: Record<string, unknown>) => Promise<unknown>, invokePageAction?: (request: Record<string, unknown>) => Promise<unknown>) {
  const port = fakePort(invokePageAction ? { invokePageAction } : {});
  return { ...port, pluginPage: vi.fn(pluginPage) };
}
type PagePort = ReturnType<typeof pagePort>;

const mounted: Array<{ unmount(): void }> = [];
afterEach(() => { mounted.splice(0).forEach((wrapper) => wrapper.unmount()); });

function render(port: PluginUiPort | null, props: Record<string, unknown> = {}, native?: NativePluginBridge) {
  const onBack = vi.fn();
  const portRef = shallowRef(port);
  const rootRef = shallowRef((props.root as CorePluginPageEntry | undefined) ?? root);
  const visibleRef = shallowRef(props.visible !== false);
  const forwardedProps = { ...props };
  delete forwardedProps.root;
  delete forwardedProps.visible;
  delete forwardedProps.omitVisible;
  const wrapper = mount(defineComponent({ setup() {
    useFlareI18nProvider("en-US");
    if (native) provideCorePluginNativeBridge(native);
    return () => h(CorePluginPage as Component, { root: rootRef.value, ...(props.omitVisible ? {} : { visible: visibleRef.value }), port: portRef.value, platform: "web", loadFailedText: "The page didn't load", onBack, ...forwardedProps });
  } }));
  mounted.push(wrapper);
  const host = () => wrapper.getComponent(FlarePluginPage);
  return { wrapper, host, onBack, portRef, rootRef, visibleRef };
}
const calls = (port: PagePort) => port.pluginPage.mock.calls.map(([request]) => request);
function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

type Kind = FlarePluginPageKind;
/** R4 / §12.1 vectors, shared by the four hosts. */
const refreshVectors = JSON.parse(readFileSync(resolve(__dirname, "../../../../flare-im-design/spec/plugin-refresh-vectors.json"), "utf8")) as {
  afterReturn: Array<{ name: string; event: "pop" | "done" | "messageCard"; origin?: boolean; expect: { refresh: boolean; page: "self" | "origin" | "close" } }>;
  doneTarget: Array<{ name: string; stack: Kind[]; expect: { target: number | null } }>;
};
/** A view the kit reads as each kind (flarePluginPageKind): an R2 overview, a primary task key, a plain list, a result block. */
const kindViews: Record<Kind, Record<string, unknown>> = {
  overview: { blocks: [{ kind: "stats", items: [{ label: "Open", value: "12" }] }],
    actions: ["a", "b", "c", "d"].map((id) => ({ id, label: id.toUpperCase(), target: { kind: "page", page: `x.${id}` } })) },
  task: { actions: [{ id: "go", label: "Go", style: "primary" }] },
  records: {},
  result: { blocks: [{ kind: "result", state: "completed", title: "Done", tone: "success" }] },
};
/** Pages `p0`…`pN` of one conversation, one per kind, each pushed by an action on the one before. */
async function openStack(kinds: Kind[], props: Record<string, unknown> = {}) {
  const at = (request: Record<string, unknown>) => Number(String(request.page).slice(1));
  const port = pagePort(async (request) => page({ nextCursor: null, ...kindViews[kinds[at(request)]] }),
    async (request) => ({ kind: "host", target: { kind: "page", page: `p${at(request) + 1}` }, payload: {} }));
  const rendered = render(port, { root: { pluginId: root.pluginId, page: "p0", title: "Wallet", conversationId: "chat-1" }, ...props });
  await flushPromises();
  for (let next = 1; next < kinds.length; next++) {
    rendered.host().vm.$emit("action", "next", { page: rendered.host().props("page"), data: {} });
    await flushPromises();
  }
  return { ...rendered, port };
}

describe("CorePluginPage", () => {
  it('keeps custom editor state through refresh and back, and discards it for a reopened flow', async () => {
    const port=pagePort(async()=>page({nextCursor:null}),async()=>({kind:'host',target:{kind:'page',page:'history'},payload:{}}));
    const Content=defineComponent({props:['contentState'],setup:props=>()=>h('input',{
      'data-editor':true,value:props.contentState?.note??'',
      onInput:(event:Event)=>{if(props.contentState)props.contentState.note=(event.target as HTMLInputElement).value;},
    })});
    const {wrapper,host,rootRef}=render(port,{pageContent:(entry: {page:string})=>entry.page===root.page?{component:Content,actionIds:[]}:undefined});
    await flushPromises();await wrapper.get('[data-editor]').setValue('Keep my draft');
    host().vm.$emit('refresh');await flushPromises();
    expect((wrapper.get('[data-editor]').element as HTMLInputElement).value).toBe('Keep my draft');
    host().vm.$emit('action','history',{page:host().props('page'),data:{}});await flushPromises();
    expect(wrapper.find('[data-editor]').exists()).toBe(false);
    host().vm.$emit('back');await flushPromises();
    expect((wrapper.get('[data-editor]').element as HTMLInputElement).value).toBe('Keep my draft');
    rootRef.value={...root};await flushPromises();
    expect((wrapper.get('[data-editor]').element as HTMLInputElement).value).toBe('');
  });
  it('clears custom editor state when its session or visibility changes',async()=>{
    const port=pagePort(async()=>page({nextCursor:null}));
    const Content=defineComponent({props:['contentState'],setup:props=>()=>h('input',{
      'data-editor':true,value:props.contentState?.note??'',
      onInput:(event:Event)=>{if(props.contentState)props.contentState.note=(event.target as HTMLInputElement).value;},
    })});
    const {wrapper,portRef,visibleRef}=render(port,{pageContent:()=>({component:Content,actionIds:[]})});
    await flushPromises();await wrapper.get('[data-editor]').setValue('Session draft');
    portRef.value=pagePort(async()=>page({nextCursor:null}));await flushPromises();
    expect((wrapper.get('[data-editor]').element as HTMLInputElement).value).toBe('');
    await wrapper.get('[data-editor]').setValue('Visible draft');visibleRef.value=false;await flushPromises();
    expect((wrapper.get('[data-editor]').element as HTMLInputElement).value).toBe('');
  });
  it("keeps host-composed kit content on the original page action session", async () => {
    const invoke = vi.fn(async () => ({kind: "formErrors", errors: [{input: "amount", issue: "outOfRange"}]}));
    const port = pagePort(async () => page({actions:[{id:"prepare",label:"Prepare",form:["amount"]}],nextCursor:null}), invoke);
    const Content = defineComponent({props:["view","onAction","formErrors"], setup: props => () => h("button", {
      "data-custom-content":true, onClick:()=>props.onAction("prepare",{formValues:{amount:{amount:"0.01",currency:"CNY"}}}),
    }, props.formErrors.length ? "Correct amount" : props.view.title)});
    const {wrapper} = render(port, {pageContent:()=>({component:Content,actionIds:["prepare"]})});
    await flushPromises();
    expect(invoke).not.toHaveBeenCalled();
    await wrapper.get("[data-custom-content]").trigger("click"); await flushPromises();
    expect(invoke).toHaveBeenCalledOnce();
    expect(invoke).toHaveBeenCalledWith(expect.objectContaining({pluginId:root.pluginId,page:root.page,userGesture:true,
      data:{balanceText:"¥12.30"},formValues:{amount:{amount:"0.01",currency:"CNY"}}}));
    expect(wrapper.get("[data-custom-content]").text()).toBe("Correct amount");
  });
  it("continues an explicit navigation into its host-approved prompt once, in the destination context", async () => {
    const prompt = vi.fn(() => ({ actionId: "authorize", operation: "wallet.prompt" }));
    const invoke = vi.fn(async (request: Record<string, unknown>) => request.page === root.page
      ? { kind: "host", target: { kind: "page", pluginId: "wallet", page: "checkout" }, payload: { intentId: "intent" } }
      : { kind: "operation", response: { success: false } });
    const port = pagePort(async request => page(request.page === "checkout" ? {
      data: { intentId: "intent", amount: "1.00" },
      actions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "wallet.prompt" } }],
    } : {}), invoke);
    const { host } = render(port, { promptOnNavigate: prompt, omitVisible: true });
    await flushPromises();
    expect(prompt).not.toHaveBeenCalled();
    expect(invoke).not.toHaveBeenCalled();
    host().vm.$emit("action", "prepare", { page: host().props("page"), data: {} });
    await flushPromises();
    expect(invoke).toHaveBeenCalledTimes(2);
    expect(invoke).toHaveBeenLastCalledWith(expect.objectContaining({ pluginId: "wallet", page: "checkout", actionId: "authorize",
      data: { intentId: "intent", amount: "1.00" }, userGesture: true }));
    host().vm.$emit("refresh"); await flushPromises();
    host().vm.$emit("back"); await flushPromises();
    expect(invoke).toHaveBeenCalledTimes(2);
    expect(prompt).toHaveBeenCalledOnce();
  });

  it.each([
    { actions: [] },
    { actions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "other.operation" } }] },
    { actions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "wallet.prompt" }, form: ["amount"] }] },
    { actions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "wallet.prompt" }, confirm: "Are you sure?" }] },
  ])("keeps unavailable, changed or additional-consent actions manual: %j", async ({ actions }) => {
    const invoke = vi.fn(async () => ({ kind: "host", target: { kind: "page", page: "checkout" }, payload: {} }));
    const port = pagePort(async request => page(request.page === "checkout" ? { actions } : {}), invoke);
    const { host } = render(port, { promptOnNavigate: () => ({ actionId: "authorize", operation: "wallet.prompt" }) });
    await flushPromises();
    host().vm.$emit("action", "prepare", { page: host().props("page"), data: {} }); await flushPromises();
    expect(invoke).toHaveBeenCalledOnce();
  });

  it("runs the action a navigation names once the pushed page has loaded, and never again on a refresh or a return", async () => {
    const invoke = vi.fn(async (request: Record<string, unknown>) => request.page === root.page
      ? { kind: "host", target: { kind: "page", pluginId: "acme.pay", page: "checkout" }, payload: { intentId: "intent" }, run: "authorize" }
      : request.page === "checkout" ? { kind: "host", target: { kind: "page", page: "result" }, payload: {} }
        : { kind: "operation", response: { success: true, data: {} } });
    const port = pagePort(async request => page(request.page === "checkout" ? {
      data: { intentId: "intent", amount: "1.00" }, actions: [],
      menuActions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "acme.pay.authorize" } }],
    } : {}), invoke);
    const { host } = render(port);
    await flushPromises();
    host().vm.$emit("action", "prepare", { page: host().props("page"), data: {} });
    await flushPromises();
    expect(invoke).toHaveBeenCalledTimes(2);
    expect(invoke).toHaveBeenNthCalledWith(2, expect.objectContaining({ pluginId: "acme.pay", page: "checkout", actionId: "authorize",
      data: { intentId: "intent", amount: "1.00" }, userGesture: true, locale: "en-US" }));
    expect(host().props("page")).toEqual({ pluginId: "acme.pay", page: "result" });
    host().vm.$emit("back"); await flushPromises();
    expect(host().props("page")).toEqual({ pluginId: "acme.pay", page: "checkout" });
    host().vm.$emit("refresh"); await flushPromises();
    expect(invoke).toHaveBeenCalledTimes(2);
  });

  it.each([
    { why: "missing", actions: [] },
    { why: "not an operation", actions: [{ id: "authorize", label: "Continue", target: { kind: "page", page: "elsewhere" } }] },
    { why: "a form", actions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "acme.pay.authorize" }, form: ["amount"] }] },
    { why: "a confirm", actions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "acme.pay.authorize" }, confirm: "Sure?" }] },
    { why: "disabled", actions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "acme.pay.authorize" }, disabledReason: "Not yet" }] },
  ])("leaves the action a navigation names to the viewer when it is $why", async ({ actions }) => {
    const invoke = vi.fn(async () => ({ kind: "host", target: { kind: "page", page: "checkout" }, payload: {}, run: "authorize" }));
    const port = pagePort(async request => page(request.page === "checkout" ? { actions } : {}), invoke);
    const { host } = render(port);
    await flushPromises();
    host().vm.$emit("action", "prepare", { page: host().props("page"), data: {} }); await flushPromises();
    expect(host().props("page")).toEqual({ pluginId: root.pluginId, page: "checkout" });
    expect(invoke).toHaveBeenCalledOnce();
  });

  it("drops a pending destination prompt when its owner is reopened", async () => {
    const pending = deferred<unknown>();
    const invoke = vi.fn(async () => ({ kind: "host", target: { kind: "page", page: "checkout" }, payload: {} }));
    const port = pagePort(async request => request.page === "checkout" ? pending.promise : page(), invoke);
    const { host, rootRef } = render(port, { promptOnNavigate: () => ({ actionId: "authorize", operation: "wallet.prompt" }) });
    await flushPromises();
    host().vm.$emit("action", "prepare", { page: host().props("page"), data: {} }); await flushPromises();
    rootRef.value = { ...root }; await flushPromises();
    pending.resolve(page({ actions: [{ id: "authorize", label: "Continue", target: { kind: "operation", operation: "wallet.prompt" } }] }));
    await flushPromises();
    expect(invoke).toHaveBeenCalledOnce();
    expect(host().props("page")).toEqual({ pluginId: root.pluginId, page: root.page });
  });
  it("inherits an approved host bridge and invalidates its context when hidden", async () => {
    const pending = deferred<unknown>();
    let context: PluginNativeContext | undefined;
    const native: NativePluginBridge = { capabilities: ["reauthenticate"], invoke: vi.fn(async (_capability, _payload, current) => { context = current; return pending.promise; }) };
    const invoke = vi.fn(async () => ({ kind: "host", target: { kind: "native", capability: "reauthenticate" }, payload: { intentId: "opaque-intent" } }));
    const port = pagePort(async () => page(), invoke);
    const { host, visibleRef } = render(port, {}, native); await flushPromises();
    host().vm.$emit("action", "reauth", { page: host().props("page"), data: {} }); await flushPromises();
    expect(invoke).toHaveBeenCalledWith(expect.objectContaining({ pluginId: root.pluginId, page: root.page }));
    expect(context).toMatchObject({ pluginId: root.pluginId, page: root.page, actionId: "reauth" }); expect(context?.isCurrent()).toBe(true);
    visibleRef.value = false; await nextTick(); expect(context?.isCurrent()).toBe(false);
    pending.resolve({ status: "cancelled" }); await flushPromises(); expect(calls(port)).toHaveLength(1);
  });
  it("refreshes the same page after a completed native capability without storing its result", async () => {
    const native: NativePluginBridge = { capabilities: ["reauthenticate"], invoke: vi.fn(async () => ({ status: "complete" })) };
    const port = pagePort(async () => page(), async () => ({ kind: "host", target: { kind: "native", capability: "reauthenticate" }, payload: {} }));
    const { host } = render(port, {}, native); await flushPromises();
    host().vm.$emit("action", "reauth", { page: host().props("page"), data: {} }); await flushPromises();
    // The kit asks for the re-read once the action settles cleanly (refresh "action"); the host adds none of its own.
    expect(calls(port)).toHaveLength(1);
    host().vm.$emit("refresh", "action"); await flushPromises();
    expect(calls(port)).toHaveLength(2); expect(host().props("view")?.data ?? {}).not.toHaveProperty("status");
  });
  it("forwards host-authorized member search and its revision without changing the page owner", async () => {
    const members = [{ userId: "admin", name: "Admin" }];
    const search = vi.fn(); const retry = vi.fn();
    const { host } = render(pagePort(async () => page()), {
      members, membersLoading: true, membersError: "Try again", membersRevision: 4,
      onMemberSearch: search, onMembersRetry: retry,
    });
    await flushPromises();
    expect(host().props("members")).toEqual(members);
    expect(host().props("membersLoading")).toBe(true);
    expect(host().props("membersError")).toBe("Try again");
    expect(host().props("membersRevision")).toBe(4);
    host().props("onMemberSearch")?.("admin"); host().props("onMembersRetry")?.();
    expect(search).toHaveBeenCalledWith("admin"); expect(retry).toHaveBeenCalledOnce();
  });
  it("keeps a pending file through ordinary refresh but invalidates it for a reopened owner", async () => {
    const pending = deferred<{fileId: string}>();
    const port = pagePort(async () => page({data: {_session: {tenantId: "tenant", userId: "person"}}}));
    port.uploadFile = vi.fn(() => pending.promise);
    const {host, rootRef} = render(port);
    await flushPromises();
    const file = new File([new Uint8Array([37, 80, 68, 70])], "proof.pdf", {type: "application/pdf"});
    Object.defineProperty(file, "arrayBuffer", {value: async () => new Uint8Array([37, 80, 68, 70]).buffer});
    const picker = vi.spyOn(HTMLInputElement.prototype, "click").mockImplementation(function(this: HTMLInputElement) {
      Object.defineProperty(this, "files", {value: [file]});
      this.dispatchEvent(new Event("change"));
    });
    try {
      const input = {id: "proof", kind: "file", label: "Proof", file: {
        accept: ["application/pdf"], maxBytes: 5242880,
        upload: {prepareOperation: "prepare", completeOperation: "complete", purpose: "proof"},
      }};
      host().vm.$emit("file-action", {action: "choose", inputId: "proof", input,
        scope: "form-ticket", generation: 1, formValues: {}});
      await flushPromises();
      expect(host().props("fileStates")?.proof.phase).toBe("uploading");
      host().vm.$emit("refresh");
      await flushPromises();
      expect(host().props("fileStates")?.proof.phase).toBe("uploading");
      pending.resolve({fileId: "proof-ready"});
      await flushPromises();
      expect(host().props("fileStates")?.proof).toMatchObject({phase: "uploaded", value: {fileId: "proof-ready"}});
      expect(port.uploadFile).toHaveBeenCalledOnce();
      rootRef.value = {...rootRef.value};
      await flushPromises();
      expect(host().props("fileStates")).toEqual({});
    } finally { picker.mockRestore(); }
  });

  it("finishes the owning flow after a nested payment page posts, without popping a single page or reloading", async () => {
    const posted = { conversationId: "chat-1", serverMsgId: "srv-1", clientMsgId: "client-1" };
    const invoke = vi.fn()
      .mockResolvedValueOnce({ kind: "host", target: { kind: "page", pluginId: "flare.wallet", page: "wallet.authorize" }, conversationId: "chat-1", payload: { paymentId: "pay-1" } })
      .mockResolvedValueOnce({ kind: "operation", response: { success: true, data: { posted } } });
    const port = pagePort(async () => page(), invoke);
    const onPosted = vi.fn();
    const { host, onBack, rootRef } = render(port, { root: { ...root, conversationId: "chat-1" }, onPosted });
    await flushPromises();
    host().vm.$emit("action", "authorize", { page: host().props("page"), data: {} });
    await flushPromises();
    expect(host().props("page")).toEqual({ pluginId: "flare.wallet", page: "wallet.authorize" });
    expect(onPosted).not.toHaveBeenCalled();
    host().vm.$emit("action", "commit", { page: host().props("page"), data: {} });
    await flushPromises();
    expect(onPosted).toHaveBeenCalledExactlyOnceWith(posted, rootRef.value);
    expect(onBack).not.toHaveBeenCalled();
    expect(calls(port)).toHaveLength(2);
    expect(port.invokePageAction).toHaveBeenCalledTimes(2);
  });

  it.each([
    { success: false, posted: { conversationId: "chat-1", serverMsgId: "s", clientMsgId: "c" } },
    { success: undefined, posted: { conversationId: "chat-1", serverMsgId: "s", clientMsgId: "c" } },
    { success: true, posted: { conversationId: "other-chat", serverMsgId: "s", clientMsgId: "c" } },
    { success: true, posted: { conversationId: "chat-1", serverMsgId: "", clientMsgId: "c" } },
    { success: true, posted: { conversationId: "chat-1", serverMsgId: "s", clientMsgId: " " } },
    { success: true, posted: { conversationId: "chat-1", serverMsgId: "s" } },
  ])("keeps incomplete, refused, unknown and foreign posted results in their flow: %j", async ({ success, posted }) => {
    const port = pagePort(async () => page(), async () => ({ kind: "operation", response: { success, data: { posted } } }));
    const onPosted = vi.fn();
    const { host, onBack } = render(port, { root: { ...root, conversationId: "chat-1" }, onPosted });
    await flushPromises();
    host().vm.$emit("action", "commit", { page: host().props("page"), data: {} });
    await flushPromises();
    expect(onPosted).not.toHaveBeenCalled();
    expect(onBack).not.toHaveBeenCalled();
  });

  it("ignores a posted completion after its owning surface has unmounted", async () => {
    const pending = deferred<unknown>();
    const port = pagePort(async () => page(), () => pending.promise);
    const onPosted = vi.fn();
    const { host, wrapper } = render(port, { root: { ...root, conversationId: "chat-1" }, onPosted });
    await flushPromises();
    host().vm.$emit("action", "commit", { page: host().props("page"), data: {} });
    await nextTick();
    wrapper.unmount();
    pending.resolve({ kind: "operation", response: { success: true, data: { posted: { conversationId: "chat-1", serverMsgId: "s", clientMsgId: "c" } } } });
    await flushPromises();
    expect(onPosted).not.toHaveBeenCalled();
  });

  it("isolates a reopened same-conversation same-entry flow from its previous pending post without unmounting", async () => {
    const old = deferred<unknown>(), current = deferred<unknown>();
    const invoke = vi.fn().mockImplementationOnce(() => old.promise).mockImplementationOnce(() => current.promise);
    const port = pagePort(async () => page(), invoke), onPosted = vi.fn();
    const { host, wrapper, rootRef } = render(port, { root: { ...root, conversationId: "chat-1" }, onPosted });
    await flushPromises();
    const element = wrapper.getComponent(CorePluginPage).element;
    host().vm.$emit("action", "oldCommit", { page: host().props("page"), data: {} });
    await nextTick();
    const previousOwner = rootRef.value;
    rootRef.value = { ...previousOwner };
    await flushPromises();
    expect(wrapper.getComponent(CorePluginPage).element).toBe(element);
    expect(host().props("busyActionId")).toBeUndefined();
    host().vm.$emit("action", "newCommit", { page: host().props("page"), data: {} });
    await nextTick();
    const posted = { conversationId: "chat-1", serverMsgId: "s1", clientMsgId: "c1" };
    old.resolve({ kind: "operation", response: { success: true, data: { posted } } });
    await flushPromises();
    expect(onPosted).not.toHaveBeenCalled();
    expect(host().props("busyActionId")).toBe("newCommit");
    current.resolve({ kind: "operation", response: { success: true, data: { posted } } });
    await flushPromises();
    expect(onPosted).toHaveBeenCalledExactlyOnceWith(posted, rootRef.value);
    expect(rootRef.value).not.toBe(previousOwner);
  });

  it("opens the root page over pluginPage once a port is there", async () => {
    const port = pagePort(async () => page());
    const { host, portRef } = render(null);
    await flushPromises();
    expect(port.pluginPage).not.toHaveBeenCalled();
    portRef.value = port;
    await flushPromises();
    expect(calls(port)).toEqual([{ pluginId: "flare.redpacket", page: "flare.redpacket.wallet", platform: "web", locale: "en-US" }]);
    expect(host().props()).toMatchObject({ page: { pluginId: "flare.redpacket", page: "flare.redpacket.wallet" }, title: "Wallet", loading: false,
      back: true, view: { title: "Wallet", data: { balanceText: "¥12.30" }, nextCursor: "c2" } });
  });

  it("loads more with the cursor and the shown page, filters from the first page, refreshes with the shown page", async () => {
    const port = pagePort(async () => page());
    const { host } = render(port);
    await flushPromises();
    const shown = host().props("view");
    port.pluginPage.mockImplementationOnce(async () => page({ nextCursor: undefined }));
    host().vm.$emit("loadMore", "c2");
    await flushPromises();
    expect(calls(port)[1]).toMatchObject({ cursor: "c2", previous: shown });
    expect(host().props("view")).not.toHaveProperty("nextCursor");
    host().vm.$emit("filter", { kind: "claim" });
    await flushPromises();
    // A filter is the page's first page with the new values, not a refresh of the shown one.
    expect(calls(port)[2]).toMatchObject({ filters: { kind: "claim" } });
    expect(calls(port)[2]).not.toHaveProperty("refresh");
    expect(calls(port)[2]).not.toHaveProperty("cursor");
    expect(host().props("filters")).toEqual({ kind: "claim" });
    host().vm.$emit("refresh");
    await flushPromises();
    expect(calls(port)[3]).toMatchObject({ refresh: true, previous: expect.objectContaining({ title: "Wallet" }), filters: { kind: "claim" } });
    expect(calls(port)[3]).not.toHaveProperty("cursor");
    expect(calls(port)).toHaveLength(4);
  });

  it("keeps the shown page when a next page fails without turning it into a financial action error", async () => {
    const port = pagePort(async () => page());
    const { host } = render(port, { errorText: (cause: unknown) => (String(cause).includes("disabled") ? "This plugin is disabled" : undefined) });
    await flushPromises();
    port.pluginPage.mockImplementationOnce(async () => { throw new Error("sdk.plugin.disabled"); });
    host().vm.$emit("loadMore", "c2");
    await flushPromises();
    expect(host().props()).toMatchObject({ view: { nextCursor: "c2" }, actionError: undefined, loadingMore: false, error: "This plugin is disabled" });
  });

  it.each([false, true])("isolates a superseded pagination result/finally from a refreshed query (rejected=%s)", async (rejected) => {
    const port = pagePort(async () => page());
    const { host } = render(port);
    await flushPromises();
    const old = deferred<unknown>();
    port.pluginPage.mockImplementationOnce(() => old.promise);
    host().vm.$emit("loadMore", "c2");
    await flushPromises();
    expect(host().props("loadingMore")).toBe(true);
    port.pluginPage.mockImplementationOnce(async () => page({ title: "Fresh records", nextCursor: "fresh-cursor" }));
    host().vm.$emit("refresh");
    await flushPromises();
    expect(host().props()).toMatchObject({ view: {title: "Fresh records"}, loadingMore: false });
    const next = deferred<unknown>();
    port.pluginPage.mockImplementationOnce(() => next.promise);
    host().vm.$emit("loadMore", "fresh-cursor");
    await flushPromises();
    const token = Number(host().props("pagingToken"));
    if (rejected) old.reject(new Error("stale read failure")); else old.resolve(page({ title: "Stale records" }));
    await flushPromises();
    expect(host().props()).toMatchObject({view: {title: "Fresh records"}, loadingMore: true, error: undefined, pagingToken: token});
    next.resolve(page({title: "Current page", nextCursor: undefined}));
    await flushPromises();
    expect(host().props()).toMatchObject({view: {title: "Current page"}, loadingMore: false});
    expect(host().props("pagingToken")).toBe(token + 1);
  });

  it("keeps the applied filter with the shown records after a failed filter and blocks paging during refresh", async () => {
    const port = pagePort(async () => page());
    const {host} = render(port);
    await flushPromises();
    host().vm.$emit("filter", {direction: "income"});
    await flushPromises();
    const failed = deferred<unknown>();
    port.pluginPage.mockImplementationOnce(() => failed.promise);
    host().vm.$emit("filter", {direction: "expense"});
    await flushPromises();
    expect(host().props("filters")).toEqual({direction: "income"});
    expect(host().props("refreshing")).toBe(true);
    const count = calls(port).length;
    host().vm.$emit("loadMore", "c2");
    await flushPromises();
    expect(calls(port)).toHaveLength(count);
    failed.reject(new Error("filter unavailable"));
    await flushPromises();
    expect(host().props()).toMatchObject({ filters: {direction: "income"}, refreshing: false, view: {title: "Wallet"}, error: "The page didn't load" });
  });

  it("clears only read errors on a paging retry, preserving financial form errors and settlement", async () => {
    const port = pagePort(async () => page(), async () => ({kind: "formErrors", errors: [{input: "amount", issue: "outOfRange"}]}));
    const {host} = render(port);
    await flushPromises();
    host().vm.$emit("action", "submit", {page: {pluginId: root.pluginId, page: root.page}, formValues: {amount: "1"}});
    await flushPromises();
    const errors = host().props("formErrors"), settle = host().props("settleToken");
    expect(errors).toHaveLength(1);
    port.pluginPage.mockImplementationOnce(async () => { throw new Error("paging offline"); });
    host().vm.$emit("loadMore", "c2");
    await flushPromises();
    expect(host().props("error")).toBe("The page didn't load");
    const token = Number(host().props("pagingToken"));
    host().vm.$emit("loadMore", "c2");
    await flushPromises();
    expect(host().props()).toMatchObject({error: undefined, formErrors: errors, settleToken: settle, pagingToken: token + 1});
  });

  it("drops the previous actor's view and loading flags when the port disappears", async () => {
    const port = pagePort(async () => page());
    const {host, portRef} = render(port);
    await flushPromises();
    portRef.value = null;
    await flushPromises();
    expect(host().props()).toMatchObject({view: undefined, loading: false, refreshing: false, loadingMore: false});
  });

  it.each(["formErrors", "reject", "navigate"])("keeps a new route's financial action locked when an old action settles (%s)", async (kind) => {
    const old = deferred<unknown>(), current = deferred<unknown>();
    const port = pagePort(async () => page(), async () => ({kind: "host", target: {kind: "page", page: "wallet.detail"}, payload: {walletId: "original"}}));
    const {host} = render(port);
    await flushPromises();
    host().vm.$emit("action", "detail", {page: {pluginId: root.pluginId, page: root.page}});
    await flushPromises();
    port.invokePageAction.mockImplementationOnce(() => old.promise);
    host().vm.$emit("action", "oldSubmit", {page: {pluginId: root.pluginId, page: "wallet.detail"}, formValues: {amount: "1"}});
    await flushPromises();
    host().vm.$emit("back");
    await flushPromises();
    port.invokePageAction.mockImplementationOnce(() => current.promise);
    host().vm.$emit("action", "currentSubmit", {page: {pluginId: root.pluginId, page: root.page}, formValues: {amount: "2"}});
    await flushPromises();
    const settled = Number(host().props("settleToken")), reads = calls(port).length;
    if (kind === "reject") old.reject(new Error("old command unavailable"));
    else if (kind === "navigate") old.resolve({kind: "host", target: {kind: "page", page: "stale.target"}, payload: {}});
    else old.resolve({kind: "formErrors", errors: [{input: "amount", issue: "outOfRange"}]});
    await flushPromises();
    expect(host().props()).toMatchObject({page: {pluginId: root.pluginId, page: root.page}, busyActionId: "currentSubmit", actionError: undefined, formErrors: [], settleToken: settled});
    expect(calls(port)).toHaveLength(reads);
    current.resolve({kind: "formErrors", errors: [{input: "amount", issue: "required"}]});
    await flushPromises();
    expect(host().props()).toMatchObject({busyActionId: undefined, formErrors: [{input: "amount", issue: "required"}], settleToken: settled + 1});
  });

  it("settles a current financial action after a same-page read refresh", async () => {
    const pending = deferred<unknown>();
    const port = pagePort(async () => page(), () => pending.promise);
    const {host} = render(port);
    await flushPromises();
    host().vm.$emit("action", "submit", {page: {pluginId: root.pluginId, page: root.page}, formValues: {amount: "1"}});
    host().vm.$emit("refresh");
    await flushPromises();
    expect(host().props("busyActionId")).toBe("submit");
    pending.resolve({kind: "formErrors", errors: [{input: "amount", issue: "required"}]});
    await flushPromises();
    expect(host().props()).toMatchObject({busyActionId: undefined, formErrors: [{input: "amount", issue: "required"}], settleToken: 1});
  });

  it("runs a page action with the page, its data and the row, never a message, and re-reads when the kit asks", async () => {
    const port = pagePort(async () => page(), async () => ({ kind: "operation", response: { success: true, data: {} } }));
    const { host } = render(port);
    await flushPromises();
    host().vm.$emit("action", "open", { page: { pluginId: root.pluginId, page: root.page }, data: { balanceText: "¥12.30" },
      row: { key: "l1", input: { packetId: "p1" } } });
    await flushPromises();
    const request = port.invokePageAction.mock.calls[0][0];
    expect(request).toEqual({ pluginId: root.pluginId, page: root.page, actionId: "open", userGesture: true, platform: "web", locale: "en-US",
      data: { balanceText: "¥12.30" }, row: { key: "l1", input: { packetId: "p1" } } });
    expect(port.invokeAction).not.toHaveBeenCalled();
    expect(host().props()).toMatchObject({ busyActionId: undefined, settleToken: 1 });
    // A clean settle is the kit's to refresh (R4): one re-read, through its refresh("action").
    expect(calls(port)).toHaveLength(1);
    host().vm.$emit("refresh", "action");
    await flushPromises();
    expect(calls(port)).toHaveLength(2);
    expect(calls(port)[1]).toMatchObject({ refresh: true });
  });

  it("shows an uncovered page's last view at once and re-reads it quietly on back", async () => {
    let wallet = 1;
    const port = pagePort(async (request) => request.page === "acme.task.board" ? page({ title: "Board" }) : page({ title: `Wallet ${wallet}` }),
      async () => ({ kind: "host", target: { kind: "page", page: "acme.task.board" }, payload: {} }));
    const { host } = render(port);
    await flushPromises();
    host().vm.$emit("action", "history", { page: { pluginId: root.pluginId, page: root.page }, data: {} });
    await flushPromises();
    wallet = 2;
    const reread = deferred<unknown>();
    port.pluginPage.mockImplementationOnce(() => reread.promise);
    host().vm.$emit("back");
    await nextTick();
    // The wallet is back on screen while it is read again, never a blank first load.
    expect(host().props()).toMatchObject({ page: { page: root.page }, view: { title: "Wallet 1" }, loading: false, refreshing: true });
    expect(calls(port).at(-1)).toMatchObject({ page: root.page, refresh: true });
    reread.resolve(page({ title: "Wallet 2" }));
    await flushPromises();
    expect(host().props()).toMatchObject({ view: { title: "Wallet 2" }, refreshing: false });
  });

  describe("done (§12.1, plugin-refresh-vectors doneTarget)", () => {
    it.each(refreshVectors.doneTarget.map((vector) => [vector.name, vector] as const))("%s", async (_, vector) => {
      const { host, port, onBack } = await openStack(vector.stack);
      const reads = calls(port).length;
      host().vm.$emit("done");
      await flushPromises();
      if (vector.expect.target === null) {
        expect(onBack).toHaveBeenCalledOnce();
        expect(calls(port)).toHaveLength(reads);
      } else {
        expect(onBack).not.toHaveBeenCalled();
        expect(host().props("page")).toEqual({ pluginId: root.pluginId, page: `p${vector.expect.target}` });
        expect(calls(port).slice(reads)).toEqual([expect.objectContaining({ page: `p${vector.expect.target}`, refresh: true })]);
      }
    });
  });

  describe("return (R4, plugin-refresh-vectors afterReturn)", () => {
    // Each event from a stack that gives it: back from a next page, done over a data page or not, an action sending a card.
    it.each(refreshVectors.afterReturn.map((vector) => [vector.name, vector] as const))("%s", async (_, vector) => {
      const kinds: Kind[] = vector.event === "done" ? [vector.origin ? "overview" : "task", "result"] : ["records", "task"];
      const onPosted = vi.fn();
      const { host, port, onBack } = await openStack(kinds, { onPosted });
      const reads = calls(port).length;
      if (vector.event === "pop") host().vm.$emit("back");
      else if (vector.event === "done") host().vm.$emit("done");
      else {
        port.invokePageAction.mockResolvedValueOnce({ kind: "operation", response: { success: true,
          data: { posted: { conversationId: "chat-1", serverMsgId: "s", clientMsgId: "c" } } } });
        host().vm.$emit("action", "send", { page: host().props("page"), data: {} });
      }
      await flushPromises();
      expect(calls(port).slice(reads)).toEqual(vector.expect.refresh ? [expect.objectContaining({ page: "p0", refresh: true })] : []);
      if (vector.expect.page === "close") expect(vector.event === "messageCard" ? onPosted : onBack).toHaveBeenCalledOnce();
      else {
        expect(onBack).not.toHaveBeenCalled();
        expect(host().props("page")).toEqual({ pluginId: root.pluginId, page: "p0" });
      }
    });
  });

  it("says a refusal in the host's words for its code or error, never the raw code, else with the kit's line (R8)", async () => {
    const errorText = (cause: unknown) => {
      const { machineReason, message } = (cause ?? {}) as { machineReason?: unknown; message?: unknown };
      if (machineReason === "PAYMENT_PASSWORD_INVALID") return "Wrong payment password";
      return typeof message === "string" && message.includes("sdk.plugin.rate_limited") ? "Too many tries" : undefined;
    };
    const native: NativePluginBridge = { capabilities: ["reauthenticate"], invoke: vi.fn(async () => ({ success: false, error: "sdk.plugin.rate_limited" })) };
    const port = pagePort(async () => page());
    const { host } = render(port, { errorText }, native);
    await flushPromises();
    const refusal = async (outcome: unknown) => {
      port.invokePageAction.mockResolvedValueOnce(outcome);
      host().vm.$emit("action", "pay", { page: host().props("page"), data: {} });
      await flushPromises();
      return host().props("actionError");
    };
    expect(await refusal({ kind: "operation", response: { success: false, data: { errorCode: "PAYMENT_PASSWORD_INVALID" } } })).toBe("Wrong payment password");
    expect(await refusal({ kind: "operation", response: { success: false, error: "sdk.plugin.rate_limited" } })).toBe("Too many tries");
    expect(await refusal({ kind: "host", target: { kind: "native", capability: "reauthenticate" }, payload: {} })).toBe("Too many tries");
    expect(await refusal({ kind: "operation", response: { success: false, data: { errorCode: "WALLET_FROZEN" } } }))
      .toBe("Plugin command rejected. Check permission and business state.");
    // The plugin's own words for the code come first, over the host's mapping and the kit's line.
    expect(await refusal({ kind: "operation", response: { success: false, data: { errorCode: "PAYMENT_PASSWORD_INVALID" } }, message: "该证件号已被其他账号使用" }))
      .toBe("该证件号已被其他账号使用");
    expect(await refusal({ kind: "operation", response: { success: false, data: { errorCode: "WALLET_FROZEN" } }, message: "Account frozen" }))
      .toBe("Account frozen");
  });

  it("says a refused action with the kit's line and a failed one with the host's copy", async () => {
    const port = pagePort(async () => page(), async () => ({ kind: "operation", response: { success: false } }));
    const { host } = render(port, { errorText: () => "Not permitted" });
    await flushPromises();
    host().vm.$emit("action", "open", { page: { pluginId: root.pluginId, page: root.page }, data: {} });
    await flushPromises();
    expect(host().props("actionError")).toBe("Plugin command rejected. Check permission and business state.");
    port.invokePageAction.mockImplementationOnce(async () => { throw new Error("denied"); });
    host().vm.$emit("action", "open", { page: { pluginId: root.pluginId, page: root.page }, data: {} });
    await flushPromises();
    expect(host().props("actionError")).toBe("Not permitted");
    expect(calls(port)).toHaveLength(2);
  });

  it("reloads a journal completed by a refusal so its acknowledgement becomes available without reopening", async () => {
    let known = false;
    const port = pagePort(async () => page({ data: { journal: { known } },
      actions: [{ id: known ? "ack" : "retry", label: known ? "Acknowledge result" : "Retry original" }] }),
    async () => {
      known = true;
      return { kind: "operation", response: { success: false, data: { errorCode: "WALLET_REJECTED" } } };
    });
    const { host } = render(port);
    await flushPromises();
    expect(host().props("view")).toMatchObject({ data: { journal: { known: false } } });
    host().vm.$emit("action", "retry", { page: { pluginId: root.pluginId, page: root.page }, data: {} });
    await flushPromises();
    expect(host().props("view")).toMatchObject({ data: { journal: { known: true } }, actions: [{ id: "ack" }] });
    expect(host().props("actionError")).toBe("Plugin command rejected. Check permission and business state.");
    expect(calls(port).at(-1)).toMatchObject({ refresh: true });
  });

  it("pushes the page a target opens with its own plugin and the payload as arguments; back pops it, then leaves", async () => {
    const port = pagePort(async (request) => page({ title: request.page === "acme.task.board" ? "Board" : "Wallet" }),
      async () => ({ kind: "host", target: { kind: "page", page: "acme.task.board" }, payload: { boardId: "b1" } }));
    const { host, onBack } = render(port);
    await flushPromises();
    host().vm.$emit("action", "history", { page: { pluginId: root.pluginId, page: root.page }, data: {} });
    await flushPromises();
    // The target is the page of the plugin whose page ran the action.
    expect(calls(port).at(-1)).toMatchObject({ pluginId: "flare.redpacket", page: "acme.task.board", arguments: { boardId: "b1" } });
    expect(host().props()).toMatchObject({ page: { pluginId: "flare.redpacket", page: "acme.task.board" }, title: "Wallet" });
    host().vm.$emit("back");
    await flushPromises();
    expect(host().props("page")).toEqual({ pluginId: root.pluginId, page: root.page });
    expect(onBack).not.toHaveBeenCalled();
    host().vm.$emit("back");
    await nextTick();
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it("replaces the shown page with a chosen tab, keeping its arguments and adding no back step", async () => {
    const records: CorePluginPageEntry = { pluginId: "flare.redpacket", page: "flare.redpacket.page.received", title: "Red packets", args: { scope: "me" } };
    const port = pagePort(async (request) => page({ nextCursor: null, tabs: [
      { page: "flare.redpacket.page.received", label: "Received", selected: request.page === "flare.redpacket.page.received" },
      { page: "flare.redpacket.page.sent", label: "Sent", selected: request.page === "flare.redpacket.page.sent" }] }));
    const { host, onBack } = render(port, { root: records });
    await flushPromises();
    expect(host().props("view")?.tabs?.[0]).toMatchObject({ selected: true });
    host().vm.$emit("tab", "flare.redpacket.page.sent");
    await flushPromises();
    expect(calls(port).at(-1)).toMatchObject({ pluginId: "flare.redpacket", page: "flare.redpacket.page.sent", arguments: { scope: "me" } });
    expect(host().props("page")).toEqual({ pluginId: "flare.redpacket", page: "flare.redpacket.page.sent" });
    expect(host().props("view")?.tabs?.[1]).toMatchObject({ selected: true });
    // The tab took the root's place: back leaves.
    host().vm.$emit("back");
    await nextTick();
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it("returns a completed workflow to its existing status page without keeping submitted editors behind Back", async () => {
    const port = pagePort(async () => page(), async (request) => ({
      kind: "host", target: { kind: "page", page: request.actionId === "edit" ? "application.editor" : root.page }, payload: {},
    }));
    const { host, onBack } = render(port);
    await flushPromises();
    host().vm.$emit("action", "edit", { page: { pluginId: root.pluginId, page: root.page } });
    await flushPromises();
    expect(host().props("page").page).toBe("application.editor");
    host().vm.$emit("action", "submit", { page: { pluginId: root.pluginId, page: "application.editor" } });
    await flushPromises();
    expect(host().props("page").page).toBe(root.page);
    host().vm.$emit("back");
    await nextTick();
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it("says why the page failed with the host's copy, or its generic line, and lets the kit draw an unavailable page", async () => {
    const port = pagePort(async () => { throw new Error("sdk.plugin.disabled"); });
    let view = render(port, { errorText: (cause: unknown) => (String(cause).includes("disabled") ? "This plugin is disabled" : undefined) });
    await flushPromises();
    expect(view.host().props("error")).toBe("This plugin is disabled");
    mounted.splice(0).forEach((wrapper) => wrapper.unmount());
    view = render(pagePort(async () => { throw new Error("offline"); }));
    await flushPromises();
    expect(view.host().props("error")).toBe("The page didn't load");
    view.host().vm.$emit("retry");
    mounted.splice(0).forEach((wrapper) => wrapper.unmount());
    view = render(pagePort(async () => ({ available: false, title: "", fields: [], actions: [], unavailableReason: "not_installed" })));
    await flushPromises();
    expect(view.host().props("view")).toMatchObject({ available: false, unavailableReason: "not_installed" });
  });

  it("preserves conversation route context through group pages and their actions", async () => {
    const port=pagePort(async (request)=>page({conversationId:request.conversationId,data:{conversationId:"injected"}}),async ()=>({kind:"host",target:{kind:"page",page:"flare.checkin.plan"},conversationId:"group-1",payload:{planId:"p1",conversationId:"injected"}}));
    const grouped={pluginId:"flare.checkin",page:"flare.checkin.plans",title:"Check-ins",conversationId:"group-1"};
    const {host}=render(port,{root:grouped});await flushPromises();
    expect(calls(port)[0]).toMatchObject({conversationId:"group-1"});
    host().vm.$emit("action","open",{page:{pluginId:grouped.pluginId,page:grouped.page},data:{conversationId:"injected"}});await flushPromises();
    expect(port.invokePageAction.mock.calls[0][0]).toMatchObject({conversationId:"group-1",data:{conversationId:"injected"}});
    expect(calls(port).at(-1)).toMatchObject({page:"flare.checkin.plan",conversationId:"group-1",arguments:{planId:"p1",conversationId:"injected"}});
    expect(corePluginPageEntry({pluginId:"flare.task",page:"flare.task.mine.page",conversationId:"group-1"})).toMatchObject({conversationId:"group-1"});
  });

  it("gives a card's page target as an entry: its plugin, its page, the bound payload as arguments", () => {
    expect(corePluginPageEntry({ pluginId: "acme.task", page: "acme.task.board" }, { boardId: "b1" }, "Board"))
      .toEqual({ pluginId: "acme.task", page: "acme.task.board", title: "Board", args: { boardId: "b1" } });
    expect(corePluginPageEntry({ pluginId: "acme.task", page: "acme.task.board" })).toEqual({ pluginId: "acme.task", page: "acme.task.board", title: "" });
  });

  it("shows an upgrade placeholder page with the device's update status and opens the update flow on its key", async () => {
    const placeholder = { available: false, title: "Board", fields: [], actions: [], unavailableReason: "upgrade_required", minBuild: 41020 };
    let opened!: () => void;
    const host = {
      upgradeStatus: vi.fn(async () => ({ available: true, build: 41020 })),
      openUpdate: vi.fn(() => new Promise<void>((resolve) => { opened = resolve; })),
    };
    const { host: kit } = render(pagePort(async () => placeholder), { host });
    await flushPromises();
    expect(host.upgradeStatus).toHaveBeenCalledWith(41020);
    expect(kit().props("upgradeStatus")).toEqual({ available: true, build: 41020 });
    expect(kit().props("upgradeBusy")).toBe(false);
    kit().props("onUpdate")?.();
    await nextTick();
    expect(host.openUpdate).toHaveBeenCalledOnce();
    expect(kit().props("upgradeBusy")).toBe(true);
    kit().props("onUpdate")?.();
    expect(host.openUpdate).toHaveBeenCalledOnce();
    opened();
    await flushPromises();
    expect(kit().props("upgradeBusy")).toBe(false);
  });

  it("asks nothing for a page that draws, and leaves the notice keyless without a host", async () => {
    const host = { upgradeStatus: vi.fn(async () => ({ available: false })) };
    const { host: kit } = render(pagePort(async () => page()), { host });
    await flushPromises();
    expect(host.upgradeStatus).not.toHaveBeenCalled();
    expect(kit().props("upgradeStatus")).toBeNull();
    const bare = render(pagePort(async () => ({ available: false, title: "", fields: [], actions: [], unavailableReason: "upgrade_required" })));
    await flushPromises();
    expect(bare.host().props("onUpdate")).toBeUndefined();
  });

  it("refreshes an expired QR code by running the declared query, then reading the page again", async () => {
    const port = pagePort(async () => page());
    const { host } = render(port);
    await flushPromises();
    host().vm.$emit("qrRefresh", { operation: "flare.wallet.receive_code", valuePath: "/code" });
    await flushPromises();
    expect(port.dispatch).toHaveBeenCalledWith({ capabilityId: "flare.wallet.receive_code", payload: {} });
    expect(calls(port)).toHaveLength(2);
    expect(calls(port)[1]).toMatchObject({ refresh: true });
    // A refused query keeps the shown page.
    port.dispatch.mockRejectedValueOnce(new Error("denied"));
    host().vm.$emit("qrRefresh", { operation: "flare.wallet.receive_code", valuePath: "/code" });
    await flushPromises();
    expect(calls(port)).toHaveLength(2);
  });

  it("hands the host's image resolver to the page", async () => {
    const resolveImage = vi.fn(() => "blob:x");
    const { host } = render(pagePort(async () => page()), { host: { resolveImage } });
    await flushPromises();
    expect(host().props("resolveImage")).toBe(resolveImage);
  });
  it("locates once through the engine into a location input and clears it again", async () => {
    const port = pagePort(async () => page({ data: { _session: { tenantId: "t", userId: "u" } } }));
    const asked: unknown[] = [];
    const answer = deferred<unknown>();
    (port as PluginUiPort).capabilityInvoke = vi.fn(async (request: Parameters<NonNullable<PluginUiPort["capabilityInvoke"]>>[0]) => { asked.push(request); return answer.promise; });
    const { host } = render(port, { root: { ...root, args: { planId: "p1" } } });
    await flushPromises();
    const input = { id: "area", kind: "location", label: "Area", precision: "coarse" };
    host().vm.$emit("locationAction", { action: "locate", inputId: "area", input, formValues: { note: "hi" } });
    await flushPromises();
    expect(host().props("locationStates")).toEqual({ area: { locating: true, error: undefined } });
    expect(asked[0]).toMatchObject({ pluginId: root.pluginId, capability: "locationOnce", params: { precision: "coarse" }, into: "area",
      page: { pluginId: root.pluginId, page: root.page }, arguments: { planId: "p1" }, formValues: { note: "hi" },
      data: { _session: { tenantId: "t", userId: "u" } }, userGesture: true });
    const value = { latitude: 31.23, longitude: 121.47, accuracyM: 1000, precision: "coarse" };
    answer.resolve({ kind: "input", input: "area", value });
    await flushPromises();
    expect(host().props("locationStates")).toEqual({ area: { value } });
    host().vm.$emit("locationAction", { action: "clear", inputId: "area", input, formValues: {} });
    await flushPromises();
    expect(host().props("locationStates")).toEqual({});
  });

  it("keeps a location input as it was when the viewer refuses, and says so when the host cannot locate", async () => {
    const port = pagePort(async () => page());
    const invoke = vi.fn(async (): Promise<unknown> => ({ kind: "denied" }));
    (port as PluginUiPort).capabilityInvoke = invoke;
    const { host } = render(port);
    await flushPromises();
    const input = { id: "spot", kind: "location", label: "Spot", precision: "fine" };
    host().vm.$emit("locationAction", { action: "locate", inputId: "spot", input, formValues: {} });
    await flushPromises();
    expect(host().props("locationStates")).toEqual({});
    invoke.mockResolvedValueOnce({ kind: "unavailable" });
    host().vm.$emit("locationAction", { action: "locate", inputId: "spot", input, formValues: {} });
    await flushPromises();
    expect((host().props("locationStates") as Record<string, { error?: string }>).spot.error).toBeTruthy();
  });

  it("captures a document through the engine into its input, never through the file picker", async () => {
    const port = pagePort(async () => page());
    const invoke = vi.fn(async (): Promise<unknown> => ({ kind: "input", input: "front", value: { fileId: "file:front-1" } }));
    (port as PluginUiPort).capabilityInvoke = invoke;
    const picker = vi.spyOn(HTMLInputElement.prototype, "click");
    const { host } = render(port);
    await flushPromises();
    const input = { id: "front", kind: "document", label: "ID", side: "front", required: true,
      file: { accept: ["image/jpeg"], maxBytes: 4194304 } };
    host().vm.$emit("fileAction", { action: "choose", inputId: "front", input, scope: "s-1", generation: 1, formValues: {} });
    await flushPromises();
    expect(invoke).toHaveBeenCalledWith(expect.objectContaining({ capability: "documentCapture", params: { side: "front" }, into: "front" }));
    expect(port.uploadFile).not.toHaveBeenCalled();
    expect(picker).not.toHaveBeenCalled();
    expect(host().props("fileStates")).toEqual({ front: { scope: "s-1", generation: 1, phase: "uploaded", value: { fileId: "file:front-1" },
      fileName: "document-front.jpg" } });
    picker.mockRestore();
  });

  it("reads protected media one item at a time through its declared action and keeps the address in memory", async () => {
    const port = pagePort(async () => page({ data: { application: { applicationId: "a-1" } } }),
      async () => ({ kind: "operation", response: { success: true, data: { readUrl: "https://example.test/m/1?grant=g" } } }));
    const { host } = render(port);
    await flushPromises();
    const item = { id: "m-1", label: "Front", input: { materialId: "m-1" } };
    host().vm.$emit("protectedMediaRead", { action: { id: "viewDocument", label: "View" }, item, reason: "", urlPath: "/readUrl",
      formValues: { materialId: "m-1" } });
    await flushPromises();
    expect(port.invokePageAction).toHaveBeenCalledWith(expect.objectContaining({ actionId: "viewDocument", formValues: { materialId: "m-1" },
      data: { application: { applicationId: "a-1" } } }));
    expect(host().props("protectedMedia")).toEqual({ "m-1": { url: "https://example.test/m/1?grant=g" } });
    // The page read again from scratch forgets it.
    host().vm.$emit("retry");
    await flushPromises();
    expect(host().props("protectedMedia")).toEqual({});
  });

  it("revokes local private previews when hidden and drops a late read", async () => {
    const request = vi.spyOn(globalThis, "fetch");
    const create = vi.spyOn(URL, "createObjectURL").mockReturnValue("blob:private-local");
    const revoke = vi.spyOn(URL, "revokeObjectURL").mockImplementation(() => {});
    const response = () => new Response(new Uint8Array([1, 2]), { headers: { "content-type": "image/png" } });
    request.mockResolvedValueOnce(response());
    const port = pagePort(async () => page(), async () => ({ kind: "operation", response: {
      success: true, data: { readUrl: "http://127.0.0.1:56200/private/realname/owner-materials/a/b?grant=synthetic" },
    } }));
    try {
      const { host, visibleRef } = render(port);
      await flushPromises();
      const read = { action: { id: "viewDocument", label: "View" }, item: { id: "m-1", label: "Front", input: { materialId: "m-1" } }, reason: "", urlPath: "/readUrl", formValues: { materialId: "m-1" } };
      host().vm.$emit("protectedMediaRead", read);
      await vi.waitFor(() => expect(host().props("protectedMedia")).toEqual({ "m-1": { url: "blob:private-local" } }));
      visibleRef.value = false; await nextTick();
      expect(revoke).toHaveBeenCalledExactlyOnceWith("blob:private-local");
      expect(host().props("protectedMedia")).toEqual({});
      visibleRef.value = true; await nextTick();
      const pending = deferred<Response>(); request.mockImplementationOnce(() => pending.promise);
      host().vm.$emit("protectedMediaRead", read); await flushPromises();
      const signal = request.mock.calls.at(-1)?.[1]?.signal;
      visibleRef.value = false; await nextTick();
      expect(signal?.aborted).toBe(true);
      pending.resolve(response()); await flushPromises();
      expect(host().props("protectedMedia")).toEqual({});
    } finally { request.mockRestore(); create.mockRestore(); revoke.mockRestore(); }
  });
});
