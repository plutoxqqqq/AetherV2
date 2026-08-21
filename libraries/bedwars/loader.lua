local cloneref = cloneref or function(obj)
    return obj
end

local HttpService = cloneref(game:GetService('HttpService'))
local function wipeFiles(old, new)
    local changes = HttpService:JSONDecode(game:HttpGet('https://gitlab.com/api/v4/projects/stxvv%2FBedwarsDeps/repository/compare?from='..old..'&to='..new)).diffs

    for _, d in changes do
        for _, v in {d.new_path, d.old_path} do
            if v then
                local time = os.clock()
                if isfile('compiler/cache/'..v) then
                    print('[COMPILER]: Deleting compiler/cache/'..v)
                    delfile('compiler/cache/'..v)
                    print(('[COMPILER]: Deleted file in %.3fs'):format(os.clock() - time))
                end
            end
        end
    end
end

for _, v in {'compiler', 'compiler/cache', 'compiler/cache/controllers', 'compiler/cache/definitions', 'compiler/cache/main'} do
    if not isfolder(v) then
        makefolder(v)
    end
end

local commit = HttpService:JSONDecode(game:HttpGet('https://gitlab.com/api/v4/projects/stxvv%2FBedwarsDeps/repository/commits?per_page=1'))[1].id
if not isfile('compiler/commit.txt') then
    writefile('compiler/commit.txt', commit)
elseif readfile('compiler/commit.txt') ~= commit then
    wipeFiles(readfile('compiler/commit.txt'), commit)
    writefile('compiler/commit.txt', commit)
end

return loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))()