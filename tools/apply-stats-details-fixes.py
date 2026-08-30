#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path, old, new):
    file = ROOT / path
    source = file.read_text(encoding='utf-8')
    if new in source:
        return False
    if old not in source:
        raise RuntimeError(f'Expected patch marker missing in {path}: {old[:80]!r}')
    file.write_text(source.replace(old, new, 1), encoding='utf-8')
    return True


changed = False

changed |= replace_once('backend/execution-stats.js',
    "const ACTIVE_WINDOW_MS = 150000;",
    "const ACTIVE_WINDOW_MS = 30000;\nconst LAUNCH_CLASSIFY_WINDOW_MS = 60000;")

changed |= replace_once('backend/execution-stats.js',
"""const classifyPending = (profile, access) => {
  if (!profile || access === 'unknown' || profile.unknownExecutions <= 0 || state.access.unknown <= 0) return false;
  profile.unknownExecutions -= 1;
  state.access.unknown -= 1;
  if (access === 'premium') profile.premiumExecutions += 1;
  else profile.freeExecutions += 1;
  state.access[access] += 1;
  return true;
};""",
"""const classifyPending = (profile, access, now = Date.now()) => {
  if (!profile || access === 'unknown' || state.access.unknown <= 0) return false;
  if (profile.unknownExecutions > 0) {
    profile.unknownExecutions -= 1;
  } else {
    const launchAt = state.lastSeenAt ? Date.parse(state.lastSeenAt) : NaN;
    if (!Number.isFinite(launchAt) || Math.abs(now - launchAt) > LAUNCH_CLASSIFY_WINDOW_MS) return false;
    // The legacy/core launch can arrive without Roblox identity. Attach that already-counted
    // launch to the first identified heartbeat without incrementing global execution totals.
    profile.executions += 1;
  }
  state.access.unknown -= 1;
  if (access === 'premium') profile.premiumExecutions += 1;
  else profile.freeExecutions += 1;
  state.access[access] += 1;
  return true;
};""")

changed |= replace_once('backend/execution-stats.js',
"""    profile.sessions += 1;
    classifyPending(profile, access);""",
"""    profile.sessions += 1;
    classifyPending(profile, access, now);""")

changed |= replace_once('backend/execution-stats.js',
"""const recordExecution = async input => String(input && input.event || 'execution').toLowerCase() === 'heartbeat'
  ? addHeartbeat(input || {})
  : addLaunch(input || {});""",
"""const addSessionEnd = input => {
  const now = Date.now();
  const sessionId = validSessionId(input && input.sessionId);
  const {id, profile} = profileFor(input || {});
  if (!id || !profile || !sessionId) return {accepted: false, event: 'session_end', reason: 'identity-or-session-missing'};
  const runtimeKey = id + ':' + sessionId;
  const session = runtimeSessions.get(runtimeKey);
  if (session) {
    const delta = Math.max(0, Math.min(MAX_HEARTBEAT_DELTA_SECONDS, (now - session.lastAt) / 1000));
    if (delta > 0) profile.trackedSeconds += delta;
    runtimeSessions.delete(runtimeKey);
  }
  profile.lastSeenAt = new Date(now).toISOString();
  state.lastSeenAt = profile.lastSeenAt;
  scheduleWrite();
  return {accepted: true, event: 'session_end', profileId: id};
};

const recordExecution = async input => {
  const event = String(input && input.event || 'execution').toLowerCase();
  if (event === 'heartbeat') return addHeartbeat(input || {});
  if (event === 'session_end') return addSessionEnd(input || {});
  return addLaunch(input || {});
};""")

changed |= replace_once('backend/execution-stats.js',
"""const publicProfile = (id, profile) => ({
  profileId: id,""",
"""const profileIsActive = id => {
  const now = Date.now();
  let active = false;
  for (const [key, session] of runtimeSessions) {
    if (now - session.lastAt > ACTIVE_WINDOW_MS) {
      runtimeSessions.delete(key);
      continue;
    }
    if (key.startsWith(id + ':')) active = true;
  }
  return active;
};

const publicProfile = (id, profile) => ({
  profileId: id,""")

changed |= replace_once('backend/execution-stats.js',
"""  lastPlaceId: validPlaceId(profile.lastPlaceId),
  active: Boolean(profile.lastHeartbeatAt && Date.now() - Date.parse(profile.lastHeartbeatAt) <= ACTIVE_WINDOW_MS)
});""",
"""  lastPlaceId: validPlaceId(profile.lastPlaceId),
  active: profileIsActive(id),
  calculating: profileIsActive(id)
});""")

