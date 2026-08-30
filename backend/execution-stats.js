'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');

const STATS_FILE = process.env.AETHER_STATS_FILE || path.join(__dirname, 'execution-stats.json');
const VERSION = 2;
const RETENTION = Object.freeze({hourly: 24 * 90, daily: 3650, weekly: 520, monthly: 240});
const PERIODS = new Set(['hourly', 'daily', 'weekly', 'monthly']);
const METRICS = new Set(['executions', 'unique']);
const ACCESS = new Set(['free', 'premium']);
const ACTIVE_WINDOW_MS = 150 * 1000;
const MAX_HEARTBEAT_DELTA_SECONDS = 90;
const runtimeSessions = new Map();

const object = value => value && typeof value === 'object' && !Array.isArray(value);
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

const migrate = input => {
  if (!object(input)) throw new Error('Execution analytics file has an invalid structure');
  if (input.version === VERSION) return input;
  if (input.version !== 1) throw new Error('Unsupported execution analytics version');
  return {
    version: VERSION,
    allTimeExecutions: Number.isSafeInteger(input.allTimeExecutions) ? input.allTimeExecutions : 0,
    allUsers: object(input.allUsers) ? input.allUsers : {},
    profiles: {},
    access: {free: 0, premium: 0, unknown: Number.isSafeInteger(input.allTimeExecutions) ? input.allTimeExecutions : 0},
    firstSeenAt: input.firstSeenAt || null,
    lastSeenAt: input.lastSeenAt || null,
    buckets: object(input.buckets) ? input.buckets : {hourly: {}, daily: {}, weekly: {}, monthly: {}}
  };
};

const validBucket = value => object(value) && Number.isSafeInteger(value.executions) && value.executions >= 0 && object(value.users);
const validProfile = value => object(value) && /^\d{1,20}$/.test(String(value.userId || '')) &&
  (value.username === null || value.username === undefined || /^[A-Za-z0-9_]{3,20}$/.test(value.username)) &&
  Number.isSafeInteger(value.executions) && value.executions >= 0 &&
  Number.isSafeInteger(value.freeExecutions) && value.freeExecutions >= 0 &&
  Number.isSafeInteger(value.premiumExecutions) && value.premiumExecutions >= 0 &&
  Number.isSafeInteger(value.unknownExecutions) && value.unknownExecutions >= 0 &&
  Number.isSafeInteger(value.sessions) && value.sessions >= 0 &&
  Number.isFinite(value.trackedSeconds) && value.trackedSeconds >= 0;

