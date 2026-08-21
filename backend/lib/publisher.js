'use strict';

const {hash} = require('./security');

const supplied = (value, fallback) => value !== undefined && value !== null && value !== '' && (!Array.isArray(value) || value.length) ? value : fallback;
const validFile = file => typeof file === 'string' && file.endsWith('.json') && file !== 'presets.json' && !file.includes('/') && !file.includes('\\');

class GitHubPublisher {
  constructor(env = process.env) {
    this.token = env.GITHUB_TOKEN || '';
    this.repo = env.GITHUB_REPO || '';
    this.baseBranch = env.GITHUB_BRANCH || 'main';
    this.mode = (env.GITHUB_PUBLISH_MODE || 'pr').toLowerCase();
    this.timeoutMs = Math.max(1_000, Math.min(Number(env.GITHUB_TIMEOUT_MS) || 15_000, 120_000));
    this.api = `https://api.github.com/repos/${this.repo}`;
  }

  get configured() {
    return Boolean(this.token && this.repo);
  }

  headers(extra = {}) {
    return {
      authorization: `Bearer ${this.token}`,
      accept: 'application/vnd.github+json',
      'user-agent': 'aetherv2-config-bot',
      'x-github-api-version': '2022-11-28',
      ...extra
    };
  }

  async request(endpoint, options = {}) {
    if (!this.configured) throw Object.assign(Error('GitHub publishing is not configured'), {status: 503});
    let response;
    try {
      response = await fetch(`${this.api}${endpoint}`, {
        ...options,
        headers: this.headers(options.headers),
        signal: AbortSignal.timeout(this.timeoutMs)
      });
    } catch (error) {
      const message = error?.name === 'TimeoutError' ? 'GitHub request timed out' : 'GitHub request could not be completed';
      throw Object.assign(Error(message), {status: 502});
    }
    const text = await response.text();
    const value = text ? (() => { try { return JSON.parse(text); } catch { return text; } })() : {};
    if (!response.ok) throw Object.assign(Error(`GitHub request failed (${response.status})`), {status: 502, details: value});
    return value;
  }

  async getFile(file, branch = this.baseBranch, required = true) {
    try {
      const value = await this.request(`/contents/configs/${encodeURIComponent(file)}?ref=${encodeURIComponent(branch)}`);
      return {...value, decoded: Buffer.from(String(value.content || '').replace(/\n/g, ''), 'base64').toString()};
    } catch (error) {
      if (!required && error.details && error.details.status === '404') return null;
      if (!required && /404/.test(error.message)) return null;
      throw error;
    }
  }

  async putFile(file, content, sha, message, branch) {
    return this.request(`/contents/configs/${encodeURIComponent(file)}`, {
      method: 'PUT',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({message, branch, content: Buffer.from(content).toString('base64'), ...(sha && {sha})})
    });
  }

  async deleteFile(file, sha, message, branch) {
    return this.request(`/contents/configs/${encodeURIComponent(file)}`, {
      method: 'DELETE',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({message, branch, sha})
    });
  }

