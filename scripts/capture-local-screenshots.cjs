#!/usr/bin/env node

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const output = process.argv[2];
if (!output) {
  console.error('Usage: capture-local-screenshots.cjs EVIDENCE_DIRECTORY');
  process.exit(1);
}

fs.mkdirSync(output, { recursive: true });

function kubectl(args) {
  return execFileSync('kubectl', args, { encoding: 'utf8' }).trim();
}

const grafanaUser = Buffer.from(
  kubectl([
    'get', 'secret', 'grafana', '-n', 'monitoring',
    '-o', 'jsonpath={.data.admin-user}',
  ]),
  'base64',
).toString('utf8');
const grafanaPassword = Buffer.from(
  kubectl([
    'get', 'secret', 'grafana', '-n', 'monitoring',
    '-o', 'jsonpath={.data.admin-password}',
  ]),
  'base64',
).toString('utf8');

async function main() {
  const browser = await chromium.launch({
    headless: true,
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
  });

  const captures = [];
  async function capture(name, url, prepare) {
    const page = await context.newPage();
    page.on('pageerror', (error) => console.error(`${name} page error: ${error.message}`));
    page.on('console', (message) => {
      if (message.type() === 'error') {
        console.error(`${name} console error: ${message.text()}`);
      }
    });
    await page.goto(url, { waitUntil: 'networkidle' });
    if (prepare) {
      await prepare(page);
    }
    const file = path.join(output, `${name}.png`);
    await page.screenshot({ path: file, fullPage: true });
    captures.push({
      file: path.basename(file),
      url: page.url(),
      capturedAtUtc: new Date().toISOString(),
      title: await page.title(),
    });
    await page.close();
  }

  await capture('t1-vote-view', 'http://vote.127.0.0.1.nip.io:8080/');
  await capture(
    't1-result-view',
    'http://result.127.0.0.1.nip.io:8080/',
    async (page) => {
      await page.waitForFunction(() => {
        const total = document.querySelector('#total');
        return total && total.textContent && total.textContent !== 'No votes yet';
      }, null, { timeout: 15000 });
    },
  );
  const loginResponse = await context.request.post(
    'http://grafana.127.0.0.1.nip.io:8080/login',
    { data: { user: grafanaUser, password: grafanaPassword } },
  );
  if (!loginResponse.ok()) {
    throw new Error(`Grafana login failed with HTTP ${loginResponse.status()}`);
  }
  await capture(
    'grafana-view',
    'http://grafana.127.0.0.1.nip.io:8080/d/portable-voting-overview/portable-voting-app-kubernetes-overview?orgId=1&refresh=5s',
    async (page) => {
      await page.getByText('Voting Pods Running', { exact: true }).waitFor({
        state: 'visible',
        timeout: 60000,
      });
      await page.waitForTimeout(5000);
    },
  );

  await browser.close();
  fs.writeFileSync(
    path.join(output, 'screenshots-metadata.json'),
    `${JSON.stringify({ viewport: '1440x900', captures }, null, 2)}\n`,
  );
  console.log(`Screenshots written to ${output}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
