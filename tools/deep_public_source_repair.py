from pathlib import Path
import re


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


# init.lua
path = Path('init.lua')
text = path.read_text()
text = text.replace("license.SourceEndpoint = nil\nlicense.SourceToken = nil\nlicense.SourceRef = nil\nshared.AetherV2SourceEndpoint = nil\nshared.AetherV2SourceToken = nil\nshared.AetherV2SourceRef = nil\n", "", 1)

marker = "local cloneref = cloneref or function(ref) return ref end\n"
text = replace_once(text, marker, marker + "\nlocal function safeLocalAsset(path)\n\tif type(getcustomasset) ~= 'function' then return '' end\n\tlocal ok, result = pcall(getcustomasset, path)\n\treturn ok and result or ''\nend\n", 'safe loading asset helper')
text = replace_once(text, "\tlogo.Image = isfile('aetherv2/assets/new/loading.png') and getcustomasset('aetherv2/assets/new/loading.png') or ''", "\tlogo.Image = isfile('aetherv2/assets/new/loading.png') and safeLocalAsset('aetherv2/assets/new/loading.png') or ''", 'safe loading logo')

old_repo = """local function repoUrl(path, ref)
	local selectedRef = ref or readfile('aetherv2/profiles/commit.txt')
	return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('aetherv2/', ''))
end"""
new_repo = """local function repoUrl(path, ref)
	local selectedRef = ref or shared.AetherV2PublicRef
	if type(selectedRef) ~= 'string' or selectedRef:gsub('%s+', '') == '' then
		local ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
		selectedRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or ''
	end
	if selectedRef == '' then selectedRef = 'main' end
	return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('^aetherv2/', ''))
end"""
text = replace_once(text, old_repo, new_repo, 'init repoUrl')

old_store = """local function storeFile(path, body)
	-- GitHub paths include nested folders (for example libraries/bedwars/controllers).
	-- Executors generally do not create missing
	-- parents for writefile, so create each parent segment before caching a file.
	local parent = path:gsub('\\\\', '/'):match('^(.*)/[^/]+$')
	if parent then
		local built = ''
		for segment in parent:gmatch('[^/]+') do
			built = built == '' and segment or built..'/'..segment
			if not isfolder(built) then
				pcall(makefolder, built)
			end
		end
	end
	if path:sub(-4) == '.lua' then
		body = watermark..body
	end
	writefile(path, body)
end"""
new_store = """local function ensureParentFolder(path)
	local parent = path:gsub('\\\\', '/'):match('^(.*)/[^/]+$')
	if not parent then return end
	local built = ''
	for segment in parent:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if not isfolder(built) then
			local ok, err = pcall(makefolder, built)
			if not ok and not isfolder(built) then error('Could not create '..built..': '..tostring(err), 0) end
		end
	end
end

local function storeFile(path, body)
	ensureParentFolder(path)
	if path:sub(-4) == '.lua' then body = watermark..body end
	local ok, err = pcall(writefile, path, body)
	if not ok then error('Could not write '..path..': '..tostring(err), 0) end
	local readOk, cached = pcall(readfile, path)
	if not readOk or payloadProblem(path, cached) then error('Cached file verification failed for '..path, 0) end
	return true
end"""
text = replace_once(text, old_store, new_store, 'verified storeFile')

old_folders = "for _, folder in {'aetherv2', 'aetherv2/games', 'aetherv2/profiles', 'aetherv2/assets', 'aetherv2/assets/new', 'aetherv2/libraries', 'aetherv2/guis', 'aetherv2/configs', 'aetherv2/songs', 'aetherv2/songs/spotify'} do"
new_folders = "for _, folder in {'aetherv2', 'aetherv2/games', 'aetherv2/profiles', 'aetherv2/assets', 'aetherv2/assets/new', 'aetherv2/assets/old', 'aetherv2/assets/rise', 'aetherv2/assets/wurst', 'aetherv2/libraries', 'aetherv2/guis', 'aetherv2/configs', 'aetherv2/songs', 'aetherv2/songs/spotify'} do"
text = replace_once(text, old_folders, new_folders, 'asset folders')
text = text.replace("\nif not isfile('aetherv2/profiles/releasechannel.txt') then\n\twritefile('aetherv2/profiles/releasechannel.txt', 'stable')\nend\n", "\n", 1)

