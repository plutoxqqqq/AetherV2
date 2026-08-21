'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {createApp, canonical, hash, API_VERSION} = require('./server');
const {JsonDatabase, MemoryDatabase} = require('./lib/database');
const {RateLimiter} = require('./lib/security');

async function withServer(options, callback) {
  const database = options.database || new MemoryDatabase();
  const publisher = options.publisher || {configured: false, mode: 'disabled'};
  const app = createApp({
    database,
    publisher,
    limiter: options.limiter,
    env: {
      ADMIN_KEY: 'test-admin',
      ALLOWED_ORIGINS: 'https://www.roblox.com',
      RATE_READ_LIMIT: '100',
      RATE_WRITE_LIMIT: '100'
    }
  });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  try {
    await callback('http://127.0.0.1:' + app.server.address().port, app);
  } finally {
    await new Promise(resolve => app.server.close(resolve));
  }
}

function validSubmission(config = {Modules: {Killaura: {Enabled: true}}}) {
  return {
    name: 'Test Config',
    submitter: 'Builder',
    userId: 12345,
    creator: 'Builder',
    category: 'Blatant',
    description: 'A complete integration-test config.',
    tags: ['pvp'],
    game: '6872274481',
    config
  };
}

test('canonical comparison is recursive and key-order independent', () => {
  assert.equal(canonical({b: {z: 2, a: 1}, a: 1}), canonical({a: 1, b: {a: 1, z: 2}}));
  assert.notEqual(canonical({a: 1}), canonical({a: 2}));
});

test('hash is a stable SHA-256 content identity', () => {
  assert.match(hash({b: 2, a: 1}), /^[a-f0-9]{64}$/);
  assert.equal(hash({b: 2, a: 1}), hash({a: 1, b: 2}));
});

test('responses expose API and request IDs while CORS stays allow-listed', async () => {
  await withServer({}, async base => {
    const allowed = await fetch(base + '/v2/health', {headers: {origin: 'https://www.roblox.com', 'x-request-id': 'request-test-123'}});
    assert.equal(allowed.status, 200);
    assert.equal(allowed.headers.get('x-aether-api-version'), API_VERSION);
    assert.equal(allowed.headers.get('x-request-id'), 'request-test-123');
    assert.equal(allowed.headers.get('access-control-allow-origin'), 'https://www.roblox.com');

    const denied = await fetch(base + '/health', {headers: {origin: 'https://evil.example'}});
    assert.equal(denied.status, 403);
    assert.equal(denied.headers.get('access-control-allow-origin'), null);
  });
});

test('public deletion is authenticated and returns structured JSON', async () => {
  await withServer({}, async base => {
    const response = await fetch(base + '/public-configs/rage.json', {method: 'DELETE'});
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), {success: false, error: 'Maintainer authentication required'});
  });
});

test('submission receipts are hashed, authorize only their item, and duplicates fail', async () => {
  await withServer({}, async (base, app) => {
    const create = await fetch(base + '/submissions', {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify(validSubmission())
    });
    assert.equal(create.status, 201);
    const receipt = await create.json();
    assert.match(receipt.token, /^[a-f0-9]{64}$/);

    const stored = (await app.database.read()).submissions[0];
    assert.equal(stored.token, undefined);
    assert.equal(stored.receiptHash, hash(receipt.token));

    const status = await fetch(base + '/submissions/' + receipt.id + '?token=' + receipt.token);
    assert.equal(status.status, 200);
    assert.equal((await status.json()).status, 'pending');

    const denied = await fetch(base + '/submissions/' + receipt.id + '?token=wrong');
    assert.equal(denied.status, 401);

    const duplicate = await fetch(base + '/submissions', {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify(validSubmission())
    });
    assert.equal(duplicate.status, 409);
  });
});

test('schema validation rejects incomplete metadata before storage', async () => {
  await withServer({}, async (base, app) => {
    const response = await fetch(base + '/submissions', {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({...validSubmission(), tags: [], description: ''})
    });
    assert.equal(response.status, 400);
    assert.equal((await app.database.read()).submissions.length, 0);
  });
});

test('ratings are one vote per user/install and expose aggregate statistics', async () => {
  await withServer({}, async base => {
    const vote = value => fetch(base + '/public-configs/test.json/ratings', {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({userId: 5, clientId: '12345678-1234-1234-1234-123456789abc', rating: value})
    });
    assert.equal((await vote(1)).status, 200);
    const changed = await vote(-1);
    const result = await changed.json();
    assert.deepEqual({likes: result.likes, dislikes: result.dislikes, ratingCount: result.ratingCount, userRating: result.userRating}, {likes: 0, dislikes: 1, ratingCount: 1, userRating: -1});
  });
});

