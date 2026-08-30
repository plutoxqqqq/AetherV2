-- AetherV2 BedWars compatibility entrypoint. The maintainable source is games/6872274481/.
local license = ... or {}
if type(license) ~= 'table' then license = {} end

local function fetchBundle()
	local path = 'aetherv2/games/6872274481/bundle.lua'
	if type(shared.AetherV2FetchSource) == 'function' then
		local ok, result = pcall(shared.AetherV2FetchSource, path)
		if ok and type(result) == 'string' and result ~= '' then return result end
	end
	local commit = 'main'
	pcall(function()
		local saved = readfile('aetherv2/profiles/commit.txt')
		if type(saved) == 'string' and saved ~= '' then commit = saved end
	end)
	return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/games/6872274481/bundle.lua', true)
end

local source = fetchBundle()
local chunk, err = loadstring(source, 'games/6872274481/bundle.lua')
if not chunk then error(err) end
return chunk(license)
