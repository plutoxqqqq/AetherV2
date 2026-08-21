local Projectiles = {}
function Projectiles.new(runtime)
    local api = {}
    function api:getMeta()
        local ok, result = pcall(function()
            return require(runtime.ReplicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta
        end)
        return ok and result or nil
    end
    function api:get(projectileType)
        local meta = self:getMeta()
        return meta and meta[projectileType] or nil
    end
    return api
end
return Projectiles
