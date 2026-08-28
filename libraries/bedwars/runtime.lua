local Runtime = {}

function Runtime.new()
    local Players = game:GetService('Players')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local lplr = Players.LocalPlayer
    local bedwars = {
        Players = Players,
        ReplicatedStorage = ReplicatedStorage,
        LocalPlayer = lplr,
        RuntimeErrors = {}
    }

    local function assign(name, resolver)
        local ok, value = pcall(resolver)
        if ok and value ~= nil then
            bedwars[name] = value
            return value
        end
        bedwars.RuntimeErrors[name] = tostring(value)
        return nil
    end

    -- Prefer the live runtime objects Aether's match file already uses. Every dependency is
    -- resolved independently so one renamed optional BedWars module cannot erase the entire
    -- compatibility runtime.
    assign('Knit', function()
        local export = require(ReplicatedStorage.rbxts_include.node_modules['@easy-games'].knit.src)
        return export.KnitClient or export.default or export
    end)

    if not bedwars.Knit then
        assign('Knit', function()
            local knitExport = require(lplr.PlayerScripts.TS.knit)
            local setup = knitExport and knitExport.setup
            if setup and debug and debug.getupvalue then
                local value = debug.getupvalue(setup, 9)
                return value
            end
        end)
    end

    assign('Client', function() return require(ReplicatedStorage.TS.remotes).default.Client end)
    assign('InventoryUtil', function() return require(ReplicatedStorage.TS.inventory['inventory-util']).InventoryUtil end)
    assign('Store', function() return require(lplr.PlayerScripts.TS.ui.store).ClientStore end)
    assign('ZapNetworking', function() return require(lplr.PlayerScripts.TS.lib.network) end)
    assign('ItemMeta', function() return require(ReplicatedStorage.TS.item['item-meta']).items end)
    assign('ProjectileMeta', function() return require(ReplicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta end)
    assign('AnimationType', function() return require(ReplicatedStorage.TS.animation['animation-type']).AnimationType end)
    assign('KnockbackUtil', function() return require(ReplicatedStorage.TS.damage['knockback-util']).KnockbackUtil end)
    assign('CombatConstant', function() return require(ReplicatedStorage.TS.combat['combat-constant']).CombatConstant end)
    assign('QueueMeta', function() return require(ReplicatedStorage.TS.game['queue-meta']).QueueMeta end)
    assign('BedwarsKitMeta', function() return require(ReplicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta end)
    assign('StatusEffectMeta', function() return require(ReplicatedStorage.TS['status-effect']['status-effect-type']).StatusEffectType end)
    assign('GameAnimationUtil', function() return require(ReplicatedStorage.TS.animation['animation-util']).GameAnimationUtil end)
    assign('RuntimeLib', function() return require(ReplicatedStorage.rbxts_include.RuntimeLib) end)
    assign('QueryUtil', function()
        return require(ReplicatedStorage.rbxts_include.node_modules['@easy-games']['game-core'].out).GameQueryUtil
    end)
    assign('SoundManager', function()
        return require(ReplicatedStorage.rbxts_include.node_modules['@easy-games']['game-core'].out).SoundManager
    end)
    assign('SoundList', function() return require(ReplicatedStorage.TS.sound['game-sound']).GameSound end)
    assign('BlockController', function()
        return require(ReplicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out).BlockEngine
    end)
    assign('BlockEngine', function()
        return require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine
    end)
    assign('BlockPlacer', function()
        return require(ReplicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer
    end)
    assign('BlockSelector', function()
        return require(ReplicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.select['block-selector']).BlockSelector
    end)
    assign('AbilityIndicatorUtil', function()
        return require(ReplicatedStorage.TS.games.bedwars.items['ability-indicator']['ability-indicator-util']).AbilityIndicatorUtil
    end)

    local Knit = bedwars.Knit
    if Knit and Knit.Controllers then
        local blockBreak = Knit.Controllers.BlockBreakController
        if blockBreak then bedwars.BlockBreaker = blockBreak.blockBreaker end
        bedwars.ProjectileController = Knit.Controllers.ProjectileController
        bedwars.SprintController = Knit.Controllers.SprintController
        bedwars.SwordController = Knit.Controllers.SwordController
        bedwars.NametagController = Knit.Controllers.NametagController
    end

    if bedwars.InventoryUtil then
        bedwars.getInventory = function(plr)
            local ok, value = pcall(bedwars.InventoryUtil.getInventory, plr)
            return ok and value or {items = {}, armor = {}}
        end
    end

    bedwars.getIcon = function(item, showInventory)
        local meta = item and bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
        return meta and showInventory and meta.image or ''
    end

    if bedwars.SoundManager then
        bedwars.AudioManager = {
            playAudio = function(_, sound, options)
                local method = bedwars.SoundManager.playSound
                if method then return method(bedwars.SoundManager, sound, options) end
            end
        }
    end

    -- Keep the same remote surface used by the direct match modules. A missing remote is retried on
    -- the next lookup rather than cached as permanently unavailable.
    bedwars.Handler = (function()
        local cache = {}
        local api = {}
        function api:Get(remoteName)
            if cache[remoteName] then return cache[remoteName] end
            local ok, remote = pcall(function()
                return bedwars.Client and bedwars.Client:Get(remoteName)
            end)
            remote = ok and remote or nil
            local entry = {
                Remote = remote,
                instance = remote and remote.instance or nil,
                Fire = function(_, method, ...)
                    if not remote then error('remote "'..tostring(remoteName)..'" is unavailable', 0) end
                    local call = remote[method]
                    if not call then error('remote "'..tostring(remoteName)..'" has no '..tostring(method), 0) end
                    return call(remote, ...)
                end
            }
            if remote then cache[remoteName] = entry end
            return entry
        end
        return api
    end)()

    return setmetatable(bedwars, {
        __index = function(self, key)
            local currentKnit = rawget(self, 'Knit')
            local controller = currentKnit and currentKnit.Controllers and currentKnit.Controllers[key]
            if controller ~= nil then
                rawset(self, key, controller)
                return controller
            end
        end
    })
end

return Runtime
