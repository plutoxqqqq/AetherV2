local Network = {}
function Network.new(runtime)
    local api = {}
    function api:getClient() return runtime.Client end
    function api:getZap() return runtime.ZapNetworking end
    function api:getRemote(name)
        local client = runtime.Client
        if not client or not client.Get then return nil end
        local ok, remote = pcall(function() return client:Get(name) end)
        return ok and remote or nil
    end
    return api
end
return Network
