'use strict';

const crypto = require('node:crypto');

const REPOSITORY = process.env.GITHUB_REPO || 'plutoxqqqq/AetherV2';
const BRANCH = process.env.GITHUB_BRANCH || 'main';
const TOKEN = process.env.GITHUB_TOKEN || '';
const KEY_SOURCE = process.env.AETHER_KEYS || process.env.AETHER_KEY || '';
const REGISTRY_FILE = process.env.AETHER_REGISTRY_FILE || 'backend/key-bindings.json';
const configuredKeys = KEY_SOURCE.split(',').map(value => value.trim()).filter(Boolean);
const configuredKeyIds = new Set();
const AUDIT_LIMIT_VALUE = Number(process.env.AETHER_AUDIT_LIMIT || 500);
const AUDIT_LIMIT = Number.isFinite(AUDIT_LIMIT_VALUE) ? Math.max(50, Math.min(5000, AUDIT_LIMIT_VALUE)) : 500;
let registryQueue = Promise.resolve();

if (!TOKEN) throw new Error('GITHUB_TOKEN is required');

const headers = {
  authorization: 'Bearer ' + TOKEN,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-key-registry',
  'x-github-api-version': '2022-11-28'
};

const digest = value => crypto.createHash('sha256').update(String(value || '')).digest();
const keyId = value => digest(value).toString('hex');
for (const value of configuredKeys) configuredKeyIds.add(keyId(value));

const problem = (message, status = 400) => Object.assign(new Error(message), {status});
const isObject = value => value && typeof value === 'object' && !Array.isArray(value);
const validRawKey = value => typeof value === 'string' && value.length >= 16 && value.length <= 256;
const validKeyId = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const emptyRegistry = () => ({version: 2, keys: {}, bindings: {}, audit: []});

const normalizeRegistry = input => {
  if (!isObject(input) || !isObject(input.bindings)) {
    throw problem('Key registry has an invalid shape', 502);
  }
  const data = {...input};
  data.version = 2;
  data.keys = isObject(data.keys) ? data.keys : {};
  data.audit = Array.isArray(data.audit) ? data.audit : [];
  return data;
};

const githubUrl = endpoint => 'https://api.github.com/repos/' + REPOSITORY + '/' + endpoint;
const githubRequest = (endpoint, options = {}) => fetch(githubUrl(endpoint), {
  ...options,
  headers: {...headers, ...(options.headers || {})}
});

const readRegistry = async () => {
  const response = await githubRequest('contents/' + REGISTRY_FILE + '?ref=' + encodeURIComponent(BRANCH));
  if (response.status === 404) return {data: emptyRegistry(), sha: null};
  if (!response.ok) throw problem('Could not read key registry (HTTP ' + response.status + ')', 502);

  const remote = await response.json();
  if (typeof remote.content !== 'string') throw problem('Invalid key registry response', 502);

  let data;
  try {
    data = JSON.parse(Buffer.from(remote.content.replace(/\n/g, ''), 'base64').toString('utf8'));
  } catch {
    throw problem('Key registry is invalid JSON', 502);
  }
  return {data: normalizeRegistry(data), sha: remote.sha};
};

const writeRegistry = async (data, sha, message) => {
  const body = {
    message: message || 'Update AetherV2 key registry',
    branch: BRANCH,
    content: Buffer.from(JSON.stringify(data, null, 2) + '\n').toString('base64'),
    ...(sha && {sha})
  };
  const response = await githubRequest('contents/' + REGISTRY_FILE, {
    method: 'PUT',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify(body)
  });
  if (!response.ok) throw problem('Could not write key registry (HTTP ' + response.status + ')', 502);
};

const withRegistryLock = work => {
  const next = registryQueue.then(work, work);
  registryQueue = next.catch(() => undefined);
  return next;
};

const normalizeLabel = value => {
  if (value === undefined) return undefined;
  const label = String(value).trim();
  if (label.toLowerCase() === 'none') return '';
  if (label.length > 80) throw problem('Key label must be 80 characters or fewer');
  return label;
};

const normalizeExpiry = value => {
  if (value === undefined) return undefined;
  if (value === null || String(value).trim().toLowerCase() === 'none') return null;
  const timestamp = Date.parse(String(value).trim());
  if (!Number.isFinite(timestamp)) {
    throw problem('Expiry must be an ISO date/time or none');
  }
  return new Date(timestamp).toISOString();
};

