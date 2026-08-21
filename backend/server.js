'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {createDatabase} = require('./lib/database');
const {canonical, hash, safeEqual, receiptMatches, RateLimiter} = require('./lib/security');
const {GitHubPublisher, validFile} = require('./lib/publisher');

const API_VERSION = '2';
const MAX_BODY = 2 * 1024 * 1024;
const categories = new Set(['Closet', 'Semi-Closet', 'Blatant']);
const writable = new Set(['POST', 'PATCH', 'PUT', 'DELETE']);

function httpError(status, message, details) {
  return Object.assign(Error(message), {status, details});
}

function parseAllowedOrigins(value) {
  return new Set(String(value || 'https://www.roblox.com,https://roblox.com,https://create.roblox.com')
    .split(',').map(item => item.trim()).filter(Boolean));
}

function requestIp(req, trustProxy) {
  if (trustProxy) {
    const forwarded = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
    if (forwarded) return forwarded;
  }
  return req.socket.remoteAddress || 'unknown';
}

function requestId(req) {
  const supplied = String(req.headers['x-request-id'] || '');
  return /^[A-Za-z0-9._-]{8,128}$/.test(supplied) ? supplied : crypto.randomUUID();
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let bytes = 0;
    let settled = false;
    req.setEncoding('utf8');
    req.on('data', chunk => {
      if (settled) return;
      bytes += Buffer.byteLength(chunk);
      if (bytes > MAX_BODY) {
        settled = true;
        // Keep consuming the request after responding. Leaving an oversized
        // stream paused keeps its socket and parser work alive unnecessarily.
        req.resume();
        reject(httpError(413, 'Request body is too large'));
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (settled) return;
      try { resolve(JSON.parse(chunks.join('') || '{}')); }
      catch { reject(httpError(400, 'Invalid JSON')); }
    });
    req.on('error', error => { if (!settled) reject(error); });
  });
}

function validateString(value, name, options = {}) {
  const min = options.min === undefined ? 1 : options.min;
  const max = options.max === undefined ? 128 : options.max;
  if (options.optional && (value === undefined || value === null || value === '')) return undefined;
  if (typeof value !== 'string') throw httpError(400, name + ' must be a string');
  const result = value.trim();
  if (result.length < min || result.length > max) throw httpError(400, name + ' must be ' + min + '-' + max + ' characters');
  return result;
}

function validateUserId(value) {
  const result = Number(value);
  if (!Number.isSafeInteger(result) || result < 1) throw httpError(400, 'userId must be a positive integer');
  return result;
}

function validateTags(value, optional = false) {
  if (optional && value === undefined) return undefined;
  if (!Array.isArray(value) || value.length < 1 || value.length > 10) throw httpError(400, 'tags must contain 1-10 values');
  const tags = [...new Set(value.map(item => validateString(item, 'tag', {max: 24})))];
  if (!tags.length) throw httpError(400, 'tags cannot be empty');
  return tags;
}

function validateStringArray(value, name, options = {}) {
  if (options.optional && value === undefined) return undefined;
  if (!Array.isArray(value) || value.length > (options.count || 5)) throw httpError(400, name + ' must be an array');
  return [...new Set(value.map(item => validateString(item, name, {max: options.max || 240})))];
}

function validateConfig(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw httpError(400, 'config must be a JSON object');
  return value;
}

