#!/usr/bin/env python3
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
GAME_FILE = ROOT / 'games' / '6872274481.lua'
GAME_DIR = ROOT / 'games' / '6872274481'


def read(path):
    return path.read_text(encoding='utf-8')


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')


def replace_once(path, old, new, label):
    text = read(path)
    if new in text:
        return False
    if old not in text:
        raise RuntimeError(f'Could not find {label} in {path.relative_to(ROOT)}')
    write(path, text.replace(old, new, 1))
    return True


def mask_lua(source):
    out = list(source)
    length = len(source)
    i = 0

    def blank(start, end):
        for index in range(start, end):
            if out[index] not in ('\n', '\r'):
                out[index] = ' '

    def long_bracket(start):
        if source[start] != '[':
            return None
        j = start + 1
        while j < length and source[j] == '=':
            j += 1
        if j >= length or source[j] != '[':
            return None
        close = ']' + ('=' * (j - start - 1)) + ']'
        end = source.find(close, j + 1)
        return length if end == -1 else end + len(close)

    while i < length:
        if source.startswith('--', i):
            lb = long_bracket(i + 2) if i + 2 < length else None
            if lb is not None:
                blank(i, lb)
                i = lb
                continue
            end = source.find('\n', i + 2)
            if end == -1:
                end = length
            blank(i, end)
            i = end
            continue
        char = source[i]
        if char in ('\'', '"'):
            quote = char
            j = i + 1
            while j < length:
                if source[j] == '\\':
                    j += 2
                    continue
                if source[j] == quote:
                    j += 1
                    break
                j += 1
            blank(i, min(j, length))
            i = min(j, length)
            continue
        if char == '[':
            lb = long_bracket(i)
            if lb is not None:
                blank(i, lb)
                i = lb
                continue
        i += 1
    return ''.join(out)


RUN_START = re.compile(r'\brun\s*\(\s*function\s*\(\s*\)')
MODULE_CALL = re.compile(r'(?:(?:vape\s*\.\s*Categories\s*\.\s*([A-Za-z0-9_]+))|(\bkits\b))\s*:\s*CreateModule\s*\(')
NAME_LITERAL = re.compile(r'\bName\s*=\s*([\'\"])(.*?)\1', re.S)


def find_run_spans(source, masked):
    spans = []
    for match in RUN_START.finditer(masked):
        opening = masked.find('(', match.start(), match.end())
        if opening == -1:
            continue
        depth = 0
        end = None
        for index in range(opening, len(masked)):
            char = masked[index]
            if char == '(':
                depth += 1
            elif char == ')':
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break
        if end is None:
            raise RuntimeError(f'Unclosed run(function()) starting near byte {match.start()}')
        spans.append((match.start(), end))
    return spans


def find_module_calls(source, masked):
    calls = []
    for match in MODULE_CALL.finditer(masked):
        category = match.group(1) or 'Kits'
        snippet = source[match.start():min(len(source), match.end() + 1200)]
        name_match = NAME_LITERAL.search(snippet)
        name = name_match.group(2).strip() if name_match else f'ModuleAt{match.start()}'
        calls.append({'pos': match.start(), 'category': category, 'name': name})
    return calls


def safe_name(value):
    value = re.sub(r'[^A-Za-z0-9_.-]+', '_', str(value)).strip('._')
    return value or 'module'