const keyStatus = record => {
  if (!record || record.enabled === false) return 'disabled';
  if (record.expiresAt) {
    const timestamp = Date.parse(record.expiresAt);
    if (Number.isFinite(timestamp) && timestamp <= Date.now()) return 'expired';
  }
  return 'active';
};

const environmentRecord = () => ({
  label: 'Environment key',
  source: 'environment',
  createdAt: null,
  createdBy: 'AETHER_KEYS',
  enabled: true,
  expiresAt: null
});

const findRecord = (data, id) => {
  if (data.keys[id]) return data.keys[id];
  if (configuredKeyIds.has(id)) return environmentRecord();
  return null;
};

const ensureMutableRecord = (data, id) => {
  if (!validKeyId(id)) throw problem('Invalid key ID');
  if (!data.keys[id] && configuredKeyIds.has(id)) data.keys[id] = environmentRecord();
  const record = data.keys[id];
  if (!record) throw problem('Key ID was not found', 404);
  return record;
};

const addAudit = (data, action, id, actor, details = {}) => {
  data.audit.push({
    at: new Date().toISOString(),
    action,
    keyId: id || null,
    actor: String(actor || 'unknown').slice(0, 100),
    ...details
  });
  if (data.audit.length > AUDIT_LIMIT) {
    data.audit.splice(0, data.audit.length - AUDIT_LIMIT);
  }
};

const resolveKey = async rawKey => {
  if (!validRawKey(rawKey)) return null;
  const id = keyId(rawKey);
  const current = await readRegistry();
  const record = findRecord(current.data, id);
  if (!record || keyStatus(record) !== 'active') return null;
  return {keyId: id, record};
};

const isValidKey = async rawKey => Boolean(await resolveKey(rawKey));

const bindKey = (id, person) => withRegistryLock(async () => {
  if (!validKeyId(id)) throw problem('Invalid key ID');
  const current = await readRegistry();
  const record = ensureMutableRecord(current.data, id);
  if (keyStatus(record) !== 'active') throw problem('This key is disabled or expired', 403);

  const existing = current.data.bindings[id];
  if (existing) {
    const sameUser = String(existing.userId) === String(person.userId) &&
      String(existing.username).toLowerCase() === String(person.username).toLowerCase();
    if (!sameUser) throw problem('This key is already locked to another Roblox account', 403);
    return {id, binding: existing, record, firstUse: false};
  }

  const now = new Date().toISOString();
  const binding = {
    username: person.username,
    userId: String(person.userId),
    firstUsedAt: now,
    uses: 1
  };
  current.data.bindings[id] = binding;
  addAudit(current.data, 'bind', id, 'loader', {
    username: person.username,
    userId: String(person.userId)
  });
  await writeRegistry(current.data, current.sha, 'Bind AetherV2 key');
  return {id, binding, record, firstUse: true};
});

const createKey = ({label, expiresAt, actor} = {}) => withRegistryLock(async () => {
  const current = await readRegistry();
  const normalizedLabel = normalizeLabel(label);
  const normalizedExpiry = normalizeExpiry(expiresAt);
  const rawKey = crypto.randomBytes(32).toString('hex');
  const id = keyId(rawKey);
  const now = new Date().toISOString();
  const record = {
    label: normalizedLabel || 'Unlabelled',
    source: 'discord',
    createdAt: now,
    createdBy: String(actor || 'unknown').slice(0, 100),
    enabled: true,
    expiresAt: normalizedExpiry === undefined ? null : normalizedExpiry
  };
  current.data.keys[id] = record;
  addAudit(current.data, 'generate', id, actor, {label: record.label});
  await writeRegistry(current.data, current.sha, 'Generate AetherV2 key');
  return {key: rawKey, keyId: id, record};
});

const editKey = ({id, label, expiresAt, enabled, actor} = {}) => withRegistryLock(async () => {
  if (label === undefined && expiresAt === undefined && enabled === undefined) {
    throw problem('Provide a label, expiry, or enabled value to edit');
  }
  const current = await readRegistry();
  const record = ensureMutableRecord(current.data, id);
  const changes = {};

  if (label !== undefined) {
    record.label = normalizeLabel(label);
    changes.label = record.label;
  }
  if (expiresAt !== undefined) {
    record.expiresAt = normalizeExpiry(expiresAt);
    changes.expiresAt = record.expiresAt;
  }
  if (enabled !== undefined) {
    if (typeof enabled !== 'boolean') throw problem('Enabled must be true or false');
    record.enabled = enabled;
    changes.enabled = enabled;
  }

  addAudit(current.data, 'edit', id, actor, {changes});
  await writeRegistry(current.data, current.sha, 'Edit AetherV2 key');
  return {keyId: id, record, binding: current.data.bindings[id] || null};
});

