// Sends test messages only with explicit opt-in and two isolated release accounts.
//
// This is the Flare IM Design 2.0 live release gate: a real browser, the real web
// app, the real client SDK and a real server. Nothing is mocked or intercepted.
// Every message it sends carries a per-run id, so a message left over from an
// earlier run can never satisfy an assertion in this one.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(new URL('../../flare-core-examples/apps/flare-core-web-app/package.json', import.meta.url));
const { chromium, expect } = require('@playwright/test');
const { FLARE_LIVE_BASE_URL: site, FLARE_LIVE_USER: user, FLARE_LIVE_PEER: peerUser } = process.env;
assert.equal(process.env.FLARE_ALLOW_LIVE_SEND, '1', 'Live send requires FLARE_ALLOW_LIVE_SEND=1');
assert(site && user && peerUser && user !== peerUser, 'Provide FLARE_LIVE_BASE_URL and two distinct release users');
assert([user, peerUser].every(id => /^ui2-release-[a-z0-9-]+$/.test(id)), 'Use isolated ui2-release-* accounts');
assert(['http:', 'https:'].includes(new URL(site).protocol), 'Use an HTTP(S) app URL');
const output = process.env.FLARE_LIVE_OUTPUT_DIR;
if (output) mkdirSync(output, { recursive: true });

const runId = `release-live-${new Date().toISOString().replace(/[-:.TZ]/g, '')}-${randomUUID().slice(0, 8)}`;
const started = Date.now();
const events = [];
// Timeline only: step names, elapsed milliseconds and non-sensitive detail. No
// token, password or payload beyond the run-scoped test strings.
const mark = (step, detail = {}) => events.push({ step, tMs: Date.now() - started, ...detail });
const counts = { send: 0, receive: 0, ack: 0, read: 0 };
const latency = { ackMs: [], receiveMs: [], readMs: [] };

