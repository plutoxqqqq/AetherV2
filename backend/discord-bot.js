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
const conflicts = require('./key-conflicts');

const OWNER_IDS = new Set((process.env.DISCORD_OWNER_IDS || '').split(',').map(value => value.trim()).filter(Boolean));
const APPLICATION_ID = process.env.DISCORD_APPLICATION_ID || '';
const GUILD_ID = process.env.DISCORD_GUILD_ID || '';
const PAGE_SIZE = 6;
const AUDIT_PAGE_SIZE = 8;
const CONFLICT_PAGE_SIZE = 5;
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
    .setDescription('Manage AetherV2 Premium keys')
    .setDMPermission(false)
    .addSubcommand(sub => sub.setName('panel').setDescription('Open the private premium-key dashboard'))
    .addSubcommand(sub => sub.setName('conflicts').setDescription('Review keys attempted by multiple Roblox accounts'))
    .addSubcommand(sub => sub
      .setName('generate')
      .setDescription('Generate a new unbound premium key')
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
const copyable = (value, language = 'text') => codeBlock(value, language) + '\n' + inline(value);
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
  if (typeof value.content === 'string' && value.content.length > MESSAGE_LIMIT) value.content = truncate(value.content, MESSAGE_LIMIT);
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
  const [keys, openConflicts] = await Promise.all([registry.listKeys(), conflicts.listConflicts({status: 'open'})]);
  const counts = keys.reduce((result, item) => {
    result[item.status] = (result[item.status] || 0) + 1;
    if (item.binding) result.bound += 1;
    return result;
  }, {active: 0, expired: 0, disabled: 0, bound: 0});
  const embed = new EmbedBuilder()
    .setColor(openConflicts.length ? 0xfee75c : 0x5865f2)
    .setTitle('🔐 AetherV2 Premium Key Manager')
    .setDescription('Owner-only premium access. Normal AetherV2 is public and does not require a key. Raw premium keys are never stored and can only be shown once.')
    .addFields(
      {name: 'All keys', value: inline(keys.length), inline: true},
      {name: 'Active', value: inline(counts.active), inline: true},
      {name: 'Inactive', value: inline(counts.expired + counts.disabled), inline: true},
      {name: 'Bound accounts', value: inline(counts.bound), inline: true},
      {name: 'Open conflicts', value: inline(openConflicts.length), inline: true}
    )
    .setFooter({text: 'Private owner dashboard • refreshed'})
    .setTimestamp();
  return {
    embeds: [embed],
    components: [new ActionRowBuilder().addComponents(
      button('aether:panel:' + userId + ':generate', 'Generate', ButtonStyle.Success),
      button('aether:panel:' + userId + ':list', 'View keys', ButtonStyle.Primary),
      button('aether:panel:' + userId + ':conflicts', 'Conflicts', openConflicts.length ? ButtonStyle.Danger : ButtonStyle.Secondary),
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
    .setTitle('🔑 AetherV2 Premium Keys')
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

const conflictListView = async (userId, requestedPage = 0) => {
  const items = await conflicts.listConflicts({status: 'open'});
  const pageCount = Math.max(1, Math.ceil(items.length / CONFLICT_PAGE_SIZE));
  const page = Math.max(0, Math.min(Number(requestedPage) || 0, pageCount - 1));
  const pageItems = items.slice(page * CONFLICT_PAGE_SIZE, (page + 1) * CONFLICT_PAGE_SIZE);
  const embed = new EmbedBuilder()
    .setColor(items.length ? 0xfee75c : 0x57f287)
    .setTitle('⚠️ Premium key conflicts')
    .setDescription(items.length
      ? 'These attempts were rejected because the key was already bound to a different Roblox identity. Select one to moderate it.'
      : 'No unresolved key conflicts were detected.')
    .setFooter({text: 'Page ' + (page + 1) + ' of ' + pageCount + ' • ' + items.length + ' open conflict' + (items.length === 1 ? '' : 's')})
    .setTimestamp();
  for (const item of pageItems) {
    embed.addFields({
      name: truncate(item.attemptedUsername + ' → ' + item.boundUsername, 100),
      value: [
        'Conflict ' + inline(item.conflictId),
        'Attempted ' + inline(item.attemptedUsername + ' (' + item.attemptedUserId + ')'),
        'Bound to ' + inline(item.boundUsername + ' (' + item.boundUserId + ')'),
        'Key ' + inline(item.keyId.slice(0, 16) + '…') + ' • attempts ' + inline(item.attempts),
        'Last seen ' + inline(dateText(item.lastSeenAt)) + (item.banned ? ' • **user already banned**' : '')
      ].join('\n')
    });
  }
  const components = [new ActionRowBuilder().addComponents(
    button('aether:conflicts:' + userId + ':' + page + ':prev', 'Previous', ButtonStyle.Secondary, page === 0),
    button('aether:conflicts:' + userId + ':' + page + ':next', 'Next', ButtonStyle.Secondary, page >= pageCount - 1),
    button('aether:conflicts:' + userId + ':' + page + ':refresh', 'Refresh'),
    button('aether:conflicts:' + userId + ':' + page + ':home', 'Dashboard', ButtonStyle.Primary)
  )];
  if (pageItems.length) {
    components.push(new ActionRowBuilder().addComponents(new StringSelectMenuBuilder()
      .setCustomId('aether:conflictselect:' + userId + ':' + page)
      .setPlaceholder('Select a conflict to review')
      .addOptions(pageItems.map(item => ({
        label: truncate(item.attemptedUsername + ' using ' + item.boundUsername + "'s key", 100),
        description: truncate(item.attempts + ' rejected attempt' + (item.attempts === 1 ? '' : 's') + ' • ' + item.keyId.slice(0, 12), 100),
        value: item.conflictId
      }))));
  }
  return {embeds: [embed], components};
};

const conflictDetailView = async (userId, conflictId, page = 0) => {
  const item = await conflicts.getConflict(conflictId);
  const embed = new EmbedBuilder()
    .setColor(0xfee75c)
    .setTitle('⚠️ Key conflict details')
    .addFields(
      {name: 'Conflict ID', value: copyable(item.conflictId)},
      {name: 'Attempted account', value: copyable(item.attemptedUsername + ' (' + item.attemptedUserId + ')')},
      {name: 'Legitimate binding', value: copyable(item.boundUsername + ' (' + item.boundUserId + ')')},
      {name: 'Key ID', value: copyable(item.keyId)},
      {name: 'Rejected attempts', value: inline(item.attempts), inline: true},
      {name: 'First seen', value: inline(dateText(item.firstSeenAt)), inline: true},
      {name: 'Last seen', value: inline(dateText(item.lastSeenAt)), inline: true},
      {name: 'Attempting user banned', value: inline(item.banned ? 'yes' : 'no'), inline: true}
    )
    .setFooter({text: 'The attempted authorization was rejected; no premium session was created.'})
    .setTimestamp();
  const base = 'aether:conflictdetail:' + userId + ':' + item.conflictId + ':' + page + ':';
  return {
    embeds: [embed],
    components: [new ActionRowBuilder().addComponents(
      button(base + 'back', 'Back', ButtonStyle.Primary),
      button(base + 'ban_user', 'Ban user', ButtonStyle.Danger, item.banned),
      button(base + 'revoke_key', 'Revoke key', ButtonStyle.Danger),
      button(base + 'both', 'Ban + revoke', ButtonStyle.Danger),
      button(base + 'ignore', 'Ignore', ButtonStyle.Secondary)
    )]
  };
};

const conflictConfirmView = async (userId, conflictId, page, action) => {
  const item = await conflicts.getConflict(conflictId);
  const labels = {
    ban_user: ['Ban attempted Roblox user?', 'This Roblox UserId will be refused by every premium key until the ban store is changed.'],
    revoke_key: ['Revoke the affected premium key?', 'The legitimate binding remains recorded, but the key and all live premium source sessions stop working.'],
    both: ['Ban user and revoke key?', 'This bans the attempted Roblox UserId and revokes the affected premium key.']
  };
  if (!labels[action]) throw new Error('Unknown conflict action');
  const base = 'aether:conflictconfirm:' + userId + ':' + item.conflictId + ':' + page + ':' + action + ':';
  return {
    embeds: [new EmbedBuilder()
      .setColor(0xed4245)
      .setTitle('⚠️ ' + labels[action][0])
      .setDescription(labels[action][1])
      .addFields(
        {name: 'Attempted account', value: copyable(item.attemptedUsername + ' (' + item.attemptedUserId + ')')},
        {name: 'Bound account', value: copyable(item.boundUsername + ' (' + item.boundUserId + ')')},
        {name: 'Key ID', value: copyable(item.keyId)}
      )],
    components: [new ActionRowBuilder().addComponents(
      button(base + 'yes', 'Confirm', ButtonStyle.Danger),
      button(base + 'cancel', 'Cancel', ButtonStyle.Secondary)
    )]
  };
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
    const changes = Object.entries(event.changes).map(([name, value]) => name + '=' + (name === 'expiresAt' ? dateText(value) : String(value))).join(', ');
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
      {name: 'Key ID', value: copyable(info.keyId), inline: false},
      {name: 'Label', value: inline(info.label || 'Unlabelled'), inline: true},
      {name: 'Status', value: inline(statusText(info.status)), inline: true},
      {name: 'Source', value: inline(info.source), inline: true},
      {name: 'Roblox username', value: info.binding ? copyable(info.binding.username) : inline('unbound'), inline: false},
      {name: 'Roblox UserId', value: info.binding ? copyable(info.binding.userId) : inline('unbound'), inline: false},
      {name: 'Uses', value: inline(info.uses), inline: true},
      {name: 'Created', value: copyable(dateText(info.createdAt)), inline: false},
      {name: 'Expires', value: copyable(dateText(info.expiresAt)), inline: false}
    )
    .setFooter({text: 'Premium raw keys cannot be viewed or recovered'})
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

const generatedText = (result, title = 'Generated premium key') => {
  const rawKey = String(result.key);
  const loader = "loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/init.lua', true), 'init.lua')({Closet = false, premiumKey = " + JSON.stringify(rawKey) + '})';
  const content = [
    '✅ **' + title + '**', '',
    'Normal AetherV2 works without this key. This key only unlocks AetherV2 Premium modules.', '',
    'Key ID', copyable(result.keyId),
    'Label ' + inline(result.record.label || 'Unlabelled') + '  •  expires ' + inline(dateText(result.record.expiresAt)), '',
    '⚠️ **Copy the raw premium key now. It is not stored and cannot be shown again.**',
    copyable(rawKey), '',
    'Premium loadstring', copyable(loader, 'lua')
  ].join('\n');
  if (content.length > MESSAGE_LIMIT) throw new Error('Generated premium loader exceeds Discord message limits');
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
    revoke: ['Revoke this premium key?', 'Existing premium sessions will stop working immediately. Normal AetherV2 will still load.'],
    unlink: ['Unlink this premium key?', 'The next verified Roblox account will be able to claim this premium key.'],
    rotate: ['Rotate this premium key?', 'The old premium key and all premium sessions will be revoked. A replacement raw premium key will be shown once.']
  };
  if (!verbs[action]) throw new Error('Unknown confirmation action');
  const base = 'aether:confirm:' + userId + ':' + action + ':' + info.keyId.slice(0, 16) + ':' + viewId + ':' + page + ':';
  return {
    embeds: [new EmbedBuilder()
      .setColor(0xed4245)
      .setTitle('⚠️ ' + verbs[action][0])
      .setDescription(verbs[action][1])
      .addFields(
        {name: 'Key ID', value: copyable(info.keyId)},
        {name: 'Label', value: inline(info.label), inline: true},
        {name: 'Account', value: info.binding ? copyable(info.binding.username) : inline('unbound'), inline: false}
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
  if (subcommand === 'conflicts') return respond(interaction, await conflictListView(interaction.user.id, 0));
  if (subcommand === 'list') return respond(interaction, await keyListView(interaction.user.id, 0, null, commandFilters(interaction)));
  if (subcommand === 'generate') {
    const result = await registry.createKey({label: interaction.options.getString('label', false) || undefined, expiresAt: interaction.options.getString('expires_at', false) || undefined, actor});
    return reply(interaction, generatedText(result));
  }
  if (subcommand === 'info') return respond(interaction, await keyDetailView(interaction.user.id, keyIdFrom(interaction)));
  if (subcommand === 'edit') {
    const result = await registry.editKey({id: keyIdFrom(interaction), label: interaction.options.getString('label', false) ?? undefined, expiresAt: interaction.options.getString('expires_at', false) ?? undefined, actor});
    return reply(interaction, ['✅ Updated premium key', copyable(result.keyId), 'Label ' + inline(result.record.label || 'none'), 'Expires', copyable(dateText(result.record.expiresAt))].join('\n'));
  }
  if (subcommand === 'renew') {
    const result = await registry.renewKey({id: keyIdFrom(interaction), expiresAt: interaction.options.getString('expires_at'), actor});
    return reply(interaction, ['✅ Renewed and enabled premium key', copyable(result.keyId), 'Expires', copyable(dateText(result.record.expiresAt))].join('\n'));
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
    return reply(interaction, ['✅ Enabled premium key', copyable(result.keyId)].join('\n'));
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
  if (action === 'conflicts') return updateComponent(interaction, conflictListView(ownerId, 0));
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

const handleConflictListButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const page = Number(parts[3]) || 0;
  const action = parts[4];
  if (action === 'home') return updateComponent(interaction, dashboardView(ownerId));
  return updateComponent(interaction, conflictListView(ownerId, action === 'prev' ? page - 1 : action === 'next' ? page + 1 : page));
};

const handleConflictSelect = async interaction => {
  const parts = interaction.customId.split(':');
  return updateComponent(interaction, conflictDetailView(parts[2], interaction.values[0], Number(parts[3]) || 0));
};

const handleConflictDetailButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const conflictId = parts[3];
  const page = Number(parts[4]) || 0;
  const action = parts[5];
  if (action === 'back') return updateComponent(interaction, conflictListView(ownerId, page));
  if (action === 'ignore') {
    await interaction.deferUpdate();
    await conflicts.resolveConflict({id: conflictId, action: 'ignore', actor: actorName(interaction)});
    return interaction.editReply(safePayload(await conflictListView(ownerId, page)));
  }
  if (['ban_user', 'revoke_key', 'both'].includes(action)) return updateComponent(interaction, conflictConfirmView(ownerId, conflictId, page, action));
  throw new Error('Unknown conflict action');
};

const handleConflictConfirmButton = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2];
  const conflictId = parts[3];
  const page = Number(parts[4]) || 0;
  const action = parts[5];
  const decision = parts[6];
  if (decision === 'cancel') return updateComponent(interaction, conflictDetailView(ownerId, conflictId, page));
  await interaction.deferUpdate();
  await conflicts.resolveConflict({id: conflictId, action, actor: actorName(interaction)});
  return interaction.editReply(safePayload(await conflictListView(ownerId, page)));
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
    return interaction.editReply(safePayload({content: ['✅ Revoked premium key', copyable(result.keyId), 'Existing premium sessions are now invalid. Normal AetherV2 is unaffected.'].join('\n'), embeds: [], components: []}));
  }
  if (action === 'unlink') {
    const result = await registry.unlinkKey({id: keyPrefix, actor});
    return interaction.editReply(safePayload({content: ['✅ Unlinked Roblox account', copyable(result.binding.username), 'From premium key', copyable(result.keyId)].join('\n'), embeds: [], components: []}));
  }
  throw new Error('Unknown confirmation action');
};

const handleModalSubmit = async interaction => {
  const parts = interaction.customId.split(':');
  const kind = parts[2];
  const actor = actorName(interaction);
  await interaction.deferReply({ephemeral: true});
  if (kind === 'generate') {
    const result = await registry.createKey({label: interaction.fields.getTextInputValue('label').trim() || undefined, expiresAt: interaction.fields.getTextInputValue('expires_at').trim() || undefined, actor});
    return reply(interaction, generatedText(result));
  }
  const keyPrefix = parts[4];
  if (kind === 'edit') {
    const label = interaction.fields.getTextInputValue('label').trim();
    const expiresAt = interaction.fields.getTextInputValue('expires_at').trim();
    const result = await registry.editKey({id: keyPrefix, label: label ? label : undefined, expiresAt: expiresAt ? expiresAt : undefined, actor});
    return reply(interaction, ['✅ Updated premium key', copyable(result.keyId), 'Label ' + inline(result.record.label || 'none'), 'Expires', copyable(dateText(result.record.expiresAt))].join('\n'));
  }
  if (kind === 'renew') {
    const result = await registry.renewKey({id: keyPrefix, expiresAt: interaction.fields.getTextInputValue('expires_at').trim(), actor});
    return reply(interaction, ['✅ Renewed and enabled premium key', copyable(result.keyId), 'Expires', copyable(dateText(result.record.expiresAt))].join('\n'));
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
    try { await handleKeyCommand(interaction); }
    catch (error) { logSafeError('Discord key command failed', error); await reply(interaction, '❌ ' + friendlyError(error)); }
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
      if (type === 'conflicts') return await handleConflictListButton(interaction);
      if (type === 'conflictdetail') return await handleConflictDetailButton(interaction);
      if (type === 'conflictconfirm') return await handleConflictConfirmButton(interaction);
      if (type === 'audit') return await handleAuditButton(interaction);
      if (type === 'detail') return await handleDetailButton(interaction);
      if (type === 'confirm') return await handleConfirmButton(interaction);
    }
    if (interaction.isStringSelectMenu()) {
      const type = interaction.customId.split(':')[1];
      if (type === 'conflictselect') return await handleConflictSelect(interaction);
      return await handleKeySelect(interaction);
    }
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
  const client = new Client({intents: [GatewayIntentBits.Guilds]});
  client.once('ready', async () => {
    try {
      await registerCommands();
      console.log('[AetherV2] Discord bot logged in as ' + client.user.tag);
    } catch (error) { logSafeError('Discord command registration failed', error); }
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
  conflictListView,
  conflictDetailView,
  confirmationView,
  friendlyError,
  MESSAGE_LIMIT,
  EMBED_DESCRIPTION_LIMIT
};
