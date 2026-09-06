'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createRequire } = require('node:module');
const resultRequire = createRequire(path.resolve(__dirname, '../../result/package.json'));
const { Server } = resultRequire('socket.io');
const { checkResult } = require('../check-result.cjs');

// A protocol fixture tests the checker, not the application or any Kubernetes cluster.
async function fixture(t, update) {
  let scores = { a: 2, b: 1 };
  let posts = 0;
  const server = http.createServer((req, res) => {
    if (req.method === 'POST') {
      assert.equal(req.headers.cookie, 'voter_id=test-live');
      posts++;
      req.resume();
      if (update) scores = { a: 1, b: 2 };
      res.end('ok');
    } else if (req.url === '/app.js') {
      res.setHeader('Content-Type', 'application/javascript');
      res.end(fs.readFileSync(path.resolve(__dirname, '../../result/views/app.js')));
    } else {
      res.setHeader('Content-Type', 'text/html');
      res.end('<div id="total"></div><div id="a-percent"></div><div id="b-percent"></div>' +
        '<div id="background-stats-1"></div><div id="background-stats-2"></div>' +
        '<script src="/socket.io/socket.io.js"></script><script src="/app.js"></script>');
    }
  });
  const io = new Server(server);
  const timer = setInterval(() => io.emit('scores', JSON.stringify(scores)), 50);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'result-checker-'));
  t.after(async () => {
    clearInterval(timer);
    await new Promise(resolve => io.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const url = `http://127.0.0.1:${server.address().port}`;
  return { run: () => checkResult(url, { a: 2, b: 1 }, path.join(dir, 'result.png'),
    { vote_url: url, key: 'test-live', choice: 'b', after: { a: 1, b: 2 } }, 1500),
    posts: () => posts };
}

test('checker observes changed scores and DOM without reloading', async t => {
  const f = await fixture(t, true);
  const report = await f.run();
  assert.equal(f.posts(), 1);
  assert.equal(report.transition.same_page_without_navigation, true);
  assert.deepEqual(report.transition.after, { a: 1, b: 2 });
  assert.equal(report.displayed.b, '67.0%');
});

test('checker rejects a server that only supplies the initial tally', async t => {
  const f = await fixture(t, false);
  await assert.rejects(f.run(), /Timeout|WebSocket/);
  assert.equal(f.posts(), 1);
});
