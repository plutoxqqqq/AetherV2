'use strict';

const crypto = require('node:crypto');
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

const OWNER_IDS = new Set((process.env.DISCORD_OWNER_IDS || '').split(',').map(value => value.trim()).filter(Boolean));
const APPLICATION_ID = process.env.DISCORD_APPLICATION_ID || '';
const GUILD_ID = process.env.DISCORD_GUILD_ID || '';
const SOURCE_ORIGIN = String(process.env.PUBLIC_ORIGIN || '').replace(/\/+$/, '');
const PAGE_SIZE = 6;
const AUDIT_PAGE_SIZE = 8;
const MESSAGE_LIMIT = 2000;
const EMBED_DESCRIPTION_LIMIT = 4096;
const VIEW_TTL = 30 * 60 * 1000;
const viewStates = new Map();

const optionString = (name, description) => option => option.setName(name).setDescription(description).setRequired(false);
const statusOption = option => option
  .setName('status')
  .setDescription('Filter by lifecycle status')
  .setRequired(false)
  .addChoices(
    {name: 'All', value: 'all'},
    {name: 'Active', value: 'active'},
    {name: 'Expired', value: 'expired'},
    {name: 'Revoked', value: 'disabled'}
  );

const commands = [
  new SlashCommandBuilder()
    .setName('key')
    .setDescription('Manage AetherV2 access keys')
    .setDMPermission(false)
    .addSubcommand(sub => sub.setName('panel').setDescription('Open the private key dashboard'))
    .addSubcommand(sub => sub
      .setName('generate')
      .setDescription('Generate a new unbound key')
      .addStringOption(optionString('label', 'Optional label for this key'))
      .addStringOption(optionString('expires_at', 'Future ISO date/time, or omit for no expiry')))
    .addSubcommand(sub => sub
      .setName('list')
      .setDescription('Browse and filter all keys')
      .addStringOption(statusOption)
      .addStringOption(optionString('username', 'Filter by Roblox username'))
      .addStringOption(optionString('label', 'Filter by key label'))
      .addStringOption(optionString('source', 'Filter by source, such as discord')))
    .addSubcommand(sub => sub
      .setName('info')
      .setDescription('Show one key by full ID or unique prefix')
      .addStringOption(option => option.setName('key_id').setDescription('Key ID or unique prefix').setRequired(true)))
    .addSubcommand(sub => sub
      .setName('edit')
      .setDescription('Edit a key label or expiry')
      .addStringOption(option => option.setName('key_id').setDescription('Key ID or unique prefix').setRequired(true))
      .addStringOption(optionString('label', 'New label, or none to clear it'))
      .addStringOption(optionString('expires_at', 'New ISO date/time, or none')))
    .addSubcommand(sub => sub
      .setName('renew')
      .setDescription('Set a future expiry and reactivate a key')
      .addStringOption(option => option.setName('key_id').setDescription('Key ID or unique prefix').setRequired(true))
      .addStringOption(option => option.setName('expires_at').setDescription('Future ISO date/time').setRequired(true)))
    .addSubcommand(sub => sub
      .setName('unlink')
      .setDescription('Unlink a Roblox account after confirmation')
      .addStringOption(optionString('key_id', 'Key ID or unique prefix'))
      .addStringOption(optionString('username', 'Roblox username to unlink'))
      .addStringOption(optionString('user_id', 'Roblox UserId to disambiguate')))
    .addSubcommand(sub => sub
      .setName('revoke')
      .setDescription('Revoke a key after confirmation')
      .addStringOption(option => option.setName('key_id').setDescription('Key ID or unique prefix').setRequired(true)))
    .addSubcommand(sub => sub
      .setName('enable')
      .setDescription('Enable a non-expired revoked key')
      .addStringOption(option => option.setName('key_id').setDescription('Key ID or unique prefix').setRequired(true)))
    .addSubcommand(sub => sub
      .setName('rotate')
      .setDescription('Revoke a key and generate a replacement after confirmation')
      .addStringOption(option => option.setName('key_id').setDescription('Key ID or unique prefix').setRequired(true)))
    .addSubcommand(sub => sub
      .setName('audit')
      .setDescription('Browse recent key-management events')
      .addIntegerOption(option => option.setName('limit').setDescription('Events to load').setMinValue(1).setMaxValue(100).setRequired(false)))
].map(command => command.toJSON());

