'use strict';

const crypto = require('node:crypto');

const REPOSITORY = process.env.GITHUB_REPO || '';
// Registry mutations are data, not source deployments. Keep them on a dedicated branch so normal
// loader authorization cannot create a commit on the Render deployment branch and restart the
// in-memory source session mid-load.
const BRANCH = process.env.AETHER_REGISTRY_BRANCH || 'aether-key-registry';
const TOKEN = process.env.GITHUB_TOKEN || '';
const REGISTRY_FILE = process.env.AETHER_REGISTRY_FILE || 'backend/key-bindings.json';
const REGISTRY_VERSION = 3;

const boundedNumber = (value, fallback, min, max) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
};

const AUDIT_LIMIT = boundedNumber(process.env.AETHER_AUDIT_LIMIT, 500, 50, 5000);
const REQUEST_TIMEOUT_MS = boundedNumber(process.env.AETHER_REQUEST_TIMEOUT_MS, 8000, 1000, 30000);
const REQUEST_RETRIES = boundedNumber(process.env.AETHER_GITHUB_RETRIES, 3, 0, 6);
const MUTATION_ATTEMPTS = boundedNumber(process.env.AETHER_GITHUB_CONFLICT_RETRIES, 4, 1, 8);
const RETRY_BASE_MS = boundedNumber(process.env.AETHER_RETRY_BASE_MS, 150, 0, 5000);
let registryQueue = Promise.resolve();

if (!TOKEN) throw new Error('GITHUB_TOKEN is required');
if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(REPOSITORY)) {
  throw new Error('GITHUB_REPO must be configured as owner/repository');
}
if (!BRANCH || BRANCH.length > 200) throw new Error('AETHER_REGISTRY_BRANCH is invalid');

const headers = {
  authorization: 'Bearer ' + TOKEN,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-key-registry',
  'x-github-api-version': '2022-11-28'
};

const problem = (message, status = 400, extra = {}) => Object.assign(new Error(message), {status, ...extra});
const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const validRawKey = value => typeof value === 'string' && value.length >= 16 && value.length <= 256;
const validKeyId = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const validIsoDate = value => typeof value === 'string' && Number.isFinite(Date.parse(value));
const digest = value => crypto.createHash('sha256').update(String(value || '')).digest();
const keyId = value => digest(value).toString('hex');
const wait = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const nowIso = () => new Date().toISOString();

const normalizeActor = actor => {
  const value = String(actor || 'unknown').trim();
  return (value || 'unknown').slice(0, 100);
};

const validateObjectKeys = (value, allowed, required, label) => {
  if (!isObject(value)) throw problem(label + ' must be an object', 502);
  for (const key of Object.keys(value)) {
    if (!allowed.includes(key)) throw problem(label + ' contains unsupported field ' + key, 502);
  }
  for (const key of required) {
    if (!Object.hasOwn(value, key)) throw problem(label + ' is missing field ' + key, 502);
  }
};

const normalizeLegacyRegistry = input => {
  if (!isObject(input)) throw problem('Key registry must be an object', 502);
  if (input.version === 1) {
    validateObjectKeys(input, ['version', 'bindings'], ['version', 'bindings'], 'Key registry');
    if (!isObject(input.bindings)) throw problem('Key registry bindings must be an object', 502);
    const keys = {};
    for (const [id, binding] of Object.entries(input.bindings)) {
      keys[id] = {
        label: 'Migrated key',
        source: 'legacy',
        createdAt: isObject(binding) && validIsoDate(binding.firstUsedAt) ? binding.firstUsedAt : null,
        createdBy: 'registry migration',
        enabled: true,
        expiresAt: null
      };
    }
    return {version: REGISTRY_VERSION, keys, bindings: input.bindings, audit: []};
  }
  if (input.version === 2) {
    validateObjectKeys(input, ['version', 'keys', 'bindings', 'audit'], ['version', 'keys', 'bindings', 'audit'], 'Key registry');
    return {...input, version: REGISTRY_VERSION};
  }
  return input;
};