function submissionSchema(value, update = false) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw httpError(400, 'Request body must be an object');
  const result = {
    name: validateString(value.name, 'name', {max: 64}),
    displayName: validateString(value.displayName, 'displayName', {max: 64, optional: true}),
    submitter: validateString(value.submitter, 'submitter', {max: 32}),
    userId: validateUserId(value.userId),
    game: validateString(String(value.game || ''), 'game', {max: 32}),
    config: validateConfig(value.config),
    gui: value.gui && typeof value.gui === 'object' && !Array.isArray(value.gui) ? value.gui : undefined,
    minimumVersion: validateString(value.minimumVersion, 'minimumVersion', {max: 32, optional: true}),
    gameVersion: validateString(value.gameVersion, 'gameVersion', {max: 64, optional: true}),
    screenshots: validateStringArray(value.screenshots, 'screenshots', {count: 4, max: 300, optional: true}),
    forkOf: validateString(value.forkOf, 'forkOf', {max: 128, optional: true})
  };
  if (update) {
    result.changelog = validateString(value.changelog, 'changelog', {max: 500});
    result.creator = validateString(value.creator, 'creator', {max: 64, optional: true});
    result.category = validateString(value.category, 'category', {max: 24, optional: true});
    if (result.category && !categories.has(result.category)) throw httpError(400, 'Invalid category');
    result.description = validateString(value.description, 'description', {max: 500, optional: true});
    result.tags = validateTags(value.tags, true);
    if (value.deprecated !== undefined) result.deprecated = Boolean(value.deprecated);
  } else {
    result.creator = validateString(value.creator, 'creator', {max: 64});
    result.category = validateString(value.category, 'category', {max: 24});
    if (!categories.has(result.category)) throw httpError(400, 'Invalid category');
    result.description = validateString(value.description, 'description', {max: 500});
    result.tags = validateTags(value.tags);
  }
  return result;
}

