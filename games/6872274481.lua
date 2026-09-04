-- AetherV2 BedWars compatibility entrypoint.
--
-- This used to request the Git tree and then download every category module
-- individually during injection. That puts 100+ serial network round trips on
-- the critical path and is why BedWars felt stuck on "Loading module for this game".
-- The generated bundle (tools/build-bedwars-bundle.py) keeps the same shared
-- lexical scope and registration order, but is one cached file.
local BUNDLE_PATH = 'aetherv2/games/6872274481/bundle.lua'

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
		if ok and type(result) == 'string' and result ~= '' then
			pcall(function()
				if type(writefile) == 'function' then writefile(BUNDLE_PATH, result) end
			end)
			return result
		end
	end
	local commit = 'main'
	pcall(function()
		local saved = readfile('aetherv2/profiles/commit.txt')
		if type(saved) == 'string' and saved ~= '' then commit = saved end
	end)
	local body = game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/games/6872274481/bundle.lua', true)
	pcall(function()
		if type(writefile) == 'function' and type(body) == 'string' and body ~= '' then
			writefile(BUNDLE_PATH, body)
		end
	end)
	return body
end

local source = fetchBundle()
local chunk, err = loadstring(source, 'games/6872274481/bundle.lua')
if not chunk then error('[AetherV2] BedWars loader: '..tostring(err), 0) end
return chunk(...)
