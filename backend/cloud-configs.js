'use strict';

const crypto = require('node:crypto');

const REPOSITORY = process.env.GITHUB_REPO || '';
const TOKEN = process.env.GITHUB_TOKEN || '';
const BRANCH = process.env.AETHER_CLOUD_BRANCH || process.env.AETHER_REGISTRY_BRANCH || 'aether-key-registry';
const CLOUD_FILE = process.env.AETHER_CLOUD_FILE || 'backend/cloud-configs.json';
const STORE_VERSION = 1;
const MAX_CONFIGS_PER_KEY = 5;
const MAX_PAYLOAD_BYTES = 1024 * 1024;
const SHARE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const boundedNumber = (value, fallback, min, max) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
};

const REQUEST_TIMEOUT_MS = boundedNumber(process.env.AETHER_REQUEST_TIMEOUT_MS, 8000, 1000, 30000);
const REQUEST_RETRIES = boundedNumber(process.env.AETHER_GITHUB_RETRIES, 3, 0, 6);
const MUTATION_ATTEMPTS = boundedNumber(process.env.AETHER_GITHUB_CONFLICT_RETRIES, 4, 1, 8);
const RETRY_BASE_MS = boundedNumber(process.env.AETHER_RETRY_BASE_MS, 150, 0, 5000);
let storeQueue = Promise.resolve();

if (!TOKEN) throw new Error('GITHUB_TOKEN is required');
if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(REPOSITORY)) throw new Error('GITHUB_REPO must be configured as owner/repository');
if (!BRANCH || BRANCH.length > 200) throw new Error('AETHER_CLOUD_BRANCH is invalid');

const headers = {
  authorization: 'Bearer ' + TOKEN,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-cloud-configs',
  'x-github-api-version': '2022-11-28'
};

const problem = (message, status = 400, extra = {}) => Object.assign(new Error(message), {status, ...extra});
const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const wait = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const nowIso = () => new Date().toISOString();
const retryStatus = status => status === 408 || status === 429 || status >= 500;
const validIsoDate = value => typeof value === 'string' && Number.isFinite(Date.parse(value));
const validKeyId = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const validConfigId = value => typeof value === 'string' && /^[a-f0-9-]{16,64}$/i.test(value);
const validShareCode = value => typeof value === 'string' && /^[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(value);
const validPlaceId = value => /^\d{1,20}$/.test(String(value || ''));

const cleanName = value => {
  const name = String(value || '').replace(/[\u0000-\u001f\u007f]/g, '').trim();
  if (!name || name.length > 60) throw problem('Cloud config names must be 1-60 characters', 400);
  return name;
};

const validatePayload = value => {
  if (typeof value !== 'string' || value.length === 0) throw problem('Config payload is required', 400);
  if (Buffer.byteLength(value, 'utf8') > MAX_PAYLOAD_BYTES) throw problem('Config payload is too large', 413);
  let parsed;
  try { parsed = JSON.parse(value); }
  catch { throw problem('Config payload must be valid Aether JSON', 400); }
  if (!isObject(parsed)) throw problem('Config payload must be an Aether config object', 400);
  return value;
};

const emptyStore = () => ({version: STORE_VERSION, configs: {}, shares: {}});

const validateBackup = backup => {
  if (backup === null) return;
  if (!isObject(backup) || typeof backup.payload !== 'string' || !validIsoDate(backup.savedAt)) {
    throw problem('Cloud config backup is invalid', 502);
  }
  validatePayload(backup.payload);
};

const validateCopy = copy => {
  if (copy === null) return;
  if (!isObject(copy) || !validShareCode(copy.sourceCode) || typeof copy.syncEnabled !== 'boolean' ||
      (copy.sourceUpdatedAt !== null && !validIsoDate(copy.sourceUpdatedAt))) {
    throw problem('Cloud config copy metadata is invalid', 502);
  }
};

const validateConfig = (id, config) => {
  if (!validConfigId(id) || !isObject(config) || config.id !== id) throw problem('Cloud config record is invalid', 502);
  if (!validKeyId(config.ownerKeyId)) throw problem('Cloud config owner key is invalid', 502);
  if (!/^[A-Za-z0-9_]{3,20}$/.test(String(config.ownerUsername || ''))) throw problem('Cloud config owner username is invalid', 502);
  if (!validPlaceId(config.ownerUserId) || !validPlaceId(config.placeId)) throw problem('Cloud config owner or place is invalid', 502);
  cleanName(config.name);
  validatePayload(config.payload);
  if (!validIsoDate(config.createdAt) || !validIsoDate(config.updatedAt)) throw problem('Cloud config timestamps are invalid', 502);
  if (config.shareCode !== null && !validShareCode(config.shareCode)) throw problem('Cloud config share code is invalid', 502);
  validateBackup(config.backup);
  validateCopy(config.copy);
};

const validateStore = data => {
  if (!isObject(data) || data.version !== STORE_VERSION || !isObject(data.configs) || !isObject(data.shares)) {
    throw problem('Cloud config store has an invalid shape', 502);
  }
  for (const [id, config] of Object.entries(data.configs)) validateConfig(id, config);
  for (const [code, id] of Object.entries(data.shares)) {
    if (!validShareCode(code) || !validConfigId(id)) throw problem('Cloud config share index is invalid', 502);
    const config = data.configs[id];
    if (!config || config.shareCode !== code) throw problem('Cloud config share index is inconsistent', 502);
  }
  for (const config of Object.values(data.configs)) {
    if (config.shareCode !== null && data.shares[config.shareCode] !== config.id) {
      throw problem('Cloud config share record is missing from the index', 502);
    }
  }
  return data;
};

const githubUrl = endpoint => 'https://api.github.com/repos/' + REPOSITORY + '/' + endpoint;
const githubRequest = async (endpoint, options = {}, retries = REQUEST_RETRIES) => {
  let lastError;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const response = await fetch(githubUrl(endpoint), {
        ...options,
        headers: {...headers, ...(options.headers || {})},
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS)
      });
      if (!retryStatus(response.status) || attempt === retries) return response;
      lastError = problem('GitHub request failed with HTTP ' + response.status, 502, {upstreamStatus: response.status});
    } catch (error) {
      lastError = problem('GitHub request timed out or failed', 502, {cause: error});
      if (attempt === retries) throw lastError;
    }
    await wait(RETRY_BASE_MS * (2 ** attempt));
  }
  throw lastError || problem('GitHub request failed', 502);
};

