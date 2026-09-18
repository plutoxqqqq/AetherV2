'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

// This file exercises the merged service as a deployment with Community Configs only. The premium
// stack is loaded by PREMIUM_GITHUB_REPO and validates GITHUB_TOKEN, GITHUB_REPO and PUBLIC_ORIGIN
// while it loads, so leaving the switch unset is what proves a configs deployment boots without
// any of those settings.
delete process.env.PREMIUM_GITHUB_REPO;

const {server} = require('./index');
const {dataPath} = require('./data-path');

const withServer = async work => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    return await work('http://127.0.0.1:' + server.address().port);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
};

test('one health probe reports every capability of the merged service', async () => {
  await withServer(async base => {
    const response = await fetch(base + '/health');
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.success, true);
    assert.equal(body.service, 'aetherv2-backend');
    assert.equal(body.configs, true);
    assert.equal(body.premiumEnabled, false);
    assert.equal(body.executionAnalytics, false);
  });
});

test('Community Configs routes answer on the merged listener and still take the maintainer key', async () => {
  await withServer(async base => {
    const response = await fetch(base + '/submissions');
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), {success: false, error: 'Maintainer authentication required'});
  });
});

test('a cross-origin preflight is answered once for both services', async () => {
  await withServer(async base => {
    const response = await fetch(base + '/public-configs', {method: 'OPTIONS'});
    assert.equal(response.status, 204);
    // The config API sends Authorization, which the premium routes do not, so one shared preflight
    // has to allow both or a browser client cannot reach the review queue.
    assert.match(response.headers.get('access-control-allow-headers'), /authorization/);
    assert.match(response.headers.get('access-control-allow-methods'), /DELETE/);
  });
});

test('an unowned path falls through both services to one 404', async () => {
  await withServer(async base => {
    const response = await fetch(base + '/not-a-route');
    assert.equal(response.status, 404);
    assert.deepEqual(await response.json(), {success: false, error: 'Endpoint not found'});
  });
});

test('premium routes are absent rather than fatal when the premium stack is not configured', async () => {
  await withServer(async base => {
    const response = await fetch(base + '/premium/tree');
    assert.equal(response.status, 404);
  });
});

test('the maintainer key can be checked without loading the review queue', async () => {
  await withServer(async base => {
    const response = await fetch(base + '/admin/verify');
    assert.equal(response.status, 401);
  });
});

test('state files resolve inside the one data directory', () => {
  // The committed config store already lives there, so the preferred path wins.
  assert.equal(dataPath('configs.json'), path.join(__dirname, 'data', 'configs.json'));
  // A file that only exists at the pre-merge location keeps being used until it is moved.
  assert.equal(dataPath('unused-name.json', ['data-path.js']), path.join(__dirname, 'data-path.js'));
  // Nothing on disk yet: the new location is returned so the first write creates it there.
  assert.equal(dataPath('unused-name.json', ['missing.json']), path.join(__dirname, 'data', 'unused-name.json'));
});