const validateRecord = (id, record) => {
  validateObjectKeys(
    record,
    ['label', 'source', 'createdAt', 'createdBy', 'enabled', 'expiresAt', 'rotatedFrom', 'rotatedTo'],
    ['label', 'source', 'createdAt', 'createdBy', 'enabled', 'expiresAt'],
    'Key record ' + id
  );
  if (typeof record.label !== 'string' || record.label.length > 80) throw problem('Key record has an invalid label', 502);
  if (!['discord', 'environment', 'legacy'].includes(record.source)) throw problem('Key record has an invalid source', 502);
  if (record.createdAt !== null && !validIsoDate(record.createdAt)) throw problem('Key record has an invalid createdAt', 502);
  if (typeof record.createdBy !== 'string' || !record.createdBy || record.createdBy.length > 100) throw problem('Key record has an invalid createdBy', 502);
  if (typeof record.enabled !== 'boolean') throw problem('Key record has an invalid enabled value', 502);
  if (record.expiresAt !== null && !validIsoDate(record.expiresAt)) throw problem('Key record has an invalid expiresAt', 502);
  if (record.rotatedFrom !== undefined && !validKeyId(record.rotatedFrom)) throw problem('Key record has an invalid rotatedFrom', 502);
  if (record.rotatedTo !== undefined && !validKeyId(record.rotatedTo)) throw problem('Key record has an invalid rotatedTo', 502);
};

const validateBinding = (id, binding) => {
  validateObjectKeys(
    binding,
    ['username', 'userId', 'firstUsedAt', 'lastUsedAt', 'uses', 'transferredAt'],
    ['username', 'userId', 'firstUsedAt', 'uses'],
    'Key binding ' + id
  );
  if (!/^[A-Za-z0-9_]{3,20}$/.test(binding.username)) throw problem('Key binding has an invalid username', 502);
  if (!/^\d{1,20}$/.test(String(binding.userId))) throw problem('Key binding has an invalid userId', 502);
  if (!validIsoDate(binding.firstUsedAt)) throw problem('Key binding has an invalid firstUsedAt', 502);
  if (binding.lastUsedAt !== undefined && !validIsoDate(binding.lastUsedAt)) throw problem('Key binding has an invalid lastUsedAt', 502);
  if (!Number.isSafeInteger(binding.uses) || binding.uses < 0) throw problem('Key binding has an invalid usage count', 502);
  if (binding.transferredAt !== undefined && !validIsoDate(binding.transferredAt)) throw problem('Key binding has an invalid transferredAt', 502);
};

const auditActions = new Set(['generate', 'bind', 'use', 'edit', 'unlink', 'revoke', 'enable', 'renew', 'rotate']);
const validateAudit = event => {
  validateObjectKeys(
    event,
    ['at', 'action', 'keyId', 'actor', 'operationId', 'label', 'username', 'userId', 'uses', 'changes', 'replacementKeyId', 'transferredUsername', 'expiresAt'],
    ['at', 'action', 'keyId', 'actor'],
    'Audit event'
  );
  if (!validIsoDate(event.at)) throw problem('Audit event has an invalid timestamp', 502);
  if (!auditActions.has(event.action)) throw problem('Audit event has an invalid action', 502);
  if (event.keyId !== null && !validKeyId(event.keyId)) throw problem('Audit event has an invalid keyId', 502);
  if (typeof event.actor !== 'string' || !event.actor || event.actor.length > 100) throw problem('Audit event has an invalid actor', 502);
  if (event.operationId !== undefined && !/^[a-f0-9-]{16,64}$/i.test(event.operationId)) throw problem('Audit event has an invalid operationId', 502);
  if (event.label !== undefined && (typeof event.label !== 'string' || event.label.length > 80)) throw problem('Audit event has an invalid label', 502);
  if (event.username !== undefined && !/^[A-Za-z0-9_]{3,20}$/.test(event.username)) throw problem('Audit event has an invalid username', 502);
  if (event.userId !== undefined && !/^\d{1,20}$/.test(String(event.userId))) throw problem('Audit event has an invalid userId', 502);
  if (event.uses !== undefined && (!Number.isSafeInteger(event.uses) || event.uses < 0)) throw problem('Audit event has an invalid usage count', 502);
  if (event.changes !== undefined) {
    validateObjectKeys(event.changes, ['label', 'expiresAt', 'enabled'], [], 'Audit changes');
    if (event.changes.label !== undefined && (typeof event.changes.label !== 'string' || event.changes.label.length > 80)) throw problem('Audit event has an invalid label change', 502);
    if (event.changes.expiresAt !== undefined && event.changes.expiresAt !== null && !validIsoDate(event.changes.expiresAt)) throw problem('Audit event has an invalid expiry change', 502);
    if (event.changes.enabled !== undefined && typeof event.changes.enabled !== 'boolean') throw problem('Audit event has an invalid enabled change', 502);
  }
  if (event.replacementKeyId !== undefined && !validKeyId(event.replacementKeyId)) throw problem('Audit event has an invalid replacementKeyId', 502);
  if (event.transferredUsername !== undefined && event.transferredUsername !== null && !/^[A-Za-z0-9_]{3,20}$/.test(event.transferredUsername)) throw problem('Audit event has an invalid transferred username', 502);
  if (event.expiresAt !== undefined && event.expiresAt !== null && !validIsoDate(event.expiresAt)) throw problem('Audit event has an invalid expiresAt', 502);
};

