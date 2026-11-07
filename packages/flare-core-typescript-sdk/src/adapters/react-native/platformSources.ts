import {
  registerPlatformLifecycleSources,
  type AppStateSource,
  type PlatformLifecycleSources,
} from "../../lifecycle/platformLifecycle";
import { AppState } from "../../model/app_state";

/**
 * React Native sources for the platform lifecycle, registered when this adapter loads.
 *
 * Foreground and background come from react-native's `AppState`. React Native has no network
 * reachability API of its own and this package does not depend on `@react-native-community/netinfo`,
 * so no network changes are reported here: the core still notices a dead link through its
 * heartbeat. `react-native` is looked up at run time, never imported, so no other runtime's
 * bundle pulls it in.
 */

/** The part of react-native's `AppState` module it uses. */
export interface ReactNativeAppStateModule {
  readonly currentState?: string | null;
  addEventListener(type: "change", listener: (state: string) => void): { remove(): void } | undefined;
}

/** `active` is foreground, `background` is background; transitional states report nothing. */
function appStateOf(state: string | null | undefined): AppState | undefined {
  switch (state) {
    case "active":
      return AppState.Foreground;
    case "background":
      return AppState.Background;
    default:
      return undefined;
  }
}

/** react-native's `AppState`, when this runs under React Native. */
export function loadReactNativeAppState(): ReactNativeAppStateModule | null {
  try {
    // A literal `require("react-native")` so Metro resolves it; other bundlers never load this file.
    const reactNative = typeof require === "function"
      ? require("react-native") as { AppState?: ReactNativeAppStateModule }
      : undefined;
    const appState = reactNative?.AppState;
    return appState && typeof appState.addEventListener === "function" ? appState : null;
  } catch {
    return null;
  }
}

export function reactNativeLifecycleSources(
  appState: ReactNativeAppStateModule | null = loadReactNativeAppState(),
): PlatformLifecycleSources {
  if (!appState) return {};
  const source: AppStateSource = {
    current: () => appStateOf(appState.currentState),
    subscribe(listener) {
      const subscription = appState.addEventListener("change", (state) => {
        const mapped = appStateOf(state);
        if (mapped !== undefined) listener(mapped);
      });
      return () => subscription?.remove();
    },
  };
  return { appState: source };
}

registerPlatformLifecycleSources(() => reactNativeLifecycleSources());
