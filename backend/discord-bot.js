'use strict';

const {
  Client,
  GatewayIntentBits,
  REST,
  Routes,
  SlashCommandBuilder
} = require('discord.js');
const registry = require('./key-registry');

const OWNER_IDS = new Set(
  (process.env.DISCORD_OWNER_IDS || process.env.DISCORD_OWNER_ID || '')
    .split(',')
    .map(value => value.trim())
    .filter(Boolean)
);
const APPLICATION_ID = process.env.DISCORD_APPLICATION_ID || '';
const GUILD_ID = process.env.DISCORD_GUILD_ID || '';
const SOURCE_ORIGIN = (process.env.PUBLIC_ORIGIN || 'https://aetherv2.onrender.com').replace(/\/+$/, '');
const CODE_FENCE = String.fromCharCode(96).repeat(3);

const optionString = (name, description) => option =>
  option.setName(name).setDescription(description).setRequired(false);

const commands = [
  new SlashCommandBuilder()
    .setName('key')
    .setDescription('Manage AetherV2 access keys')
    .setDMPermission(false)
    .addSubcommand(sub => sub
      .setName('generate')
      .setDescription('Generate a new unbound key')
      .addStringOption(optionString('label', 'Optional label for this key'))
      .addStringOption(optionString('expires_at', 'ISO date/time or none')))
    .addSubcommand(sub => sub
      .setName('list')
      .setDescription('List key IDs and their current status')
      .addIntegerOption(option => option
        .setName('limit')
        .setDescription('Number of keys to show')
        .setMinValue(1)
        .setMaxValue(50)
        .setRequired(false)))
    .addSubcommand(sub => sub
      .setName('info')
      .setDescription('Show details for one key ID')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('The full SHA-256 key ID')
        .setRequired(true)))
    .addSubcommand(sub => sub
      .setName('edit')
      .setDescription('Edit a key label, expiry, or enabled state')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('The full SHA-256 key ID')
        .setRequired(true))
      .addStringOption(optionString('label', 'New label, or none to clear it'))
      .addStringOption(optionString('expires_at', 'New ISO date/time, or none'))
      .addBooleanOption(option => option
        .setName('enabled')
        .setDescription('Whether this key can be used')
        .setRequired(false)))
    .addSubcommand(sub => sub
      .setName('unlink')
      .setDescription('Unlink a key so another account can claim it')
      .addStringOption(optionString('key_id', 'The full SHA-256 key ID'))
      .addStringOption(optionString('username', 'Roblox username to unlink'))
      .addStringOption(optionString('user_id', 'Roblox UserId to disambiguate')))
    .addSubcommand(sub => sub
      .setName('revoke')
      .setDescription('Disable a key without deleting its history')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('The full SHA-256 key ID')
        .setRequired(true)))
    .addSubcommand(sub => sub
      .setName('enable')
      .setDescription('Re-enable a revoked key')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('The full SHA-256 key ID')
        .setRequired(true)))
    .addSubcommand(sub => sub
      .setName('rotate')
      .setDescription('Revoke a key and generate a replacement')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('The full SHA-256 key ID')
        .setRequired(true)))
    .addSubcommand(sub => sub
      .setName('audit')
      .setDescription('Show recent key-management events')
      .addIntegerOption(option => option
        .setName('limit')
        .setDescription('Number of events to show')
        .setMinValue(1)
        .setMaxValue(100)
        .setRequired(false)))
].map(command => command.toJSON());

const actorName = interaction =>
  interaction.user.username + ' (' + interaction.user.id + ')';

const dateText = value => {
  if (!value) return 'never';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? String(value) : date.toISOString();
};

const bindingText = binding => binding
  ? binding.username + ' (' + binding.userId + ')'
  : 'unbound';

const reply = async (interaction, content) => {
  const payload = {content, allowedMentions: {parse: []}};
  if (interaction.deferred || interaction.replied) return interaction.editReply(payload);
  return interaction.reply({...payload, ephemeral: true});
};

const keyIdFrom = interaction =>
  interaction.options.getString('key_id', false);