const unlinkKey = ({id, username, userId, actor} = {}) => withRegistryLock(async () => {
  const current = await readRegistry();
  let selectedId = id;

  if (!selectedId) {
    const matches = Object.entries(current.data.bindings).filter(([, binding]) =>
      String(binding.username).toLowerCase() === String(username || '').trim().toLowerCase() &&
      (!userId || String(binding.userId) === String(userId))
    );
    if (matches.length === 0) throw problem('No matching username binding was found', 404);
    if (matches.length > 1) throw problem('More than one key is bound to that username; use key_id');
    selectedId = matches[0][0];
  }

  if (!validKeyId(selectedId)) throw problem('Invalid key ID');
  const existing = current.data.bindings[selectedId];
  if (!existing) throw problem('This key is not currently bound', 404);

  delete current.data.bindings[selectedId];
  addAudit(current.data, 'unlink', selectedId, actor, {
    username: existing.username,
    userId: String(existing.userId)
  });
  await writeRegistry(current.data, current.sha, 'Unlink AetherV2 key');
  return {keyId: selectedId, binding: existing};
});

const revokeKey = ({id, actor} = {}) => editKey({id, enabled: false, actor});
const enableKey = ({id, actor} = {}) => editKey({id, enabled: true, actor});

const rotateKey = ({id, actor} = {}) => withRegistryLock(async () => {
  const current = await readRegistry();
  const oldRecord = ensureMutableRecord(current.data, id);
  const oldBinding = current.data.bindings[id] || null;
  const rawKey = crypto.randomBytes(32).toString('hex');
  const newId = keyId(rawKey);
  const now = new Date().toISOString();

  oldRecord.enabled = false;
  oldRecord.rotatedTo = newId;
  current.data.keys[newId] = {
    label: oldRecord.label || 'Rotated key',
    source: 'discord',
    createdAt: now,
    createdBy: String(actor || 'unknown').slice(0, 100),
    enabled: true,
    expiresAt: oldRecord.expiresAt || null,
    rotatedFrom: id
  };
  if (oldBinding) current.data.bindings[newId] = {...oldBinding, transferredAt: now};

  addAudit(current.data, 'rotate', id, actor, {
    replacementKeyId: newId,
    transferredUsername: oldBinding && oldBinding.username
  });
  await writeRegistry(current.data, current.sha, 'Rotate AetherV2 key');
  return {
    oldKeyId: id,
    key: rawKey,
    keyId: newId,
    record: current.data.keys[newId],
    binding: current.data.bindings[newId] || null
  };
});

const listKeys = async () => {
  const current = await readRegistry();
  const ids = new Set([...Object.keys(current.data.keys), ...configuredKeyIds]);
  return Array.from(ids).sort().map(id => {
    const record = findRecord(current.data, id);
    return {
      keyId: id,
      label: record && record.label || 'Unlabelled',
      source: record && record.source || 'unknown',
      status: keyStatus(record),
      createdAt: record && record.createdAt || null,
      expiresAt: record && record.expiresAt || null,
      uses: current.data.bindings[id] && current.data.bindings[id].uses || 0,
      binding: current.data.bindings[id] || null
    };
  });
};

const getKeyInfo = async id => {
  if (!validKeyId(id)) throw problem('Invalid key ID');
  const current = await readRegistry();
  const record = findRecord(current.data, id);
  if (!record) throw problem('Key ID was not found', 404);
  return {
    keyId: id,
    label: record.label || 'Unlabelled',
    source: record.source || 'unknown',
    status: keyStatus(record),
    createdAt: record.createdAt || null,
    expiresAt: record.expiresAt || null,
    uses: current.data.bindings[id] && current.data.bindings[id].uses || 0,
    binding: current.data.bindings[id] || null,
    record
  };
};

const getAudit = async limit => {
  const current = await readRegistry();
  const count = Math.max(1, Math.min(100, Number(limit) || 20));
  return current.data.audit.slice(-count).reverse();
};

module.exports = {
  keyId,
  validKeyId,
  resolveKey,
  isValidKey,
  bindKey,
  createKey,
  editKey,
  unlinkKey,
  revokeKey,
  enableKey,
  rotateKey,
  listKeys,
  getKeyInfo,
  getAudit,
  normalizeExpiry
};
