-- AetherV2 BedWars ports derived from the AlSploit implementations requested for PR #144.
-- The original behaviours are adapted to Aether's module lifecycle, entitylib targeting,
-- movement leases, live BedWars controllers and cleanup rules.

local Runtime, ctx = ...
assert(type(Runtime) == 'table', 'AlSploit ports require AetherMatchRuntime')
assert(type(ctx) == 'table', 'AlSploit ports require match context')

local vape = assert(ctx.vape, 'missing vape')
local entitylib = assert(ctx.entitylib, 'missing entitylib')
local bedwars = assert(ctx.bedwars, 'missing bedwars')
local store = assert(ctx.store, 'missing store')
local lplr = assert(ctx.lplr, 'missing local player')
local runService = assert(ctx.runService, 'missing RunService')
local gameCamera = ctx.gameCamera or workspace.CurrentCamera
local remotes = ctx.remotes or {}
local getItem = assert(ctx.getItem, 'missing getItem')
local isnetworkowner = ctx.isnetworkowner or function() return true end
local notif = ctx.notif or function() end
local workspaceService = game:GetService('Workspace')
local teleportService = game:GetService('TeleportService')

local Ports = {Version = 1, Modules = {}, Diagnostics = {}}
Runtime.AlSploitPorts = Ports

local function safe(label, fn, ...)
    if type(fn) ~= 'function' then return false, 'missing function' end
    local ok, result = pcall(fn, ...)
    if not ok then
        Ports.Diagnostics[label] = {At = tick(), Error = tostring(result)}
        return false, result
    end
    return true, result
end

local function notify(text, duration, kind)
    safe('notify', notif, 'AetherV2', text, duration or 3, kind)
end

local function rootOfLocal()
    local char = entitylib.character
    if entitylib.isAlive and char and char.RootPart and char.RootPart.Parent then
        return char.RootPart, char, char.Humanoid
    end
    local character = lplr.Character
    local root = character and (character.PrimaryPart or character:FindFirstChild('HumanoidRootPart'))
    local humanoid = character and character:FindFirstChildOfClass('Humanoid')
    if root and humanoid and humanoid.Health > 0 then return root, character, humanoid end
end

local function matchRunning()
    local match = Runtime.BedWarsAPI and Runtime.BedWarsAPI.Match
    if not match then return store.matchState ~= 0 end
    local state = match:GetState()
    return state == match.States.RUNNING
end

local function equippedKit()
    local kits = Runtime.BedWarsAPI and Runtime.BedWarsAPI.Kits
    if kits then return select(1, kits:GetEquipped()) end
    return store.equippedKit or lplr:GetAttribute('PlayingAsKit')
end

local function horizontalUnit(vector)
    if not vector then return nil end
    local flat = Vector3.new(vector.X, 0, vector.Z)
    return flat.Magnitude > 0.01 and flat.Unit or nil
end

local function moduleByName(name)
    return vape.Modules and vape.Modules[name] or nil
end

local function register(categoryName, name, definition)
    local existing = moduleByName(name)
    if existing then
        Ports.Modules[name] = existing
        Ports.Diagnostics['duplicate.'..name] = {At = tick(), Existing = true}
        return existing, false
    end
    local category = vape.Categories and vape.Categories[categoryName]
    assert(category and type(category.CreateModule) == 'function', 'missing Aether category '..categoryName)
    definition.Name = name
    local module = category:CreateModule(definition)
    Ports.Modules[name] = module
    return module, true
end

local function abilityController()
    return bedwars.AbilityController or (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.AbilityController)
end

local function canUseAbility(name)
    local controller = abilityController()
    if not controller then return false end
    if type(controller.canUseAbility) == 'function' then
        local ok, result = pcall(controller.canUseAbility, controller, name, {disableBlockedAbilityAlert = true})
        if ok then return result ~= false end
    end
    return true
end

local function useAbility(name)
    local controller = abilityController()
    if not controller or type(controller.useAbility) ~= 'function' then return false, 'missing AbilityController' end
    local ok, result = pcall(controller.useAbility, controller, name)
    return ok and result ~= false, result
end

local function nearestTarget(range, includeNPCs)
    local root = rootOfLocal()
    if not root then return nil end
    local ok, target = pcall(entitylib.EntityPosition, {
        Origin = root.Position,
        Range = range,
        Part = 'RootPart',
        Players = true,
        NPCs = includeNPCs and true or false
    })
    return ok and target or nil
