// Exercises the actual browser WASM + IndexedDB-host wrapper using isolated fixtures.
// Optional argument: deployed site URL. No test data is sent to the server.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { createRequire } from "node:module";

const require = createRequire(new URL("../../flare-core-examples/apps/flare-core-web-app/package.json", import.meta.url));
const { chromium } = require("@playwright/test");
const pkg = new URL("../../flare-core-sdk-engine/bindings/wasm/pkg/", import.meta.url);
let server;
let base = process.argv[2];
if (!base) {
  server = createServer(async (req, res) => {
    const name = req.url?.split("/").pop();
    if (!["flare_im_core_sdk.js", "flare_im_core_sdk_bg.wasm"].includes(name)) {
      res.end("<!doctype html><title>Search regression</title>"); return;
    }
    try {
      res.setHeader("Content-Type", name.endsWith(".wasm") ? "application/wasm" : "text/javascript");
      res.end(await readFile(new URL(name, pkg)));
    } catch (error) { res.statusCode = 500; res.end(String(error)); }
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  base = `http://127.0.0.1:${server.address().port}`;
}
let browser;
try {
  browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(base, { waitUntil: "domcontentloaded" });
  const matrix = await Promise.race([
    page.evaluate(async () => {
      const mod = await import("/flare-core-wasm/flare_im_core_sdk.js");
      await mod.default();
      const content = {
        text: { contentType: "text", text: "111", mentions: [] },
        mention: { contentType: "text", text: "@11111 111", mentions: [] },
        file: { contentType: "file", fileId: "file-11", fileName: "photo_11.jpg", mimeType: "image/jpeg", fileSize: 12, url: "", description: "" },
        image: { contentType: "image", source: null, thumbnail: null, description: "11" },
        imageGroup: { contentType: "image_group", images: [], description: "11", metadata: {} },
        video: { contentType: "video", videoId: "11", source: null, cover: null, description: "11" },
        audio: { contentType: "audio", audioId: "11", source: null, description: "11" },
      };
      const types = { text: 1, mention: 1, image: 2, video: 3, audio: 4, file: 5, imageGroup: 16 };
      const rows = Object.entries(content).map(([id, value], index) => ({
        serverId: id, clientMsgId: `client-${id}`, conversationId: "search-fixture", conversationType: 2,
        channelId: "search-fixture", senderId: "alice", source: 0, conversationSeq: 100 - index,
        createdAt: 1000 - index, clientCreatedAt: 1000 - index, messageType: types[id], content: value,
        senderName: "alice", senderAvatar: "", senderDisplayName: "alice", status: 2,
        isRead: false, isRecalled: false, isEdited: false, mentionUsers: [], mentionAll: false,
        attributes: {}, version: 1, updatedAt: 1000 - index,
      }));
      const file = rows.find(m => m.serverId === "file");
      rows.push({ ...file, serverId: "recalled", clientMsgId: "recalled", isRecalled: true });
      rows.push({ ...file, serverId: "foreign", clientMsgId: "foreign", conversationId: "other" });
      rows.push({ ...file, serverId: "sender", clientMsgId: "sender", senderId: "bob", createdAt: 2000 });
      const runtime = mod.createWasmRuntime();
      let loads = 0;
      runtime.setStorageHost(async () => { loads++; return JSON.stringify({ messages: rows }); },
        ...Array.from({ length: 7 }, () => async () => {}));
      const invoke = (op, request) => runtime.invoke(op, JSON.stringify(request));
      await invoke("sdk.init", { sdkConfig: { dataUrl: "file:///search-fixture" } });
      await invoke("sdk.prepare", { userId: "search-fixture-user" });
      const results = { loads };
      const query = { conversationId: "search-fixture", keyword: "11", kinds: [], limit: 50, includeRecalled: false };
      for (const op of ["message.search", "message.search_in_conversation", "message.search_by_query"]) {
        for (const kind of ["message", "text", "media", "image", "video", "audio", "file"]) {
          const response = await invoke(op, { ...query, kinds: [kind] });
          results[`${op}:${kind}`] = response.messages.map(m => m.serverId).sort();
        }
      }
      for (const [label, patch] of Object.entries({
        combined: { kinds: ["file"], senderId: "alice", fromTime: 990, toTime: 1000, limit: 1 },
        recalled: { kinds: ["file"], senderId: "alice", includeRecalled: true },
        filename: { kinds: ["file"], keyword: "PHOTO_11.JPG", senderId: "alice" },
        globalMissing: { conversationId: null, keyword: "definitely-absent" },
        typeOnly: { kinds: ["image"], keyword: "" },
      })) {
        const response = await invoke("message.search_by_query", { ...query, ...patch });
        results[label] = response.messages.map(m => m.serverId).sort();
      }
      await runtime.dispose();
      return results;
    }),
    new Promise((_, reject) => setTimeout(() => reject(new Error("Search regression exceeded 45s")), 45000).unref()),
  ]);
  assert.equal(matrix.loads, 1, "IndexedDB host fixture must actually load");
  const expected = {
    message: ["audio", "file", "image", "imageGroup", "mention", "sender", "text", "video"],
    text: ["mention", "text"], media: ["audio", "file", "image", "imageGroup", "sender", "video"],
    image: ["image", "imageGroup"], video: ["video"], audio: ["audio"], file: ["file", "sender"],
  };
  for (const op of ["message.search", "message.search_in_conversation", "message.search_by_query"])
    for (const [kind, ids] of Object.entries(expected)) assert.deepEqual(matrix[`${op}:${kind}`], ids, `${op}:${kind}`);
  assert.deepEqual(matrix.combined, ["file"]);
  assert.deepEqual(matrix.recalled, ["file", "recalled"]);
  assert.deepEqual(matrix.filename, ["file"]);
  assert.deepEqual(matrix.globalMissing, []);
  assert.deepEqual(matrix.typeOnly, ["image", "imageGroup"]);
  console.log(`PASS ${base}: 21 route/type combinations + 5 compound queries; IndexedDB host used`);
} finally {
  await browser?.close();
  if (server) await new Promise(resolve => server.close(resolve));
}
