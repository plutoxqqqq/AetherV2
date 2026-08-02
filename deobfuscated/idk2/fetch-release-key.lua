--!nocheck
-- Fetch the release key that opens the sealed payload in ../../idk2.
--
-- Run this in your executor, in a BedWars place, with your own licence key. It
-- makes exactly the same request the protected loader makes, then prints the
-- 64-hex releaseKey from the response instead of using it to decrypt.
--
-- Run it yourself rather than handing the licence key to anyone else: the auth
-- endpoint sees X-HWID, and these systems commonly bind a key to the first
-- device that presents it. The loader's own failure list includes
-- `hwid_mismatch`, `ambiguous_hwid` and `uid_requires_bound_device`, so
-- authenticating from someone else's machine can lock you out of your own key.
--
-- The release key is per-release. If `releaseId` below stops matching the one
-- in idk2, the server will refuse: re-read it out of the current file.

local LICENCE_KEY = 'PUT-YOUR-KEY-HERE'
local RELEASE_ID = '4264b175447dc2361b9419bb51c47181'

local httpService = game:GetService('HttpService')

-- Preflight. A generic AUTH_FAILED from the server tells you nothing about which
-- half of the request it disliked, so check the client half here first.
LICENCE_KEY = tostring(LICENCE_KEY):match('^%s*(.-)%s*$')
if LICENCE_KEY == 'PUT-YOUR-KEY-HERE' or LICENCE_KEY == '' then
	error('[-] LICENCE_KEY is still the placeholder -- edit it before running.', 0)
end
if #LICENCE_KEY < 1 or #LICENCE_KEY > 128 then
	error('[-] LICENCE_KEY length ' .. #LICENCE_KEY .. ' is outside the 1..128 the loader accepts.', 0)
end
if not LICENCE_KEY:match('^BV%-%u%-%w+$') then
	warn('[!] Key does not look like BV-<letter>-<alphanumerics>. Check for a stray')
	warn('[!] space, a smart dash, or a truncated copy/paste.')
end

local requestFunction = request
	or http_request
	or (syn and syn.request)
	or (fluxus and fluxus.request)
	or (krnl and krnl.request)
assert(requestFunction, 'no request function -- unsupported executor')

local placeId = tostring(game.PlaceId)
if placeId ~= '6872274481' and placeId ~= '8444591321' and placeId ~= '8560631822' then
	warn('[!] PlaceId ' .. placeId .. ' is not one of the three the loader accepts.')
	warn('[!] The server validates placeId against the request, so join BedWars first.')
end

local headers = {
	['Accept'] = 'application/json',
	['Content-Type'] = 'application/json'
}

local hwidOk, hwid = pcall(function()
	return (gethwid and gethwid())
		or (get_hwid and get_hwid())
		or (syn and syn.gethwid and syn.gethwid())
		or game:GetService('RbxAnalyticsService'):GetClientId()
end)
if hwidOk and type(hwid) == 'string' then headers['X-HWID'] = hwid end

local executorOk, executor = pcall(function()
	return (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname())
end)
if executorOk and type(executor) == 'string' then headers['X-Executor'] = executor end

local nonce = httpService:GenerateGUID(false)

-- Echo the request context, with the key masked, so a denial can be attributed.
print('[i] placeId    = ' .. placeId)
print('[i] releaseId  = ' .. RELEASE_ID)
print('[i] key        = ' .. LICENCE_KEY:sub(1, 5) .. string.rep('*', math.max(0, #LICENCE_KEY - 5))
	.. '  (' .. #LICENCE_KEY .. ' chars)')
print('[i] X-HWID     = ' .. (headers['X-HWID'] and 'present (' .. #headers['X-HWID'] .. ' chars)' or 'ABSENT'))
print('[i] X-Executor = ' .. (headers['X-Executor'] or 'ABSENT'))

local response = requestFunction({
	Url = 'https://luvit.cc/badvape-api/v1/auth/verify',
	Method = 'POST',
	Headers = headers,
	Body = httpService:JSONEncode({
		protocolVersion = 4,
		key = LICENCE_KEY,
		nonce = nonce,
		placeId = placeId,
		releaseId = RELEASE_ID
	})
})

local body = response.Body or response.body
local decodeOk, decoded = pcall(function()
	return httpService:JSONDecode(body)
end)

if not decodeOk or type(decoded) ~= 'table' then
	warn('[-] Response was not JSON: ' .. tostring(body):sub(1, 400))
	return
end

if decoded.ok ~= true or type(decoded.releaseKey) ~= 'string' then
	warn('[-] Auth denied. code=' .. tostring(decoded.code)
		.. ' reason=' .. tostring(decoded.reason)
		.. ' correlationId=' .. tostring(decoded.correlationId))

	-- The reason field narrows this down; the loader only ever honours these.
	local reason = decoded.reason
	if reason == 'hwid_mismatch' or reason == 'uid_requires_bound_device' then
		warn('[-] The key is bound to a different device. Reset the binding with the vendor.')
	elseif reason == 'hwid_required' or reason == 'ambiguous_hwid' then
		warn('[-] The executor did not expose a usable HWID. Try a different executor.')
	elseif reason == 'rate_limited' then
		warn('[-] Too many attempts. Wait before retrying.')
	elseif reason == 'script_outdated' then
		warn('[-] releaseId ' .. RELEASE_ID .. ' is stale. Re-read it from a current idk2.')
	else
		warn('[-] Generic denial: the server did not accept this key for this place.')
		warn('[-] That means the key is invalid, expired, revoked, or not entitled to')
		warn('[-] this release -- not a bug in this script. Quote the correlationId')
		warn('[-] above to the vendor if the key is yours and you believe it is valid.')
	end
	return
end

-- Sanity-check the binding the loader also checks, so a mismatched key is
-- caught here rather than as an opaque tag failure inside unseal.py.
if decoded.nonce ~= nonce or decoded.placeId ~= placeId or decoded.releaseId ~= RELEASE_ID then
	warn('[-] Response is not bound to this request -- refusing to trust it.')
	return
end

print('releaseKey = ' .. decoded.releaseKey)
if setclipboard then
	pcall(setclipboard, decoded.releaseKey)
	print('(copied to clipboard)')
end
print('Now run:  python3 deobfuscated/idk2/unseal.py --release-key <that value>')