changed |= replace_once('backend/execution-stats.js',
"""const series = (period, metric = 'executions') => ['7d', '30d', '90d', 'all'].includes(period)
  ? dailySeries(period, metric)
  : normalSeries(period, metric);""",
"""const series = (period, metric = 'executions') => {
  // Every graph is daily. Legacy period names remain accepted for API compatibility, but are
  // mapped to useful daily windows instead of changing the x-axis unit.
  const range = ({hourly: '7d', daily: '30d', weekly: '90d', monthly: 'all'})[period] || period;
  return dailySeries(range, metric);
};""")

changed |= replace_once('backend/discord-bot.js',
"""const formatDuration = seconds => {
  const total = Math.max(0, Math.floor(Number(seconds) || 0));""",
"""const formatDuration = seconds => {
  const total = Math.max(0, Math.floor(Number(seconds) || 0));""")

changed |= replace_once('backend/discord-bot.js',
"""inline(accessText(profile.lastAccess)) + ' • ' + inline(profile.executions + ' uses') + ' • ' + inline(formatDuration(profile.trackedSeconds)),""",
"""inline(accessText(profile.lastAccess)) + ' • ' + inline(profile.executions + ' uses') + ' • ' + inline(profile.active ? 'Calculating' : formatDuration(profile.trackedSeconds)),""")

changed |= replace_once('backend/discord-bot.js',
"""description: truncate(accessText(profile.lastAccess) + ' • ' + profile.executions + ' uses • ' + formatDuration(profile.trackedSeconds), 100),""",
"""description: truncate(accessText(profile.lastAccess) + ' • ' + profile.executions + ' uses • ' + (profile.active ? 'Calculating' : formatDuration(profile.trackedSeconds)), 100),""")

changed |= replace_once('backend/discord-bot.js',
"""      {name: 'Tracked use time', value: inline(formatDuration(profile.trackedSeconds)), inline: true},""",
"""      {name: 'Tracked use time', value: inline(profile.active ? 'Calculating' : formatDuration(profile.trackedSeconds)), inline: true},""")

changed |= replace_once('init.lua',
"""local function sendHeartbeat(sessionId)
	local player = game:GetService('Players').LocalPlayer""",
"""local function sendTelemetry(sessionId, eventName)
	local player = game:GetService('Players').LocalPlayer""")

changed |= replace_once('init.lua',
"""		Body = http:JSONEncode({
			event = 'heartbeat',""",
"""		Body = http:JSONEncode({
			event = eventName or 'heartbeat',""")

changed |= replace_once('init.lua',
"""task.spawn(function()
	local sessionId = game:GetService('HttpService'):GenerateGUID(false):gsub('[^%w%-_]', '')
	local deadline = os.clock() + 30
	repeat task.wait(0.5) until (shared.vape and shared.vape.Loaded) or os.clock() >= deadline
	if not shared.vape then return end
	while shared.vape do
		sendHeartbeat(sessionId)
		for _ = 1, 60 do
			task.wait(1)
			if not shared.vape then return end
		end
	end
end)""",
"""task.spawn(function()
	local sessionId = game:GetService('HttpService'):GenerateGUID(false):gsub('[^%w%-_]', '')
	local deadline = os.clock() + 30
	local function running()
		local current = shared.vape
		return type(current) == 'table' and current.Loaded ~= false and current.Uninjecting ~= true
	end
	repeat task.wait(0.5) until running() or os.clock() >= deadline
	if not running() then return end
	while running() do
		sendTelemetry(sessionId, 'heartbeat')
		for _ = 1, 10 do
			task.wait(1)
			if not running() then
				sendTelemetry(sessionId, 'session_end')
				return
			end
		end
	end
	sendTelemetry(sessionId, 'session_end')
end)""")

# Extend regression tests for the repaired classification and all-daily graph contract.
file = ROOT / 'backend/execution-stats-v2.test.js'
source = file.read_text(encoding='utf-8')
marker = "test('all-time graph is daily and renders a valid PNG', () => {"
if "legacy graph periods also use daily points" not in source:
    insertion = """test('legacy graph periods also use daily points', () => {
  for (const period of ['hourly', 'daily', 'weekly', 'monthly', '7d', '30d', '90d', 'all']) {
    const graph = stats.renderGraph(period, 'executions');
    assert.ok(graph.points.length >= 1);
    assert.ok(graph.points.every(point => /^\\d{4}-\\d{2}-\\d{2}$/.test(point.key)), period + ' should use daily keys');
  }
});

"""
    if marker not in source:
        raise RuntimeError('execution stats graph test marker missing')
    file.write_text(source.replace(marker, insertion + marker, 1), encoding='utf-8')
    changed = True

print('Applied stats/details fixes' if changed else 'Stats/details fixes already applied')
