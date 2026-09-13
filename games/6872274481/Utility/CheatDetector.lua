run(function()
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    local CheatDetector
    local Toggles = {}

    
    
    local GROUPS = {
        {Name = 'Impossible hits', Children = {'Killaura', 'SilentAim', 'HitBoxes', 'Reach'}},
        {Name = 'Blatant modules', Children = {'PlayerAttach', 'AntiDeath', 'Phase', 'Invisible', 'HighJump', 'Speed'}},
        {Name = 'Bypasses', Children = {'NoFallDamage', 'VoidFlight', 'ExtremeSpeed'}},
        {Name = 'AutoKit'},
        {Name = 'Crashers', Children = {'Animation', 'Remote'}},
        {Name = 'Breaker'},
        {Name = 'ProjectileAimbot and Aura'}
    }

    
    
    
    
    
    local DETECT_SELF = '[TEST] Detect self'

    
    local POLL_INTERVAL = 0.1
    
    
    local STRIKE_MEMORY = 45
    
    
    
    local MAX_PING = 0.3
    
    local TELEPORT_STEP = 100

    
    
    
    
    
    local SPEED_LIMIT = 22
    local SPEED_WINDOW = 1.6
    
    
    
    local SPEED_SANE = 60

    
    
    
    
    local REACH_LIMIT = 15.5

    
    local MIN_HUMAN_INTERVAL = 0.1
    
    
    
    local CADENCE_SAMPLES = 6
    local CADENCE_SPREAD = 0.03
    
    
    
    local BURST_HITS, BURST_WINDOW = 10, 2.5
    
    
    local SWITCH_VICTIMS, SWITCH_WINDOW = 3, 1.2

    
    
    
    local ATTACH_RANGE = 3
    local ATTACH_SAMPLES = 10
    local ATTACH_TRAVEL = 6
    local ATTACH_JITTER = 1.2
    local ATTACH_JUMP = 12
    local ATTACH_RATE = 100

    
    
    local VERTICAL_TELEPORT = 25
    local VERTICAL_RATE = 320
    local VERTICAL_REVERSALS, VERTICAL_MEMORY = 2, 3

    
    
    
    local ANIMATION_FLOOD, ANIMATION_WINDOW = 45, 1
    local REMOTE_FLOOD, REMOTE_WINDOW = 45, 1

    
    
    
    local REQUIRED = {
        Killaura = 3,
        SilentAim = 4,
        HitBoxes = 4,
        Reach = 3,
        PlayerAttach = 2,
        AntiDeath = 2,
        Phase = 6,
        Invisible = 4,
        HighJump = 4,
        Speed = 3,
        NoFallDamage = 3,
        VoidFlight = 2,
        ExtremeSpeed = 2,
        AutoKit = 4,
        Animation = 3,
        Remote = 3,
        Breaker = 4,
        ProjectileAim = 4
    }

    local strikes = {}
    
    
    local lastHurt = {}

    local function enabled(name)
        local toggle = Toggles[name]
        return toggle ~= nil and toggle.Enabled == true
    end

    
    
    local function checkEnabled(group, name)
        if not enabled(group) then return false end
        return group == name or enabled(name)
    end

    
    
    local function selfExcluded(plr)
        return plr == lplr and not enabled(DETECT_SELF)
    end

    
    
    
    
    local function entities()
        if not enabled(DETECT_SELF) or not entitylib.isAlive or not entitylib.character then
            return entitylib.List
        end
        local list = table.clone(entitylib.List)
        table.insert(list, entitylib.character)
        return list
    end

    local function strikeCount(plr, reason)
        local perPlayer = strikes[plr]
        if not perPlayer then return 0 end
        local list = perPlayer[reason]
        if not list then return 0 end
        local now, count = tick(), 0
        for i = #list, 1, -1 do
            if now - list[i] > STRIKE_MEMORY then
                table.remove(list, i)
            else
                count += 1
            end
        end
        return count
    end

    local function Added(player, reason, detail)
        if not CheatersFlagged[player] then
            CheatersFlagged[player] = true
            whitelist.customtags[player.Name] = {{text = 'CHEATER', color = Color3.new(1, 0, 0)}}
            
            
            notif('CheatDetector', `{player.Name} flagged for {reason:lower()}{detail and ' ('..detail..')' or ''}`, 10, 'alert')
        end
    end

    
    
    local function strike(plr, reason, label, detail)
        if not plr or selfExcluded(plr) or CheatersFlagged[plr] then return end
        strikes[plr] = strikes[plr] or {}
        strikes[plr][reason] = strikes[plr][reason] or {}
        table.insert(strikes[plr][reason], tick())
        if strikeCount(plr, reason) >= (REQUIRED[reason] or 5) then
            Added(plr, label or reason, detail)
        end
    end

    local function ping()
        local value = 0
        pcall(function()
            value = lplr:GetNetworkPing()
        end)
        return value
    end

    
    
    
    local function conditionsUsable(plr)
        if plr == lplr then return true end
        return ping() <= MAX_PING
    end

    local function recentlyTeleported(plr)
        return (workspace:GetServerTimeNow() - (plr:GetAttribute('LastTeleported') or 0)) <= 1
    end

    local function correctionContext(plr, char)
        if recentlyTeleported(plr) or not char then return true end
        for name, value in char:GetAttributes() do
            local lowered = tostring(name):lower()
            if value and (lowered:find('teleport') or lowered:find('servercorrect') or lowered:find('respawn') or lowered:find('launch')) then
                if type(value) ~= 'number' or math.abs(workspace:GetServerTimeNow() - value) < 2 then return true end
            end
        end
        local humanoid = char:FindFirstChildOfClass('Humanoid')
        return humanoid and table.find({Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.GettingUp}, humanoid:GetState()) ~= nil
    end

    
    
    
    
    
    
    
    
    local EFFECT_WORDS = {
        Movement = {'speed', 'dash', 'sprint', 'haste', 'boost', 'launch', 'grapple', 'balloon', 'wind', 'momentum', 'charge', 'rush', 'swift', 'leap', 'pounce', 'slide', 'drift', 'frenzy'},
        Vertical = {'jump', 'launch', 'bounce', 'pad', 'grapple', 'balloon', 'levitat', 'fly', 'wind', 'rocket', 'leap', 'pounce'},
        Invisible = {'invis', 'vanish', 'cloak', 'ghost'},
        Ability = {'ability', 'kit_', 'kitability', 'cooldown'}
    }

    
    
    
    local function effectsOf(char)
        local flags = {}
        if not char then return flags end
        for name, value in char:GetAttributes() do
            if type(name) ~= 'string' or value == false or value == 0 then continue end
            local lowered = name:lower()
            for key, words in EFFECT_WORDS do
                if flags[key] then continue end
                for _, word in words do
                    if lowered:find(word, 1, true) then
                        flags[key] = true
                        break
                    end
                end
            end
        end
        return flags
    end

    local function weaponReach(plr)
        local inv = store.inventories[plr]
        local hand = inv and inv.hand
        
        
        
        local itemType = hand and (hand.itemType or (hand.tool and hand.tool.Name))
        local meta = itemType and bedwars.ItemMeta[itemType]
        local sword = meta and meta.sword
        return (sword and sword.attackRange or 14.4)
    end

    
    
    
    local voidCached, voidStamp = -300, 0
    local function voidLevel()
        local now = os.clock()
        if now - voidStamp < 5 then return voidCached end
        voidStamp = now
        local lowest = math.huge
        for _, v in store.blocks do
            local point = (v.Position.Y - (v.Size.Y / 2)) - 50
            if point < lowest then
                lowest = point
            end
        end
        voidCached = lowest < math.huge and lowest or -300
        return voidCached
    end

    
    
    
    
    
    local kitCeilings = {}
    local function speedCeiling(plr)
        local kit = plr:GetAttribute('PlayingAsKits') or plr:GetAttribute('PlayingAsKit')
        if type(kit) ~= 'string' or kit == '' or kit == 'none' then return SPEED_LIMIT end
        local cached = kitCeilings[kit]
        if cached then return cached end

        local multiplier = 1
        pcall(function()
            local meta = bedwars.BedwarsKitMeta and bedwars.BedwarsKitMeta[kit]
            if type(meta) ~= 'table' then return end
            local function scan(tab, depth)
                for key, value in tab do
                    if type(value) == 'number' and type(key) == 'string' then
                        local lowered = key:lower()
                        
                        
                        if lowered:find('speed') and (lowered:find('multiplier') or lowered:find('move')) then
                            multiplier = math.max(multiplier, value)
                        end
                    elseif type(value) == 'table' and depth < 3 then
                        scan(value, depth + 1)
                    end
                end
            end
            scan(meta, 1)
        end)

        local ceiling = SPEED_LIMIT * math.clamp(multiplier, 1, 2)
        kitCeilings[kit] = ceiling
        return ceiling
    end

    
    
    local function bumpRate(store_, key, window)
        local list = store_[key]
        if not list then
            list = {}
            store_[key] = list
        end
        local now = os.clock()
        table.insert(list, now)
        for i = #list, 1, -1 do
            if now - list[i] > window then
                table.remove(list, i)
            end
        end
        return #list
    end

    
    
    
    
    
    
    local animationLast, animationRates, animationHooked = {}, {}, {}
    
    
    
    local animationBacked = 0

    local function watchAnimations(list)
        for _, rec in list do
            local plr = rec.Player
            if animationHooked[plr] == rec.Character then continue end
            local humanoid = rec.Character:FindFirstChildOfClass('Humanoid')
            local animator = humanoid and humanoid:FindFirstChildOfClass('Animator')
            if not animator then continue end
            animationHooked[plr] = rec.Character
            CheatDetector:Clean(animator.AnimationPlayed:Connect(function()
                animationLast[plr] = os.clock()
                if not checkEnabled('Crashers', 'Animation') then return end
                if CheatersFlagged[plr] then return end
                
                
                
                local state = humanoid:GetState()
                if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Landed
                    or math.abs((rec.RootPart and rec.RootPart.AssemblyLinearVelocity.Y) or 0) > 8 then return end
                if bumpRate(animationRates, plr, ANIMATION_WINDOW) >= ANIMATION_FLOOD then
                    animationRates[plr] = nil
                    strike(plr, 'Animation', 'animation spam', `{ANIMATION_FLOOD} animation starts inside {ANIMATION_WINDOW}s`)
                end
            end))
        end
    end

    
    local CHECK_GROUP = {
        Killaura = 'Impossible hits',
        SilentAim = 'Impossible hits',
        HitBoxes = 'Impossible hits',
        Reach = 'Impossible hits',
        PlayerAttach = 'Blatant modules',
        AntiDeath = 'Blatant modules',
        Phase = 'Blatant modules',
        Invisible = 'Blatant modules',
        HighJump = 'Blatant modules',
        Speed = 'Blatant modules',
        NoFallDamage = 'Bypasses',
        VoidFlight = 'Bypasses',
        ExtremeSpeed = 'Bypasses',
        AutoKit = 'AutoKit',
        Animation = 'Crashers',
        Remote = 'Crashers',
        Breaker = 'Breaker',
        ProjectileAim = 'ProjectileAimbot and Aura'
    }
    
    local CHECK_TOGGLE = {
        AutoKit = 'AutoKit',
        Breaker = 'Breaker',
        ProjectileAim = 'ProjectileAimbot and Aura'
    }

    local function wanted(name)
        local group = CHECK_GROUP[name]
        return group ~= nil and checkEnabled(group, CHECK_TOGGLE[name] or name)
    end

    
    
    
    
    
    
    local Pollers = {}

    
    
    
    
    
    
    
    
    Pollers.Speed = function()
        local tracks = {}
        return function(now, list)
            local seen = {}
            for _, rec in list do
                local plr = rec.Player
                seen[plr] = true
                local track = tracks[plr]
                
                
                if not track or track.Character ~= rec.Character then
                    tracks[plr] = {Character = rec.Character, Ceiling = speedCeiling(plr), Position = rec.Flat, Time = now, Distance = 0, Start = now, Samples = 0, Above = 0}
                    continue
                end
                local ceiling = track.Ceiling or SPEED_LIMIT

                local delta = now - track.Time
                local step = (rec.Flat - track.Position).Magnitude
                track.Position, track.Time = rec.Flat, now

                local usable = delta >= 0.05 and delta <= 0.5
                    and step <= TELEPORT_STEP
                    and (step / delta) <= SPEED_SANE
                    and not rec.Teleported
                    and not rec.Effects.Movement
                    and not rec.Hurt
                    and math.abs(rec.Velocity.Y) < 14
                    
                    
                    
                    
                    and (step / delta) > (ceiling * 0.85)
                if not usable then
                    track.Distance, track.Start, track.Samples, track.Above = 0, now, 0, 0
                    continue
                end

                track.Distance += step
                track.Samples += 1
                if (step / delta) > ceiling then
                    track.Above += 1
                end

                local span = now - track.Start
                if span >= SPEED_WINDOW and track.Samples >= 8 then
                    local average = track.Distance / span
                    local share = track.Above / track.Samples
                    track.Distance, track.Start, track.Samples, track.Above = 0, now, 0, 0
                    
                    
                    
                    
                    if average > ceiling and share >= 0.7 then
                        strike(plr, 'Speed', 'speeding', `{math.floor(average)} studs/s held for {math.floor(span * 10) / 10}s, ceiling {math.floor(ceiling)}`)
                    end
                end
            end
            for plr in tracks do
                if not seen[plr] then tracks[plr] = nil end
            end
        end
    end

    
    
    
    
    
    
    Pollers.ExtremeSpeed = function()
        local held = {}
        return function(now, list, delta)
            for _, rec in list do
                local plr = rec.Player
                if rec.Teleported or rec.Effects.Movement or rec.Hurt or not rec.Grounded then
                    held[plr] = nil
                    continue
                end
                local speed = (rec.Velocity * Vector3.new(1, 0, 1)).Magnitude
                if speed > 40 then
                    local entry = held[plr] or {Since = now, Peak = speed}
                    entry.Peak = math.max(entry.Peak, speed)
                    held[plr] = entry
                    if now - entry.Since >= 0.6 then
                        held[plr] = nil
                        strike(plr, 'ExtremeSpeed', 'anticheat bypass', `{math.floor(entry.Peak)} studs/s without a movement effect`)
                    end
                else
                    held[plr] = nil
                end
            end
        end
    end

    Pollers.VoidFlight = function()
        local since = {}
        return function(now, list)
            local floor = voidLevel()
            for _, rec in list do
                local plr = rec.Player
                
                
                
                if rec.Position.Y < floor and rec.Velocity.Y > -35 and not rec.Teleported and not rec.Effects.Vertical then
                    since[plr] = since[plr] or now
                    if now - since[plr] >= 3 then
                        since[plr] = now
                        strike(plr, 'VoidFlight', 'anticheat bypass', 'remained mobile over the void for more than 3s')
                    end
                else
                    since[plr] = nil
                end
            end
        end
    end

    Pollers.NoFallDamage = function()
        local falls = {}
        return function(now, list)
            for _, rec in list do
                local plr = rec.Player
                local fall = falls[plr]
                if rec.Teleported or rec.Effects.Vertical or rec.Effects.Ability then
                    falls[plr] = nil
                    continue
                end
                if not rec.Grounded then
                    fall = fall or {Peak = rec.Position.Y, Lowest = rec.Position.Y, Health = rec.Health}
                    fall.Peak = math.max(fall.Peak, rec.Position.Y)
                    fall.Lowest = math.min(fall.Lowest, rec.Position.Y)
                    fall.Health = math.max(fall.Health, rec.Health)
                    falls[plr] = fall
                elseif fall then
                    local distance = fall.Peak - rec.Position.Y
                    
                    
                    
                    if distance >= 32 then
                        fall.Landed = fall.Landed or now
                        if now - fall.Landed >= 0.8 then
                            if rec.Health >= fall.Health - 1 and not rec.Hurt then
                                strike(plr, 'NoFallDamage', 'no fall damage', `fell {math.floor(distance)} studs without losing health`)
                            end
                            falls[plr] = nil
                        end
                    else
                        falls[plr] = nil
                    end
                end
            end
        end
    end

    
    
    
    
    
    
    
    Pollers.PlayerAttach = function()
        local held, previous = {}, {}
        return function(now, list, delta)
            local seen = {}
            for _, rec in list do
                local plr, position = rec.Player, rec.Position
                seen[plr] = true
                local last = previous[plr]
                
                
                local before = last and last.Character == rec.Character and last.Position or nil
                previous[plr] = {Character = rec.Character, Position = position}

                local nearest, nearestPlr = math.huge, nil
                for _, other in list do
                    if other.Player == plr then continue end
                    local separation = (position - other.Position).Magnitude
                    if separation < nearest then
                        nearest, nearestPlr = separation, other.Player
                    end
                end
                if not nearestPlr then
                    held[plr] = nil
                    continue
                end

                local step = before and (position - before).Magnitude or 0
                
                
                local rate = delta > 0 and (step / delta) or 0
                if before and step > ATTACH_JUMP and rate > ATTACH_RATE and step <= TELEPORT_STEP and nearest <= ATTACH_RANGE * 2 and not rec.Teleported then
                    strike(plr, 'PlayerAttach', 'player attach', `{math.floor(step)} studs onto {nearestPlr.Name} in one step`)
                end

                if nearest > ATTACH_RANGE then
                    held[plr] = nil
                    continue
                end

                local entry = held[plr]
                if not entry or entry.Target ~= nearestPlr then
                    entry = {Target = nearestPlr, Count = 0, Travel = 0, Min = nearest, Max = nearest}
                    held[plr] = entry
                end
                entry.Count += 1
                entry.Travel += step
                entry.Min = math.min(entry.Min, nearest)
                entry.Max = math.max(entry.Max, nearest)
                if entry.Count >= ATTACH_SAMPLES and entry.Travel > ATTACH_TRAVEL and (entry.Max - entry.Min) < ATTACH_JITTER then
                    held[plr] = nil
                    strike(plr, 'PlayerAttach', 'player attach', `rode {nearestPlr.Name} at {math.floor(nearest * 10) / 10} studs`)
                end
            end
            for plr in held do
                if not seen[plr] then held[plr] = nil end
            end
            for plr in previous do
                if not seen[plr] then previous[plr] = nil end
            end
        end
    end

    
    
    
    
    
    
    
    Pollers.AntiDeath = function()
        local tracks = {}
        return function(now, list, delta)
            local floor = voidLevel()
            local seen = {}
            for _, rec in list do
                local plr, position = rec.Player, rec.Position
                seen[plr] = true
                local track = tracks[plr]
                if not track or track.Character ~= rec.Character then
                    tracks[plr] = {Character = rec.Character, Y = position.Y, Flat = rec.Flat, Below = position.Y < floor, Crossings = {}, Direction = 0, Reversals = {}}
                    continue
                end

                local rise = position.Y - track.Y
                local flatStep = (rec.Flat - track.Flat).Magnitude
                track.Y, track.Flat = position.Y, rec.Flat

                local below = position.Y < floor
                if rec.Teleported or delta <= 0 then
                    track.Below = below
                    continue
                end
                
                
                
                if math.abs(rise) < VERTICAL_TELEPORT or (math.abs(rise) / delta) < VERTICAL_RATE or flatStep > 15 then
                    track.Below = below
                    continue
                end

                if below ~= track.Below then
                    table.insert(track.Crossings, {Time = now, Below = below})
                    for i = #track.Crossings, 1, -1 do
                        if now - track.Crossings[i].Time > VERTICAL_MEMORY then
                            table.remove(track.Crossings, i)
                        end
                    end
                    local alternating = 0
                    for i = 2, #track.Crossings do
                        if track.Crossings[i].Below ~= track.Crossings[i - 1].Below then
                            alternating += 1
                        end
                    end
                    if alternating >= 3 then
                        table.clear(track.Crossings)
                        strike(plr, 'AntiDeath', 'anti death', 'repeatedly teleported to and from below the map')
                    end
                end
                track.Below = below

                local direction = rise > 0 and 1 or -1
                if track.Direction ~= 0 and direction ~= track.Direction then
                    table.insert(track.Reversals, now)
                end
                track.Direction = direction
                for i = #track.Reversals, 1, -1 do
                    if now - track.Reversals[i] > VERTICAL_MEMORY then
                        table.remove(track.Reversals, i)
                    end
                end
                if #track.Reversals >= VERTICAL_REVERSALS then
                    table.clear(track.Reversals)
                    track.Direction = 0
                    strike(plr, 'AntiDeath', 'anti death', `hitbox thrown {math.floor(math.abs(rise))} studs up and down`)
                end
            end
            for plr in tracks do
                if not seen[plr] then tracks[plr] = nil end
            end
        end
    end

    
    
    
    
    
    
    
    
    Pollers.Phase = function()
        local buried = {}
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        local skip = 0
        return function(now, list)
            skip += 1
            if skip % 3 ~= 0 then return end
            local seen = {}
            for _, rec in list do
                local plr = rec.Player
                seen[plr] = true
                if rec.Teleported or rec.Effects.Movement then
                    buried[plr] = nil
                    continue
                end

                overlap.FilterDescendantsInstances = {rec.Character, lplr.Character, gameCamera}
                
                
                local parts = workspace:GetPartBoundsInBox(CFrame.new(rec.Position), Vector3.new(1, 1, 1), overlap)
                local solid = false
                for _, part in parts do
                    if part.CanCollide and part.Anchored then
                        solid = true
                        break
                    end
                end

                if solid then
                    buried[plr] = (buried[plr] or 0) + 1
                    if buried[plr] >= 4 then
                        buried[plr] = 0
                        strike(plr, 'Phase', 'phasing', 'stood inside a solid block')
                    end
                else
                    buried[plr] = nil
                end
            end
            for plr in buried do
                if not seen[plr] then buried[plr] = nil end
            end
        end
    end

    
    
    
    
    
    
    Pollers.Invisible = function()
        local hidden = {}
        local skip = 0
        return function(now, list)
            
            
            skip += 1
            if skip % 5 ~= 0 then return end
            local seen = {}
            for _, rec in list do
                local plr = rec.Player
                seen[plr] = true
                if rec.Effects.Invisible or rec.Velocity.Magnitude < 4 then
                    hidden[plr] = nil
                    continue
                end

                local visible, counted = false, 0
                for _, part in rec.Character:GetDescendants() do
                    if part:IsA('BasePart') and part.Name ~= 'HumanoidRootPart' then
                        counted += 1
                        if part.Transparency < 0.95 then
                            visible = true
                            break
                        end
                    end
                end

                
                
                if counted >= 4 and not visible then
                    hidden[plr] = (hidden[plr] or 0) + 1
                    if hidden[plr] >= 3 then
                        hidden[plr] = 0
                        strike(plr, 'Invisible', 'invisibility', 'moving with every limb hidden')
                    end
                else
                    hidden[plr] = nil
                end
            end
            for plr in hidden do
                if not seen[plr] then hidden[plr] = nil end
            end
        end
    end

    
    
    
    
    
    
    Pollers.HighJump = function()
        local tracked = {}
        return function(now, list)
            local seen = {}
            for _, rec in list do
                local plr = rec.Player
                seen[plr] = true
                if rec.Teleported or rec.Effects.Vertical or rec.Hurt then
                    tracked[plr] = nil
                    continue
                end

                local y = rec.Position.Y
                local entry = tracked[plr]
                if rec.Grounded then
                    tracked[plr] = {Base = y, Peak = y}
                elseif entry then
                    entry.Peak = math.max(entry.Peak, y)
                    
                    
                    
                    if (entry.Peak - entry.Base) > 18 then
                        tracked[plr] = nil
                        strike(plr, 'HighJump', 'high jump', `rose {math.floor(entry.Peak - entry.Base)} studs off one jump`)
                    end
                end
            end
            for plr in tracked do
                if not seen[plr] then tracked[plr] = nil end
            end
        end
    end

    
    
    
    
    
    
    Pollers.AutoKit = function()
        local activations, previous = {}, {}
        return function(now, list)
            local seen = {}
            for _, rec in list do
                local plr = rec.Player
                seen[plr] = true
                local active = rec.Effects.Ability
                local was = previous[plr]
                previous[plr] = active
                if not active or was then continue end

                
                local times = activations[plr]
                if not times then
                    times = {}
                    activations[plr] = times
                end
                table.insert(times, now)
                if #times > 6 then
                    table.remove(times, 1)
                end
                if #times < 6 then continue end

                local shortest, longest = math.huge, 0
                for i = 2, #times do
                    local gap = times[i] - times[i - 1]
                    shortest = math.min(shortest, gap)
                    longest = math.max(longest, gap)
                end
                
                
                if (longest - shortest) < 0.1 and longest < 30 then
                    table.clear(times)
                    strike(plr, 'AutoKit', 'automated kit use', `5 activations {math.floor(longest * 100) / 100}s apart`)
                end
            end
            for plr in activations do
                if not seen[plr] then
                    activations[plr] = nil
                    previous[plr] = nil
                end
            end
        end
    end

    
    
    
    
    
    local Events = {}

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    Events.Killaura = function()
        local last, intervals, victims, hits, quiet = {}, {}, {}, {}, {}

        CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
            if not wanted('Killaura') then return end
            if damageTable.damageType ~= 0 or not damageTable.fromEntity then return end

            local from = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
            if not from or selfExcluded(from) or CheatersFlagged[from] then return end
            if not conditionsUsable(from) then return end

            local victim = damageTable.entityInstance and playersService:GetPlayerFromCharacter(damageTable.entityInstance)
            local now = os.clock()

            
            if (now - (animationLast[from] or 0)) <= 0.4 then
                animationBacked += 1
                quiet[from] = 0
            elseif animationBacked >= 5 then
                quiet[from] = (quiet[from] or 0) + 1
                if quiet[from] >= 6 then
                    quiet[from] = 0
                    strike(from, 'Killaura', 'using killaura', '6 hits with no swing behind them')
                end
            end

            
            if victim then
                local seen = victims[from]
                if not seen then
                    seen = {}
                    victims[from] = seen
                end
                seen[victim] = now
                local distinct = 0
                for plr, stamp in seen do
                    if now - stamp > SWITCH_WINDOW then
                        seen[plr] = nil
                    else
                        distinct += 1
                    end
                end
                if distinct >= SWITCH_VICTIMS then
                    table.clear(seen)
                    strike(from, 'Killaura', 'using killaura', `{distinct} different targets inside {SWITCH_WINDOW}s`)
                end
            end

            local previous = last[from]
            last[from] = now
            if not previous then return end

            local interval = now - previous
            
            
            
            if interval <= 0.008 then return end

            if interval < MIN_HUMAN_INTERVAL then
                strike(from, 'Killaura', 'using killaura', `hits {math.floor(interval * 1000)}ms apart`)
                return
            end

            
            if bumpRate(hits, from, BURST_WINDOW) >= BURST_HITS then
                hits[from] = nil
                strike(from, 'Killaura', 'using killaura', `{BURST_HITS} hits inside {BURST_WINDOW}s`)
            end

            
            
            local run = intervals[from]
            if not run then
                run = {}
                intervals[from] = run
            end
            if interval > 0.6 then
                table.clear(run)
                return
            end
            table.insert(run, interval)
            if #run > CADENCE_SAMPLES then
                table.remove(run, 1)
            end
            if #run < CADENCE_SAMPLES then return end

            local shortest, longest = math.huge, 0
            for _, value in run do
                shortest = math.min(shortest, value)
                longest = math.max(longest, value)
            end
            if (longest - shortest) <= CADENCE_SPREAD then
                table.clear(run)
                strike(from, 'Killaura', 'using killaura', `{CADENCE_SAMPLES} hits {math.floor(shortest * 1000)}ms apart to the millisecond`)
            end
        end))
    end

    
    
    
    
    
    
    
    
    Events.Reach = function()
        CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
            if not wanted('Reach') then return end
            if damageTable.damageType ~= 0 or not damageTable.fromEntity or not damageTable.entityInstance then return end

            local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
            if not attacker or selfExcluded(attacker) or CheatersFlagged[attacker] then return end
            if not conditionsUsable(attacker) or recentlyTeleported(attacker) then return end

            local fromRoot = damageTable.fromEntity.PrimaryPart
            local toRoot = damageTable.entityInstance.PrimaryPart
            if not fromRoot or not toRoot then return end

            local distance = (fromRoot.Position - toRoot.Position).Magnitude
            
            
            local allowance = math.clamp(ping() * 20, 0, 3)
            local limit = math.max(weaponReach(attacker) + 1.1, REACH_LIMIT) + allowance

            if distance > limit then
                strike(attacker, 'Reach', 'using reach', `{math.floor(distance * 10) / 10} studs, limit {math.floor(limit * 10) / 10}`)
            end
        end))
    end

    
    
    
    
    
    
    
    
    Events.HitBoxes = function()
        CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
            if not wanted('HitBoxes') then return end
            if damageTable.damageType ~= 0 or not damageTable.fromEntity or not damageTable.entityInstance then return end

            local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
            if not attacker or selfExcluded(attacker) or CheatersFlagged[attacker] then return end
            if not conditionsUsable(attacker) or recentlyTeleported(attacker) then return end

            local fromRoot = damageTable.fromEntity.PrimaryPart
            local toRoot = damageTable.entityInstance.PrimaryPart
            if not fromRoot or not toRoot then return end

            local delta = (toRoot.Position - fromRoot.Position)
            local distance = delta.Magnitude
            
            
            if distance < 6 or distance > REACH_LIMIT then return end

            local facing = fromRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
            local toward = delta * Vector3.new(1, 0, 1)
            if facing.Magnitude < 0.01 or toward.Magnitude < 0.01 then return end

            local angle = math.deg(math.acos(math.clamp(facing.Unit:Dot(toward.Unit), -1, 1)))
            
            
            
            if angle > 70 then
                strike(attacker, 'HitBoxes', 'expanded hitboxes', `hit {math.floor(angle)} degrees off target`)
            end
        end))
    end

    
    
    
    
    
    
    Events.SilentAim = function()
        CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
            if not wanted('SilentAim') then return end
            if damageTable.damageType == 0 or not damageTable.fromEntity or not damageTable.entityInstance then return end

            local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
            if not attacker or selfExcluded(attacker) or CheatersFlagged[attacker] then return end
            if not conditionsUsable(attacker) or recentlyTeleported(attacker) then return end

            local fromRoot = damageTable.fromEntity.PrimaryPart
            local toRoot = damageTable.entityInstance.PrimaryPart
            if not fromRoot or not toRoot then return end

            local delta = (toRoot.Position - fromRoot.Position) * Vector3.new(1, 0, 1)
            
            
            if delta.Magnitude < 25 then return end

            local facing = fromRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
            if facing.Magnitude < 0.01 then return end

            local angle = math.deg(math.acos(math.clamp(facing.Unit:Dot(delta.Unit), -1, 1)))
            if angle > 50 then
                strike(attacker, 'SilentAim', 'silent aim', `landed a shot {math.floor(angle)} degrees off their heading`)
            end
        end))
    end

    
    
    
    
    
    Events.ProjectileAim = function()
        local hits = {}
        CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
            if not wanted('ProjectileAim') then return end
            if damageTable.damageType == 0 or not damageTable.fromEntity or not damageTable.entityInstance then return end

            local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
            local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
            
            if not attacker or not victim or selfExcluded(attacker) or CheatersFlagged[attacker] then return end
            if not conditionsUsable(attacker) then return end

            local fromRoot = damageTable.fromEntity.PrimaryPart
            local toRoot = damageTable.entityInstance.PrimaryPart
            if not fromRoot or not toRoot then return end
            if (toRoot.Position - fromRoot.Position).Magnitude < 30 then return end

            
            
            if bumpRate(hits, attacker, 6) >= 4 then
                hits[attacker] = nil
                strike(attacker, 'ProjectileAim', 'projectile aimbot', '4 long-range projectile hits inside 6s')
            end
        end))
    end

    
    
    
    
    
    Events.Breaker = function()
        local rates = {}
        CheatDetector:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(data)
            if not wanted('Breaker') then return end
            local plr = data.player
            if not plr or selfExcluded(plr) or CheatersFlagged[plr] then return end
            if not conditionsUsable(plr) then return end

            local blockPosition = data.blockRef and data.blockRef.blockPosition
            if typeof(blockPosition) == 'Vector3' then
                local root
                for _, ent in entities() do
                    if ent.Player == plr then
                        root = ent.RootPart
                        break
                    end
                end
                if root and root.Parent then
                    local distance = (root.Position - (blockPosition * 3)).Magnitude
                    
                    if distance > 45 and not recentlyTeleported(plr) then
                        strike(plr, 'Breaker', 'block breaker', `broke a block {math.floor(distance)} studs away`)
                        return
                    end
                end
            end

            
            
            
            if bumpRate(rates, plr, 2) >= 12 then
                rates[plr] = nil
                strike(plr, 'Breaker', 'block breaker', '12 blocks broken inside 2s')
            end
        end))
    end

    
    
    
    
    
    
    
    
    Events.Remote = function()
        local rates = {}

        local function count(plr)
            if not wanted('Remote') then return end
            if not plr or selfExcluded(plr) or CheatersFlagged[plr] then return end
            if bumpRate(rates, plr, REMOTE_WINDOW) >= REMOTE_FLOOD then
                rates[plr] = nil
                strike(plr, 'Remote', 'remote spam', `{REMOTE_FLOOD} replicated actions inside {REMOTE_WINDOW}s`)
            end
        end

        CheatDetector:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(data)
            count(data.player)
        end))
        CheatDetector:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(function(data)
            count(data and data.player)
        end))
        CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
            if not damageTable.fromEntity then return end
            count(playersService:GetPlayerFromCharacter(damageTable.fromEntity))
        end))
    end

    
    
    
    local function snapshot(now)
        local list = {}
        for _, ent in entities() do
            local plr, root, char = ent.Player, ent.RootPart, ent.Character
            if not plr or selfExcluded(plr) or CheatersFlagged[plr] then continue end
            if not root or not root.Parent or not char then continue end
            if (ent.Health or 0) <= 0 then continue end

            local position = root.Position
            local effects = effectsOf(char)
            if tostring(store.queueType):lower():find('custom') then effects.Ability = true end
            table.insert(list, {
                Player = plr,
                Character = char,
                Root = root,
                Position = position,
                Flat = position * Vector3.new(1, 0, 1),
                Velocity = root.AssemblyLinearVelocity,
                Grounded = (ent.Humanoid and ent.Humanoid.FloorMaterial ~= Enum.Material.Air) or false,
                Effects = effects,
                Teleported = correctionContext(plr, char),
                Hurt = (now - (lastHurt[plr] or 0)) < 1.5,
                Health = ent.Health or (ent.Humanoid and ent.Humanoid.Health) or 0
            })
        end
        return list
    end

    CheatDetector = vape.Categories.Utility:CreateModule({
        Name = 'CheatDetector',
        Function = function(callback)
            if callback then
                table.clear(strikes)
                table.clear(lastHurt)
                table.clear(animationLast)
                table.clear(animationRates)
                table.clear(animationHooked)
                animationBacked = 0
                voidStamp = 0

                
                CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    local victim = damageTable.entityInstance and playersService:GetPlayerFromCharacter(damageTable.entityInstance)
                    if victim then
                        lastHurt[victim] = tick()
                    end
                end))

                
                
                
                
                
                for name, event in Events do
                    local ok, err = pcall(event)
                    if not ok then
                        warn('[AetherV2] CheatDetector '..name..': '..tostring(err))
                    end
                end

                local running = {}
                for name, poller in Pollers do
                    local ok, fn = pcall(poller)
                    if ok and type(fn) == 'function' then
                        running[name] = fn
                    else
                        warn('[AetherV2] CheatDetector '..name..': '..tostring(fn))
                    end
                end

                local last = tick()
                repeat
                    local now = tick()
                    local delta = now - last
                    last = now

                    
                    
                    local watching = wanted('Animation') or wanted('Killaura')
                    local polling = false
                    for name in running do
                        if wanted(name) then
                            polling = true
                            break
                        end
                    end

                    if watching or polling then
                        
                        
                        local taken, list = pcall(snapshot, now)
                        if taken and #list > 0 then
                            if watching then
                                pcall(watchAnimations, list)
                            end
                            for name, fn in running do
                                if not wanted(name) then continue end
                                local ok, err = pcall(fn, now, list, delta)
                                if not ok then
                                    warn('[AetherV2] CheatDetector '..name..': '..tostring(err))
                                end
                            end
                        end
                    end

                    task.wait(POLL_INTERVAL)
                until not CheatDetector.Enabled
            else
                table.clear(strikes)
                table.clear(lastHurt)
                table.clear(animationLast)
                table.clear(animationRates)
                table.clear(animationHooked)
                animationBacked = 0
            end
        end,
        Tooltip = 'Alerts for likely cheaters. Every detection needs several impossible readings, and ignores ones taken on a poor connection'
    })

    local GROUP_TOOLTIPS = {
        ['Impossible hits'] = 'Hits that cannot have been aimed or thrown by hand: killaura, silent aim, expanded hitboxes, reach past any weapon',
        ['Blatant modules'] = 'Movement and state nobody can produce by playing: attach, anti death, phase, invisibility, high jump, speed',
        ['Bypasses'] = 'Outcome-based checks for impossible movement, sustained void flight, and suppressed fall damage',
        ['AutoKit'] = 'Kit abilities fired on a fixed interval, the regularity no hand holds',
        ['Crashers'] = 'Floods meant to bury other clients - animations or replicated actions many times a second',
        ['Breaker'] = 'Blocks broken faster than a tool swings, or from across the map',
        ['ProjectileAimbot and Aura'] = 'Long-range projectiles landing on players faster than a bow can be drawn and aimed'
    }
    local CHILD_TOOLTIPS = {
        Killaura = 'Hit rate, an unvarying cadence, several targets at once, or damage with no swing behind it',
        SilentAim = 'Shots landing on someone the shooter was not pointing at',
        HitBoxes = 'Melee landing while facing well off the body being drawn',
        Reach = 'Hits landing past 15.5 studs, further than any sword in the game swings',
        PlayerAttach = 'Teleporting onto a player, or riding them with the gap between you barely moving',
        AntiDeath = 'Repeated impossible teleports to and from below the map, or rapid vertical reversals faster than gravity',
        Phase = 'The body stood inside solid geometry across consecutive samples',
        Invisible = 'Moving with every limb hidden and no invisibility effect of their own',
        HighJump = 'Rising far past jump power off one jump, with no launch or ability effect',
        Speed = 'Ground speed held past 22 studs/s - or past whatever the kit\'s own metadata says it is worth - with potions, dashes and knockback excluded',
        NoFallDamage = 'Falls over 32 studs that settle without health loss; teleports, kit abilities, launches and vertical effects are excluded',
        VoidFlight = 'A player held or moving below all playable ground for more than three seconds instead of naturally falling',
        ExtremeSpeed = 'Sustained movement over 40 studs/s without a kit movement effect, knockback, teleport, or launch',
        Animation = 'Animation starts many times a second, far past anything play produces',
        Remote = 'Replicated actions - places, breaks, hits - many times a second'
    }

    for _, group in GROUPS do
        Toggles[group.Name] = CheatDetector:CreateToggle({
            Name = group.Name,
            Default = true,
            Tooltip = GROUP_TOOLTIPS[group.Name],
            Function = function(callback)
                for _, child in (group.Children or {}) do
                    local toggle = Toggles[child]
                    if toggle and toggle.Object then
                        toggle.Object.Visible = callback
                    end
                end
            end
        })
        for _, child in (group.Children or {}) do
            Toggles[child] = CheatDetector:CreateToggle({
                Name = child,
                Default = true,
                Darker = true,
                Tooltip = CHILD_TOOLTIPS[child]
            })
        end
    end

    
    
    
    Toggles[DETECT_SELF] = CheatDetector:CreateToggle({
        Name = DETECT_SELF,
        Tooltip = 'Testing aid. Runs every enabled detection against you as well, on your behaviour alone - it never looks at which of your modules are on - and flags you like anyone else if one of them fires',
        Function = function()
            
            
            strikes[lplr] = nil
        end
    })
end)
