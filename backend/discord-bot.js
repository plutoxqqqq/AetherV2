'use strict';

const {
  Client,
  GatewayIntentBits,
  REST,
  Routes,
  SlashCommandBuilder,
  EmbedBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  StringSelectMenuBuilder,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle
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
const PAGE_SIZE = 8;

const optionString = (name, description) => option =>
  option.setName(name).setDescription(description).setRequired(false);

const commands = [
  new SlashCommandBuilder()
    .setName('key')
    .setDescription('Manage AetherV2 access keys')
    .setDMPermission(false)
    .addSubcommand(sub => sub
      .setName('panel')
      .setDescription('Open the AetherV2 key dashboard'))
    .addSubcommand(sub => sub
      .setName('generate')
      .setDescription('Generate a new unbound key')
      .addStringOption(optionString('label', 'Optional label for this key'))
      .addStringOption(optionString('expires_at', 'ISO date/time or none')))
    .addSubcommand(sub => sub
      .setName('list')
      .setDescription('Browse every active and inactive key'))
    .addSubcommand(sub => sub
      .setName('info')
      .setDescription('Show details for one key ID or unique prefix')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('Full key ID or unique prefix')
        .setRequired(true)))
    .addSubcommand(sub => sub
      .setName('edit')
      .setDescription('Edit a key label, expiry, or enabled state')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('Full key ID or unique prefix')
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
      .addStringOption(optionString('key_id', 'Full key ID or unique prefix'))
      .addStringOption(optionString('username', 'Roblox username to unlink'))
      .addStringOption(optionString('user_id', 'Roblox UserId to disambiguate')))
    .addSubcommand(sub => sub
      .setName('revoke')
      .setDescription('Disable a key without deleting its history')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('Full key ID or unique prefix')
        .setRequired(true)))
    .addSubcommand(sub => sub
      .setName('enable')
      .setDescription('Re-enable a revoked key')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('Full key ID or unique prefix')
        .setRequired(true)))
    .addSubcommand(sub => sub
      .setName('rotate')
      .setDescription('Revoke a key and generate a replacement')
      .addStringOption(option => option
        .setName('key_id')
        .setDescription('Full key ID or unique prefix')
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

const bindingText = binding =>
  binding ? binding.username + ' (' + binding.userId + ')' : 'unbound';

const statusText = status => ({
  active: 'Active',
  disabled: 'Disabled',
  expired: 'Expired'
}[status] || 'Unknown');

const statusIcon = status => ({
  active: '🟢',
  disabled: '🔴',
  expired: '🟠'
}[status] || '⚪');

const statusRank = status => ({
  active: 0,
  expired: 1,
  disabled: 2
}[status] ?? 3);

const truncate = (value, length) => {
  const text = String(value || '');
  return text.length <= length ? text : text.slice(0, length - 1) + '…';
};

const respond = async (interaction, payload) => {
  const value = {...payload, allowedMentions: {parse: []}};
  if (interaction.deferred || interaction.replied) return interaction.editReply(value);
  return interaction.reply({...value, ephemeral: true});
};

const reply = (interaction, content) => respond(interaction, {content});

const updateComponent = async (interaction, payloadPromise) => {
  if (!interaction.deferred && !interaction.replied) await interaction.deferUpdate();
  const payload = await payloadPromise;
  return interaction.editReply({...payload, allowedMentions: {parse: []}});
};

const button = (customId, label, style = ButtonStyle.Secondary, disabled = false) =>
  new ButtonBuilder()
    .setCustomId(customId)
    .setLabel(label)
    .setStyle(style)
    .setDisabled(disabled);

const dashboardView = async userId => {
  const keys = await registry.listKeys();
  const counts = keys.reduce((result, item) => {
    result[item.status] = (result[item.status] || 0) + 1;
    if (item.binding) result.bound += 1;
    return result;
  }, {active: 0, expired: 0, disabled: 0, bound: 0});

  const embed = new EmbedBuilder()
    .setColor(0x5865f2)
    .setTitle('AetherV2 Key Manager')
    .setDescription('Use the buttons below to manage access without scrolling through command output.')
    .addFields(
      {name: 'Total keys', value: String(keys.length), inline: true},
      {name: 'Active', value: String(counts.active), inline: true},
      {name: 'Inactive', value: String(counts.expired + counts.disabled), inline: true},
      {name: 'Bound accounts', value: String(counts.bound), inline: true}
    )
    .setFooter({text: 'Private owner dashboard'})
    .setTimestamp();

  return {
    embeds: [embed],
    components: [
      new ActionRowBuilder().addComponents(
        button('aether:panel:' + userId + ':generate', 'Generate key', ButtonStyle.Success),
        button('aether:panel:' + userId + ':list', 'View all keys', ButtonStyle.Primary),
        button('aether:panel:' + userId + ':audit', 'Audit log'),
        button('aether:panel:' + userId + ':refresh', 'Refresh')
      )
    ]
  };
};

const sortedKeys = async () => {
  const keys = await registry.listKeys();
  return keys.sort((left, right) =>
    statusRank(left.status) - statusRank(right.status) ||
    String(left.label).localeCompare(String(right.label)) ||
    left.keyId.localeCompare(right.keyId)
  );
};

const keyListView = async (userId, requestedPage = 0) => {
  const keys = await sortedKeys();
  const pageCount = Math.max(1, Math.ceil(keys.length / PAGE_SIZE));
  const page = Math.max(0, Math.min(Number(requestedPage) || 0, pageCount - 1));
  const pageKeys = keys.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);

  const embed = new EmbedBuilder()
    .setColor(0x5865f2)
    .setTitle('AetherV2 Keys')
    .setDescription(keys.length
      ? 'Every registered key is shown below. Select one to manage it.'
      : 'No keys are registered yet.')
    .setFooter({text: 'Page ' + (page + 1) + ' of ' + pageCount})
    .setTimestamp();

  for (const item of pageKeys) {
    const binding = item.binding
      ? item.binding.username + ' (' + item.binding.userId + ')'
      : 'Unbound';
    embed.addFields({
      name: statusIcon(item.status) + ' ' + truncate(item.label || 'Unlabelled', 50),
      value: [
        'ID: ' + item.keyId.slice(0, 16) + '…',
        'Status: ' + statusText(item.status),
        'Username: ' + truncate(binding, 80),
        'Uses: ' + item.uses + ' • Expires: ' + (item.expiresAt ? dateText(item.expiresAt) : 'never')
      ].join('\n'),
      inline: false
    });
  }

  if (!pageKeys.length) {
    embed.addFields({name: 'No keys found', value: 'Use Generate key from the dashboard to create one.'});
  }

  const components = [
    new ActionRowBuilder().addComponents(
      button('aether:list:' + userId + ':' + page + ':prev', 'Previous', ButtonStyle.Secondary, page === 0),
      button('aether:list:' + userId + ':' + page + ':next', 'Next', ButtonStyle.Secondary, page >= pageCount - 1),
      button('aether:list:' + userId + ':' + page + ':refresh', 'Refresh'),
      button('aether:list:' + userId + ':' + page + ':home', 'Dashboard', ButtonStyle.Primary)
    )
  ];

  if (pageKeys.length) {
    const selector = new StringSelectMenuBuilder()
      .setCustomId('aether:keyselect:' + userId + ':' + page)
      .setPlaceholder('Select a key to manage');
    selector.addOptions(pageKeys.map(item => ({
      label: truncate(item.label || 'Unlabelled', 80),
      description: statusText(item.status) + ' • ' + (item.binding ? item.binding.username : 'Unbound'),
      value: item.keyId.slice(0, 16)
    })));
    components.push(new ActionRowBuilder().addComponents(selector));
  }

  return {embeds: [embed], components};
};

const auditView = async userId => {
  const events = await registry.getAudit(15);
  const embed = new EmbedBuilder()
    .setColor(0x5865f2)
    .setTitle('AetherV2 Audit Log')
    .setDescription(events.length ? 'Most recent key-management events.' : 'No events recorded yet.')
    .setFooter({text: 'Private owner dashboard'})
    .setTimestamp();

  if (events.length) {
    embed.addFields({
      name: 'Recent events',
      value: events.map(event => [
        dateText(event.at),
        event.action,
        event.keyId ? event.keyId.slice(0, 16) + '…' : '',
        event.username || event.transferredUsername || ''
      ].filter(Boolean).join(' • ')).join('\n').slice(0, 1024)
    });
  }

  return {
    embeds: [embed],
    components: [
      new ActionRowBuilder().addComponents(
        button('aether:audit:' + userId + ':home', 'Dashboard', ButtonStyle.Primary),
        button('aether:audit:' + userId + ':refresh', 'Refresh')
      )
    ]
  };
};

const keyDetailView = async (userId, keyPrefix, page = 0) => {
  const info = await registry.getKeyInfo(keyPrefix);
  const embed = new EmbedBuilder()
    .setColor(info.status === 'active' ? 0x57f287 : 0xed4245)
    .setTitle(statusIcon(info.status) + ' Key details')
    .addFields(
      {name: 'Key ID', value: info.keyId, inline: false},
      {name: 'Label', value: info.label || 'Unlabelled', inline: true},
      {name: 'Status', value: statusText(info.status), inline: true},
      {name: 'Source', value: info.source, inline: true},
      {name: 'Roblox account', value: bindingText(info.binding), inline: false},
      {name: 'Uses', value: String(info.uses), inline: true},
      {name: 'Created', value: dateText(info.createdAt), inline: true},
      {name: 'Expires', value: dateText(info.expiresAt), inline: true}
    )
    .setFooter({text: 'Use the buttons below to manage this key'})
    .setTimestamp();

  return {
    embeds: [embed],
    components: [
      new ActionRowBuilder().addComponents(
        button('aether:detail:' + userId + ':' + keyPrefix + ':back:' + page, 'Back to list', ButtonStyle.Primary),
        button('aether:detail:' + userId + ':' + keyPrefix + ':edit:' + page, 'Edit'),
        button('aether:detail:' + userId + ':' + keyPrefix + ':unlink:' + page, 'Unlink', ButtonStyle.Secondary, !info.binding),
        button('aether:detail:' + userId + ':' + keyPrefix + ':toggle:' + page,
          info.status === 'active' ? 'Disable' : 'Enable',
          info.status === 'active' ? ButtonStyle.Danger : ButtonStyle.Success),
        button('aether:detail:' + userId + ':' + keyPrefix + ':rotate:' + page, 'Rotate', ButtonStyle.Danger)
      )
    ]
  };
};

const generatedText = (result, title = 'Generated key') => {
  const loader = 'loadstring(game:HttpGet("' + SOURCE_ORIGIN + '/loader?key=' + result.key + '", true))()';
  return [
    title + '.',
    'Key ID: ' + result.keyId,
    'Label: ' + result.record.label,
    'Expires: ' + dateText(result.record.expiresAt),
    '',
    'Raw key — copy it now. It will not be stored or shown again:',
    CODE_FENCE + result.key + CODE_FENCE,
    '',
    'Loader:',
    CODE_FENCE + 'lua\n' + loader + '\n' + CODE_FENCE
  ].join('\n');
};


const keyIdFrom = interaction =>
  interaction.options.getString('key_id', false);

const createKeyModal = userId => {
  const label = new TextInputBuilder()
    .setCustomId('label')
    .setLabel('Label')
    .setPlaceholder('Example: Tester 1')
    .setStyle(TextInputStyle.Short)
    .setRequired(false)
    .setMaxLength(80);
  const expiry = new TextInputBuilder()
    .setCustomId('expires_at')
    .setLabel('Expiry')
    .setPlaceholder('ISO date/time, or none')
    .setStyle(TextInputStyle.Short)
    .setRequired(false)
    .setMaxLength(64);

  return new ModalBuilder()
    .setCustomId('aether:modal:generate:' + userId)
    .setTitle('Generate AetherV2 key')
    .addComponents(
      new ActionRowBuilder().addComponents(label),
      new ActionRowBuilder().addComponents(expiry)
    );
};

const editKeyModal = (userId, keyPrefix) => {
  const label = new TextInputBuilder()
    .setCustomId('label')
    .setLabel('Label')
    .setPlaceholder('Leave blank to keep, or type none to clear')
    .setStyle(TextInputStyle.Short)
    .setRequired(false)
    .setMaxLength(80);
  const expiry = new TextInputBuilder()
    .setCustomId('expires_at')
    .setLabel('Expiry')
    .setPlaceholder('Leave blank to keep, or type none to clear')
    .setStyle(TextInputStyle.Short)
    .setRequired(false)
    .setMaxLength(64);

  return new ModalBuilder()
    .setCustomId('aether:modal:edit:' + userId + ':' + keyPrefix)
    .setTitle('Edit AetherV2 key')
    .addComponents(
      new ActionRowBuilder().addComponents(label),
      new ActionRowBuilder().addComponents(expiry)
    );
};

const handleKeyCommand = async interaction => {
  const subcommand = interaction.options.getSubcommand();
  const actor = actorName(interaction);

  if (subcommand === 'panel') return respond(interaction, await dashboardView(interaction.user.id));
  if (subcommand === 'list') return respond(interaction, await keyListView(interaction.user.id, 0));

  if (subcommand === 'generate') {
    const result = await registry.createKey({
      label: interaction.options.getString('label', false) || undefined,
      expiresAt: interaction.options.getString('expires_at', false) || undefined,
      actor
    });
    return reply(interaction, generatedText(result));
  }

  if (subcommand === 'info') {
    const info = await registry.getKeyInfo(keyIdFrom(interaction));
    return reply(interaction, [
      'Key ID: ' + info.keyId,
      'Label: ' + info.label,
      'Source: ' + info.source,
      'Status: ' + statusText(info.status),
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
    return reply(interaction, generatedText({
      ...result,
      record: result.record
    }, 'Rotated key ' + result.oldKeyId + '. The old key is disabled'));
  }

  if (subcommand === 'audit') {
    const events = await registry.getAudit(interaction.options.getInteger('limit', false) || 20);
    if (events.length === 0) return reply(interaction, 'No key-management events recorded.');
    const lines = events.map(event => [
      dateText(event.at),
      event.action,
      event.keyId ? event.keyId.slice(0, 16) + '…' : '',
      event.username ? event.username : ''
    ].filter(Boolean).join(' | '));
    return reply(interaction, CODE_FENCE + lines.join('\n') + CODE_FENCE);
  }

  return reply(interaction, 'Unknown key command.');
};

const handlePanelButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const action = parts[3];

  if (action === 'generate') return interaction.showModal(createKeyModal(ownerId));
  if (action === 'list') return updateComponent(interaction, keyListView(ownerId, 0));
  if (action === 'audit') return updateComponent(interaction, auditView(ownerId));
  if (action === 'refresh') return updateComponent(interaction, dashboardView(ownerId));
  return updateComponent(interaction, dashboardView(ownerId));
};

const handleListButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const page = Number(parts[3]) || 0;
  const action = parts[4];

  if (action === 'home') return updateComponent(interaction, dashboardView(ownerId));
  if (action === 'prev') return updateComponent(interaction, keyListView(ownerId, page - 1));
  if (action === 'next') return updateComponent(interaction, keyListView(ownerId, page + 1));
  return updateComponent(interaction, keyListView(ownerId, page));
};

const handleAuditButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  return updateComponent(interaction, parts[3] === 'home'
    ? dashboardView(ownerId)
    : auditView(ownerId));
};

