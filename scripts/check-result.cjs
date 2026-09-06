#!/usr/bin/env node
'use strict';
const { chromium } = require('playwright');
const fs = require('node:fs');

async function main() {
  const [url, expectedText, screenshot] = process.argv.slice(2);
  const expected = JSON.parse(expectedText);
  const browser = await chromium.launch({
    headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {})
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 850 } });
    const errors = [];
    const scores = [];
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
    const total = expected.a + expected.b;
    const a = Math.round(expected.a / total * 100).toFixed(1) + '%';
    const b = (100 - Math.round(expected.a / total * 100)).toFixed(1) + '%';
    await page.waitForFunction(({ total, a, b }) =>
      document.querySelector('#total').textContent === total + ' votes' &&
      document.querySelector('#a-percent').textContent === a &&
      document.querySelector('#b-percent').textContent === b,
    { total, a, b }, { timeout: 45000 });
    if (!scores.some(v => v.a === expected.a && v.b === expected.b)) throw new Error('No matching live WebSocket scores');
    if (errors.length) throw new Error('Browser errors: ' + errors.join('; '));
    await page.screenshot({ path: screenshot, fullPage: true });
    const report = { url, checked_at_utc: new Date().toISOString(), expected, scores, errors,
                     displayed: { total: await page.locator('#total').innerText(),
                                  a: await page.locator('#a-percent').innerText(),
                                  b: await page.locator('#b-percent').innerText() } };
    fs.writeFileSync(screenshot + '.json', JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify(report));
  } finally {
    await browser.close();
  }
}
main().catch(err => { console.error(err); process.exitCode = 1; });
