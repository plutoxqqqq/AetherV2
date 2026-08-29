from pathlib import Path
import re


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    if new in text:
        return False
    if text.count(old) != 1:
        raise SystemExit(f'{path}: expected one {label} marker, found {text.count(old)}')
    p.write_text(text.replace(old, new, 1))
    return True


def regex_once(text, pattern, replacement, label, flags=0):
    updated, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'expected one {label} marker, found {count}')
    return updated


# Loader loading-screen artwork: support common executor aliases and reject nil/empty "successful"
# registrations. A stub getcustomasset must not hide a working getsynasset/syn implementation.
replace_once(
    'init.lua',
    "local cloneref = cloneref or function(ref) return ref end\n\nlocal function safeLocalAsset(path)\n\tif type(getcustomasset) ~= 'function' then return '' end\n\tlocal ok, result = pcall(getcustomasset, path)\n\treturn ok and result or ''\nend",
    "local cloneref = cloneref or function(ref) return ref end\n\nlocal localAssetFunctions = {}\nlocal function addLocalAssetFunction(candidate)\n\tif type(candidate) == 'function' and not table.find(localAssetFunctions, candidate) then\n\t\ttable.insert(localAssetFunctions, candidate)\n\tend\nend\naddLocalAssetFunction(getcustomasset)\naddLocalAssetFunction(getsynasset)\nlocal executorEnvironment = getgenv and getgenv() or nil\nif type(executorEnvironment) == 'table' then\n\taddLocalAssetFunction(executorEnvironment.getcustomasset)\n\taddLocalAssetFunction(executorEnvironment.getsynasset)\nend\nif type(syn) == 'table' then\n\taddLocalAssetFunction(syn.getcustomasset)\n\taddLocalAssetFunction(syn.getsynasset)\nend\n\nlocal function safeLocalAsset(path)\n\tfor _, assetFunction in localAssetFunctions do\n\t\tlocal ok, result = pcall(assetFunction, path)\n\t\tif ok and type(result) == 'string' and result ~= '' then return result end\n\tend\n\treturn ''\nend",
    'safe local asset function',
)

# Asset bodies are binary. Some executor game:HttpGet implementations are fine for Lua/JSON but
# normalize binary strings. Prefer executor request APIs for assets, while retaining HttpGet as the
# universal fallback.
replace_once(
    'init.lua',
    "local function repoUrl(path, ref)\n\tlocal selectedRef = ref or shared.AetherV2PublicRef\n\tif type(selectedRef) ~= 'string' or selectedRef:gsub('%s+', '') == '' then\n\t\tlocal ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')\n\t\tselectedRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or ''\n\tend\n\tif selectedRef == '' then selectedRef = 'main' end\n\treturn 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('^aetherv2/', ''))\nend\n\n-- Fetch with retries, returning the body or nil plus a reason. Most failures here are transient - a\n-- dropped connection, a moment of rate limiting - and one of them used to end the whole load.\nlocal function fetchFile(path, ref, attempts)\n\tattempts = attempts or 3\n\tlocal url = repoUrl(path, ref)\n\tlocal problem\n\tfor attempt = 1, attempts do\n\t\tlocal suc, res = pcall(function()\n\t\t\treturn game:HttpGet(url, true)\n\t\tend)",
    "local function repoUrl(path, ref)\n\tlocal selectedRef = ref or shared.AetherV2PublicRef\n\tif type(selectedRef) ~= 'string' or selectedRef:gsub('%s+', '') == '' then\n\t\tlocal ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')\n\t\tselectedRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or ''\n\tend\n\tif selectedRef == '' then selectedRef = 'main' end\n\treturn 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('^aetherv2/', ''))\nend\n\nlocal executorRequest = request or http_request\nif type(executorRequest) ~= 'function' and type(syn) == 'table' then executorRequest = syn.request end\nif type(executorRequest) ~= 'function' and type(http) == 'table' then executorRequest = http.request end\n\nlocal function rawHttpGet(url, preferBinary)\n\tif preferBinary and type(executorRequest) == 'function' then\n\t\tlocal ok, response = pcall(executorRequest, {Url = url, Method = 'GET'})\n\t\tif ok and type(response) == 'table' then\n\t\t\tlocal status = tonumber(response.StatusCode or response.Status or response.status_code or 200) or 0\n\t\t\tlocal body = response.Body or response.body\n\t\t\tif status >= 200 and status < 300 and type(body) == 'string' then return body end\n\t\tend\n\tend\n\treturn game:HttpGet(url, true)\nend\n\n-- Fetch with retries, returning the body or nil plus a reason. Most failures here are transient - a\n-- dropped connection, a moment of rate limiting - and one of them used to end the whole load.\nlocal function fetchFile(path, ref, attempts)\n\tattempts = attempts or 3\n\tlocal url = repoUrl(path, ref)\n\tlocal cleanPath = tostring(path):gsub('^aetherv2/', '')\n\tlocal problem\n\tfor attempt = 1, attempts do\n\t\tlocal suc, res = pcall(function()\n\t\t\treturn rawHttpGet(url, cleanPath:sub(1, 7) == 'assets/')\n\t\tend)",
    'binary-safe init fetcher',
)

