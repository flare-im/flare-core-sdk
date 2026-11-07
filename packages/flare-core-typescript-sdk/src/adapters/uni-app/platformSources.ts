import {
  browserLifecycleSources,
  registerPlatformLifecycleSources,
  type AppStateSource,
  type NetworkSnapshot,
  type NetworkSource,
  type PlatformLifecycleSources,
} from "../../lifecycle/platformLifecycle";
import { AppState } from "../../model/app_state";
import { NetworkInterfaceKind } from "../../model/network_interface_kind";

/**
 * uni-app sources for the platform lifecycle, registered when this adapter loads.
 *
 * Foreground and background come from `uni.onAppShow` / `uni.onAppHide`, the network from
 * `uni.onNetworkStatusChange` / `uni.getNetworkType` (its `networkType` is the fingerprint hint).
 * Each half falls back to the browser's sources (H5) when the `uni` API for it is missing.
 */

interface UniNetworkStatus {
  isConnected?: boolean;
  networkType?: string;
}

/** The part of the `uni` global it uses; every member is probed before use. */
export interface UniLifecycleApi {
  onAppShow?(listener: () => void): void;
  offAppShow?(listener: () => void): void;
  onAppHide?(listener: () => void): void;
  offAppHide?(listener: () => void): void;
  onNetworkStatusChange?(listener: (status: UniNetworkStatus) => void): void;
  offNetworkStatusChange?(listener: (status: UniNetworkStatus) => void): void;
  getNetworkType?(options: {
    success?: (result: { networkType?: string }) => void;
    fail?: (error: unknown) => void;
  }): void;
}

function interfaceOf(networkType: string | undefined): NetworkInterfaceKind | undefined {
  switch (networkType) {
    case undefined:
    case "":
      return undefined;
    case "wifi":
      return NetworkInterfaceKind.Wifi;
    case "2g":
    case "3g":
    case "4g":
    case "5g":
      return NetworkInterfaceKind.Cellular;
    case "ethernet":
      return NetworkInterfaceKind.Ethernet;
    case "none":
    case "unknown":
      return NetworkInterfaceKind.Unknown;
    default:
      return NetworkInterfaceKind.Other;
  }
}

function snapshotOf(networkType: string | undefined, isConnected?: boolean): NetworkSnapshot {
  const kind = interfaceOf(networkType);
  return {
    available: isConnected ?? networkType !== "none",
    ...(kind !== undefined ? { interface: kind } : {}),
    ...(networkType ? { fingerprintHint: networkType } : {}),
  };
}

function isFunction(value: unknown): value is (...args: never[]) => unknown {
  return typeof value === "function";
}

export function uniLifecycleSources(
  uni: UniLifecycleApi | null | undefined = (globalThis as { uni?: UniLifecycleApi }).uni,
): PlatformLifecycleSources {
  const browser = browserLifecycleSources();
  if (!uni) return browser;

  let appState: AppStateSource | undefined = browser.appState;
  if (isFunction(uni.onAppShow) && isFunction(uni.onAppHide)) {
    let current: AppState | undefined;
    appState = {
      current: () => current,
      subscribe(listener) {
        let active = true;
        const show = () => {
          current = AppState.Foreground;
          if (active) listener(AppState.Foreground);
        };
        const hide = () => {
          current = AppState.Background;
          if (active) listener(AppState.Background);
        };
        uni.onAppShow!(show);
        uni.onAppHide!(hide);
        return () => {
          active = false;
          if (isFunction(uni.offAppShow)) uni.offAppShow(show);
          if (isFunction(uni.offAppHide)) uni.offAppHide(hide);
        };
      },
    };
  }

  let network: NetworkSource | undefined = browser.network;
  if (isFunction(uni.onNetworkStatusChange)) {
    network = {
      current: () => new Promise<NetworkSnapshot | undefined>((resolve) => {
        if (!isFunction(uni.getNetworkType)) {
          resolve(undefined);
          return;
        }
        uni.getNetworkType({
          success: (result) => resolve(snapshotOf(result.networkType)),
          fail: () => resolve(undefined),
        });
      }),
      subscribe(listener) {
        let active = true;
        const changed = (status: UniNetworkStatus) => {
          if (active) listener(snapshotOf(status.networkType, status.isConnected), "network_status_change");
        };
        uni.onNetworkStatusChange!(changed);
        return () => {
          active = false;
          if (isFunction(uni.offNetworkStatusChange)) uni.offNetworkStatusChange(changed);
        };
      },
    };
  }

  return { ...(appState ? { appState } : {}), ...(network ? { network } : {}) };
}

registerPlatformLifecycleSources(() => uniLifecycleSources());
