import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import type { FlareWasmRuntime } from "../../../bridge/wasmNativeBridge";

const WASM_DIR = path.resolve(
  fileURLToPath(new URL(".", import.meta.url)),
  "../../../../../../../flare-core-sdk-engine/bindings/wasm/pkg",
);

/**
 * wasm 产物来自同级仓库 flare-im-core-sdk 的 `wasm-pack build`，不在本仓内。
 * 单仓 checkout（CI 默认）里它必然缺失，此时依赖它的用例应当跳过而非失败——
 * 否则「环境缺件」会被误报成「集成回归」。
 */
export function wasmPkgAvailable(): boolean {
  return (
    fs.existsSync(path.join(WASM_DIR, "flare_im_core_sdk.js")) &&
    fs.existsSync(path.join(WASM_DIR, "flare_im_core_sdk_bg.wasm"))
  );
}

export async function loadWasmRuntimeForTests(): Promise<FlareWasmRuntime> {
  const jsPath = path.join(WASM_DIR, "flare_im_core_sdk.js");
  const wasmPath = path.join(WASM_DIR, "flare_im_core_sdk_bg.wasm");
  if (!fs.existsSync(jsPath) || !fs.existsSync(wasmPath)) {
    throw new Error(`wasm pkg missing under ${WASM_DIR}; run wasm-pack build in bindings/wasm`);
  }

  const mod = (await import(/* @vite-ignore */ jsPath)) as {
    default: (input?: unknown) => Promise<unknown>;
    initSync?: (input: Uint8Array) => void;
    createWasmRuntime: () => Omit<FlareWasmRuntime, "flareBindingContractVersion">;
    flareBindingContractVersion: () => string;
  };

  const wasmBytes = fs.readFileSync(wasmPath);
  if (typeof mod.initSync === "function") {
    mod.initSync({ module: wasmBytes } as { module: Uint8Array });
  } else {
    await mod.default(wasmBytes);
  }
  const runtime = mod.createWasmRuntime();
  // wasm-bindgen methods live on the class prototype: bind the host hooks explicitly.
  const hooks = runtime as unknown as Record<string, unknown>;
  const bindHook = (name: string) =>
    typeof hooks[name] === "function"
      ? { [name]: (hooks[name] as (...args: unknown[]) => unknown).bind(runtime) }
      : {};
  return {
    ...runtime,
    invoke: runtime.invoke.bind(runtime),
    ...(runtime.dispose ? { dispose: runtime.dispose.bind(runtime) } : {}),
    ...bindHook("setAccessStoreHost"),
    ...bindHook("setConnectTokenRefresher"),
    flareBindingContractVersion: mod.flareBindingContractVersion,
  };
}

export function wasmPkgDir(): string {
  return WASM_DIR;
}
