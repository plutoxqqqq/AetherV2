'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'aether-stats-'));
const statsFile = path.join(temp, 'execution-stats.json');
fs.writeFileSync(statsFile, JSON.stringify({
  version: 1,
  allTimeExecutions: 5,
  allUsers: {},
  firstSeenAt: null,
  lastSeenAt: null,
  buckets: {hourly: {}, daily: {}, weekly: {}, monthly: {}}
}));
process.env.AETHER_STATS_FILE = statsFile;
const stats = require('./execution-stats');

test('v1 analytics migrate without losing all-time totals', () => {
  const summary = stats.summary();
  assert.equal(summary.allTime.executions, 5);
  assert.equal(summary.unknownExecutions, 5);
  assert.equal(summary.freeExecutions, 0);
  assert.equal(summary.premiumExecutions, 0);
});

test('heartbeats classify launches and accumulate real tracked time', async () => {
  const realNow = Date.now;
  let now = 1800000000000;
  Date.now = () => now;
  try {
    await stats.recordExecution({userId: '123456789', placeId: '6872274481'});
    let summary = stats.summary();
    assert.equal(summary.allTime.executions, 6);
    assert.equal(summary.unknownExecutions, 6);

    await stats.recordExecution({
      event: 'heartbeat', sessionId: 'session_test_1234', username: 'Example_User',
      userId: '123456789', placeId: '6872274481', access: 'premium'
    });
    summary = stats.summary();
    assert.equal(summary.premiumExecutions, 1);
    assert.equal(summary.unknownExecutions, 5);
    assert.equal(summary.activeUsers, 1);

    now += 60000;
    await stats.recordExecution({
      event: 'heartbeat', sessionId: 'session_test_1234', username: 'Example_User',
      userId: '123456789', placeId: '6872274481', access: 'premium'
    });
    const profile = stats.listUsers({pageSize: 10}).users[0];
    assert.equal(profile.username, 'Example_User');
    assert.equal(profile.executions, 1);
    assert.equal(profile.premiumExecutions, 1);
    assert.equal(profile.sessions, 1);
    assert.equal(profile.trackedSeconds, 60);
  } finally {
    Date.now = realNow;
  }
});

test('legacy graph periods also use daily points', () => {
  for (const period of ['hourly', 'daily', 'weekly', 'monthly', '7d', '30d', '90d', 'all']) {
    const graph = stats.renderGraph(period, 'executions');
    assert.ok(graph.points.length >= 1);
    assert.ok(graph.points.every(point => /^\d{4}-\d{2}-\d{2}$/.test(point.key)), period + ' should use daily keys');
  }
});

test('all-time graph is daily and renders a valid PNG', () => {
  const graph = stats.renderGraph('all', 'executions');
  assert.ok(graph.points.length >= 1);
  assert.ok(graph.points.every(point => /^\d{4}-\d{2}-\d{2}$/.test(point.key)));
  assert.deepEqual([...graph.buffer.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  assert.ok(graph.maxValue >= 1);
});

test.after(() => {
  stats.flush();
  fs.rmSync(temp, {recursive: true, force: true});
});
