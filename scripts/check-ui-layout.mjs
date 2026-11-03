// Real-browser layout regression. Uses an existing account; does not send messages.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
const require = createRequire(new URL("../../flare-core-examples/apps/flare-core-web-app/package.json", import.meta.url));
const { chromium } = require("@playwright/test");
const [site, gateway, userId, outputDir] = process.argv.slice(2);
assert(site && gateway && userId && outputDir, "Provide site, gateway, existing userId, screenshot directory");
await mkdir(outputDir, { recursive: true });
const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1600, height: 1000 }, reducedMotion: "reduce" });
  page.setDefaultTimeout(15000);
  await page.route("**/api/**", async route => {
    const url = new URL(route.request().url());
    if (url.origin === new URL(site).origin) {
      const response = await route.fetch({ url: gateway + url.pathname + url.search });
      await route.fulfill({ response });
    } else await route.continue();
  });
  await page.goto(site);
  await page.getByText("服务器地址", { exact: true }).click();
  await page.locator("input").nth(1).fill(gateway.replace(/^http/, "ws") + "/ws");
  await page.getByPlaceholder("请输入用户 ID").fill(userId);
  await page.getByRole("button", { name: "立即登录", exact: true }).click();
  await page.locator(".im-conv-item__select").first().waitFor({ timeout: 60000 });
  await page.locator(".im-conv-item__select").first().click();
  await page.locator(".message-row").first().waitFor({ timeout: 45000 });
  await page.locator(".im-conv-item").first().click({ button: "right" });
  console.log("opened conversation and context menu");
  const menu = page.locator(".im-conv-dropdown");
  await menu.waitFor();
  await page.waitForFunction(() => {
    const el = document.querySelector(".im-conv-dropdown .n-dropdown-option-body");
    return el && Math.abs(el.getBoundingClientRect().height - 40) < 0.1;
  });
  console.log("menu ready");
  const rows = await page.locator(".im-conv-dropdown .n-dropdown-option-body").evaluateAll(elements => elements.map(el => {
    const body = el.getBoundingClientRect();
    const icon = el.querySelector(".n-dropdown-option-body__prefix").getBoundingClientRect();
    const text = el.querySelector(".n-dropdown-option-body__label").getBoundingClientRect();
    return { label: el.textContent, height: body.height, iconOffset: Math.abs(icon.y + icon.height / 2 - body.y - body.height / 2), textOffset: Math.abs(text.y + text.height / 2 - body.y - body.height / 2) };
  }));
  assert.equal(rows.length, 7);
  for (const row of rows) assert(row.iconOffset < 1 && row.textOffset < 1, JSON.stringify(row));
  await page.screenshot({ path: outputDir + "/desktop-menu.png", animations: "disabled" });
  await page.locator(".im-conv-item__select").first().focus();
  await page.keyboard.press("Escape");
  await menu.waitFor({ state: "hidden" });
  await page.keyboard.press("Shift+F10");
  await menu.waitFor();
  await page.keyboard.press("Escape");
  await menu.waitFor({ state: "hidden" });
  const layouts = [];
  for (const [name, width, height, colorScheme] of [["desktop",1600,1000,"light"],["tablet",1024,768,"light"],["mobile",390,844,"light"],["mobile-dark",390,844,"dark"]]) {
    console.log("checking", name);
    await page.setViewportSize({ width, height });
    await page.emulateMedia({ colorScheme });
    if (colorScheme === "dark") await page.waitForFunction(() => document.documentElement.dataset.flareTheme === "dark");
    await page.screenshot({ path: outputDir + "/" + name + ".png", animations: "disabled" });
    const geometry = await page.evaluate(() => ({ viewport: innerWidth, scroll: document.documentElement.scrollWidth, theme: document.documentElement.dataset.flareTheme }));
    assert(geometry.scroll <= geometry.viewport + 1, name + " horizontal overflow " + JSON.stringify(geometry));
    layouts.push({ name, ...geometry });
  }
  const result = { menu: rows, keyboard: "Shift+F10/Escape pass", layouts };
  await writeFile(outputDir + "/browser-check.json", JSON.stringify(result, null, 2) + "\n");
  console.log(JSON.stringify(result, null, 2));
} finally { await browser.close(); }