const readStore = async () => {
  const response = await githubRequest('contents/' + CLOUD_FILE + '?ref=' + encodeURIComponent(BRANCH));
  if (response.status === 404) return {data: emptyStore(), sha: null};
  if (!response.ok) throw problem('Could not read cloud configs (HTTP ' + response.status + ')', 502);
  let remote;
  try { remote = await response.json(); }
  catch (error) { throw problem('GitHub returned an invalid cloud config response', 502, {cause: error}); }
  if (!isObject(remote) || typeof remote.content !== 'string' || typeof remote.sha !== 'string') {
    throw problem('GitHub returned an invalid cloud config response', 502);
  }
  let parsed;
  try { parsed = JSON.parse(Buffer.from(remote.content.replace(/\n/g, ''), 'base64').toString('utf8')); }
  catch (error) { throw problem('Cloud config store is invalid JSON', 502, {cause: error}); }
  return {data: validateStore(parsed), sha: remote.sha};
};

const writeStore = async (data, sha, message) => {
  validateStore(data);
  const body = {
    message: message || 'Update AetherV2 cloud configs',
    branch: BRANCH,
    content: Buffer.from(JSON.stringify(data, null, 2) + '\n').toString('base64'),
    ...(sha && {sha})
  };
  let response;
  try {
    response = await githubRequest('contents/' + CLOUD_FILE, {
      method: 'PUT',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify(body)
    }, 0);
  } catch (error) {
    throw problem('Could not write cloud configs', 502, {cause: error, retryable: true});
  }
  if (!response.ok) {
    const conflict = response.status === 409 || response.status === 422;
    throw problem(
      conflict ? 'Cloud configs changed during the update' : 'Could not write cloud configs (HTTP ' + response.status + ')',
      conflict ? 409 : 502,
      {retryable: conflict || retryStatus(response.status), upstreamStatus: response.status}
    );
  }
};

const withStoreLock = work => {
  const next = storeQueue.then(work, work);
  storeQueue = next.catch(() => undefined);
  return next;
};

const mutateStore = (message, work) => withStoreLock(async () => {
  let lastError;
  for (let attempt = 0; attempt < MUTATION_ATTEMPTS; attempt += 1) {
    const {data, sha} = await readStore();
    const result = await work(data);
    if (result && result.write === false) return result.value;
    try {
      await writeStore(data, sha, message);
      return result && Object.hasOwn(result, 'value') ? result.value : result;
    } catch (error) {
      lastError = error;
      if (!error.retryable || attempt + 1 >= MUTATION_ATTEMPTS) throw error;
      await wait(RETRY_BASE_MS * (2 ** attempt));
    }
  }
  throw lastError || problem('Cloud config update failed', 502);
});

