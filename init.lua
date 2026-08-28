local license = ... or {}
local globalenv = (getgenv and getgenv()) or _G
repeat task.wait() until game:IsLoaded()

-- Private-source bootstrap.
-- AetherV2 is private: client code must never fall back to raw.githubusercontent.com or the
-- GitHub API. The authenticated source service is the only repository transport.
local HttpService = game:GetService('HttpService')
local StarterGui = game:GetService('StarterGui')
local watermark = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'

local isfile = isfile or function(path)
	local ok, value = pcall(readfile, path)
	return ok and type(value) == 'string' and value ~= ''
end

local trace = {}
shared.AetherLoadTrace = trace
local function traceStage(stage, detail)
	local line = tostring(stage)..(detail ~= nil and (' | '..tostring(detail)) or '')
	table.insert(trace, line)
	if isfolder and isfolder('aetherv2/profiles') then
		pcall(writefile, 'aetherv2/profiles/load-trace.txt', table.concat(trace, '\n'))
	end
end

local function failLoad(message)
	traceStage('FAILED', message)
	warn('[AetherV2] Load failed: '..tostring(message))
	pcall(function()
		StarterGui:SetCore('SendNotification', {
			Title = 'AetherV2 failed to load',
			Text = tostring(message):sub(1, 180),
			Duration = 12
		})
	end)
	error(message, 0)
end

local function normalizeEndpoint(value)
	if type(value) ~= 'string' then return nil end
	value = value:gsub('%s+', '')
	while value:sub(-1) == '/' do value = value:sub(1, -2) end
	return value ~= '' and value or nil
end

local function encode(value)
	return tostring(value):gsub('([^%w%-%._~])', function(character)
		return string.format('%%%02X', string.byte(character))
	end)
end

local sourceEndpoint = normalizeEndpoint(type(license) == 'table' and license.SourceEndpoint)
local sourceToken = type(license) == 'table' and license.SourceToken or nil
local sourceRef = type(license) == 'table' and license.SourceRef or nil

if getgenv then
	pcall(function()
		sourceEndpoint = sourceEndpoint or normalizeEndpoint(getgenv().AetherV2SourceEndpoint)
		sourceToken = sourceToken or getgenv().AetherV2SourceToken
		sourceRef = sourceRef or getgenv().AetherV2SourceRef
	end)
end
sourceEndpoint = sourceEndpoint or normalizeEndpoint(shared.AetherV2SourceEndpoint)
sourceToken = sourceToken or shared.AetherV2SourceToken
sourceRef = sourceRef or shared.AetherV2SourceRef

if not sourceEndpoint then failLoad('Private source endpoint is missing') end
if type(sourceToken) ~= 'string' or sourceToken == '' then failLoad('Private source session token is missing') end
if type(sourceRef) ~= 'string' or sourceRef == '' then failLoad('Private source ref is missing') end

shared.AetherV2SourceEndpoint = sourceEndpoint
shared.AetherV2SourceToken = sourceToken
shared.AetherV2SourceRef = sourceRef
shared.AetherResolvedCommit = nil
traceStage('source', 'private proxy / '..sourceRef)
traceStage('place', game.PlaceId)

for _, folder in {
	'aetherv2',
	'aetherv2/games',
	'aetherv2/profiles',
	'aetherv2/assets',
	'aetherv2/assets/new',
	'aetherv2/libraries',
	'aetherv2/guis',
	'aetherv2/configs',
	'aetherv2/songs',
	'aetherv2/songs/spotify'
} do
	if not isfolder(folder) then makefolder(folder) end
end

local function requestUrl(route, path, ref)
	local url = sourceEndpoint..'/'..route..'?ref='..encode(ref or sourceRef)..'&session='..encode(sourceToken)
	if path then url = url..'&path='..encode(path) end
	return url
end

local function getText(route, path, ref, attempts)
	attempts = attempts or 3
	local lastError = 'unknown error'
	local url = requestUrl(route, path, ref)
	for attempt = 1, attempts do
		local ok, body = pcall(function()
			return game:HttpGet(url, true)
		end)
		if ok and type(body) == 'string' and body ~= '' then
			return body
		end
		lastError = ok and 'empty response' or tostring(body)
		if attempt < attempts then task.wait(math.min(attempt, 2)) end
	end
	return nil, lastError
end

local function getJson(route, ref, attempts)
	local body, problem = getText(route, nil, ref, attempts)
	if not body then return nil, problem end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, body)
	if not ok then return nil, 'invalid JSON response' end
	return decoded
end