const validateRegistry = input => {
  const data = normalizeLegacyRegistry(input);
  validateObjectKeys(data, ['version', 'keys', 'bindings', 'audit'], ['version', 'keys', 'bindings', 'audit'], 'Key registry');
  if (data.version !== REGISTRY_VERSION) throw problem('Unsupported key registry version', 502);
  if (!isObject(data.keys) || !isObject(data.bindings) || !Array.isArray(data.audit)) throw problem('Key registry has an invalid shape', 502);
  if (data.audit.length > AUDIT_LIMIT) throw problem('Key registry audit history exceeds the configured limit', 502);
  for (const [id, record] of Object.entries(data.keys)) {
    if (!validKeyId(id)) throw problem('Key registry contains an invalid key ID', 502);
    validateRecord(id, record);
  }
  for (const [id, record] of Object.entries(data.keys)) {
    if (record.rotatedFrom !== undefined) {
      const previous = data.keys[record.rotatedFrom];
      if (!previous || previous.rotatedTo !== id) throw problem('Key registry contains an inconsistent rotatedFrom link', 502);
    }
    if (record.rotatedTo !== undefined) {
      const replacement = data.keys[record.rotatedTo];
      if (!replacement || replacement.rotatedFrom !== id || record.enabled) throw problem('Key registry contains an inconsistent rotatedTo link', 502);
      if (data.bindings[id]) throw problem('Rotated keys cannot retain an account binding', 502);
    }
  }
  for (const [id, binding] of Object.entries(data.bindings)) {
    if (!validKeyId(id) || !data.keys[id]) throw problem('Key registry contains an orphaned binding', 502);
    validateBinding(id, binding);
  }
  for (const event of data.audit) {
    validateAudit(event);
    if (event.keyId !== null && !data.keys[event.keyId]) throw problem('Audit event references an unknown key ID', 502);
    if (event.replacementKeyId !== undefined && !data.keys[event.replacementKeyId]) throw problem('Audit event references an unknown replacement key ID', 502);
  }
  return data;
};

const emptyRegistry = () => ({version: REGISTRY_VERSION, keys: {}, bindings: {}, audit: []});
const githubUrl = endpoint => 'https://api.github.com/repos/' + REPOSITORY + '/' + endpoint;
const retryStatus = status => status === 408 || status === 429 || status >= 500;

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

