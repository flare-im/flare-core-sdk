// Search UI regression. Supply an existing test account/conversation
// with both text and file messages matching the keyword. Does not send messages.
// node scripts/check-web-search-ui.mjs <site> <userId> <conversationTitle> <keyword>
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../flare-core-examples/apps/flare-core-web-app/package.json", import.meta.url));
const { chromium } = require("@playwright/test");
const [site, userId, conversation, keyword] = process.argv.slice(2);
assert(site && userId && conversation && keyword, "Provide site, userId, conversation title and keyword");
const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  await page.goto(site, { waitUntil: "networkidle" });
  await page.getByPlaceholder("请输入用户 ID").fill(userId);
  await page.getByRole("button", { name: "立即登录", exact: true }).click();
  await page.waitForURL(url => !url.hash.includes("login"), { timeout: 60000 });
  await page.getByText(conversation, { exact: true }).first().click();
  await page.getByTitle("搜索消息", { exact: true }).click();
  await page.getByPlaceholder("搜索聊天记录").fill(keyword);
  await page.locator(".chat-search-panel").getByRole("button", { name: "搜索", exact: true }).click();
  await page.locator(".chat-search-panel__summary").filter({ hasText: /条结果/ }).waitFor({ timeout: 45000 });
  const counts = {};
  for (const kind of ["文本", "文件"]) {
    await page.locator(".chat-search-panel__filters").getByText(kind, { exact: true }).click();
    await page.waitForFunction(expected => {
      const summary = document.querySelector(".chat-search-panel__summary")?.textContent ?? "";
      const labels = [...document.querySelectorAll(".chat-search-result-card__meta span:first-child")];
      return summary.includes("条结果") && labels.length > 0 && labels.every(el => el.textContent === expected);
    }, kind, { timeout: 45000 });
    counts[kind] = await page.locator(".chat-search-result-card").count();
  }
  if (process.env.FLARE_SEARCH_SCREENSHOT) {
    await page.screenshot({ path: process.env.FLARE_SEARCH_SCREENSHOT, fullPage: true });
  }
  console.log("PASS online search UI", JSON.stringify(counts));
} finally { await browser.close(); }
