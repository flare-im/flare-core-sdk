/**
 * CorePluginCapabilityHost: each engine request answered once, in order, with the kit's screen for it. Consent answers
 * the decision as it is (the engine keeps only "always"); a payment answers the password as the proof and never keeps
 * it; a location and a pick need no screen; an unknown method and an unmounted host answer unavailable.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { defineComponent, h, type Component } from "vue";
import { flushPromises, mount } from "@vue/test-utils";
import { FlareButton, FlareCapabilityConsent, FlareDocumentCapture, FlarePaymentConfirmation, FlarePinInput } from "@flare-im/vue-ui";
import { takeCapturedPhoto } from "../src/capturedPhotos";
import { provideFlareVoiceRecorder, type FlareVoiceCaptureSession, type FlareVoiceRecorderAdapter } from "@flare-im/vue-ui/composables";
import { useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import {
  CorePluginCapabilityHost, CORE_PLUGIN_CAPABILITY_REQUEST_CHANNEL, corePluginCapabilityFile, createCorePluginCapabilityRequestFeed,
} from "../src/index";

const mounted: Array<{ unmount(): void }> = [];
afterEach(() => { mounted.splice(0).forEach((wrapper) => wrapper.unmount()); });

function render(props: Record<string, unknown> = {}, recorder?: FlareVoiceRecorderAdapter) {
  const hub = createCorePluginCapabilityRequestFeed();
  const complete = vi.fn(async (_id: number, _result: Record<string, unknown>) => undefined);
  const wrapper = mount(defineComponent({ setup() {
    useFlareI18nProvider("en-US");
    if (recorder) provideFlareVoiceRecorder(recorder);
    return () => h(CorePluginCapabilityHost as Component, { requests: hub.requests, complete, paymentPasswordLabel: "Payment PIN",
      pluginName: (id: string) => (id === "flare.wallet" ? "Wallet" : undefined), ...props });
  } }), { attachTo: document.body });
  mounted.push(wrapper);
  return { wrapper, hub, complete };
}

describe("CorePluginCapabilityHost", () => {
  it("reads only well-formed requests from the event channel", () => {
    const { hub } = render();
    expect(CORE_PLUGIN_CAPABILITY_REQUEST_CHANNEL).toBe("im://plugin_capability_request");
    expect(hub.announce({ requestId: 0, method: "consent", request: {} })).toBe(false);
    expect(hub.announce({ requestId: 3, method: "", request: {} })).toBe(false);
    expect(hub.announce(null)).toBe(false);
  });

  it("answers consent with the viewer's decision as it is, with the plugin's name", async () => {
    const { wrapper, hub, complete } = render();
    hub.announce({ requestId: 7, method: "consent", request: { pluginId: "flare.wallet", pluginVersion: "0.6.0", capability: "paymentConfirmation" } });
    await flushPromises();
    const consent = wrapper.getComponent(FlareCapabilityConsent);
    expect(consent.props("pluginName")).toBe("Wallet");
    expect(consent.props("capability")).toBe("paymentConfirmation");
    consent.vm.$emit("decide", "once");
    await flushPromises();
    expect(complete).toHaveBeenCalledWith(7, { decision: "once" });
    expect(wrapper.findComponent(FlareCapabilityConsent).exists()).toBe(false);
  });

  it("hands a captured document photo to the page once, then answers the file", async () => {
    const { wrapper, hub, complete } = render();
    hub.announce({ requestId: 4, method: "captureDocument", request: { pluginId: "flare.realname", side: "back" } });
    await flushPromises();
    wrapper.getComponent(FlareDocumentCapture).vm.$emit("done", { fileName: "back.jpg", contentType: "image/jpeg", bytes: new Uint8Array([1, 2, 3]) });
    await flushPromises();
    const photo = takeCapturedPhoto("flare.realname", "back");
    expect(photo?.type).toBe("image/jpeg");
    expect(photo?.size).toBe(3);
    expect(takeCapturedPhoto("flare.realname", "back")).toBeUndefined();
    expect(complete).toHaveBeenCalledWith(4, { file: { fileName: "back.jpg", contentType: "image/jpeg", bytes: [1, 2, 3] } });
  });

  it("answers requests one at a time, in order", async () => {
    const { wrapper, hub, complete } = render();
    hub.announce({ requestId: 1, method: "consent", request: { pluginId: "a", capability: "documentCapture" } });
    hub.announce({ requestId: 2, method: "consent", request: { pluginId: "b", capability: "locationOnce", params: { precision: "fine" } } });
    await flushPromises();
    wrapper.getComponent(FlareCapabilityConsent).vm.$emit("decide", "deny");
    await flushPromises();
    expect(wrapper.getComponent(FlareCapabilityConsent).props("params")).toEqual({ precision: "fine" });
    wrapper.getComponent(FlareCapabilityConsent).vm.$emit("decide", "always");
    await flushPromises();
    expect(complete.mock.calls).toEqual([[1, { decision: "deny" }], [2, { decision: "always" }]]);
  });

  it("confirms a payment with the six-digit password as the proof and keeps nothing", async () => {
    const { wrapper, hub, complete } = render();
    const order = { orderId: "o-1", amount: "12.50", currency: "CNY", payee: "Alice", title: "Transfer", expiresAtMs: Date.now() + 600000,
      operation: "flare.wallet.payments.confirm" };
    hub.announce({ requestId: 9, method: "confirmPayment", request: { pluginId: "flare.wallet", order } });
    await flushPromises();
    const sheet = wrapper.getComponent(FlarePaymentConfirmation);
    expect(sheet.props("order")).toMatchObject({ orderId: "o-1", amount: "12.50", payee: "Alice" });
    expect(sheet.props("confirmDisabled")).toBe(true);
    const field = document.body.querySelector("input") as HTMLInputElement;
    field.value = "123456";
    field.dispatchEvent(new Event("input"));
    await flushPromises();
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("confirmDisabled")).toBe(false);
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("confirm");
    await flushPromises();
    expect(complete).toHaveBeenCalledWith(9, { confirmation: { method: "paymentPassword", password: "123456" } });
    expect(wrapper.findComponent(FlarePaymentConfirmation).exists()).toBe(false);
  });

  it("keeps the sheet busy until the engine settles, and shows a refused password in the same sheet for another try", async () => {
    const errorText = (cause: unknown) => ((cause as { machineReason?: string }).machineReason === "PAYMENT_PASSWORD_INVALID" ? "Wrong PIN" : undefined);
    const { wrapper, hub, complete } = render({ errorText });
    const order = { orderId: "o-7", amount: "8.88", currency: "CNY", payee: "Red packet", title: "Lucky", expiresAtMs: Date.now() + 600000 };
    const type = async (digits: string) => {
      const field = document.body.querySelector("input") as HTMLInputElement;
      field.value = digits;
      field.dispatchEvent(new Event("input"));
      await flushPromises();
    };
    hub.announce({ requestId: 20, method: "confirmPayment", request: { pluginId: "flare.redpacket", order, reportsOutcome: true } });
    await flushPromises();
    // The credential slot is the kit's six cells; five digits keep confirm off.
    expect(wrapper.findComponent(FlarePinInput).exists()).toBe(true);
    await type("12345");
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("confirmDisabled")).toBe(true);
    await type("123456");
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("confirm");
    await flushPromises();
    expect(complete).toHaveBeenCalledWith(20, { confirmation: { method: "paymentPassword", password: "123456" } });
    // Answered, still up: busy, the PIN locked, and no way out.
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("busy")).toBe(true);
    expect(wrapper.getComponent(FlarePinInput).props("disabled")).toBe(true);
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("cancel");
    await flushPromises();
    expect(complete).toHaveBeenCalledTimes(1);
    // The provider refused it: the engine asks again for the same order, with why.
    hub.announce({ requestId: 21, method: "confirmPayment", request: { pluginId: "flare.redpacket", order, reportsOutcome: true,
      error: { key: "sdk.plugin.rejected", code: "PAYMENT_PASSWORD_INVALID" } } });
    await flushPromises();
    const sheet = wrapper.getComponent(FlarePaymentConfirmation);
    expect(sheet.props("busy")).toBe(false);
    expect(sheet.props("error")).toBe("Wrong PIN");
    expect(sheet.props("confirmDisabled")).toBe(true);
    await type("654321");
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("confirm");
    await flushPromises();
    expect(complete).toHaveBeenLastCalledWith(21, { confirmation: { method: "paymentPassword", password: "654321" } });
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("error")).toBeUndefined();
    // A notice for another order changes nothing; the one for this order closes the sheet, unanswered.
    hub.announce({ requestId: 22, method: "paymentSettled", request: { pluginId: "flare.redpacket", orderId: "o-other" } });
    await flushPromises();
    expect(wrapper.findComponent(FlarePaymentConfirmation).exists()).toBe(true);
    hub.announce({ requestId: 23, method: "paymentSettled", request: { pluginId: "flare.redpacket", orderId: "o-7" } });
    await flushPromises();
    expect(wrapper.findComponent(FlarePaymentConfirmation).exists()).toBe(false);
    expect(complete).toHaveBeenCalledTimes(2);
  });

  it("shows the provider's words for a refused password over the host's mapping", async () => {
    const errorText = () => "Wrong PIN";
    const { wrapper, hub } = render({ errorText });
    const order = { orderId: "o-8", amount: "1", currency: "CNY", payee: "Bob", title: "Gift", expiresAtMs: Date.now() + 600000 };
    hub.announce({ requestId: 30, method: "confirmPayment", request: { pluginId: "flare.wallet", order, reportsOutcome: true,
      error: { key: "sdk.plugin.rejected", code: "PAYMENT_PASSWORD_INVALID", message: "支付密码错误，请重新输入" } } });
    await flushPromises();
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("error")).toBe("支付密码错误，请重新输入");
  });

  it("names the plugin the order is for when the host knows it, else the requesting plugin", async () => {
    const names: Record<string, string> = { "flare.wallet": "Wallet", "acme.gift": "Gift box" };
    const { wrapper, hub } = render({ pluginName: (id: string) => names[id] });
    const order = { orderId: "o-9", amount: "1", currency: "CNY", payee: "Bob", title: "Gift", expiresAtMs: Date.now() + 600000 };
    hub.announce({ requestId: 40, method: "confirmPayment", request: { pluginId: "flare.wallet", order: { ...order, requestedBy: "acme.gift" } } });
    await flushPromises();
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("pluginName")).toBe("Gift box");
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("cancel");
    hub.announce({ requestId: 41, method: "confirmPayment", request: { pluginId: "flare.wallet", order: { ...order, orderId: "o-10", requestedBy: "acme.unknown" } } });
    await flushPromises();
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("pluginName")).toBe("Wallet");
  });

  it("shows a short balance formatted, and top up answers cancelled then opens the page of the requesting plugin", async () => {
    const openPage = vi.fn();
    const { wrapper, hub, complete } = render({ onOpenPage: openPage });
    const order = { orderId: "o-5", amount: "26.64", currency: "CNY", payee: "Red packet", title: "Lucky", expiresAtMs: Date.now() + 600000,
      shortfall: "6.64", topUp: { kind: "page", page: "flare.wallet.page.recharge" } };
    hub.announce({ requestId: 11, method: "confirmPayment", request: { pluginId: "flare.redpacket", order } });
    await flushPromises();
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("shortfall")).toBe("¥6.64");
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("topUp");
    await flushPromises();
    expect(complete).toHaveBeenCalledWith(11, { cancelled: true });
    // No pluginId on the target: the plugin that asked for the payment.
    expect(openPage).toHaveBeenCalledWith({ pluginId: "flare.redpacket", page: "flare.wallet.page.recharge" });
    expect(complete.mock.invocationCallOrder[0]).toBeLessThan(openPage.mock.invocationCallOrder[0]);
    expect(wrapper.findComponent(FlarePaymentConfirmation).exists()).toBe(false);
    // Without the engine's shortfall nothing is short, and a zero or malformed one is ignored.
    hub.announce({ requestId: 12, method: "confirmPayment", request: { pluginId: "flare.wallet", order: { ...order, orderId: "o-6", shortfall: "0.00", topUp: undefined } } });
    await flushPromises();
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("shortfall")).toBeUndefined();
  });

  it("keeps an expired payment open until the viewer starts again, then answers cancelled once", async () => {
    const { wrapper, hub, complete } = render();
    const order = { orderId: "o-2", amount: "1", currency: "CNY", payee: "Bob", title: "Gift", expiresAtMs: Date.now() + 600000 };
    hub.announce({ requestId: 4, method: "confirmPayment", request: { pluginId: "flare.wallet", order } });
    hub.announce({ requestId: 6, method: "confirmPayment", request: { pluginId: "flare.wallet", order: { ...order, orderId: "o-4" } } });
    await flushPromises();
    // §4.3: expiry leaves the panel in the kit's expired state; nothing is answered yet.
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("expire");
    await flushPromises();
    expect(complete).not.toHaveBeenCalled();
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("order")).toMatchObject({ orderId: "o-2" });
    // Start again (and a close in the same tick) answers this order once; the next queued order is not touched.
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("startAgain");
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("cancel");
    await flushPromises();
    expect(complete.mock.calls).toEqual([[4, { cancelled: true }]]);
    expect(wrapper.getComponent(FlarePaymentConfirmation).props("order")).toMatchObject({ orderId: "o-4" });
  });

  it("cancels a payment the viewer backs out of, and refuses an order it cannot show", async () => {
    const { wrapper, hub, complete } = render();
    const order = { orderId: "o-2", amount: "1", currency: "CNY", payee: "Bob", title: "Gift", expiresAtMs: Date.now() + 600000 };
    hub.announce({ requestId: 4, method: "confirmPayment", request: { pluginId: "flare.wallet", order } });
    await flushPromises();
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("cancel");
    await flushPromises();
    hub.announce({ requestId: 5, method: "confirmPayment", request: { pluginId: "flare.wallet", order: { orderId: "o-3" } } });
    await flushPromises();
    expect(complete.mock.calls).toEqual([[4, { cancelled: true }], [5, { unavailable: true }]]);
  });

  it("locates once at the precision asked, and answers unavailable without a fix", async () => {
    const locate = vi.fn(async (precision: string) => (precision === "fine" ? { latitude: 1.5, longitude: 2.5, accuracyM: 8 } : null));
    const { hub, complete } = render({ locate });
    hub.announce({ requestId: 11, method: "locateOnce", request: { pluginId: "example.checkin", precision: "fine" } });
    await flushPromises();
    hub.announce({ requestId: 12, method: "locateOnce", request: { pluginId: "example.checkin", precision: "coarse" } });
    await flushPromises();
    expect(locate.mock.calls).toEqual([["fine"], ["coarse"]]);
    expect(complete.mock.calls).toEqual([[11, { location: { latitude: 1.5, longitude: 2.5, accuracyM: 8 } }], [12, { unavailable: true }]]);
  });

  it("picks a file within the request's accept list and size, and answers an unknown method unavailable", async () => {
    const file = new File([new Uint8Array([1, 2, 3])], "a.png", { type: "image/png" });
    Object.defineProperty(file, "arrayBuffer", { value: async () => new Uint8Array([1, 2, 3]).buffer });
    const pickFile = vi.fn(async () => file);
    const { wrapper, hub, complete } = render({ pickFile });
    hub.announce({ requestId: 21, method: "pickFile", request: { pluginId: "p", capability: "selectImage", accept: ["image/png"], maxBytes: 10 } });
    await flushPromises();
    expect(pickFile).not.toHaveBeenCalled();
    await wrapper.getComponent(FlareButton).trigger("click");
    await flushPromises();
    hub.announce({ requestId: 22, method: "pickFile", request: { pluginId: "p", capability: "selectImage", accept: ["image/jpeg"], maxBytes: 10 } });
    await flushPromises();
    await wrapper.getComponent(FlareButton).trigger("click");
    await flushPromises();
    hub.announce({ requestId: 23, method: "rtcSession", request: { pluginId: "p" } });
    await flushPromises();
    expect(complete.mock.calls).toEqual([
      [21, { file: { fileName: "a.png", contentType: "image/png", bytes: [1, 2, 3] } }],
      [22, { unavailable: true }],
      [23, { unavailable: true }],
    ]);
    expect(await corePluginCapabilityFile(file, [], 2)).toBeNull();
  });

  it("answers what is still waiting as unavailable when it goes away", async () => {
    const { wrapper, hub, complete } = render();
    hub.announce({ requestId: 31, method: "consent", request: { pluginId: "a", capability: "documentCapture" } });
    await flushPromises();
    wrapper.unmount();
    mounted.splice(0);
    await flushPromises();
    expect(complete).toHaveBeenCalledWith(31, { unavailable: true });
  });

  it("opens the microphone only on click and sends audio only after review", async () => {
    let data: (chunk: BlobPart) => void = () => {};
    let stopped: () => void = () => {};
    let state: FlareVoiceCaptureSession["state"] = "inactive";
    const release = vi.fn();
    const session: FlareVoiceCaptureSession = {
      mimeType: "audio/webm;codecs=opus",
      get state() { return state; },
      start() { state = "recording"; },
      stop() { state = "inactive"; data(new Uint8Array([1, 2, 3])); stopped(); },
      pause() {}, resume() {}, requestData() {},
      onData(callback) { data = callback; },
      onStop(callback) { stopped = callback; },
      onError() {}, onEnded() {}, release,
    };
    const open = vi.fn(async () => session);
    const { wrapper, hub, complete } = render({}, { isSupported: () => true, open });
    hub.announce({ requestId: 41, method: "pickFile", request: {
      pluginId: "p", capability: "microphone", accept: ["audio/webm"], maxBytes: 10,
    } });
    await flushPromises();
    expect(open).not.toHaveBeenCalled();
    const click = async (label: string) => {
      const button = wrapper.findAllComponents(FlareButton).find((candidate) => candidate.props("label") === label);
      expect(button).toBeDefined();
      await button!.trigger("click");
      await flushPromises();
    };
    await click("Start recording");
    expect(open).toHaveBeenCalledOnce();
    await click("Stop recording");
    expect(release).toHaveBeenCalledOnce();
    expect(complete).not.toHaveBeenCalled();
    await click("Use recording");
    expect(complete).toHaveBeenCalledWith(41, { file: {
      fileName: expect.stringMatching(/\.webm$/), contentType: "audio/webm", bytes: [1, 2, 3],
    } });
  });
});