const readRegistry = async () => {
  const response = await githubRequest('contents/' + REGISTRY_FILE + '?ref=' + encodeURIComponent(BRANCH));
  if (response.status === 404) return {data: emptyRegistry(), sha: null};
  if (!response.ok) throw problem('Could not read key registry (HTTP ' + response.status + ')', 502);
  let remote;
  try {
    remote = await response.json();
  } catch (error) {
    throw problem('GitHub returned an invalid key registry response', 502, {cause: error});
  }
  if (!isObject(remote) || typeof remote.content !== 'string' || typeof remote.sha !== 'string') {
    throw problem('GitHub returned an invalid key registry response', 502);
  }
  let parsed;
  try {
    parsed = JSON.parse(Buffer.from(remote.content.replace(/\n/g, ''), 'base64').toString('utf8'));
  } catch (error) {
    throw problem('Key registry is invalid JSON', 502, {cause: error});
  }
  return {data: validateRegistry(parsed), sha: remote.sha};
};

const writeRegistry = async (data, sha, message) => {
  validateRegistry(data);
  const body = {
    message: message || 'Update AetherV2 key registry',
    branch: BRANCH,
    content: Buffer.from(JSON.stringify(data, null, 2) + '\n').toString('base64'),
    ...(sha && {sha})
  };
  let response;
  try {
    response = await githubRequest('contents/' + REGISTRY_FILE, {
      method: 'PUT',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify(body)
    }, 0);
  } catch (error) {
    throw problem('Could not write key registry', 502, {cause: error, retryable: true});
  }
  if (!response.ok) {
    const conflict = response.status === 409 || response.status === 422;
    throw problem(
      conflict ? 'Key registry changed during the update' : 'Could not write key registry (HTTP ' + response.status + ')',
      conflict ? 409 : 502,
      {retryable: conflict || retryStatus(response.status), upstreamStatus: response.status}
    );
  }
};

const withRegistryLock = work => {
  const next = registryQueue.then(work, work);
  registryQueue = next.catch(() => undefined);
  return next;
};

const findOperation = (data, operationId) => data.audit.find(event => event.operationId === operationId);
const addAudit = (data, action, id, actor, operationId, details = {}) => {
  if (findOperation(data, operationId)) return;
  data.audit.push({
    at: nowIso(),
    action,
    keyId: id || null,
    actor: normalizeActor(actor),
    operationId,
    ...details
  });
  if (data.audit.length > AUDIT_LIMIT) data.audit.splice(0, data.audit.length - AUDIT_LIMIT);
};

const mutateRegistry = (message, mutate) => withRegistryLock(async () => {
  const operationId = crypto.randomUUID();
  let lastError;
  for (let attempt = 0; attempt < MUTATION_ATTEMPTS; attempt += 1) {
    const current = await readRegistry();
    const mutation = await mutate(current.data, operationId);
    if (mutation.changed === false) return mutation.result;
    try {
      await writeRegistry(current.data, current.sha, message);
      return mutation.result;
    } catch (error) {
      lastError = error;
      if (!error.retryable || attempt === MUTATION_ATTEMPTS - 1) throw error;
      await wait(RETRY_BASE_MS * (2 ** attempt));
    }
  }
  throw lastError || problem('Key registry update failed', 502);
});

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
  if (!Number.isFinite(timestamp)) throw problem('Expiry must be an ISO date/time or none');
  return new Date(timestamp).toISOString();
};

const requireFutureExpiry = value => {
  const expiresAt = normalizeExpiry(value);
  if (!expiresAt) throw problem('A future expiry date is required');
  if (Date.parse(expiresAt) <= Date.now()) throw problem('Expiry must be in the future');
  return expiresAt;
};

const keyStatus = record => {
  if (!record) return 'unknown';
  if (record.expiresAt && Date.parse(record.expiresAt) <= Date.now()) return 'expired';
  if (!record.enabled) return 'disabled';
  return 'active';
};

const resolveIdInData = (data, value) => {
  const candidate = String(value || '').trim().toLowerCase();
  if (!/^[a-f0-9]{8,64}$/.test(candidate)) throw problem('Key ID must be a hexadecimal ID or unique prefix');
  if (candidate.length === 64 && data.keys[candidate]) return candidate;
  const matches = Object.keys(data.keys).filter(id => id.startsWith(candidate));
  if (matches.length === 0) throw problem('Key ID was not found', 404);
  if (matches.length > 1) throw problem('Key ID prefix is ambiguous; copy more characters', 409);
  return matches[0];
};

