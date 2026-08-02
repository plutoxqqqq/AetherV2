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
