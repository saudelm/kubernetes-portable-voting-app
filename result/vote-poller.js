'use strict';

function createVotePoller(pool, emit, options = {}) {
  const interval = options.interval || 1000;
  const now = options.now || Date.now;
  const log = options.log || ((err) => console.error('Database unavailable:', err.code || err.name));
  let lastSuccess = null;
  let available = false;
  let stopped = true;
  let timer;
  let inFlight = Promise.resolve();

  pool.on('error', (err) => {
    available = false;
    log(err);
  });

  async function poll() {
    try {
      // pool.query releases each client and discards failed connections.
      const result = await pool.query('SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote');
      const votes = { a: 0, b: 0 };
      for (const row of result.rows) {
        if (row.vote === 'a' || row.vote === 'b') votes[row.vote] = Number(row.count);
      }
      emit(votes);
      lastSuccess = now();
      available = true;
      return true;
    } catch (err) {
      available = false;
      log(err);
      return false;
    }
  }

  async function loop() {
    await poll();
    if (!stopped) timer = setTimeout(() => { inFlight = loop(); }, interval);
  }

  return {
    poll,
    ready: () => available && lastSuccess !== null && now() - lastSuccess < 5000,
    start() {
      if (!stopped) return;
      stopped = false;
      inFlight = loop();
    },
    async stop() {
      stopped = true;
      clearTimeout(timer);
      await inFlight;
    }
  };
}

module.exports = { createVotePoller };