const ensureRecord = (data, value) => {
  const id = resolveIdInData(data, value);
  return {id, record: data.keys[id]};
};

const normalizePerson = person => {
  const username = String(person && person.username || '');
  const userId = String(person && person.userId || '');
  if (!/^[A-Za-z0-9_]{3,20}$/.test(username) || !/^\d{1,20}$/.test(userId)) {
    throw problem('Invalid Roblox identity');
  }
  return {username, userId};
};

const resolveKey = async rawKey => {
  if (!validRawKey(rawKey)) return null;
  const id = keyId(rawKey);
  const current = await readRegistry();
  const record = current.data.keys[id];
  return record && keyStatus(record) === 'active' ? {keyId: id, record} : null;
};

const isValidKey = async rawKey => Boolean(await resolveKey(rawKey));
const isKeyIdActive = async id => {
  if (!validKeyId(id)) return false;
  const current = await readRegistry();
  return Boolean(current.data.keys[id] && keyStatus(current.data.keys[id]) === 'active');
};

const bindKey = (id, person) => {
  const identity = normalizePerson(person);
  if (!validKeyId(id)) throw problem('Invalid key ID');
  return mutateRegistry('Authorize AetherV2 key', async (data, operationId) => {
    const applied = findOperation(data, operationId);
    if (applied) return {
      changed: false,
      result: {id, binding: data.bindings[id], record: data.keys[id], firstUse: applied.action === 'bind'}
    };
    const record = data.keys[id];
    if (!record) throw problem('Key ID was not found', 404);
    if (keyStatus(record) !== 'active') throw problem('This key is revoked or expired', 403);
    const existing = data.bindings[id];
    const timestamp = nowIso();
    if (existing) {
      const sameUser = existing.userId === identity.userId && existing.username.toLowerCase() === identity.username.toLowerCase();
      if (!sameUser) throw problem('This key is already locked to another Roblox account', 403);
      existing.uses += 1;
      existing.lastUsedAt = timestamp;
      addAudit(data, 'use', id, 'loader', operationId, {username: existing.username, userId: existing.userId, uses: existing.uses});
      return {changed: true, result: {id, binding: existing, record, firstUse: false}};
    }
    const binding = {username: identity.username, userId: identity.userId, firstUsedAt: timestamp, lastUsedAt: timestamp, uses: 1};
    data.bindings[id] = binding;
    addAudit(data, 'bind', id, 'loader', operationId, {username: binding.username, userId: binding.userId, uses: 1});
    return {changed: true, result: {id, binding, record, firstUse: true}};
  });
};

const createKey = ({label, expiresAt, actor} = {}) => {
  const rawKey = crypto.randomBytes(32).toString('hex');
  const id = keyId(rawKey);
  const createdAt = nowIso();
  const normalizedLabel = normalizeLabel(label) || 'Unlabelled';
  const normalizedExpiry = expiresAt === undefined ? null : requireFutureExpiry(expiresAt);
  return mutateRegistry('Generate AetherV2 key', async (data, operationId) => {
    const applied = findOperation(data, operationId);
    if (applied) return {changed: false, result: {key: rawKey, keyId: id, record: data.keys[id]}};
    if (data.keys[id]) throw problem('Generated key ID collision; retry the command', 409);
    const record = {
      label: normalizedLabel,
      source: 'discord',
      createdAt,
      createdBy: normalizeActor(actor),
      enabled: true,
      expiresAt: normalizedExpiry
    };
    data.keys[id] = record;
    addAudit(data, 'generate', id, actor, operationId, {label: record.label});
    return {changed: true, result: {key: rawKey, keyId: id, record}};
  });
};