def split_game_file():
    main_template = GAME_DIR / 'main.lua'
    if main_template.exists() and 'AETHER_MODULE:' in read(main_template):
        print('BedWars source is already split; skipping one-time extraction')
        return

    source = read(GAME_FILE)
    masked = mask_lua(source)
    spans = find_run_spans(source, masked)
    calls = find_module_calls(source, masked)
    if not calls:
        raise RuntimeError('No CreateModule calls were found in games/6872274481.lua')

    # A module belongs to the nearest run(function()) wrapper around it. That keeps helper locals,
    # toggles, callbacks, and conditional alternatives in the same source block without inventing
    # a new runtime scope.
    nearest = {}
    for call_index, call in enumerate(calls):
        containing = [span for span in spans if span[0] <= call['pos'] < span[1]]
        if not containing:
            raise RuntimeError(f"Module {call['name']} is not inside run(function())")
        nearest[call_index] = min(containing, key=lambda span: span[1] - span[0])

    selected = sorted(set(nearest.values()))
    # If selected wrappers overlap, promote the nested set to the outer selected wrapper. This is
    # rare, but it preserves exact lexical/conditional behaviour instead of producing invalid Lua.
    changed = True
    while changed:
        changed = False
        result = []
        for span in sorted(selected, key=lambda item: (item[0], -(item[1] - item[0]))):
            overlap = next((existing for existing in result if existing[0] <= span[0] < existing[1]), None)
            if overlap:
                changed = True
                continue
            result.append(span)
        selected = sorted(result)

    covered = [False] * len(calls)
    entries = []
    used_paths = set()
    group_number = 0

    for order, span in enumerate(selected, 1):
        members = []
        for index, call in enumerate(calls):
            if span[0] <= call['pos'] < span[1]:
                members.append(call)
                covered[index] = True
        unique = []
        seen = set()
        for call in members:
            key = (call['category'].lower(), call['name'].lower())
            if key not in seen:
                seen.add(key)
                unique.append(call)
        if not unique:
            continue

        categories = {item['category'].lower() for item in unique}
        category = next(iter(categories)) if len(categories) == 1 else 'mixed'
        if len(unique) == 1:
            stem = safe_name(unique[0]['name'])
        else:
            group_number += 1
            stem = safe_name(unique[0]['name']) + '__group' + str(group_number)

        relative = Path(category) / (stem + '.lua')
        counter = 2
        while str(relative).lower() in used_paths:
            relative = Path(category) / (stem + '__variant' + str(counter) + '.lua')
            counter += 1
        used_paths.add(str(relative).lower())
        block = source[span[0]:span[1]]
        write(GAME_DIR / relative, block)

        # Coupled wrappers occasionally register more than one module. Keep one authoritative block
        # to preserve the original local scope, but leave a small discoverability file for each
        # additional module so every module can still be found under its category/name.
        if len(unique) > 1:
            for module in unique:
                alias = Path(module['category'].lower()) / (safe_name(module['name']) + '.lua')
                alias_key = str(alias).lower()
                if alias_key in used_paths or alias == relative:
                    continue
                used_paths.add(alias_key)
                pointer = '-- Coupled module source. The original run(function()) scope also registers other modules.\n' \
                    + '-- Edit the authoritative block at: ../' + str(relative).replace('\\', '/') + '\n'
                write(GAME_DIR / alias, pointer)

        entries.append({'start': span[0], 'end': span[1], 'path': str(relative).replace('\\', '/'), 'modules': unique})

    if not all(covered):
        missing = [calls[index]['name'] for index, value in enumerate(covered) if not value]
        raise RuntimeError('Some modules were not assigned to split files: ' + ', '.join(missing[:20]))

    template_parts = []
    cursor = 0
    for entry in entries:
        template_parts.append(source[cursor:entry['start']])
        template_parts.append('--[[AETHER_MODULE:' + entry['path'] + ']]')
        cursor = entry['end']
    template_parts.append(source[cursor:])
    template = ''.join(template_parts)

    # The template is deliberately not executed directly; build-bedwars-bundle.py restores each
    # exact module block into the marker position, producing the same lexical scope as the old file.
    first_newline = template.find('\n')
    header = (
        '-- AetherV2 BedWars source template. Shared setup/non-module logic stays here.\n'
        '-- Category module blocks live beside this file and are reassembled into bundle.lua for runtime.\n'
        '-- Run tools/build-bedwars-bundle.py after editing a module.\n'
    )
    if first_newline >= 0:
        template = header + template[first_newline + 1:]
    else:
        template = header + template
    write(main_template, template)

    # Verify markers can recreate every extracted byte before replacing the legacy entrypoint.
    rebuilt = template
    for entry in entries:
        marker = '--[[AETHER_MODULE:' + entry['path'] + ']]'
        rebuilt = rebuilt.replace(marker, read(GAME_DIR / entry['path']), 1)
    if ':CreateModule' not in rebuilt:
        raise RuntimeError('Bundle verification unexpectedly contains no modules')

    wrapper = """-- AetherV2 BedWars compatibility entrypoint. The maintainable source is games/6872274481/.\nlocal license = ... or {}\nif type(license) ~= 'table' then license = {} end\n\nlocal function fetchBundle()\n\tlocal path = 'aetherv2/games/6872274481/bundle.lua'\n\tif type(shared.AetherV2FetchSource) == 'function' then\n\t\tlocal ok, result = pcall(shared.AetherV2FetchSource, path)\n\t\tif ok and type(result) == 'string' and result ~= '' then return result end\n\tend\n\tlocal commit = 'main'\n\tpcall(function()\n\t\tlocal saved = readfile('aetherv2/profiles/commit.txt')\n\t\tif type(saved) == 'string' and saved ~= '' then commit = saved end\n\tend)\n\treturn game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/games/6872274481/bundle.lua', true)\nend\n\nlocal source = fetchBundle()\nlocal chunk, err = loadstring(source, 'games/6872274481/bundle.lua')\nif not chunk then error(err) end\nreturn chunk(license)\n"""
    write(GAME_FILE, wrapper)

    manifest = {
        'generatedFrom': 'games/6872274481.lua',
        'moduleBlocks': len(entries),
        'moduleRegistrations': len(calls),
        'coupledGroups': sum(1 for entry in entries if len(entry['modules']) > 1),
        'categories': sorted({call['category'].lower() for call in calls})
    }
    write(GAME_DIR / 'structure.json', json.dumps(manifest, indent=2) + '\n')
    print(f"Split {len(calls)} module registrations into {len(entries)} source blocks across {len(manifest['categories'])} categories")