# All lazy GUI fetches route through main.lua. Keep those asset fetches binary-safe too.
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

    # Replace either historical variable naming (suc/res or success/result), with optional comments
    # before the wrapper. This is intentionally structural instead of a whole-block literal match.
    if asset_wrapper not in text:
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
        text = regex_once(text, wrapper_pattern, lambda _: asset_wrapper, f'{path} asset wrapper')

    # Verify the exact bytes that landed on disk after every GUI-side lazy download.
    if 'Cached asset/source verification failed for ' not in text:
        write_pattern = (
            r"(\t\tensureDownloadFolder\(path\)\n\t\twritefile\(path, res\)\n)"
            r"(\tend\n\n?\treturn \(func or readfile\)\(path\))"
        )
        write_replacement = (
            "\\1"
            "\t\tlocal readOk, cached = pcall(readfile, path)\n"
            "\t\tif not readOk or not validDownloadedFile(path, cached) then\n"
            "\t\t\terror('Cached asset/source verification failed for '..path, 0)\n"
            "\t\tend\n"
            "\\2"
        )
        text = regex_once(text, write_pattern, write_replacement, f'{path} post-write verification')

    # If the shared transport returns invalid bytes, retry the canonical raw GitHub URL. Account for
    # both compact and expanded formatting in the three GUI implementations.
    if 'local sharedOk, sharedBody = pcall(shared.AetherV2FetchSource' not in text:
        fetch_pattern = (
            r"\t\tlocal suc, res = pcall\(function\(\)\n"
            r"\t\t\tif type\(shared\.AetherV2FetchSource\) == 'function' then(?:\n)?"
            r"(?:\t\t\t\t)?return shared\.AetherV2FetchSource\(path, installedSourceRef\(\)\)(?:\n\t\t\tend)?\n"
            r"\t\t\treturn game:HttpGet\(remoteSourceUrl\(path\), true\)\n"
            r"\t\tend\)"
        )
        fetch_replacement = (
            "\t\tlocal suc, res = pcall(function()\n"
            "\t\t\tif type(shared.AetherV2FetchSource) == 'function' then\n"
            "\t\t\t\tlocal sharedOk, sharedBody = pcall(shared.AetherV2FetchSource, path, installedSourceRef())\n"
            "\t\t\t\tif sharedOk and validDownloadedFile(path, sharedBody) then return sharedBody end\n"
            "\t\t\tend\n"
            "\t\t\treturn game:HttpGet(remoteSourceUrl(path), true)\n"
            "\t\tend)"
        )
        text = regex_once(text, fetch_pattern, lambda _: fetch_replacement, f'{path} transport fallback')

    p.write_text(text)

# Guards: no active GUI may treat a nil/empty local-asset return as success, and every GUI must know
# the common alias family.
for path in ('guis/new.core.lua', 'guis/old.lua', 'guis/rise.lua'):
    text = Path(path).read_text()
    if re.search(r"if (?:suc|success) then return (?:res|result) end", text):
        raise SystemExit(f'{path}: silent custom-asset success path still exists')
    for marker in ('getsynasset', 'assetfunctions', "type(result) == 'string' and result ~= ''"):
        if marker not in text:
            raise SystemExit(f'{path}: missing asset compatibility marker: {marker}')

print('final asset display repair applied')