const editKey = ({id, label, expiresAt, actor} = {}) => {
  if (label === undefined && expiresAt === undefined) throw problem('Provide a label or expiry to edit');
  const normalizedLabel = label === undefined ? undefined : normalizeLabel(label);
  const normalizedExpiry = expiresAt === undefined ? undefined : normalizeExpiry(expiresAt);
  return mutateRegistry('Edit AetherV2 key', async (data, operationId) => {
    const applied = findOperation(data, operationId);
    const selected = ensureRecord(data, id);
    if (applied) return {changed: false, result: {keyId: selected.id, record: selected.record, binding: data.bindings[selected.id] || null}};
    const changes = {};
    if (normalizedLabel !== undefined) selected.record.label = changes.label = normalizedLabel;
    if (normalizedExpiry !== undefined) selected.record.expiresAt = changes.expiresAt = normalizedExpiry;
    addAudit(data, 'edit', selected.id, actor, operationId, {changes});
    return {changed: true, result: {keyId: selected.id, record: selected.record, binding: data.bindings[selected.id] || null}};
  });
};

const findBoundKeyInData = (data, {username, userId} = {}) => {
  const name = String(username || '').trim().toLowerCase();
  const matches = Object.entries(data.bindings).filter(([, binding]) =>
    (!name || binding.username.toLowerCase() === name) && (!userId || binding.userId === String(userId))
  );
  if (matches.length === 0) throw problem('No matching username binding was found', 404);
  if (matches.length > 1) throw problem('More than one key matches; use a key ID', 409);
  return {keyId: matches[0][0], binding: matches[0][1]};
};

const findBoundKey = async filter => {
  const current = await readRegistry();
  return findBoundKeyInData(current.data, filter);
};

const unlinkKey = ({id, username, userId, actor} = {}) => mutateRegistry('Unlink AetherV2 key', async (data, operationId) => {
  const applied = findOperation(data, operationId);
  if (applied) return {changed: false, result: {keyId: applied.keyId, binding: {username: applied.username, userId: applied.userId}}};
  const selectedId = id ? resolveIdInData(data, id) : findBoundKeyInData(data, {username, userId}).keyId;
  const binding = data.bindings[selectedId];
  if (!binding) throw problem('This key is not currently bound', 404);
  delete data.bindings[selectedId];
  addAudit(data, 'unlink', selectedId, actor, operationId, {username: binding.username, userId: binding.userId});
  return {changed: true, result: {keyId: selectedId, binding}};
});

const setEnabled = ({id, actor}, enabled, action) => mutateRegistry((enabled ? 'Enable' : 'Revoke') + ' AetherV2 key', async (data, operationId) => {
  const applied = findOperation(data, operationId);
  const selected = ensureRecord(data, id);
  if (applied) return {changed: false, result: {keyId: selected.id, record: selected.record, binding: data.bindings[selected.id] || null}};
  if (enabled && selected.record.expiresAt && Date.parse(selected.record.expiresAt) <= Date.now()) {
    throw problem('This key is expired; renew it with /key renew before enabling it', 409);
  }
  if (selected.record.enabled === enabled) throw problem('This key is already ' + (enabled ? 'enabled' : 'revoked'), 409);
  selected.record.enabled = enabled;
  addAudit(data, action, selected.id, actor, operationId);
  return {changed: true, result: {keyId: selected.id, record: selected.record, binding: data.bindings[selected.id] || null}};
});

const revokeKey = options => setEnabled(options, false, 'revoke');
const enableKey = options => setEnabled(options, true, 'enable');

const renewKey = ({id, expiresAt, actor} = {}) => {
  const renewedUntil = requireFutureExpiry(expiresAt);
  return mutateRegistry('Renew AetherV2 key', async (data, operationId) => {
    const applied = findOperation(data, operationId);
    const selected = ensureRecord(data, id);
    if (applied) return {changed: false, result: {keyId: selected.id, record: selected.record, binding: data.bindings[selected.id] || null}};
    selected.record.expiresAt = renewedUntil;
    selected.record.enabled = true;
    addAudit(data, 'renew', selected.id, actor, operationId, {expiresAt: renewedUntil});
    return {changed: true, result: {keyId: selected.id, record: selected.record, binding: data.bindings[selected.id] || null}};
  });
};

