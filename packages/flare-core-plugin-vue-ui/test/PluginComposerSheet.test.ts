import { afterEach, describe, expect, it, vi } from "vitest";
import { h, nextTick } from "vue";
import { flushPromises } from "@vue/test-utils";
import { FlareDangerConfirm, FlarePluginForm, FlarePluginView } from "@flare-im/vue-ui";
import {
  CLOSED_COMPOSER_MENU, PluginComposerSheet, composerPanelActions, parseComposerMenu, pluginPostedCard,
  routeComposerAction, useComposerMenu, type ComposerPluginItem,
} from "../src/index";
import { deferred, fakePort, mountWithSession, unmountAll } from "./support";

const item: ComposerPluginItem = { id: "plugin:acme.task.create", kind: "plugin", pluginId: "acme.task", contributionId: "acme.task.create", label: "Task", order: 130 };
const synthesized = { pluginId: "acme.task", contributionId: "acme.task.create", schemaVersion: 1, summary: "Task", payload: { conversationId: "group-1" } };
/** What Core answers once it has posted the card in the user's name: the plugin's own `message` never reaches the client. */
const posted = { conversationId: "group-1", serverMsgId: "srv-77", clientMsgId: "pcard-1" };
const inputs = [
  { id: "title", kind: "text", label: "Title", required: true },
  { id: "assignees", kind: "members", label: "Assignees" },
  { id: "hidden", kind: "toggle", label: "Unused by create" },
];
const formView = (extra: Record<string, unknown> = {}) => ({
  available: true, title: "New task", fields: [], stateVersion: 0, inputs,
  actions: [{ id: "help", label: "Help" }, { id: "create", label: "Create", style: "primary", form: ["title", "assignees"] }],
  ...extra,
});

afterEach(unmountAll);

function render(port = fakePort(), props: Record<string, unknown> = {}, directory?: Parameters<typeof mountWithSession>[2]) {
  const onPosted = vi.fn();
  const close = vi.fn();
  const { wrapper } = mountWithSession(port, () => h(PluginComposerSheet, { item, conversationId: "group-1", onPosted, onClose: close, ...props }), directory);
  return { port, wrapper, onPosted, close };
}