const handleKeyCommand = async interaction => {
  const subcommand = interaction.options.getSubcommand();
  const actor = actorName(interaction);

  if (subcommand === 'generate') {
    const result = await registry.createKey({
      label: interaction.options.getString('label', false) || undefined,
      expiresAt: interaction.options.getString('expires_at', false) || undefined,
      actor
    });
    const loader = 'loadstring(game:HttpGet("' + SOURCE_ORIGIN + '/loader?key=' + result.key + '", true))()';
    return reply(interaction, [
      'Generated key.',
      'Key ID: ' + result.keyId,
      'Label: ' + result.record.label,
      'Expires: ' + dateText(result.record.expiresAt),
      '',
      'Raw key — copy it now. It will not be stored or shown again:',
      CODE_FENCE + result.key + CODE_FENCE,
      '',
      'Loader:',
      CODE_FENCE + 'lua\n' + loader + '\n' + CODE_FENCE
    ].join('\n'));
  }

  if (subcommand === 'list') {
    const limit = interaction.options.getInteger('limit', false) || 20;
    const keys = (await registry.listKeys()).slice(0, limit);
    if (keys.length === 0) return reply(interaction, 'No keys are registered.');
    const lines = keys.map(item => [
      item.keyId.slice(0, 16) + '…',
      item.status,
      item.label,
      'bound: ' + bindingText(item.binding),
      'uses: ' + item.uses,
      item.expiresAt ? 'expires: ' + dateText(item.expiresAt) : ''
    ].filter(Boolean).join(' | '));
    let output = CODE_FENCE + lines.join('\n') + CODE_FENCE;
    if (output.length > 1900) {
      output = CODE_FENCE + lines.slice(0, 10).join('\n') +
        '\n… list shortened; use /key info for a specific key' + CODE_FENCE;
    }
    return reply(interaction, output);
  }

  if (subcommand === 'info') {
    const info = await registry.getKeyInfo(keyIdFrom(interaction));
    return reply(interaction, [
      'Key ID: ' + info.keyId,
      'Label: ' + info.label,
      'Source: ' + info.source,
      'Status: ' + info.status,
      'Created: ' + dateText(info.createdAt),
      'Expires: ' + dateText(info.expiresAt),
      'Uses: ' + info.uses,
      'Binding: ' + bindingText(info.binding)
    ].join('\n'));
  }

  if (subcommand === 'edit') {
    const result = await registry.editKey({
      id: keyIdFrom(interaction),
      label: interaction.options.getString('label', false) ?? undefined,
      expiresAt: interaction.options.getString('expires_at', false) ?? undefined,
      enabled: interaction.options.getBoolean('enabled', false) ?? undefined,
      actor
    });
    return reply(interaction, [
      'Updated key ' + result.keyId + '.',
      'Label: ' + (result.record.label || 'none'),
      'Status: ' + (result.record.enabled === false ? 'disabled' : 'enabled'),
      'Expires: ' + dateText(result.record.expiresAt),
      'Binding: ' + bindingText(result.binding)
    ].join('\n'));
  }

  if (subcommand === 'unlink') {
    const id = interaction.options.getString('key_id', false) || undefined;
    const username = interaction.options.getString('username', false) || undefined;
    const userId = interaction.options.getString('user_id', false) || undefined;
    if (Boolean(id) === Boolean(username)) {
      return reply(interaction, 'Provide exactly one of key_id or username.');
    }
    const result = await registry.unlinkKey({id, username, userId, actor});
    return reply(interaction, 'Unlinked ' + result.binding.username + ' from key ' + result.keyId + '. The key can now bind to another account.');
  }

  if (subcommand === 'revoke' || subcommand === 'enable') {
    const id = keyIdFrom(interaction);
    const result = subcommand === 'revoke'
      ? await registry.revokeKey({id, actor})
      : await registry.enableKey({id, actor});
    return reply(interaction, (subcommand === 'revoke' ? 'Revoked ' : 'Enabled ') + result.keyId + '.');
  }

  if (subcommand === 'rotate') {
    const result = await registry.rotateKey({id: keyIdFrom(interaction), actor});
    const loader = 'loadstring(game:HttpGet("' + SOURCE_ORIGIN + '/loader?key=' + result.key + '", true))()';
    return reply(interaction, [
      'Rotated key ' + result.oldKeyId + '. The old key is disabled.',
      'New key ID: ' + result.keyId,
      'Binding transferred: ' + bindingText(result.binding),
      '',
      'New raw key — copy it now:',
      CODE_FENCE + result.key + CODE_FENCE,
      '',
      'New loader:',
      CODE_FENCE + 'lua\n' + loader + '\n' + CODE_FENCE
    ].join('\n'));
  }

  if (subcommand === 'audit') {
    const events = await registry.getAudit(interaction.options.getInteger('limit', false) || 20);
    if (events.length === 0) return reply(interaction, 'No key-management events recorded.');
    const lines = events.map(event => [
      dateText(event.at),
      event.action,
      event.keyId ? event.keyId.slice(0, 16) + '…' : '',
      event.username ? event.username : '',
      event.actor
    ].filter(Boolean).join(' | '));
    return reply(interaction, CODE_FENCE + lines.join('\n') + CODE_FENCE);
  }

  return reply(interaction, 'Unknown key command.');
};

const handleInteraction = async interaction => {
  if (!interaction.isChatInputCommand() || interaction.commandName !== 'key') return;
  if (!OWNER_IDS.has(interaction.user.id)) {
    return reply(interaction, 'You are not authorized to manage AetherV2 keys.');
  }

  await interaction.deferReply({ephemeral: true});
  try {
    await handleKeyCommand(interaction);
  } catch (error) {
    console.error('[AetherV2] Discord key command failed:', error.message || error);
    await reply(interaction, 'Error: ' + (error.message || 'Key operation failed'));
  }
};

const registerCommands = async client => {
  const rest = new REST({version: '10'}).setToken(process.env.DISCORD_TOKEN);
  const route = GUILD_ID
    ? Routes.applicationGuildCommands(APPLICATION_ID, GUILD_ID)
    : Routes.applicationCommands(APPLICATION_ID);
  await rest.put(route, {body: commands});
  console.log('[AetherV2] registered Discord key commands' + (GUILD_ID ? ' for guild ' + GUILD_ID : ' globally'));
};

const startDiscordBot = async () => {
  if (!process.env.DISCORD_TOKEN) throw new Error('DISCORD_TOKEN is required');
  if (!APPLICATION_ID) throw new Error('DISCORD_APPLICATION_ID is required');
  if (OWNER_IDS.size === 0) throw new Error('DISCORD_OWNER_IDS is required');

  const client = new Client({intents: [GatewayIntentBits.Guilds]});
  client.once('ready', async () => {
    try {
      await registerCommands(client);
      console.log('[AetherV2] Discord bot logged in as ' + client.user.tag);
    } catch (error) {
      console.error('[AetherV2] Discord command registration failed:', error.message || error);
    }
  });
  client.on('interactionCreate', interaction => {
    handleInteraction(interaction).catch(error => {
      console.error('[AetherV2] Discord interaction failed:', error.message || error);
    });
  });
  await client.login(process.env.DISCORD_TOKEN);
  return client;
};

module.exports = {startDiscordBot, commands};