const truncate = (value, length) => {
  const string = String(value ?? '');
  return string.length <= length ? string : string.slice(0, Math.max(0, length - 1)) + '…';
};
const inline = value => '`' + String(value ?? '').replace(/`/g, 'ˋ') + '`';
const codeBlock = (value, language = 'text') => '```' + language + '\n' + String(value ?? '').replace(/```/g, 'ˋˋˋ') + '\n```';
const actorName = interaction => interaction.user.username + ' (' + interaction.user.id + ')';
const isOwnerId = value => OWNER_IDS.has(String(value));
const dateText = value => {
  if (!value) return 'never';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? truncate(value, 80) : date.toISOString();
};
const bindingText = binding => binding ? binding.username + ' (' + binding.userId + ')' : 'unbound';
const statusText = status => ({active: 'Active', disabled: 'Revoked', expired: 'Expired'}[status] || 'Unknown');
const statusIcon = status => ({active: '🟢', disabled: '🔴', expired: '🟠'}[status] || '⚪');
const statusRank = status => ({active: 0, expired: 1, disabled: 2}[status] ?? 3);
const safePayload = payload => {
  const value = {...payload, allowedMentions: {parse: []}};
  if (typeof value.content === 'string' && value.content.length > MESSAGE_LIMIT) {
    value.content = truncate(value.content, MESSAGE_LIMIT);
  }
  return value;
};

const respond = async (interaction, payload) => {
  const value = safePayload(payload);
  if (interaction.deferred || interaction.replied) return interaction.editReply(value);
  return interaction.reply({...value, ephemeral: true});
};
const reply = (interaction, content) => respond(interaction, {content});
const updateComponent = async (interaction, payloadPromise) => {
  if (!interaction.deferred && !interaction.replied) await interaction.deferUpdate();
  return interaction.editReply(safePayload(await payloadPromise));
};
const button = (customId, label, style = ButtonStyle.Secondary, disabled = false) => new ButtonBuilder()
  .setCustomId(customId).setLabel(label).setStyle(style).setDisabled(disabled);

const cleanViews = () => {
  const now = Date.now();
  for (const [id, view] of viewStates) if (view.expiresAt <= now) viewStates.delete(id);
};
const createView = (ownerId, filters = {}) => {
  cleanViews();
  const id = crypto.randomBytes(5).toString('hex');
  viewStates.set(id, {ownerId: String(ownerId), filters, expiresAt: Date.now() + VIEW_TTL});
  return id;
};
const readView = (id, ownerId) => {
  cleanViews();
  const view = viewStates.get(id);
  if (!view || view.ownerId !== String(ownerId)) throw Object.assign(new Error('This filtered view expired; run /key list again'), {status: 410});
  view.expiresAt = Date.now() + VIEW_TTL;
  return view;
};

const normalizeFilters = filters => ({
  status: ['all', 'active', 'expired', 'disabled'].includes(String(filters.status || '').toLowerCase()) ? String(filters.status).toLowerCase() : 'all',
  username: truncate(String(filters.username || '').trim(), 20),
  label: truncate(String(filters.label || '').trim(), 80),
  source: truncate(String(filters.source || '').trim(), 40)
});
const filterText = filters => {
  const values = [];
  if (filters.status && filters.status !== 'all') values.push('status ' + inline(statusText(filters.status)));
  if (filters.username) values.push('username ' + inline(filters.username));
  if (filters.label) values.push('label ' + inline(filters.label));
  if (filters.source) values.push('source ' + inline(filters.source));
  return values.length ? 'Filters: ' + values.join(' • ') : 'No filters applied.';
};

const dashboardView = async userId => {
  const keys = await registry.listKeys();
  const counts = keys.reduce((result, item) => {
    result[item.status] = (result[item.status] || 0) + 1;
    if (item.binding) result.bound += 1;
    return result;
  }, {active: 0, expired: 0, disabled: 0, bound: 0});
  const embed = new EmbedBuilder()
    .setColor(0x5865f2)
    .setTitle('🔐 AetherV2 Key Manager')
    .setDescription('Owner-only access control. Raw keys are never stored and can only be shown once.')
    .addFields(
      {name: 'All keys', value: inline(keys.length), inline: true},
      {name: 'Active', value: inline(counts.active), inline: true},
      {name: 'Inactive', value: inline(counts.expired + counts.disabled), inline: true},
      {name: 'Bound accounts', value: inline(counts.bound), inline: true}
    )
    .setFooter({text: 'Private owner dashboard • refreshed'})
    .setTimestamp();
  return {
    embeds: [embed],
    components: [new ActionRowBuilder().addComponents(
      button('aether:panel:' + userId + ':generate', 'Generate', ButtonStyle.Success),
      button('aether:panel:' + userId + ':list', 'View keys', ButtonStyle.Primary),
      button('aether:panel:' + userId + ':audit', 'Audit log'),
      button('aether:panel:' + userId + ':refresh', 'Refresh')
    )]
  };
};

const keyListView = async (userId, requestedPage = 0, viewId, initialFilters = {}) => {
  const id = viewId || createView(userId, normalizeFilters(initialFilters));
  const filters = readView(id, userId).filters;
  const keys = (await registry.listKeys(filters)).sort((left, right) =>
    statusRank(left.status) - statusRank(right.status) || String(left.label).localeCompare(String(right.label)) || left.keyId.localeCompare(right.keyId)
  );
  const pageCount = Math.max(1, Math.ceil(keys.length / PAGE_SIZE));
  const page = Math.max(0, Math.min(Number(requestedPage) || 0, pageCount - 1));
  const pageKeys = keys.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);
  const embed = new EmbedBuilder()
    .setColor(0x5865f2)
    .setTitle('🔑 AetherV2 Keys')
    .setDescription(filterText(filters) + '\n' + (keys.length ? 'Select a key below to manage it.' : 'No keys match these filters.'))
    .setFooter({text: 'Page ' + (page + 1) + ' of ' + pageCount + ' • ' + keys.length + ' result' + (keys.length === 1 ? '' : 's')})
    .setTimestamp();
  for (const item of pageKeys) {
    embed.addFields({
      name: statusIcon(item.status) + ' ' + truncate(item.label || 'Unlabelled', 60),
      value: [
        'ID ' + inline(item.keyId.slice(0, 16) + '…') + '  •  ' + inline(statusText(item.status)),
        'User ' + inline(item.binding ? item.binding.username : 'unbound') + '  •  uses ' + inline(item.uses),
        'Expires ' + inline(dateText(item.expiresAt)) + '  •  source ' + inline(item.source)
      ].join('\n')
    });
  }
  const components = [new ActionRowBuilder().addComponents(
    button('aether:list:' + userId + ':' + id + ':' + page + ':prev', 'Previous', ButtonStyle.Secondary, page === 0),
    button('aether:list:' + userId + ':' + id + ':' + page + ':next', 'Next', ButtonStyle.Secondary, page >= pageCount - 1),
    button('aether:list:' + userId + ':' + id + ':' + page + ':refresh', 'Refresh'),
    button('aether:list:' + userId + ':' + id + ':' + page + ':home', 'Dashboard', ButtonStyle.Primary)
  )];
  if (pageKeys.length) {
    const selector = new StringSelectMenuBuilder()
      .setCustomId('aether:keyselect:' + userId + ':' + id + ':' + page)
      .setPlaceholder('Select a key to manage')
      .addOptions(pageKeys.map(item => ({
        label: truncate(item.label || 'Unlabelled', 80),
        description: truncate(statusText(item.status) + ' • ' + (item.binding ? item.binding.username : 'Unbound') + ' • ' + item.source, 100),
        value: item.keyId.slice(0, 16)
      })));
    components.push(new ActionRowBuilder().addComponents(selector));
  }
  return {embeds: [embed], components};
};

const auditDetail = event => {
  const extras = [];
  if (event.username) extras.push('user ' + inline(event.username));
  if (event.userId) extras.push('UserId ' + inline(event.userId));
  if (event.label) extras.push('label ' + inline(event.label));
  if (event.transferredUsername) extras.push('transferred ' + inline(event.transferredUsername));
  if (event.replacementKeyId) extras.push('replacement ' + inline(event.replacementKeyId.slice(0, 16) + '…'));
  if (event.expiresAt) extras.push('until ' + inline(dateText(event.expiresAt)));
  if (event.uses !== undefined) extras.push('uses ' + inline(event.uses));
  if (event.changes) {
    const changes = Object.entries(event.changes).map(([name, value]) =>
      name + '=' + (name === 'expiresAt' ? dateText(value) : String(value))
    ).join(', ');
    if (changes) extras.push('changed ' + inline(truncate(changes, 120)));
  }
  return truncate([
    '**' + String(event.action || 'unknown').toUpperCase() + '** • ' + inline(dateText(event.at)),
    (event.keyId ? 'key ' + inline(event.keyId.slice(0, 16) + '…') + ' • ' : '') + 'actor ' + inline(truncate(event.actor || 'unknown', 70)),
    extras.join(' • ')
  ].filter(Boolean).join('\n'), 430);
};

const auditView = async (userId, requestedPage = 0, requestedLimit = 40) => {
  const limit = Math.max(1, Math.min(100, Number(requestedLimit) || 40));
  const events = await registry.getAudit(limit);
  const pageCount = Math.max(1, Math.ceil(events.length / AUDIT_PAGE_SIZE));
  const page = Math.max(0, Math.min(Number(requestedPage) || 0, pageCount - 1));
  const description = events.length
    ? truncate(events.slice(page * AUDIT_PAGE_SIZE, (page + 1) * AUDIT_PAGE_SIZE).map(auditDetail).join('\n\n'), EMBED_DESCRIPTION_LIMIT)
    : 'No key-management events have been recorded.';
  const embed = new EmbedBuilder()
    .setColor(0x5865f2)
    .setTitle('📜 AetherV2 Audit Log')
    .setDescription(description)
    .setFooter({text: 'Page ' + (page + 1) + ' of ' + pageCount + ' • newest first'})
    .setTimestamp();
  return {
    embeds: [embed],
    components: [new ActionRowBuilder().addComponents(
      button('aether:audit:' + userId + ':' + page + ':' + limit + ':prev', 'Previous', ButtonStyle.Secondary, page === 0),
      button('aether:audit:' + userId + ':' + page + ':' + limit + ':next', 'Next', ButtonStyle.Secondary, page >= pageCount - 1),
      button('aether:audit:' + userId + ':' + page + ':' + limit + ':refresh', 'Refresh'),
      button('aether:audit:' + userId + ':' + page + ':' + limit + ':home', 'Dashboard', ButtonStyle.Primary)
    )]
  };
};

const keyDetailView = async (userId, keyPrefix, viewId, page = 0) => {
  const info = await registry.getKeyInfo(keyPrefix);
  const id = viewId || createView(userId, normalizeFilters({}));
  const embed = new EmbedBuilder()
    .setColor(info.status === 'active' ? 0x57f287 : info.status === 'expired' ? 0xfee75c : 0xed4245)
    .setTitle(statusIcon(info.status) + ' Key details')
    .addFields(
      {name: 'Key ID', value: codeBlock(info.keyId), inline: false},
      {name: 'Label', value: inline(info.label || 'Unlabelled'), inline: true},
      {name: 'Status', value: inline(statusText(info.status)), inline: true},
      {name: 'Source', value: inline(info.source), inline: true},
      {name: 'Roblox account', value: inline(bindingText(info.binding)), inline: false},
      {name: 'Uses', value: inline(info.uses), inline: true},
      {name: 'Created', value: inline(dateText(info.createdAt)), inline: true},
      {name: 'Expires', value: inline(dateText(info.expiresAt)), inline: true}
    )
    .setFooter({text: 'Raw keys cannot be viewed or recovered'})
    .setTimestamp();
  const stateAction = info.status === 'active' ? 'revoke' : info.status === 'expired' ? 'renew' : 'enable';
  const stateLabel = info.status === 'active' ? 'Revoke' : info.status === 'expired' ? 'Renew' : 'Enable';
  const stateStyle = info.status === 'active' ? ButtonStyle.Danger : ButtonStyle.Success;
  const base = 'aether:detail:' + userId + ':' + info.keyId.slice(0, 16) + ':' + id + ':' + page + ':';
  return {
    embeds: [embed],
    components: [new ActionRowBuilder().addComponents(
      button(base + 'back', 'Back', ButtonStyle.Primary),
      button(base + 'edit', 'Edit'),
      button(base + 'unlink', 'Unlink', ButtonStyle.Secondary, !info.binding),
      button(base + stateAction, stateLabel, stateStyle),
      button(base + 'rotate', 'Rotate', ButtonStyle.Danger)
    )]
  };
};

const generatedText = (result, title = 'Generated key') => {
  if (!SOURCE_ORIGIN) throw new Error('PUBLIC_ORIGIN is required before generating loaders');
  const loader = 'loadstring(game:HttpGet("' + SOURCE_ORIGIN + '/loader?key=' + result.key + '", true))()';
  const content = [
    '✅ **' + title + '**',
    '',
    'Key ID', codeBlock(result.keyId),
    'Label ' + inline(result.record.label || 'Unlabelled') + '  •  expires ' + inline(dateText(result.record.expiresAt)),
    '',
    '⚠️ **Copy the raw key now. It is not stored and cannot be shown again.**',
    codeBlock(result.key),
    '',
    'Loader', codeBlock(loader, 'lua')
  ].join('\n');
  if (content.length > MESSAGE_LIMIT) throw new Error('Generated loader exceeds Discord message limits');
  return content;
};

const keyIdFrom = interaction => interaction.options.getString('key_id', false);
const createKeyModal = userId => new ModalBuilder()
  .setCustomId('aether:modal:generate:' + userId)
  .setTitle('Generate AetherV2 key')
  .addComponents(
    new ActionRowBuilder().addComponents(new TextInputBuilder().setCustomId('label').setLabel('Label').setPlaceholder('Example: Tester 1').setStyle(TextInputStyle.Short).setRequired(false).setMaxLength(80)),
    new ActionRowBuilder().addComponents(new TextInputBuilder().setCustomId('expires_at').setLabel('Future expiry (optional)').setPlaceholder('ISO date/time').setStyle(TextInputStyle.Short).setRequired(false).setMaxLength(64))
  );
const editKeyModal = (userId, keyPrefix) => new ModalBuilder()
  .setCustomId('aether:modal:edit:' + userId + ':' + keyPrefix)
  .setTitle('Edit AetherV2 key')
  .addComponents(
    new ActionRowBuilder().addComponents(new TextInputBuilder().setCustomId('label').setLabel('Label').setPlaceholder('Blank keeps it; none clears it').setStyle(TextInputStyle.Short).setRequired(false).setMaxLength(80)),
    new ActionRowBuilder().addComponents(new TextInputBuilder().setCustomId('expires_at').setLabel('Expiry').setPlaceholder('Blank keeps it; none clears it').setStyle(TextInputStyle.Short).setRequired(false).setMaxLength(64))
  );
const renewKeyModal = (userId, keyPrefix) => new ModalBuilder()
  .setCustomId('aether:modal:renew:' + userId + ':' + keyPrefix)
  .setTitle('Renew AetherV2 key')
  .addComponents(new ActionRowBuilder().addComponents(
    new TextInputBuilder().setCustomId('expires_at').setLabel('New future expiry').setPlaceholder('ISO date/time').setStyle(TextInputStyle.Short).setRequired(true).setMaxLength(64)
  ));

const confirmationView = async (userId, action, keyPrefix, viewId, page = 0) => {
  const info = await registry.getKeyInfo(keyPrefix);
  const verbs = {
    revoke: ['Revoke this key?', 'Existing loader sessions will stop working immediately.'],
    unlink: ['Unlink this account?', 'The next verified Roblox account will be able to claim this key.'],
    rotate: ['Rotate this key?', 'The old key and all of its sessions will be revoked. A replacement raw key will be shown once.']
  };
  if (!verbs[action]) throw new Error('Unknown confirmation action');
  const base = 'aether:confirm:' + userId + ':' + action + ':' + info.keyId.slice(0, 16) + ':' + viewId + ':' + page + ':';
  return {
    embeds: [new EmbedBuilder()
      .setColor(0xed4245)
      .setTitle('⚠️ ' + verbs[action][0])
      .setDescription(verbs[action][1])
      .addFields(
        {name: 'Key ID', value: codeBlock(info.keyId)},
        {name: 'Label', value: inline(info.label), inline: true},
        {name: 'Account', value: inline(bindingText(info.binding)), inline: true}
      )],
    components: [new ActionRowBuilder().addComponents(
      button(base + 'yes', 'Confirm ' + action, ButtonStyle.Danger),
      button(base + 'cancel', 'Cancel', ButtonStyle.Secondary)
    )]
  };
};

const commandFilters = interaction => normalizeFilters({
  status: interaction.options.getString('status', false) || 'all',
  username: interaction.options.getString('username', false) || '',
  label: interaction.options.getString('label', false) || '',
  source: interaction.options.getString('source', false) || ''
});

const handleKeyCommand = async interaction => {
  const subcommand = interaction.options.getSubcommand();
  const actor = actorName(interaction);
  if (subcommand === 'panel') return respond(interaction, await dashboardView(interaction.user.id));
  if (subcommand === 'list') return respond(interaction, await keyListView(interaction.user.id, 0, null, commandFilters(interaction)));
  if (subcommand === 'generate') {
    const result = await registry.createKey({
      label: interaction.options.getString('label', false) || undefined,
      expiresAt: interaction.options.getString('expires_at', false) || undefined,
      actor
    });
    return reply(interaction, generatedText(result));
  }
  if (subcommand === 'info') return respond(interaction, await keyDetailView(interaction.user.id, keyIdFrom(interaction)));
  if (subcommand === 'edit') {
    const result = await registry.editKey({
      id: keyIdFrom(interaction),
      label: interaction.options.getString('label', false) ?? undefined,
      expiresAt: interaction.options.getString('expires_at', false) ?? undefined,
      actor
    });
    return reply(interaction, '✅ Updated key ' + inline(result.keyId) + '.\nLabel ' + inline(result.record.label || 'none') + ' • expires ' + inline(dateText(result.record.expiresAt)) + '.');
  }
  if (subcommand === 'renew') {
    const result = await registry.renewKey({id: keyIdFrom(interaction), expiresAt: interaction.options.getString('expires_at'), actor});
    return reply(interaction, '✅ Renewed and enabled ' + inline(result.keyId) + ' until ' + inline(dateText(result.record.expiresAt)) + '.');
  }
  if (subcommand === 'unlink') {
    const id = interaction.options.getString('key_id', false) || undefined;
    const username = interaction.options.getString('username', false) || undefined;
    const userId = interaction.options.getString('user_id', false) || undefined;
    if (Boolean(id) === Boolean(username)) return reply(interaction, 'Provide exactly one of `key_id` or `username`.');
    const selected = id ? await registry.getKeyInfo(id) : await registry.findBoundKey({username, userId});
    const viewId = createView(interaction.user.id, normalizeFilters({}));
    return respond(interaction, await confirmationView(interaction.user.id, 'unlink', selected.keyId, viewId, 0));
  }
  if (subcommand === 'revoke' || subcommand === 'rotate') {
    const viewId = createView(interaction.user.id, normalizeFilters({}));
    return respond(interaction, await confirmationView(interaction.user.id, subcommand, keyIdFrom(interaction), viewId, 0));
  }
  if (subcommand === 'enable') {
    const result = await registry.enableKey({id: keyIdFrom(interaction), actor});
    return reply(interaction, '✅ Enabled ' + inline(result.keyId) + '.');
  }
  if (subcommand === 'audit') return respond(interaction, await auditView(interaction.user.id, 0, interaction.options.getInteger('limit', false) || 40));
  return reply(interaction, 'Unknown key command.');
};

const handlePanelButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const action = parts[3];
  if (action === 'generate') return interaction.showModal(createKeyModal(ownerId));
  if (action === 'list') return updateComponent(interaction, keyListView(ownerId, 0));
  if (action === 'audit') return updateComponent(interaction, auditView(ownerId));
  return updateComponent(interaction, dashboardView(ownerId));
};

const handleListButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const viewId = parts[3];
  const page = Number(parts[4]) || 0;
  const action = parts[5];
  if (action === 'home') return updateComponent(interaction, dashboardView(ownerId));
  if (action === 'prev') return updateComponent(interaction, keyListView(ownerId, page - 1, viewId));
  if (action === 'next') return updateComponent(interaction, keyListView(ownerId, page + 1, viewId));
  return updateComponent(interaction, keyListView(ownerId, page, viewId));
};

const handleAuditButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const page = Number(parts[3]) || 0;
  const limit = Number(parts[4]) || 40;
  const action = parts[5];
  if (action === 'home') return updateComponent(interaction, dashboardView(ownerId));
  return updateComponent(interaction, auditView(ownerId, action === 'prev' ? page - 1 : action === 'next' ? page + 1 : page, limit));
};

const handleKeySelect = async interaction => {
  const parts = interaction.customId.split(':');
  return updateComponent(interaction, keyDetailView(parts[2], interaction.values[0], parts[3], Number(parts[4]) || 0));
};

const handleDetailButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const keyPrefix = parts[3];
  const viewId = parts[4];
  const page = Number(parts[5]) || 0;
  const action = parts[6];
  const actor = actorName(interaction);
  if (action === 'back') return updateComponent(interaction, keyListView(ownerId, page, viewId));
  if (action === 'edit') return interaction.showModal(editKeyModal(ownerId, keyPrefix));
  if (action === 'renew') return interaction.showModal(renewKeyModal(ownerId, keyPrefix));
  if (['unlink', 'revoke', 'rotate'].includes(action)) return updateComponent(interaction, confirmationView(ownerId, action, keyPrefix, viewId, page));
  if (action === 'enable') {
    await interaction.deferUpdate();
    await registry.enableKey({id: keyPrefix, actor});
    return interaction.editReply(safePayload(await keyDetailView(ownerId, keyPrefix, viewId, page)));
  }
  throw new Error('Unknown key action');
};

const handleConfirmButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const action = parts[3];
  const keyPrefix = parts[4];
  const viewId = parts[5];
  const page = Number(parts[6]) || 0;
  const decision = parts[7];
  if (decision === 'cancel') return updateComponent(interaction, keyDetailView(ownerId, keyPrefix, viewId, page));
  await interaction.deferUpdate();
  const actor = actorName(interaction);
  if (action === 'rotate') {
    const result = await registry.rotateKey({id: keyPrefix, actor});
    return interaction.editReply(safePayload({content: generatedText(result, 'Rotated key ' + result.oldKeyId + '; the old key is revoked'), embeds: [], components: []}));
  }
  if (action === 'revoke') {
    const result = await registry.revokeKey({id: keyPrefix, actor});
    return interaction.editReply(safePayload({content: '✅ Revoked ' + inline(result.keyId) + '. Existing source sessions are now invalid.', embeds: [], components: []}));
  }
  if (action === 'unlink') {
    const result = await registry.unlinkKey({id: keyPrefix, actor});
    return interaction.editReply(safePayload({content: '✅ Unlinked ' + inline(result.binding.username) + ' from ' + inline(result.keyId) + '.', embeds: [], components: []}));
  }
  throw new Error('Unknown confirmation action');
};

const handleModalSubmit = async interaction => {
  const parts = interaction.customId.split(':');
  const kind = parts[2];
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
  const keyPrefix = parts[4];
  if (kind === 'edit') {
    const label = interaction.fields.getTextInputValue('label').trim();
    const expiresAt = interaction.fields.getTextInputValue('expires_at').trim();
    const result = await registry.editKey({
      id: keyPrefix,
      label: label ? label : undefined,
      expiresAt: expiresAt ? expiresAt : undefined,
      actor
    });
    return reply(interaction, '✅ Updated ' + inline(result.keyId) + '.\nLabel ' + inline(result.record.label || 'none') + ' • expires ' + inline(dateText(result.record.expiresAt)) + '.');
  }
  if (kind === 'renew') {
    const result = await registry.renewKey({id: keyPrefix, expiresAt: interaction.fields.getTextInputValue('expires_at').trim(), actor});
    return reply(interaction, '✅ Renewed and enabled ' + inline(result.keyId) + ' until ' + inline(dateText(result.record.expiresAt)) + '.');
  }
  return reply(interaction, 'Unknown modal.');
};