end

local function waitCancelable(seconds, cancelled, step)
    local deadline = tick() + seconds
    repeat
        if cancelled and cancelled() then return false end
        task.wait(step or 0.03)
    until tick() >= deadline
    return true
end

local function addMovementOwner(name)
    local movement = Runtime.Movement
    if not movement or not movement.ExternalNames then return end
    if not table.find(movement.ExternalNames, name) then table.insert(movement.ExternalNames, name) end
end

for _, name in ipairs({'JadeExploit', 'AntiHitBETA', 'AntiLagback'}) do addMovementOwner(name) end

--------------------------------------------------------------------------------
-- YaminiExploit
--------------------------------------------------------------------------------
local YaminiExploit
local yaminiCreated
local YaminiOptions = {}
local yaminiGeneration = 0
YaminiExploit, yaminiCreated = register('Exploits', 'YaminiExploit', {
    Tooltip = 'Automatically uses Yamini/Cat pounce while moving when the ability is ready.',
    Function = function(callback)
        yaminiGeneration = yaminiGeneration + 1
        local generation = yaminiGeneration
        if not callback then return end
        task.spawn(function()
            local lastUse = 0
            while YaminiExploit.Enabled and generation == yaminiGeneration do
                local root, _, humanoid = rootOfLocal()
                local kit = tostring(equippedKit() or ''):lower()
                if root and humanoid and matchRunning() and (kit == 'cat' or kit:find('yamini', 1, true)) and humanoid.MoveDirection.Magnitude > 0 then
                    if tick() - lastUse >= 5.2 and canUseAbility('CAT_POUNCE') then
                        local used = useAbility('CAT_POUNCE')
                        if used then lastUse = tick() end
                    end
                end
                task.wait(1 / math.max(YaminiOptions.SpamSpeed.Value, 1))
            end
        end)
    end
})
if yaminiCreated then
    YaminiOptions.SpamSpeed = YaminiExploit:CreateSlider({Name = 'Spam speed', Min = 1, Max = 100, Default = 100, Suffix = ' checks/s'})
end

--------------------------------------------------------------------------------
-- JadeExploit
--------------------------------------------------------------------------------
local JadeExploit
local jadeCreated
local JadeOptions = {}
local jadeGeneration = 0
local jadeBusy = false

local function runJadeExploit(generation)
    if jadeBusy or not Runtime.Jade then return end
    local root, _, humanoid = rootOfLocal()
    if not root or not humanoid or humanoid.MoveDirection.Magnitude <= 0 or not matchRunning() then return end

    local target = JadeOptions.Smash.Enabled and nearestTarget(20, JadeOptions.Entities.Enabled) or nil
    if not target and not JadeOptions.Speed.Enabled then return end

    jadeBusy = true
    local cancelled = function()
        return not JadeExploit.Enabled or generation ~= jadeGeneration or not entitylib.isAlive
    end
    local movement = Runtime.Movement
    local lease
    local ok, err = xpcall(function()
        local hammer = Runtime.Jade:GetBestHammer()
        if not hammer then return end
        local ability = Runtime.Jade:ResolveAbility(hammer)
        local state = Runtime.Jade:GetState(ability)
        if state == 'BLOCKED' then return end

        lease = movement and movement:Acquire('JadeExploit', movement.Priorities.Ability, 3.5, nil, true) or nil
        if movement and not lease then return end
        local equipped = Runtime.Jade:Equip(hammer, 0.8, cancelled)
        if not equipped or cancelled() then return end

        root = rootOfLocal()
        if not root then return end
        if target and target.RootPart and target.RootPart.Parent and JadeOptions.Smash.Enabled then
            if (not movement or movement:CanWrite('JadeExploit')) and isnetworkowner(root) then
                root.CFrame = CFrame.new(root.Position + Vector3.new(0, 150, 0)) * root.CFrame.Rotation
            end
            if not waitCancelable(0.5, cancelled) then return end
            local confirmed = Runtime.Jade:RequestActivation(hammer, ability, target.RootPart.Position, cancelled)
            if not confirmed then return end
            local followUntil = tick() + 2.3
            repeat
                if cancelled() or not target.RootPart or not target.RootPart.Parent then break end
                root = rootOfLocal()
                if not root then break end
                if lease then lease:Renew(0.5) end
                if (not movement or movement:CanWrite('JadeExploit')) and isnetworkowner(root) then
                    local direction = horizontalUnit(target.RootPart.Position - root.Position)
                    if direction then
                        local velocity = root.AssemblyLinearVelocity
                        root.AssemblyLinearVelocity = Vector3.new(direction.X * 23.3, velocity.Y, direction.Z * 23.3)
                    end
                end
                task.wait()
            until tick() >= followUntil
        elseif JadeOptions.Speed.Enabled then
            local direction = horizontalUnit(humanoid.MoveDirection) or horizontalUnit(root.CFrame.LookVector)
            Runtime.Jade:RequestActivation(hammer, ability, root.Position + (direction or Vector3.zAxis) * 20, cancelled)
        end
    end, debug and debug.traceback or tostring)
    if not ok then Ports.Diagnostics.JadeExploit = {At = tick(), Error = tostring(err)} end
    if lease then lease:Release() end
    jadeBusy = false
