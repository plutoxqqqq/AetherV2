from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    if new in text:
        return False
    if text.count(old) != 1:
        raise SystemExit(f'{path}: expected one {label} marker, found {text.count(old)}')
    p.write_text(text.replace(old, new, 1))
    return True


# init.lua: support the common executor custom-asset aliases and never accept a silent nil/empty
# registration result as a valid image. This specifically fixes executors that expose a stub
# getcustomasset while their working implementation is getsynasset/syn.getcustomasset.
replace_once(
    'init.lua',
    "local cloneref = cloneref or function(ref) return ref end\n\nlocal function safeLocalAsset(path)\n\tif type(getcustomasset) ~= 'function' then return '' end\n\tlocal ok, result = pcall(getcustomasset, path)\n\treturn ok and result or ''\nend",
    "local cloneref = cloneref or function(ref) return ref end\n\nlocal localAssetFunctions = {}\nlocal function addLocalAssetFunction(candidate)\n\tif type(candidate) == 'function' and not table.find(localAssetFunctions, candidate) then\n\t\ttable.insert(localAssetFunctions, candidate)\n\tend\nend\naddLocalAssetFunction(getcustomasset)\naddLocalAssetFunction(getsynasset)\nlocal executorEnvironment = getgenv and getgenv() or nil\nif type(executorEnvironment) == 'table' then\n\taddLocalAssetFunction(executorEnvironment.getcustomasset)\n\taddLocalAssetFunction(executorEnvironment.getsynasset)\nend\nif type(syn) == 'table' then\n\taddLocalAssetFunction(syn.getcustomasset)\n\taddLocalAssetFunction(syn.getsynasset)\nend\n\nlocal function safeLocalAsset(path)\n\tfor _, assetFunction in localAssetFunctions do\n\t\tlocal ok, result = pcall(assetFunction, path)\n\t\tif ok and type(result) == 'string' and result ~= '' then return result end\n\tend\n\treturn ''\nend",
    'safe local asset function',
)

# init.lua: raw PNG/font bodies are binary. Prefer an executor request API for assets because some
# game:HttpGet implementations UTF-8-normalize binary responses while still working perfectly for
# Lua/JSON. Fall back to game:HttpGet everywhere else.
replace_once(
    'init.lua',
    "local function repoUrl(path, ref)\n\tlocal selectedRef = ref or shared.AetherV2PublicRef\n\tif type(selectedRef) ~= 'string' or selectedRef:gsub('%s+', '') == '' then\n\t\tlocal ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')\n\t\tselectedRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or ''\n\tend\n\tif selectedRef == '' then selectedRef = 'main' end\n\treturn 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('^aetherv2/', ''))\nend\n\n-- Fetch with retries, returning the body or nil plus a reason. Most failures here are transient - a\n-- dropped connection, a moment of rate limiting - and one of them used to end the whole load.\nlocal function fetchFile(path, ref, attempts)\n\tattempts = attempts or 3\n\tlocal url = repoUrl(path, ref)\n\tlocal problem\n\tfor attempt = 1, attempts do\n\t\tlocal suc, res = pcall(function()\n\t\t\treturn game:HttpGet(url, true)\n\t\tend)",
    "local function repoUrl(path, ref)\n\tlocal selectedRef = ref or shared.AetherV2PublicRef\n\tif type(selectedRef) ~= 'string' or selectedRef:gsub('%s+', '') == '' then\n\t\tlocal ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')\n\t\tselectedRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or ''\n\tend\n\tif selectedRef == '' then selectedRef = 'main' end\n\treturn 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('^aetherv2/', ''))\nend\n\nlocal executorRequest = request or http_request\nif type(executorRequest) ~= 'function' and type(syn) == 'table' then executorRequest = syn.request end\nif type(executorRequest) ~= 'function' and type(http) == 'table' then executorRequest = http.request end\n\nlocal function rawHttpGet(url, preferBinary)\n\tif preferBinary and type(executorRequest) == 'function' then\n\t\tlocal ok, response = pcall(executorRequest, {Url = url, Method = 'GET'})\n\t\tif ok and type(response) == 'table' then\n\t\t\tlocal status = tonumber(response.StatusCode or response.Status or response.status_code or 200) or 0\n\t\t\tlocal body = response.Body or response.body\n\t\t\tif status >= 200 and status < 300 and type(body) == 'string' then return body end\n\t\tend\n\tend\n\treturn game:HttpGet(url, true)\nend\n\n-- Fetch with retries, returning the body or nil plus a reason. Most failures here are transient - a\n-- dropped connection, a moment of rate limiting - and one of them used to end the whole load.\nlocal function fetchFile(path, ref, attempts)\n\tattempts = attempts or 3\n\tlocal url = repoUrl(path, ref)\n\tlocal cleanPath = tostring(path):gsub('^aetherv2/', '')\n\tlocal problem\n\tfor attempt = 1, attempts do\n\t\tlocal suc, res = pcall(function()\n\t\t\treturn rawHttpGet(url, cleanPath:sub(1, 7) == 'assets/')\n\t\tend)",
    'binary-safe init fetcher',
)

