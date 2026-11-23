/**
 * CorePluginCapabilityHost: each engine request answered once, in order, with the kit's screen for it. Consent answers
 * the decision as it is (the engine keeps only "always"); a payment answers the password as the proof and never keeps
 * it; a location and a pick need no screen; an unknown method and an unmounted host answer unavailable.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { defineComponent, h, type Component } from "vue";
import { flushPromises, mount } from "@vue/test-utils";
import { FlareButton, FlareCapabilityConsent, FlarePaymentConfirmation } from "@flare-im/vue-ui";
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

  it("cancels a payment the viewer backs out of or that runs out, and refuses an order it cannot show", async () => {
    const { wrapper, hub, complete } = render();
    const order = { orderId: "o-2", amount: "1", currency: "CNY", payee: "Bob", title: "Gift", expiresAtMs: Date.now() + 600000 };
    hub.announce({ requestId: 4, method: "confirmPayment", request: { pluginId: "flare.wallet", order } });
    await flushPromises();
    wrapper.getComponent(FlarePaymentConfirmation).vm.$emit("expire");
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