end

JadeExploit, jadeCreated = register('Exploits', 'JadeExploit', {
    Tooltip = 'Auto-uses Jade hammer movement; Smash tracks nearby targets and Speed uses the hammer for movement.',
    Function = function(callback)
        jadeGeneration = jadeGeneration + 1
        local generation = jadeGeneration
        if not callback then jadeBusy = false; return end
        task.spawn(function()
            local lastUse = 0
            while JadeExploit.Enabled and generation == jadeGeneration do
                if tick() - lastUse >= 6 and not jadeBusy then
                    local hammer = Runtime.Jade and Runtime.Jade:GetBestHammer()
                    if hammer and rootOfLocal() then
                        lastUse = tick()
                        task.spawn(runJadeExploit, generation)
                    end
                end
                task.wait(1 / math.max(JadeOptions.SpamSpeed.Value, 1))
            end
        end)
    end
})
if jadeCreated then
    JadeOptions.SpamSpeed = JadeExploit:CreateSlider({Name = 'Spam speed', Min = 1, Max = 100, Default = 100, Suffix = ' checks/s'})
    JadeOptions.Entities = JadeExploit:CreateToggle({Name = 'Entities', Default = false})
    JadeOptions.Speed = JadeExploit:CreateToggle({Name = 'Speed', Default = false})
    JadeOptions.Smash = JadeExploit:CreateToggle({Name = 'Smash', Default = true})
end

--------------------------------------------------------------------------------
-- Shared visual decoy used by AntiHitBETA and AntiLagback
--------------------------------------------------------------------------------
local function createDecoy(followHorizontal)
    local root, character, humanoid = rootOfLocal()
    if not root or not character or not humanoid then return nil end
    local oldArchivable = character.Archivable
    character.Archivable = true
    local ok, clone = pcall(character.Clone, character)
    character.Archivable = oldArchivable
    if not ok or not clone then return nil end

    for _, object in ipairs(clone:GetDescendants()) do
        if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy() end
        if object:IsA('BasePart') then object.CanCollide = false end
        if object:IsA('BasePart') and object.Name == 'Cape' then object:Destroy() end
    end
    clone.Name = 'AetherMovementDecoy'
    clone.Parent = workspaceService
    local cloneRoot = clone.PrimaryPart or clone:FindFirstChild('HumanoidRootPart')
    local cloneHumanoid = clone:FindFirstChildOfClass('Humanoid')
    if not cloneRoot or not cloneHumanoid then clone:Destroy(); return nil end
    clone.PrimaryPart = cloneRoot
    cloneRoot.Anchored = true
    clone:PivotTo(character:GetPivot())
    local originalSubject = gameCamera.CameraSubject
    gameCamera.CameraSubject = cloneHumanoid

    local decoy = {Model = clone, Root = cloneRoot, Humanoid = cloneHumanoid, OriginalSubject = originalSubject, Connection = nil}
    if followHorizontal then
        decoy.Connection = runService.RenderStepped:Connect(function()
            local liveRoot = rootOfLocal()
            if not clone.Parent or not liveRoot then return end
            cloneRoot.CFrame = CFrame.new(liveRoot.Position.X, cloneRoot.Position.Y, liveRoot.Position.Z) * liveRoot.CFrame.Rotation
        end)
    end
    function decoy:Destroy()
        if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
        if gameCamera.CameraSubject == self.Humanoid then
            local _, _, liveHumanoid = rootOfLocal()
            gameCamera.CameraSubject = (self.OriginalSubject and self.OriginalSubject.Parent and self.OriginalSubject) or liveHumanoid
        end
        if self.Model and self.Model.Parent then self.Model:Destroy() end
        self.Model = nil
    end
    return decoy
