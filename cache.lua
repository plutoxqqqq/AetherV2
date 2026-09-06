-- Runtime cache. Skip work when aetherv2/profiles/commit.txt matches GitHub HEAD.
-- On a new commit, only existing runtime files with a different blob SHA are
-- re-downloaded in parallel from a commit-pinned raw URL (avoids stale /main/).

local function exists(path)
	local ok, data = pcall(readfile, path)
	return ok and type(data) == 'string' and data ~= ''
end

local revisionPath = 'aetherv2/profiles/file-revisions.json'
local commitPath = 'aetherv2/profiles/commit.txt'
local httpService = game:GetService('HttpService')
local revisions = {}
local remoteFiles = {}
local checkedFiles = {}
local sourceCommit = 'main'

local function loadRevisions()
	if not exists(revisionPath) then return end
	local ok, decoded = pcall(function()
		return httpService:JSONDecode(readfile(revisionPath))
	end)
	if ok and type(decoded) == 'table' then
		revisions = decoded
	end
end

local function saveRevisions()
	pcall(function()
		writefile(revisionPath, httpService:JSONEncode(revisions))
	end)
end

local function cachePath(relative)
	return 'aetherv2/'..relative
end

local function isRuntimePath(relative)
	if relative == 'init.lua' or relative == 'main.lua' or relative == 'cache.lua' or relative == 'version.txt' then
		return true
	end
	local prefix = relative:match('^([^/]+)/')
	return prefix == 'games' or prefix == 'guis' or prefix == 'libraries' or prefix == 'assets'
end

local function validDownloadedFile(path, body)
	if type(body) ~= 'string' or #body < 1 then return false end
	local head = body:sub(1, 300):lower()
	if head:find('^%s*404') or head:find('^%s*429') or head:find('^%s*5%d%d:') or head:find('<!doctype html') or head:find('<html') then
		return false
	end
	if path:lower():sub(-4) == '.png' then
		return body:sub(1, 8) == '\137PNG\r\n\26\n'
	end
	return true
end

local function ensureFolder(path)
	local parent = path:gsub('\\', '/'):match('^(.*)/[^/]+$')
	if not parent then return end
	local built = ''
	for segment in parent:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if not isfolder(built) then
			pcall(makefolder, built)
		end
	end
end

local function fetchJson(url)
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if not ok or type(body) ~= 'string' then
		return nil
	end
	local decodedOk, decoded = pcall(function()
		return httpService:JSONDecode(body)
	end)
	if decodedOk and type(decoded) == 'table' then
		return decoded
	end
	return nil
end

local function resolveCommit()
	local data = fetchJson('https://api.github.com/repos/plutoxqqqq/AetherV2/commits/main?per_page=1')
	local sha = data and type(data.sha) == 'string' and data.sha or nil
	if type(sha) == 'string' and #sha >= 7 then
		return sha
	end
	return nil
end

local function fetchTree(ref)
	local decoded = fetchJson('https://api.github.com/repos/plutoxqqqq/AetherV2/git/trees/'..ref..'?recursive=1')
	if not decoded or type(decoded.tree) ~= 'table' then
		return false, 'GitHub tree response was invalid'
	end
	for _, entry in ipairs(decoded.tree) do
		if type(entry) == 'table' and entry.type == 'blob' and type(entry.path) == 'string' and type(entry.sha) == 'string' then
			remoteFiles[entry.path] = entry.sha
		end
	end
	return true
end

local function rawUrl(relative, ref)
	return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..(ref or sourceCommit)..'/'..relative
end

local function downloadCurrent(relative, expectedSha, ref)
	local path = cachePath(relative)
	local ok, body = pcall(function()
		return game:HttpGet(rawUrl(relative, ref), true)
	end)
	if not ok or not validDownloadedFile(relative, body) then
		warn('[AetherV2] Failed to update '..relative)
		return false
	end
	if relative:sub(-4) == '.lua' then
		body = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..body
	end
	ensureFolder(path)
	local wrote = pcall(writefile, path, body)
	if not wrote then
		warn('[AetherV2] Failed to write '..path)
		return false
	end
	revisions[relative] = expectedSha
	checkedFiles[relative] = true
	return true
end

local function downloadParallel(jobs, ref)
	if #jobs == 0 then return end
	local finished = Instance.new('BindableEvent')
	local index = 1
	local workers = math.min(8, #jobs)
	local running = workers
	local function worker()
		while index <= #jobs do
			local job = jobs[index]
			index += 1
			downloadCurrent(job.path, job.sha, ref)
		end
		running -= 1
		if running == 0 then
			finished:Fire()
		end
	end
	for _ = 1, workers do
		task.spawn(worker)
	end
	finished.Event:Wait()
	finished:Destroy()
end

loadRevisions()
local latest = resolveCommit()
local cached = exists(commitPath) and readfile(commitPath):gsub('%s+', '') or ''
if latest then
	sourceCommit = latest
	shared.AetherV2PublicRef = latest
end

if not (latest and cached == latest) then
	local ok, err = fetchTree(sourceCommit)
	if ok then
		local jobs = {}
		for relative, remoteSha in pairs(remoteFiles) do
			if isRuntimePath(relative) then
				local path = cachePath(relative)
				if isfile(path) then
					if revisions[relative] == remoteSha and cached ~= '' then
						checkedFiles[relative] = true
					else
						table.insert(jobs, {path = relative, sha = remoteSha})
					end
				end
			end
		end
		downloadParallel(jobs, sourceCommit)
		if latest then
			pcall(writefile, commitPath, latest)
		end
	else
		warn('[AetherV2] File revision check skipped: '..tostring(err))
	end
end

shared.AetherV2PublicRef = sourceCommit
shared.AetherV2FetchSourceUrl = function(path)
	return rawUrl(tostring(path):gsub('^aetherv2/', ''), sourceCommit)
end
shared.AetherV2RawUrl = rawUrl
shared.AetherV2RemoteFiles = remoteFiles
shared.AetherV2Revisions = revisions
shared.AetherV2CheckedFiles = checkedFiles

if next(checkedFiles) then
	for relative in pairs(checkedFiles) do
		local remoteSha = remoteFiles[relative]
		if remoteSha then
			revisions[relative] = remoteSha
		end
	end
	saveRevisions()
end
