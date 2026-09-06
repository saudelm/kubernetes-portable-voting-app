#!/usr/bin/env node
'use strict';
const { chromium } = require('playwright');
const fs = require('node:fs');

async function checkResult(url, expected, screenshot, change = null, timeout = 45000) {
  const browser = await chromium.launch({
    headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {})
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 850 } });
    const errors = [];
    const scores = [];
    let navigations = 0;
    page.on('framenavigated', frame => { if (frame === page.mainFrame()) navigations++; });
    page.on('pageerror', err => errors.push(err.message));
    page.on('websocket', ws => ws.on('framereceived', event => {
      const payload = String(event.payload);
      if (payload.startsWith('42')) {
        const [name, data] = JSON.parse(payload.slice(2));
        if (name === 'scores') scores.push(JSON.parse(data));
      }
    }));
    const response = await page.goto(url, { waitUntil: 'domcontentloaded' });
    if (!response.ok()) throw new Error('Result HTTP status ' + response.status());
    async function waitForScores(target, from = 0) {
      const total = target.a + target.b;
      const aValue = total ? Math.round(target.a / total * 100) : 50;
      const shown = { total: total === 0 ? 'No votes yet' : `${total} ${total === 1 ? 'vote' : 'votes'}`,
                      a: aValue.toFixed(1) + '%', b: (100 - aValue).toFixed(1) + '%' };
      await page.waitForFunction(({ total, a, b }) =>
        document.querySelector('#total').textContent === total &&
        document.querySelector('#a-percent').textContent === a &&
        document.querySelector('#b-percent').textContent === b,
      shown, { timeout });
      const deadline = Date.now() + timeout;
      while (!scores.slice(from).some(v => v.a === target.a && v.b === target.b)) {
        if (Date.now() >= deadline) throw new Error('No matching live WebSocket scores');
        await new Promise(resolve => setTimeout(resolve, 25));
      }
    }
    await waitForScores(expected);
    let transition = null;
    if (change) {
      if (change.after.a === expected.a && change.after.b === expected.b)
        throw new Error('Live test requires a changed tally');
      const from = scores.length;
      const navigationCount = navigations;
      const sentAt = new Date().toISOString();
      const vote = await page.request.post(change.vote_url.replace(/\/$/, '') + '/', {
        form: { vote: change.choice }, headers: { Cookie: 'voter_id=' + change.key }, timeout
      });
      if (!vote.ok()) throw new Error('Vote HTTP status ' + vote.status());
      await waitForScores(change.after, from);
      if (navigations !== navigationCount) throw new Error('Result page reloaded during live test');
      transition = { before: expected, after: change.after, sent_at_utc: sentAt,
                     observed_at_utc: new Date().toISOString(), new_scores: scores.slice(from),
                     same_page_without_navigation: true };
    }
    if (errors.length) throw new Error('Browser errors: ' + errors.join('; '));
    await page.screenshot({ path: screenshot, fullPage: true });
    const report = { url, checked_at_utc: new Date().toISOString(), expected, transition, scores, errors,
                     displayed: { total: await page.locator('#total').innerText(),
                                  a: await page.locator('#a-percent').innerText(),
                                  b: await page.locator('#b-percent').innerText() } };
    fs.writeFileSync(screenshot + '.json', JSON.stringify(report, null, 2) + '\n');
    return report;
  } finally {
    await browser.close();
  }
}
module.exports = { checkResult };
if (require.main === module) {
  const [url, expected, screenshot, change] = process.argv.slice(2);
  checkResult(url, JSON.parse(expected), screenshot, change ? JSON.parse(change) : null)
    .then(report => console.log(JSON.stringify(report)))
    .catch(err => { console.error(err); process.exitCode = 1; });
}
