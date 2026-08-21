'use strict';

const fs = require('node:fs');
const path = require('node:path');
const child = require('node:child_process');

const root = path.resolve(__dirname, '..');
const run = command => {
  try { return child.execFileSync('git', command, {cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore']}).trim(); }
  catch { return ''; }
};
const versionText = fs.readFileSync(path.join(root, 'version.txt'), 'utf8');
const version = (versionText.match(/version\s*=\s*([^\r\n]+)/) || [])[1]?.trim() || 'unknown';

function sourceFiles(folder) {
  const absolute = path.join(root, folder);
  if (!fs.existsSync(absolute)) return [];
  const result = [];
  for (const entry of fs.readdirSync(absolute, {withFileTypes: true})) {
    const relative = path.join(folder, entry.name);
    if (entry.isDirectory()) result.push(...sourceFiles(relative));
    else if (entry.name.endsWith('.lua')) result.push(relative);
  }
  return result;
}

function field(chunk, name) {
  const match = chunk.match(new RegExp('\\b' + name + '\\s*=\\s*([\\\'\"])(.*?)\\1'));
  return match ? match[2].replace(/\\n/g, '\n').replace(/\\([\\\'\"])/g, '$1') : undefined;
}

// Module settings are the manifest: Version, Changed and ChangeType sit beside Name in the
// CreateModule table. The generated catalogue includes unchanged modules too, giving diagnostics
// and tooling one authoritative inventory without another hand-maintained feature list.
const discovered = new Map();
for (const file of [...sourceFiles('games'), ...sourceFiles('guis'), ...sourceFiles('libraries')]) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  const marker = /CreateModule\s*\(\s*\{/g;
  for (let match; (match = marker.exec(text));) {
    const chunk = text.slice(match.index, match.index + 2200);
    const name = field(chunk, 'Name');
    if (!name) continue;
    const item = {
      name,
      version: field(chunk, 'Version') || version,
      changed: field(chunk, 'Changed') || '',
      changeType: field(chunk, 'ChangeType') || 'Maintained',
      source: file
    };
    const current = discovered.get(name);
    if (!current || (!current.changed && item.changed)) discovered.set(name, item);
  }
}
const modules = [...discovered.values()].sort((a, b) => a.name.localeCompare(b.name));
const changes = modules.filter(item => item.changed);
const added = changes.filter(item => item.changeType === 'Added').map(item => item.name);
const updated = changes.filter(item => item.changeType !== 'Added').map(item => item.name);
const sigil = {Added: '[+]', Improved: '[^]', Fixed: '[!]', Removed: '[-]'};
const featureText = changes.map(item => `${sigil[item.changeType] || '[^]'} ${item.name}: ${item.changed}`).join('\n');
const features = {added, updated, text: featureText, newModules: added, updatedModules: updated, removedModules: []};

fs.writeFileSync(path.join(root, 'profiles', 'modules.json'), JSON.stringify({version, modules}, null, 2) + '\n');
fs.writeFileSync(path.join(root, 'profiles', 'features.json'), JSON.stringify(features, null, 2) + '\n');

const sections = {Added: [], Improved: [], Fixed: [], Other: []};
for (const item of changes) (sections[item.changeType] || sections.Improved).push(`${item.name}: ${item.changed}`);
const tag = run(['describe', '--tags', '--abbrev=0']);
const range = tag ? tag + '..HEAD' : 'HEAD~25..HEAD';
const log = run(['log', range, '--pretty=format:%s']);
for (const subject of log.split('\n').map(line => line.trim()).filter(Boolean)) {
  const clean = subject.replace(/^(feat|fix|perf|refactor|chore)(\([^)]*\))?!?:\s*/i, '');
  if (!Object.values(sections).some(items => items.includes(clean))) sections.Other.push(clean);
}
const highlights = changes.slice(0, 12).map(item => `${item.name}: ${item.changed}`);
if (!highlights.length) highlights.push('No module-level changes declared for this build.');
const commitTime = Number(run(['log', '-1', '--pretty=format:%ct'])) || Math.floor(Date.now() / 1000);
const generatedAt = new Date(Number(process.env.SOURCE_DATE_EPOCH || commitTime) * 1000).toISOString();
const payload = {version, generatedAt, range, highlights, sections};
fs.writeFileSync(path.join(root, 'profiles', 'changelog.json'), JSON.stringify(payload, null, 2) + '\n');

const markdown = ['# AetherV2 Changelog', '', `Generated from module manifests and Git history for v${version} at ${generatedAt}.`, '', '## Highlights', ''];
for (const item of highlights) markdown.push('- ' + item);
for (const [name, items] of Object.entries(sections)) {
  if (!items.length) continue;
  markdown.push('', '## ' + name, '');
  for (const item of items) markdown.push('- ' + item);
}
markdown.push('');
fs.writeFileSync(path.join(root, 'CHANGELOG.md'), markdown.join('\n'));
