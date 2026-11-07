// @vitest-environment happy-dom
import { mount } from "@vue/test-utils";
import { defineComponent, h, type Component } from "vue";
import { describe, expect, it } from "vitest";
import { useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import ConversationListPanel from "./ConversationListPanel.vue";

function mountPanel(overrides: Record<string, unknown> = {}) {
  const props = {
    items: [
      { id: "pinned", displayName: "Pinned chat", pinned: true },
      { id: "regular", displayName: "Regular chat" },
    ],
    activeId: "regular",
    title: "Messages",
    filterOptions: [
      { value: "all", label: "All" },
      { value: "unread", label: "Unread" },
    ],
    activeFilter: "all",
    searchLabel: "Search conversations",
    closeSearchLabel: "Close search",
    createLabel: "New chat",
    moreLabel: "More actions",
    loadingTitle: "Loading conversations",
    emptyTitle: "No conversations",
    noResultsTitle: "No matches",
    pinnedSectionLabel: "Pinned",
    allSectionLabel: "All conversations",
    ...overrides,
  };
  const host = mount(defineComponent({
    setup() {
      useFlareI18nProvider("en-US");
      return () => h(ConversationListPanel as Component, props);
    },
  }));
  return host.findComponent(ConversationListPanel);
}

describe("ConversationListPanel (reference workbench)", () => {
  it("owns the complete list hierarchy and emits host business events", async () => {
    const wrapper = mountPanel();

    expect(wrapper.find(".flare-filter-tabs--grid").exists()).toBe(true);
    expect(wrapper.findAll(".im-conv-item")).toHaveLength(2);
    expect(wrapper.findAll(".im-conv-list__section").map((node) => node.text())).toEqual([
      "Pinned",
      "All conversations",
    ]);

    await wrapper.get("[aria-label='Search conversations']").trigger("click");
    expect(wrapper.emitted("update:searchOpen")).toEqual([[true]]);

    await wrapper.findAll("[role='tab']")[1].trigger("click");
    expect(wrapper.emitted("filterChange")).toEqual([["unread"]]);

    await wrapper.findAll(".im-conv-item__select")[1].trigger("click");
    expect(wrapper.emitted("select")).toEqual([["regular"]]);
  });

  it("puts the red dot on the More button only when asked", () => {
    expect(mountPanel().find(".flare-icon-button__dot").exists()).toBe(false);

    const more = mountPanel({ moreDot: true }).get("[aria-label='More actions, New']");
    expect(more.find(".flare-icon-button__dot").exists()).toBe(true);
  });

  it("uses the shared empty state for search results", () => {
    const wrapper = mountPanel({ items: [], searchQuery: "missing" });
    expect(wrapper.find(".flare-empty").text()).toContain("No matches");
    expect(wrapper.find(".flare-empty__act").exists()).toBe(false);
  });
});