# main.lua: all lazy GUI/asset fetches go through this helper after startup. Preserve raw binary
# bodies through request/http_request/syn.request when available.
replace_once(
    'main.lua',
    "-- Game and GUI modules use this shared fetcher when they need another public source file.\nshared.AetherV2FetchSource = function(path, ref)\n\treturn game:HttpGet(publicSourceUrl(path, ref), true)\nend",
    "local executorRequest = request or http_request\nif type(executorRequest) ~= 'function' and type(syn) == 'table' then executorRequest = syn.request end\nif type(executorRequest) ~= 'function' and type(http) == 'table' then executorRequest = http.request end\n\nlocal function publicHttpGet(url, preferBinary)\n\tif preferBinary and type(executorRequest) == 'function' then\n\t\tlocal ok, response = pcall(executorRequest, {Url = url, Method = 'GET'})\n\t\tif ok and type(response) == 'table' then\n\t\t\tlocal status = tonumber(response.StatusCode or response.Status or response.status_code or 200) or 0\n\t\t\tlocal body = response.Body or response.body\n\t\t\tif status >= 200 and status < 300 and type(body) == 'string' then return body end\n\t\tend\n\tend\n\treturn game:HttpGet(url, true)\nend\n\n-- Game and GUI modules use this shared fetcher when they need another public source file.\nshared.AetherV2FetchSource = function(path, ref)\n\tlocal cleanPath = tostring(path):gsub('^aetherv2/', '')\n\treturn publicHttpGet(publicSourceUrl(cleanPath, ref), cleanPath:sub(1, 7) == 'assets/')\nend",
    'binary-safe shared source fetcher',
)

asset_function_block = """local assetfunctions = {}
local function addAssetFunction(candidate)
\tif type(candidate) == 'function' and not table.find(assetfunctions, candidate) then
\t\ttable.insert(assetfunctions, candidate)
\tend
end
addAssetFunction(getcustomasset)
addAssetFunction(getsynasset)
local executorEnvironment = getgenv and getgenv() or nil
if type(executorEnvironment) == 'table' then
\taddAssetFunction(executorEnvironment.getcustomasset)
\taddAssetFunction(executorEnvironment.getsynasset)
end
if type(syn) == 'table' then
\taddAssetFunction(syn.getcustomasset)
\taddAssetFunction(syn.getsynasset)
end
local assetfunction = assetfunctions[1]
local getcustomasset"""