def patch_reviewer():
    path = ROOT / 'guis' / 'new.core.lua'
    old = "\t\treview.Visible = localPlayer.Name:lower() == 'plutoxqqqqq'"
    new = "\t\tlocal reviewAccounts = {aetherv2owner = true, plutoxqqqqqq = true}\n\t\treview.Visible = reviewAccounts[localPlayer.Name:lower()] == true"
    replace_once(path, old, new, 'config review account check')


def patch_init_analytics():
    path = ROOT / 'init.lua'
    text = read(path)
    if '/analytics/execution' in text:
        return
    marker = 'local function authorizePremium()\n'
    if marker not in text:
        raise RuntimeError('Could not locate premium authorization in init.lua')
    block = """local function reportExecution()\n\tlocal player = game:GetService('Players').LocalPlayer\n\tif not player then return end\n\tlocal endpoint = premiumEndpoint()..'/analytics/execution'\n\tlocal requestFunction = (syn and syn.request) or http_request or request\n\tif type(requestFunction) == 'function' then\n\t\tlocal http = game:GetService('HttpService')\n\t\tlocal ok = pcall(requestFunction, {\n\t\t\tUrl = endpoint,\n\t\t\tMethod = 'POST',\n\t\t\tHeaders = {['Content-Type'] = 'application/json'},\n\t\t\tBody = http:JSONEncode({userId = tostring(player.UserId), placeId = tostring(game.PlaceId)})\n\t\t})\n\t\tif ok then return end\n\tend\n\t-- Executors without a request API still contribute to execution totals, but no user identity is sent.\n\tpcall(game.HttpGet, game, endpoint, true)\nend\ntask.spawn(reportExecution)\n\n"""
    write(path, text.replace(marker, block + marker, 1))


