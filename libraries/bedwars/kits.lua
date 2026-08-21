local Kits = {}
function Kits.new(runtime)
    local api = {}
    function api:getMeta()
        local ok, result = pcall(function()
            return require(runtime.ReplicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta
        end)
        return ok and result or nil
    end
    function api:getCurrent(player)
        player = player or runtime.LocalPlayer
        return player and (player:GetAttribute('PlayingAsKit') or player:GetAttribute('Kit')) or nil
    end
    function api:is(kit, player) return self:getCurrent(player) == kit end
    return api
end
return Kits
