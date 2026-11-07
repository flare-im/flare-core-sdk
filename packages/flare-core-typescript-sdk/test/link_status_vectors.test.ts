import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it, vi } from "vitest";

import {
  DefaultEventsApi,
  connectionStatusFromJson,
  eventTypeForWebChannel,
  nativeEventFromCode,
} from "../src/adapter/module/DefaultEventsApi";
import { FlareSdkException } from "../src/bridge/flareSdkException";
import type { NativeBridge } from "../src/contract/bridge_contract";
import { ConnectionPhase, type ConnectionStatus } from "../src/model";

/**
 * The engine's link status vectors (`flare-core-sdk-engine/tests/vectors/link_status.json`): each case's
 * `expected` is a `connection://status` payload exactly as the core puts it on the wire. Every platform
 * package decodes the same file.
 */
type WireStatus = Record<keyof ConnectionStatus, unknown>;
type Vector = { name: string; expected: WireStatus };

const vectorPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../../../flare-core-sdk-engine/tests/vectors/link_status.json",
);
const vectors = (JSON.parse(fs.readFileSync(vectorPath, "utf8")) as { cases: Vector[] }).cases;

const fields: Array<keyof ConnectionStatus> = [
  "phase", "quality", "accessPointId", "cellId", "regionId", "protocol",
  "rttMs", "attempt", "nextRetryAt", "reason", "developmentMode",
];

/** The decoded status as wire values: the TS model leaves null fields out. */
function asWire(status: ConnectionStatus): WireStatus {
  const record = status as unknown as Record<string, unknown>;
  return Object.fromEntries(fields.map((field) => [field, record[field] ?? null])) as WireStatus;
}

function testBridge(): NativeBridge {
  return { invoke: vi.fn(async () => ({ subscriptionId: "vectors" })) } as unknown as NativeBridge;
}

const statusEventType = eventTypeForWebChannel("connection://status")!;

describe("link status vectors", () => {
  it("covers every public phase", () => {
    expect(vectors.length).toBeGreaterThanOrEqual(22);
    expect(new Set(vectors.map((vector) => vector.expected.phase)))
      .toEqual(new Set(Object.values(ConnectionPhase)));
    for (const vector of vectors) expect(Object.keys(vector.expected).sort()).toEqual([...fields].sort());
  });

  it.each(vectors.map((vector) => [vector.name, vector] as const))("decodes %s", (_name, vector) => {
    const decoded = connectionStatusFromJson(vector.expected);
    expect(asWire(decoded)).toEqual(vector.expected);
    for (const field of fields) {
      if (vector.expected[field] === null) expect(decoded).not.toHaveProperty(field);
    }

    const events = new DefaultEventsApi(testBridge());
    const delivered: ConnectionStatus[] = [];
    events.onConnectionStatusChanged((status) => delivered.push(status));
    events.emitNativeEvent(statusEventType, { type: "connection", event: "status", ...vector.expected });
    expect(delivered.map(asWire)).toEqual([vector.expected]);
  });

  it("rejects a phase it does not know instead of guessing one", () => {
    const unknown = { ...vectors[0].expected, phase: "halfOpen" };

    expect(() => connectionStatusFromJson(unknown)).toThrow(FlareSdkException);
    expect(() => connectionStatusFromJson(unknown)).toThrow("invalid event payload field: phase");
    expect(() => nativeEventFromCode(statusEventType, unknown)).toThrow("invalid event payload field: phase");

    const events = new DefaultEventsApi(testBridge());
    const delivered: ConnectionStatus[] = [];
    events.onConnectionStatusChanged((status) => delivered.push(status));
    expect(() => events.emitNativeEvent(statusEventType, unknown)).toThrow(FlareSdkException);
    expect(delivered).toEqual([]);
  });
});
