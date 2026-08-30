'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');

const STATS_FILE = process.env.AETHER_STATS_FILE || path.join(__dirname, 'execution-stats.json');
const VERSION = 2;
const ACTIVE_WINDOW_MS = 30000;
const LAUNCH_CLASSIFY_WINDOW_MS = 60000;
const MAX_HEARTBEAT_DELTA_SECONDS = 90;
const RETENTION = Object.freeze({hourly: 2160, daily: 3650, weekly: 520, monthly: 240});
const PERIODS = ['hourly', 'daily', 'weekly', 'monthly'];
const runtimeSessions = new Map();

const isObject = value => value && typeof value === 'object' && !Array.isArray(value);
const pad = value => String(value).padStart(2, '0');
const dayKey = date => date.getUTCFullYear() + '-' + pad(date.getUTCMonth() + 1) + '-' + pad(date.getUTCDate());
const hourKey = date => dayKey(date) + 'T' + pad(date.getUTCHours());
const monthKey = date => date.getUTCFullYear() + '-' + pad(date.getUTCMonth() + 1);
const weekStart = date => {
  const value = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const weekday = value.getUTCDay() || 7;
  value.setUTCDate(value.getUTCDate() - weekday + 1);
  return value;
};
const weekKey = date => 'W:' + dayKey(weekStart(date));
const keyFor = (period, date) => period === 'hourly' ? hourKey(date) : period === 'daily' ? dayKey(date) : period === 'weekly' ? weekKey(date) : monthKey(date);
const startOf = (period, date) => {
  if (period === 'hourly') return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), date.getUTCHours()));
  if (period === 'daily') return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  if (period === 'weekly') return weekStart(date);
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));
};
const shift = (period, date, amount) => {
  const value = new Date(date);
  if (period === 'hourly') value.setUTCHours(value.getUTCHours() + amount);
  else if (period === 'daily') value.setUTCDate(value.getUTCDate() + amount);
  else if (period === 'weekly') value.setUTCDate(value.getUTCDate() + amount * 7);
  else value.setUTCMonth(value.getUTCMonth() + amount);
  return value;
};
const labelFor = (period, date) => period === 'hourly'
  ? pad(date.getUTCHours()) + ':00'
  : period === 'daily'
    ? pad(date.getUTCDate()) + '/' + pad(date.getUTCMonth() + 1)
    : period === 'weekly'
      ? dayKey(date)
      : monthKey(date);
const userHash = value => /^\d{1,20}$/.test(String(value || ''))
  ? crypto.createHash('sha256').update('aetherv2-user\0' + String(value)).digest('hex').slice(0, 32)
  : null;
const validUsername = value => /^[A-Za-z0-9_]{3,20}$/.test(String(value || '')) ? String(value) : null;
const validPlaceId = value => /^\d{1,20}$/.test(String(value || '')) ? String(value) : null;
const validSessionId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{8,80}$/.test(value) ? value : null;
const validAccess = value => value === 'premium' || value === 'free' ? value : 'unknown';

const emptyState = () => ({
  version: VERSION,
  allTimeExecutions: 0,
  allUsers: {},
  profiles: {},
  access: {free: 0, premium: 0, unknown: 0},
  firstSeenAt: null,
  lastSeenAt: null,
  buckets: {hourly: {}, daily: {}, weekly: {}, monthly: {}}
});

const migrate = raw => {
  if (!isObject(raw)) throw new Error('Execution analytics file has an invalid structure');
  if (raw.version === VERSION) return raw;
  if (raw.version !== 1) throw new Error('Unsupported execution analytics version');
  const allTime = Number.isSafeInteger(raw.allTimeExecutions) && raw.allTimeExecutions >= 0 ? raw.allTimeExecutions : 0;
  return {
    version: VERSION,
    allTimeExecutions: allTime,
    allUsers: isObject(raw.allUsers) ? raw.allUsers : {},
    profiles: {},
    access: {free: 0, premium: 0, unknown: allTime},
    firstSeenAt: raw.firstSeenAt || null,
    lastSeenAt: raw.lastSeenAt || null,
    buckets: isObject(raw.buckets) ? raw.buckets : {hourly: {}, daily: {}, weekly: {}, monthly: {}}
  };
};