function createApp(options = {}) {
  const env = options.env || process.env;
  const database = options.database || createDatabase({file: env.DATA_FILE || path.join(__dirname, 'data.json')});
  const publisher = options.publisher || new GitHubPublisher(env);
  const limiter = options.limiter || new RateLimiter({
    windowMs: Number(env.RATE_WINDOW_MS || 60000),
    readLimit: Number(env.RATE_READ_LIMIT || 180),
    writeLimit: Number(env.RATE_WRITE_LIMIT || 20)
  });
  const allowedOrigins = parseAllowedOrigins(env.ALLOWED_ORIGINS);
  const adminKey = env.ADMIN_KEY || '';
  const verifiedCreators = new Set(String(env.VERIFIED_CREATORS || '').split(',').map(value => value.trim().toLowerCase()).filter(Boolean));
  const trustProxy = env.TRUST_PROXY === 'true';
  const localConfigFolder = path.resolve(__dirname, '..', 'configs');

  function responseHeaders(context, extra = {}) {
    const headers = {
      'content-type': 'application/json; charset=utf-8',
      'x-request-id': context.id,
      'x-aether-api-version': API_VERSION,
      'x-content-type-options': 'nosniff',
      'cache-control': 'no-store',
      vary: 'origin',
      ...extra
    };
    if (context.origin) headers['access-control-allow-origin'] = context.origin;
    return headers;
  }

  function send(res, context, status, value, extra) {
    res.writeHead(status, responseHeaders(context, extra));
    if (status === 204 || status === 304) return res.end();
    return res.end(JSON.stringify(value));
  }

  function isAdmin(req) {
    return Boolean(adminKey) && safeEqual(req.headers.authorization, 'Bearer ' + adminKey);
  }

  async function audit(context, action, target, outcome = 'success', metadata = {}) {
    await database.transaction(data => {
      data.audit.push({
        id: crypto.randomUUID(),
        requestId: context.id,
        at: new Date().toISOString(),
        actor: hash(context.ip).slice(0, 24),
        action,
        target: String(target || ''),
        outcome,
        metadata
      });
      if (data.audit.length > 5000) data.audit.splice(0, data.audit.length - 5000);
    });
  }

  function localManifest() {
    try {
      const parsed = JSON.parse(fs.readFileSync(path.join(localConfigFolder, 'presets.json'), 'utf8'));
      return Array.isArray(parsed.presets) ? parsed : {presets: []};
    } catch {
      return {presets: []};
    }
  }

  async function manifest() {
    if (!publisher.configured) return localManifest();
    const parsed = JSON.parse((await publisher.getFile('presets.json')).decoded);
    return Array.isArray(parsed.presets) ? parsed : {presets: []};
  }

  async function publicFile(file) {
    if (!validFile(file)) throw httpError(400, 'Invalid public config file');
    if (publisher.configured) return (await publisher.getFile(file)).decoded;
    try { return fs.readFileSync(path.join(localConfigFolder, file), 'utf8'); }
    catch { throw httpError(404, 'Public Config not found'); }
  }

  async function isPublishedDuplicate(configHash, items) {
    for (const item of items) {
      if (item.hash === configHash) return true;
      if (!item.hash && validFile(item.file)) {
        try {
          const wrapper = JSON.parse(await publicFile(item.file));
          const config = typeof wrapper.config === 'string' ? JSON.parse(wrapper.config) : wrapper.config;
          if (hash(config) === configHash) return true;
        } catch {}
      }
    }
    return false;
  }

  function enrichPresets(items, data, userId, clientId) {
    const voter = userId && clientId ? String(userId) + ':' + hash(clientId).slice(0, 24) : undefined;
    return items.map(preset => {
      const stats = data.publicConfigs[preset.file] || {};
      const ratings = data.ratings[preset.file] || {};
      const values = Object.values(ratings);
      const likes = values.filter(value => value === 1).length;
      const dislikes = values.filter(value => value === -1).length;
      const ratingCount = likes + dislikes;
      const userRating = voter ? ratings[voter] : undefined;
      const favorites = data.favorites[preset.file] || {};
      const creatorKey = String(preset.credits || '').toLowerCase();
      return {
        ...preset,
        downloads: Number(stats.downloads || preset.downloads || 0),
        likes,
        dislikes,
        ratingCount,
        ratingPercentage: ratingCount ? Math.round(likes / ratingCount * 100) : 0,
        userRating,
        favoriteCount: Object.keys(favorites).length,
        favorited: voter ? Boolean(favorites[voter]) : false,
        verifiedCreator: verifiedCreators.has(creatorKey) || data.creators[creatorKey]?.verified === true
      };
    });
  }

  function sortPresets(items, mode) {
    const copy = [...items];
    const date = item => Date.parse(item.updatedAt || item.lastPublishedAt || item.createdAt || 0) || 0;
    const score = item => (item.downloads || 0) + (item.likes || 0) * 4 - (item.dislikes || 0) * 2;
    const comparators = {
      'most-downloaded': (a, b) => b.downloads - a.downloads,
      'highest-rated': (a, b) => (b.ratingPercentage - a.ratingPercentage) || (b.ratingCount - a.ratingCount),
      newest: (a, b) => date(b) - date(a),
      'recently-updated': (a, b) => date(b) - date(a),
      trending: (a, b) => score(b) - score(a)
    };
    return copy.sort(comparators[mode] || comparators.trending);
  }

  async function handler(req, res) {
    const requestedOrigin = String(req.headers.origin || '') || undefined;
    const context = {
      id: requestId(req),
      ip: requestIp(req, trustProxy),
      origin: requestedOrigin && allowedOrigins.has(requestedOrigin) ? requestedOrigin : undefined
    };
    let rateHeaders = {};
    try {
      if (requestedOrigin && !context.origin) throw httpError(403, 'Origin is not allowed');
      const limited = limiter.take(context.ip, writable.has(req.method));
      rateHeaders = {'x-ratelimit-limit': String(limited.limit), 'x-ratelimit-remaining': String(limited.remaining)};
      if (!limited.allowed) return send(res, context, 429, {success: false, error: 'Rate limit exceeded'}, {...rateHeaders, 'retry-after': String(limited.retryAfter)});
      if (req.method === 'OPTIONS') {
        return send(res, context, 204, null, {
          ...rateHeaders,
          'access-control-allow-headers': 'authorization,content-type,x-aether-receipt,x-request-id',
          'access-control-allow-methods': 'GET,POST,PATCH,DELETE,OPTIONS',
          'access-control-max-age': '600'
        });
      }

      const url = new URL(req.url, 'http://localhost');
      const pathname = url.pathname.replace(/^\/v2(?=\/|$)/, '') || '/';
      if (req.method === 'GET' && pathname === '/health') {
        return send(res, context, 200, {success: true, apiVersion: API_VERSION, storage: database.constructor.name, publishing: publisher.configured ? publisher.mode : 'disabled'}, rateHeaders);
      }

      if (req.method === 'POST' && pathname === '/submissions') {
        const value = submissionSchema(await readBody(req));
        if (value.forkOf && !(await manifest()).presets.some(item => item.file === value.forkOf)) throw httpError(400, 'forkOf must identify a published config');
        const configHash = hash(value.config);
        const published = (await manifest()).presets || [];
        if (await isPublishedDuplicate(configHash, published)) throw httpError(409, 'An identical config is already published');
        let token;
        const item = await database.transaction(data => {
          if (data.submissions.some(entry => entry.configHash === configHash || (!entry.configHash && canonical(entry.config) === canonical(value.config)))) {
            throw httpError(409, 'An identical config has already been submitted');
          }
          token = crypto.randomBytes(32).toString('hex');
          const created = {...value, id: crypto.randomUUID(), receiptHash: hash(token), configHash, type: 'new', status: 'pending', createdAt: new Date().toISOString()};
          data.submissions.push(created);
          return created;
        });
        await audit(context, 'submission.create', item.id, 'success', {hash: configHash});
        return send(res, context, 201, {success: true, id: item.id, token, status: item.status}, rateHeaders);
      }

      const updateMatch = pathname.match(/^\/public-configs\/([^/]+)\/updates$/);
      if (req.method === 'POST' && updateMatch) {
        const file = decodeURIComponent(updateMatch[1]);
        if (!validFile(file)) throw httpError(400, 'Invalid public config file');
        const raw = await readBody(req);
        const value = submissionSchema(raw, true);
        const owner = (await database.read()).submissions.find(item => item.file === file && item.status === 'accepted' && Number(item.userId) === value.userId && receiptMatches(raw.ownerToken, item));
        if (!owner) throw httpError(401, 'A valid ownership receipt is required');
        const configHash = hash(value.config);
        let token;
        const item = await database.transaction(data => {
          if (data.submissions.some(entry => entry.configHash === configHash)) throw httpError(409, 'An identical config has already been submitted');
          token = crypto.randomBytes(32).toString('hex');
          const created = {
            ...value,
            creator: value.creator || owner.creator,
            category: value.category || owner.category,
            description: value.description || owner.description,
            tags: value.tags || owner.tags,
            id: crypto.randomUUID(),
            receiptHash: hash(token),
            configHash,
            type: 'update',
            targetFile: file,
            status: 'pending',
            createdAt: new Date().toISOString()
          };
          data.submissions.push(created);
          return created;
        });
        await audit(context, 'submission.update', file, 'success', {submissionId: item.id, hash: configHash});
        const current = (await manifest()).presets.find(entry => entry.file === file);
        return send(res, context, 201, {success: true, id: item.id, token, status: item.status, targetVersion: Number(current?.version || 0) + 1}, rateHeaders);
      }

      if (req.method === 'GET' && pathname === '/submissions') {
        if (!isAdmin(req)) throw httpError(401, 'Maintainer authentication required');
        const status = url.searchParams.get('status');
        const items = (await database.read()).submissions.filter(item => !status || item.status === status)
          .map(({receiptHash, token, config, gui, ...item}) => item);
        await audit(context, 'submission.list', status || 'all');
        return send(res, context, 200, {success: true, submissions: items}, rateHeaders);
      }

      const submissionMatch = pathname.match(/^\/submissions\/([^/]+)$/);
      if (submissionMatch && req.method === 'GET') {
        const item = (await database.read()).submissions.find(entry => entry.id === decodeURIComponent(submissionMatch[1]));
        if (!item) throw httpError(404, 'Submission not found');
        const token = req.headers['x-aether-receipt'] || url.searchParams.get('token');
        if (!receiptMatches(token, item) && !isAdmin(req)) throw httpError(401, 'Invalid receipt');
        return send(res, context, 200, {
          success: true,
          id: item.id,
          name: item.name,
          displayName: item.displayName || item.name,
          status: item.status,
          reason: item.reason,
          decidedAt: item.decidedAt,
          file: item.file,
          publishedFile: item.file,
          version: item.version,
          submissionType: item.type,
          pullRequestUrl: item.pullRequestUrl
        }, rateHeaders);
      }

      if (submissionMatch && req.method === 'PATCH') {
        if (!isAdmin(req)) throw httpError(401, 'Maintainer authentication required');
        const decision = await readBody(req);
        if (!['accept', 'reject'].includes(decision.action)) throw httpError(400, 'action must be accept or reject');
        const id = decodeURIComponent(submissionMatch[1]);
        const item = (await database.read()).submissions.find(entry => entry.id === id);
        if (!item) throw httpError(404, 'Submission not found');
        if (item.status !== 'pending') throw httpError(409, 'Submission already reviewed');
        const publication = decision.action === 'accept' ? await publisher.publish(item, context.id) : undefined;
        const decided = await database.transaction(data => {
          const current = data.submissions.find(entry => entry.id === id);
          if (!current || current.status !== 'pending') throw httpError(409, 'Submission already reviewed');
          current.status = decision.action === 'accept' ? 'accepted' : 'declined';
          current.reason = validateString(String(decision.reason || ''), 'reason', {min: 0, max: 500, optional: true}) || '';
          current.decidedAt = new Date().toISOString();
          if (publication) {
            Object.assign(current, {file: publication.file, version: publication.version, publishedHash: publication.hash, branch: publication.branch, pullRequest: publication.pullRequest, pullRequestUrl: publication.pullRequestUrl});
            const stats = data.publicConfigs[publication.file] || {downloads: 0, versions: []};
            stats.versions = Array.isArray(stats.versions) ? stats.versions : [];
            stats.versions.push({
              version: publication.version,
              versionLabel: 'v' + publication.version,
              hash: publication.hash,
              at: current.decidedAt,
              publishedAt: current.decidedAt,
              changelog: current.changelog || 'Initial publication'
            });
            data.publicConfigs[publication.file] = stats;
          }
          return current;
        });
        await audit(context, 'submission.' + decision.action, id, 'success', publication || {});
        return send(res, context, 200, {success: true, id, status: decided.status, file: decided.file, version: decided.version, pullRequest: decided.pullRequest, pullRequestUrl: decided.pullRequestUrl}, rateHeaders);
      }

      if (req.method === 'GET' && pathname === '/public-configs') {
        const catalogue = await manifest();
        const rawUserId = url.searchParams.get('userId');
        const userId = rawUserId === null ? undefined : validateUserId(rawUserId);
        const rawClientId = url.searchParams.get('clientId');
        const clientId = userId && rawClientId ? validateString(rawClientId, 'clientId', {min: 16, max: 80}) : undefined;
        const presets = enrichPresets(catalogue.presets || [], await database.read(), userId, clientId);
        return send(res, context, 200, {success: true, apiVersion: API_VERSION, presets: sortPresets(presets, url.searchParams.get('sort'))}, {...rateHeaders, 'cache-control': 'public, max-age=30'});
      }

      const versionsMatch = pathname.match(/^\/public-configs\/([^/]+)\/versions$/);
      if (req.method === 'GET' && versionsMatch) {
        const file = decodeURIComponent(versionsMatch[1]);
        const stats = (await database.read()).publicConfigs[file] || {};
        return send(res, context, 200, {success: true, file, versions: stats.versions || []}, rateHeaders);
      }

      const ratingsMatch = pathname.match(/^\/public-configs\/([^/]+)\/ratings$/);
      if (req.method === 'POST' && ratingsMatch) {
        const file = decodeURIComponent(ratingsMatch[1]);
        if (!validFile(file)) throw httpError(400, 'Invalid public config file');
        const value = await readBody(req);
        const userId = validateUserId(value.userId);
        const clientId = validateString(value.clientId, 'clientId', {min: 16, max: 80});
        const rating = value.rating === 'like' ? 1 : value.rating === 'dislike' ? -1 : Number(value.rating);
        if (rating !== 1 && rating !== -1) throw httpError(400, 'rating must be 1 or -1');
        const voter = String(userId) + ':' + hash(clientId).slice(0, 24);
        const result = await database.transaction(data => {
          data.ratings[file] = data.ratings[file] || {};
          data.ratings[file][voter] = rating;
          const values = Object.values(data.ratings[file]);
          const likes = values.filter(item => item === 1).length;
          const dislikes = values.filter(item => item === -1).length;
          return {likes, dislikes, ratingCount: likes + dislikes, ratingPercentage: likes + dislikes ? Math.round(likes / (likes + dislikes) * 100) : 0, userRating: rating};
        });
        await audit(context, 'rating.set', file, 'success', {userId, rating});
        return send(res, context, 200, {success: true, ...result}, rateHeaders);
      }

      const favoritesMatch = pathname.match(/^\/public-configs\/([^/]+)\/favorites$/);
      if (req.method === 'POST' && favoritesMatch) {
        const file = decodeURIComponent(favoritesMatch[1]);
        if (!validFile(file)) throw httpError(400, 'Invalid public config file');
        const value = await readBody(req);
        const userId = validateUserId(value.userId);
        const clientId = validateString(value.clientId, 'clientId', {min: 16, max: 80});
        const voter = String(userId) + ':' + hash(clientId).slice(0, 24);
        const result = await database.transaction(data => {
          data.favorites[file] = data.favorites[file] || {};
          if (value.favorite === false) delete data.favorites[file][voter];
          else data.favorites[file][voter] = new Date().toISOString();
          return {favorited: Boolean(data.favorites[file][voter]), favoriteCount: Object.keys(data.favorites[file]).length};
        });
        await audit(context, 'favorite.set', file, 'success', {userId, favorited: result.favorited});
        return send(res, context, 200, {success: true, ...result}, rateHeaders);
      }

      const reportsMatch = pathname.match(/^\/public-configs\/([^/]+)\/reports$/);
      if (req.method === 'POST' && reportsMatch) {
        const file = decodeURIComponent(reportsMatch[1]);
        if (!validFile(file)) throw httpError(400, 'Invalid public config file');
        const value = await readBody(req);
        const report = {
          id: crypto.randomUUID(),
          file,
          userId: validateUserId(value.userId),
          reason: validateString(value.reason, 'reason', {min: 4, max: 500}),
          createdAt: new Date().toISOString(),
          status: 'open'
        };
        await database.transaction(data => {
          if (data.reports.some(item => item.file === file && item.userId === report.userId && item.status === 'open')) throw httpError(409, 'You already have an open report for this config');
          data.reports.push(report);
        });
        await audit(context, 'report.create', file, 'success', {reportId: report.id, userId: report.userId});
        return send(res, context, 201, {success: true, id: report.id}, rateHeaders);
      }

      if (req.method === 'GET' && pathname === '/reports') {
        if (!isAdmin(req)) throw httpError(401, 'Maintainer authentication required');
        return send(res, context, 200, {success: true, reports: (await database.read()).reports}, rateHeaders);
      }

      const creatorMatch = pathname.match(/^\/creators\/([^/]+)$/);
      if (req.method === 'GET' && creatorMatch) {
        const name = decodeURIComponent(creatorMatch[1]);
        const catalogue = enrichPresets((await manifest()).presets || [], await database.read());
        const configs = catalogue.filter(item => String(item.credits || '').toLowerCase() === name.toLowerCase());
        if (!configs.length) throw httpError(404, 'Creator not found');
        return send(res, context, 200, {
          success: true,
          creator: name,
          verified: configs.some(item => item.verifiedCreator),
          downloads: configs.reduce((total, item) => total + Number(item.downloads || 0), 0),
          configs
        }, {...rateHeaders, 'cache-control': 'public, max-age=30'});
      }

      const publicMatch = pathname.match(/^\/public-configs\/([^/]+)$/);
      if (req.method === 'GET' && publicMatch) {
        const file = decodeURIComponent(publicMatch[1]);
        const content = await publicFile(file);
        const etag = '"sha256-' + hash(content) + '"';
        if (req.headers['if-none-match'] === etag) return send(res, context, 304, null, {...rateHeaders, etag});
        const client = String(url.searchParams.get('clientId') || String(url.searchParams.get('userId') || 'guest') + ':' + context.ip);
        const downloadKey = hash(client).slice(0, 32);
        await database.transaction(data => {
          const stats = data.publicConfigs[file] || {downloads: 0, versions: [], downloadKeys: []};
          stats.downloadKeys = Array.isArray(stats.downloadKeys) ? stats.downloadKeys : [];
          if (!stats.downloadKeys.includes(downloadKey)) {
            stats.downloadKeys.push(downloadKey);
            stats.downloads = Number(stats.downloads || 0) + 1;
            if (stats.downloadKeys.length > 5000) stats.downloadKeys.splice(0, stats.downloadKeys.length - 5000);
          }
          data.publicConfigs[file] = stats;
        });
        res.writeHead(200, responseHeaders(context, {...rateHeaders, etag, 'cache-control': 'public, max-age=60'}));
        return res.end(content);
      }

      const deleteMatch = pathname.match(/^\/public-configs\/([^/]+)$/);
      if (req.method === 'DELETE' && deleteMatch) {
        const file = decodeURIComponent(deleteMatch[1]);
		const value = await readBody(req);
		const owner = !isAdmin(req) && (await database.read()).submissions.find(item =>
			item.file === file && item.status === 'accepted' && Number(item.userId) === Number(value.userId) && receiptMatches(value.ownerToken, item)
		);
		if (!isAdmin(req) && !owner) throw httpError(401, value.ownerToken ? 'A valid ownership receipt is required' : 'Maintainer authentication required');
        const removed = await publisher.remove(file, context.id);
        await database.transaction(data => { delete data.publicConfigs[file]; delete data.ratings[file]; delete data.favorites[file]; });
        await audit(context, 'public-config.delete', file, 'success', removed);
        return send(res, context, 200, {success: true, status: 'pending-merge', ...removed}, rateHeaders);
      }

      if (req.method === 'DELETE' && pathname === '/public-configs') {
        if (!isAdmin(req)) throw httpError(401, 'Maintainer authentication required');
        const file = validateString((await readBody(req)).file, 'file', {max: 128});
        const removed = await publisher.remove(file, context.id);
        await audit(context, 'public-config.delete', file, 'success', removed);
        return send(res, context, 200, {success: true, status: 'pending-merge', ...removed}, rateHeaders);
      }

      return send(res, context, 404, {success: false, error: 'Not found'}, rateHeaders);
    } catch (error) {
      const status = Number(error.status) || 500;
      if (writable.has(req.method)) {
        try { await audit(context, 'request.failure', req.url, 'failure', {status, error: String(error.message || 'Operation failed')}); } catch {}
      }
      return send(res, context, status, {success: false, error: error.message || 'Operation failed', ...(error.details && {details: error.details})}, rateHeaders);
    }
  }

  const server = http.createServer(handler);
  return {server, handler, database, publisher, limiter};
}

const app = createApp();
if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  app.server.listen(port, () => console.log('Aether config backend v' + API_VERSION + ' listening on ' + port));
}

module.exports = {server: app.server, createApp, canonical, hash, API_VERSION};
