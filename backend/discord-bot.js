'use strict';

const {
  Client,
  GatewayIntentBits,
  REST,
  Routes,
  SlashCommandBuilder,
  EmbedBuilder,
  AttachmentBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  StringSelectMenuBuilder,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle
} = require('discord.js');
const legacy = require('./discord-bot-core');
const registry = require('./key-registry');
const executionStats = require('./execution-stats');

const APPLICATION_ID = process.env.DISCORD_APPLICATION_ID || '';
const GUILD_ID = process.env.DISCORD_GUILD_ID || '';
const STATS_PAGE_SIZE = 8;
const MESSAGE_LIMIT = 2000;

const statsCommand = new SlashCommandBuilder()
  .setName('stats')
  .setDescription('View AetherV2 execution analytics')
  .setDMPermission(false)
  .addSubcommand(sub => sub.setName('summary').setDescription('Show totals, access split, active users, and detailed players'))
  .addSubcommand(sub => sub
    .setName('graph')
    .setDescription('Render daily execution trends so peaks and dips stay visible')
    .addStringOption(option => option.setName('period').setDescription('Daily graph range').setRequired(true).addChoices(
      {name: 'Last 7 days', value: '7d'},
      {name: 'Last 30 days', value: '30d'},
      {name: 'Last 90 days', value: '90d'},
      {name: 'All time · daily', value: 'all'}
    ))
    .addStringOption(option => option.setName('metric').setDescription('What to graph').setRequired(false).addChoices(
      {name: 'Executions', value: 'executions'},
      {name: 'Unique players', value: 'unique'}
    )));