local function validCommit(value)
	return type(value) == 'string' and value:match('^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

local function resolveLiveCommit()
	local body, problem = getText('commit', nil, sourceRef, 3)
	if not body then failLoad('Could not resolve private source commit - '..tostring(problem)) end
	local commit = body:match('^%s*(%x+)')
	if not validCommit(commit) then failLoad('Private source returned an invalid commit') end
	return commit
end

local function resolveTargetCommit()
	local pinPath = 'aetherv2/profiles/version-pin.txt'
	local pin = isfile(pinPath) and readfile(pinPath):gsub('%s+', '') or nil
	if pin and not validCommit(pin) then
		pcall(delfile, pinPath)
		pin = nil
	end
	if not pin then return resolveLiveCommit() end

	-- /history both verifies the ten-version downgrade window and approves those immutable SHAs for
	-- this source session. A stale/out-of-window pin is discarded instead of breaking startup.
	local history, problem = getJson('history', sourceRef, 2)
	if history and type(history.versions) == 'table' then
		for _, version in ipairs(history.versions) do
			if type(version) == 'table' and version.sha == pin then
				traceStage('version pin', pin:sub(1, 10))
				return pin
			end
		end
	end
	pcall(delfile, pinPath)
	traceStage('version pin cleared', problem or 'not in history')
	return resolveLiveCommit()
end

local commit = resolveTargetCommit()
traceStage('commit', commit:sub(1, 12))

local treeBody, treeProblem = getText('tree', nil, commit, 3)
if not treeBody then failLoad('Could not read private source manifest - '..tostring(treeProblem)) end
local treeOk, treeData = pcall(HttpService.JSONDecode, HttpService, treeBody)
if not treeOk or type(treeData) ~= 'table' or type(treeData.tree) ~= 'table' or treeData.truncated then
	failLoad('Private source manifest is invalid or incomplete')
end

local manifest = {}
local manifestLines = {}
for _, entry in ipairs(treeData.tree) do
	if type(entry) == 'table' and entry.type == 'blob' and type(entry.path) == 'string' and type(entry.sha) == 'string' then
		manifest[entry.path] = entry.sha
		table.insert(manifestLines, entry.sha..' '..entry.path)
	end
end
if not manifest['main.lua'] or not manifest['games/universal.lua'] then
	failLoad('Private source manifest is missing core AetherV2 files')
end
shared.AetherSourceManifest = manifest
traceStage('manifest', tostring(#manifestLines)..' files')

local function sourceBody(path, attempts)
	if not manifest[path] then return nil, 'not present in authenticated manifest' end
	local body, problem = getText('source', path, commit, attempts or 3)
	if not body then return nil, problem end
	if #body < 8 then return nil, 'empty source response' end
	if path:sub(-4) == '.lua' then
		local chunk, compileError = loadstring(body, path)
		if not chunk then return nil, 'compile failed: '..tostring(compileError) end
	end
	return body
end

shared.AetherV2FetchSource = function(path, attempts)
	path = tostring(path):gsub('^aetherv2/', '')
	local body, problem = sourceBody(path, attempts)
	if not body then error('Could not download '..path..' - '..tostring(problem), 0) end
	return body
end

local function ensureParent(path)
	local parent = path:gsub('\\', '/'):match('^(.*)/[^/]+$')
	if not parent then return end
	local built = ''
	for segment in parent:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if not isfolder(built) then pcall(makefolder, built) end
	end
end

local function store(path, body)
	ensureParent(path)
	if path:sub(-4) == '.lua' then body = watermark..body end
	writefile(path, body)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, child in ipairs(listfiles(path)) do
		if isfile(child) then
			pcall(delfile, child)
		elseif isfolder(child) then
			wipeFolder(child)
		end
	end
end

local oldCommit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt'):gsub('%s+', '') or ''
local modulePlace = tostring(game.PlaceId)
local gameRepoPath = 'games/'..modulePlace..'.lua'
local gameExists = manifest[gameRepoPath] ~= nil
traceStage('exact game manifest', gameRepoPath..' = '..tostring(gameExists))

-- Stage all startup-critical code in memory BEFORE touching the current install. This makes updates
-- transactional enough for the loader: a network failure cannot leave commit.txt pointing at a
-- half-downloaded build.
local required = {
	'main.lua',
	'games/universal.lua',
	'version.txt'
}
if gameExists then table.insert(required, gameRepoPath) end

local gui = isfile('aetherv2/profiles/gui.txt') and readfile('aetherv2/profiles/gui.txt'):gsub('%s+', '') or 'new'
if gui == 'newer' then gui = 'new' end
if gui ~= 'new' and gui ~= 'old' and gui ~= 'rise' then gui = 'new' end
local guiPath = 'guis/'..gui..'.lua'
if manifest[guiPath] then table.insert(required, guiPath) end
if gui == 'new' and manifest['guis/new.core.lua'] then table.insert(required, 'guis/new.core.lua') end
if manifest['profiles/features.json'] then table.insert(required, 'profiles/features.json') end

local staged = {}
for _, path in ipairs(required) do
	local body, problem = sourceBody(path, 3)
	if not body then failLoad('Could not stage '..path..' - '..tostring(problem)) end
	staged[path] = body
	traceStage('staged', path..' ('..#body..' bytes)')
end

if oldCommit ~= '' and oldCommit ~= commit then
	traceStage('cache reset', oldCommit:sub(1, 12)..' -> '..commit:sub(1, 12))
	-- Only repository-managed caches are reset. User profiles, configs and songs are preserved.
	wipeFolder('aetherv2/games')
	wipeFolder('aetherv2/guis')
	wipeFolder('aetherv2/libraries')
	wipeFolder('aetherv2/assets')
	pcall(delfile, 'aetherv2/main.lua')
	pcall(delfile, 'aetherv2/version.txt')
end

-- Even when the commit did not change, replace the exact game/core files from this authenticated
-- session. This heals interrupted/stale caches that previously survived forever because they still
-- compiled successfully.
for path, body in pairs(staged) do
	store('aetherv2/'..path, body)
end

if not gameExists and isfile('aetherv2/'..gameRepoPath) then
	-- Never let a stale file from an older commit make an unsupported exact PlaceId look supported.
	pcall(delfile, 'aetherv2/'..gameRepoPath)
end

table.sort(manifestLines)
writefile('aetherv2/profiles/files.txt', table.concat(manifestLines, '\n'))
writefile('aetherv2/profiles/commit.txt', commit)
traceStage('cache committed', commit:sub(1, 12))

license.SourceEndpoint = sourceEndpoint
license.SourceToken = sourceToken
license.SourceRef = sourceRef
license.Commit = commit

local mainChunk, mainError = loadstring(staged['main.lua'], 'main.lua')
if not mainChunk then failLoad('main.lua did not compile - '..tostring(mainError)) end
traceStage('main', 'starting')
return mainChunk(license)