  async createContext(label, requestId) {
    if (this.mode === 'direct') return {branch: this.baseBranch, direct: true};
    const base = await this.request(`/git/ref/heads/${this.baseBranch.split('/').map(encodeURIComponent).join('/')}`);
    const slug = String(label || 'config').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 28) || 'config';
    const branch = `aether-configs/${Date.now()}-${slug}-${String(requestId).slice(0, 8)}`;
    await this.request('/git/refs', {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({ref: `refs/heads/${branch}`, sha: base.object.sha})
    });
    return {branch, direct: false};
  }

  async finishContext(context, title, body) {
    if (context.direct) return {branch: context.branch};
    const pr = await this.request('/pulls', {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({title, body, head: context.branch, base: this.baseBranch, maintainer_can_modify: true})
    });
    return {branch: context.branch, pullRequest: pr.number, pullRequestUrl: pr.html_url};
  }

  async rollbackPayload(file, previous, branch) {
    const current = await this.getFile(file, branch, false);
    if (!current) return;
    if (previous) {
      await this.putFile(file, previous.decoded, current.sha, `Rollback failed publish: ${file}`, branch);
    } else {
      await this.deleteFile(file, current.sha, `Rollback failed publish: ${file}`, branch);
    }
  }

  async publish(item, requestId) {
    const slug = item.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || item.id;
    const file = item.targetFile && validFile(item.targetFile) ? item.targetFile : `${slug}.json`;
    const context = await this.createContext(item.name, requestId);
    const existingFile = await this.getFile(file, context.branch, false);
    const presetRemote = await this.getFile('presets.json', context.branch);
    const manifest = JSON.parse(presetRemote.decoded);
    const presets = Array.isArray(manifest.presets) ? manifest.presets : [];
    const old = presets.find(p => p.file === file) || presets.find(p => String(p.name).toLowerCase() === String(item.name).toLowerCase()) || {};
    const version = Number(old.version || 0) + 1;
    const configHash = hash(item.config);
    const now = new Date().toISOString();
    const metadata = {
      ...old,
      name: item.displayName || item.name,
      file,
      credits: supplied(item.creator, old.credits),
      tags: supplied([item.category, ...(item.tags || [])].filter(Boolean), old.tags),
      description: supplied(item.description, old.description),
      category: supplied(item.category, old.category),
      minimumVersion: supplied(item.minimumVersion, old.minimumVersion || '4.0.0'),
      gameVersion: supplied(item.gameVersion, old.gameVersion),
      screenshots: supplied(item.screenshots, old.screenshots),
      forkOf: supplied(item.forkOf, old.forkOf),
      deprecated: item.deprecated === undefined ? Boolean(old.deprecated) : Boolean(item.deprecated),
      version,
      versionLabel: `v${version}`,
      hash: configHash,
      createdAt: old.createdAt || now,
      updatedAt: now,
      lastPublishedAt: now
    };
    const wrapper = {
      name: metadata.name,
      credits: metadata.credits,
      tags: metadata.tags,
      description: metadata.description,
      game: item.game,
      hash: configHash,
      version,
      minimumVersion: metadata.minimumVersion,
      gameVersion: metadata.gameVersion,
      screenshots: metadata.screenshots,
      forkOf: metadata.forkOf,
      deprecated: metadata.deprecated,
      config: JSON.stringify(item.config),
      ...(item.gui && {gui: JSON.stringify(item.gui)})
    };
    const payload = `${JSON.stringify(wrapper, null, 2)}\n`;
    await this.putFile(file, payload, existingFile && existingFile.sha, `Publish config: ${item.name} v${version}`, context.branch);
    try {
      manifest.presets = presets.filter(p => p.file !== file && String(p.name).toLowerCase() !== String(item.name).toLowerCase());
      manifest.presets.push(metadata);
      await this.putFile('presets.json', `${JSON.stringify(manifest, null, 2)}\n`, presetRemote.sha, `List config: ${item.name} v${version}`, context.branch);
    } catch (error) {
      await this.rollbackPayload(file, existingFile, context.branch).catch(() => {});
      throw error;
    }
    const review = await this.finishContext(context, `Config: ${metadata.name} v${version}`, `Automated AetherV2 config publication.\n\nSHA-256: \`${configHash}\`\nRequest: \`${requestId}\``);
    return {file, version, hash: configHash, metadata, ...review};
  }

  async remove(file, requestId) {
    if (!validFile(file)) throw Object.assign(Error('Invalid public config file'), {status: 400});
    const context = await this.createContext(`delete-${file}`, requestId);
    const presetRemote = await this.getFile('presets.json', context.branch);
    const configRemote = await this.getFile(file, context.branch);
    const manifest = JSON.parse(presetRemote.decoded);
    const presets = Array.isArray(manifest.presets) ? manifest.presets : [];
    if (!presets.some(p => p.file === file)) throw Object.assign(Error('The requested file is not a known Public Config'), {status: 404});
    const previousManifest = presetRemote.decoded;
    manifest.presets = presets.filter(p => p.file !== file);
    await this.putFile('presets.json', `${JSON.stringify(manifest, null, 2)}\n`, presetRemote.sha, `Unlist config: ${file}`, context.branch);
    try {
      await this.deleteFile(file, configRemote.sha, `Delete config: ${file}`, context.branch);
    } catch (error) {
      const currentManifest = await this.getFile('presets.json', context.branch).catch(() => null);
      if (currentManifest) await this.putFile('presets.json', previousManifest, currentManifest.sha, `Rollback deletion: ${file}`, context.branch).catch(() => {});
      throw error;
    }
    const review = await this.finishContext(context, `Delete config: ${file}`, `Automated AetherV2 config removal.\n\nRequest: \`${requestId}\``);
    return {file, ...review};
  }
}

module.exports = {GitHubPublisher, validFile};
