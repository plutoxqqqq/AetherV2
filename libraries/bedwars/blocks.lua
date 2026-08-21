local Blocks = {}
function Blocks.new(runtime)
    local api = {}
    function api:getController()
        return runtime.BlockController or runtime.BlockBreakController or runtime.BlockPlacementController
    end
    function api:getQueryUtil()
        local rs = runtime.ReplicatedStorage
        local ok, result = pcall(function()
            return require(rs['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil
        end)
        return ok and result or nil
    end
    return api
end
return Blocks
