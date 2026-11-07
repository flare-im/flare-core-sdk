import { beforeEach, describe, expect, it, vi } from 'vitest';

import { NativeCallMap } from '../../contract/bridge_contract';
import { ffiContractVersion } from '../../contract/sdk_contract';

const tauri = vi.hoisted(() => ({
  invoke: vi.fn(),
  listen: vi.fn(),
}));

vi.mock('@tauri-apps/api/core', () => ({
  invoke: tauri.invoke,
}));

vi.mock('@tauri-apps/api/event', () => ({
  listen: tauri.listen,
}));

describe('Tauri TypeScript SDK adapter', () => {
  beforeEach(() => {
    tauri.invoke.mockReset();
    tauri.listen.mockReset();
  });

  it('uses dedicated lifecycle commands and contract invoke JSON for generated SDK APIs', async () => {
    const { TauriNativeBridge } = await import('./index');
    const bridge = new TauriNativeBridge();

    tauri.invoke.mockImplementation(async (command: string) => {
      if (command === 'sdk_ffi_contract_version') {
        return { version: ffiContractVersion };
      }
      if (command === 'sdk_invoke_json') {
        return true;
      }
      return undefined;
    });

    const sdkConfig = {
      access: { trustMode: 'development', developmentEndpoints: { wsUrl: 'ws://127.0.0.1:60051' } },
    };
    await bridge.invoke(NativeCallMap.sdkInit, { environment: 'development', sdkConfig });
    const connected = await bridge.invoke<boolean>(NativeCallMap.sdkIsConnected);

    expect(connected).toBe(true);
    expect(tauri.invoke).toHaveBeenCalledWith('sdk_init', { environment: 'development', sdkConfig });
    expect(tauri.invoke).toHaveBeenCalledWith('sdk_ffi_contract_version');
    expect(tauri.invoke).toHaveBeenCalledWith('sdk_invoke_json', {
      apiId: 'sdk.is_connected',
      requestJson: '{}',
    });
  });

  it('rejects with the structured SDK error the command rejected with', async () => {
    const { TauriNativeBridge } = await import('./index');
    const { FlareSdkException } = await import('../../bridge/flareSdkException');
    const bridge = new TauriNativeBridge();
    tauri.invoke.mockImplementation(async (command: string) => {
      if (command === 'sdk_ffi_contract_version') {
        return { version: ffiContractVersion };
      }
      throw {
        code: 'OPERATION_FAILED',
        reason: 'sdk.plugin.rejected',
        retryable: false,
        httpStatus: 422,
        machineReason: 'CALL_FULL',
        message: '错误 [OPERATION_FAILED] sdk.plugin.rejected',
        operation: 'sdk.is_connected',
      };
    });

    const error = await bridge.invoke(NativeCallMap.sdkIsConnected).catch((e: unknown) => e);

    expect(error).toBeInstanceOf(FlareSdkException);
    expect(error).toMatchObject({
      code: 'OPERATION_FAILED',
      reason: 'sdk.plugin.rejected',
      retryable: false,
      httpStatus: 422,
      machineReason: 'CALL_FULL',
      operation: 'sdk.is_connected',
    });
  });

  it('connects Tauri event channels to DefaultEventsApi when creating the default client', async () => {
    const { FlareCoreSdk } = await import('./index');
    const unlisten = vi.fn();
    let statusPayload: ((event: { payload: unknown }) => void) | undefined;

    tauri.listen.mockImplementation(async (channel: string, handler: (event: { payload: unknown }) => void) => {
      if (channel === 'connection://status') {
        statusPayload = handler;
      }
      return unlisten;
    });
    tauri.invoke.mockImplementation(async (command: string) => {
      if (command === 'sdk_ffi_contract_version') {
        return { version: ffiContractVersion };
      }
      return undefined;
    });

    const client = FlareCoreSdk.createClient();
    const received: unknown[] = [];
    client.events.addEventListener({
      onConnectionStatusChanged(status) {
        received.push(status);
      },
    });

    await client.events.subscribeEventsBatch({});
    statusPayload?.({
      payload: {
        phase: 'actionRequired', quality: null, accessPointId: 'ap-1', cellId: null, regionId: null,
        protocol: 'ws', rttMs: null, attempt: 0, nextRetryAt: null, reason: 'kicked', developmentMode: false,
      },
    });

    expect(received).toEqual([{
      phase: 'actionRequired',
      accessPointId: 'ap-1',
      protocol: 'ws',
      attempt: 0,
      reason: 'kicked',
      developmentMode: false,
    }]);
  });

  it('answers token refresh requests with the one host function', async () => {
    const { FlareCoreSdk, CONNECT_TOKEN_REFRESH_EVENT } = await import('./index');
    let refreshRequested: ((event: { payload: unknown }) => void) | undefined;
    const unlisten = vi.fn();
    tauri.listen.mockImplementation(async (channel: string, handler: (event: { payload: unknown }) => void) => {
      if (channel === CONNECT_TOKEN_REFRESH_EVENT) refreshRequested = handler;
      return unlisten;
    });
    const completed = new Promise<Record<string, unknown>>((resolve) => {
      tauri.invoke.mockImplementation(async (command: string, args?: Record<string, unknown>) => {
        if (command === 'sdk_ffi_contract_version') return { version: ffiContractVersion };
        if (command === 'sdk_complete_connect_token_refresh') {
          resolve(args ?? {});
          return true;
        }
        return undefined;
      });
    });

    const client = FlareCoreSdk.createClient();
    const refresher = vi.fn(async () => 'fresh-token');
    await client.setConnectTokenRefresher(refresher);

    expect(tauri.invoke).toHaveBeenCalledWith('sdk_set_connect_token_refresher', { enabled: true });
    refreshRequested?.({ payload: { requestId: 7 } });
    await expect(completed).resolves.toEqual({ requestId: 7, token: 'fresh-token' });
    expect(refresher).toHaveBeenCalledTimes(1);

    await client.setConnectTokenRefresher(null);
    expect(tauri.invoke).toHaveBeenCalledWith('sdk_set_connect_token_refresher', { enabled: false });
    expect(unlisten).toHaveBeenCalledTimes(1);
  });

  it('answers without a token when the host function has none', async () => {
    const { TauriNativeBridge, CONNECT_TOKEN_REFRESH_EVENT } = await import('./index');
    let refreshRequested: ((event: { payload: unknown }) => void) | undefined;
    tauri.listen.mockImplementation(async (channel: string, handler: (event: { payload: unknown }) => void) => {
      if (channel === CONNECT_TOKEN_REFRESH_EVENT) refreshRequested = handler;
      return vi.fn();
    });
    const completed = new Promise<Record<string, unknown>>((resolve) => {
      tauri.invoke.mockImplementation(async (command: string, args?: Record<string, unknown>) => {
        if (command === 'sdk_ffi_contract_version') return { version: ffiContractVersion };
        if (command === 'sdk_complete_connect_token_refresh') resolve(args ?? {});
        return undefined;
      });
    });

    const bridge = new TauriNativeBridge();
    await bridge.setConnectTokenRefresher(async () => null);
    refreshRequested?.({ payload: { requestId: 8 } });
    await expect(completed).resolves.toEqual({ requestId: 8 });
  });

  it('rejects an overloaded command with the typed error', async () => {
    const { TauriNativeBridge, OverloadedError } = await import('./index');
    const bridge = new TauriNativeBridge();
    tauri.invoke.mockImplementation(async (command: string) => {
      if (command === 'sdk_ffi_contract_version') return { version: ffiContractVersion };
      throw { code: 'OVERLOADED', message: 'shedding load', retryable: true, retryAfterMs: 2500 };
    });

    const error = await bridge.invoke(NativeCallMap.accessGetStatus).catch((e: unknown) => e);

    expect(error).toBeInstanceOf(OverloadedError);
    expect(error).toMatchObject({ code: 'OVERLOADED', retryAfterMs: 2500, operation: 'access.get_status' });
  });
});