asset_wrapper = """getcustomasset = function(path)
\tlocal downloaded, downloadResult = pcall(downloadFile, path)
\tif downloaded then
\t\tfor _, registerAsset in assetfunctions do
\t\t\tlocal success, result = pcall(registerAsset, path)
\t\t\tif success and type(result) == 'string' and result ~= '' then return result end
\t\tend
\telse
\t\twarn('[AetherV2] Failed to cache asset '..tostring(path)..': '..tostring(downloadResult))
\tend
\treturn getcustomassets[path] or ''
end"""

for path in ('guis/new.core.lua', 'guis/old.lua', 'guis/rise.lua'):
    replace_once(path, 'local assetfunction = getcustomasset\nlocal getcustomasset', asset_function_block, 'asset API resolver')
    p = Path(path)
    text = p.read_text()
    old_wrapper = """getcustomasset = function(path)
\tlocal downloaded = pcall(downloadFile, path)
\tif assetfunction and downloaded then
\t\tlocal success, result = pcall(assetfunction, path)
\t\tif success then return result end
\tend
\treturn getcustomassets[path] or ''
end"""
    if asset_wrapper not in text:
        if text.count(old_wrapper) != 1:
            raise SystemExit(f'{path}: expected one asset wrapper, found {text.count(old_wrapper)}')
        text = text.replace(old_wrapper, asset_wrapper, 1)

    # Verify the file after write. The previous GUI-side downloader validated the network response
    # but never checked what actually landed on disk.
    old_write = "\t\tensureDownloadFolder(path)\n\t\twritefile(path, res)\n\tend\n\treturn (func or readfile)(path)"
    new_write = "\t\tensureDownloadFolder(path)\n\t\twritefile(path, res)\n\t\tlocal readOk, cached = pcall(readfile, path)\n\t\tif not readOk or not validDownloadedFile(path, cached) then\n\t\t\terror('Cached asset/source verification failed for '..path, 0)\n\t\tend\n\tend\n\treturn (func or readfile)(path)"
    if new_write not in text:
        if text.count(old_write) != 1:
            raise SystemExit(f'{path}: expected one write verification marker, found {text.count(old_write)}')
        text = text.replace(old_write, new_write, 1)

    # If the shared transport ever returns a bad body, retry the direct public URL before failing.
    old_fetch = """\t\tlocal suc, res = pcall(function()
\t\t\tif type(shared.AetherV2FetchSource) == 'function' then return shared.AetherV2FetchSource(path, installedSourceRef()) end
\t\t\treturn game:HttpGet(remoteSourceUrl(path), true)
\t\tend)
\t\tif not suc then error(res) end
\t\tif not validDownloadedFile(path, res) then error('Invalid GitHub response while downloading '..path, 0) end"""
    new_fetch = """\t\tlocal suc, res = pcall(function()
\t\t\tif type(shared.AetherV2FetchSource) == 'function' then
\t\t\t\tlocal sharedOk, sharedBody = pcall(shared.AetherV2FetchSource, path, installedSourceRef())
\t\t\t\tif sharedOk and validDownloadedFile(path, sharedBody) then return sharedBody end
\t\t\tend
\t\t\treturn game:HttpGet(remoteSourceUrl(path), true)
\t\tend)
\t\tif not suc then error(res) end
\t\tif not validDownloadedFile(path, res) then error('Invalid GitHub response while downloading '..path, 0) end"""
    if new_fetch not in text:
        if text.count(old_fetch) != 1:
            raise SystemExit(f'{path}: expected one transport fallback marker, found {text.count(old_fetch)}')
        text = text.replace(old_fetch, new_fetch, 1)
    p.write_text(text)

# Guard against accidentally leaving the silent-success bug anywhere in the active GUI files.
for path in ('guis/new.core.lua', 'guis/old.lua', 'guis/rise.lua'):
    text = Path(path).read_text()
    if "if success then return result end" in text:
        raise SystemExit(f'{path}: silent custom-asset success path still exists')
    if 'getsynasset' not in text or 'assetfunctions' not in text:
        raise SystemExit(f'{path}: executor asset aliases were not installed')

print('final asset display repair applied')
