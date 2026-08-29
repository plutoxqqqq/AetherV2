'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GITHUB_TOKEN = 'test-token';
process.env.GITHUB_REPO = 'plutoxqqqq/AetherV2';
process.env.GITHUB_BRANCH = 'release/security';
process.env.PUBLIC_ORIGIN = 'https://source.example.test';
process.env.DISCORD_OWNER_IDS = '111,222';

const registry = require('./key-registry');
const bot = require('./discord-bot');

test('slash command schema includes renewal and all key-list filters', () => {
  const key = bot.commands.find(command => command.name === 'key');
  const renew = key.options.find(option => option.name === 'renew');
  const list = key.options.find(option => option.name === 'list');
  assert.ok(renew);
  assert.deepEqual(list.options.map(option => option.name), ['status', 'username', 'label', 'source']);
});

test('owner authorization uses immutable configured Discord IDs', async () => {
  let payload;
  const interaction = {
    commandName: 'key',
    user: {id: '999', username: 'not-owner'},
    deferred: false,
    replied: false,
    isChatInputCommand: () => true,
    isButton: () => false,
    isStringSelectMenu: () => false,
    isModalSubmit: () => false,
    reply: async value => { payload = value; }
  };
  await bot.handleInteraction(interaction);
  assert.equal(bot.isOwnerId('111'), true);
  assert.equal(bot.isOwnerId('999'), false);
  assert.equal(payload.ephemeral, true);
  assert.match(payload.content, /not authorized/i);
});

test('generated premium keys and loaders support desktop and mobile copying', () => {
  const raw = 'c'.repeat(64);
  const content = bot.generatedText({key: raw, keyId: 'd'.repeat(64), record: {label: 'Customer', expiresAt: null}});
  assert.ok(content.length <= bot.MESSAGE_LIMIT);
  assert.match(content, /```text\n[c]+\n```/);
  assert.match(content, /`[c]+`/);
  assert.match(content, /```lua\nloadstring/);
  assert.match(content, /`loadstring\(game:HttpGet/);
  assert.match(content, /raw\.githubusercontent\.com\/plutoxqqqq\/AetherV2\/main\/init\.lua/);
  assert.match(content, /premiumKey = \"[c]+\"/);
  assert.doesNotMatch(content, /\/loader\?key=/);
  assert.match(content, /only unlocks AetherV2 Premium/i);
  assert.match(content, /cannot be shown again/i);
});

test('destructive key actions require an explicit confirmation button', async () => {
  const original = registry.getKeyInfo;
  registry.getKeyInfo = async () => ({
    keyId: 'e'.repeat(64), label: 'Confirm me', status: 'active', source: 'discord',
    createdAt: null, expiresAt: null, uses: 0, binding: null
  });
  try {
    const payload = await bot.confirmationView('111', 'revoke', 'e'.repeat(16), 'view', 0);
    const buttons = payload.components[0].toJSON().components;
    assert.equal(buttons.length, 2);
    assert.match(buttons[0].custom_id, /:yes$/);
    assert.match(buttons[1].custom_id, /:cancel$/);
  } finally {
    registry.getKeyInfo = original;
  }
});

test('audit pagination cannot exceed Discord embed limits', async () => {
  const original = registry.getAudit;
  registry.getAudit = async () => Array.from({length: 100}, (_, index) => ({
    at: new Date(1700000000000 + index * 1000).toISOString(),
    action: 'rotate',
    keyId: String(index).padStart(64, 'a').slice(-64),
    actor: 'owner-' + 'x'.repeat(90),
    replacementKeyId: 'f'.repeat(64),
    transferredUsername: 'Example_User'
  }));
  try {
    const payload = await bot.auditView('111', 0, 100);
    const embed = payload.embeds[0].toJSON();
    assert.ok(embed.description.length <= bot.EMBED_DESCRIPTION_LIMIT);
    assert.ok(payload.components.length <= 5);
  } finally {
    registry.getAudit = original;
  }
});