const customOwnerId = customId => {
  const parts = customId.split(':');
  return parts[1] === 'modal' ? parts[3] : parts[2];
};
const friendlyError = error => {
  if (error && error.status === 404) return 'Not found: ' + error.message;
  if (error && error.status === 409) return 'Could not apply that change: ' + error.message;
  if (error && error.status === 410) return error.message;
  if (error && error.status === 429) return 'The service is busy. Please wait a moment and try again.';
  if (error && error.status >= 500) return 'The key registry or an upstream service is temporarily unavailable. No change was confirmed; try again.';
  return error && error.message ? error.message : 'The key operation failed.';
};
const logSafeError = (context, error) => console.error('[AetherV2] ' + context + ':', truncate(error && error.message || error, 300));

const handleInteraction = async interaction => {
  if (interaction.isChatInputCommand()) {
    if (interaction.commandName !== 'key') return;
    if (!isOwnerId(interaction.user.id)) return reply(interaction, 'You are not authorized to manage AetherV2 keys.');
    await interaction.deferReply({ephemeral: true});
    try {
      await handleKeyCommand(interaction);
    } catch (error) {
      logSafeError('Discord key command failed', error);
      await reply(interaction, '❌ ' + friendlyError(error));
    }
    return;
  }
  if (!interaction.isButton() && !interaction.isStringSelectMenu() && !interaction.isModalSubmit()) return;
  if (!isOwnerId(interaction.user.id)) return reply(interaction, 'You are not authorized to use this dashboard.');
  if (customOwnerId(interaction.customId) !== interaction.user.id) return reply(interaction, 'This private dashboard belongs to another owner.');
  try {
    if (interaction.isButton()) {
      const type = interaction.customId.split(':')[1];
      if (type === 'panel') return await handlePanelButton(interaction);
      if (type === 'list') return await handleListButton(interaction);
      if (type === 'audit') return await handleAuditButton(interaction);
      if (type === 'detail') return await handleDetailButton(interaction);
      if (type === 'confirm') return await handleConfirmButton(interaction);
    }
    if (interaction.isStringSelectMenu()) return await handleKeySelect(interaction);
    if (interaction.isModalSubmit()) return await handleModalSubmit(interaction);
  } catch (error) {
    logSafeError('Discord dashboard action failed', error);
    return reply(interaction, '❌ ' + friendlyError(error));
  }
};

