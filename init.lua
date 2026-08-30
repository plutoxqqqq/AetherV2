--!nocheck
local license = ... or {}
if type(license) ~= 'table' then license = {} end

local function analyticsEndpoint()
	local endpoint = license.PremiumEndpoint
	if (type(endpoint) ~= 'string' or endpoint == '') and getgenv then pcall(function() endpoint = getgenv().AetherV2PremiumEndpoint end) end
	if (type(endpoint) ~= 'string' or endpoint == '') then endpoint = shared.AetherV2PremiumEndpoint end
	if type(endpoint) ~= 'string' or endpoint == '' then endpoint = 'https://aetherv2.onrender.com' end
	return endpoint:gsub('/+$', '')..'/analytics/execution'
end

local function sendHeartbeat(sessionId)
	local player = game:GetService('Players').LocalPlayer
	if not player then return false end
	local requestFunction = (syn and syn.request) or http_request or request
	if type(requestFunction) ~= 'function' then return false end
	local http = game:GetService('HttpService')
	local ok = pcall(requestFunction, {
		Url = analyticsEndpoint(),
		Method = 'POST',
		Headers = {['Content-Type'] = 'application/json'},
		Body = http:JSONEncode({
			event = 'heartbeat',
			sessionId = sessionId,
			username = player.Name,
			userId = tostring(player.UserId),
			placeId = tostring(game.PlaceId),
			access = shared.AetherV2PremiumAuthorized == true and 'premium' or 'free'
		})
	})
	return ok
end

local function fetchCore()
	local ref = type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') or ''
	local refs = {}
	if ref ~= '' then table.insert(refs, ref) end
	table.insert(refs, 'main')
	for _, candidate in refs do
		local ok, body = pcall(game.HttpGet, game, 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..candidate..'/init-core.lua', true)
		if ok and type(body) == 'string' and #body > 100 and body ~= '404: Not Found' then return body end
	end
	error('AetherV2: could not load init-core.lua', 0)
end

local core, compileError = loadstring(fetchCore(), 'init-core.lua')
if not core then error('AetherV2: init-core.lua did not compile: '..tostring(compileError), 0) end
local result = core(license)

-- The core already records exactly one launch. The heartbeat classifies that launch as
-- Free/Premium and then measures actual use time without incrementing execution totals.
task.spawn(function()
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
end)

return result
