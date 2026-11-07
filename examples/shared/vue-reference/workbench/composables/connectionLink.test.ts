import { describe, expect, it } from "vitest";
import { ref, shallowRef } from "vue";
import type { ConnectionStatus, FlareImClient } from "@flare-im/sdk/web";
import { bindFlareSessionEvents, type RuntimeEventLogItem } from "./useFlareSessionBridge";

function bridge() {
  let emit: (payload: unknown) => void = () => {};
  const appClient = {
    events: {
      addEventListener(listener: (payload: unknown) => void) {
        emit = listener;
        return { unsubscribe() {} };
      },
    },
  } as unknown as FlareImClient;
  const connectionStatus = shallowRef<ConnectionStatus | null>(null);
  const loggedIn = ref(true);
  const events = ref<RuntimeEventLogItem[]>([]);
  bindFlareSessionEvents({ appClient, events, connectionStatus, loggedIn });
  return { emit: (payload: unknown) => emit(payload), connectionStatus, loggedIn, events };
}

describe("the reference app's connection signal", () => {
  it("replaces the held status whole with every connection://status, without the routing keys", () => {
    const { emit, connectionStatus } = bridge();
    emit({ type: "connection", event: "status", phase: "reconnecting", attempt: 2, nextRetryAt: 1762250000000, developmentMode: true });
    expect(connectionStatus.value).toEqual({ phase: "reconnecting", attempt: 2, nextRetryAt: 1762250000000, developmentMode: true });
    emit({ type: "connection", event: "status", phase: "online", quality: "good", attempt: 0, developmentMode: true });
    expect(connectionStatus.value).toEqual({ phase: "online", quality: "good", attempt: 0, developmentMode: true });
  });

  it("keeps the session on actionRequired: the kit's notice offers the way out", () => {
    const { emit, connectionStatus, loggedIn } = bridge();
    emit({ type: "connection", event: "status", phase: "actionRequired", reason: "kicked", attempt: 0, developmentMode: false });
    expect(connectionStatus.value?.reason).toBe("kicked");
    expect(loggedIn.value).toBe(true);
  });

  it("logs access switches and manifest changes without touching the status", () => {
    const { emit, connectionStatus, events } = bridge();
    emit({ type: "access", event: "switched", from: { ap: "development", protocol: "ws" }, to: { ap: "dev-b", protocol: "ws" }, reason: "failure" });
    emit({ type: "access", event: "changed", serial: 3, source: "development", stale: false, developmentMode: true, changes: { accessPointsAdded: [], accessPointsRemoved: [], policyChanged: false } });
    expect(connectionStatus.value).toBeNull();
    expect(events.value.map((item) => item.label)).toEqual(["access_changed", "access_switched"]);
    expect(events.value[1].detail).toBe("development → dev-b (failure)");
  });

  it("ignores the removed connection events", () => {
    const { emit, connectionStatus, loggedIn } = bridge();
    for (const name of ["connected", "disconnected", "reconnecting", "kicked_off", "token_expired"]) {
      emit({ type: "connection", name, state: name });
    }
    expect(connectionStatus.value).toBeNull();
    expect(loggedIn.value).toBe(true);
  });
});
