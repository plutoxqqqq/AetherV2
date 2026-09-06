run(function()
    local Runtime = assert(AetherMatchRuntime, 'Aether BedWars runtime is unavailable')
    local ctx = AetherRuntimeContext
    local Ports = AetherPortContext
    local safe = aetherPortSafe
    local notify = aetherPortNotify
    local rootOfLocal = aetherPortRoot
    local matchRunning = aetherPortMatchRunning
    local equippedKit = aetherPortEquippedKit
    local horizontalUnit = aetherPortHorizontalUnit
    local moduleByName = aetherPortModule
    local register = aetherPortRegister
    local abilityController = aetherPortAbilityController
    local canUseAbility = aetherPortCanUseAbility
    local useAbility = aetherPortUseAbility
    local nearestTarget = aetherPortNearestTarget
    local waitCancelable = aetherPortWait
    local addMovementOwner = aetherPortAddMovementOwner
    local createDecoy = aetherPortCreateDecoy
    local workspaceService = workspace
local MultiAction, MultiActionActions, MultiActionContexts
local multiActionHooks, multiActionCalls, multiActionLast = {}, {}, {}
local multiActionControllers = {}
local multiActionActionNames = {'Hotbar switching', 'Melee attacking', 'Block placement'}
local multiActionContextNames = {'Projectile charging', 'Consuming', 'Ability aiming'}

local function multiActionSelected(option, name)
    return option and table.find(option.ListEnabled, name) ~= nil
end

local function refreshMultiActionControllers()
    local result, seen = {}, {}
    local function add(name, controller)
        if type(controller) == 'table' and not seen[controller] then
            seen[controller] = true
            table.insert(result, {Name = tostring(name):lower(), Value = controller})
        end
    end
    if bedwars.Knit and bedwars.Knit.Controllers then
        for name, controller in pairs(bedwars.Knit.Controllers) do add(name, controller) end
    end
    for name, controller in pairs(bedwars) do
        if type(name) == 'string' and name:find('Controller') then add(name, controller) end
    end
    add('blockplacer', store.blockPlacer)
    local placement = bedwars.BlockPlacementController
    add('blockplacementcontroller', placement)
    add('blockplacementplacer', placement and placement.blockPlacer)
    multiActionControllers = result
end

local multiActionPatterns = {
    ['Projectile charging'] = {'charg', 'draw', 'projectile'},
    Consuming = {'consum', 'eat', 'drink'},
    ['Ability aiming'] = {'aim', 'targeting'}
}

local function multiActionContextMatches(controllerName, key, context)
    local lower = tostring(key):lower()
    for _, pattern in ipairs(multiActionPatterns[context] or {}) do
        if lower:find(pattern, 1, true) then
            if context ~= 'Projectile charging'
                or controllerName:find('projectile')
                or controllerName:find('bow')
                or controllerName:find('crossbow')
                or lower:find('projectile')
                or lower:find('charg')
                or lower:find('draw') then
                return true
            end
        end
    end
    return false
end

local function multiActionValueActive(value, key)
    if type(value) == 'boolean' then return value end
    if type(value) == 'table' or typeof(value) == 'Instance' then return value ~= nil end
    return type(value) == 'number'
        and tostring(key):lower():find('consum', 1, true)
        and value > 0
        and tick() - value < 30
end

local function collectMultiActionBypasses(action)
    local bypasses, found = {}, {}
    for _, entry in ipairs(multiActionControllers) do
        for key, value in pairs(entry.Value) do
            if type(key) == 'string' then
                for _, context in ipairs(multiActionContextNames) do
                    if multiActionSelected(MultiActionContexts, context)
                        and multiActionContextMatches(entry.Name, key, context)
                        and multiActionValueActive(value, key) then
                        found[entry.Value] = found[entry.Value] or {}
                        table.insert(found[entry.Value], {Key = key, Value = value})
                        break
                    end
                end
            end
        end
    end

    for controller, contextStates in pairs(found) do
        if action ~= 'Hotbar switching' then
            for _, state in ipairs(contextStates) do
                table.insert(bypasses, {
                    Object = controller,
                    Key = state.Key,
                    Value = state.Value,
                    Temporary = type(state.Value) == 'boolean' and false or nil
                })
            end
        end
        for key, value in pairs(controller) do
            local lower = type(key) == 'string' and key:lower() or ''
            if type(value) == 'boolean' and value
                and (lower == 'busy' or lower == 'locked' or lower == 'actionblocked' or lower == 'isbusy') then
                table.insert(bypasses, {Object = controller, Key = key, Value = value, Temporary = false})
            end
        end
    end
    return bypasses
end

local function restoreMultiActionHooks()
    for _, hook in ipairs(multiActionHooks) do
        if hook.Object and hook.Object[hook.Key] == hook.Wrapper then
            hook.Object[hook.Key] = hook.Original
        end
    end
    table.clear(multiActionHooks)
    table.clear(multiActionCalls)
    table.clear(multiActionLast)
end

local function multiActionWithBypass(action, original, ...)
    if not MultiAction.Enabled
        or not multiActionSelected(MultiActionActions, action)
        or multiActionCalls[action] then
        return original(...)
    end
    local currentTime = os.clock()
    if currentTime - (multiActionLast[action] or 0) < 1 / 240 then
        return original(...)
    end
    multiActionLast[action], multiActionCalls[action] = currentTime, true

    local states = collectMultiActionBypasses(action)
    for _, state in ipairs(states) do
        if state.Object[state.Key] == state.Value then
            state.Object[state.Key] = state.Temporary
        end
    end

    local results = table.pack(pcall(original, ...))
    for index = #states, 1, -1 do
        local state = states[index]
        if state.Object[state.Key] == state.Temporary then
            state.Object[state.Key] = state.Value
        end
    end
    multiActionCalls[action] = nil
    if not results[1] then error(results[2], 0) end
    return table.unpack(results, 2, results.n)
end

local function hookMultiAction(object, key, action, predicate)
    if type(object) ~= 'table' or type(object[key]) ~= 'function' then return end
    for _, existing in ipairs(multiActionHooks) do
        if existing.Object == object and existing.Key == key then return end
    end
    local original = object[key]
    local wrapper
    wrapper = function(...)
        if predicate and not predicate(...) then return original(...) end
        return multiActionWithBypass(action, original, ...)
    end
    table.insert(multiActionHooks, {Object = object, Key = key, Original = original, Wrapper = wrapper})
    object[key] = wrapper
end

local function installMultiActionHooks()
    refreshMultiActionControllers()
    local sword = bedwars.SwordController
    hookMultiAction(sword, 'swingSwordAtMouse', 'Melee attacking')
    hookMultiAction(sword, 'swingSwordInRegion', 'Melee attacking')
    hookMultiAction(sword, 'attackEntity', 'Melee attacking')

    local placement = bedwars.BlockPlacementController
    hookMultiAction(placement, 'placeBlock', 'Block placement')
    hookMultiAction(placement and placement.blockPlacer, 'placeBlock', 'Block placement')
    hookMultiAction(store.blockPlacer, 'placeBlock', 'Block placement')

    local storeController = bedwars.Store
    hookMultiAction(storeController, 'dispatch', 'Hotbar switching', function(_, action)
        return type(action) == 'table' and action.type == 'InventorySelectHotbarSlot'
    end)
end

MultiAction = (function()
    local module, created = register('Exploits', 'MultiAction', {
        Tooltip = 'Separates compatible local action locks without changing progress, speed, cooldowns, inputs, or remotes.',
        Function = function(enabled)
            restoreMultiActionHooks()
            if not enabled then return end
            safe('multiaction.install', installMultiActionHooks)

            local nextRefresh = 0
            module:Clean(runService.Heartbeat:Connect(function()
                if tick() >= nextRefresh then
                    nextRefresh = tick() + 1
                    safe('multiaction.refresh', installMultiActionHooks)
                end
            end))
            module:Clean(lplr.CharacterAdded:Connect(function()
                task.defer(function()
                    if module.Enabled then safe('multiaction.character', installMultiActionHooks) end
                end)
            end))
        end
    })
    if created then
        MultiActionActions = module:CreateTextList({
            Name = 'Allowed actions',
            Default = multiActionActionNames,
            Tooltip = 'Enable only Hotbar switching, Melee attacking, or Block placement.'
        })
        MultiActionContexts = module:CreateTextList({
            Name = 'Active contexts',
            Default = multiActionContextNames,
            Tooltip = 'Enable Projectile charging, Consuming, or Ability aiming.'
        })
        module:Clean(function()
            restoreMultiActionHooks()
        end)
    end
    return module
end)()

if type(shared.AetherMultiActionCleanup) == 'function' then
    pcall(shared.AetherMultiActionCleanup)
end
shared.AetherMultiActionCleanup = restoreMultiActionHooks
vape:Clean(function()
    restoreMultiActionHooks()
    if shared.AetherMultiActionCleanup == restoreMultiActionHooks then
        shared.AetherMultiActionCleanup = nil
    end
end)


end)
