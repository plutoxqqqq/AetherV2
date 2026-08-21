'use strict';

const fs = require('node:fs');
const path = require('node:path');

function normalize(value) {
  const data = value && typeof value === 'object' ? value : {};
  return {
    schemaVersion: 2,
    submissions: Array.isArray(data.submissions) ? data.submissions : [],
    publicConfigs: data.publicConfigs && typeof data.publicConfigs === 'object' ? data.publicConfigs : {},
    ratings: data.ratings && typeof data.ratings === 'object' ? data.ratings : {},
    favorites: data.favorites && typeof data.favorites === 'object' ? data.favorites : {},
    reports: Array.isArray(data.reports) ? data.reports : [],
    creators: data.creators && typeof data.creators === 'object' ? data.creators : {},
    audit: Array.isArray(data.audit) ? data.audit : []
  };
}

class JsonDatabase {
  constructor(file) {
    this.file = file;
    this.data = normalize();
    this.queue = this.load();
  }

  async load() {
    try { this.data = normalize(JSON.parse(await fs.promises.readFile(this.file, 'utf8'))); }
    catch { this.data = normalize(); }
  }

  async persist(data) {
    const normalized = normalize(data);
    await fs.promises.mkdir(path.dirname(this.file), {recursive: true});
    const temporary = `${this.file}.${process.pid}.${Date.now()}.tmp`;
    await fs.promises.writeFile(temporary, `${JSON.stringify(normalized, null, 2)}\n`, {mode: 0o600});
    await fs.promises.rename(temporary, this.file);
    this.data = normalized;
    return normalized;
  }

  async read() {
    await this.queue;
    return structuredClone(this.data);
  }

  async write(data) {
    let result;
    const operation = this.queue.then(async () => { result = await this.persist(structuredClone(data)); });
    this.queue = operation.catch(() => {});
    await operation;
    return structuredClone(result);
  }

  async transaction(mutator) {
    let result;
    const operation = this.queue.then(async () => {
      const data = structuredClone(this.data);
      result = await mutator(data);
      await this.persist(data);
    });
    this.queue = operation.catch(() => {});
    await operation;
    return result;
  }
}

class MemoryDatabase {
  constructor(initial) {
    this.data = normalize(initial);
  }
  async read() {
    return structuredClone(this.data);
  }
  async write(data) {
    this.data = normalize(structuredClone(data));
    return structuredClone(this.data);
  }
  async transaction(mutator) {
    const data = structuredClone(this.data);
    const result = await mutator(data);
    this.data = normalize(structuredClone(data));
    return result;
  }
}

function createDatabase(options = {}) {
  return options.memory ? new MemoryDatabase(options.initial) : new JsonDatabase(options.file);
}

module.exports = {JsonDatabase, MemoryDatabase, createDatabase, normalize};