const validate = raw => {
  const value = migrate(raw);
  if (!isObject(value) || value.version !== VERSION || !Number.isSafeInteger(value.allTimeExecutions) || value.allTimeExecutions < 0 ||
      !isObject(value.allUsers) || !isObject(value.profiles) || !isObject(value.access) || !isObject(value.buckets)) {
    throw new Error('Execution analytics file has an invalid structure');
  }
  for (const name of ['free', 'premium', 'unknown']) {
    if (!Number.isSafeInteger(value.access[name]) || value.access[name] < 0) throw new Error('Execution analytics access totals are invalid');
  }
  for (const period of PERIODS) {
    if (!isObject(value.buckets[period])) throw new Error('Execution analytics bucket is missing: ' + period);
    for (const bucket of Object.values(value.buckets[period])) {
      if (!isObject(bucket) || !Number.isSafeInteger(bucket.executions) || bucket.executions < 0 || !isObject(bucket.users)) {
        throw new Error('Execution analytics bucket is invalid: ' + period);
      }
    }
  }
  return value;
};

const load = () => {
  try { return validate(JSON.parse(fs.readFileSync(STATS_FILE, 'utf8'))); }
  catch (error) {
    if (error && error.code === 'ENOENT') return emptyState();
    throw error;
  }
};

let state = load();
let dirty = false;
let flushTimer = null;

const writeNow = () => {
  if (!dirty) return;
  fs.mkdirSync(path.dirname(STATS_FILE), {recursive: true});
  const temp = STATS_FILE + '.' + process.pid + '.tmp';
  fs.writeFileSync(temp, JSON.stringify(state, null, 2));
  fs.renameSync(temp, STATS_FILE);
  dirty = false;
};
const scheduleWrite = () => {
  dirty = true;
  if (flushTimer) return;
  flushTimer = setTimeout(() => {
    flushTimer = null;
    try { writeNow(); }
    catch (error) { console.error('[AetherV2] execution analytics write failed:', error.message || error); }
  }, 5000);
  if (typeof flushTimer.unref === 'function') flushTimer.unref();
};

const prune = period => {
  const keys = Object.keys(state.buckets[period]).sort();
  const count = Math.max(0, keys.length - RETENTION[period]);
  for (let index = 0; index < count; index += 1) delete state.buckets[period][keys[index]];
};

const profileFor = input => {
  const id = userHash(input && input.userId);
  if (!id) return {id: null, profile: null};
  let profile = state.profiles[id];
  if (!isObject(profile)) {
    profile = {
      userId: String(input.userId),
      username: null,
      executions: 0,
      freeExecutions: 0,
      premiumExecutions: 0,
      unknownExecutions: 0,
      sessions: 0,
      trackedSeconds: 0,
      firstSeenAt: null,
      lastSeenAt: null,
      lastHeartbeatAt: null,
      lastAccess: 'unknown',
      lastPlaceId: null
    };
    state.profiles[id] = profile;
  }
  const username = validUsername(input.username);
  if (username) profile.username = username;
  const placeId = validPlaceId(input.placeId);
  if (placeId) profile.lastPlaceId = placeId;
  return {id, profile};
};

const addLaunch = input => {
  const now = new Date();
  const access = validAccess(input && input.access);
  const {id, profile} = profileFor(input || {});
  state.allTimeExecutions += 1;
  state.access[access] += 1;
  state.firstSeenAt ||= now.toISOString();
  state.lastSeenAt = now.toISOString();
  if (id) state.allUsers[id] = true;
  if (profile) {
    profile.executions += 1;
    if (access === 'premium') profile.premiumExecutions += 1;
    else if (access === 'free') profile.freeExecutions += 1;
    else profile.unknownExecutions += 1;
    profile.firstSeenAt ||= now.toISOString();
    profile.lastSeenAt = now.toISOString();
    if (access !== 'unknown') profile.lastAccess = access;
  }
  for (const period of PERIODS) {
    const key = keyFor(period, now);
    const bucket = state.buckets[period][key] || {executions: 0, users: {}};
    bucket.executions += 1;
    if (id) bucket.users[id] = true;
    state.buckets[period][key] = bucket;
    prune(period);
  }
  scheduleWrite();
  return {accepted: true, event: 'execution', profileId: id, uniqueKnown: Boolean(id)};
};

