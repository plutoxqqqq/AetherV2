local Runtime = {}

function Runtime.new()
    local Players = game:GetService('Players')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local lplr = Players.LocalPlayer
    local bedwars = {Players = Players, ReplicatedStorage = ReplicatedStorage, LocalPlayer = lplr}

    pcall(function()
        local knitExport = require(lplr.PlayerScripts.TS.knit)
        local setup = knitExport and knitExport.setup
        if setup and debug and debug.getupvalue then
            local ok, Knit = pcall(debug.getupvalue, setup, 9)
            if ok then bedwars.Knit = Knit end
        end
    end)

    pcall(function() bedwars.Client = require(ReplicatedStorage.TS.remotes).default.Client end)
    pcall(function() bedwars.InventoryUtil = require(ReplicatedStorage.TS.inventory['inventory-util']).InventoryUtil end)
    pcall(function() bedwars.Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore end)
    pcall(function() bedwars.ZapNetworking = require(lplr.PlayerScripts.TS.lib.network) end)

    return setmetatable(bedwars, {
        __index = function(self, key)
            local Knit = rawget(self, 'Knit')
            local controller = Knit and Knit.Controllers and Knit.Controllers[key]
            if controller ~= nil then
                rawset(self, key, controller)
                return controller
            end
        end
    })
end

return Runtime
