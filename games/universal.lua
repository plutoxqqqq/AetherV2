-- AetherV2 universal compatibility entrypoint.
-- The core lives in games/universal/main.lua; every .lua module under a category folder is
-- discovered from the repository tree and concatenated in memory before execution. This keeps
-- the lexical scope shared with main.lua while removing the generated bundle as a module registry.

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
	return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/' .. commit .. '/' .. path:gsub('^aetherv2/', ''), true)
end

local function fail(message)
	error('[AetherV2] Universal loader: ' .. message, 0)
end

-- main.lua contains the shared lexical environment followed by legacy in-file module sections.
-- Only keep the shared core here; the real module files are the source of truth.
local mainSource = fetch('aetherv2/games/universal/main.lua')
local marker = mainSource:find('%-%-%[%[AETHER_UNIVERSAL_MODULE:')
local core = marker and mainSource:sub(1, marker - 1) or mainSource

local treeSource = game:HttpGet('https://api.github.com/repos/plutoxqqqq/AetherV2/git/trees/' .. commit .. '?recursive=1', true)
local ok, tree = pcall(function()
	return httpService:JSONDecode(treeSource)
end)
if not ok or type(tree) ~= 'table' or type(tree.tree) ~= 'table' then
	fail('could not read the repository module tree')
end

local files = {}
for _, entry in ipairs(tree.tree) do
	local path = entry.path
	if entry.type == 'blob' and type(path) == 'string'
		and path:match('^games/universal/[^/]+/.+%.lua$')
		and not path:match('/bundle%.lua$') then
		table.insert(files, path)
	end
end

if #files == 0 then fail('no universal .lua modules were discovered') end

table.sort(files)

-- Preserve the established main.lua registration order where possible, then append newly
-- created/moved files that have no legacy marker. This avoids breaking existing dependencies while
-- still making new files and moved files load automatically.
local byPath = {}
for _, path in ipairs(files) do byPath[path] = true end
local ordered = {}
local seen = {}
for path in mainSource:gmatch('%-%-%[%[AETHER_UNIVERSAL_MODULE:([^%]]+)%]%]') do
	if byPath[path] and not seen[path] then
		seen[path] = true
		table.insert(ordered, path)
	end
end
for _, path in ipairs(files) do
	if not seen[path] then
		table.insert(ordered, path)
	end
end

local chunks = {core}
local loaded = 0
for _, path in ipairs(ordered) do
	local source = fetch('aetherv2/' .. path)
	if type(source) ~= 'string' or source == '' then
		fail('failed to fetch module: ' .. path)
	end
	table.insert(chunks, '\n-- AETHER_DYNAMIC_MODULE:' .. path .. '\n' .. source)
	loaded += 1
end

if loaded ~= #files then
	fail(('module discovery mismatch: discovered %d, prepared %d'):format(#files, loaded))
end

local source = table.concat(chunks, '\n')
local chunk, err = loadstring(source, 'games/universal/dynamic-bundle.lua')
if not chunk then fail(err) end
local result = chunk(...)
warn(('[AetherV2] Universal loader prepared %d/%d Lua modules'):format(loaded, #files))
return result