end

--------------------------------------------------------------------------------
-- AntiHitBETA
--------------------------------------------------------------------------------
local AntiHitBETA
local antiHitCreated
local AntiHitOptions = {}
local antiHitGeneration = 0
local antiHitBusy = false
local antiHitDecoy

local function currentAttackDelay()
    local held = store.hand
    local meta = held and held.itemType and bedwars.ItemMeta and bedwars.ItemMeta[held.itemType]
    local sword = meta and meta.sword
    return sword and tonumber(sword.attackSpeed) or 0.3
end

local function antiHitCleanup()
    if antiHitDecoy then antiHitDecoy:Destroy(); antiHitDecoy = nil end
    antiHitBusy = false
    local movement = Runtime.Movement
    local current = movement and movement.Current
    if current and current.Owner == 'AntiHitBETA' then current:Release() end
end

local function executeAntiHit(generation)
    if antiHitBusy then return end
    local root = rootOfLocal()
    if not root then return end
    antiHitBusy = true
    local movement = Runtime.Movement
    local lease = movement and movement:Acquire('AntiHitBETA', movement.Priorities.Emergency, 1.5, antiHitCleanup, true) or nil
    if movement and not lease then antiHitBusy = false; return end
    local originalY = root.Position.Y
    antiHitDecoy = createDecoy(true)
    local delay = currentAttackDelay()
    local ok, err = xpcall(function()
        if generation ~= antiHitGeneration or not AntiHitBETA.Enabled then return end
        root = rootOfLocal()
        if not root then return end
        if (not movement or movement:CanWrite('AntiHitBETA')) and isnetworkowner(root) then
            root.CFrame = CFrame.new(root.Position + Vector3.new(0, 25, 0)) * root.CFrame.Rotation
        end
        if not waitCancelable(delay, function() return generation ~= antiHitGeneration or not AntiHitBETA.Enabled end) then return end
        root = rootOfLocal()
        if root and (not movement or movement:CanWrite('AntiHitBETA')) and isnetworkowner(root) then
            root.CFrame = CFrame.new(root.Position.X, originalY + 5, root.Position.Z) * root.CFrame.Rotation
        end
        waitCancelable(delay, function() return generation ~= antiHitGeneration or not AntiHitBETA.Enabled end)
    end, debug and debug.traceback or tostring)
    if not ok then Ports.Diagnostics.AntiHitBETA = {At = tick(), Error = tostring(err)} end
    if antiHitDecoy then antiHitDecoy:Destroy(); antiHitDecoy = nil end
    if lease then lease:Release() end
    antiHitBusy = false
end

AntiHitBETA, antiHitCreated = register('Blatant', 'AntiHitBETA', {
    Tooltip = 'BETA dodge port of AlSploit AntiHit using a short vertical displacement and decoy camera.',
    Function = function(callback)
        antiHitGeneration = antiHitGeneration + 1
        local generation = antiHitGeneration
        if not callback then antiHitCleanup(); return end
        AntiHitBETA:Clean(antiHitCleanup)
        task.spawn(function()
            while AntiHitBETA.Enabled and generation == antiHitGeneration do
                if entitylib.isAlive and matchRunning() and not antiHitBusy then
                    local target = nearestTarget(AntiHitOptions.Range.Value, AntiHitOptions.Entities.Enabled)
                    if target then task.spawn(executeAntiHit, generation) end
                end
                task.wait(0.04)
            end
        end)
    end
})
if antiHitCreated then
    AntiHitOptions.Entities = AntiHitBETA:CreateToggle({Name = 'Entities', Default = false})
    AntiHitOptions.Range = AntiHitBETA:CreateSlider({Name = 'Range', Min = 1, Max = 20, Default = 20, Suffix = ' studs'})
end

