import { afterEach, describe, expect, it, vi } from "vitest";
import { defineComponent, h, nextTick, ref } from "vue";
import { mount } from "@vue/test-utils";
import type { FlarePluginMember } from "@flare-im/vue-ui";
import { usePluginMemberSearch } from "../src/memberSearch";

const mounted: Array<{ unmount(): void }> = [];
afterEach(() => { mounted.splice(0).forEach(wrapper => wrapper.unmount()); vi.useRealTimers(); });
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>(yes => { resolve = yes; });
  return { promise, resolve };
}
function host(load: (query: string) => Promise<readonly FlarePluginMember[]>) {
  const identity = ref("viewer-a/chat-a");
  let state!: ReturnType<typeof usePluginMemberSearch>;
  mounted.push(mount(defineComponent({ setup() {
    state = usePluginMemberSearch({ identity: () => identity.value, load, failure: () => "Members failed" });
    return () => h("div");
  } })));
  return { state, identity };
}
async function settle() { await Promise.resolve(); await nextTick(); }

describe("member query ownership", () => {
  it("debounces search and makes old choices unselectable immediately", async () => {
    vi.useFakeTimers();
    const load = vi.fn(async () => [{ userId: "admin", name: "Admin" }]);
    const { state } = host(load);
    state.onMemberSearch(""); vi.advanceTimersByTime(200); await settle();
    expect(state.members.value).toHaveLength(1);
    state.onMemberSearch("a"); state.onMemberSearch("al");
    expect(state.membersLoading.value).toBe(true); expect(state.members.value).toEqual([]);
    vi.advanceTimersByTime(199); expect(load).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(1); await settle();
    expect(load).toHaveBeenLastCalledWith("al");
    expect(state.membersRevision.value).toBe(0);
  });
  it("ignores a slow old search after the newer query completes", async () => {
    vi.useFakeTimers();
    const old = deferred<FlarePluginMember[]>();
    const { state } = host(query => query === "old" ? old.promise : Promise.resolve([{ userId: "owner", name: "Owner" }]));
    state.onMemberSearch("old"); vi.advanceTimersByTime(200);
    state.onMemberSearch("new"); vi.advanceTimersByTime(200); await settle();
    old.resolve([{ userId: "hidden", name: "Old hidden person" }]); await settle();
    expect(state.members.value.map(member => member.userId)).toEqual(["owner"]);
    expect(state.membersLoading.value).toBe(false);
  });
  it("an authoritative revision drops old candidates and rechecks the current query", async () => {
    vi.useFakeTimers();
    const old = deferred<FlarePluginMember[]>();
    const load = vi.fn().mockReturnValueOnce(old.promise).mockResolvedValue([{ userId: "admin", name: "Admin" }]);
    const { state } = host(load);
    state.onMemberSearch("manager"); vi.advanceTimersByTime(200);
    state.invalidate(); expect(state.membersRevision.value).toBe(1); expect(state.members.value).toEqual([]);
    vi.advanceTimersByTime(200); await settle();
    old.resolve([{ userId: "demoted", name: "Former manager" }]); await settle();
    expect(state.members.value.map(member => member.userId)).toEqual(["admin"]);
    expect(load).toHaveBeenLastCalledWith("manager");
  });
  it("a route or account change cannot restore a prior account's response", async () => {
    vi.useFakeTimers();
    const old = deferred<FlarePluginMember[]>();
    const load = vi.fn(() => old.promise);
    const { state, identity } = host(load);
    state.onMemberSearch(""); vi.advanceTimersByTime(200);
    identity.value = "viewer-b/chat-b";
    old.resolve([{ userId: "other-account-person", name: "Private" }]); await settle();
    expect(state.members.value).toEqual([]); expect(state.membersLoading.value).toBe(false);
    expect(load).toHaveBeenCalledOnce();
  });
  it("a failed read shows bounded copy and retries the same query", async () => {
    vi.useFakeTimers();
    const load = vi.fn().mockRejectedValueOnce(new Error("private upstream detail"))
      .mockResolvedValueOnce([{ userId: "owner", name: "Owner" }]);
    const { state } = host(load);
    state.onMemberSearch("owner"); vi.advanceTimersByTime(200); await settle();
    expect(state.membersError.value).toBe("Members failed"); expect(state.members.value).toEqual([]);
    state.onMembersRetry(); expect(state.membersError.value).toBeUndefined();
    vi.advanceTimersByTime(200); await settle();
    expect(load.mock.calls.map(call => call[0])).toEqual(["owner", "owner"]);
    expect(state.members.value).toHaveLength(1);
  });
});