test('catalogue vote and favorite state belong to the requesting installation', async () => {
  await withServer({}, async base => {
    const first = {userId: 5, clientId: '12345678-1234-1234-1234-123456789abc'};
    const second = {userId: 5, clientId: 'abcdefab-cdef-cdef-cdef-abcdefabcdef'};
    const post = (route, body) => fetch(base + route, {
      method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify(body)
    });

    await post('/public-configs/rage.json/ratings', {...first, rating: 1});
    await post('/public-configs/rage.json/ratings', {...second, rating: -1});
    await post('/public-configs/rage.json/favorites', {...first, favorite: true});

    const catalogue = async identity => {
      const response = await fetch(base + '/public-configs?userId=' + identity.userId + '&clientId=' + identity.clientId);
      return (await response.json()).presets.find(item => item.file === 'rage.json');
    };
    assert.deepEqual(
      {rating: (await catalogue(first)).userRating, favorited: (await catalogue(first)).favorited},
      {rating: 1, favorited: true}
    );
    assert.deepEqual(
      {rating: (await catalogue(second)).userRating, favorited: (await catalogue(second)).favorited},
      {rating: -1, favorited: false}
    );
  });
});

test('favorites, reports, creator pages, forks and compatibility metadata use the v2 contract', async () => {
  await withServer({}, async (base, app) => {
    const identity = {userId: 5, clientId: '12345678-1234-1234-1234-123456789abc'};
    const favorite = await fetch(base + '/public-configs/rage.json/favorites', {
      method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify({...identity, favorite: true})
    });
    assert.equal(favorite.status, 200);
    assert.deepEqual(await favorite.json(), {success: true, favorited: true, favoriteCount: 1});

    const report = await fetch(base + '/public-configs/rage.json/reports', {
      method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify({userId: 5, reason: 'This config needs a compatibility review.'})
    });
    assert.equal(report.status, 201);
    assert.equal((await app.database.read()).reports.length, 1);

    const creator = await fetch(base + '/creators/plutoxqqqqq');
    assert.equal(creator.status, 200);
    assert.equal((await creator.json()).configs[0].file, 'rage.json');

    const submission = validSubmission({Modules: {Scaffold: {Enabled: true}}});
    Object.assign(submission, {
      name: 'Rage Fork',
      forkOf: 'rage.json',
      minimumVersion: '4.0.0',
      gameVersion: '1234',
      screenshots: ['https://example.invalid/screenshot.png']
    });
    const fork = await fetch(base + '/v2/submissions', {
      method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify(submission)
    });
    assert.equal(fork.status, 201);
    const stored = (await app.database.read()).submissions.find(item => item.name === 'Rage Fork');
    assert.equal(stored.forkOf, 'rage.json');
    assert.equal(stored.minimumVersion, '4.0.0');
    assert.deepEqual(stored.screenshots, ['https://example.invalid/screenshot.png']);
  });
});

test('rate limiter separates read and write budgets', () => {
  const limiter = new RateLimiter({windowMs: 1000, readLimit: 2, writeLimit: 1});
  assert.equal(limiter.take('ip', false, 0).allowed, true);
  assert.equal(limiter.take('ip', false, 0).allowed, true);
  assert.equal(limiter.take('ip', false, 0).allowed, false);
  assert.equal(limiter.take('ip', true, 0).allowed, true);
  assert.equal(limiter.take('ip', true, 0).allowed, false);
  assert.equal(limiter.take('ip', false, 1001).allowed, true);
});

test('asynchronous JSON persistence serializes writes and recovers after a rejected mutation', async () => {
  const folder = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'aether-db-'));
  try {
    const database = new JsonDatabase(path.join(folder, 'data.json'));
    await assert.rejects(database.transaction(() => { throw Error('rejected'); }), /rejected/);
    await Promise.all([
      database.transaction(data => { data.audit.push({id: 1}); }),
      database.transaction(data => { data.audit.push({id: 2}); })
    ]);
    assert.deepEqual((await database.read()).audit.map(item => item.id), [1, 2]);
    assert.equal(JSON.parse(await fs.promises.readFile(path.join(folder, 'data.json'), 'utf8')).audit.length, 2);
  } finally {
    await fs.promises.rm(folder, {recursive: true, force: true});
  }
});
