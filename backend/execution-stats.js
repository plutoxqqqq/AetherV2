'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');

const STATS_FILE = process.env.AETHER_STATS_FILE || path.join(__dirname, 'execution-stats.json');
const VERSION = 1;
const SERIES_LENGTHS = Object.freeze({hourly: 24, daily: 30, weekly: 12, monthly: 12});
const RETENTION = Object.freeze({hourly: 24 * 90, daily: 730, weekly: 260, monthly: 120});
const PERIODS = new Set(Object.keys(SERIES_LENGTHS));
const METRICS = new Set(['executions', 'unique']);

const emptyState = () => ({
  version: VERSION,
  allTimeExecutions: 0,
  allUsers: {},
  firstSeenAt: null,
  lastSeenAt: null,
  buckets: {hourly: {}, daily: {}, weekly: {}, monthly: {}}
});

const object = value => value && typeof value === 'object' && !Array.isArray(value);
const validBucket = value => object(value) && Number.isSafeInteger(value.executions) && value.executions >= 0 && object(value.users);
const validate = value => {
  if (!object(value) || value.version !== VERSION || !Number.isSafeInteger(value.allTimeExecutions) || value.allTimeExecutions < 0 || !object(value.allUsers) || !object(value.buckets)) {
    throw new Error('Execution analytics file has an invalid structure');
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
  else if (period === 'weekly') result.setUTCDate(result.getUTCDate() + (amount * 7));
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

const prune = period => {
  const entries = Object.keys(state.buckets[period]).sort();
  const remove = Math.max(0, entries.length - RETENTION[period]);
  for (let index = 0; index < remove; index += 1) delete state.buckets[period][entries[index]];
};

const recordExecution = async input => {
  const now = new Date();
  const hashedUser = userHash(input && input.userId);
  state.allTimeExecutions += 1;
  state.firstSeenAt ||= now.toISOString();
  state.lastSeenAt = now.toISOString();
  if (hashedUser) state.allUsers[hashedUser] = true;

  for (const period of PERIODS) {
    const key = keyFor(period, now);
    const bucket = state.buckets[period][key] || {executions: 0, users: {}};
    bucket.executions += 1;
    if (hashedUser) bucket.users[hashedUser] = true;
    state.buckets[period][key] = bucket;
    prune(period);
  }
  scheduleWrite();
  return {accepted: true, uniqueKnown: Boolean(hashedUser)};
};

const bucketCount = bucket => ({
  executions: bucket ? bucket.executions : 0,
  unique: bucket ? Object.keys(bucket.users).length : 0
});

const summary = () => {
  const now = new Date();
  return {
    hourly: bucketCount(state.buckets.hourly[keyFor('hourly', now)]),
    daily: bucketCount(state.buckets.daily[keyFor('daily', now)]),
    weekly: bucketCount(state.buckets.weekly[keyFor('weekly', now)]),
    monthly: bucketCount(state.buckets.monthly[keyFor('monthly', now)]),
    allTime: {executions: state.allTimeExecutions, unique: Object.keys(state.allUsers).length},
    firstSeenAt: state.firstSeenAt,
    lastSeenAt: state.lastSeenAt,
    timezone: 'UTC'
  };
};

const series = (period, metric = 'executions') => {
  if (!PERIODS.has(period)) throw new Error('Unknown analytics period');
  if (!METRICS.has(metric)) throw new Error('Unknown analytics metric');
  const count = SERIES_LENGTHS[period];
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
    label: point.label
  }));
  for (let index = 1; index < coordinates.length; index += 1) {
    line(coordinates[index - 1].x, coordinates[index - 1].y, coordinates[index].x, coordinates[index].y, [190, 115, 255, 255]);
  }
  for (const point of coordinates) {
    for (let oy = -2; oy <= 2; oy += 1) for (let ox = -2; ox <= 2; ox += 1) if ((ox * ox) + (oy * oy) <= 5) set(Math.round(point.x) + ox, Math.round(point.y) + oy, [238, 222, 255, 255]);
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
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', zlib.deflateSync(raw, {level: 9})),
    pngChunk('IEND', Buffer.alloc(0))
  ]);
  return {buffer, points, maxValue};
};

const flush = () => writeNow();
process.once('beforeExit', flush);
process.once('SIGTERM', () => { try { flush(); } finally { process.exit(0); } });

module.exports = {recordExecution, summary, series, renderGraph, flush, STATS_FILE, SERIES_LENGTHS};
