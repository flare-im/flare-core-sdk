/**
 * The host of the network and line diagnostics page: it reads `access.*`, hands the results to the kit's
 * FlareAccessDiagnostics and carries out what the kit reports. What the page says, which line can be pinned and how a
 * rejected recovery link reads are the kit's; here are only the reads, the calls and the outcomes filled back in.
 *
 * A recovery link is pasted into the kit's field, or arrives from the system on a desktop shell that registers
 * `flare-recover://`: `pendingRecoveryLink` holds it until this page takes it.
 */
import { ref, shallowRef } from "vue";
import type { FlareImClient } from "@flare-im/sdk/api";
import type { AccessPointInfo, AccessRecoveryImport, AccessStatus } from "@flare-im/sdk/model";

/** A recovery link the system delivered, waiting for the diagnostics page to import it. */
export const pendingRecoveryLink = ref<string | null>(null);

export interface AccessDiagnosticsHost {
  client: Pick<FlareImClient, "access" | "events">;
  /** A pin the core refused: the line left the directory while the page was open. */
  onPinFailed: () => void;
  writeClipboard?: (text: string) => Promise<void>;
}

export function createAccessDiagnostics({
  client,
  onPinFailed,
  writeClipboard = (text) => navigator.clipboard.writeText(text),
}: AccessDiagnosticsHost) {
  const status = shallowRef<AccessStatus | null>(null);
  const accessPoints = shallowRef<AccessPointInfo[]>([]);
  const refreshing = ref(false);
  const refreshOutcome = ref<string | null>(null);
  const importing = ref(false);
  const importResult = shallowRef<Pick<AccessRecoveryImport, "outcome" | "code"> | null>(null);
  const exporting = ref(false);
  const exportOutcome = ref<"copied" | "failed" | null>(null);

  /** Bumped by every read: a slower read that started earlier must not put an older directory back. */
  let reads = 0;
  async function reload(): Promise<void> {
    const read = ++reads;
    try {
      const [nextStatus, nextPoints] = await Promise.all([client.access.getStatus(), client.access.listAccessPoints()]);
      if (read !== reads) return;
      status.value = nextStatus;
      accessPoints.value = [...nextPoints];
    } catch (error) {
      console.warn("[access] reading the access directory failed", error);
    }
  }

  async function pin(accessPointId: string): Promise<void> {
    try {
      await client.access.pin({ accessPointId });
    } catch (error) {
      console.warn("[access] pinning an access point failed", error);
      onPinFailed();
    }
    await reload();
  }

  async function unpin(): Promise<void> {
    try {
      await client.access.unpin();
    } catch (error) {
      console.warn("[access] unpinning failed", error);
    }
    await reload();
  }

  async function refresh(): Promise<void> {
    refreshing.value = true;
    refreshOutcome.value = null;
    try {
      refreshOutcome.value = (await client.access.refresh()).outcome;
    } catch (error) {
      console.warn("[access] refreshing the access manifest failed", error);
      refreshOutcome.value = "failed";
    } finally {
      refreshing.value = false;
    }
    await reload();
  }

  /** A bad link comes back as `rejected` with its code; only a configuration problem throws. */
  async function importRecovery(link: string): Promise<void> {
    importing.value = true;
    importResult.value = null;
    try {
      importResult.value = await client.access.importRecovery({ link });
    } catch (error) {
      console.warn("[access] importing a recovery link failed", error);
      importResult.value = { outcome: "rejected" };
    } finally {
      importing.value = false;
    }
    await reload();
  }

  async function exportDiagnostics(): Promise<void> {
    exporting.value = true;
    exportOutcome.value = null;
    try {
      const diagnostics = await client.access.exportDiagnostics();
      await writeClipboard(JSON.stringify(diagnostics, null, 2));
      exportOutcome.value = "copied";
    } catch (error) {
      console.warn("[access] copying the diagnostics failed", error);
      exportOutcome.value = "failed";
    } finally {
      exporting.value = false;
    }
  }

  /** Reads now and again on every link event; the returned function stops following. */
  function follow(): () => void {
    void reload();
    const onLinkEvent = () => void reload();
    const subscription = client.events.addEventListener({
      onAccessChanged: onLinkEvent,
      onAccessSwitched: onLinkEvent,
      onConnectionStatusChanged: onLinkEvent,
    });
    return () => subscription.unsubscribe();
  }

  return {
    status,
    accessPoints,
    refreshing,
    refreshOutcome,
    importing,
    importResult,
    exporting,
    exportOutcome,
    pin,
    unpin,
    refresh,
    importRecovery,
    exportDiagnostics,
    follow,
  };
}