const classifyPending = (profile, access, now = Date.now()) => {
  if (!profile || access === 'unknown' || state.access.unknown <= 0) return false;
  if (profile.unknownExecutions > 0) {
    profile.unknownExecutions -= 1;
  } else {
    const launchAt = state.lastSeenAt ? Date.parse(state.lastSeenAt) : NaN;
    if (!Number.isFinite(launchAt) || Math.abs(now - launchAt) > LAUNCH_CLASSIFY_WINDOW_MS) return false;
    // The legacy/core launch can arrive without Roblox identity. Attach that already-counted
    // launch to the first identified heartbeat without incrementing global execution totals.
    profile.executions += 1;
  }
  state.access.unknown -= 1;
  if (access === 'premium') profile.premiumExecutions += 1;
  else profile.freeExecutions += 1;
  state.access[access] += 1;
  return true;
};

const addHeartbeat = input => {
  const now = Date.now();
  const sessionId = validSessionId(input && input.sessionId);
  const access = validAccess(input && input.access) === 'premium' ? 'premium' : 'free';
  const {id, profile} = profileFor(input || {});
  if (!id || !profile || !sessionId) return {accepted: false, event: 'heartbeat', reason: 'identity-or-session-missing'};
  const runtimeKey = id + ':' + sessionId;
  let session = runtimeSessions.get(runtimeKey);
  if (!session) {
    session = {lastAt: now, access};
    runtimeSessions.set(runtimeKey, session);
    profile.sessions += 1;
    classifyPending(profile, access, now);
  } else {
    const delta = Math.max(0, Math.min(MAX_HEARTBEAT_DELTA_SECONDS, (now - session.lastAt) / 1000));
    if (delta > 0) profile.trackedSeconds += delta;
    session.lastAt = now;
    session.access = access;
  }
  profile.lastAccess = access;
  profile.lastHeartbeatAt = new Date(now).toISOString();
  profile.lastSeenAt = profile.lastHeartbeatAt;
  state.lastSeenAt = profile.lastHeartbeatAt;
  if (runtimeSessions.size > 10000) {
    const cutoff = now - ACTIVE_WINDOW_MS * 4;
    for (const [key, value] of runtimeSessions) if (value.lastAt < cutoff) runtimeSessions.delete(key);
  }
  scheduleWrite();
  return {accepted: true, event: 'heartbeat', profileId: id};
};

const addSessionEnd = input => {
  const now = Date.now();
  const sessionId = validSessionId(input && input.sessionId);
  const {id, profile} = profileFor(input || {});
  if (!id || !profile || !sessionId) return {accepted: false, event: 'session_end', reason: 'identity-or-session-missing'};
  const runtimeKey = id + ':' + sessionId;
  const session = runtimeSessions.get(runtimeKey);
  if (session) {
    const delta = Math.max(0, Math.min(MAX_HEARTBEAT_DELTA_SECONDS, (now - session.lastAt) / 1000));
    if (delta > 0) profile.trackedSeconds += delta;
    runtimeSessions.delete(runtimeKey);
  }
  profile.lastSeenAt = new Date(now).toISOString();
  state.lastSeenAt = profile.lastSeenAt;
  scheduleWrite();
  return {accepted: true, event: 'session_end', profileId: id};
};

const recordExecution = async input => {
  const event = String(input && input.event || 'execution').toLowerCase();
  if (event === 'heartbeat') return addHeartbeat(input || {});
  if (event === 'session_end') return addSessionEnd(input || {});
  return addLaunch(input || {});
};

const bucketCount = bucket => ({executions: bucket ? bucket.executions : 0, unique: bucket ? Object.keys(bucket.users).length : 0});
const profileIsActive = id => {
  const now = Date.now();
  let active = false;
  for (const [key, session] of runtimeSessions) {
    if (now - session.lastAt > ACTIVE_WINDOW_MS) {
      runtimeSessions.delete(key);
      continue;
    }
    if (key.startsWith(id + ':')) active = true;
  }
  return active;
};

