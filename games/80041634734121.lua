local license = ... or {}
local vape = shared.vape
local targetPlace = 77790193039862
local path = 'aetherv2/games/'..targetPlace..'.lua'
local watermark = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'

local function sourceHasCode(source)
	if type(source) ~= 'string' then return false end
	if source:sub(1, #watermark) == watermark then
		source = source:sub(#watermark + 1)
	end
	source = source:gsub('^\239\187\191', '')
	while true do
		local before = source
		source = source:gsub('^%s*%-%-%[(=*)%[.-%]%1%]', '')
		source = source:gsub('^%s*%-%-[^\r\n]*', '')
		if source == before then break end
	end
	return source:match('%S') ~= nil
end

local function compileCanonical(source)
	if not sourceHasCode(source) then
		return nil, 'cached canonical game module contains no executable code'
	end
	return loadstring(source, tostring(targetPlace))
end

if vape then vape.Place = targetPlace end
if type(shared.AetherGameLoadTrace) == 'table' then
	shared.AetherGameLoadTrace.CanonicalPlace = targetPlace
end

local source = isfile(path) and readfile(path) or nil
local chunk, compileError = compileCanonical(source)
if not chunk then
	local fetch = shared.AetherV2FetchSource
	if type(fetch) ~= 'function' then
		error('[AetherV2] Private source fetcher is unavailable for child-place forwarding', 0)
	end

	local lastError = compileError
	for attempt = 1, 3 do
		local ok, result = pcall(fetch, path)
		if ok then
			local fetchedChunk, fetchedError = compileCanonical(result)
			if fetchedChunk then
				source, chunk, compileError = result, fetchedChunk, nil
				pcall(writefile, path, watermark..result)
				break
			end
			lastError = fetchedError
		else
			lastError = result
		end
		if attempt < 3 then task.wait(attempt) end
	end
	if not chunk then
		error('[AetherV2] Failed to load canonical game '..targetPlace..': '..tostring(lastError), 0)
	end
end

return chunk(license)