describe("PluginComposerSheet", () => {
  it.each([
    { success: false, posted },
    { success: undefined, posted },
    { success: true, posted: { ...posted, conversationId: "other-chat" } },
    { success: true, posted: { ...posted, clientMsgId: "" } },
    { success: true, posted: { ...posted, serverMsgId: " " } },
  ])("keeps the composer open without a definite matching posted result: %j", async (response) => {
    const port = fakePort({ presentMessage: vi.fn(async () => formView()), invokeAction: vi.fn(async () => ({ kind: "operation", response: { success: response.success, data: { posted: response.posted } } })) });
    const { wrapper, onPosted, close } = render(port);
    await flushPromises();
    wrapper.getComponent(FlarePluginForm).vm.$emit("submit", { title: "Ship it" });
    await flushPromises();
    expect(onPosted).not.toHaveBeenCalled();
    expect(close).not.toHaveBeenCalled();
  });

  it("draws a contribution without inputs embedded in the sheet and runs its keys", async () => {
    const port = fakePort({
      presentMessage: vi.fn(async () => ({ available: true, title: "Quick vote", fields: [{ label: "Question", value: "Lunch?" }], actions: [{ id: "send", label: "Send" }], stateVersion: 0 })),
      invokeAction: vi.fn(async () => ({ kind: "operation", response: { success: true, requestId: "req-7", data: { posted } } })),
    });
    const { wrapper, onPosted, close } = render(port);
    await flushPromises();
    expect(port.presentMessage).toHaveBeenCalledWith(expect.objectContaining({ message: synthesized, kind: "composer-action" }));
    const view = wrapper.getComponent(FlarePluginView);
    // Straight into the kit sheet: the kit's sheet insets, no wrapper of the host's own.
    expect(view.props()).toMatchObject({ embedded: true, inset: "sheet", settleToken: 0 });
    expect(view.element.parentElement?.classList.contains("core-plugin-entry__body")).toBe(false);
    expect(wrapper.findComponent(FlarePluginForm).exists()).toBe(false);
    view.vm.$emit("action", "send");
    await flushPromises();
    expect(port.invokeAction).toHaveBeenCalledWith(expect.objectContaining({ message: synthesized, actionId: "send", conversationId: "group-1", userGesture: true }));
    // Nothing is sent from here: the sheet names the card Core posted and closes; the card comes with the push.
    expect(onPosted).toHaveBeenCalledWith(posted);
    expect(port.dispatch).not.toHaveBeenCalled();
    expect(close).toHaveBeenCalledTimes(1);
  });

  it("collects a contribution's inputs with the kit form and submits them to the create action", async () => {
    const answer = deferred<unknown>();
    const port = fakePort({ presentMessage: vi.fn(async () => formView()), invokeAction: vi.fn(() => answer.promise) });
    const members = [{ userId: "u-1", name: "Ann" }];
    const { wrapper, onPosted, close } = render(port, {}, { members: () => members });
    await flushPromises();
    const form = () => wrapper.getComponent(FlarePluginForm);
    expect(wrapper.findComponent(FlarePluginView).exists()).toBe(false);
    expect(form().props("inputs").map((input: { id: string }) => input.id)).toEqual(["title", "assignees"]);
    expect(form().props("submitLabel")).toBe("Create");
    expect(form().props("members")).toBe(members);

    form().vm.$emit("submit", { title: "Ship it", assignees: ["u-1"] });
    await nextTick();
    expect(port.invokeAction).toHaveBeenCalledWith(expect.objectContaining({
      message: synthesized, actionId: "create", conversationId: "group-1", userGesture: true, formValues: { title: "Ship it", assignees: ["u-1"] },
    }));
    expect(form().props("busy")).toBe(true);
    answer.resolve({ kind: "operation", response: { success: true, requestId: "req-9", data: { posted } } });
    await flushPromises();
    expect(onPosted).toHaveBeenCalledWith(posted);
    expect(close).toHaveBeenCalledTimes(1);
  });

  it("keeps the form open with Core's errors, then with a refusal, clearing both when the next submit starts", async () => {
    const port = fakePort({ presentMessage: vi.fn(async () => formView()) });
    port.invokeAction
      .mockResolvedValueOnce({ kind: "formErrors", errors: [{ input: "title", issue: "required" }] })
      .mockResolvedValueOnce({ kind: "operation", response: { success: false } })
      .mockImplementationOnce(() => new Promise(() => {}));
    const { wrapper, onPosted, close } = render(port);
    await flushPromises();
    const form = () => wrapper.getComponent(FlarePluginForm);
    form().vm.$emit("submit", { title: " " });
    await flushPromises();
    expect(form().props("errors")).toEqual([{ input: "title", issue: "required" }]);
    expect(form().props("busy")).toBe(false);
    form().vm.$emit("submit", { title: "Ship it" });
    await flushPromises();
    expect(form().props("errors")).toEqual([]);
    expect(form().props("error")).toBeTruthy();
    form().vm.$emit("submit", { title: "Ship it" });
    await nextTick();
    expect(form().props("error")).toBeUndefined();
    expect(form().props("busy")).toBe(true);
    expect(onPosted).not.toHaveBeenCalled();
    expect(close).not.toHaveBeenCalled();
  });

  it("shows what the document says besides the form above it, without its keys", async () => {
    const port = fakePort({ presentMessage: vi.fn(async () => formView({ blocks: [{ kind: "note", text: "Everyone in the group sees it" }] })) });
    const { wrapper } = render(port);
    await flushPromises();
    const preface = wrapper.getComponent(FlarePluginView);
    expect(preface.props()).toMatchObject({ embedded: true, inset: "sheetTop" });
    expect(preface.props("view")).toMatchObject({ blocks: [{ kind: "note" }], actions: [] });
    expect(wrapper.findComponent(FlarePluginForm).exists()).toBe(true);
  });

  it("asks first when the create action wants confirmation", async () => {
    const port = fakePort({
      presentMessage: vi.fn(async () => formView({ actions: [{ id: "create", label: "Publish", confirm: "Everyone will be notified", form: ["title"] }] })),
    });
    const { wrapper } = render(port);
    await flushPromises();
    wrapper.getComponent(FlarePluginForm).vm.$emit("submit", { title: "Notice" });
    await nextTick();
    expect(port.invokeAction).not.toHaveBeenCalled();
    const confirm = wrapper.getComponent(FlareDangerConfirm);
    expect(confirm.props("description")).toBe("Everyone will be notified");
    confirm.vm.$emit("confirm");
    await flushPromises();
    expect(port.invokeAction).toHaveBeenCalledWith(expect.objectContaining({ actionId: "create", formValues: { title: "Notice" } }));
  });

  it("settles a drawn view's key once its outcome is set, and stays open to say a refusal", async () => {
    const port = fakePort({
      presentMessage: vi.fn(async () => ({ available: true, title: "Quick vote", fields: [], actions: [{ id: "send", label: "Send" }], stateVersion: 0 })),
      invokeAction: vi.fn(async () => ({ kind: "operation", response: { success: false } })),
    });
    const { wrapper, close } = render(port);
    await flushPromises();
    const view = () => wrapper.getComponent(FlarePluginView);
    view().vm.$emit("action", "send");
    await flushPromises();
    expect(view().props()).toMatchObject({ settleToken: 1, busyActionId: undefined });
    expect(view().props("error")).toBeTruthy();
    expect(close).not.toHaveBeenCalled();
  });

  it("closes from the form's cancel, but not while a submit is in flight", async () => {
    const port = fakePort({ presentMessage: vi.fn(async () => formView()), invokeAction: vi.fn(() => new Promise(() => {})) });
    const { wrapper, close } = render(port);
    await flushPromises();
    wrapper.getComponent(FlarePluginForm).vm.$emit("submit", { title: "x" });
    await nextTick();
    wrapper.getComponent(FlarePluginForm).vm.$emit("cancel");
    expect(close).not.toHaveBeenCalled();
    const idle = render(fakePort({ presentMessage: vi.fn(async () => formView()) }));
    await flushPromises();
    idle.wrapper.getComponent(FlarePluginForm).vm.$emit("cancel");
    expect(idle.close).toHaveBeenCalledTimes(1);
  });
});

describe("composer menu exports", () => {
  it("still parse, lay out and route the social SDK's menu", () => {
    const menu = parseComposerMenu({ tools: ["emoji", "attachments"], actions: [
      { id: "image", kind: "feature", featureKey: "chat.image", icon: "image", order: 10 },
      { ...item, icon: "task" },
    ] });
    expect(composerPanelActions(menu).map((action) => action.id)).toEqual(["image", "plugin:acme.task.create"]);
    const fallback = vi.fn();
    expect(routeComposerAction(menu, item.id, { features: {}, plugins: {}, fallback })).toBe(true);
    expect(fallback).toHaveBeenCalledWith(expect.objectContaining({ pluginId: "acme.task" }));
    expect(parseComposerMenu(null)).toBe(CLOSED_COMPOSER_MENU);
    expect(pluginPostedCard({ posted })).toEqual(posted);
    expect(pluginPostedCard({ posted: { conversationId: "group-1" } })).toBeNull();
    // A plugin's envelope is not something a client posts any more.
    expect(pluginPostedCard({ message: { pluginId: "acme.task" } })).toBeNull();
    expect(typeof useComposerMenu).toBe("function");
  });
});
