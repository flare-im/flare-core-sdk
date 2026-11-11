import {
  WebFlareImClient,
  WebProductionBridge,
  wrapWebHostBridge,
  type WasmRuntimeLoader,
} from "@flare-im/sdk/web";

/** A UI-free public SDK consumer. The host owns loading its WASM asset. */
export async function inspectWebSdk(loadRuntime: WasmRuntimeLoader) {
  const client = new WebFlareImClient(wrapWebHostBridge(new WebProductionBridge({ loadRuntime })));
  try {
    return {
      sdk: await client.diagnostics.getSdkVersion(),
      contract: await client.diagnostics.getFfiContractVersion(),
    };
  } finally {
    await client.dispose();
  }
}