const handleKeySelect = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const page = Number(parts[3]) || 0;
  return updateComponent(interaction, keyDetailView(ownerId, interaction.values[0], page));
};

const handleDetailButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const keyPrefix = parts[3];
  const action = parts[4];
  const page = Number(parts[5]) || 0;
  const actor = actorName(interaction);

  if (action === 'back') return updateComponent(interaction, keyListView(ownerId, page));
  if (action === 'edit') return interaction.showModal(editKeyModal(ownerId, keyPrefix));

  if (action === 'rotate') {
    await interaction.deferReply({ephemeral: true});
    const result = await registry.rotateKey({id: keyPrefix, actor});
    return reply(interaction, generatedText(result, 'Rotated key ' + result.oldKeyId + '. The old key is disabled'));
  }

  await interaction.deferUpdate();
  if (action === 'unlink') {
    await registry.unlinkKey({id: keyPrefix, actor});
  } else if (action === 'toggle') {
    const info = await registry.getKeyInfo(keyPrefix);
    if (info.status === 'active') await registry.revokeKey({id: keyPrefix, actor});
    else await registry.enableKey({id: keyPrefix, actor});
  }
  return interaction.editReply({
    ...(await keyDetailView(ownerId, keyPrefix, page)),
    allowedMentions: {parse: []}
  });
};

