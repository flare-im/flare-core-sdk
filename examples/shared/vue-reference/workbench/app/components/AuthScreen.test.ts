// @vitest-environment happy-dom
import { afterEach, describe, expect, it } from "vitest";
import { mount } from "@vue/test-utils";
import { defineComponent, h, nextTick, reactive, type Component } from "vue";
import { registerFlareMessages, useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import AuthScreen from "./AuthScreen.vue";
import { flareMessages as referenceMessages } from "../../i18n/legacyMessages";

// The auth copy (`login.*`) is reference-app copy, registered at bootstrap by
// configureReferenceApp; the test registers it the same way.
for (const [locale, tree] of Object.entries(referenceMessages)) registerFlareMessages(locale, tree);

const hosts: ReturnType<typeof mount>[] = [];

function setup(overrides: Record<string, unknown> = {}, count = 1) {
  const props = reactive({
    userId: "",
    ...overrides,
  });
  const host = mount(defineComponent({ setup() {
    useFlareI18nProvider("en-US");
    return () => h("div", Array.from({ length: count }, () => h(AuthScreen as Component, props)));
  } }), { attachTo: document.body });
  hosts.push(host);
  return { props, screen: host.findComponent(AuthScreen), screens: host.findAllComponents(AuthScreen) };
}

afterEach(() => {
  hosts.splice(0).forEach(host => host.unmount());
  document.body.innerHTML = "";
  localStorage.clear();
});

describe("shared authentication screen", () => {
  it("uses the shared decorative brand motif without rendering simulated messages", () => {
    const { screen } = setup();
    expect(screen.get(".flare-auth-shell__art").attributes("aria-hidden")).toBe("true");
    expect(screen.findAll(".message-bubble")).toHaveLength(0);
    expect(screen.findAll("form")).toHaveLength(1);
    expect(screen.emitted("login")).toBeUndefined();
  });

  it("labels the identity field and asks for nothing else: where to connect is the build's", () => {
    const { screen } = setup();
    expect(screen.text()).toContain("Flare IM");
    expect(screen.get("h1").text()).toBe("Welcome back");
    const input = screen.get(".auth-user-input input");
    expect(input.attributes("aria-label")).toBe("User ID");
    expect(document.getElementById(input.attributes("aria-describedby") ?? "")?.textContent?.toLowerCase()).toContain("user id");
    expect(screen.findAll("form input")).toHaveLength(1);
    expect(screen.findAll(".auth-server-toggle")).toHaveLength(0);
    expect(screen.text()).not.toMatch(/WebSocket|QUIC|gateway URL/i);
  });

  it("blocks empty and whitespace submissions, then submits a valid identity", async () => {
    const { screen, props } = setup();
    expect(screen.get(".auth-login-btn").attributes("disabled")).toBeDefined();
    await screen.get("form").trigger("submit");
    props.userId = "   ";
    await nextTick();
    await screen.get("form").trigger("submit");
    expect(screen.emitted("login")).toBeUndefined();
    props.userId = "auth-test-user";
    await nextTick();
    expect(screen.get(".auth-login-btn").attributes("disabled")).toBeUndefined();
    await screen.get("form").trigger("submit");
    expect(screen.emitted("login")).toHaveLength(1);
  });

  it("prevents duplicate submission while busy and allows retry without clearing the identity", async () => {
    const { screen, props } = setup({ userId: "auth-test-user", loading: true });
    expect(screen.get("form").attributes("aria-busy")).toBe("true");
    await screen.get("form").trigger("submit");
    expect(screen.emitted("login")).toBeUndefined();
    Object.assign(props, { loading: false });
    await nextTick();
    expect((screen.get(".auth-user-input input").element as HTMLInputElement).value).toBe("auth-test-user");
    await screen.get("form").trigger("submit");
    expect(screen.emitted("login")).toHaveLength(1);
  });

  it("reports identity edits to the host", async () => {
    const { screen } = setup();
    await screen.get(".auth-user-input input").setValue("alice");
    expect(screen.emitted("update:userId")?.[0]).toEqual(["alice"]);
  });

  it("offers no sign-in while the build has nowhere to connect", async () => {
    const { screen, props } = setup({ userId: "auth-test-user", disabled: true });
    expect(screen.get(".auth-login-btn").attributes("disabled")).toBeDefined();
    await screen.get("form").trigger("submit");
    expect(screen.emitted("login")).toBeUndefined();
    Object.assign(props, { disabled: false });
    await nextTick();
    await screen.get("form").trigger("submit");
    expect(screen.emitted("login")).toHaveLength(1);
  });

  it("uses distinct accessible references when multiple screens are mounted", () => {
    const { screens: [first, second] } = setup({}, 2);
    expect(first.get("h1").attributes("id")).not.toBe(second.get("h1").attributes("id"));
    expect(first.get(".auth-user-input input").attributes("aria-describedby"))
      .not.toBe(second.get(".auth-user-input input").attributes("aria-describedby"));
  });
});
