import type { NativeBridge, NativeCallDescriptor } from "../../../contract/bridge_contract";

export type RecordedInvoke = {
  operation: string;
  request?: unknown;
};

/** Deterministic bridge for app/session orchestration tests. */
export class LoginFlowMockBridge implements NativeBridge {
  readonly calls: RecordedInvoke[] = [];
  private currentUserId = "alice";

  constructor(
    private readonly handlers: Partial<
      Record<string, (request?: unknown) => unknown | Promise<unknown>>
    > = {},
  ) {}

  async invoke<T>(descriptor: NativeCallDescriptor, request?: unknown): Promise<T> {
    this.calls.push({ operation: descriptor.operation, request });
    if (descriptor.operation === "sdk.login") {
      const login = (request ?? {}) as Record<string, unknown>;
      if (typeof login.userId === "string" && login.userId.trim()) {
        this.currentUserId = login.userId.trim();
      }
    }
    const handler = this.handlers[descriptor.operation];
    if (handler) {
      return (await handler(request)) as T;
    }
    return this.defaultLoginFlowResponse(descriptor.operation) as T;
  }

  private defaultLoginFlowResponse(operation: string): unknown {
    switch (operation) {
      case "sdk.create":
        return { handle: 1 };
      case "sdk.init":
      case "sdk.login":
      case "sdk.logout":
      case "sdk.uninit":
      case "sdk.dispose":
        return undefined;
      case "event.subscribe":
        return { id: 1 };
      case "connection.get_status":
        return {
          phase: "online",
          quality: "good",
          accessPointId: "development",
          cellId: null,
          regionId: null,
          protocol: "ws",
          rttMs: 12,
          attempt: 0,
          nextRetryAt: null,
          reason: null,
          developmentMode: true,
        };
      case "sdk.current_user_id":
        return { userId: this.currentUserId };
      case "sdk.session_active":
        return true;
      case "sdk.is_connected":
        return true;
      case "diagnostics.sdk_version":
        return { version: "test-sdk" };
      case "diagnostics.ffi_contract_version":
        return { version: "test-ffi" };
      case "diagnostics.data_root":
        return { path: "memory://" };
      case "message_builder.list_catalog":
        return {
          entries: [{ op: "create_text", label: "Text", stability: "stable" }],
        };
      default:
        return {};
    }
  }
}

export function operations(calls: RecordedInvoke[]): string[] {
  return calls.map((call) => call.operation);
}
