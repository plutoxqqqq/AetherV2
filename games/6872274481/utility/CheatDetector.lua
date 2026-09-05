run(function()
    -- CheatDetector
    --
    -- Everything here is measured through our own connection, which is the whole problem: what we
    -- see is a lagged, interpolated copy of what the server actually resolved. So every check is
    -- built the same way - a reading only counts when it is impossible rather than merely
    -- surprising, readings taken through bad conditions are thrown away instead of counted, and
    -- nobody is flagged until several independent readings of the same kind have stacked up.
    --
    -- Nothing here looks at what anybody is RUNNING. There is no module list, no remote name and
    -- no signature to keep up to date - every check reads position, timing and replicated state,
    -- which is all a cheat can never hide, because the whole point of a cheat is that the server
    -- and everyone else can see what it did.
    --
    -- One loop does all the polling. Each position-based check is a function fed the same
    -- once-per-tick snapshot of every player rather than its own thread walking the entity list,
    -- so the cost of the module is one pass over the players every tenth of a second no matter
    -- how many checks are ticked on.
    local CheatDetector
    local Toggles = {}

    -- Detections, in the order they are offered. A group with children is a heading: its own
    -- toggle gates the whole family, and the children pick which of them run.
    local GROUPS = {
        {Name = 'Impossible hits', Children = {'Killaura', 'SilentAim', 'HitBoxes', 'Reach'}},
        {Name = 'Blatant modules', Children = {'PlayerAttach', 'AntiDeath', 'Phase', 'Invisible', 'HighJump', 'Speed'}},
        {Name = 'Bypasses', Children = {'NoFallDamage', 'VoidFlight', 'ExtremeSpeed'}},
        {Name = 'AutoKit'},
        {Name = 'Crashers', Children = {'Animation', 'Remote'}},
        {Name = 'Breaker'},
        {Name = 'ProjectileAimbot and Aura'}
    }

    -- Off by default, and deliberately named so nobody leaves it on by accident. Every check below
    -- is written to read somebody else's replicated state, and the local player is normally exempt
    -- from all of them; this lifts that exemption so the detector measures us too. It changes who
    -- is looked at and nothing else - the checks still read behaviour, never which of our own
    -- modules happen to be on, so a flag here means the cheat was actually visible from outside.
    local DETECT_SELF = '[TEST] Detect self'

    -- How often every position-based check gets its sample.
    local POLL_INTERVAL = 0.1
    -- A strike older than this is forgotten. Long enough that a cheat running all match keeps
    -- stacking up, short enough that unrelated anomalies minutes apart never add together.
    local STRIKE_MEMORY = 45
    -- Nothing is measured through a connection worse than this. Above it, event timings and
    -- replicated positions are both fiction and every check would be reading noise. Our own
    -- behaviour is exempt: there is no network between us and our own character.
    local MAX_PING = 0.3
    -- A position step larger than this is streaming, a respawn or a real teleport, never movement.
    local TELEPORT_STEP = 100

    -- Speed. Sprint in this game is 20 studs/s and every legitimate way past that - a potion, a
    -- kit dash, a launch pad - is either a burst that decays within a second or announces itself
    -- through a status effect. So the limit is only a little over sprint, and what makes it safe
    -- is that it has to be HELD: the average has to stay over it across a continuous run of
    -- movement, which a dash, a pounce, a grapple or a knockback cannot do.
    local SPEED_LIMIT = 22
    local SPEED_WINDOW = 1.6
    -- No single sample above this is movement at all - it is a respawn, a streaming pop or a
    -- teleport that did not set the attribute. Counting one of those into a run is how a player
    -- who then simply sprints away gets flagged for it, so a sample this size ends the run.
    local SPEED_SANE = 60

    -- Reach. Every sword in the game swings 14.4 studs or less, so a hit landing past this is
    -- past the weapon whatever is being held. This is the one number that catches an aura built
    -- to fake its own position: the fake goes in the packet, but the body everyone else sees
    -- stays where it really is, and that is what gets measured here.
    local REACH_LIMIT = 15.5

    -- Killaura. No hand clicks faster than this, whatever the CPS cap says.
    local MIN_HUMAN_INTERVAL = 0.1
    -- An aura fires the instant the swing cooldown is up, every time, so the gaps between its
    -- hits stop varying. A hand saturating the same cooldown still scatters by tens of
    -- milliseconds, so the window is deliberately tighter than human jitter.
    local CADENCE_SAMPLES = 6
    local CADENCE_SPREAD = 0.03
    -- Sustained rate. A sword is on a cooldown near three tenths of a second, so even a hand
    -- that never misses and never stops cannot land four a second - which is where this sits,
    -- deliberately above the fastest legitimate weapon rather than at the pace of a fast mouse.
    local BURST_HITS, BURST_WINDOW = 10, 2.5
    -- Aura targeting: hitting this many different players inside the window means the aim moved
    -- between them instantly, which is the one signature clicking quickly cannot produce.
    local SWITCH_VICTIMS, SWITCH_WINDOW = 3, 1.2

    -- PlayerAttach. Riding somebody puts you inside arm's length of them and holds you there,
    -- with the separation barely moving, while the pair of you travel. Getting there is a jump
    -- no run can make.
    local ATTACH_RANGE = 3
    local ATTACH_SAMPLES = 10
    local ATTACH_TRAVEL = 6
    local ATTACH_JITTER = 1.2
    local ATTACH_JUMP = 12
    local ATTACH_RATE = 100

    -- AntiDeath. Parking the hitbox out of reach and bringing it back is a vertical step no fall
    -- produces: free fall tops out near 200 studs/s, so anything past this was set, not fallen.
    local VERTICAL_TELEPORT = 25
    local VERTICAL_RATE = 320
    local VERTICAL_REVERSALS, VERTICAL_MEMORY = 2, 3

    -- Crashers are floods, and the bar has to sit well above a player having a busy second -
    -- jumping while spamming a sword throws out a surprising number of both animations and
    -- replicated actions. These are per SECOND, not per three.
    local ANIMATION_FLOOD, ANIMATION_WINDOW = 45, 1
    local REMOTE_FLOOD, REMOTE_WINDOW = 45, 1

    -- How many readings of one kind before a player is flagged. Set per check rather than shared:
    -- a Reach reading is one clean measurement, a Phase reading is a guess about geometry we only
    -- half see, and they cannot sensibly share a threshold.
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
    -- When each player last took a hit. Knockback throws people faster than they can run, so a
    -- speed sample taken just after one measures the hit, not the player.
    local lastHurt = {}

    local function enabled(name)
        local toggle = Toggles[name]
        return toggle ~= nil and toggle.Enabled == true
    end

    -- A child check runs only while its heading is on as well, so switching a family off switches
    -- off everything under it without disturbing which children were picked.
    local function checkEnabled(group, name)
        if not enabled(group) then return false end
        return group == name or enabled(name)
    end

    -- The one place the self exemption is decided. Checks ask this instead of comparing against
    -- lplr themselves, so the toggle reaches all of them at once and nothing is left half exempt.
    local function selfExcluded(plr)
        return plr == lplr and not enabled(DETECT_SELF)
    end

    -- entitylib keeps our own entity apart from the rest - entitylib.List is everyone but us - so a
    -- check that walks the list can never see the local player no matter what the guards say. This
    -- hands back that same list with our entity on the end while the toggle is on, which is what
    -- lets the polling checks read us without each of them knowing where our entity is kept.
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
            -- Say what was actually measured, not just which check fired. A flag you cannot
            -- sanity-check yourself is a flag you have to take on trust.
            notif('CheatDetector', `{player.Name} flagged for {reason:lower()}{detail and ' ('..detail..')' or ''}`, 10, 'alert')
        end
    end

    -- One reading is an oddity, several is a pattern. Nothing reaches Added until the pattern is
    -- there, at whatever count this particular check needs to be worth trusting.
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

    -- Our own connection is the measuring instrument. When it is bad, every reading of somebody
    -- else is wrong in a direction that produces false positives, so we take none at all. Nothing
    -- sits between us and our own character, so measuring ourselves is always allowed.
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

    ------------------------------------------------------------------------
    -- Status effects.
    ------------------------------------------------------------------------
    -- Kits are the reason speed and jump checks need this. A kit that is MEANT to move you fast -
    -- a reaper's drift, a dash, a wind push - replicates a status attribute onto the character
    -- while it is doing it, so the sample is thrown away rather than counted. Matched on what the
    -- effect is called rather than on a list of kits, so a kit added next update is covered by
    -- the words it uses, and a kit renamed does not quietly become undetectable.
    local EFFECT_WORDS = {
        Movement = {'speed', 'dash', 'sprint', 'haste', 'boost', 'launch', 'grapple', 'balloon', 'wind', 'momentum', 'charge', 'rush', 'swift', 'leap', 'pounce', 'slide', 'drift', 'frenzy'},
        Vertical = {'jump', 'launch', 'bounce', 'pad', 'grapple', 'balloon', 'levitat', 'fly', 'wind', 'rocket', 'leap', 'pounce'},
        Invisible = {'invis', 'vanish', 'cloak', 'ghost'},
        Ability = {'ability', 'kit_', 'kitability', 'cooldown'}
    }

    -- One pass over a character's attributes per tick, producing every flag the checks want.
    -- Reading them separately meant walking the same attribute table three times a tick per
    -- player for answers that all come out of the same read.
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
        -- The old check read hand.tool.Name, which is nil for anything the game hands over as a
        -- plain item rather than a Tool - so the reach fell back to the default for half the
        -- weapons in the game and flagged anyone holding a long one.
        local itemType = hand and (hand.itemType or (hand.tool and hand.tool.Name))
        local meta = itemType and bedwars.ItemMeta[itemType]
        local sword = meta and meta.sword
        return (sword and sword.attackRange or 14.4)
    end

    -- Lowest solid ground anywhere on the map, minus a margin. Below this is the void, and nothing
    -- alive belongs there. Recomputed on a timer rather than per sample: it walks every block on
    -- the map, and the floor of the world does not move between ticks.
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

    -- What the game itself says a kit's movement is worth. Read out of the kit metadata rather
    -- than from a list of kit names: a kit added, renamed or rebalanced next update is covered by
    -- whatever its own meta says about itself, and there is nothing here to keep up to date. Any
    -- move-speed multiplier the meta declares raises that player's ceiling by the same
    -- proportion, so a kit whose whole point is moving fast is never flagged for moving fast.
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
                        -- Only a movement multiplier, never a raw number and never a speed that
                        -- belongs to something else the kit throws.
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

    -- Rolling counter shared by every rate-based check: record an event, get back how many landed
    -- inside `window`.
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

    ------------------------------------------------------------------------
    -- Animation watch, shared.
    ------------------------------------------------------------------------
    -- Two checks want the same fact from different angles: the crasher check wants how OFTEN a
    -- player starts animations, and killaura's packet signal wants whether they started one at
    -- all. One hook per character answers both.
    local animationLast, animationRates, animationHooked = {}, {}, {}
    -- How many hits anywhere in the match arrived with a swing behind them. Until the game has
    -- proven to us that it replicates swings at all, "no swing behind that hit" means nothing,
    -- and the packet signal stays switched off rather than flagging the entire lobby.
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
                -- Landing/fall-state animations are restarted by the stock controller and by
                -- NoFallDamage's landed-state path. They are movement state, not an animation
                -- flood, and counting them made the Animation toggle accuse ordinary falls.
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

    -- Which heading each check belongs to, so a family can be switched off in one place.
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
    -- The checks whose toggle name is the heading itself.
    local CHECK_TOGGLE = {
        AutoKit = 'AutoKit',
        Breaker = 'Breaker',
        ProjectileAim = 'ProjectileAimbot and Aura'
    }

    local function wanted(name)
        local group = CHECK_GROUP[name]
        return group ~= nil and checkEnabled(group, CHECK_TOGGLE[name] or name)
    end

    ------------------------------------------------------------------------
    -- Polling checks.
    ------------------------------------------------------------------------
    -- Each entry is a factory: it is called once when the module starts and hands back the
    -- function that runs against every snapshot, so all of a check's state is private to one
    -- run of the module and starts empty on the next.
    local Pollers = {}

    ------------------------------------------------------------------------
    -- Speed.
    ------------------------------------------------------------------------
    -- Not "how fast was that one step" - a knockback, a dash and a bad interpolation all answer
    -- that loudly. This measures a continuous run: distance actually covered over the time it
    -- took, with the run reset the moment anything makes a sample untrustworthy (a buff, a
    -- teleport, a hit taken, leaving the ground, or simply slowing down). What is left is speed
    -- that was HELD, which is the difference between a kit ability and a speed hack.
    Pollers.Speed = function()
        local tracks = {}
        return function(now, list)
            local seen = {}
            for _, rec in list do
                local plr = rec.Player
                seen[plr] = true
                local track = tracks[plr]
                -- A respawn is a new character in the same player's name, and the position it
                -- starts at has nothing to do with the one the last one died at.
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
                    -- Sprint pace keeps a run alive, anything below it ends the run. That is
                    -- deliberately generous: a kit dash decays into a sprint rather than a stop,
                    -- so the sprinting that follows stays in the window and drags the average
                    -- back under the limit, while a hack that simply holds one speed does not.
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
                    -- Both, and the second one is what keeps kits out of this. A dash, a pounce or
                    -- a wind push is a spike that decays: most of the window sits at running pace
                    -- even when the average of it is dragged over the limit. A hack holds one
                    -- speed, so nearly every sample in its window is over on its own.
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

    ------------------------------------------------------------------------
    -- Bypass behaviour.
    ------------------------------------------------------------------------
    -- These checks intentionally measure outcomes rather than known module signatures. A bypass
    -- can rename itself, but it still has to keep a player above the void, move them at an
    -- impossible pace, or suppress the health loss from a long unassisted fall.
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
                -- A genuine void fall keeps descending. Only a body held/flying for three seconds
                -- below all playable ground is suspicious; this also fixes AntiDeath flagging the
                -- first samples of somebody simply falling out of the map.
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
                    -- BedWars starts meaningful fall damage well below this. The generous height
                    -- keeps slopes, replicated ground jitter and ordinary jumps out. Wait through
                    -- the server's damage-settle window before deciding health never changed.
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

    ------------------------------------------------------------------------
    -- PlayerAttach.
    ------------------------------------------------------------------------
    -- Two halves of the same behaviour, either of which is enough on its own. Getting there: a
    -- position step no run can make, landing on top of somebody. Staying there: held inside arm's
    -- length of one player while the pair actually travel, with the separation barely changing -
    -- two players who merely happen to be close bob around each other by whole studs.
    Pollers.PlayerAttach = function()
        local held, previous = {}, {}
        return function(now, list, delta)
            local seen = {}
            for _, rec in list do
                local plr, position = rec.Player, rec.Position
                seen[plr] = true
                local last = previous[plr]
                -- Same player, different body: the step from where they died to where they
                -- respawned is not a step they took.
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
                -- Rate, not raw distance: a poll stretched by a lag spike covers plenty of ground
                -- at a run, and calling that a teleport would flag whoever was standing nearby.
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

    ------------------------------------------------------------------------
    -- AntiDeath.
    ------------------------------------------------------------------------
    -- The hitbox taken somewhere nothing can reach it and brought straight back. This does not
    -- flag somebody merely for spending time below the map: it records impossible boundary
    -- crossings and requires repeated teleports to and from the void, which is what parking a
    -- hitbox out of a fight and restoring it looks like from outside.
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
                -- Straight up or straight down, faster than free fall, with the body barely
                -- moving sideways. Nothing physical does this. A normal void fall can cross the
                -- boundary once; AntiDeath has to cross it in both directions repeatedly.
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

    ------------------------------------------------------------------------
    -- Phase.
    ------------------------------------------------------------------------
    -- Standing inside solid geometry. Every part of this is arguable on its own - a body clips a
    -- block on a slope, streaming puts a block in late - so the reading needs the root buried in
    -- something solid across consecutive samples while the player is not being carried by
    -- anything, and it needs the most readings of any check before it flags. Sampled every third
    -- tick because it is the only check here that costs a spatial query.
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
                -- A box well inside the torso, so brushing a wall is not enough - the body has
                -- to be in the block.
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

    ------------------------------------------------------------------------
    -- Invisible.
    ------------------------------------------------------------------------
    -- Every limb fully transparent while the player is alive, moving and carrying no invisibility
    -- effect of their own. Movement is what separates this from a ragdoll or a death animation,
    -- and the status-effect check is what keeps the game's own invisibility potion out of it.
    Pollers.Invisible = function()
        local hidden = {}
        local skip = 0
        return function(now, list)
            -- Every fifth tick. Walking a character's whole descendant tree is the most expensive
            -- read in the module, and nobody turns invisible for a tenth of a second.
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

                -- No limbs found at all means the character has not streamed in, which is not
                -- the same thing as being invisible.
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

    ------------------------------------------------------------------------
    -- HighJump.
    ------------------------------------------------------------------------
    -- Rising further off one jump than the game's own jump power allows. Measured as a climb from
    -- a standing start rather than as an instantaneous velocity, because a launch pad or a
    -- knockback shows up in velocity and both of those are legitimate.
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
                    -- Roblox's own jump tops out near 7 studs, and BedWars kits that go higher
                    -- all announce themselves through a status effect, which is excluded above.
                    -- 18 is far past anything left.
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

    ------------------------------------------------------------------------
    -- AutoKit.
    ------------------------------------------------------------------------
    -- A kit ability is a cooldown, and a script fires it the instant it is up - every time. What
    -- gives it away is not the speed but the regularity: the gaps between activations stop
    -- varying. A hand cannot hold an interval to within a tenth of a second five times running.
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

                -- Rising edge: the ability just went off.
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
                -- Five gaps that agree to within a tenth of a second, and none of them long
                -- enough to be somebody simply playing at a steady pace.
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

    ------------------------------------------------------------------------
    -- Event-driven checks.
    ------------------------------------------------------------------------
    -- Same idea as the pollers: a factory called once at startup which puts its connections in
    -- place. Everything they need about a player is read at the moment of the event.
    local Events = {}

    ------------------------------------------------------------------------
    -- Killaura.
    ------------------------------------------------------------------------
    -- Four things an aura does that a hand does not, any one of which is a reading:
    --
    --   * hits closer together than anybody can click at all;
    --   * a cadence that does not vary, because the aura fires the moment the cooldown is up
    --     rather than whenever a finger happened to come down;
    --   * a run of hits held at a rate no hand sustains;
    --   * damage on several different people in the time it takes to turn to face one of them.
    --
    -- Plus the packet case: an aura that talks straight to the server does not swing anything,
    -- so the damage lands with no animation behind it. That one is only trusted once other
    -- players in the same match have proven that swings do reach us, so a game that simply does
    -- not replicate them cannot make the check flag everybody.
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

            -- Was there a swing behind this hit?
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

            -- Several different people inside the time it takes to turn around.
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
            -- Two events delivered in the same frame were batched by the network, not thrown that
            -- fast. Reading a batch as a zero interval is how a check like this flags people who
            -- are simply being replicated to us in bursts.
            if interval <= 0.008 then return end

            if interval < MIN_HUMAN_INTERVAL then
                strike(from, 'Killaura', 'using killaura', `hits {math.floor(interval * 1000)}ms apart`)
                return
            end

            -- Held rate. Not one fast hit - a run of them.
            if bumpRate(hits, from, BURST_WINDOW) >= BURST_HITS then
                hits[from] = nil
                strike(from, 'Killaura', 'using killaura', `{BURST_HITS} hits inside {BURST_WINDOW}s`)
            end

            -- Cadence. Only gaps short enough to be a weapon on cooldown are considered: a run of
            -- evenly spaced hits seconds apart is somebody trading, not a machine.
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

    ------------------------------------------------------------------------
    -- Reach.
    ------------------------------------------------------------------------
    -- The measurement an aura cannot fake. It can put whatever position it likes in the packet it
    -- sends the server, but the body the rest of us see stays where the player really is, so the
    -- distance between the two characters at the moment damage lands is the honest one. Every
    -- sword in the game swings 14.4 studs or less; past 15.5 the hit came from somewhere the
    -- weapon does not reach.
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
            -- Ping converted into studs rather than added as seconds, and kept small: this is an
            -- allowance for our own view of two moving bodies, not for the weapon.
            local allowance = math.clamp(ping() * 20, 0, 3)
            local limit = math.max(weaponReach(attacker) + 1.1, REACH_LIMIT) + allowance

            if distance > limit then
                strike(attacker, 'Reach', 'using reach', `{math.floor(distance * 10) / 10} studs, limit {math.floor(limit * 10) / 10}`)
            end
        end))
    end

    ------------------------------------------------------------------------
    -- HitBoxes.
    ------------------------------------------------------------------------
    -- An expanded hitbox lives on the attacker's own client, so it is never visible from here
    -- directly. What it produces that a normal swing cannot is a hit landing while the attacker is
    -- facing well off the target: the swing resolved against a box far wider than the body. The
    -- distance has to be inside legitimate reach too, otherwise this is just Reach again and one
    -- swing would be counted twice.
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
            -- Point blank the angle means nothing - the bodies overlap and any heading hits - and
            -- past the weapon's own reach this is Reach's reading, not this one.
            if distance < 6 or distance > REACH_LIMIT then return end

            local facing = fromRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
            local toward = delta * Vector3.new(1, 0, 1)
            if facing.Magnitude < 0.01 or toward.Magnitude < 0.01 then return end

            local angle = math.deg(math.acos(math.clamp(facing.Unit:Dot(toward.Unit), -1, 1)))
            -- 70 degrees off and still landing means the swing did not resolve against the body
            -- that is being drawn. Wide enough that our own interpolation of a strafing player
            -- cannot get there on its own.
            if angle > 70 then
                strike(attacker, 'HitBoxes', 'expanded hitboxes', `hit {math.floor(angle)} degrees off target`)
            end
        end))
    end

    ------------------------------------------------------------------------
    -- SilentAim.
    ------------------------------------------------------------------------
    -- The projectile equivalent: a shot that lands on someone the shooter was never pointing at.
    -- Only long shots are considered, because at close range the angle to a target is wide even
    -- when aimed honestly, and only non-melee damage, so a sword swing is never counted here.
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
            -- A thrown projectile arcs, and a short lob can leave at a heading well off the
            -- target quite legitimately. Distance is what makes the heading meaningful.
            if delta.Magnitude < 25 then return end

            local facing = fromRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
            if facing.Magnitude < 0.01 then return end

            local angle = math.deg(math.acos(math.clamp(facing.Unit:Dot(delta.Unit), -1, 1)))
            if angle > 50 then
                strike(attacker, 'SilentAim', 'silent aim', `landed a shot {math.floor(angle)} degrees off their heading`)
            end
        end))
    end

    ------------------------------------------------------------------------
    -- ProjectileAimbot and Aura.
    ------------------------------------------------------------------------
    -- Aimbot is not one impossible shot, it is never missing. Landing projectile after projectile
    -- on live players at long range, faster than they can be aimed, is the thing no hand does.
    Events.ProjectileAim = function()
        local hits = {}
        CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
            if not wanted('ProjectileAim') then return end
            if damageTable.damageType == 0 or not damageTable.fromEntity or not damageTable.entityInstance then return end

            local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
            local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
            -- Players only. A projectile stream into a mob or a bed is a different thing entirely.
            if not attacker or not victim or selfExcluded(attacker) or CheatersFlagged[attacker] then return end
            if not conditionsUsable(attacker) then return end

            local fromRoot = damageTable.fromEntity.PrimaryPart
            local toRoot = damageTable.entityInstance.PrimaryPart
            if not fromRoot or not toRoot then return end
            if (toRoot.Position - fromRoot.Position).Magnitude < 30 then return end

            -- Four long-range projectile hits on players inside six seconds. Bows are slow to
            -- draw, so this is well past what the weapon itself allows aimed by hand.
            if bumpRate(hits, attacker, 6) >= 4 then
                hits[attacker] = nil
                strike(attacker, 'ProjectileAim', 'projectile aimbot', '4 long-range projectile hits inside 6s')
            end
        end))
    end

    ------------------------------------------------------------------------
    -- Breaker.
    ------------------------------------------------------------------------
    -- Blocks coming apart faster than a tool can swing, or coming apart from across the map. Both
    -- are read off the break event itself, which carries who did it and where.
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
                    -- Block reach in this game is well under 30 studs even with every modifier.
                    if distance > 45 and not recentlyTeleported(plr) then
                        strike(plr, 'Breaker', 'block breaker', `broke a block {math.floor(distance)} studs away`)
                        return
                    end
                end
            end

            -- Twelve blocks inside two seconds. Flat out with the fastest tool in the game on the
            -- softest block is not close to this, and a burst that size cannot be a batch of
            -- replicated events either.
            if bumpRate(rates, plr, 2) >= 12 then
                rates[plr] = nil
                strike(plr, 'Breaker', 'block breaker', '12 blocks broken inside 2s')
            end
        end))
    end

    ------------------------------------------------------------------------
    -- Crashers: Remote.
    ------------------------------------------------------------------------
    -- Another player's remote traffic is not visible from here, but its effect is: a crasher
    -- pushes replicated actions out at a rate the game itself never produces. Block places and
    -- breaks and damage events are all counted together, because a crasher does not care which
    -- remote it is hammering. The bar is per second and set well past a busy one: jumping around
    -- spamming a sword while building throws out a lot of events, and none of that is a crash.
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

    -- One snapshot of everybody worth measuring, taken once per tick and handed to every polling
    -- check. Attributes, ground state and velocity are read here rather than inside each check,
    -- so a player is walked over once however many checks are on.
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

                -- Feeds the knockback suppression the speed and jump checks rely on.
                CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    local victim = damageTable.entityInstance and playersService:GetPlayerFromCharacter(damageTable.entityInstance)
                    if victim then
                        lastHurt[victim] = tick()
                    end
                end))

                -- Every check is put in place, whichever toggles happen to be ticked right now,
                -- and each one asks whether it is wanted as it runs. Building only the ticked
                -- ones meant a detection switched on mid-match did nothing at all until the
                -- module was cycled by hand, which is most of what "half of these do not work"
                -- was. An unwanted check costs one table lookup a tick.
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

                    -- The animation watch is what the crasher check counts and what killaura
                    -- asks whether a swing happened at all, so it runs for either of them.
                    local watching = wanted('Animation') or wanted('Killaura')
                    local polling = false
                    for name in running do
                        if wanted(name) then
                            polling = true
                            break
                        end
                    end

                    if watching or polling then
                        -- A character coming apart mid-read throws, and an unguarded throw here
                        -- ends the loop and the whole module with it.
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

    -- Last, and under everything else, because it is not a detection - it only changes who the
    -- detections above are allowed to look at. Takes effect immediately: the checks ask about it
    -- as they run rather than reading it once at startup, so there is no need to cycle the module.
    Toggles[DETECT_SELF] = CheatDetector:CreateToggle({
        Name = DETECT_SELF,
        Tooltip = 'Testing aid. Runs every enabled detection against you as well, on your behaviour alone - it never looks at which of your modules are on - and flags you like anyone else if one of them fires',
        Function = function()
            -- Readings taken either side of a change of mind about whether we count are not a
            -- pattern, so whichever way it just moved, our own history starts again from nothing.
            strikes[lplr] = nil
        end
    })
end)