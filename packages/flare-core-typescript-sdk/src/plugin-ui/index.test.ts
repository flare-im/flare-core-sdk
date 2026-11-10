import { describe, expect, it } from "vitest";
import { PluginUiSession, pluginManifestLocale, type PluginUiPort } from "./index";
const message = { pluginId: "example.poll", contributionId: "example.poll.card", schemaVersion: 1, summary: "Poll", payload: { packetId: "one", injected: "unused" } };
function port(): PluginUiPort { return { catalog: async () => ({}), resolveMessage: async () => ({ available: true, title: "Poll", fields: [], actions: [{ id: "vote", label: "Vote" }] }), action: async () => ({ target: { kind: "operation", operation: "example.poll.vote" }, payload: { packetId: "one" } }),
  presentMessage: async () => ({ available: true, title: "Poll", fields: [], actions: [], data: { packetId: "one", status: "completed" }, stateVersion: 3 }),
  invokeAction: async () => ({ kind: "operation", response: { success: true, data: { messageState: { version: 4, values: { status: "completed" } } } } }),
  invokePageAction: async () => ({ kind: "operation", response: { success: true, data: {} } }),
  uploadFile: async () => ({ fileId: "file-1" }),
  dispatch: async () => ({ success: true }) }; }
describe("plugin UI runtime adapter", () => {
  it("frames private uploads and rejects a completion from a reset session", async () => {
    const api = port(); let release!: (value: { fileId: string }) => void; let seen: unknown;
    api.uploadFile = async (request) => { seen = request; return await new Promise((resolve) => { release = resolve; }); };
    const session = new PluginUiSession(api, "web", () => "zh-CN");
    const pending = session.uploadFile({ page: { pluginId: "example.poll", page: "example.poll.page.form" },
      inputId: "proof", fileName: "proof.png", contentType: "image/png", bytes: [1, 2], commandId: "upload-1" });
    expect(seen).toMatchObject({ platform: "web", locale: "zh-CN", commandId: "upload-1", bytes: [1, 2] });
    session.reset(); release({ fileId: "file-1" });
    await expect(pending).rejects.toThrow("session changed");
  });
  it("never exposes an upload URL or mixed file reference returned by a bad port", async () => {
    const api = port(); api.uploadFile = async () => ({ fileId: "file-1", uploadUrl: "/private/secret?grant=secret" });
    await expect(new PluginUiSession(api, "web").uploadFile({ page: { pluginId: "example.poll", page: "example.poll.page.form" },
      inputId: "proof", fileName: "proof.png", contentType: "image/png", bytes: [1], commandId: "upload-1" })).rejects.toThrow("Invalid");
  });
  it("coalesces simultaneous timeline reads while actions still refresh", async () => {
    const api = port(); let calls = 0;
    api.catalog = async () => { calls++; await Promise.resolve(); return {}; };
    const host = new PluginUiSession(api, "web");
    await Promise.all(Array.from({ length: 100 }, () => host.resolve(message)));
    expect(calls).toBe(1);
    await host.invoke(message, "vote", true); expect(calls).toBe(2);
  });
  it("dispatches only the Rust-prepared input and refreshes before actions", async () => {
    const api = port(); let refreshed = 0, submitted: unknown;
    api.catalog = async () => { refreshed++; return {}; }; api.dispatch = async (input) => { submitted = input; return {}; };
    const host = new PluginUiSession(api, "web");
    await host.resolve(message); await host.invoke(message, "vote", true);
    expect(refreshed).toBe(2); expect(submitted).toEqual({ capabilityId: "example.poll.vote", payload: { packetId: "one" } });
  });
  it("discards completion from a previous session", async () => {
    const api = port(); let release!: (value: unknown) => void;
    api.catalog = () => new Promise((resolve) => { release = resolve; });
    const host = new PluginUiSession(api, "web"); const pending = host.resolve(message); host.reset(); release({});
    expect(await pending).toEqual({ available: false, title: "Poll", fields: [], actions: [] });
  });
  it("keeps unavailable history inert and rejects arbitrary byte payloads", async () => {
    const api = port(); api.catalog = async () => { throw new Error("offline"); };
    const host = new PluginUiSession(api, "tauri");
    expect((await host.resolve(message)).actions).toEqual([]);
    expect(host.envelope({ payload: [999], description: "bad" })).toBeNull();
    expect(host.envelope({ payload: [...new TextEncoder().encode(JSON.stringify(message))] })).toEqual(message);
  });
  it("presents a stored card with the message id and keeps Core's merged data and state version", async () => {
    const api = port(); const requests: unknown[] = [];
    api.presentMessage = async (request) => { requests.push(request); return { available: true, title: "Poll", fields: [], actions: [], data: { packetId: "one", status: "completed" }, stateVersion: 3 }; };
    const host = new PluginUiSession(api, "web", () => "zh-CN");
    expect(await host.present(message, "client-1")).toEqual({ available: true, title: "Poll", fields: [], actions: [], data: { packetId: "one", status: "completed" }, stateVersion: 3 });
    expect(requests[0]).toEqual({ message, messageId: "client-1", platform: "web", locale: "zh-CN", kind: "message-content" });
    // Core would refuse these ids; the card still presents, without stored state.
    for (const bad of ["", "has space", "line\nbreak", "x".repeat(257)]) {
      await host.present(message, bad);
      expect(requests.at(-1)).not.toHaveProperty("messageId");
    }
    api.presentMessage = async () => ({ available: false, title: "Poll", fields: [], actions: [], data: { leaked: true }, stateVersion: 2 });
    expect(await host.present(message, "client-1")).toEqual({ available: false, title: "Poll", fields: [], actions: [], stateVersion: 2 });
    api.presentMessage = async () => { throw new Error("offline"); };
    expect(await host.present(message, "client-1")).toEqual({ available: false, title: "Poll", fields: [], actions: [], stateVersion: 0 });
  });
  it("invokes a card action through Core with the message and conversation", async () => {
    const api = port(); let request: unknown;
    api.invokeAction = async (value) => { request = value; return { kind: "operation", response: { success: true, data: { messageState: { version: 4, values: {} } } } }; };
    const host = new PluginUiSession(api, "tauri", () => "en-US");
    expect(await host.invokeAction(message, "vote", { messageId: "server-9", conversationId: "group-1", userGesture: true }))
      .toEqual({ kind: "operation", response: { success: true, data: { messageState: { version: 4, values: {} } } } });
    expect(request).toEqual({ message, messageId: "server-9", conversationId: "group-1", platform: "tauri", actionId: "vote", userGesture: true, nativeAllowlist: [] });
    api.invokeAction = async () => ({ kind: "host", target: { kind: "page", page: "wallet" }, payload: {} });
    await expect(host.invokeAction(message, "vote", { userGesture: true })).rejects.toThrow("Plugin target unavailable");
    const pages: unknown[] = [];
    const navigating = new PluginUiSession(api, "web", undefined, undefined, (page, args) => { pages.push([page, args]); });
    await navigating.invokeAction(message, "vote", { userGesture: true });
    // A card's page target opens a page of the card's plugin, whatever page stack the host has open.
    expect(pages).toEqual([[{ pluginId: message.pluginId, page: "wallet" }, {}]]);
  });
  it("drops an action result from a previous session", async () => {
    const api = port(); let release!: (value: unknown) => void;
    api.invokeAction = () => new Promise((resolve) => { release = resolve; });
    const host = new PluginUiSession(api, "web"); const pending = host.invokeAction(message, "vote", { userGesture: true }); host.reset();
    release({ kind: "operation", response: { success: true } });
    await expect(pending).rejects.toThrow("Plugin session changed");
  });
});
describe("plugin UI card protocol v2", () => {
  const choices = { kind: "choices", options: [{ index: 0, label: "Yes", selected: true, count: 2, percent: 67 }, { index: 1, label: "No", selected: false, count: 1, percent: 33 }],
    multiple: false, voted: true, closed: false, showResults: true, total: 3, inputName: "selection", action: { id: "vote", label: "Vote", style: "primary" } };
  const inputs = [{ id: "question", kind: "text", label: "Question", required: true }];
  it("keeps blocks, inputs, detail and the shared layer version from Core", async () => {
    const api = port();
    api.presentMessage = async () => ({ available: true, title: "Poll", fields: [], actions: [], blocks: [choices], inputs, detail: true,
      data: { counts: [2, 1], mySelection: [0] }, stateVersion: 1, sharedStateVersion: 7 });
    const host = new PluginUiSession(api, "web");
    expect(await host.present(message, "server-1")).toEqual({ available: true, title: "Poll", fields: [], actions: [], blocks: [choices], inputs, detail: true,
      data: { counts: [2, 1], mySelection: [0] }, stateVersion: 1, sharedStateVersion: 7 });
    // Empty or malformed v2 members are left out, so a v1 card keeps its v1 shape.
    api.presentMessage = async () => ({ available: true, title: "Poll", fields: [], actions: [], blocks: [], inputs: "bad", detail: false, stateVersion: 0, sharedStateVersion: 0 });
    expect(await host.present(message, "server-1")).toEqual({ available: true, title: "Poll", fields: [], actions: [], stateVersion: 0 });
  });
  it("sends form values and a selection, and returns Core's form errors", async () => {
    const api = port(); const requests: Array<Record<string, unknown>> = [];
    api.invokeAction = async (request) => { requests.push(request);
      return { kind: "formErrors", errors: [{ input: "question", issue: "required" }, { input: "x", issue: "made-up" }, "junk"] }; };
    const host = new PluginUiSession(api, "android");
    expect(await host.invokeAction(message, "create", { conversationId: "group-1", userGesture: true, formValues: { question: "" } }))
      .toEqual({ kind: "formErrors", errors: [{ input: "question", issue: "required" }] });
    expect(requests[0]).toMatchObject({ actionId: "create", formValues: { question: "" } });
    expect(requests[0]).not.toHaveProperty("selection");
    api.invokeAction = async (request) => { requests.push(request); return { kind: "operation", response: { success: true, data: {} } }; };
    await host.invokeAction(message, "vote", { messageId: "server-1", userGesture: true, selection: [1] });
    expect(requests[1]).toMatchObject({ actionId: "vote", messageId: "server-1", selection: [1] });
    expect(requests[1]).not.toHaveProperty("formValues");
  });
  it("opens a card's detail through Core", async () => {
    const api = port(); let request: unknown;
    const entries = { kind: "entries", items: [{ index: 1, text: "Yes", userId: "u2" }], numbered: true, total: 1, more: false };
    api.pluginDetail = async (value) => { request = value; return { available: true, title: "Poll details", fields: [], actions: [], blocks: [entries] }; };
    const host = new PluginUiSession(api, "ios", () => "en-US");
    expect(await host.detail(message, { messageId: "server-1", conversationId: "group-1", userGesture: true }))
      .toEqual({ available: true, title: "Poll details", fields: [], actions: [], blocks: [entries] });
    expect(request).toEqual({ message, messageId: "server-1", conversationId: "group-1", platform: "ios", locale: "en-US", userGesture: true });
    api.pluginDetail = async () => ({ broken: true });
    await expect(host.detail(message, { userGesture: true })).rejects.toThrow("Plugin detail unavailable");
    delete api.pluginDetail;
    await expect(host.detail(message, { userGesture: true })).rejects.toThrow("Plugin detail unavailable");
  });
  it("pages a detail through Core, which appends each page to the sheet it is given", async () => {
    const api = port(); const requests: Array<Record<string, unknown>> = [];
    const first = { kind: "entries", items: [{ index: 1, text: "Ann" }], numbered: true, total: 2, more: false };
    const merged = { ...first, items: [...first.items, { index: 2, text: "Bo" }] };
    api.pluginDetail = async (value) => {
      requests.push(value);
      return value.cursor
        ? { available: true, title: "Lines", fields: [], actions: [], blocks: [merged] }
        : { available: true, title: "Lines", fields: [], actions: [], blocks: [first], nextCursor: "50" };
    };
    const host = new PluginUiSession(api, "web", () => "en-US");
    const sheet = await host.detail(message, { messageId: "server-1", userGesture: true });
    expect(sheet).toEqual({ available: true, title: "Lines", fields: [], actions: [], blocks: [first], nextCursor: "50" });
    expect(requests[0]).not.toHaveProperty("cursor");
    expect(requests[0]).not.toHaveProperty("previous");
    const more = await host.detail(message, { messageId: "server-1", userGesture: true, page: { cursor: sheet.nextCursor!, previous: sheet } });
    expect(requests[1]).toMatchObject({ messageId: "server-1", cursor: "50", previous: sheet });
    expect(more).toEqual({ available: true, title: "Lines", fields: [], actions: [], blocks: [merged] });
    expect(more).not.toHaveProperty("nextCursor");
    api.pluginDetail = async () => ({ available: true, title: "Lines", fields: [], actions: [], nextCursor: "" });
    expect(await host.detail(message, { userGesture: true })).not.toHaveProperty("nextCursor");
  });
  it("refreshes a shown sheet through Core, which keeps the pages it had loaded", async () => {
    const api = port(); const requests: Array<Record<string, unknown>> = [];
    const shown = { available: true, title: "Lines", fields: [], actions: [],
      blocks: [{ kind: "entries", items: [{ index: 1, text: "Ann" }, { index: 2, text: "Bo" }], numbered: true, total: 3, more: false }],
      nextCursor: "100" } as const;
    const fresh = { kind: "entries", items: [{ index: 1, text: "Cy" }, { index: 2, text: "Ann" }], numbered: true, total: 4, more: false };
    api.pluginDetail = async (value) => { requests.push(value); return { available: true, title: "Lines", fields: [], actions: [], blocks: [fresh], nextCursor: "100" }; };
    const host = new PluginUiSession(api, "web", () => "en-US");
    const sheet = await host.detail(message, { messageId: "server-1", conversationId: "group-1", userGesture: true, refresh: shown });
    expect(requests[0]).toEqual({ message, messageId: "server-1", conversationId: "group-1", platform: "web", locale: "en-US",
      userGesture: true, refresh: true, previous: shown });
    expect(requests[0]).not.toHaveProperty("cursor");
    expect(sheet).toEqual({ available: true, title: "Lines", fields: [], actions: [], blocks: [fresh], nextCursor: "100" });
    await expect(host.detail(message, { userGesture: true, refresh: shown, page: { cursor: "100", previous: shown } }))
      .rejects.toThrow("page and refresh exclude each other");
    expect(requests).toHaveLength(1);
  });
  it("reads a plugin page through Core and runs its actions without a message", async () => {
    const api = port(); const sent: Record<string, unknown>[] = [];
    api.pluginPage = async (request) => {
      sent.push(request);
      return { available: true, title: "Wallet", fields: [{ label: "Balance", value: "¥1.00" }], actions: [],
        blocks: [{ kind: "rows", source: "x.history", columns: [], rows: [{ key: "l1", cells: [], actions: [{ id: "hide", input: { lineId: "l1" } }],
          badge: { text: "Received", tone: "success" } }], actions: [] }],
        nextCursor: "c2", data: { currency: "CNY" } };
    };
    const opened: Array<[unknown, unknown]> = [];
    const host = new PluginUiSession(api, "web", () => "zh-CN", undefined, (page, args) => { opened.push([page, args]); });
    const view = await host.page("example.poll", "example.poll.wallet", { args: { currency: "CNY" }, filters: { kind: "claim" } });
    expect(sent[0]).toEqual({ pluginId: "example.poll", page: "example.poll.wallet", platform: "web", locale: "zh-CN",
      arguments: { currency: "CNY" }, filters: { kind: "claim" } });
    expect(view.nextCursor).toBe("c2");
    expect(view.data).toEqual({ currency: "CNY" });
    await host.page("example.poll", "example.poll.wallet", { page: { cursor: "c2", previous: view } });
    expect(sent[1]).toMatchObject({ cursor: "c2", previous: view });
    await expect(host.page("example.poll", "p", { page: { cursor: "c", previous: view }, refresh: view })).rejects.toThrow();
    const actions: Record<string, unknown>[] = [];
    api.invokePageAction = async (request) => { actions.push({ ...request }); return { kind: "host", target: { kind: "page", page: "example.poll.history" }, payload: { currency: "CNY" } }; };
    await host.invokePageAction("example.poll", "example.poll.wallet", "history", { data: view.data, userGesture: true });
    expect(actions[0]).toEqual({ pluginId: "example.poll", page: "example.poll.wallet", actionId: "history", platform: "web", userGesture: true,
      nativeAllowlist: [], data: { currency: "CNY" } });
    expect(opened).toEqual([[{ pluginId: "example.poll", page: "example.poll.history" }, { currency: "CNY" }]]);
    const bare = new PluginUiSession(port(), "web");
    await expect(bare.page("example.poll", "example.poll.wallet")).rejects.toThrow("Plugin page unavailable");
  });
  it("hands a page action to the port's page action call, which frames it; the card action call is never used for it", async () => {
    const api = port(); const card: unknown[] = []; const pages: unknown[] = [];
    api.invokeAction = async (request) => { card.push(request); return {}; };
    api.invokePageAction = async (request) => { pages.push({ ...request }); return { kind: "formErrors", errors: [{ input: "amount", issue: "required" }] }; };
    const native = { capabilities: ["clipboardWrite"] as const, invoke: async () => null };
    const host = new PluginUiSession(api, "android", () => "en-US", native);
    const outcome = await host.invokePageAction("flare.wallet", "flare.wallet.history", "open", { row: { key: "e-1", input: { entryId: "e-1" } },
      conversationId: "conv-1", userGesture: true, formValues: { note: "hi" }, selection: [0] });
    expect(outcome).toEqual({ kind: "formErrors", errors: [{ input: "amount", issue: "required" }] });
    expect(card).toEqual([]);
    expect(pages).toEqual([{ pluginId: "flare.wallet", page: "flare.wallet.history", actionId: "open", platform: "android", userGesture: true,
      nativeAllowlist: ["clipboardWrite"], row: { key: "e-1", input: { entryId: "e-1" } }, conversationId: "conv-1", formValues: { note: "hi" }, selection: [0] }]);
    // An answer that arrives after the session changed (sign-out, another account) is not acted on.
    let release!: (value: unknown) => void;
    api.invokePageAction = () => new Promise((resolve) => { release = resolve; });
    const pending = host.invokePageAction("flare.wallet", "flare.wallet.home", "refresh", { userGesture: false });
    host.reset(); release({ kind: "operation", response: { success: true } });
    await expect(pending).rejects.toThrow("Plugin session changed");
  });
  it("carries the host conversation through page reads and navigation outside business arguments", async () => {
    const api=port(); const reads:Record<string,unknown>[]=[]; const opened:unknown[]=[];
    api.pluginPage=async (request)=>{reads.push(request);return {available:true,title:"Group",fields:[],actions:[],conversationId:request.conversationId,data:{conversationId:"injected"}};};
    api.invokeAction=async ()=>({kind:"host",target:{kind:"page",page:"flare.checkin.plans"},conversationId:"group-1",payload:{conversationId:"injected"}});
    api.invokePageAction=async ()=>({kind:"host",target:{kind:"page",page:"flare.checkin.plan"},conversationId:"group-1",payload:{planId:"p1",conversationId:"injected"}});
    const session=new PluginUiSession(api,"web",undefined,undefined,(target,args)=>opened.push([target,args]));
    await session.invokeAction({...message,pluginId:"flare.checkin"},"open",{conversationId:"group-1",userGesture:true});
    expect(opened[0]).toEqual([{pluginId:"flare.checkin",page:"flare.checkin.plans",conversationId:"group-1"},{conversationId:"injected"}]);
    const view=await session.page("flare.checkin","flare.checkin.plans",{conversationId:"group-1",args:{conversationId:"injected"}});
    expect(reads[0]).toMatchObject({conversationId:"group-1",arguments:{conversationId:"injected"}});
    expect(view.conversationId).toBe("group-1");
    await session.invokePageAction("flare.checkin","flare.checkin.plans","open",{conversationId:"group-1",data:view.data,userGesture:true});
    expect(opened[1]).toEqual([{pluginId:"flare.checkin",page:"flare.checkin.plan",conversationId:"group-1"},{planId:"p1",conversationId:"injected"}]);
  });
  it("maps the host's UI language onto the manifest locales", () => {
    for (const tag of ["en", "en-US", "en-GB", " EN-au "]) expect(pluginManifestLocale(tag)).toBe("en-US");
    for (const tag of ["zh-CN", "zh-Hant-TW", "ja-JP", "", undefined, null]) expect(pluginManifestLocale(tag)).toBe("zh-CN");
  });
});