start = text.index('local function selectedReleaseChannel()')
end = text.index('\n-- The list of files a commit contains', start)
resolver = r'''local function resolveCommit()
	local recent = shared.AetherResolvedCommit
	if type(recent) == 'table' and recent.Channel == 'main' and type(recent.Commit) == 'string'
		and os.clock() - (recent.CheckedAt or 0) < 60 then
		return recent.Commit
	end
	local sources = {
		{Url = 'https://api.github.com/repos/plutoxqqqq/AetherV2/commits/main', Pattern = '"sha"%s*:%s*"(%x+)'},
		{Url = 'https://github.com/plutoxqqqq/AetherV2/commits/main.atom', Pattern = 'Commit/(%x+)'},
		{Url = 'https://github.com/plutoxqqqq/AetherV2/tree/main', Pattern = 'currentOid[^%x]*(%x+)'}
	}
	for _, source in sources do
		local suc, body = pcall(game.HttpGet, game, source.Url, true)
		if suc and type(body) == 'string' then
			local found = body:match(source.Pattern)
			if found and #found >= 40 then
				found = found:sub(1, 40)
				shared.AetherResolvedCommit = {Commit = found, Channel = 'main', CheckedAt = os.clock()}
				return found
			end
		end
	end
	return 'main'
end
'''
text = text[:start] + resolver + text[end:]

block_start = text.index("if not shared.VapeDeveloper then\n\tlocal oldCommit = isfile('aetherv2/profiles/commit.txt')")
block_end = text.index('\n-- main.lua uses this authoritative tree', block_start)
old_block = text[block_start:block_end]
branch_marker = '\tif commit and commit ~= oldCommit then\n'
branch_start = old_block.index(branch_marker) + len(branch_marker)
branch_end = old_block.index("\n\telseif oldCommit == '' then", branch_start)
changed = old_block[branch_start:branch_end]
new_block = """if not shared.VapeDeveloper then
	local oldCommit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt'):gsub('%s+', '') or ''
	_G.AetherV2SetLoadingStatus('Checking for updates', 0.12)
	local commit = license.Commit or resolveCommit() or 'main'
	commit = tostring(commit):gsub('%s+', '')
	if commit == '' then commit = 'main' end
	shared.AetherV2PublicRef = commit

	if commit ~= oldCommit then
""" + changed + """
	else
		prefetchPaths = readFileList()
		if not prefetchPaths then
			prefetchPaths = fetchFileList(commit)
			if prefetchPaths then writeFileList(prefetchPaths) end
		end
	end
else
	local ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
	shared.AetherV2PublicRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or 'main'
	if shared.AetherV2PublicRef == '' then shared.AetherV2PublicRef = 'main' end
end
"""
text = text[:block_start] + new_block + text[block_end:]

asset_verifier = r'''
local function selectedAssetPath(path)
	if type(path) ~= 'string' or path:sub(1, 7) ~= 'assets/' then return false end
	local gui = selectedGui()
	return path:sub(1, 8 + #gui) == 'assets/'..gui..'/'
		or path == 'assets/new/loading.png'
		or gui == 'old' and (path == 'assets/new/guivape.png' or path == 'assets/new/guiv4.png')
end

local function verifySelectedAssets(files)
	if type(files) ~= 'table' then return end
	for repoPath in files do
		if selectedAssetPath(repoPath) then
			local target = 'aetherv2/'..repoPath
			local valid = false
			if isfile(target) then
				local ok, cached = pcall(readfile, target)
				valid = ok and payloadProblem(target, cached) == nil
			end
			if not valid then
				if isfile(target) then delfile(target) end
				local body, problem = fetchFile(target, shared.AetherV2PublicRef, 3)
				if not body then failLoad('Could not download required asset '..repoPath..' - '..tostring(problem)) end
				local stored, storeError = pcall(storeFile, target, body)
				if not stored then failLoad('Could not cache required asset '..repoPath..' - '..tostring(storeError)) end
			end
		end
	end
end
'''
needle = "\n_G.AetherV2SetLoadingStatus('Checking version', 0.18)"
text = replace_once(text, needle, asset_verifier + needle, 'asset verifier')
text = replace_once(text, "-- Only worth doing once we know the script is actually going to run.\nprefetch(prefetchPaths)\n\n_G.AetherV2SetLoadingStatus('Preparing loading artwork...', 0.70)", "-- Only worth doing once we know the script is actually going to run.\nif not prefetchPaths then prefetchPaths = fetchFileList(shared.AetherV2PublicRef or 'main') end\nprefetch(prefetchPaths)\nverifySelectedAssets(prefetchPaths)\n\n_G.AetherV2SetLoadingStatus('Preparing loading artwork...', 0.70)", 'verify after prefetch')
if 'releasechannel' in text.lower() or "'beta'" in text or "'nightly'" in text:
    raise SystemExit('init.lua still contains retired release-channel routing')
path.write_text(text)