const publicProfile = (id, profile) => ({
  profileId: id,
  userId: String(profile.userId),
  username: validUsername(profile.username),
  executions: Number(profile.executions) || 0,
  freeExecutions: Number(profile.freeExecutions) || 0,
  premiumExecutions: Number(profile.premiumExecutions) || 0,
  unknownExecutions: Number(profile.unknownExecutions) || 0,
  sessions: Number(profile.sessions) || 0,
  trackedSeconds: Math.max(0, Math.round(Number(profile.trackedSeconds) || 0)),
  firstSeenAt: profile.firstSeenAt || null,
  lastSeenAt: profile.lastSeenAt || null,
  lastHeartbeatAt: profile.lastHeartbeatAt || null,
  lastAccess: validAccess(profile.lastAccess),
  lastPlaceId: validPlaceId(profile.lastPlaceId),
  active: profileIsActive(id),
  calculating: profileIsActive(id)
});

const summary = () => {
  const now = new Date();
  const profiles = Object.entries(state.profiles).map(([id, profile]) => publicProfile(id, profile));
  return {
    hourly: bucketCount(state.buckets.hourly[keyFor('hourly', now)]),
    daily: bucketCount(state.buckets.daily[keyFor('daily', now)]),
    weekly: bucketCount(state.buckets.weekly[keyFor('weekly', now)]),
    monthly: bucketCount(state.buckets.monthly[keyFor('monthly', now)]),
    allTime: {executions: state.allTimeExecutions, unique: Object.keys(state.allUsers).length},
    freeExecutions: state.access.free,
    premiumExecutions: state.access.premium,
    unknownExecutions: state.access.unknown,
    activeUsers: profiles.filter(profile => profile.active).length,
    trackedSeconds: profiles.reduce((sum, profile) => sum + profile.trackedSeconds, 0),
    firstSeenAt: state.firstSeenAt,
    lastSeenAt: state.lastSeenAt,
    timezone: 'UTC'
  };
};

const listUsers = ({page = 0, pageSize = 8} = {}) => {
  const size = Math.max(1, Math.min(25, Number(pageSize) || 8));
  const users = Object.entries(state.profiles)
    .map(([id, profile]) => publicProfile(id, profile))
    .sort((left, right) => Date.parse(right.lastSeenAt || 0) - Date.parse(left.lastSeenAt || 0) || right.executions - left.executions);
  const pageCount = Math.max(1, Math.ceil(users.length / size));
  const selected = Math.max(0, Math.min(Number(page) || 0, pageCount - 1));
  return {users: users.slice(selected * size, (selected + 1) * size), total: users.length, page: selected, pageCount};
};
const getUser = id => /^[a-f0-9]{32}$/.test(String(id || '')) && state.profiles[id] ? publicProfile(id, state.profiles[id]) : null;

const normalSeries = (period, metric) => {
  const lengths = {hourly: 24, daily: 30, weekly: 12, monthly: 12};
  if (!Object.hasOwn(lengths, period)) throw new Error('Unknown analytics period');
  if (!['executions', 'unique'].includes(metric)) throw new Error('Unknown analytics metric');
  const count = lengths[period];
  const end = startOf(period, new Date());
  const values = [];
  for (let index = count - 1; index >= 0; index -= 1) {
    const date = shift(period, end, -index);
    const bucket = state.buckets[period][keyFor(period, date)];
    values.push({
      key: keyFor(period, date),
      label: labelFor(period, date),
      value: metric === 'executions' ? (bucket ? bucket.executions : 0) : (bucket ? Object.keys(bucket.users).length : 0)
    });
  }
  return values;
};

const dailySeries = (range, metric) => {
  if (!['executions', 'unique'].includes(metric)) throw new Error('Unknown analytics metric');
  const today = startOf('daily', new Date());
  let days = range === 'all' ? null : Number(String(range).replace(/d$/, ''));
  if (range !== 'all' && ![7, 30, 90].includes(days)) throw new Error('Unknown daily graph range');
  if (range === 'all') {
    const earliestBucket = Object.keys(state.buckets.daily).sort()[0];
    const start = earliestBucket
      ? new Date(earliestBucket + 'T00:00:00Z')
      : state.firstSeenAt
        ? startOf('daily', new Date(state.firstSeenAt))
        : today;
    days = Math.max(1, Math.floor((today - start) / 86400000) + 1);
  }
  const values = [];
  for (let index = days - 1; index >= 0; index -= 1) {
    const date = shift('daily', today, -index);
    const key = dayKey(date);
    const bucket = state.buckets.daily[key];
    values.push({key, label: labelFor('daily', date), value: metric === 'executions' ? (bucket ? bucket.executions : 0) : (bucket ? Object.keys(bucket.users).length : 0)});
  }
  return values;
};
const series = (period, metric = 'executions') => {
  // Every graph is daily. Legacy period names remain accepted for API compatibility, but are
  // mapped to useful daily windows instead of changing the x-axis unit.
  const range = ({hourly: '7d', daily: '30d', weekly: '90d', monthly: 'all'})[period] || period;
  return dailySeries(range, metric);
};

