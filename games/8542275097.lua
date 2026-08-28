local license = ... or {}
local vape = shared.vape
local targetPlace = 8768229691
local path = 'aetherv2/games/'..targetPlace..'.lua'
local watermark = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'

if vape then vape.Place = targetPlace end

local source
if isfile(path) then
	source = readfile(path)
else
	local fetch = shared.AetherV2FetchSource
	if type(fetch) ~= 'function' then error('[AetherV2] Private source fetcher is unavailable for child-place forwarding', 0) end
	local ok, result = pcall(fetch, path, 3)
	if not ok or type(result) ~= 'string' or result == '' then error('[AetherV2] Failed to load canonical game '..targetPlace..': '..tostring(result), 0) end
	source = result
	pcall(writefile, path, watermark..result)
end
local chunk, compileError = loadstring(source, tostring(targetPlace))
if not chunk then error('[AetherV2] Canonical game '..targetPlace..' failed to compile: '..tostring(compileError), 0) end
return chunk(license)