const ownedConfigs = (data, session) => Object.values(data.configs).filter(config => config.ownerKeyId === session.keyId);
const requireOwned = (data, session, id) => {
  const config = data.configs[id];
  if (!config || config.ownerKeyId !== session.keyId) throw problem('Cloud config not found', 404);
  return config;
};
const ensureUniqueName = (data, session, name, ignoreId = null) => {
  const lowered = name.toLowerCase();
  if (ownedConfigs(data, session).some(config => config.id !== ignoreId && config.name.toLowerCase() === lowered)) {
    throw problem('You already have a cloud config with that name', 409);
  }
};
const ensureCapacity = (data, session) => {
  if (ownedConfigs(data, session).length >= MAX_CONFIGS_PER_KEY) throw problem('Premium users can store up to 5 cloud configs', 409);
};

const publicMetadata = config => ({
  id: config.id,
  name: config.name,
  placeId: config.placeId,
  lastSaved: config.updatedAt,
  hasBackup: config.backup !== null,
  shareCode: config.shareCode,
  isCopy: config.copy !== null,
  syncEnabled: Boolean(config.copy && config.copy.syncEnabled),
  sourceUpdatedAt: config.copy && config.copy.sourceUpdatedAt || null
});

const generateShareCode = data => {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const bytes = crypto.randomBytes(8);
    let raw = '';
    for (let index = 0; index < 8; index += 1) raw += SHARE_ALPHABET[bytes[index] % SHARE_ALPHABET.length];
    const code = raw.slice(0, 4) + '-' + raw.slice(4);
    if (!data.shares[code]) return code;
  }
  throw problem('Could not generate a unique share code', 503);
};

const nextImportedName = (data, session, wanted) => {
  const base = cleanName(wanted);
  const names = new Set(ownedConfigs(data, session).map(config => config.name.toLowerCase()));
  if (!names.has(base.toLowerCase())) return base;
  for (let suffix = 2; suffix <= 99; suffix += 1) {
    const candidate = (base.slice(0, Math.max(1, 56 - String(suffix).length)) + ' ' + suffix).trim();
    if (!names.has(candidate.toLowerCase())) return candidate;
  }
  throw problem('Could not choose a unique imported config name', 409);
};

const applySync = (data, config) => {
  if (!config.copy || !config.copy.syncEnabled) return false;
  const sourceId = data.shares[config.copy.sourceCode];
  const source = sourceId && data.configs[sourceId];
  if (!source || source.shareCode !== config.copy.sourceCode) {
    config.copy.syncEnabled = false;
    return true;
  }
  if (source.updatedAt === config.copy.sourceUpdatedAt) return false;
  config.backup = {payload: config.payload, savedAt: config.updatedAt};
  config.payload = source.payload;
  config.placeId = source.placeId;
  config.updatedAt = nowIso();
  config.copy.sourceUpdatedAt = source.updatedAt;
  return true;
};

const list = async (session, placeId) => mutateStore('Refresh AetherV2 cloud config syncs', async data => {
  let changed = false;
  for (const config of ownedConfigs(data, session)) changed = applySync(data, config) || changed;
  const configs = ownedConfigs(data, session)
    .filter(config => !placeId || String(config.placeId) === String(placeId))
    .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt))
    .map(publicMetadata);
  return changed ? {value: configs} : {write: false, value: configs};
});

const create = async (session, input) => mutateStore('Create AetherV2 cloud config', async data => {
  ensureCapacity(data, session);
  const name = cleanName(input.name);
  ensureUniqueName(data, session, name);
  const payload = validatePayload(input.payload);
  if (!validPlaceId(input.placeId)) throw problem('A valid placeId is required', 400);
  const id = crypto.randomUUID();
  const createdAt = nowIso();
  data.configs[id] = {
    id,
    ownerKeyId: session.keyId,
    ownerUsername: session.username,
    ownerUserId: String(session.userId),
    name,
    placeId: String(input.placeId),
    payload,
    createdAt,
    updatedAt: createdAt,
    backup: null,
    shareCode: null,
    copy: null
  };
  return {value: publicMetadata(data.configs[id])};
});

const get = async (session, id) => mutateStore('Refresh AetherV2 cloud config sync', async data => {
  const config = requireOwned(data, session, id);
  const changed = applySync(data, config);
  const value = {...publicMetadata(config), payload: config.payload};
  return changed ? {value} : {write: false, value};
});

const save = async (session, id, input) => mutateStore('Save AetherV2 cloud config', async data => {
  const config = requireOwned(data, session, id);
  const payload = validatePayload(input.payload);
  if (input.placeId !== undefined && !validPlaceId(input.placeId)) throw problem('A valid placeId is required', 400);
  const changed = payload !== config.payload || (input.placeId !== undefined && String(input.placeId) !== config.placeId);
  if (!changed) return {write: false, value: publicMetadata(config)};
  config.backup = {payload: config.payload, savedAt: config.updatedAt};
  config.payload = payload;
  if (input.placeId !== undefined) config.placeId = String(input.placeId);
  config.updatedAt = nowIso();
  return {value: publicMetadata(config)};
});