const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    table[n] = c >>> 0;
  }
  return table;
})();
const crc32 = buffer => {
  let crc = 0xffffffff;
  for (const value of buffer) crc = crcTable[(crc ^ value) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
};
const pngChunk = (type, data) => {
  const name = Buffer.from(type);
  const size = Buffer.alloc(4); size.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([name, data])));
  return Buffer.concat([size, name, data, crc]);
};

const renderGraph = (period, metric = 'executions') => {
  const points = series(period, metric);
  const width = 900, height = 360, left = 42, right = 24, top = 24, bottom = 34;
  const pixels = Buffer.alloc(width * height * 4);
  const set = (x, y, rgba) => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const offset = (y * width + x) * 4;
    pixels[offset] = rgba[0]; pixels[offset + 1] = rgba[1]; pixels[offset + 2] = rgba[2]; pixels[offset + 3] = rgba[3];
  };
  const fill = rgba => {
    for (let y = 0; y < height; y += 1) for (let x = 0; x < width; x += 1) set(x, y, rgba);
  };
  const line = (x0, y0, x1, y1, rgba) => {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    const dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    let error = dx + dy;
    while (true) {
      set(x0, y0, rgba); set(x0 + 1, y0, rgba); set(x0, y0 + 1, rgba);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * error;
      if (e2 >= dy) { error += dy; x0 += sx; }
      if (e2 <= dx) { error += dx; y0 += sy; }
    }
  };
  fill([24, 25, 31, 255]);
  const chartWidth = width - left - right;
  const chartHeight = height - top - bottom;
  for (let grid = 0; grid <= 4; grid += 1) {
    const y = Math.round(top + chartHeight * grid / 4);
    for (let x = left; x < width - right; x += 1) set(x, y, [55, 57, 68, 255]);
  }
  const maxValue = Math.max(1, ...points.map(point => point.value));
  const coordinates = points.map((point, index) => ({
    x: left + (points.length === 1 ? 0 : chartWidth * index / (points.length - 1)),
    y: top + chartHeight - (point.value / maxValue) * chartHeight,
    value: point.value,
    key: point.key,
    label: point.label
  }));
  for (let index = 1; index < coordinates.length; index += 1) {
    line(coordinates[index - 1].x, coordinates[index - 1].y, coordinates[index].x, coordinates[index].y, [190, 115, 255, 255]);
  }
  const markerStride = Math.max(1, Math.ceil(coordinates.length / 180));
  for (let index = 0; index < coordinates.length; index += markerStride) {
    const point = coordinates[index];
    for (let oy = -2; oy <= 2; oy += 1) for (let ox = -2; ox <= 2; ox += 1) {
      if (ox * ox + oy * oy <= 5) set(Math.round(point.x) + ox, Math.round(point.y) + oy, [238, 222, 255, 255]);
    }
    for (let y = height - bottom + 2; y < height - bottom + 7; y += 1) set(Math.round(point.x), y, [105, 107, 124, 255]);
  }
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y += 1) {
    const row = y * (width * 4 + 1);
    raw[row] = 0;
    pixels.copy(raw, row + 1, y * width * 4, (y + 1) * width * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  return {
    buffer: Buffer.concat([
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
      pngChunk('IHDR', ihdr),
      pngChunk('IDAT', zlib.deflateSync(raw, {level: 9})),
      pngChunk('IEND', Buffer.alloc(0))
    ]),
    points,
    maxValue
  };
};

const flush = () => writeNow();
process.once('beforeExit', flush);
process.once('SIGTERM', () => { try { flush(); } finally { process.exit(0); } });

module.exports = {recordExecution, summary, series, renderGraph, listUsers, getUser, flush, STATS_FILE, ACTIVE_WINDOW_MS};