def patch_private_source():
    path = ROOT / 'backend' / 'private-source.js'
    text = read(path)
    if "require('./execution-stats')" not in text:
        text = text.replace("const cloud = require('./cloud-configs');\n", "const cloud = require('./cloud-configs');\nconst executionStats = require('./execution-stats');\n", 1)
    if 'AETHER_ANALYTICS_RATE_LIMIT' not in text:
        text = text.replace(
            "const CLOUD_RATE_LIMIT = boundedNumber(process.env.AETHER_CLOUD_RATE_LIMIT, 120, 10, 10000);\n",
            "const CLOUD_RATE_LIMIT = boundedNumber(process.env.AETHER_CLOUD_RATE_LIMIT, 120, 10, 10000);\nconst ANALYTICS_RATE_LIMIT = boundedNumber(process.env.AETHER_ANALYTICS_RATE_LIMIT, 60, 5, 1000);\n",
            1
        )
    if 'const ANALYTICS_MAX_BODY' not in text:
        text = text.replace("const CLOUD_MAX_BODY = cloud.MAX_PAYLOAD_BYTES + (64 * 1024);\n", "const CLOUD_MAX_BODY = cloud.MAX_PAYLOAD_BYTES + (64 * 1024);\nconst ANALYTICS_MAX_BODY = 8 * 1024;\n", 1)
    if 'const readAnalyticsBody' not in text:
        marker = 'const requestIp = req =>'
        body = """const readAnalyticsBody = req => new Promise((resolve, reject) => {\n  let size = 0;\n  const chunks = [];\n  req.on('data', chunk => {\n    const value = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);\n    size += value.length;\n    if (size > ANALYTICS_MAX_BODY) return reject(problem('Analytics payload is too large', 413));\n    chunks.push(value);\n  });\n  req.on('end', () => {\n    try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); }\n    catch { reject(problem('Invalid analytics JSON body', 400)); }\n  });\n  req.on('error', reject);\n});\n\n"""
        if marker not in text:
            raise RuntimeError('Could not locate requestIp in private-source.js')
        text = text.replace(marker, body + marker, 1)
    old_rate = "  const authRoute = pathname === '/premium/authorize';\n  const cloudRoute = pathname.startsWith('/cloud/');\n  const limit = authRoute ? AUTH_RATE_LIMIT : cloudRoute ? CLOUD_RATE_LIMIT : RATE_LIMIT;\n  const group = authRoute ? 'auth' : cloudRoute ? 'cloud' : 'premium-source';"
    new_rate = "  const authRoute = pathname === '/premium/authorize';\n  const cloudRoute = pathname.startsWith('/cloud/');\n  const analyticsRoute = pathname === '/analytics/execution';\n  const limit = analyticsRoute ? ANALYTICS_RATE_LIMIT : authRoute ? AUTH_RATE_LIMIT : cloudRoute ? CLOUD_RATE_LIMIT : RATE_LIMIT;\n  const group = analyticsRoute ? 'analytics' : authRoute ? 'auth' : cloudRoute ? 'cloud' : 'premium-source';"
    if new_rate not in text:
        if old_rate not in text:
            raise RuntimeError('Could not locate rate-limit routing in private-source.js')
        text = text.replace(old_rate, new_rate, 1)
    if "url.pathname === '/analytics/execution'" not in text:
        marker = "    if (url.pathname.startsWith('/cloud/')) return await routeCloud(req, res, url);\n"
        route = """    if (url.pathname === '/analytics/execution' && (req.method === 'POST' || req.method === 'GET')) {\n      const payload = req.method === 'POST' ? await readAnalyticsBody(req) : {};\n      await executionStats.recordExecution(payload);\n      return json(res, 202, {success: true});\n    }\n\n"""
        if marker not in text:
            raise RuntimeError('Could not locate cloud route in private-source.js')
        text = text.replace(marker, route + marker, 1)
    if 'executionAnalytics: true' not in text:
        text = text.replace('        cloudConfigs: true,\n', '        cloudConfigs: true,\n        executionAnalytics: true,\n', 1)
    write(path, text)