const handleModalSubmit = async interaction => {
  const parts = interaction.customId.split(':');
  const kind = parts[2];
  const ownerId = parts[3];
  const actor = actorName(interaction);

  await interaction.deferReply({ephemeral: true});

  if (kind === 'generate') {
    const result = await registry.createKey({
      label: interaction.fields.getTextInputValue('label').trim() || undefined,
      expiresAt: interaction.fields.getTextInputValue('expires_at').trim() || undefined,
      actor
    });
    return reply(interaction, generatedText(result));
  }

  if (kind === 'edit') {
    const keyPrefix = parts[4];
    const label = interaction.fields.getTextInputValue('label').trim();
    const expiresAt = interaction.fields.getTextInputValue('expires_at').trim();
    const result = await registry.editKey({
      id: keyPrefix,
      label: label.toLowerCase() === 'none' ? '' : (label || undefined),
      expiresAt: expiresAt.toLowerCase() === 'none' ? '' : (expiresAt || undefined),
      actor
    });
    return reply(interaction, [
      'Updated key ' + result.keyId + '.',
      'Label: ' + (result.record.label || 'none'),
      'Expires: ' + dateText(result.record.expiresAt),
      'Binding: ' + bindingText(result.binding)
    ].join('\n'));
  }

  return reply(interaction, 'Unknown modal.');
};

