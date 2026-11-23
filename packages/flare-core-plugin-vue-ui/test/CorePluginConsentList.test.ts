import { afterEach, describe, expect, it, vi } from "vitest";
import { defineComponent, h, shallowRef } from "vue";
import { flushPromises, mount } from "@vue/test-utils";
import { FlareEmptyState, FlareSettingsList, FlareUiProvider } from "@flare-im/vue-ui";
import ConsentList, { type CorePluginConsentPort } from "../src/CorePluginConsentList.vue";

const texts = { empty: "No saved permissions", revokeTitle: "Revoke permission", revokeDescription: "Ask again next time", revoke: "Revoke", failed: "Could not update permissions" };
const consent = { pluginId: "test.wallet", capability: "documentCapture", level: 0 };
const mounted: ReturnType<typeof mount>[] = [];
afterEach(() => { mounted.splice(0).forEach(w => w.unmount()); });
function render(initial: CorePluginConsentPort | null) {
  const port = shallowRef(initial);
  const wrapper = mount(defineComponent({ setup: () => () => h(FlareUiProvider, { locale: "en-US" }, {
    default: () => h(ConsentList, { port: port.value, texts, pluginName: () => "Wallet" }),
  }) }), { attachTo: document.body });
  mounted.push(wrapper);
  return { wrapper, port };
}
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>(yes => { resolve = yes; });
  return { promise, resolve };
}
function clickDialogAction() {
  const dialog = document.querySelector('[role="dialog"]')!;
  const button = [...dialog.querySelectorAll<HTMLButtonElement>('button')].find(b => b.textContent?.trim() === texts.revoke)!;
  button.click();
}

describe("CorePluginConsentList recovery", () => {
  it("shows loading while the SDK is starting and reads when its port arrives", async () => {
    const { wrapper, port } = render(null);
    expect(wrapper.getComponent(FlareEmptyState).props("loading")).toBe(true);
    const capabilityConsents = vi.fn(async () => ({ consents: [] }));
    port.value = { capabilityConsents, revokeCapabilityConsent: vi.fn() };
    await flushPromises();
    expect(capabilityConsents).toHaveBeenCalledOnce();
    expect(wrapper.text()).toContain(texts.empty);
  });

  it("offers retry after a read fails without reporting an empty permission list", async () => {
    const capabilityConsents = vi.fn().mockRejectedValueOnce(new Error("private transport detail")).mockResolvedValueOnce({ consents: [consent] });
    const { wrapper } = render({ capabilityConsents, revokeCapabilityConsent: vi.fn() });
    await flushPromises();
    expect(wrapper.text()).toContain(texts.failed);
    expect(wrapper.text()).not.toContain(texts.empty);
    expect(wrapper.text()).not.toContain("private transport detail");
    const retry = wrapper.findAll("button").find(b => b.text() === "Retry")!;
    expect(retry).toBeDefined();
    await retry.trigger("click"); await flushPromises();
    expect(wrapper.getComponent(FlareSettingsList).props("sections")[0].items).toHaveLength(1);
  });

  it("keeps a failed revoke open for retry and only removes the grant after success", async () => {
    let revoked = false;
    const capabilityConsents = vi.fn(async () => ({ consents: revoked ? [] : [consent] }));
    const revokeCapabilityConsent = vi.fn().mockRejectedValueOnce(new Error("private revocation detail")).mockImplementationOnce(async () => { revoked = true; return {}; });
    const { wrapper } = render({ capabilityConsents, revokeCapabilityConsent });
    await flushPromises();
    const list = wrapper.getComponent(FlareSettingsList);
    list.vm.$emit("select", list.props("sections")[0].items[0]); await flushPromises();
    clickDialogAction(); await flushPromises();
    expect(document.querySelector('[role="dialog"]')?.textContent).toContain(texts.failed);
    expect(document.body.textContent).not.toContain("private revocation detail");
    expect(capabilityConsents).toHaveBeenCalledTimes(1);
    expect(wrapper.getComponent(FlareSettingsList).props("sections")[0].items).toHaveLength(1);
    clickDialogAction(); await flushPromises();
    expect(revokeCapabilityConsent).toHaveBeenCalledTimes(2);
    expect(revokeCapabilityConsent).toHaveBeenLastCalledWith({ pluginId: consent.pluginId, capability: consent.capability });
    expect(document.querySelector('[role="dialog"]')).toBeNull();
    expect(wrapper.text()).toContain(texts.empty);
  });

  it("ignores a read from a replaced port", async () => {
    const old = deferred<Record<string, unknown>>();
    const { wrapper, port } = render({ capabilityConsents: () => old.promise, revokeCapabilityConsent: vi.fn() });
    port.value = { capabilityConsents: vi.fn(async () => ({ consents: [] })), revokeCapabilityConsent: vi.fn() };
    await flushPromises(); old.resolve({ consents: [consent] }); await flushPromises();
    expect(wrapper.text()).toContain(texts.empty);
    expect(wrapper.findComponent(FlareSettingsList).exists()).toBe(false);
  });
});
