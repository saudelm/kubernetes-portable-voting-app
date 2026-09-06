'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { createVotePoller } = require('../vote-poller');

test('query failure makes readiness false and next successful query recovers', async () => {
  const pool = new EventEmitter();
  let fail = false;
  let clock = 1;
  const events = [];
  pool.query = async () => {
    if (fail) throw Object.assign(new Error('database restart'), { code: '57P01' });
    return { rows: [{ vote: 'a', count: '2' }, { vote: 'b', count: '1' }] };
  };
  const poller = createVotePoller(pool, v => events.push(v), { log: () => {}, now: () => clock });
  assert.equal(poller.ready(), false);
  assert.equal(await poller.poll(), true);
  assert.equal(poller.ready(), true);
  assert.deepEqual(events[0], { a: 2, b: 1 });
  fail = true;
  assert.equal(await poller.poll(), false);
  assert.equal(poller.ready(), false);
  assert.equal(events.length, 1);
  fail = false;
  assert.equal(await poller.poll(), true);
  assert.equal(poller.ready(), true);
  clock += 5001;
  assert.equal(poller.ready(), false);
});

test('idle PostgreSQL client error is handled and polling can recover', async () => {
  const pool = new EventEmitter();
  pool.query = async () => ({ rows: [] });
  const poller = createVotePoller(pool, () => {}, { log: () => {} });
  await poller.poll();
  pool.emit('error', new Error('connection lost'));
  assert.equal(poller.ready(), false);
  await poller.poll();
  assert.equal(poller.ready(), true);
});