const rename = async (session, id, name) => mutateStore('Rename AetherV2 cloud config', async data => {
  const config = requireOwned(data, session, id);
  const nextName = cleanName(name);
  ensureUniqueName(data, session, nextName, id);
  if (config.name === nextName) return {write: false, value: publicMetadata(config)};
  config.name = nextName;
  return {value: publicMetadata(config)};
});

const remove = async (session, id) => mutateStore('Delete AetherV2 cloud config', async data => {
  const config = requireOwned(data, session, id);
  if (config.shareCode) delete data.shares[config.shareCode];
  delete data.configs[id];
  return {value: {id}};
});

const sharing = async (session, id, mode) => mutateStore('Update AetherV2 cloud config sharing', async data => {
  const config = requireOwned(data, session, id);
  if (!['generate', 'regenerate', 'disable'].includes(mode)) throw problem('Invalid sharing action', 400);
  if (mode === 'disable') {
    if (!config.shareCode) return {write: false, value: publicMetadata(config)};
    delete data.shares[config.shareCode];
    config.shareCode = null;
    return {value: publicMetadata(config)};
  }
  if (mode === 'generate' && config.shareCode) return {write: false, value: publicMetadata(config)};
  if (config.shareCode) delete data.shares[config.shareCode];
  config.shareCode = generateShareCode(data);
  data.shares[config.shareCode] = config.id;
  return {value: publicMetadata(config)};
});

const setSync = async (session, id, enabled) => mutateStore('Update AetherV2 cloud config copy sync', async data => {
  const config = requireOwned(data, session, id);
  if (!config.copy) throw problem('Only configs imported from a share code can sync to the original', 409);
  if (typeof enabled !== 'boolean') throw problem('Sync enabled must be true or false', 400);
  if (enabled) {
    const sourceId = data.shares[config.copy.sourceCode];
    const source = sourceId && data.configs[sourceId];
    if (!source || source.shareCode !== config.copy.sourceCode) {
      config.copy.syncEnabled = false;
      return {value: {...publicMetadata(config), syncInvalidated: true}};
    }
    config.copy.syncEnabled = true;
    applySync(data, config);
  } else {
    config.copy.syncEnabled = false;
  }
  return {value: publicMetadata(config)};
});

const resolveShare = async code => {
  const normalized = String(code || '').trim().toUpperCase();
  if (!validShareCode(normalized)) throw problem('Share code is invalid', 404);
  const {data} = await readStore();
  const id = data.shares[normalized];
  const config = id && data.configs[id];
  if (!config || config.shareCode !== normalized) throw problem('Share code is invalid or has been disabled', 404);
  return {
    name: config.name,
    placeId: config.placeId,
    payload: config.payload,
    lastSaved: config.updatedAt
  };
};

const importShare = async (session, input) => mutateStore('Import AetherV2 shared cloud config', async data => {
  ensureCapacity(data, session);
  const code = String(input.code || '').trim().toUpperCase();
  if (!validShareCode(code)) throw problem('Share code is invalid', 404);
  const sourceId = data.shares[code];
  const source = sourceId && data.configs[sourceId];
  if (!source || source.shareCode !== code) throw problem('Share code is invalid or has been disabled', 404);
  const name = nextImportedName(data, session, input.name || source.name + ' Copy');
  const id = crypto.randomUUID();
  const createdAt = nowIso();
  data.configs[id] = {
    id,
    ownerKeyId: session.keyId,
    ownerUsername: session.username,
    ownerUserId: String(session.userId),
    name,
    placeId: source.placeId,
    payload: source.payload,
    createdAt,
    updatedAt: createdAt,
    backup: null,
    shareCode: null,
    copy: {
      sourceCode: code,
      syncEnabled: input.sync === true,
      sourceUpdatedAt: source.updatedAt
    }
  };
  return {value: publicMetadata(data.configs[id])};
});

const restoreBackup = async (session, id) => mutateStore('Restore AetherV2 cloud config backup', async data => {
  const config = requireOwned(data, session, id);
  if (!config.backup) throw problem('This cloud config has no backup', 404);
  const current = {payload: config.payload, savedAt: config.updatedAt};
  config.payload = config.backup.payload;
  config.updatedAt = nowIso();
  config.backup = current;
  return {value: publicMetadata(config)};
});

module.exports = {
  MAX_CONFIGS_PER_KEY,
  MAX_PAYLOAD_BYTES,
  validShareCode,
  validatePayload,
  validateStore,
  emptyStore,
  publicMetadata,
  list,
  create,
  get,
  save,
  rename,
  remove,
  sharing,
  setSync,
  resolveShare,
  importShare,
  restoreBackup,
  readStore
};