const rotateKey = ({id, actor} = {}) => {
  const rawKey = crypto.randomBytes(32).toString('hex');
  const replacementId = keyId(rawKey);
  const createdAt = nowIso();
  return mutateRegistry('Rotate AetherV2 key', async (data, operationId) => {
    const applied = findOperation(data, operationId);
    if (applied) return {
      changed: false,
      result: {
        oldKeyId: applied.keyId,
        key: rawKey,
        keyId: applied.replacementKeyId,
        record: data.keys[applied.replacementKeyId],
        binding: data.bindings[applied.replacementKeyId] || null
      }
    };
    const selected = ensureRecord(data, id);
    if (selected.record.rotatedTo) throw problem('This key was already rotated; rotate its replacement instead', 409);
    if (data.keys[replacementId]) throw problem('Generated key ID collision; retry the command', 409);
    const oldBinding = data.bindings[selected.id] || null;
    const expiry = selected.record.expiresAt && Date.parse(selected.record.expiresAt) > Date.now()
      ? selected.record.expiresAt
      : null;
    selected.record.enabled = false;
    selected.record.rotatedTo = replacementId;
    const replacement = {
      label: selected.record.label || 'Rotated key',
      source: 'discord',
      createdAt,
      createdBy: normalizeActor(actor),
      enabled: true,
      expiresAt: expiry,
      rotatedFrom: selected.id
    };
    data.keys[replacementId] = replacement;
    if (oldBinding) {
      delete data.bindings[selected.id];
      data.bindings[replacementId] = {
        ...oldBinding,
        uses: 0,
        transferredAt: createdAt
      };
    }
    addAudit(data, 'rotate', selected.id, actor, operationId, {
      replacementKeyId: replacementId,
      transferredUsername: oldBinding && oldBinding.username
    });
    return {
      changed: true,
      result: {oldKeyId: selected.id, key: rawKey, keyId: replacementId, record: replacement, binding: data.bindings[replacementId] || null}
    };
  });
};

const toKeyInfo = (data, id) => {
  const record = data.keys[id];
  const binding = data.bindings[id] || null;
  return {
    keyId: id,
    label: record.label || 'Unlabelled',
    source: record.source,
    status: keyStatus(record),
    createdAt: record.createdAt,
    expiresAt: record.expiresAt,
    uses: binding ? binding.uses : 0,
    binding,
    record
  };
};

const listKeys = async (filters = {}) => {
  const current = await readRegistry();
  const status = String(filters.status || '').toLowerCase();
  const username = String(filters.username || '').trim().toLowerCase();
  const label = String(filters.label || '').trim().toLowerCase();
  const source = String(filters.source || '').trim().toLowerCase();
  return Object.keys(current.data.keys).sort().map(id => toKeyInfo(current.data, id)).filter(item =>
    (!status || status === 'all' || item.status === status) &&
    (!username || item.binding && item.binding.username.toLowerCase().includes(username)) &&
    (!label || item.label.toLowerCase().includes(label)) &&
    (!source || item.source.toLowerCase().includes(source))
  );
};

const getKeyInfo = async id => {
  const current = await readRegistry();
  const selectedId = resolveIdInData(current.data, id);
  return toKeyInfo(current.data, selectedId);
};

const getAudit = async limit => {
  const current = await readRegistry();
  const count = Math.max(1, Math.min(100, Number(limit) || 20));
  return current.data.audit.slice(-count).reverse();
};

module.exports = {
  keyId,
  validKeyId,
  validateRegistry,
  resolveKey,
  isValidKey,
  isKeyIdActive,
  bindKey,
  createKey,
  editKey,
  findBoundKey,
  unlinkKey,
  revokeKey,
  enableKey,
  renewKey,
  rotateKey,
  listKeys,
  getKeyInfo,
  getAudit,
  normalizeExpiry,
  keyStatus
};
