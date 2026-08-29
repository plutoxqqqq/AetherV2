from pathlib import Path
import re


def exact(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: {label}: expected 1 marker, got {count}')
    p.write_text(text.replace(old, new, 1))


def regex(path, pattern, replacement, label):
    p = Path(path)
    text = p.read_text()
    if isinstance(replacement, str) and replacement in text:
        return
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.M)
    if count != 1:
        raise SystemExit(f'{path}: {label}: expected 1 marker, got {count}')
    p.write_text(updated)


# Loading-screen local asset registration.
exact(
    'init.lua',
    "local cloneref = cloneref or function(ref) return ref end\n\nlocal function safeLocalAsset(path)\n\tif type(getcustomasset) ~= 'function' then return '' end\n\tlocal ok, result = pcall(getcustomasset, path)\n\treturn ok and result or ''\nend",
    "local cloneref = cloneref or function(ref) return ref end\n\nlocal localAssetFunctions = {}\nlocal function addLocalAssetFunction(candidate)\n\tif type(candidate) == 'function' and not table.find(localAssetFunctions, candidate) then\n\t\ttable.insert(localAssetFunctions, candidate)\n\tend\nend\naddLocalAssetFunction(getcustomasset)\naddLocalAssetFunction(getsynasset)\nlocal executorEnvironment = getgenv and getgenv() or nil\nif type(executorEnvironment) == 'table' then\n\taddLocalAssetFunction(executorEnvironment.getcustomasset)\n\taddLocalAssetFunction(executorEnvironment.getsynasset)\nend\nif type(syn) == 'table' then\n\taddLocalAssetFunction(syn.getcustomasset)\n\taddLocalAssetFunction(syn.getsynasset)\nend\n\nlocal function safeLocalAsset(path)\n\tfor _, registerAsset in localAssetFunctions do\n\t\tlocal ok, result = pcall(registerAsset, path)\n\t\tif ok and type(result) == 'string' and result ~= '' then return result end\n\tend\n\treturn ''\nend",
    'safeLocalAsset',
)

# Binary-safe startup source transport for assets. Lua/JSON still use game:HttpGet.
old_init_fetch = """local function repoUrl(path, ref)
\tlocal selectedRef = ref or shared.AetherV2PublicRef
\tif type(selectedRef) ~= 'string' or selectedRef:gsub('%s+', '') == '' then
\t\tlocal ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
\t\tselectedRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or ''
\tend
\tif selectedRef == '' then selectedRef = 'main' end
\treturn 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('^aetherv2/', ''))
end

-- Fetch with retries, returning the body or nil plus a reason. Most failures here are transient - a
-- dropped connection, a moment of rate limiting - and one of them used to end the whole load.
local function fetchFile(path, ref, attempts)
\tattempts = attempts or 3
\tlocal url = repoUrl(path, ref)
\tlocal problem
\tfor attempt = 1, attempts do
\t\tlocal suc, res = pcall(function()
\t\t\treturn game:HttpGet(url, true)
\t\tend)"""
new_init_fetch = """local function repoUrl(path, ref)
\tlocal selectedRef = ref or shared.AetherV2PublicRef
\tif type(selectedRef) ~= 'string' or selectedRef:gsub('%s+', '') == '' then
\t\tlocal ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
\t\tselectedRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or ''
\tend
\tif selectedRef == '' then selectedRef = 'main' end
\treturn 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('^aetherv2/', ''))
end

local executorRequest = request or http_request
if type(executorRequest) ~= 'function' and type(syn) == 'table' then executorRequest = syn.request end
if type(executorRequest) ~= 'function' and type(http) == 'table' then executorRequest = http.request end

local function publicHttpGet(url, binary)
\tif binary and type(executorRequest) == 'function' then
\t\tlocal ok, response = pcall(executorRequest, {Url = url, Method = 'GET'})
\t\tif ok and type(response) == 'table' then
\t\t\tlocal status = tonumber(response.StatusCode or response.Status or response.status_code or 200) or 0
\t\t\tlocal body = response.Body or response.body
\t\t\tif status >= 200 and status < 300 and type(body) == 'string' then return body end
\t\tend
\tend
\treturn game:HttpGet(url, true)
end

-- Fetch with retries, returning the body or nil plus a reason. Most failures here are transient - a
-- dropped connection, a moment of rate limiting - and one of them used to end the whole load.
local function fetchFile(path, ref, attempts)
\tattempts = attempts or 3
\tlocal url = repoUrl(path, ref)
\tlocal cleanPath = tostring(path):gsub('^aetherv2/', '')
\tlocal problem
\tfor attempt = 1, attempts do
\t\tlocal suc, res = pcall(function()
\t\t\treturn publicHttpGet(url, cleanPath:sub(1, 7) == 'assets/')
\t\tend)"""
exact('init.lua', old_init_fetch, new_init_fetch, 'binary startup fetch')

