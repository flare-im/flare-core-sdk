import { onBeforeUnmount, ref, shallowRef, watch } from "vue";
import type { FlarePluginMember } from "@flare-im/vue-ui";

/** Host-owned, read-only member choices. The supplied query must already enforce visibility. */
export function usePluginMemberSearch(options: {
  identity: () => unknown;
  load: (query: string) => Promise<readonly FlarePluginMember[]>;
  failure: () => string;
}) {
  const members = shallowRef<FlarePluginMember[]>([]);
  const membersLoading = ref(false);
  const membersError = ref<string>();
  const membersRevision = ref(0);
  let ticket = 0;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let disposed = false;
  let requested = false;
  let query = "";

  function cancel(): void {
    ++ticket;
    if (timer !== undefined) clearTimeout(timer);
    timer = undefined;
    members.value = [];
    membersLoading.value = false;
    membersError.value = undefined;
  }
  function search(value: string): void {
    if (disposed) return;
    cancel();
    requested = true;
    query = value.trim();
    const mine = ticket;
    membersLoading.value = true;
    timer = setTimeout(async () => {
      timer = undefined;
      try {
        const rows = await options.load(query);
        if (!disposed && mine === ticket) members.value = [...rows];
      } catch {
        if (!disposed && mine === ticket) membersError.value = options.failure();
      } finally {
        if (!disposed && mine === ticket) membersLoading.value = false;
      }
    }, 200);
  }
  /** An authoritative roster/policy change invalidates choices, including an old in-flight page. */
  function invalidate(): void {
    ++membersRevision.value;
    if (requested) search(query);
    else cancel();
  }
  watch(options.identity, () => {
    cancel();
    requested = false;
    query = "";
    ++membersRevision.value;
  }, { flush: "sync" });
  onBeforeUnmount(() => { disposed = true; cancel(); });
  return {
    members, membersLoading, membersError, membersRevision,
    onMemberSearch: search,
    onMembersRetry: () => search(query),
    invalidate,
  };
}