--------------------------------------------------------------------------------
-- NoFallDamageV2
--------------------------------------------------------------------------------
local NoFallDamageV2
local noFallCreated
local noFallGeneration = 0
local noFallBusy = false
NoFallDamageV2, noFallCreated = register('Blatant', 'NoFallDamageV2', {
    Tooltip = 'AlSploit-style fall-damage prevention: briefly reports a landed state while preserving downward velocity.',
    Function = function(callback)
        noFallGeneration = noFallGeneration + 1
        local generation = noFallGeneration
        noFallBusy = false
        if not callback then return end
        local connection = runService.PostSimulation:Connect(function()
            if noFallBusy or generation ~= noFallGeneration or not NoFallDamageV2.Enabled then return end
            local highJump = moduleByName('HighJump')
            if highJump and highJump.Enabled then return end
            local root, _, humanoid = rootOfLocal()
            if not root or not humanoid then return end
            local velocity = root.AssemblyLinearVelocity
            if velocity.Y >= -45 then return end
            noFallBusy = true
            task.spawn(function()
                local oldY = velocity.Y
                root = rootOfLocal()
                if not root or generation ~= noFallGeneration or not NoFallDamageV2.Enabled then noFallBusy = false; return end
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 44, root.AssemblyLinearVelocity.Z)
                safe('nofall.landed', humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Landed)
                runService.PreSimulation:Wait()
                root = rootOfLocal()
                if root and generation == noFallGeneration and NoFallDamageV2.Enabled then
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, oldY, root.AssemblyLinearVelocity.Z)
                end
                noFallBusy = false
            end)
        end)
        NoFallDamageV2:Clean(connection)
    end
})

--------------------------------------------------------------------------------
-- InstantWin
--------------------------------------------------------------------------------
local InstantWin
local instantCreated
local instantGeneration = 0
InstantWin, instantCreated = register('World', 'InstantWin', {
    Tooltip = 'Ports the original InstantWin teleport-data rejoin sequence.',
    Function = function(callback)
        instantGeneration = instantGeneration + 1
        local generation = instantGeneration
        if not callback then return end
        task.spawn(function()
            local notified = false
            while InstantWin.Enabled and generation == instantGeneration and not matchRunning() do
                if not notified then notify('Waiting for match to start for InstantWin', 5); notified = true end
                task.wait(0.2)
            end
            if not InstantWin.Enabled or generation ~= instantGeneration then return end
            notify('Starting InstantWin', 3)
            local data
            safe('instantwin.teleportData', function() data = teleportService:GetLocalPlayerTeleportData() end)
            if InstantWin.Enabled then InstantWin:Toggle() end
            safe('instantwin.teleport', teleportService.Teleport, teleportService, game.PlaceId, lplr, data)
        end)
    end
})

--------------------------------------------------------------------------------
-- AntiLagback
--------------------------------------------------------------------------------
local AntiLagback
local antiLagbackCreated
local AntiLagbackOptions = {}
local antiLagbackGeneration = 0
local antiLagbackBusy = false
local antiLagbackDecoy

local function fireRemote(remote, payload)
    if not remote then return false end
    if typeof(remote) == 'Instance' then
        if remote:IsA('RemoteEvent') then return pcall(remote.FireServer, remote, payload) end
        if remote:IsA('RemoteFunction') then return pcall(remote.InvokeServer, remote, payload) end
    end
    for _, method in ipairs({'FireServer', 'SendToServer', 'CallServer', 'InvokeServer'}) do
        if type(remote[method]) == 'function' then
            local ok = pcall(remote[method], remote, payload)
            if ok then return true end
        end
    end
    return false
end

local function voidWalkerRecovery(generation)
    local root = rootOfLocal()
    if not root then return false end
    local direction = horizontalUnit(root.CFrame.LookVector) or Vector3.zAxis
    local remote = remotes.VoidWalker_ClientUsedWarpAbility or bedwars.VoidWalker_ClientUsedWarpAbility
    local payload = {
        clientStartPosition = root.Position + direction * 10,
        direction = direction,
        clientDestinationPosition = root.Position + direction * 5
    }
    fireRemote(remote, payload)
    waitCancelable(0.1, function() return generation ~= antiLagbackGeneration or not AntiLagback.Enabled end)
    useAbility('void_walker_rewind')
    return true
end