# main.lua
path = Path('main.lua')
text = path.read_text()
old_selected = """local function selectedSourceRef(ref)
	if type(ref) == 'string' and ref:gsub('%s+', '') ~= '' then
		return ref:gsub('%s+', '')
	end
	local ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
	if ok and type(cached) == 'string' and cached:gsub('%s+', '') ~= '' then
		return cached:gsub('%s+', '')
	end
	return 'main'
end"""
new_selected = """local function selectedSourceRef(ref)
	if type(ref) == 'string' and ref:gsub('%s+', '') ~= '' then return ref:gsub('%s+', '') end
	if type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') ~= '' then
		return shared.AetherV2PublicRef:gsub('%s+', '')
	end
	local ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
	if ok and type(cached) == 'string' and cached:gsub('%s+', '') ~= '' then return cached:gsub('%s+', '') end
	return 'main'
end"""
text = replace_once(text, old_selected, new_selected, 'main selectedSourceRef')
text = replace_once(text, "\tlocal ref = readfile('aetherv2/profiles/commit.txt')\n", "\tlocal ref = selectedSourceRef()\n", 'main fetch ref')

m = re.search(r"local function downloadFile\(path, func\)\n[\s\S]*?\nend\n\nlocal function downloadOptionalFile\(path\)\n[\s\S]*?\nend", text)
if not m:
    raise SystemExit('main download helpers not found')
new_helpers = r'''local function ensureParentFolder(path)
	local parent = path:gsub('\\', '/'):match('^(.*)/[^/]+$')
	if not parent then return end
	local built = ''
	for segment in parent:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if not isfolder(built) then pcall(makefolder, built) end
	end
end

local function storePublicFile(path, body)
	ensureParentFolder(path)
	if path:sub(-4) == '.lua' then body = watermark..body end
	local ok, err = pcall(writefile, path, body)
	if not ok then return false, err end
	local readOk, cached = pcall(readfile, path)
	local problem = readOk and payloadProblem(path, cached) or 'unreadable cache'
	return problem == nil, problem
end

local function downloadFile(path, func)
	local exists = isfile(path)
	local cachedProblem = exists and payloadProblem(path, readfile(path)) or nil
	if cachedProblem then
		warn('[AetherV2] Cached '..path..' is unusable ('..cachedProblem..'), downloading it again')
		delfile(path)
		exists = false
	end
	if not exists then
		setPhaseProgress('Downloading '..path, 0.15)
		local body, problem = fetchFile(path)
		if not body then failLoad('Could not download '..path..' - '..tostring(problem)) end
		local stored, storeProblem = storePublicFile(path, body)
		if not stored then failLoad('Could not cache '..path..' - '..tostring(storeProblem)) end
		setPhaseProgress('Downloaded '..path, 0.75)
	end
	return (func or readfile)(path)
end

local function downloadOptionalFile(path)
	if isfile(path) then
		local ok, cached = pcall(readfile, path)
		if ok and not payloadProblem(path, cached) then return true end
		delfile(path)
	end
	local suc, res = pcall(function()
		if type(shared.AetherV2FetchSource) ~= 'function' then return nil end
		return shared.AetherV2FetchSource(path, selectedSourceRef())
	end)
	if not suc or payloadProblem(path, res) then return false end
	return storePublicFile(path, res)
end'''
text = text[:m.start()] + new_helpers + text[m.end():]
text = text.replace("\nif not isfile('aetherv2/profiles/releasechannel.txt') then\n\twritefile('aetherv2/profiles/releasechannel.txt', 'stable')\nend\n", "\n", 1)
text = text.replace("writefile('aetherv2/profiles/commit.txt', sourceRef or 'main')", "writefile('aetherv2/profiles/commit.txt', selectedSourceRef())", 1)
text = text.replace("traceGameLoad('source-ready', 'authenticated source')", "traceGameLoad('source-ready', 'public GitHub source')", 1)
if 'releasechannel' in text.lower() or 'sourceRef or' in text:
    raise SystemExit('main.lua still contains stale source routing')
path.write_text(text)

# guis/new.lua
path = Path('guis/new.lua')
text = path.read_text()
text = re.sub(r"local FALLBACK_COMMIT = '[0-9a-f]+'\n", '', text, count=1)
text = replace_once(text, "local function currentRef()\n\tlocal ok, ref = pcall(readfile, 'aetherv2/profiles/commit.txt')", "local function currentRef()\n\tif type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') ~= '' then\n\t\treturn shared.AetherV2PublicRef:gsub('%s+', '')\n\tend\n\tlocal ok, ref = pcall(readfile, 'aetherv2/profiles/commit.txt')", 'new wrapper ref')
text = text.replace("\n\tif true then\n\t\tbody, lastError = fetch(FALLBACK_COMMIT, 'guis/new.lua')\n\t\tif body then return body end\n\tend", "", 1)
text = replace_once(text, "local function validSource(body)\n\treturn type(body) == 'string' and #body > 32 and body ~= '404: Not Found'\nend", "local function validSource(body)\n\tif type(body) ~= 'string' or #body <= 32 or body == '404: Not Found' then return false end\n\tlocal head = body:sub(1, 300):lower()\n\treturn not head:find('<!doctype html') and not head:find('<html') and not body:find('SourceEndpoint', 1, true)\nend", 'new wrapper validation')
if 'FALLBACK_COMMIT' in text:
    raise SystemExit('new.lua still has fallback commit')
