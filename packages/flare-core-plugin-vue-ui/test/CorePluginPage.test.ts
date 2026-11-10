/**
 * CorePluginPage: a plugin page over the core's `pluginPage` with its own stack. The first page, a next page with the
 * cursor and the shown page, a filter as the first page again, a refresh with the shown page; page actions through
 * the core's invoke with the page, its data and the row, never a message; a page target pushed with its own plugin and
 * the bound payload as arguments, popped by back, and `back` out of the root.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { defineComponent, h, nextTick, shallowRef, type Component } from "vue";
import { flushPromises, mount } from "@vue/test-utils";
import { FlarePluginPage } from "@flare-im/vue-ui";
import { useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import type { PluginUiPort } from "@flare-im/sdk/plugin-ui";
import { CorePluginPage, corePluginPageEntry, type CorePluginPageEntry } from "../src/index";
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

function render(port: PluginUiPort | null, props: Record<string, unknown> = {}) {
  const onBack = vi.fn();
  const portRef = shallowRef(port);
  const rootRef = shallowRef((props.root as CorePluginPageEntry | undefined) ?? root);
  const forwardedProps = { ...props };
  delete forwardedProps.root;
  const wrapper = mount(defineComponent({ setup() {
    useFlareI18nProvider("en-US");
    return () => h(CorePluginPage as Component, { root: rootRef.value, port: portRef.value, platform: "web", loadFailedText: "The page didn't load", onBack, ...forwardedProps });
  } }));
  mounted.push(wrapper);
  const host = () => wrapper.getComponent(FlarePluginPage);
  return { wrapper, host, onBack, portRef, rootRef };
}
const calls = (port: PagePort) => port.pluginPage.mock.calls.map(([request]) => request);
function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

describe("CorePluginPage", () => {
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

  it("runs a page action with the page, its data and the row, never a message, then reads the page again", async () => {
    const port = pagePort(async () => page(), async () => ({ kind: "operation", response: { success: true, data: {} } }));
    const { host } = render(port);
    await flushPromises();
    host().vm.$emit("action", "open", { page: { pluginId: root.pluginId, page: root.page }, data: { balanceText: "¥12.30" },
      row: { key: "l1", input: { packetId: "p1" } } });
    await flushPromises();
    const request = port.invokePageAction.mock.calls[0][0];
    expect(request).toEqual({ pluginId: root.pluginId, page: root.page, actionId: "open", userGesture: true, platform: "web", nativeAllowlist: [],
      data: { balanceText: "¥12.30" }, row: { key: "l1", input: { packetId: "p1" } } });
    expect(port.invokeAction).not.toHaveBeenCalled();
    expect(host().props()).toMatchObject({ busyActionId: undefined, settleToken: 1 });
    expect(calls(port)).toHaveLength(2);
    expect(calls(port)[1]).toMatchObject({ refresh: true });
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
});
