-- AetherV2 universal compatibility entrypoint. Source lives in games/universal/.
local function fetchBundle()
	local path = 'aetherv2/games/universal/bundle.lua'
	if type(shared.AetherV2FetchSource) == 'function' then
		local ok, result = pcall(shared.AetherV2FetchSource, path)
		if ok and type(result) == 'string' and result ~= '' then return result end
	end
	local commit = 'main'
	pcall(function()
		local saved = readfile('aetherv2/profiles/commit.txt')
		if type(saved) == 'string' and saved ~= '' then commit = saved end
	end)
	return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/games/universal/bundle.lua', true)
end
local source = fetchBundle()
local chunk, err = loadstring(source, 'games/universal/bundle.lua')
if not chunk then error(err) end
return chunk(...)
