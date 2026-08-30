local license = ... or {}

local function currentRef()
	if type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') ~= '' then
		return shared.AetherV2PublicRef:gsub('%s+', '')
	end
	local ok, ref = pcall(readfile, 'aetherv2/profiles/commit.txt')
	if ok and type(ref) == 'string' and ref:gsub('%s+', '') ~= '' then return ref:gsub('%s+', '') end
	return 'main'
end

local function fetchCore()
	local refs = {currentRef()}
	if refs[1] ~= 'main' then table.insert(refs, 'main') end
	for _, ref in refs do
		local source
		if type(shared.AetherV2FetchSource) == 'function' then
			local ok, result = pcall(shared.AetherV2FetchSource, 'main-core.lua', ref)
			if ok then source = result end
		end
		if type(source) ~= 'string' or #source < 100 then
			local ok, result = pcall(game.HttpGet, game, 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/main-core.lua', true)
			if ok then source = result end
		end
		if type(source) == 'string' and #source > 100 and source ~= '404: Not Found' then return source end
	end
	error('AetherV2: could not load main-core.lua', 0)
end

local source = fetchCore()
local marker = [=[
				local ran, result = xpcall(function()
					return chunk(vape, license, context)
				end, debug.traceback)
]=]
local replacement = [=[
				local premiumModuleSnapshot = {}
				for name, loadedModule in pairs(vape.Modules or {}) do premiumModuleSnapshot[name] = loadedModule end
				local ran, result = xpcall(function()
					return chunk(vape, license, context)
				end, debug.traceback)
]=]
local first, last = source:find(marker, 1, true)
if first and not source:find(marker, last + 1, true) then
	source = source:sub(1, first - 1)..replacement..source:sub(last + 1)
else
	warn('[AetherV2] Premium tag patch: module execution marker was not uniquely found')
end

local afterMarker = [=[
				if not ran then warn('[AetherV2] Premium module '..module.Path..' failed: '..tostring(result)) end
]=]
local afterReplacement = [=[
				if ran then
					for name, loadedModule in pairs(vape.Modules or {}) do
						if premiumModuleSnapshot[name] ~= loadedModule and type(loadedModule) == 'table' then
							loadedModule.Premium = true
							loadedModule.Tag = 'PREMIUM'
						end
					end
				end
				if not ran then warn('[AetherV2] Premium module '..module.Path..' failed: '..tostring(result)) end
]=]
first, last = source:find(afterMarker, 1, true)
if first and not source:find(afterMarker, last + 1, true) then
	source = source:sub(1, first - 1)..afterReplacement..source:sub(last + 1)
else
	warn('[AetherV2] Premium tag patch: post-execution marker was not uniquely found')
end

local chunk, compileError = loadstring(source, 'main-core.lua')
if not chunk then error('AetherV2: transformed main-core.lua did not compile: '..tostring(compileError), 0) end
return chunk(license)