const customOwnerId = customId => {
  const parts = customId.split(':');
  return parts[1] === 'modal' ? parts[3] : parts[2];
};

const handleInteraction = async interaction => {
  if (interaction.isChatInputCommand()) {
    if (interaction.commandName !== 'key') return;
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
    return;
  }

  if (!interaction.isButton() && !interaction.isStringSelectMenu() && !interaction.isModalSubmit()) return;
  if (!OWNER_IDS.has(interaction.user.id)) {
    return reply(interaction, 'You are not authorized to use this dashboard.');
  }
  if (customOwnerId(interaction.customId) !== interaction.user.id) {
    return reply(interaction, 'This dashboard belongs to another owner.');
  }

  try {
    if (interaction.isButton()) {
      const type = interaction.customId.split(':')[1];
      if (type === 'panel') return await handlePanelButton(interaction);
      if (type === 'list') return await handleListButton(interaction);
      if (type === 'audit') return await handleAuditButton(interaction);
      if (type === 'detail') return await handleDetailButton(interaction);
    }
    if (interaction.isStringSelectMenu()) return await handleKeySelect(interaction);
    if (interaction.isModalSubmit()) return await handleModalSubmit(interaction);
  } catch (error) {
    console.error('[AetherV2] Discord dashboard action failed:', error.message || error);
    return reply(interaction, 'Error: ' + (error.message || 'Dashboard action failed'));
  }
};

const registerCommands = async () => {
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
      await registerCommands();
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