local function antiLagbackCleanup()
    if antiLagbackDecoy then antiLagbackDecoy:Destroy(); antiLagbackDecoy = nil end
    antiLagbackBusy = false
    local movement = Runtime.Movement
    local current = movement and movement.Current
    if current and current.Owner == 'AntiLagback' then current:Release() end
end

local function genericLagbackRecovery(generation)
    if antiLagbackBusy then return end
    antiLagbackBusy = true
    local movement = Runtime.Movement
    local lease = movement and movement:Acquire('AntiLagback', movement.Priorities.Emergency, 5, antiLagbackCleanup, true) or nil
    if movement and not lease then antiLagbackBusy = false; return end
    antiLagbackDecoy = createDecoy(false)
    notify('Lagback detected, attempting bypass', 2)
    local start = tick()
    local stableSince
    local ok, err = xpcall(function()
        while AntiLagback.Enabled and generation == antiLagbackGeneration and tick() - start < 4.5 do
            local root, character, humanoid = rootOfLocal()
            if not root or not character or not humanoid or character:FindFirstChildWhichIsA('ForceField') then break end
            if lease then lease:Renew(0.6) end
            local owned = isnetworkowner(root)
            if owned then
                stableSince = stableSince or tick()
                if tick() - stableSince > 0.45 then break end
            else
                stableSince = nil
            end

            local direction
            if AntiLagbackOptions.MovementMethod.Value == 'Manual' then
                direction = horizontalUnit(humanoid.MoveDirection)
            end
            direction = direction or horizontalUnit(gameCamera.CFrame.LookVector)
            if direction and (not movement or movement:CanWrite('AntiLagback')) then
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = antiLagbackDecoy and {character, antiLagbackDecoy.Model} or {character}
                local ahead = root.Position + direction * 5
                local ground = workspaceService:Raycast(ahead, Vector3.new(0, -1000, 0), params)
                local under = workspaceService:Raycast(root.Position - Vector3.new(0, 15, 0) + direction * 5, Vector3.new(0, -1000, 0), params)
                if ground or under then
                    local horizontalSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
                    local step = math.clamp(horizontalSpeed / 16, 0.5, 2.5)
                    root.CFrame = CFrame.new(root.Position + direction * step) * root.CFrame.Rotation
                end
            end
            task.wait()
        end
    end, debug and debug.traceback or tostring)
    if not ok then Ports.Diagnostics.AntiLagback = {At = tick(), Error = tostring(err)} end
    if antiLagbackDecoy then antiLagbackDecoy:Destroy(); antiLagbackDecoy = nil end
    if lease then lease:Release() end
    antiLagbackBusy = false
    if AntiLagback.Enabled and generation == antiLagbackGeneration then notify('Lagback recovery finished', 2) end
end

AntiLagback, antiLagbackCreated = register('Exploits', 'AntiLagback', {
    Tooltip = 'Detects LastTeleported lagbacks and runs a bounded movement/kit recovery path with full cleanup.',
    Function = function(callback)
        antiLagbackGeneration = antiLagbackGeneration + 1
        local generation = antiLagbackGeneration
        if not callback then antiLagbackCleanup(); return end
        AntiLagback:Clean(antiLagbackCleanup)
        local lastHandled = 0
        local connection = lplr:GetAttributeChangedSignal('LastTeleported'):Connect(function()
            if not AntiLagback.Enabled or generation ~= antiLagbackGeneration or tick() - lastHandled < 0.75 then return end
            local _, character = rootOfLocal()
            if not character or not matchRunning() or character:FindFirstChildWhichIsA('ForceField') then return end
            lastHandled = tick()
            task.spawn(function()
                local kit = tostring(equippedKit() or ''):lower()
                if AntiLagbackOptions.KitAntiLagback.Enabled and kit == 'void_walker' then
                    voidWalkerRecovery(generation)
                else
                    genericLagbackRecovery(generation)
                end
            end)
        end)
        AntiLagback:Clean(connection)
    end
})
if antiLagbackCreated then
    AntiLagbackOptions.KitAntiLagback = AntiLagback:CreateToggle({Name = 'Kit anti-lagback', Default = true})
    AntiLagbackOptions.MovementMethod = AntiLagback:CreateDropdown({Name = 'Movement method', List = {'Manual', 'Automatic'}})
    pcall(function() AntiLagbackOptions.MovementMethod:SetValue('Manual') end)
end

return Ports