const commands = legacy.commands.filter(command => command.name !== 'stats').concat(statsCommand.toJSON());
const inline = value => '`' + String(value ?? '').replace(/`/g, 'ˋ') + '`';
const truncate = (value, length) => {
  const string = String(value ?? '');
  return string.length <= length ? string : string.slice(0, Math.max(0, length - 1)) + '…';
};
const button = (customId, label, style = ButtonStyle.Secondary, disabled = false) => new ButtonBuilder()
  .setCustomId(customId).setLabel(label).setStyle(style).setDisabled(disabled);
const safePayload = payload => ({...payload, allowedMentions: {parse: []}});
const actorName = interaction => interaction.user.username + ' (' + interaction.user.id + ')';
const accessText = value => value === 'premium' ? 'Premium' : value === 'free' ? 'Free' : 'Unclassified';
const formatDuration = seconds => {
  const total = Math.max(0, Math.floor(Number(seconds) || 0));
  const days = Math.floor(total / 86400);
  const hours = Math.floor((total % 86400) / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const secs = total % 60;
  if (days) return days + 'd ' + hours + 'h ' + minutes + 'm';
  if (hours) return hours + 'h ' + minutes + 'm';
  if (minutes) return minutes + 'm ' + secs + 's';
  return secs + 's';
};
const dateText = value => value ? new Date(value).toISOString() : 'never';
const statValue = value => inline(String(value.executions) + ' exec / ' + String(value.unique) + ' unique');
const rangeName = range => ({'7d': '7 days', '30d': '30 days', '90d': '90 days', all: 'all time'}[range] || range);

const reply = async (interaction, payload) => {
  const value = safePayload(payload);
  if (interaction.deferred || interaction.replied) return interaction.editReply(value);
  return interaction.reply({...value, ephemeral: true});
};
const update = async (interaction, payload) => {
  if (!interaction.deferred && !interaction.replied) await interaction.deferUpdate();
  return interaction.editReply(safePayload(payload));
};

const summaryView = ownerId => {
  const stats = executionStats.summary();
  const embed = new EmbedBuilder()
    .setColor(0xbe73ff)
    .setTitle('📈 AetherV2 execution stats')
    .setDescription('UTC totals. Detailed tracking is owner-only; use time comes from live heartbeats instead of being guessed from launch count.')
    .addFields(
      {name: 'This hour', value: statValue(stats.hourly), inline: true},
      {name: 'Today', value: statValue(stats.daily), inline: true},
      {name: 'This week', value: statValue(stats.weekly), inline: true},
      {name: 'This month', value: statValue(stats.monthly), inline: true},
      {name: 'All time', value: statValue(stats.allTime), inline: true},
      {name: 'Active now', value: inline(stats.activeUsers), inline: true},
      {name: 'Free', value: inline(stats.freeExecutions), inline: true},
      {name: 'Premium', value: inline(stats.premiumExecutions), inline: true},
      {name: 'Unclassified', value: inline(stats.unknownExecutions), inline: true},
      {name: 'Tracked use time', value: inline(formatDuration(stats.trackedSeconds)), inline: true}
    )
    .setFooter({text: stats.lastSeenAt ? 'Last activity ' + stats.lastSeenAt : 'No executions recorded yet'});
  return {
    embeds: [embed],
    components: [new ActionRowBuilder().addComponents(
      button('aether:statslist:' + ownerId + ':0', 'Details', ButtonStyle.Primary),
      button('aether:statsrefresh:' + ownerId, 'Refresh')
    )]
  };
};

const userListView = (ownerId, requestedPage = 0) => {
  const result = executionStats.listUsers({page: requestedPage, pageSize: STATS_PAGE_SIZE});
  const embed = new EmbedBuilder()
    .setColor(0xbe73ff)
    .setTitle('👥 AetherV2 execution details')
    .setDescription(result.total ? 'Select a Roblox player for full execution, usage-time, and premium details.' : 'No identified players have been recorded yet. Anonymous fallback executions remain included in totals.')
    .setFooter({text: 'Page ' + (result.page + 1) + ' of ' + result.pageCount + ' • ' + result.total + ' identified player' + (result.total === 1 ? '' : 's')})
    .setTimestamp();
  for (const profile of result.users) {
    embed.addFields({
      name: (profile.active ? '🟢 ' : '⚪ ') + (profile.username || ('UserId ' + profile.userId)),
      value: [
        inline(accessText(profile.lastAccess)) + ' • ' + inline(profile.executions + ' uses') + ' • ' + inline(formatDuration(profile.trackedSeconds)),
        'Premium/free ' + inline(profile.premiumExecutions + '/' + profile.freeExecutions) + ' • last ' + inline(dateText(profile.lastSeenAt))
      ].join('\n')
    });
  }
  const components = [new ActionRowBuilder().addComponents(
    button('aether:statslist:' + ownerId + ':' + (result.page - 1), 'Previous', ButtonStyle.Secondary, result.page <= 0),
    button('aether:statslist:' + ownerId + ':' + (result.page + 1), 'Next', ButtonStyle.Secondary, result.page >= result.pageCount - 1),
    button('aether:statslist:' + ownerId + ':' + result.page, 'Refresh'),
    button('aether:statshome:' + ownerId, 'Summary', ButtonStyle.Primary)
  )];
  if (result.users.length) {
    components.push(new ActionRowBuilder().addComponents(new StringSelectMenuBuilder()
      .setCustomId('aether:statsselect:' + ownerId + ':' + result.page)
      .setPlaceholder('Select a player')
      .addOptions(result.users.map(profile => ({
        label: truncate(profile.username || ('UserId ' + profile.userId), 100),
        description: truncate(accessText(profile.lastAccess) + ' • ' + profile.executions + ' uses • ' + formatDuration(profile.trackedSeconds), 100),
        value: profile.profileId
      })))))
  }
  return {embeds: [embed], components};
};

const premiumForProfile = async profile => {
  const keys = await registry.listKeys();
  const matches = keys.filter(item => item.binding && String(item.binding.userId) === String(profile.userId));
  return {
    active: matches.find(item => item.status === 'active') || null,
    latest: matches.sort((left, right) => Date.parse(right.createdAt || 0) - Date.parse(left.createdAt || 0))[0] || null
  };
};

const userDetailView = async (ownerId, profileId, page = 0) => {
  const profile = executionStats.getUser(profileId);
  if (!profile) throw Object.assign(new Error('That execution profile no longer exists.'), {status: 404});
  const premium = await premiumForProfile(profile);
  const keyState = premium.active ? 'Active key' : premium.latest ? ('No active key · latest ' + premium.latest.status) : 'No premium key';
  const embed = new EmbedBuilder()
    .setColor(profile.lastAccess === 'premium' ? 0xf1c40f : 0xbe73ff)
    .setTitle('👤 ' + (profile.username || 'AetherV2 player'))
    .setDescription(profile.active ? '🟢 Active recently' : '⚪ Not active recently')
    .addFields(
      {name: 'Roblox identity', value: inline(profile.username || 'unknown') + '\n' + inline(profile.userId), inline: true},
      {name: 'Latest access', value: inline(accessText(profile.lastAccess)) + '\n' + inline(keyState), inline: true},
      {name: 'Aether uses', value: inline(profile.executions), inline: true},
      {name: 'Tracked use time', value: inline(formatDuration(profile.trackedSeconds)), inline: true},
      {name: 'Premium / Free', value: inline(profile.premiumExecutions + ' / ' + profile.freeExecutions), inline: true},
      {name: 'Sessions tracked', value: inline(profile.sessions), inline: true},
      {name: 'First seen', value: inline(dateText(profile.firstSeenAt)), inline: false},
      {name: 'Last seen', value: inline(dateText(profile.lastSeenAt)), inline: false},
      {name: 'Last PlaceId', value: inline(profile.lastPlaceId || 'unknown'), inline: true}
    )
    .setFooter({text: 'Client telemetry is useful product analytics, not tamper-proof billing/security evidence.'});
  return {
    embeds: [embed],
    components: [new ActionRowBuilder().addComponents(
      button('aether:statsuser:' + ownerId + ':' + profileId + ':' + page + ':back', 'Back'),
      button('aether:statsuser:' + ownerId + ':' + profileId + ':' + page + ':refresh', 'Refresh'),
      button('aether:statsuser:' + ownerId + ':' + profileId + ':' + page + ':grant', premium.active ? 'Premium Active' : 'Grant Premium', premium.active ? ButtonStyle.Secondary : ButtonStyle.Success, Boolean(premium.active))
    )]
  };
};

const grantModal = (ownerId, profileId, page) => new ModalBuilder()
  .setCustomId('aether:statsgrant:' + ownerId + ':' + profileId + ':' + page)
  .setTitle('Grant AetherV2 Premium')
  .addComponents(
    new ActionRowBuilder().addComponents(new TextInputBuilder()
      .setCustomId('discord_user_id').setLabel('Recipient Discord user ID').setStyle(TextInputStyle.Short).setRequired(true).setMaxLength(20)),
    new ActionRowBuilder().addComponents(new TextInputBuilder()
      .setCustomId('expiry_days').setLabel('Expiry in days (optional)').setStyle(TextInputStyle.Short).setRequired(false).setMaxLength(4).setPlaceholder('Blank = no expiry'))
  );

const handleStatsCommand = async interaction => {
  const subcommand = interaction.options.getSubcommand();
  if (subcommand === 'summary') return reply(interaction, summaryView(interaction.user.id));
  const range = interaction.options.getString('period', true);
  const metric = interaction.options.getString('metric', false) || 'executions';
  const graph = executionStats.renderGraph(range, metric);
  const fileName = 'aetherv2-' + range + '-' + metric + '.png';
  const attachment = new AttachmentBuilder(graph.buffer, {name: fileName});
  const first = graph.points[0], last = graph.points[graph.points.length - 1];
  const peak = graph.points.reduce((best, point) => point.value > best.value ? point : best, graph.points[0]);
  const embed = new EmbedBuilder()
    .setColor(0xbe73ff)
    .setTitle('📈 ' + (metric === 'unique' ? 'Unique players' : 'Executions') + ' · ' + rangeName(range))
    .setDescription('One x-axis point per UTC day • ' + inline(first.key) + ' → ' + inline(last.key) + '\nPeak ' + inline(peak.value) + ' on ' + inline(peak.key))
    .setImage('attachment://' + fileName);
  return reply(interaction, {embeds: [embed], files: [attachment]});
};

const handleStatsComponent = async interaction => {
  const parts = interaction.customId.split(':');
  const type = parts[1];
  const ownerId = parts[2];
  if (String(ownerId) !== String(interaction.user.id)) return reply(interaction, {content: 'This private stats view belongs to another owner.'});
  if (type === 'statsrefresh' || type === 'statshome') return update(interaction, summaryView(ownerId));
  if (type === 'statslist') return update(interaction, userListView(ownerId, Number(parts[3]) || 0));
  if (type === 'statsselect') return update(interaction, await userDetailView(ownerId, interaction.values[0], Number(parts[3]) || 0));
  if (type === 'statsuser') {
    const profileId = parts[3], page = Number(parts[4]) || 0, action = parts[5];
    if (action === 'back') return update(interaction, userListView(ownerId, page));
    if (action === 'refresh') return update(interaction, await userDetailView(ownerId, profileId, page));
    if (action === 'grant') return interaction.showModal(grantModal(ownerId, profileId, page));
  }
  throw new Error('Unknown stats action');
};

const handleGrant = async interaction => {
  const parts = interaction.customId.split(':');
  const ownerId = parts[2], profileId = parts[3];
  if (String(ownerId) !== String(interaction.user.id)) return reply(interaction, {content: 'This private stats view belongs to another owner.'});
  const profile = executionStats.getUser(profileId);
  if (!profile) return reply(interaction, {content: 'That execution profile no longer exists.'});
  const existing = await premiumForProfile(profile);
  if (existing.active) return reply(interaction, {content: 'This Roblox user already has an active premium key.'});
  const discordUserId = interaction.fields.getTextInputValue('discord_user_id').trim();
  if (!/^\d{15,20}$/.test(discordUserId)) return reply(interaction, {content: 'Enter a valid Discord user ID.'});
  const expiryText = interaction.fields.getTextInputValue('expiry_days').trim();
  let expiresAt;
  if (expiryText) {
    const days = Number(expiryText);
    if (!Number.isInteger(days) || days < 1 || days > 3650) return reply(interaction, {content: 'Expiry days must be a whole number from 1 to 3650.'});
    expiresAt = new Date(Date.now() + days * 86400000).toISOString();
  }
  await interaction.deferReply({ephemeral: true});
  const result = await registry.createKey({label: 'Stats grant · ' + (profile.username || profile.userId), expiresAt, actor: actorName(interaction)});
  const intended = '\nIntended Roblox user: ' + inline(profile.username || 'unknown') + ' (' + inline(profile.userId) + '). The key binds on first successful use.';
  const delivery = legacy.generatedText(result) + intended;
  try {
    const target = await interaction.client.users.fetch(discordUserId);
    if (!target || target.bot) throw new Error('Recipient is not a normal Discord user');
    await target.send({content: truncate(delivery, MESSAGE_LIMIT), allowedMentions: {parse: []}});
    return interaction.editReply(safePayload({content: '✅ Premium key generated and DMed to ' + inline(target.username) + ' for Roblox user ' + inline(profile.username || profile.userId) + '.'}));
  } catch {
    return interaction.editReply(safePayload({content: truncate('⚠️ The key was generated, but the DM could not be delivered. This is the only recovery copy; send it manually to the intended user.\n\n' + delivery, MESSAGE_LIMIT)}));
  }
};

const isStatsInteraction = interaction =>
  Boolean(interaction.isChatInputCommand && interaction.isChatInputCommand() && interaction.commandName === 'stats') ||
  Boolean(interaction.customId && interaction.customId.startsWith('aether:stats'));

const handleInteraction = async interaction => {
  if (!isStatsInteraction(interaction)) return legacy.handleInteraction(interaction);
  if (!legacy.isOwnerId(interaction.user.id)) return reply(interaction, {content: 'You are not authorized to view AetherV2 analytics.'});
  try {
    if (interaction.isChatInputCommand()) return await handleStatsCommand(interaction);
    if (interaction.isModalSubmit()) return await handleGrant(interaction);
    if (interaction.isButton() || interaction.isStringSelectMenu()) return await handleStatsComponent(interaction);
  } catch (error) {
    console.error('[AetherV2] stats dashboard failed:', truncate(error && error.message || error, 300));
    return reply(interaction, {content: '❌ ' + (error && error.message ? error.message : 'The stats action failed.')});
  }
};

const registerCommands = async () => {
  const rest = new REST({version: '10'}).setToken(process.env.DISCORD_TOKEN);
  const route = GUILD_ID ? Routes.applicationGuildCommands(APPLICATION_ID, GUILD_ID) : Routes.applicationCommands(APPLICATION_ID);
  await rest.put(route, {body: commands});
  console.log('[AetherV2] registered Discord key + stats commands' + (GUILD_ID ? ' for guild ' + GUILD_ID : ' globally'));
};

const startDiscordBot = async () => {
  if (!process.env.DISCORD_TOKEN) throw new Error('DISCORD_TOKEN is required');
  if (!APPLICATION_ID) throw new Error('DISCORD_APPLICATION_ID is required');
  const client = new Client({intents: [GatewayIntentBits.Guilds]});
  client.once('ready', async () => {
    try {
      await registerCommands();
      console.log('[AetherV2] Discord bot logged in as ' + client.user.tag);
    } catch (error) { console.error('[AetherV2] Discord command registration failed:', error.message || error); }
  });
  client.on('interactionCreate', interaction => handleInteraction(interaction).catch(error => console.error('[AetherV2] Discord interaction failed:', error.message || error)));
  await client.login(process.env.DISCORD_TOKEN);
  return client;
};

if (require.main === module) startDiscordBot().catch(error => { console.error(error); process.exitCode = 1; });

module.exports = {...legacy, startDiscordBot, commands, handleInteraction, summaryView, userListView, userDetailView, statsCommand};
