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

local function patchExact(name, marker, replacement)
	local first, last = source:find(marker, 1, true)
	if first and not source:find(marker, last + 1, true) then
		source = source:sub(1, first - 1)..replacement..source:sub(last + 1)
		return true
	end
	warn('[AetherV2] '..name..' patch skipped: marker was not unique')
	return false
end

-- Executor filesystems can report a successful write before the file is readable on the
-- following instruction. Retry the write/read/validation cycle instead of killing the whole
-- loader with a false "unreadable cache" error.
patchExact('cache write/read retry', [=[local function storePublicFile(path, body)
	ensureParentFolder(path)
	if path:sub(-4) == '.lua' then body = watermark..body end
	local ok, err = pcall(writefile, path, body)
	if not ok then return false, err end
	local readOk, cached = pcall(readfile, path)
	local problem = readOk and payloadProblem(path, cached) or 'unreadable cache'
	return problem == nil, problem
end]=], [=[local function storePublicFile(path, body)
	ensureParentFolder(path)
	if path:sub(-4) == '.lua' then body = watermark..body end
	local lastProblem = 'unreadable cache'
	for attempt = 1, 4 do
		local ok, err = pcall(writefile, path, body)
		if ok then
			-- Give executor-backed filesystems a moment to publish the new file before reading it.
			task.wait(0.04 * attempt)
			local readOk, cached = pcall(readfile, path)
			if readOk and type(cached) == 'string' then
				local problem = payloadProblem(path, cached)
				if problem == nil then return true, nil end
				lastProblem = problem
			else
				lastProblem = 'unreadable cache'
			end
		else
			lastProblem = err or 'write failed'
		end
		if attempt < 4 then task.wait(0.04 * attempt) end
	end
	return false, lastProblem
end]=])

-- Keep premium ownership entirely in runtime metadata. Module objects remain ordinary module
-- records; Liquid Glass reads the premium set from features.json plus this short-lived loader set.
shared.AetherV2PremiumModules = {}
patchExact('premium runtime metadata', [=[				local ran, result = xpcall(function()
					return chunk(vape, license, context)
				end, debug.traceback)
]=], [=[				local premiumModuleSnapshot = {}
				for name, loadedModule in pairs(vape.Modules or {}) do premiumModuleSnapshot[name] = loadedModule end
				local ran, result = xpcall(function()
					return chunk(vape, license, context)
				end, debug.traceback)
]=])

patchExact('premium runtime metadata capture', [=[				if not ran then warn('[AetherV2] Premium module '..module.Path..' failed: '..tostring(result)) end
]=], [=[				if ran then
					for name, loadedModule in pairs(vape.Modules or {}) do
						if premiumModuleSnapshot[name] ~= loadedModule then
							local normalized = tostring(name):lower():gsub('[%s_%-%./]+', '')
							shared.AetherV2PremiumModules[normalized] = true
						end
					end
				end
				if not ran then warn('[AetherV2] Premium module '..module.Path..' failed: '..tostring(result)) end
]=])

local chunk, compileError = loadstring(source, 'main-core.lua')
if not chunk then error('AetherV2: transformed main-core.lua did not compile: '..tostring(compileError), 0) end
return chunk(license)