# Binary-safe lazy transport used by GUI downloaders after main.lua starts.
exact(
    'main.lua',
    "-- Game and GUI modules use this shared fetcher when they need another public source file.\nshared.AetherV2FetchSource = function(path, ref)\n\treturn game:HttpGet(publicSourceUrl(path, ref), true)\nend",
    "local executorRequest = request or http_request\nif type(executorRequest) ~= 'function' and type(syn) == 'table' then executorRequest = syn.request end\nif type(executorRequest) ~= 'function' and type(http) == 'table' then executorRequest = http.request end\n\nlocal function sharedPublicHttpGet(url, binary)\n\tif binary and type(executorRequest) == 'function' then\n\t\tlocal ok, response = pcall(executorRequest, {Url = url, Method = 'GET'})\n\t\tif ok and type(response) == 'table' then\n\t\t\tlocal status = tonumber(response.StatusCode or response.Status or response.status_code or 200) or 0\n\t\t\tlocal body = response.Body or response.body\n\t\t\tif status >= 200 and status < 300 and type(body) == 'string' then return body end\n\t\tend\n\tend\n\treturn game:HttpGet(url, true)\nend\n\n-- Game and GUI modules use this shared fetcher when they need another public source file.\nshared.AetherV2FetchSource = function(path, ref)\n\tlocal cleanPath = tostring(path):gsub('^aetherv2/', '')\n\treturn sharedPublicHttpGet(publicSourceUrl(cleanPath, ref), cleanPath:sub(1, 7) == 'assets/')\nend",
    'binary lazy fetch',
)

resolver = """local assetfunctions = {}
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

wrapper = """getcustomasset = function(path)
\tlocal downloaded, downloadError = pcall(downloadFile, path)
\tif downloaded then
\t\tfor _, registerAsset in assetfunctions do
\t\t\tlocal success, result = pcall(registerAsset, path)
\t\t\tif success and type(result) == 'string' and result ~= '' then return result end
\t\tend
\telse
\t\twarn('[AetherV2] Failed to cache asset '..tostring(path)..': '..tostring(downloadError))
\tend
\treturn getcustomassets[path] or ''
end"""

wrapper_pattern = (
    r"getcustomasset = function\(path\)\n"
    r"\tlocal downloaded = pcall\(downloadFile, path\)\n"
    r"\tif assetfunction and downloaded then\n"
    r"\t\tlocal (?:suc, res|success, result) = pcall\(assetfunction, path\)\n"
    r"\t\tif (?:suc|success) then return (?:res|result) end\n"
    r"\tend\n"
    r"\treturn getcustomassets\[path\] or ''\n"
    r"end"
)

for name in ('guis/new.core.lua', 'guis/old.lua', 'guis/rise.lua'):
    exact(name, 'local assetfunction = getcustomasset\nlocal getcustomasset', resolver, 'asset API resolver')
    p = Path(name)
    text = p.read_text()
    if wrapper not in text:
        text, count = re.subn(wrapper_pattern, lambda _: wrapper, text, count=1)
        if count != 1:
            raise SystemExit(f'{name}: asset wrapper: expected 1 marker, got {count}')

    # Verify on-disk bytes after lazy downloads too. This handles executors whose writefile can
    # silently fail/truncate under concurrent filesystem activity.
    if 'Cached asset/source verification failed for ' not in text:
        marker = '\t\tensureDownloadFolder(path)\n\t\twritefile(path, res)\n'
        if text.count(marker) != 1:
            raise SystemExit(f'{name}: post-write marker: expected 1, got {text.count(marker)}')
        replacement = marker + (
            "\t\tlocal readOk, cached = pcall(readfile, path)\n"
            "\t\tif not readOk or not validDownloadedFile(path, cached) then\n"
            "\t\t\terror('Cached asset/source verification failed for '..path, 0)\n"
            "\t\tend\n"
        )
        text = text.replace(marker, replacement, 1)
    p.write_text(text)

# Runtime safety assertions.
for name in ('guis/new.core.lua', 'guis/old.lua', 'guis/rise.lua'):
    text = Path(name).read_text()
    if re.search(r'if (?:suc|success) then return (?:res|result) end', text):
        raise SystemExit(f'{name}: empty-result custom asset bug still present')
    for expected in ('addAssetFunction(getsynasset)', "type(result) == 'string' and result ~= ''", 'Cached asset/source verification failed for '):
        if expected not in text:
            raise SystemExit(f'{name}: missing {expected}')

print('focused asset runtime repair applied')