const browser = await chromium.launch();
const errors = [];
let wasmBuild = null;
try {
  async function login(id, viewport, label) {
    const context = await browser.newContext({ viewport });
    const page = await context.newPage();
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (message.text().startsWith('[flare-web] conversation_operation_')) console.log(message.text());
    });
    page.on('request', request => {
      const match = /flare_im_core_sdk_bg\.wasm\?v=([0-9a-f]+)/.exec(request.url());
      if (match) wasmBuild = match[1];
    });
    await page.goto(new URL('/#/login', site).href);
    await page.locator('.auth-user-input input').fill(id);
    await page.getByRole('button', { name: '立即登录', exact: true }).click();
    await page.waitForURL(/#\/(chat|conversations)/, { timeout: 45000 });
    mark('login', { client: label });
    return page;
  }

  // The sender's view of one outgoing message: its row, the id the UI holds for
  // it, and the lifecycle state MessageStatus renders (`message-status--<state>`).
  const ownRow = (page, text) => page.locator('.message-row--self').filter({ hasText: text }).filter({ visible: true }).last();
  const statusOf = async (row) => (await row.locator('.message-status').first().getAttribute('class')) ?? '';

  /** Sends one text and waits for the server ACK to land in the UI: the row must
   *  leave `sending`/`pending`, must not be failed, and must carry an id. A UI
   *  that showed "sent" while the server had failed would stall or fail here. */
  async function sendAndAck(page, placeholder, text) {
    const sentAt = Date.now();
    await page.getByPlaceholder(placeholder).fill(text);
    await page.getByRole('button', { name: '发送', exact: true }).click();
    counts.send += 1;
    mark('send', { text });
    const row = ownRow(page, text);
    await row.waitFor({ timeout: 30000 });
    await expect.poll(async () => {
      const cls = await statusOf(row);
      return /--(sent|delivered|read)\b/.test(cls) ? 'acked' : cls;
    }, { timeout: 30000, message: `no ACK reached the UI for "${text}"` }).toBe('acked');
    await expect(row, `"${text}" is marked failed after ACK`).not.toHaveClass(/message-row--failed/);
    const id = await row.getAttribute('data-message-id');
    assert(id && id.trim(), `"${text}" has no message id after ACK`);
    counts.ack += 1;
    latency.ackMs.push(Date.now() - sentAt);
    mark('ack', { text, messageId: id });
    return { id, sentAt };
  }

  async function received(page, text, sentAt) {
    await page.getByText(text, { exact: true }).filter({ visible: true }).first().waitFor({ timeout: 45000 });
    counts.receive += 1;
    latency.receiveMs.push(Date.now() - sentAt);
    mark('receive', { text });
  }

  const peer = await login(peerUser, { width: 390, height: 844 }, 'mobile');
  const desktop = await login(user, { width: 1440, height: 900 }, 'desktop');
  await desktop.getByRole('button', { name: '新建会话', exact: true }).first().click();
  await desktop.getByPlaceholder('输入一个真实用户 ID').fill(peerUser);
  // The dialog's confirm button is localized like everything else on this screen
  // (`startConversation.open` → 「打开会话」). The old English 'Open' selector predated
  // the P0-4 merge of FlareStartConversationSheet into FlareStartConversationDialog
  // and never matched; scope it to the dialog so the page's other buttons cannot.
  await desktop.getByRole('dialog').getByRole('button', { name: '打开会话', exact: true }).click();
  await desktop.waitForURL(/#\/chat/, { timeout: 30000 });
  await desktop.getByRole('dialog').waitFor({ state: 'hidden', timeout: 30000 });
  mark('conversation-open', { client: 'desktop' });

  const outbound = `UI 2.0 desktop release verification ${runId}`;
  const inbound = `UI 2.0 mobile release verification ${runId}`;
  const sentByDesktop = new Map();

  // 1. A -> B, with the ACK reconciled into the sender's UI.
  const first = await sendAndAck(desktop, `发送给 ${peerUser}`, outbound);
  sentByDesktop.set(outbound, first.id);
  await received(peer, outbound, first.sentAt);
  await peer.getByRole('button').filter({ hasText: user }).first().click();
  await peer.getByPlaceholder(`发送给 ${user}`).waitFor({ timeout: 30000 });
  await peer.getByText(outbound, { exact: true }).filter({ visible: true }).first().waitFor();
  mark('conversation-open', { client: 'mobile' });

  // 2. B has the conversation open, so A must see its message become read.
  await expect.poll(async () => statusOf(ownRow(desktop, outbound)), {
    timeout: 30000, message: 'the sender never saw a read update after the peer opened the conversation',
  }).toMatch(/--read\b/);
  counts.read += 1;
  latency.readMs.push(Date.now() - first.sentAt);
  mark('read', { client: 'desktop', text: outbound });

  // 3. B -> A.
  const reply = await sendAndAck(peer, `发送给 ${user}`, inbound);
  await received(desktop, inbound, reply.sentAt);

  // 4. Ordering: three messages in a row must arrive at B in the order A sent them.
  const burst = [1, 2, 3].map(index => `${runId} burst-${index}`);
  for (const text of burst) {
    const acked = await sendAndAck(desktop, `发送给 ${peerUser}`, text);
    sentByDesktop.set(text, acked.id);
    await received(peer, text, acked.sentAt);
  }
  const order = await peer.locator('.message-row').filter({ visible: true }).evaluateAll((rows, texts) =>
    texts.map(text => rows.findIndex(row => row.textContent?.includes(text))), burst);
  assert(order.every(index => index >= 0), `peer is missing a burst message: ${JSON.stringify(order)}`);
  assert.deepEqual([...order].sort((a, b) => a - b), order, `peer received the burst out of order: ${JSON.stringify(order)}`);
  mark('ordering', { rowIndexes: order });
  await expect.poll(async () => statusOf(ownRow(desktop, burst.at(-1))), {
    timeout: 30000, message: 'the last burst message never became read while the peer had the conversation open',
  }).toMatch(/--read\b/);
  counts.read += 1;
  mark('read', { client: 'desktop', text: burst.at(-1) });

  // 5. Conversation state operations.
  const row = desktop.locator('.im-conv-item').filter({ hasText: peerUser });
  await expect(row).toHaveCount(1);
  if (await row.evaluate(node => node.classList.contains('im-conv-item--pinned'))) {
    await row.click({ button: 'right' });
    await desktop.locator('.im-conv-dropdown').getByText('取消置顶', { exact: true }).click();
    await expect(desktop.locator('.im-conv-dropdown')).toBeHidden();
    await expect(row).not.toHaveClass(/im-conv-item--pinned/, { timeout: 30000 });
  }
  for (const [label, pinned] of [['置顶', true], ['取消置顶', false]]) {
    await row.click({ button: 'right' });
    await desktop.locator('.im-conv-dropdown').getByText(label, { exact: true }).click();
    await expect(desktop.locator('.im-conv-dropdown')).toBeHidden();
    await expect.poll(() => row.evaluate(node => node.classList.contains('im-conv-item--pinned')), { timeout: 30000 }).toBe(pinned);
  }
  await row.click({ button: 'right' });
  await desktop.locator('.im-conv-dropdown').getByText('标为未读', { exact: true }).click();
  await expect(row.locator('.im-conv-item__unread-pill')).toBeVisible({ timeout: 15000 });
  await row.click({ button: 'right' });
  await desktop.locator('.im-conv-dropdown').getByText('标为已读', { exact: true }).click();
  await expect(row.locator('.im-conv-item__unread-pill')).toHaveCount(0, { timeout: 15000 });
  mark('conversation-state', { pinUnpin: true, unreadRead: true });

  for (const [name, page] of [['desktop', desktop], ['mobile', peer]]) {
    const size = await page.evaluate(() => ({ viewport: innerWidth, content: document.documentElement.scrollWidth }));
    assert(size.content <= size.viewport, `${name} horizontal overflow: ${JSON.stringify(size)}`);
    if (output) await page.screenshot({ path: path.join(output, `${name}.png`), animations: 'disabled' });
  }

  // 6. After a reload the history comes from the server, not from memory: each
  //    message A sent is there exactly once, under the id the UI held after ACK.
  //    A reload lands on the conversation list (the route carries no conversation
  //    id), so the chat has to be reopened. The previous version waited for the
  //    inbound text right after the reload and passed only because that text was
  //    also the list row's last-message preview — it never looked at history.
  await desktop.reload();
  await expect(row).toHaveCount(1, { timeout: 45000 });
  await expect(row).not.toHaveClass(/im-conv-item--pinned/);
  await expect(row.locator('.im-conv-item__unread-pill')).toHaveCount(0);
  await row.click();
  await desktop.getByPlaceholder(`发送给 ${peerUser}`).waitFor({ timeout: 30000 });
  await desktop.locator('.message-row:not(.message-row--self)').filter({ hasText: inbound }).filter({ visible: true })
    .first().waitFor({ timeout: 45000 });
  for (const [text, id] of sentByDesktop) {
    const rows = desktop.locator('.message-row--self').filter({ hasText: text }).filter({ visible: true });
    await expect(rows, `"${text}" is not present exactly once after reload`).toHaveCount(1, { timeout: 30000 });
    assert.equal(await rows.first().getAttribute('data-message-id'), id, `"${text}" changed id between ACK and reload`);
  }
  mark('reload-history', { verifiedMessages: sentByDesktop.size });

  assert.deepEqual(errors, [], 'Browser runtime errors');
  const summary = (values) => values.length
    ? { count: values.length, minMs: Math.min(...values), maxMs: Math.max(...values), p50Ms: [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)] }
    : { count: 0 };
  if (output) {
    const report = {
      result: 'PASS',
      runId,
      // Set by flare-im-design tooling/release-check.mjs; evidence without it cannot be bound to a candidate.
      candidateId: process.env.FLARE_RELEASE_CANDIDATE_ID ?? null,
      startedAt: new Date(started).toISOString(),
      finishedAt: new Date().toISOString(),
      flags: { LIVE_BACKEND: true, LIVE_SEND: true, SDK_MOCK: false, NETWORK_INTERCEPT: false },
      clients: { desktop: { viewport: '1440x900' }, mobile: { viewport: '390x844' } },
      accounts: { user, peer: peerUser },
      site,
      browser: browser.version(),
      wasmBuild,
      counts,
      latency: { ack: summary(latency.ackMs), receive: summary(latency.receiveMs), read: summary(latency.readMs) },
      coverage: ['login x2', 'open conversation', 'A->B text + ACK', 'cross-user read update', 'B->A text + ACK',
        'ordered burst x3', 'pin/unpin', 'unread/read', 'no horizontal overflow', 'reload: exactly once, stable id', 'no runtime errors'],
      notCovered: ['media', 'offline', 'reconnect (SDK behaviour, not part of the design-kit 2.0 contract)',
        'duplicate-delivery injection (not part of the design-kit 2.0 contract)', 'native clients'],
    };
    writeFileSync(path.join(output, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);
    writeFileSync(path.join(output, 'events.json'), `${JSON.stringify(events, null, 2)}\n`);
  }
  console.log(`PASS live Web SDK [${runId}]: login, open conversation, A->B/B->A text with ACK, cross-user read, ordered burst x3, pin/unpin, unread/read, reload exactly-once with stable ids, no horizontal overflow`);
  console.log('Scope: not a media, offline, reconnect or native certification');
} catch (error) {
  if (output) {
    writeFileSync(path.join(output, 'report.json'), `${JSON.stringify({ result: 'FAIL', runId, candidateId: process.env.FLARE_RELEASE_CANDIDATE_ID ?? null,
      startedAt: new Date(started).toISOString(), failedAt: new Date().toISOString(), site, accounts: { user, peer: peerUser }, wasmBuild, counts,
      lastStep: events.at(-1)?.step ?? null, error: String(error.message).slice(0, 500) }, null, 2)}\n`);
    writeFileSync(path.join(output, 'events.json'), `${JSON.stringify([...events, { step: 'failed', tMs: Date.now() - started, message: String(error.message).slice(0, 500) }], null, 2)}\n`);
    for (const [index, context] of browser.contexts().entries()) {
      for (const page of context.pages()) {
        await page.screenshot({ path: path.join(output, `failure-${index}.png`), animations: 'disabled' }).catch(() => {});
      }
    }
  }
  throw error;
} finally {
  await browser.close();
}