def patch_discord_bot():
    path = ROOT / 'backend' / 'discord-bot.js'
    text = read(path)
    if 'AttachmentBuilder' not in text:
        text = text.replace('  EmbedBuilder,\n', '  EmbedBuilder,\n  AttachmentBuilder,\n', 1)
    if "require('./execution-stats')" not in text:
        text = text.replace("const conflicts = require('./key-conflicts');\n", "const conflicts = require('./key-conflicts');\nconst executionStats = require('./execution-stats');\n", 1)
    if ".setName('stats')" not in text:
        marker = '].map(command => command.toJSON());'
        stats_command = """,\n  new SlashCommandBuilder()\n    .setName('stats')\n    .setDescription('View AetherV2 execution analytics')\n    .setDMPermission(false)\n    .addSubcommand(sub => sub.setName('summary').setDescription('Show hourly, daily, weekly, monthly, and all-time stats'))\n    .addSubcommand(sub => sub\n      .setName('graph')\n      .setDescription('Render an execution trend line graph')\n      .addStringOption(option => option.setName('period').setDescription('Graph period').setRequired(true).addChoices(\n        {name: 'Hourly · last 24 hours', value: 'hourly'},\n        {name: 'Daily · last 30 days', value: 'daily'},\n        {name: 'Weekly · last 12 weeks', value: 'weekly'},\n        {name: 'Monthly · last 12 months', value: 'monthly'}\n      ))\n      .addStringOption(option => option.setName('metric').setDescription('What to graph').setRequired(false).addChoices(\n        {name: 'Executions', value: 'executions'},\n        {name: 'Unique players', value: 'unique'}\n      )))\n"""
        if marker not in text:
            raise RuntimeError('Could not locate Discord command array end')
        text = text.replace(marker, stats_command + marker, 1)
    if 'const handleStatsCommand = async interaction =>' not in text:
        marker = 'const handleInteraction = async interaction => {'
        helper = """const statValue = value => inline(String(value.executions) + ' exec / ' + String(value.unique) + ' unique');\nconst handleStatsCommand = async interaction => {\n  const subcommand = interaction.options.getSubcommand();\n  if (subcommand === 'summary') {\n    const stats = executionStats.summary();\n    const embed = new EmbedBuilder()\n      .setColor(0xbe73ff)\n      .setTitle('📈 AetherV2 execution stats')\n      .setDescription('Execution totals and hashed unique-player counts. Period buckets use UTC.')\n      .addFields(\n        {name: 'This hour', value: statValue(stats.hourly), inline: true},\n        {name: 'Today', value: statValue(stats.daily), inline: true},\n        {name: 'This week', value: statValue(stats.weekly), inline: true},\n        {name: 'This month', value: statValue(stats.monthly), inline: true},\n        {name: 'All time', value: statValue(stats.allTime), inline: true}\n      )\n      .setFooter({text: stats.lastSeenAt ? 'Last execution ' + stats.lastSeenAt : 'No executions recorded yet'});\n    return respond(interaction, {embeds: [embed]});\n  }\n  const period = interaction.options.getString('period', true);\n  const metric = interaction.options.getString('metric', false) || 'executions';\n  const graph = executionStats.renderGraph(period, metric);\n  const fileName = 'aetherv2-' + period + '-' + metric + '.png';\n  const attachment = new AttachmentBuilder(graph.buffer, {name: fileName});\n  const first = graph.points[0], last = graph.points[graph.points.length - 1];\n  const embed = new EmbedBuilder()\n    .setColor(0xbe73ff)\n    .setTitle('📈 ' + (metric === 'unique' ? 'Unique players' : 'Executions') + ' · ' + period)\n    .setDescription('Range ' + inline(first.label) + ' → ' + inline(last.label) + ' • peak ' + inline(graph.maxValue) + ' • UTC')\n    .setImage('attachment://' + fileName);\n  return respond(interaction, {embeds: [embed], files: [attachment]});\n};\n\n"""
        if marker not in text:
            raise RuntimeError('Could not locate Discord interaction handler')
        text = text.replace(marker, helper + marker, 1)
    old_handler = """  if (interaction.isChatInputCommand()) {\n    if (interaction.commandName !== 'key') return;\n    if (!isOwnerId(interaction.user.id)) return reply(interaction, 'You are not authorized to manage AetherV2 keys.');\n    await interaction.deferReply({ephemeral: true});\n    try { await handleKeyCommand(interaction); }\n    catch (error) { logSafeError('Discord key command failed', error); await reply(interaction, '❌ ' + friendlyError(error)); }\n    return;\n  }"""
    new_handler = """  if (interaction.isChatInputCommand()) {\n    if (!['key', 'stats'].includes(interaction.commandName)) return;\n    if (!isOwnerId(interaction.user.id)) return reply(interaction, 'You are not authorized to manage AetherV2.');\n    await interaction.deferReply({ephemeral: true});\n    try {\n      if (interaction.commandName === 'stats') await handleStatsCommand(interaction);\n      else await handleKeyCommand(interaction);\n    }\n    catch (error) { logSafeError('Discord command failed', error); await reply(interaction, '❌ ' + friendlyError(error)); }\n    return;\n  }"""
    if new_handler not in text:
        if old_handler not in text:
            raise RuntimeError('Could not locate Discord chat command handler')
        text = text.replace(old_handler, new_handler, 1)
    text = text.replace("console.log('[AetherV2] registered Discord key commands'", "console.log('[AetherV2] registered Discord management commands'", 1)
    write(path, text)


