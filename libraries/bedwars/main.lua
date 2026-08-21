local cloneref = cloneref or function(obj)
    return obj
end

local HttpService = cloneref(game:GetService('HttpService'))

local bwdeps = {}
local function fetchFile(name, codeext)
    local time = os.clock()
    print('[COMPILER]: Fetching file: '..name)
    
	url = name:gsub('compiler/cache/', '')
	if not isfile(name..'.'..codeext) then
	    writefile(name..'.'..codeext, game:HttpGet(string.format('https://gitlab.com/stxvv/BedwarsDeps/-/raw/%s/%s.%s', readfile('compiler/commit.txt'), url, codeext)))
        repeat task.wait() until isfile(name..'.'..codeext)
    end

    local res = readfile(name..'.'..codeext)
    print(('[COMPILER]: Fetched file in %.3fs'):format(os.clock() - time))

    return res
end

function bwdeps:GetJson(name)
    return HttpService:JSONDecode(fetchFile('compiler/cache/'..name, 'json'))
end

function bwdeps:GetController(name)
    return loadstring(fetchFile('compiler/cache/controllers/'..name, 'lua'))()
end

function bwdeps:GetMeta(name)
    if name == 'ProdAnimations' or name == 'GameSound' or name == 'ItemMeta' or name == 'GameSoundMeta' then
        return loadstring(fetchFile('compiler/cache/definitions/'..name, 'lua'))()
    end

    return HttpService:JSONDecode(fetchFile('compiler/cache/definitions/'..name, 'json'))
end

function bwdeps:GetMain(name)
    return loadstring(fetchFile('compiler/cache/main/'..name, 'lua'))()
end

return bwdeps