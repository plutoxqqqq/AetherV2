'use strict';

const http = require('node:http');
const crypto = require('node:crypto');

const PORT = Number(process.env.PORT || 3000);
const REPOSITORY = process.env.GITHUB_REPO || 'plutoxqqqq/AetherV2';
const BRANCH = process.env.GITHUB_BRANCH || 'main';
const TOKEN = process.env.GITHUB_TOKEN || '';

if (!TOKEN) {
  throw new Error('GITHUB_TOKEN is required');
}

const headers = {
  authorization: `Bearer ${TOKEN}`,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-private-source-proxy',
  'x-github-api-version': '2022-11-28'
};

const validRef = value =>
  typeof value === 'string' && value.length > 0 && value.length <= 200 &&
  !value.includes('..') && !value.includes('\\') && !value.includes('?') &&
  !value.includes('#');

const validPath = value =>
  typeof value === 'string' && value.length > 0 && value.length <= 300 &&
  !value.startsWith('/') && !value.includes('\\') &&
  value.split('/').every(segment => segment && segment !== '.' && segment !== '..');

const json = (res, status, value) => {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,OPTIONS',
    'access-control-allow-headers': 'content-type'
  });
  res.end(JSON.stringify(value));
};

const text = (res, status, value, contentType = 'text/plain; charset=utf-8') => {
  res.writeHead(status, {
    'content-type': contentType,
    'cache-control': 'no-store',
    'access-control-allow-origin': '*'
  });
  res.end(value);
};

const github = async endpoint => {
  const response = await fetch(`https://api.github.com/repos/${REPOSITORY}/${endpoint}`, {headers});
  if (!response.ok) {
    const error = new Error(`GitHub request failed with HTTP ${response.status}`);
    error.status = response.status === 404 ? 404 : 502;
    throw error;
  }
  return response;
};

const sourceFile = async (file, ref) => {
  const response = await github(`contents/${file}?ref=${encodeURIComponent(ref)}`);
  const value = await response.json();
  if (value.type !== 'file' || typeof value.content !== 'string') {
    const error = new Error('GitHub returned an invalid source file');
    error.status = 502;
    throw error;
  }
  return Buffer.from(value.content.replace(/\\n/g, ''), 'base64').toString('utf8');
};

const commitSha = async ref => {
  const value = await (await github(`commits/${encodeURIComponent(ref)}`)).json();
  if (typeof value.sha !== 'string') {
    const error = new Error('GitHub returned an invalid commit');
    error.status = 502;
    throw error;
  }
  return value.sha;
};

const tree = async ref =>
  (await github(`git/trees/${encodeURIComponent(ref)}?recursive=1`)).text();

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return res.writeHead(204).end();

    const url = new URL(req.url, 'http://localhost');
    const ref = url.searchParams.get('ref') || BRANCH;

    if (!validRef(ref)) return json(res, 400, {success: false, error: 'Invalid ref'});

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, {success: true, service: 'aetherv2-private-source'});
    }

    if (req.method === 'GET' && url.pathname === '/source') {
      const file = url.searchParams.get('path');
      if (!validPath(file)) return json(res, 400, {success: false, error: 'Invalid source path'});
      return text(res, 200, await sourceFile(file, ref));
    }

    if (req.method === 'GET' && url.pathname === '/commit') {
      return text(res, 200, await commitSha(ref));
    }

    if (req.method === 'GET' && url.pathname === '/tree') {
      return text(res, 200, await tree(ref), 'application/json; charset=utf-8');
    }

    return json(res, 404, {success: false, error: 'Not found'});
  } catch (error) {
    return json(res, error.status || 500, {success: false, error: error.message || 'Proxy failure'});
  }
});

if (require.main === module) {
  server.listen(PORT, () => console.log(`AetherV2 private-source proxy listening on port ${PORT}`));
}

module.exports = {server, validPath, validRef};
