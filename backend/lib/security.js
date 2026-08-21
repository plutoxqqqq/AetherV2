'use strict';

const crypto = require('node:crypto');

function sortValue(value) {
  if (Array.isArray(value)) return value.map(sortValue);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map(key => [key, sortValue(value[key])]));
  }
  return value;
}

function canonical(value) {
  return JSON.stringify(sortValue(value));
}

function hash(value) {
  return crypto.createHash('sha256').update(typeof value === 'string' ? value : canonical(value)).digest('hex');
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left || ''));
  const b = Buffer.from(String(right || ''));
  return a.length === b.length && a.length > 0 && crypto.timingSafeEqual(a, b);
}

function receiptMatches(token, item) {
  if (!token || !item) return false;
  return item.receiptHash ? safeEqual(hash(token), item.receiptHash) : safeEqual(token, item.token);
}

class RateLimiter {
  constructor({windowMs = 60_000, readLimit = 180, writeLimit = 20} = {}) {
    this.windowMs = windowMs;
    this.readLimit = readLimit;
    this.writeLimit = writeLimit;
    this.buckets = new Map();
  }

  take(key, write = false, now = Date.now()) {
    const limit = write ? this.writeLimit : this.readLimit;
    const bucketKey = `${key}:${write ? 'write' : 'read'}`;
    let bucket = this.buckets.get(bucketKey);
    if (!bucket || now >= bucket.resetAt) bucket = {count: 0, resetAt: now + this.windowMs};
    bucket.count += 1;
    this.buckets.set(bucketKey, bucket);
    if (this.buckets.size > 10_000) {
      for (const [name, value] of this.buckets) if (now >= value.resetAt) this.buckets.delete(name);
    }
    return {
      allowed: bucket.count <= limit,
      limit,
      remaining: Math.max(0, limit - bucket.count),
      retryAfter: Math.max(1, Math.ceil((bucket.resetAt - now) / 1000))
    };
  }
}

module.exports = {canonical, hash, safeEqual, receiptMatches, RateLimiter};
