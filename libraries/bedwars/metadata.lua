local Metadata = {}
local function try(callback) local ok, value = pcall(callback); return ok and value or nil end
function Metadata.new(runtime)
    local ReplicatedStorage = runtime.ReplicatedStorage
    local data = {}
    data.ItemMeta = try(function()
        local module = require(ReplicatedStorage.TS.item['item-meta'])
        return debug.getupvalue(module.getItemMeta, 1)
    end)
    data.ProjectileMeta = try(function() return require(ReplicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta end)
    data.BedwarsKitMeta = try(function() return require(ReplicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta end)
    data.QueueMeta = try(function() return require(ReplicatedStorage.TS.game['queue-meta']).QueueMeta end)
    data.TeamUpgradeMeta = try(function()
        local module = require(ReplicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta'])
        return debug.getupvalue(module.getTeamUpgradeMetaForQueue, 6)
    end)
    function data:getItem(itemType) return self.ItemMeta and self.ItemMeta[itemType] or nil end
    function data:getProjectile(projectileType) return self.ProjectileMeta and self.ProjectileMeta[projectileType] or nil end
    return data
end
return Metadata