path.write_text(text)

# guis/new.core.lua
path = Path('guis/new.core.lua')
text = path.read_text()
text = replace_once(text, "local function installedSourceRef()\n\tlocal ref = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt'):gsub('%s+', '') or ''\n\treturn ref ~= '' and ref or sourceBranch()\nend", "local function installedSourceRef()\n\tlocal sharedRef = type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') or ''\n\tif sharedRef ~= '' then return sharedRef end\n\tlocal ref = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt'):gsub('%s+', '') or ''\n\treturn ref ~= '' and ref or sourceBranch()\nend", 'new.core ref')
path.write_text(text)

# old/rise downloaders
for file in ['guis/old.lua', 'guis/rise.lua']:
    path = Path(file)
    text = path.read_text()
    m = re.search(r"local function remoteSourceUrl\(path\)\n[\s\S]*?\nend\n\nlocal function downloadFile\(path, func\)\n[\s\S]*?\nend\n\ngetcustomasset = function\(path\)\n[\s\S]*?\nend", text)
    if not m:
        raise SystemExit(f'{file}: downloader block not found')
    new = r'''local function installedSourceRef()
	local sharedRef = type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') or ''
	if sharedRef ~= '' then return sharedRef end
	local commit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt'):gsub('%s+', '') or ''
	return commit ~= '' and commit or 'main'
end

local function remoteSourceUrl(path)
	return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..installedSourceRef()..'/'..
		select(1, path:gsub('^aetherv2/', ''))
end

local function validDownloadedFile(path, body)
	if type(body) ~= 'string' or #body < 8 then return false end
	local head = body:sub(1, 300):lower()
	if head:find('^%s*404') or head:find('^%s*429') or head:find('^%s*5%d%d:') or head:find('<!doctype html') or head:find('<html') then return false end
	if path:lower():sub(-4) == '.png' then return body:sub(1, 8) == '\137PNG\r\n\26\n' end
	return true
end

local function ensureDownloadFolder(path)
	local parent = path:gsub('\\', '/'):match('^(.*)/[^/]+$')
	if not parent then return end
	local built = ''
	for segment in parent:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if not isfolder(built) then pcall(makefolder, built) end
	end
end

local function downloadFile(path, func)
	local exists = isfile(path)
	if exists then
		local ok, cached = pcall(readfile, path)
		if not ok or not validDownloadedFile(path, cached) then
			if delfile then pcall(delfile, path) else pcall(writefile, path, '') end
			exists = false
		end
	end
	if not exists then
		createDownloader(path)
		local suc, res = pcall(function()
			if type(shared.AetherV2FetchSource) == 'function' then return shared.AetherV2FetchSource(path, installedSourceRef()) end
			return game:HttpGet(remoteSourceUrl(path), true)
		end)
		if not suc then error(res) end
		if not validDownloadedFile(path, res) then error('Invalid GitHub response while downloading '..path, 0) end
		if path:sub(-4) == '.lua' then res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res end
		ensureDownloadFolder(path)
		writefile(path, res)
	end
	return (func or readfile)(path)
end

getcustomasset = function(path)
	local downloaded = pcall(downloadFile, path)
	if assetfunction and downloaded then
		local success, result = pcall(assetfunction, path)
		if success then return result end
	end
	return getcustomassets[path] or ''
end'''
    text = text[:m.start()] + new + text[m.end():]
    path.write_text(text)

# architecture invariants
for file in [Path('init.lua'), Path('main.lua'), *Path('guis').glob('*.lua')]:
    body = file.read_text()
    if any(term in body for term in ['SourceEndpoint', 'SourceToken', 'SourceRef']):
        raise SystemExit(f'{file}: legacy normal private-source field remains')
if 'releasechannel' in Path('init.lua').read_text().lower() or 'releasechannel' in Path('main.lua').read_text().lower():
    raise SystemExit('release-channel state remains')
if 'FALLBACK_COMMIT' in Path('guis/new.lua').read_text():
    raise SystemExit('stale GUI fallback remains')
print('deep public source repair applied')