const registerCommands = async () => {
  const rest = new REST({version: '10'}).setToken(process.env.DISCORD_TOKEN);
  const route = GUILD_ID ? Routes.applicationGuildCommands(APPLICATION_ID, GUILD_ID) : Routes.applicationCommands(APPLICATION_ID);
  await rest.put(route, {body: commands});
  console.log('[AetherV2] registered Discord key commands' + (GUILD_ID ? ' for guild ' + GUILD_ID : ' globally'));
};

const startDiscordBot = async () => {
  if (!process.env.DISCORD_TOKEN) throw new Error('DISCORD_TOKEN is required');
  if (!APPLICATION_ID) throw new Error('DISCORD_APPLICATION_ID is required');
  if (OWNER_IDS.size === 0) throw new Error('DISCORD_OWNER_IDS is required');
  if (!SOURCE_ORIGIN) throw new Error('PUBLIC_ORIGIN is required');
  const client = new Client({intents: [GatewayIntentBits.Guilds]});
  client.once('ready', async () => {
    try {
      await registerCommands();
      console.log('[AetherV2] Discord bot logged in as ' + client.user.tag);
    } catch (error) {
      logSafeError('Discord command registration failed', error);
    }
  });
  client.on('interactionCreate', interaction => handleInteraction(interaction).catch(error => logSafeError('Discord interaction failed', error)));
  await client.login(process.env.DISCORD_TOKEN);
  return client;
};

module.exports = {
  startDiscordBot,
  commands,
  handleInteraction,
  isOwnerId,
  generatedText,
  auditView,
  keyListView,
  confirmationView,
  friendlyError,
  MESSAGE_LIMIT,
  EMBED_DESCRIPTION_LIMIT
};
