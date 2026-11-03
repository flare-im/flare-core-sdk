// Real browser regression against the core-owned, compiled WASM package.
// Run after `cargo xtask build wasm`: node scripts/check-wasm-session-recovery.mjs
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { createRequire } from "node:module";

const require = createRequire(new URL("../examples/flare-core-web-app/package.json", import.meta.url));
const { chromium } = require("@playwright/test");
const pkg = new URL("../../flare-core-sdk-engine/bindings/wasm/pkg/", import.meta.url);
const server = createServer(async (req, res) => {
  const filename = req.url === "/runtime.js" ? "flare_im_core_sdk.js"
    : req.url === "/flare_im_core_sdk_bg.wasm" ? "flare_im_core_sdk_bg.wasm" : null;
  if (!filename) { res.end("<!doctype html><title>WASM recovery regression</title>"); return; }
  try {
    res.setHeader("Content-Type", filename.endsWith(".wasm") ? "application/wasm" : "text/javascript");
    res.end(await readFile(new URL(filename, pkg)));
  } catch (error) { res.statusCode = 500; res.end(String(error)); }
});
await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
let browser;
try {
  browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  const result = await Promise.race([
    page.evaluate(async () => {
      const mod = await import("/runtime.js");
      await mod.default();
      const a = mod.createWasmRuntime();
      const b = mod.createWasmRuntime();
      const invoke = (r, op, request = {}) => r.invoke(op, JSON.stringify(request));
      const search = r => invoke(r, "message.search_in_conversation", {
        conversationId: "c1", keyword: "hello", limit: 10,
      });
      for (const [runtime, userId] of [[a, "alice"], [b, "bob"]]) {
        await invoke(runtime, "sdk.init", { sdkConfig: { dataUrl: "file:///wasm-recovery-test" } });
        await invoke(runtime, "sdk.prepare", { userId });
      }
      const active = await invoke(a, "sdk.session_active");
      const offlineSearch = await search(a);
      // Registration is synchronous: cancel before the driver polls this query.
      const pending = search(a).then(() => null, error => String(error));
      const cancelled = a.cancelPendingInvocations();
      const cancellationError = await pending;
      const recoveredSearch = await search(a);
      await a.dispose();
      const otherActive = await invoke(b, "sdk.session_active");
      const otherSearch = await search(b);
      await invoke(b, "sdk.logout");
      const loggedOut = await invoke(b, "sdk.session_active");
      const afterLogout = await search(b).then(() => null, error => String(error));
      await b.dispose();
      return { active, offlineSearch, cancelled, cancellationError, recoveredSearch,
        otherActive, otherSearch, loggedOut, afterLogout };
    }),
    new Promise((_, reject) => setTimeout(() => reject(new Error("WASM regression exceeded 30s")), 30_000).unref()),
  ]);
  assert.equal(result.active, true);
  assert.deepEqual(result.offlineSearch, { messages: [] });
  assert.equal(result.cancelled, true);
  assert.match(result.cancellationError, /wasm.operation_cancelled/);
  assert.deepEqual(result.recoveredSearch, { messages: [] });
  assert.equal(result.otherActive, true);
  assert.deepEqual(result.otherSearch, { messages: [] });
  assert.equal(result.loggedOut, false);
  assert.match(result.afterLogout, /NOT_CONNECTED/);
  console.log("WASM browser regression passed: offline search, cancellation, instance isolation, logout");
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
