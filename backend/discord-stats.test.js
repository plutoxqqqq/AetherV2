'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GITHUB_TOKEN = 'test-token';
process.env.GITHUB_REPO = 'plutoxqqqq/AetherV2';
process.env.PUBLIC_ORIGIN = 'https://source.example.test';
process.env.DISCORD_OWNER_IDS = '111';

const bot = require('./discord-bot');

test('stats graph exposes daily ranges including all time', () => {
  const stats = bot.commands.find(command => command.name === 'stats');
  const graph = stats.options.find(option => option.name === 'graph');
  const period = graph.options.find(option => option.name === 'period');
  assert.deepEqual(period.choices.map(choice => choice.value), ['7d', '30d', '90d', 'all']);
});

test('stats summary exposes a details drill-down button', () => {
  const payload = bot.summaryView('111');
  const buttons = payload.components[0].toJSON().components;
  assert.equal(buttons[0].label, 'Details');
  assert.match(buttons[0].custom_id, /^aether:statslist:111:0$/);
});

test('enhanced bot preserves legacy key-management exports', () => {
  assert.equal(typeof bot.generatedText, 'function');
  assert.equal(typeof bot.keyListView, 'function');
  assert.equal(typeof bot.confirmationView, 'function');
  assert.equal(bot.isOwnerId('111'), true);
});