const validate = raw => {
  const value = migrate(raw);
  if (!object(value) || value.version !== VERSION || !Number.isSafeInteger(value.allTimeExecutions) || value.allTimeExecutions < 0 ||
      !object(value.allUsers) || !object(value.profiles) || !object(value.access) || !object(value.buckets)) {
    throw new Error('Execution analytics file has an invalid structure');
  }
  for (const key of ['free', 'premium', 'unknown']) {
    if (!Number.isSafeInteger(value.access[key]) || value.access[key] < 0) throw new Error('Execution analytics access totals are invalid');
  }
  for (const [id, profile] of Object.entries(value.profiles)) {
    if (!/^[a-f0-9]{32}$/.test(id) || !validProfile(profile)) throw new Error('Execution analytics profile is invalid');
  }
  for (const period of PERIODS) {
    if (!object(value.buckets[period])) throw new Error('Execution analytics bucket is missing: ' + period);
    for (const bucket of Object.values(value.buckets[period])) if (!validBucket(bucket)) throw new Error('Execution analytics bucket is invalid: ' + period);
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
let flushTimer = null;
let dirty = false;

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

const pad = value => String(value).padStart(2, '0');
const hourKey = date => date.getUTCFullYear() + '-' + pad(date.getUTCMonth() + 1) + '-' + pad(date.getUTCDate()) + 'T' + pad(date.getUTCHours());
const dayKey = date => date.getUTCFullYear() + '-' + pad(date.getUTCMonth() + 1) + '-' + pad(date.getUTCDate());
const monthKey = date => date.getUTCFullYear() + '-' + pad(date.getUTCMonth() + 1);
const weekStart = date => {
  const result = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const weekday = result.getUTCDay() || 7;
  result.setUTCDate(result.getUTCDate() - weekday + 1);
  return result;
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
  const result = new Date(date);
  if (period === 'hourly') result.setUTCHours(result.getUTCHours() + amount);
  else if (period === 'daily') result.setUTCDate(result.getUTCDate() + amount);
  else if (period === 'weekly') result.setUTCDate(result.getUTCDate() + amount * 7);
  else result.setUTCMonth(result.getUTCMonth() + amount);
  return result;
};
const labelFor = (period, date) => {
  if (period === 'hourly') return pad(date.getUTCHours()) + ':00';
  if (period === 'daily') return pad(date.getUTCDate()) + '/' + pad(date.getUTCMonth() + 1);
  if (period === 'weekly') return dayKey(date);
  return monthKey(date);
};
const userHash = value => /^\d{1,20}$/.test(String(value || ''))
  ? crypto.createHash('sha256').update('aetherv2-user\0' + String(value)).digest('hex').slice(0, 32)
  : null;
const validUsername = value => /^[A-Za-z0-9_]{3,20}$/.test(String(value || '')) ? String(value) : null;
const validPlaceId = value => /^\d{1,20}$/.test(String(value || '')) ? String(value) : null;
const validSessionId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{8,80}$/.test(value) ? value : null;

const prune = period => {
  const entries = Object.keys(state.buckets[period]).sort();
  const remove = Math.max(0, entries.length - RETENTION[period]);
  for (let index = 0; index < remove; index += 1) delete state.buckets[period][entries[index]];
};
const profileFor = input => {
  const id = userHash(input && input.userId);
  if (!id) return {id: null, profile: null};
  let profile = state.profiles[id];
  if (!profile) {
    profile = {
      userId: String(input.userId), username: validUsername(input.username), executions: 0,
      freeExecutions: 0, premiumExecutions: 0, unknownExecutions: 0,
      sessions: 0, trackedSeconds: 0, firstSeenAt: null, lastSeenAt: null,
      lastHeartbeatAt: null, lastAccess: 'unknown', lastPlaceId: null
    };
    state.profiles[id] = profile;
  }
  const username = validUsername(input.username);
  if (username) profile.username = username;
  const placeId = validPlaceId(input.placeId);
  if (placeId) profile.lastPlaceId = placeId;
  return {id, profile};
};

const recordLaunch = input => {
  const now = new Date();
  const {id, profile} = profileFor(input || {});
  const requestedAccess = ACCESS.has(input && input.access) ? input.access : 'unknown';
  state.allTimeExecutions += 1;
  state.access[requestedAccess] += 1;
  state.firstSeenAt ||= now.toISOString();
  state.lastSeenAt = now.toISOString();
  if (id) state.allUsers[id] = true;
  if (profile) {
    profile.executions += 1;
    profile[requestedAccess === 'premium' ? 'premiumExecutions' : requestedAccess === 'free' ? 'freeExecutions' : 'unknownExecutions'] += 1;
    profile.firstSeenAt ||= now.toISOString();
    profile.lastSeenAt = now.toISOString();
    if (requestedAccess !== 'unknown') profile.lastAccess = requestedAccess;
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
  return {accepted: true, event: 'execution', uniqueKnown: Boolean(id), profileId: id};
};

const classifyPendingLaunch = (profile, access) => {
  if (!profile || !ACCESS.has(access) || profile.unknownExecutions <= 0 || state.access.unknown <= 0) return false;
  profile.unknownExecutions -= 1;
  profile[access === 'premium' ? 'premiumExecutions' : 'freeExecutions'] += 1;
  state.access.unknown -= 1;
  state.access[access] += 1;
  return true;
};

const recordHeartbeat = input => {
  const now = Date.now();
  const sessionId = validSessionId(input && input.sessionId);
  const access = ACCESS.has(input && input.access) ? input.access : 'free';
  const {id, profile} = profileFor(input || {});
  if (!id || !profile || !sessionId) return {accepted: false, event: 'heartbeat', reason: 'identity-or-session-missing'};
  const runtimeKey = id + ':' + sessionId;
  let session = runtimeSessions.get(runtimeKey);
  if (!session) {
    session = {lastAt: now, access};
    runtimeSessions.set(runtimeKey, session);
    profile.sessions += 1;
    classifyPendingLaunch(profile, access);
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
  return {accepted: true, event: 'heartbeat', profileId: id, classified: true};
};

const recordExecution = async input => {
  const event = String(input && input.event || 'execution').toLowerCase();
  return event === 'heartbeat' ? recordHeartbeat(input) : recordLaunch(input || {});
};

const bucketCount = bucket => ({executions: bucket ? bucket.executions : 0, unique: bucket ? Object.keys(bucket.users).length : 0});
const profilePublic = (id, profile) => ({
  profileId: id,
  userId: profile.userId,
  username: profile.username || null,
  executions: profile.executions,
  freeExecutions: profile.freeExecutions,
  premiumExecutions: profile.premiumExecutions,
  unknownExecutions: profile.unknownExecutions,
  sessions: profile.sessions,
  trackedSeconds: Math.round(profile.trackedSeconds),
  firstSeenAt: profile.firstSeenAt,
  lastSeenAt: profile.lastSeenAt,
  lastHeartbeatAt: profile.lastHeartbeatAt,
  lastAccess: profile.lastAccess,
  lastPlaceId: profile.lastPlaceId,
  active: Boolean(profile.lastHeartbeatAt && Date.now() - Date.parse(profile.lastHeartbeatAt) <= ACTIVE_WINDOW_MS)
});

const summary = () => {
  const now = new Date();
  const profiles = Object.entries(state.profiles).map(([id, profile]) => profilePublic(id, profile));
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
    trackedSeconds: profiles.reduce((total, profile) => total + profile.trackedSeconds, 0),
    firstSeenAt: state.firstSeenAt,
    lastSeenAt: state.lastSeenAt,
    timezone: 'UTC'
  };
};

const listUsers = ({page = 0, pageSize = 8} = {}) => {
  const size = Math.max(1, Math.min(25, Number(pageSize) || 8));
  const users = Object.entries(state.profiles).map(([id, profile]) => profilePublic(id, profile))
    .sort((left, right) => Date.parse(right.lastSeenAt || 0) - Date.parse(left.lastSeenAt || 0) || right.executions - left.executions);
  const pageCount = Math.max(1, Math.ceil(users.length / size));
  const selectedPage = Math.max(0, Math.min(Number(page) || 0, pageCount - 1));
  return {users: users.slice(selectedPage * size, (selectedPage + 1) * size), total: users.length, page: selectedPage, pageCount};
};
const getUser = profileId => /^[a-f0-9]{32}$/.test(String(profileId || '')) && state.profiles[profileId]
  ? profilePublic(profileId, state.profiles[profileId]) : null;

const dailySeries = (days, metric = 'executions') => {
  if (!METRICS.has(metric)) throw new Error('Unknown analytics metric');
  const today = startOf('daily', new Date());
  let count = Math.max(1, Number(days) || 30);
  if (days === 'all') {
    const earliestKey = Object.keys(state.buckets.daily).sort()[0];
    const start = earliestKey ? new Date(earliestKey + 'T00:00:00Z') : state.firstSeenAt ? startOf('daily', new Date(state.firstSeenAt)) : today;
    count = Math.max(1, Math.floor((today - start) / 86400000) + 1);
  }
  const values = [];
  for (let index = count - 1; index >= 0; index -= 1) {
    const date = shift('daily', today, -index);
    const key = keyFor('daily', date);
    const bucket = state.buckets.daily[key];
    values.push({key, label: labelFor('daily', date), value: metric === 'executions' ? (bucket ? bucket.executions : 0) : (bucket ? Object.keys(bucket.users).length : 0)});
  }
  return values;
};

const series = (period, metric = 'executions') => {
  if (['7d', '30d', '90d', 'all'].includes(period)) return dailySeries(period === 'all' ? 'all' : Number(period.slice(0, -1)), metric);
  if (!PERIODS.has(period)) throw new Error('Unknown analytics period');
  const lengths = {hourly: 24, daily: 30, weekly: 12, monthly: 12};
  if (!METRICS.has(metric)) throw new Error('Unknown analytics metric');
  const count = lengths[period];
  const end = startOf(period, new Date());
  const values = [];
  for (let index = count - 1; index >= 0; index -= 1) {
    const date = shift(period, end, -index);
    const bucket = state.buckets[period][keyFor(period, date)];
    values.push({key: keyFor(period, date), label: labelFor(period, date), value: metric === 'executions' ? (bucket ? bucket.executions : 0) : (bucket ? Object.keys(bucket.users).length : 0)});
  }
  return values;
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
  for (const value of buffer) crc = crcTable[(crc ^ value) & 0xff] ^ (crc >>> 1);
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
  const chartWidth = width - left - right, chartHeight = height - top - bottom;
  for (let grid = 0; grid <= 4; grid += 1) {
    const y = Math.round(top + chartHeight * grid / 4);
    for (let x = left; x < width - right; x += 1) set(x, y, [55, 57, 68, 255]);
  }
  const maxValue = Math.max(1, ...points.map(point => point.value));
  const coordinates = points.map((point, index) => ({
    x: left + (points.length === 1 ? 0 : chartWidth * index / (points.length - 1)),
    y: top + chartHeight - (point.value / maxValue) * chartHeight,
    value: point.value,
    label: point.label,
    key: point.key
  }));
  for (let index = 1; index < coordinates.length; index += 1) line(coordinates[index - 1].x, coordinates[index - 1].y, coordinates[index].x, coordinates[index].y, [190, 115, 255, 255]);
  const markerStride = Math.max(1, Math.ceil(points.length / 180));
  for (let index = 0; index < coordinates.length; index += markerStride) {
    const point = coordinates[index];
    for (let oy = -2; oy <= 2; oy += 1) for (let ox = -2; ox <= 2; ox += 1) if (ox * ox + oy * oy <= 5) set(Math.round(point.x) + ox, Math.round(point.y) + oy, [238, 222, 255, 255]);
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
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const buffer = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), pngChunk('IHDR', ihdr),
    pngChunk('IDAT', zlib.deflateSync(raw, {level: 9})), pngChunk('IEND', Buffer.alloc(0))
  ]);
  return {buffer, points, maxValue};
};

const flush = () => writeNow();
process.once('beforeExit', flush);
process.once('SIGTERM', () => { try { flush(); } finally { process.exit(0); } });

module.exports = {recordExecution, summary, series, renderGraph, listUsers, getUser, flush, STATS_FILE, ACTIVE_WINDOW_MS};