def patch_backend_misc():
    package = ROOT / 'backend' / 'package.json'
    text = read(package)
    if 'execution-stats.js' not in text:
        text = text.replace('node --check cloud-configs.js && node --check discord-bot.js', 'node --check cloud-configs.js && node --check execution-stats.js && node --check discord-bot.js')
        write(package, text)

    ignore = ROOT / 'backend' / '.gitignore'
    text = read(ignore)
    if 'execution-stats.json' not in text:
        write(ignore, text + ('\n' if text and not text.endswith('\n') else '') + 'execution-stats.json\n')

    readme = ROOT / 'backend' / 'README.md'
    text = read(readme)
    if '## Execution analytics' not in text:
        text += """\n## Execution analytics\n\nThe public loader reports one execution to the premium-source service without sending a premium key. When the executor exposes a request API, the report includes the Roblox UserId so the backend can count unique players; only a one-way SHA-256 hash is persisted. Executors without a request API still increment the anonymous execution total.\n\nFor durable all-time stats on Render, attach a persistent disk to the combined `node private-source.js` service and set:\n\n```text\nAETHER_STATS_FILE=/var/data/execution-stats.json\nAETHER_ANALYTICS_RATE_LIMIT=60\n```\n\nRun the Discord bot in the same `private-source.js` process so it reads the same live stats store. `/stats summary` shows the current hour, day, week, month, and all-time totals. `/stats graph` renders a PNG line graph for hourly (24 points), daily (30), weekly (12), or monthly (12) data and can graph either executions or unique players. Buckets use UTC.\n\nThe client-side report is intentionally lightweight and can be spoofed by a modified client, so these numbers are product telemetry rather than tamper-proof billing/security data. The analytics endpoint is separately rate-limited and never accepts or stores raw premium keys.\n"""
        write(readme, text)


def main():
    split_game_file()
    patch_reviewer()
    patch_init_analytics()
    patch_private_source()
    patch_discord_bot()
    patch_backend_misc()
    print('Applied reviewer and analytics updates')


if __name__ == '__main__':
    main()
