-- AetherV2 BedWars compatibility entrypoint. The maintainable source is games/6872274481/.
local license = ... or {}
if type(license) ~= 'table' then license = {} end

local httpService = game:GetService('HttpService')
local function getCommit()
	local commit = 'main'
	pcall(function()
		local saved = readfile('aetherv2/profiles/commit.txt')
		if type(saved) == 'string' and saved ~= '' then commit = saved end
	end)
	return commit
end

local commit = getCommit()
local function fetch(path)
	if type(shared.AetherV2FetchSource) == 'function' then
		local ok, result = pcall(shared.AetherV2FetchSource, path)
		if ok and type(result) == 'string' and result ~= '' then return result end
	end
	return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/'..path:gsub('^aetherv2/', ''), true)
end

local function fail(message)
	error('[AetherV2] BedWars loader: '..message, 0)
end

local mainSource = fetch('aetherv2/games/6872274481/main.lua')
local marker = mainSource:find('%-%-%[%[AETHER_MODULES%]%]')
if not marker then
	fail('main.lua is missing the module insertion marker')
end
local core = mainSource:sub(1, marker - 1)
local suffix = mainSource:sub(marker + #('--[[AETHER_MODULES]]'))

local treeSource = game:HttpGet('https://api.github.com/repos/plutoxqqqq/AetherV2/git/trees/'..commit..'?recursive=1', true)
local ok, tree = pcall(function()
	return httpService:JSONDecode(treeSource)
end)
if not ok or type(tree) ~= 'table' or type(tree.tree) ~= 'table' then
	fail('could not read the repository module tree')
end
if tree.truncated then
	fail('repository module tree was truncated; refusing to start with an incomplete module list')
end

local files = {}
local base = 'games/6872274481/'
for _, entry in ipairs(tree.tree) do
	local path = entry.path
	if entry.type == 'blob' and type(path) == 'string'
		and path:sub(1, #base) == base
		and path:sub(-4) == '.lua' then
		local rel = path:sub(#base + 1)
		if rel ~= 'main.lua' and rel ~= 'bundle.lua' and rel:find('/', 1, true) then
			table.insert(files, path)
		end
	end
end

if #files == 0 then fail('no BedWars category modules were discovered') end
table.sort(files)

local chunks = {core}
local loaded = 0
for _, path in ipairs(files) do
	local source = fetch('aetherv2/'..path)
	if type(source) ~= 'string' or source == '' then
		fail('failed to fetch module: '..path)
	end
	table.insert(chunks, '\n-- AETHER_DYNAMIC_MODULE:'..path..'\n'..source)
	loaded += 1
end

-- Keep the shared main.lua setup after the module insertion point, if any, so the dynamic
-- modules remain in the same lexical chunk as the original source.
table.insert(chunks, suffix)

if loaded ~= #files then
	fail(('module discovery mismatch: discovered %d, prepared %d'):format(#files, loaded))
end

local source = table.concat(chunks, '\n')
local chunk, err = loadstring(source, 'games/6872274481/dynamic-bundle.lua')
if not chunk then fail(err) end
return chunk(license)
