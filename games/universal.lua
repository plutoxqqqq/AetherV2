-- AetherV2 universal compatibility entrypoint.
--
-- Universal used to request the Git tree and then download every module individually during
-- injection.  That puts dozens of serial network round trips on the critical path.  The generated
-- bundle retains the same shared lexical scope and registration order, but requires one cached file.
local BUNDLE_PATH = 'aetherv2/games/universal/bundle.lua'

local function cachedBundle()
	if type(isfile) ~= 'function' or not isfile(BUNDLE_PATH) then return nil end
	local ok, source = pcall(readfile, BUNDLE_PATH)
	if ok and type(source) == 'string' and #source > 8 then return source end
	return nil
end

local function fetchBundle()
	local cached = cachedBundle()
	if cached then return cached end
	if type(shared.AetherV2FetchSource) == 'function' then
		local ok, result = pcall(shared.AetherV2FetchSource, BUNDLE_PATH)
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
if not chunk then error('[AetherV2] Universal loader: '..tostring(err), 0) end
return chunk(...)
