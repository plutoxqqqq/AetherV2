run(function()
    -- EntityAnalyser
    --
    -- Works out how good each player actually is from what they do in front of us, and nothing
    -- else. Every input below is something the game already hands every client: damage and death
    -- events, block placements and breaks, bed breaks, replicated inventories, replicated
    -- animations, character attributes and the positions of entities that are streamed in. There
    -- is no stat page, no leaderboard and no rank lookup anywhere in here, and kills and gear are
    -- two signals out of forty-odd - neither can carry a rating on its own.
    --
    -- Six categories are scored separately (Combat, Movement, GameSense, Objectives, Resources,
    -- Teamwork) and each is built the same way: a fixed list of named signals, each reporting a
    -- deviation from -1 (as bad as it gets) to +1 (as good as it gets) together with a confidence
    -- saying how much evidence is behind it. A signal we have never observed is still declared, at
    -- confidence zero - which is what makes incomplete data cost confidence instead of quietly
    -- reweighting whatever happened to survive. The overall skill is a confidence-weighted blend
    -- of the categories, re-weighted for the role the player is actually playing, so a Support or
    -- an Economy player is not marked down against a Fighter's yardstick.
    --
    -- Things that would make a number a lie are handled where they happen rather than averaged
    -- over: kills on AFK, trapped, out-geared or repeatedly-respawning players are discounted at
    -- the moment of the kill; fights taken against equal or better gear count for more; samples
    -- taken across a teleport or a streaming gap are thrown away instead of read as movement;
    -- time we could not see the player is not counted as time observed.
    --
    -- This module is a read-out. It never touches another module's settings. What it knows is
    -- published on getgenv().EntityAnalyser and vapeEvents.EntityAnalysed for anything that wants
    -- to act on it - Killaura's 'Target skilled' is the first consumer.
    local EntityAnalyser
    local SweatAt
    local SkilledAt
    local AboveAt
    local BeginnerBelow
    local NewBelow
    local MinConfidence
    local SampleRange
    local Labels
    local ShowScore
    local ShowRole
    local ShowConfidence
    local ShowSweat
    local ShowSkilled
    local ShowAbove
    local ShowAverage
    local ShowBeginner
    local ShowNew
    local ShowUnknown
    local Teammates
    local Notify

    ----------------------------------------------------------------------------
    -- Constants.
    ----------------------------------------------------------------------------
    local COMBO_WINDOW = 1.6      -- hits inside this gap are one combo
    local FIGHT_MEMORY = 6        -- still "in a fight" this long after a hit either way
    local ENGAGE_MEMORY = 14      -- an engagement stays resolvable this long after its last hit
    local ASSIST_WINDOW = 8       -- damage this recent counts toward someone else's kill
    local SWING_WINDOW = 0.28     -- a swing this soon before damage is the swing that landed
    local AFK_TIME = 12           -- no movement and no action for this long reads as AFK
    local TELEPORT_JUMP = 90      -- a position step bigger than this is lag, not movement
    local EVENT_LIMIT = 12        -- RecentEvents ring size
    local RESCORE_INTERVAL = 0.5  -- a profile is rebuilt at most this often
    local FAR_INTERVAL = 0.5      -- sampling period outside the near radius
    local AFK_INTERVAL = 2        -- sampling period for someone who is not doing anything
    local NEAR_INTERVAL = 0.1     -- combat sampling does not need the render frame rate
    local PROBE_INTERVAL = 0.1    -- terrain probe period for near players
    local PROBE_BUDGET = 4        -- terrain probes allowed per frame, across everyone
    local WORLD_INTERVAL = 0.5    -- bed/generator/roster snapshot rebuild period
    local HEAVY_INTERVAL = 0.5    -- period for the per-player checks that allocate
    local BED_NEAR = 30           -- "at a bed" radius
    local GEN_NEAR = 16           -- "at a generator" radius
    local THREAT_NEAR = 35        -- an enemy this close is a threat to have noticed
    local MATE_NEAR = 45          -- a teammate this close is one you could have helped
    local VOID_WINDOW = 4         -- knockback to void death has to land inside this
    local SEEN_TIMEOUT = 2        -- no sample for this long is a streaming gap, not idling

    local ratingColor = {
        Sweat = Color3.fromRGB(255, 105, 180),
        Skilled = Color3.fromRGB(85, 220, 130),
        ['Above Average'] = Color3.fromRGB(170, 225, 110),
        Average = Color3.fromRGB(235, 205, 90),
        Beginner = Color3.fromRGB(235, 95, 95),
        New = Color3.fromRGB(170, 115, 115),
        Unknown = Color3.fromRGB(150, 150, 158)
    }

    local ROLES = {'Rusher', 'Defender', 'Fighter', 'Support', 'Economy', 'ResourceControl'}
    local CATEGORIES = {'Combat', 'Movement', 'GameSense', 'Objectives', 'Resources', 'Teamwork'}

    -- How much each category counts toward the overall score, per role. A Defender who never
    -- rushes is not a worse player for it, so Objectives weighs less for them and the job they
    -- are actually doing weighs more. Mixed is the neutral profile everyone starts on.
    local ROLE_WEIGHTS = {
        Mixed           = {Combat = 1.00, Movement = 0.75, GameSense = 1.00, Objectives = 0.85, Resources = 0.55, Teamwork = 0.60},
        Rusher          = {Combat = 1.00, Movement = 0.95, GameSense = 0.85, Objectives = 1.20, Resources = 0.45, Teamwork = 0.50},
        Defender        = {Combat = 0.95, Movement = 0.70, GameSense = 1.20, Objectives = 0.70, Resources = 0.60, Teamwork = 0.90},
        Fighter         = {Combat = 1.30, Movement = 0.90, GameSense = 0.95, Objectives = 0.60, Resources = 0.40, Teamwork = 0.55},
        Support         = {Combat = 0.70, Movement = 0.70, GameSense = 1.05, Objectives = 0.65, Resources = 0.70, Teamwork = 1.35},
        Economy         = {Combat = 0.60, Movement = 0.70, GameSense = 0.95, Objectives = 0.70, Resources = 1.35, Teamwork = 0.85},
        ResourceControl = {Combat = 0.85, Movement = 0.75, GameSense = 1.10, Objectives = 0.75, Resources = 1.15, Teamwork = 0.90}
    }

    ----------------------------------------------------------------------------
    -- Rolling statistics.
    ----------------------------------------------------------------------------
    -- A mean that converges fast while there is little evidence and settles as more arrives, so an
    -- early read is usable and a late one is stable. `n` is the evidence weight behind it, which
    -- is what every count-based confidence term in the module is built from.
    local function meter(initial)
        return {v = initial or 0, n = 0}
    end

    local function observe(m, value, weight)
        weight = weight or 1
        if weight <= 0 or value ~= value then return end
        m.n = m.n + weight
        m.v = m.v + (value - m.v) * math.clamp(weight / math.min(m.n, 24), 0.04, 1)
    end

    -- Confidence a meter has earned. `full` is the observation weight at which the signal counts
    -- as properly evidenced; below that it is scaled down rather than dropped off a cliff.
    local function evidence(m, full)
        return math.clamp(m.n / (full or 8), 0, 1)
    end

    local function countConf(count, full)
        return math.clamp(count / (full or 6), 0, 1)
    end

    local function safeDiv(a, b)
        return b > 0 and (a / b) or 0
    end

    -- Maps a measurement onto the -1..+1 the blender wants, given the value a weak player produces
    -- and the value a strong one does. Used where both ends mean something - an accuracy of zero
    -- really is bad, not merely unremarkable.
    local function scale(value, low, high)
        if low == high then return 0 end
        return math.clamp((value - low) / (high - low), 0, 1) * 2 - 1
    end

    -- Counting signals where doing none of it is unremarkable rather than bad. Most players never
    -- break a bed; that is not a flaw, so zero has to land on neutral and not on -1.
    local function reward(value, good)
        if good <= 0 then return 0 end
        return math.clamp(value / good, 0, 1)
    end

    -- Signals where both extremes are wrong and the middle is right - target switching, time spent
    -- on a generator.
    local function bell(value, ideal, spread)
        if spread <= 0 then return 0 end
        return math.clamp(1 - (math.abs(value - ideal) / spread), -1, 1)
    end

    ----------------------------------------------------------------------------
    -- The blender.
    ----------------------------------------------------------------------------
    -- Every category is a bag of named signals. `total` accumulates the weight of every signal the
    -- category declares, `conf` the weight actually backed by evidence - so a category we can only
    -- half observe reports a middling confidence and a score pulled toward 50, rather than a
    -- confident-looking score assembled from whichever three signals happened to have data.
    local function blender()
        return {sum = 0, weight = 0, conf = 0, total = 0, named = {}}
    end

    local function signal(b, name, deviation, weight, confidence)
        weight = weight or 1
        confidence = math.clamp(confidence or 0, 0, 1)
        deviation = math.clamp(deviation or 0, -1, 1)
        b.total = b.total + weight
        b.conf = b.conf + weight * confidence
        local w = weight * confidence
        if w > 0 then
            b.sum = b.sum + deviation * w
            b.weight = b.weight + w
            b.named[name] = {Deviation = deviation, Confidence = confidence, Weight = weight}
        end
    end

    local function resolve(b)
        if b.total <= 0 then return 50, 0, b end
        local conf = b.conf / b.total
        if b.weight <= 0 then return 50, conf, b end
        local mean = b.sum / b.weight
        -- Low confidence holds the score near Average, so one well-evidenced signal in an
        -- otherwise unobserved category cannot swing it to an extreme.
        return math.clamp(50 + mean * 50 * (0.4 + 0.6 * conf), 0, 100), conf, b
    end

    ----------------------------------------------------------------------------
    -- State.
    ----------------------------------------------------------------------------
    local profiles, engagements, pendingVoid, tags, seen = {}, {}, {}, {}, {}
    local folder
    local running = false
    local probeBudget = 0
    local matchStart, bedsAtStart, lastMatchState = tick(), 0, -1

    -- Bed, generator and player positions are rebuilt a couple of times a second and shared by
    -- everyone, so the per-frame sampling never walks CollectionService or re-reads a position
    -- once per player per player.
    local world = {
        At = 0,
        Beds = {},
        Generators = {},
        Roster = {},
        Stage = 'Early',
        Elapsed = 0,
        TeamSize = 1
    }

    local function newProfile(plr)
        local now = tick()
        return {
            Player = plr,
            FirstSeen = now,
            LastSeen = now,
            LastSample = 0,
            LastProbe = 0,
            LastHeavy = 0,
            Observed = 0,       -- seconds we have actually had eyes on them
            Dirty = true,
            NextScore = 0,
            Cache = nil,
            Events = {},

            Combat = {
                Swings = 0, SwingHits = 0, SwingIds = {}, PendingSwing = 0, PendingSwingId = nil,
                Hits = 0, MeleeHits = 0,
                Projectiles = 0, ProjectileHits = 0,
                DamageDealt = 0, DamageTaken = 0,
                Kills = 0, Deaths = 0, FinalKills = 0,
                FightsWon = 0, FightsLost = 0,
                UphillFights = 0, UphillWins = 0,
                Combo = 0, BestCombo = 0, ComboCount = 0, ComboHits = 0,
                LastVictim = nil, LastHit = 0,
                LastHurt = 0, LastHurtBy = nil,
                FirstHits = 0, FirstHitChances = 0,
                VoidKills = 0,
                Switches = 0, SwitchSeen = {}, SwitchAt = 0,
                Reaction = meter(0),
                Strafe = meter(0),
                Tracking = meter(0),
                KillQuality = meter(1)
            },

            Movement = {
                Blocks = 0, BridgeRun = 0, BridgeTime = 0, BridgeAt = 0,
                Distance = 0, Pauses = 0, PauseAt = 0,
                Falls = 0, UnforcedFalls = 0, Saves = 0, Parkour = 0, Jumps = 0,
                Clutches = 0,
                KnockbackAt = 0, KnockbackFrom = nil,
                EdgeApproaches = 0, EdgeStops = 0, EdgeAt = 0,
                LastPos = nil, LastDir = nil, LastVel = nil,
                Ground = nil, OverVoid = false,
                FallFrom = nil, Airborne = false,
                BridgeSpeed = meter(0),
                Recovery = meter(0),
                Positioning = meter(0)
            },

            Sense = {
                Threats = 0, ThreatReactions = 0, ThreatFrom = nil, ThreatAt = 0, ThreatAnswered = false,
                BedAlerts = 0, BedResponses = 0, BedAlert = false, LastAlert = 0,
                Retreats = 0, RetreatFrom = nil, RetreatAt = 0,
                Chases = 0, PointlessChases = 0, ChaseAt = 0,
                SafeTime = 0, ExposedTime = 0,
                ToolSwaps = 0, LastHand = nil,
                LowHealthDeaths = 0, LowHealthEscapes = 0,
                SaveChanceAt = 0,
                BedResponseTime = meter(0)
            },

            Objectives = {
                BedApproaches = 0, BedApproachAt = 0,
                DefenceBroken = 0,
                Rushes = 0, RushWins = 0,
                Beds = 0,
                FinalKills = 0, Assists = 0, Escapes = 0,
                Pressure = 0,
                BedBreakTime = meter(0)
            },

            Resources = {
                GenTime = 0, GenAt = 0, GenVisits = 0,
                Iron = 0, Diamond = 0, Emerald = 0,
                IronSpent = 0, DiamondSpent = 0, EmeraldSpent = 0,
                Lost = 0, LostEvents = 0,
                Purchases = 0, Upgrades = 0,
                BestGear = 0,
                LastInventory = nil, InventoryAt = 0,
                Prepared = meter(0),
                GearTier = meter(0)
            },

            Teamwork = {
                Assists = 0,
                Saves = 0, SaveChances = 0, SaveAt = 0,
                Shared = 0,
                Defends = 0,
                PushWindow = 0,
                ControlTime = 0
            },

            Context = {
                Kit = nil, Team = nil,
                AFK = false,
                LastMove = now, LastAction = now,
                Alive = true, Respawns = 0, LastDeath = 0,
                Trapped = false,
                Lagged = 0, Samples = 0,
                Gaps = 0, GapTime = 0,
                Health = 1, Gear = 0, Armour = 0
            }
        }
    end

    local function profileFor(plr)
        if not plr then return nil end
        local record = profiles[plr]
        if not record then
            record = newProfile(plr)
            profiles[plr] = record
        end
        return record
    end

    -- Read path only, so asking about a player never allocates them a profile.
    local function peek(plr)
        return plr and profiles[plr] or nil
    end

    local function touch(record)
        record.Dirty = true
    end

    local function addEvent(record, kind, confidence, detail)
        local events = record.Events
        table.insert(events, {Type = kind, Time = tick(), Confidence = math.clamp(confidence or 1, 0, 1), Detail = detail})
        while #events > EVENT_LIMIT do
            table.remove(events, 1)
        end
        record.Dirty = true
    end

    ----------------------------------------------------------------------------
    -- Match context.
    ----------------------------------------------------------------------------
    local function teamOf(plr)
        if not plr then return nil end
        local team = plr:GetAttribute('Team')
        if team == nil and plr.Character then
            team = plr.Character:GetAttribute('Team')
        end
        return team
    end

    local function sameTeam(a, b)
        local ta, tb = teamOf(a), teamOf(b)
        return ta ~= nil and tb ~= nil and ta == tb
    end

    -- 0 = warmup, 1 = playing, 2 = over. Only a live match is worth judging anyone on, so the
    -- event handlers gate on this while the labels keep rendering whatever we already know.
    local function playing()
        return store.matchState == 1
    end

    local function bedPartOf(bed)
        return bed:IsA('BasePart') and bed or bed:FindFirstChildWhichIsA('BasePart')
    end

    local function refreshWorld(now)
        if now - world.At < WORLD_INTERVAL then return end
        world.At = now

        table.clear(world.Beds)
        local standing = 0
        for _, bed in collectionService:GetTagged('bed') do
            if bed.Parent then
                local part = bedPartOf(bed)
                if part then
                    standing = standing + 1
                    table.insert(world.Beds, {Position = part.Position, Object = bed})
                end
            end
        end

        table.clear(world.Generators)
        for _, gen in collectionService:GetTagged('Generator') do
            local part = gen:IsA('BasePart') and gen or gen:FindFirstChildWhichIsA('BasePart')
            if part then
                local id = tostring(gen:GetAttribute('Id') or ''):lower()
                table.insert(world.Generators, {
                    Position = part.Position,
                    Kind = id:find('emerald') and 'emerald' or id:find('diamond') and 'diamond' or 'iron'
                })
            end
        end

        -- One pass for the roster: positions, teams and the biggest team in the lobby, which is
        -- the only honest read on whether this is solos or squads. We are in it too, because we
        -- are a threat to stand on somebody's bed like anyone else.
        table.clear(world.Roster)
        local sizes, biggest = {}, 1
        local function addToRoster(plr, root)
            if not plr or not root or not root.Parent then return end
            local team = teamOf(plr)
            table.insert(world.Roster, {Player = plr, Position = root.Position, Team = team})
            if team ~= nil then
                sizes[team] = (sizes[team] or 0) + 1
                biggest = math.max(biggest, sizes[team])
            end
        end
        for _, ent in entitylib.List do
            addToRoster(ent.Player, ent.RootPart)
        end
        if entitylib.isAlive then
            addToRoster(lplr, entitylib.character.RootPart)
        end
        world.TeamSize = biggest

        -- Early / mid / late, from the clock and from how many beds are left. Rushing is worth far
        -- more in the first two minutes, and what counts as impressive gear moves with the match.
        local elapsed = now - matchStart
        local fraction = safeDiv(standing, math.max(bedsAtStart, standing, 1))
        world.Elapsed = elapsed
        if elapsed < 150 and fraction > 0.7 then
            world.Stage = 'Early'
        elseif elapsed > 480 or fraction < 0.35 then
            world.Stage = 'Late'
        else
            world.Stage = 'Mid'
        end
    end

    -- The bed belonging to this player's team, and the nearest bed that does not - the two things
    -- every objective, defence and positioning signal is measured against.
    local function bedsFor(plr, position)
        local team = teamOf(plr)
        local own, ownDist, enemy, enemyDist = nil, math.huge, nil, math.huge
        for _, bed in world.Beds do
            local mine = team ~= nil and bed.Object:GetAttribute('Team' .. team .. 'NoBreak') and true or false
            local dist = position and (bed.Position - position).Magnitude or math.huge
            if mine then
                -- Their own bed is theirs whether or not we were given a position to measure to.
                if own == nil or dist < ownDist then
                    own, ownDist = bed, dist
                end
            elseif dist < enemyDist then
                enemy, enemyDist = bed, dist
            end
        end
        return own, ownDist, enemy, enemyDist
    end

    local function nearestGenerator(position)
        local bestDist, bestKind = math.huge, nil
        for _, gen in world.Generators do
            local dist = (gen.Position - position).Magnitude
            if dist < bestDist then
                bestDist, bestKind = dist, gen.Kind
            end
        end
        return bestDist, bestKind
    end

    ----------------------------------------------------------------------------
    -- Gear, health and kits.
    ----------------------------------------------------------------------------
    local function inventoryOf(plr)
        return store.inventories[plr]
    end

    local function swordDamage(inv)
        local best = 0
        for _, item in (inv and inv.items or {}) do
            local meta = bedwars.ItemMeta[item.itemType]
            if meta and meta.sword and (meta.sword.damage or 0) > best then
                best = meta.sword.damage
            end
        end
        return best
    end

    local function armourValue(inv)
        local total = 0
        for _, item in (inv and inv.armor or {}) do
            local meta = item and bedwars.ItemMeta[item.itemType]
            if meta and meta.armor then
                total = total + (meta.armor.damageReductionMultiplier or 0)
            end
        end
        return total
    end

    local function resourceCount(inv, kind)
        local total = 0
        for _, item in (inv and inv.items or {}) do
            if item.itemType == kind then
                total = total + (item.amount or 0)
            end
        end
        return total
    end

    -- One number for "how well equipped are they", weapon and armour together, so comparing two
    -- players' gear is a single subtraction. nil when their inventory has not replicated to us -
    -- which is a missing input, not a player with nothing.
    local function gearOf(plr)
        local inv = inventoryOf(plr)
        if not inv then return nil end
        return swordDamage(inv) + armourValue(inv) * 30
    end

    local function healthFraction(plr)
        local char = plr.Character
        if not char then return 1 end
        local health, maximum = char:GetAttribute('Health'), char:GetAttribute('MaxHealth')
        if not health or not maximum or maximum <= 0 then return 1 end
        return math.clamp(health / maximum, 0, 1)
    end

    local function kitOf(plr)
        return plr:GetAttribute('PlayingAsKits') or plr:GetAttribute('PlayingAsKit') or nil
    end

    -- Kits change what a signal is worth. A kit that hands out mobility makes bridging and parkour
    -- cheaper to look good at; a kit with a combat ability does the same for damage. These only
    -- soften the confidence of the affected signals, never the score itself, so a kit we do not
    -- recognise costs nobody anything.
    local KIT_MOVEMENT = {dasher = 0.7, angel = 0.65, void_dragon = 0.6, owl = 0.7, dragonslayer = 0.8, yuzi = 0.8, melody = 0.85, cyber = 0.8}
    local KIT_COMBAT = {barbarian = 0.8, vulcan = 0.75, ember = 0.8, ice_queen = 0.85, mage = 0.85, ranger = 0.85, pyro = 0.85}

    -- Status effects replicate as character attributes. Being trapped or frozen is not a skill
    -- failure, and killing somebody who is is not a skill success.
    local function statusTrapped(plr)
        local char = plr.Character
        if not char then return false end
        for name, value in char:GetAttributes() do
            if type(name) == 'string' and name:find('StatusEffect_') and value ~= false and value ~= 0 then
                local lowered = name:lower()
                if lowered:find('trap') or lowered:find('stun') or lowered:find('freeze') or lowered:find('root') or lowered:find('web') then
                    return true
                end
            end
        end
        return false
    end

    ----------------------------------------------------------------------------
    -- Data quality.
    ----------------------------------------------------------------------------
    local function localPing()
        local ping = 0
        pcall(function()
            ping = lplr:GetNetworkPing()
        end)
        return ping
    end

    -- Everything timing-sensitive - reaction time, first hits, aim tracking - is measured through
    -- our own connection, so our own ping is a hard ceiling on how far any of it can be trusted.
    local function timingConfidence()
        return math.clamp(1 - (localPing() / 0.35), 0.15, 1)
    end

    -- How much of what we think we know is actually ours to know. Time streamed out, samples
    -- thrown away as lag and a missing replicated inventory all land here, and all of them cost
    -- confidence rather than quietly changing the score.
    local function dataQuality(record)
        local context = record.Context
        local watched = math.max(record.Observed, 0.01)
        local coverage = math.clamp(watched / math.max(tick() - record.FirstSeen, watched), 0.2, 1)
        local clean = 1 - math.clamp(safeDiv(context.Lagged, math.max(context.Samples, 1)), 0, 0.6)
        return math.clamp(coverage * clean * (inventoryOf(record.Player) and 1 or 0.75), 0.1, 1)
    end

    -- A player nobody should be scored against. Returns 0..1, where 1 is somebody in a fair state
    -- to be fighting. This is the number that stops farming reading as skill.
    local function playerQuality(record)
        if not record then return 0.5 end
        local context = record.Context
        local quality = 1
        if context.AFK then
            quality = quality * 0.15
        end
        if context.Trapped then
            quality = quality * 0.4
        end
        -- Repeatedly respawning into the same fight. Every death inside the last minute makes the
        -- next one worth less to whoever takes it.
        local rate = safeDiv(context.Respawns, math.max((tick() - record.FirstSeen) / 60, 0.5))
        if rate > 1.5 then
            quality = quality * math.clamp(1 - (rate - 1.5) * 0.3, 0.3, 1)
        end
        if context.Health < 0.35 then
            quality = quality * 0.7
        end
        return math.clamp(quality, 0.05, 1)
    end

    ----------------------------------------------------------------------------
    -- Engagements.
    ----------------------------------------------------------------------------
    -- A fight is a pair of players trading damage. Tracking it as an object rather than as two
    -- separate hit counters is what makes first-hit rate, fight wins, escapes, assists and
    -- gear-relative performance answerable at all.
    local function engagementFor(attacker, victim)
        local key, flipped
        if attacker.UserId < victim.UserId then
            key, flipped = attacker.UserId .. ':' .. victim.UserId, false
        else
            key, flipped = victim.UserId .. ':' .. attacker.UserId, true
        end

        local now = tick()
        local fight = engagements[key]
        if fight and now - fight.Last > ENGAGE_MEMORY then
            engagements[key] = nil
            fight = nil
        end
        if not fight then
            fight = {
                A = flipped and victim or attacker,
                B = flipped and attacker or victim,
                Start = now,
                Opener = attacker,
                Damage = {},
                Counted = false,
                Resolved = false,
                -- Gear as it stood when the fight opened. The winner may well be holding the
                -- loser's kit by the time it ends, so reading it later would invert the signal.
                GearA = gearOf(flipped and victim or attacker),
                GearB = gearOf(flipped and attacker or victim)
            }
            engagements[key] = fight
        end
        fight.Last = now
        return fight
    end

    local function engagementsInvolving(plr, into)
        table.clear(into)
        for _, fight in engagements do
            if fight.A == plr or fight.B == plr then
                table.insert(into, fight)
            end
        end
        return into
    end

    ----------------------------------------------------------------------------
    -- Event ingestion: swings.
    ----------------------------------------------------------------------------
    -- Swing animations replicate, so misses are countable - but only once we know which of a
    -- player's animations is their swing. The first animation id that keeps coinciding with their
    -- damage output becomes their swing id, and only then do misses start counting, so a kit
    -- ability is never mistaken for a whiffed hit. Until an id is confirmed nothing is scored.
    local function noteSwing(plr, animationId)
        local record = peek(plr)
        if not record then return end
        local combat = record.Combat
        local entry = combat.SwingIds[animationId]
        if not entry then
            entry = {Seen = 0, Hits = 0, Confirmed = false}
            combat.SwingIds[animationId] = entry
        end
        entry.Seen = entry.Seen + 1
        if entry.Confirmed then
            combat.Swings = combat.Swings + 1
        end
        combat.PendingSwing = tick()
        combat.PendingSwingId = animationId
        record.Context.LastAction = tick()
    end

    local function confirmSwing(record)
        local combat = record.Combat
        local id = combat.PendingSwingId
        if not id or tick() - combat.PendingSwing > SWING_WINDOW then return end
        local entry = combat.SwingIds[id]
        if not entry then return end
        entry.Hits = entry.Hits + 1
        if entry.Confirmed then
            combat.SwingHits = combat.SwingHits + 1
        elseif entry.Hits >= 3 and entry.Hits / math.max(entry.Seen, 1) > 0.3 then
            -- Recognised. Everything already seen for this id was a swing, so accuracy does not
            -- restart from zero the moment we work out what we have been watching.
            entry.Confirmed = true
            combat.Swings = combat.Swings + entry.Seen
            combat.SwingHits = combat.SwingHits + entry.Hits
        end
        combat.PendingSwingId = nil
    end

    ----------------------------------------------------------------------------
    -- Event ingestion: damage.
    ----------------------------------------------------------------------------
    local function noteTargetSwitch(record, victim)
        local combat = record.Combat
        local now = tick()
        if now - combat.SwitchAt > FIGHT_MEMORY then
            table.clear(combat.SwitchSeen)
            combat.SwitchAt = now
        end
        if victim and not combat.SwitchSeen[victim] then
            combat.SwitchSeen[victim] = true
            local count = 0
            for _ in combat.SwitchSeen do
                count = count + 1
            end
            if count > 1 then
                combat.Switches = combat.Switches + 1
            end
        end
    end

    local fightScratch = {}

    local function onDamage(damageTable)
        if not running or not playing() then return end
        local amount = damageTable.damage or 0
        if amount <= 0 then return end

        local attacker = damageTable.fromEntity and playersService:GetPlayerFromCharacter(damageTable.fromEntity)
        local victim = damageTable.entityInstance and playersService:GetPlayerFromCharacter(damageTable.entityInstance)
        if attacker == victim then return end
        if not attacker and not victim then return end

        local now = tick()
        local melee = damageTable.damageType == 0
        local attackerRecord = attacker and attacker ~= lplr and profileFor(attacker) or nil
        local victimRecord = victim and victim ~= lplr and profileFor(victim) or nil

        if victimRecord then
            local combat = victimRecord.Combat
            combat.DamageTaken = combat.DamageTaken + amount
            combat.LastHurt = now
            combat.LastHurtBy = attacker
            victimRecord.Context.LastAction = now
            -- Knockback is what actually kills people over a gap, so remember who applied it and
            -- whether the victim was over open air when it landed.
            local knockback = damageTable.knockbackMultiplier
            if knockback and not knockback.disabled and attacker then
                victimRecord.Movement.KnockbackAt = now
                victimRecord.Movement.KnockbackFrom = attacker
                if victimRecord.Movement.OverVoid then
                    pendingVoid[victim] = {From = attacker, At = now}
                end
            end
            touch(victimRecord)
        end

        -- The engagement is tracked from whichever side we can profile, including fights against
        -- us. A player who spends the whole match on the local player would otherwise finish it
        -- with no fight wins, no first hits and no gear-relative record at all - there is simply
        -- nobody to award the other half of each fight to.
        if attacker and victim then
            local fight = engagementFor(attacker, victim)
            fight.Damage[attacker] = (fight.Damage[attacker] or 0) + amount

            -- First hit. Only the opener gets the credit, and only once per fight, so a long
            -- scrap cannot inflate it.
            if not fight.Counted then
                fight.Counted = true
                if attackerRecord then
                    attackerRecord.Combat.FirstHitChances = attackerRecord.Combat.FirstHitChances + 1
                    if fight.Opener == attacker then
                        attackerRecord.Combat.FirstHits = attackerRecord.Combat.FirstHits + 1
                    end
                end
                if victimRecord then
                    victimRecord.Combat.FirstHitChances = victimRecord.Combat.FirstHitChances + 1
                end
            end
        end

        if not attackerRecord then return end
        local combat = attackerRecord.Combat
        combat.DamageDealt = combat.DamageDealt + amount
        combat.Hits = combat.Hits + 1
        attackerRecord.Context.LastAction = now
        if melee then
            combat.MeleeHits = combat.MeleeHits + 1
            confirmSwing(attackerRecord)
        else
            combat.ProjectileHits = combat.ProjectileHits + 1
        end

        -- Combo: hits that keep landing on the same person without a gap. Any pause or a change of
        -- victim ends it, so two people trading singles never adds up into one long combo.
        if combat.LastVictim == victim and now - combat.LastHit <= COMBO_WINDOW then
            combat.Combo = combat.Combo + 1
            combat.ComboHits = combat.ComboHits + 1
            if combat.Combo == 3 then
                combat.ComboCount = combat.ComboCount + 1
                addEvent(attackerRecord, 'Combo', 1, victim and victim.Name or nil)
            end
        else
            combat.Combo = 1
        end
        combat.BestCombo = math.max(combat.BestCombo, combat.Combo)
        combat.LastVictim, combat.LastHit = victim, now
        noteTargetSwitch(attackerRecord, victim)

        -- Reaction time: how quickly they answer being hit themselves.
        if combat.LastHurt > 0 and now - combat.LastHurt < 2 then
            observe(combat.Reaction, math.clamp(now - combat.LastHurt, 0.05, 2))
        end

        if not victim then
            touch(attackerRecord)
            return
        end

        -- Protecting a teammate: hitting somebody who is at that moment in a fight with one of
        -- your own. Rate limited so holding an angle on one attacker is one save, not thirty.
        if now - attackerRecord.Teamwork.SaveAt > 3 then
            for _, other in engagementsInvolving(victim, fightScratch) do
                local partner = other.A == victim and other.B or other.A
                if partner ~= attacker and sameTeam(partner, attacker) and now - other.Last <= FIGHT_MEMORY then
                    attackerRecord.Teamwork.Saves = attackerRecord.Teamwork.Saves + 1
                    attackerRecord.Teamwork.SaveAt = now
                    break
                end
            end
        end

        touch(attackerRecord)
    end

    ----------------------------------------------------------------------------
    -- Event ingestion: deaths.
    ----------------------------------------------------------------------------
    local function resolveEngagements(victim, killer)
        local now = tick()
        local fights = engagementsInvolving(victim, {})
        for _, fight in fights do
            local other = fight.A == victim and fight.B or fight.A
            local otherRecord = peek(other)

            if not fight.Resolved then
                fight.Resolved = true
                local victimRecord = peek(victim)
                if victimRecord then
                    victimRecord.Combat.FightsLost = victimRecord.Combat.FightsLost + 1
                end
                if otherRecord and (killer == other or (fight.Damage[other] or 0) > 0) then
                    otherRecord.Combat.FightsWon = otherRecord.Combat.FightsWon + 1
                    local mine = fight.A == other and fight.GearA or fight.GearB
                    local theirs = fight.A == other and fight.GearB or fight.GearA
                    -- Only counts as a fair test when we actually knew both loadouts.
                    if mine and theirs then
                        otherRecord.Combat.UphillFights = otherRecord.Combat.UphillFights + 1
                        if mine <= theirs + 1 then
                            otherRecord.Combat.UphillWins = otherRecord.Combat.UphillWins + 1
                            addEvent(otherRecord, 'UphillWin', 0.85, victim.Name)
                        end
                    end
                end
            end

            -- Anyone who did real damage inside the assist window and did not land the kill.
            if other ~= killer and (fight.Damage[other] or 0) > 0 and now - fight.Last <= ASSIST_WINDOW then
                if otherRecord and not sameTeam(other, victim) then
                    otherRecord.Objectives.Assists = otherRecord.Objectives.Assists + 1
                    otherRecord.Teamwork.Assists = otherRecord.Teamwork.Assists + 1
                    addEvent(otherRecord, 'Assist', 0.8, victim.Name)
                end
            end
        end
    end

    local function onDeath(deathTable)
        if not running then return end
        local killer = deathTable.fromEntity and playersService:GetPlayerFromCharacter(deathTable.fromEntity)
        local victim = deathTable.entityInstance and playersService:GetPlayerFromCharacter(deathTable.entityInstance)
        if not victim then return end

        local now = tick()
        local victimRecord = victim ~= lplr and profileFor(victim) or nil
        if victimRecord then
            local context = victimRecord.Context
            context.Alive = false
            context.Respawns = context.Respawns + 1
            context.LastDeath = now
            victimRecord.Combat.Deaths = victimRecord.Combat.Deaths + 1
            victimRecord.Combat.Combo = 0

            -- What the death cost them. The last inventory we saw is the best estimate, and it is
            -- the number that separates a careful player from one who dies holding forty iron.
            local inv = victimRecord.Resources.LastInventory
            if inv then
                local lost = inv.Iron + inv.Diamond * 4 + inv.Emerald * 8
                if lost > 0 then
                    victimRecord.Resources.Lost = victimRecord.Resources.Lost + lost
                    victimRecord.Resources.LostEvents = victimRecord.Resources.LostEvents + 1
                end
            end
            addEvent(victimRecord, deathTable.finalKill and 'Eliminated' or 'Death', 1, killer and killer.Name or nil)
        end

        -- Void kill: somebody knocked them out over open air and the death followed. Inferred, so
        -- it carries a confidence rather than being counted as a clean fact.
        local void = pendingVoid[victim]
        if void and now - void.At <= VOID_WINDOW then
            local voidRecord = peek(void.From)
            if voidRecord and not sameTeam(void.From, victim) then
                voidRecord.Combat.VoidKills = voidRecord.Combat.VoidKills + 1
                addEvent(voidRecord, 'VoidKnockback', 0.7, victim.Name)
            end
        end
        pendingVoid[victim] = nil

        if killer and killer ~= victim and killer ~= lplr and not sameTeam(killer, victim) then
            local killerRecord = profileFor(killer)
            killerRecord.Combat.Kills = killerRecord.Combat.Kills + 1
            killerRecord.Context.LastAction = now

            -- What was this kill actually worth? An AFK, trapped, out-geared or endlessly
            -- respawning victim is not evidence of skill, and the discount is applied here rather
            -- than by trying to unpick it from an aggregate later. Killing us is worth most of a
            -- real kill - we are demonstrably a live human - but we do not profile ourselves, so
            -- it cannot be checked the way everybody else's is.
            local quality = victimRecord and playerQuality(victimRecord) or (victim == lplr and 0.85 or 0.5)
            local killerGear, victimGear = gearOf(killer), gearOf(victim)
            if killerGear and victimGear and killerGear > victimGear + 20 then
                quality = quality * math.clamp(1 - (killerGear - victimGear - 20) / 80, 0.35, 1)
            end
            observe(killerRecord.Combat.KillQuality, quality)

            if deathTable.finalKill then
                killerRecord.Combat.FinalKills = killerRecord.Combat.FinalKills + 1
                killerRecord.Objectives.FinalKills = killerRecord.Objectives.FinalKills + 1
                addEvent(killerRecord, 'FinalKill', 1, victim.Name)
            else
                addEvent(killerRecord, 'Kill', 1, victim.Name)
            end
        end

        resolveEngagements(victim, killer)
    end

    ----------------------------------------------------------------------------
    -- Event ingestion: beds and blocks.
    ----------------------------------------------------------------------------
    -- One place to register "they have turned up at somebody else's bed", so the counters and the
    -- event trail agree however we came to notice. Standing near a bed is weak evidence of intent
    -- and only reads as a rush early on; taking its defence apart is neither, and the confidence
    -- carried by the event says which of the two it was.
    local function noteBedApproach(record, rushing, confidence)
        if record.Objectives.BedApproachAt ~= 0 then return end
        record.Objectives.BedApproachAt = tick()
        record.Objectives.BedApproaches = record.Objectives.BedApproaches + 1
        if rushing then
            record.Objectives.Rushes = record.Objectives.Rushes + 1
        end
        addEvent(record, 'BedApproach', confidence, world.Stage)
    end

    local function onBedBreak(bedTable)
        if not running then return end
        local breaker = bedTable.player
        if not breaker or breaker == lplr then return end
        local record = profileFor(breaker)
        record.Objectives.Beds = record.Objectives.Beds + 1
        record.Context.LastAction = tick()

        -- How long from turning up at that bed to taking it. Short is a clean break; a long one
        -- means they were fought off it and came back, which is a different story - and a better
        -- one, so it is credited as a rush that eventually worked either way.
        if record.Objectives.BedApproachAt > 0 then
            observe(record.Objectives.BedBreakTime, math.clamp(tick() - record.Objectives.BedApproachAt, 1, 120))
            record.Objectives.RushWins = record.Objectives.RushWins + 1
            record.Objectives.BedApproachAt = 0
        end

        addEvent(record, 'BedBreak', 1, world.Stage)
        -- Pressure created for teammates: a bed gone is a team that has to defend instead of push.
        for _, entry in world.Roster do
            if entry.Player ~= breaker and sameTeam(entry.Player, breaker) then
                local mate = peek(entry.Player)
                if mate then
                    mate.Objectives.Pressure = mate.Objectives.Pressure + 1
                    touch(mate)
                end
            end
        end
    end

    local function onPlaceBlock(data)
        if not running or not playing() then return end
        local plr = data.player
        if not plr or plr == lplr then return end
        local record = profileFor(plr)
        local movement, now = record.Movement, tick()
        movement.Blocks = movement.Blocks + 1
        record.Context.LastAction = now

        -- Bridging: blocks laid in an unbroken run. The rate over the run is the speed signal, and
        -- a run that keeps going is what tells bridging apart from panic placing.
        if now - movement.BridgeAt <= 1.2 then
            movement.BridgeRun = movement.BridgeRun + 1
            movement.BridgeTime = movement.BridgeTime + (now - movement.BridgeAt)
            if movement.BridgeRun >= 4 and movement.BridgeTime > 0 then
                observe(movement.BridgeSpeed, movement.BridgeRun / movement.BridgeTime, 0.5)
            end
        else
            movement.BridgeRun, movement.BridgeTime = 1, 0
        end
        movement.BridgeAt = now

        local position = data.blockRef and data.blockRef.blockPosition
        if not position then
            touch(record)
            return
        end
        position = position * 3

        -- A block dropped under their own feet while falling fast is a clutch, not a bridge.
        if movement.LastPos and movement.LastVel and position.Y < movement.LastPos.Y - 2 and movement.LastVel.Y < -35 then
            movement.Clutches = movement.Clutches + 1
            addEvent(record, 'BlockClutch', 0.75)
        end

        local own, ownDist, _, enemyDist = bedsFor(plr, position)
        if own and ownDist <= BED_NEAR then
            record.Teamwork.Defends = record.Teamwork.Defends + 1
            if record.Sense.BedAlert and record.Sense.LastAlert > 0 then
                record.Sense.BedResponses = record.Sense.BedResponses + 1
                observe(record.Sense.BedResponseTime, math.clamp(now - record.Sense.LastAlert, 0.5, 30))
                record.Sense.BedAlert = false
            end
        elseif enemyDist <= BED_NEAR then
            -- Blocks at somebody else's bed are a push being consolidated, not defence.
            record.Objectives.Pressure = record.Objectives.Pressure + 0.5
        end
        touch(record)
    end

    local function onBreakBlock(data)
        if not running or not playing() then return end
        local plr = data.player
        if not plr or plr == lplr then return end
        local position = data.blockRef and data.blockRef.blockPosition
        if not position then return end
        local record = profileFor(plr)
        record.Context.LastAction = tick()
        position = position * 3

        local _, _, _, enemyDist = bedsFor(plr, position)
        if enemyDist <= BED_NEAR then
            -- Defence broken: blocks coming off the shell around a bed that is not theirs. Digging
            -- into someone's base is a push at any stage of the match, not just an early rush.
            record.Objectives.DefenceBroken = record.Objectives.DefenceBroken + 1
            noteBedApproach(record, true, 0.85)
        end
        touch(record)
    end

    ----------------------------------------------------------------------------
    -- Event ingestion: projectiles.
    ----------------------------------------------------------------------------
    -- Every projectile in the game replicates as a workspace child carrying the shooter's UserId,
    -- so launches are countable for everyone and not just for us. Hits come from the damage
    -- stream, and the two together are the only honest read on projectile accuracy.
    local function onProjectile(object)
        if not running then return end
        local shooter = object:GetAttribute('ProjectileShooter')
        if not shooter then return end
        local plr = playersService:GetPlayerByUserId(shooter)
        if not plr or plr == lplr then return end
        local record = peek(plr)
        if not record then return end
        record.Combat.Projectiles = record.Combat.Projectiles + 1
        record.Context.LastAction = tick()
        touch(record)
    end

    ----------------------------------------------------------------------------
    -- Sampling.
    ----------------------------------------------------------------------------
    local function sampleEntity(ent, record, dt, near)
        local root = ent.RootPart
        if not root or not root.Parent then return end
        local now = tick()
        local movement, context = record.Movement, record.Context
        local position = root.Position
        local velocity = root.AssemblyLinearVelocity
        local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

        -- A streaming gap. Nothing measured across one means anything, so the movement history is
        -- dropped rather than read as a very fast trip across the map.
        if now - record.LastSeen > SEEN_TIMEOUT then
            context.Gaps = context.Gaps + 1
            context.GapTime = context.GapTime + (now - record.LastSeen)
            movement.LastPos, movement.LastDir, movement.LastVel = nil, nil, nil
        end
        record.LastSeen = now
        context.Samples = context.Samples + 1
        record.Observed = record.Observed + math.min(dt, 1)

        local previous = movement.LastPos
        if previous then
            local step = (position - previous).Magnitude
            if step > TELEPORT_JUMP then
                -- A teleport, a respawn or a lag spike, not movement.
                context.Lagged = context.Lagged + 1
                movement.LastPos, movement.LastDir, movement.LastVel = position, nil, velocity
                touch(record)
                return
            end
            movement.Distance = movement.Distance + step
            if step > 0.6 then
                context.LastMove = now
            end
        end

        local fighting = now - record.Combat.LastHit <= FIGHT_MEMORY or now - record.Combat.LastHurt <= FIGHT_MEMORY
        local sampleWeight = math.min(dt * 4, 1)

        -- Strafing. Direction changes frame to frame while fighting, never while walking the map.
        if fighting and movement.LastDir and horizontal.Magnitude > 4 then
            local change = 1 - math.clamp(horizontal.Unit:Dot(movement.LastDir), -1, 1)
            observe(record.Combat.Strafe, math.clamp(change / 1.2, 0, 1), sampleWeight)
        end
        if horizontal.Magnitude > 1 then
            movement.LastDir = horizontal.Unit
        end

        -- Aim tracking. How well they keep facing whoever they are actually fighting.
        local opponent = record.Combat.LastVictim or record.Combat.LastHurtBy
        if fighting and opponent and opponent.Character then
            local theirRoot = opponent.Character:FindFirstChild('HumanoidRootPart')
            if theirRoot then
                local toward = (theirRoot.Position - position) * Vector3.new(1, 0, 1)
                local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
                if toward.Magnitude > 1 and facing.Magnitude > 0.01 then
                    observe(record.Combat.Tracking, math.clamp(facing.Unit:Dot(toward.Unit), 0, 1), sampleWeight)
                end
            end
        end

        -- Pauses. Standing still mid-fight is hesitation; standing still out of one is not.
        if fighting and horizontal.Magnitude < 1.5 then
            if movement.PauseAt == 0 then
                movement.PauseAt = now
            elseif now - movement.PauseAt > 0.8 then
                movement.Pauses = movement.Pauses + 1
                movement.PauseAt = now
            end
        else
            movement.PauseAt = 0
        end

        -- Knockback recovery: how fast they get back to moving under their own power after a hit -
        -- the difference between eating a combo and walking out of one.
        if movement.KnockbackAt > 0 and now - movement.KnockbackAt < 3 then
            if horizontal.Magnitude > 12 and math.abs(velocity.Y) < 12 then
                observe(movement.Recovery, math.clamp(now - movement.KnockbackAt, 0.05, 3))
                movement.KnockbackAt = 0
            end
        end

        if ent.Jumping then
            movement.Jumps = movement.Jumps + 1
        end

        -- Falls. Falling after being hit is somebody else's doing; falling with nothing on the
        -- clock is their own, and a big drop they walk away from was a save.
        local wasAirborne = movement.Airborne
        movement.Airborne = velocity.Y < -12
        if movement.Airborne and not wasAirborne then
            movement.FallFrom = position
        elseif wasAirborne and not movement.Airborne and movement.FallFrom then
            local drop = movement.FallFrom.Y - position.Y
            if drop > 12 then
                movement.Falls = movement.Falls + 1
                if now - record.Combat.LastHurt > FIGHT_MEMORY then
                    movement.UnforcedFalls = movement.UnforcedFalls + 1
                    addEvent(record, 'UnforcedFall', 0.6)
                elseif drop > 25 then
                    movement.Saves = movement.Saves + 1
                end
            elseif drop > 4 then
                movement.Parkour = movement.Parkour + 1
            end
            movement.FallFrom = nil
        end

        movement.LastPos, movement.LastVel = position, velocity

        -- Generator camping and resource control. Time on a generator is economy; time on a
        -- diamond or emerald generator is map control, whoever owns it.
        local genDist, genKind = nearestGenerator(position)
        if genDist <= GEN_NEAR then
            record.Resources.GenTime = record.Resources.GenTime + dt
            if record.Resources.GenAt == 0 or now - record.Resources.GenAt > 5 then
                record.Resources.GenVisits = record.Resources.GenVisits + 1
            end
            record.Resources.GenAt = now
            if genKind == 'diamond' or genKind == 'emerald' then
                record.Teamwork.ControlTime = record.Teamwork.ControlTime + dt
            end
        end

        -- Positioning. Home ground is safe; deep in enemy territory with no teammate in reach is
        -- not. Kept as a running fraction so one bad push does not erase an hour of good sense,
        -- and one good stretch does not hide a habit of overextending.
        local plr = record.Player
        local own, ownDist, _, enemyDist = bedsFor(plr, position)
        local nearOwn = own ~= nil and ownDist <= BED_NEAR
        if nearOwn then
            record.Sense.SafeTime = record.Sense.SafeTime + dt
        end
        if enemyDist <= BED_NEAR * 2 then
            record.Sense.ExposedTime = record.Sense.ExposedTime + dt
            noteBedApproach(record, world.Stage == 'Early', 0.5)
        elseif record.Objectives.BedApproachAt ~= 0
            and enemyDist > BED_NEAR * 4
            and now - record.Objectives.BedApproachAt > 20
        then
            -- Broken off and gone. The next time they come back is a fresh approach, and the one
            -- they gave up on stays on the books as a rush that did not work.
            record.Objectives.BedApproachAt = 0
        end

        -- Teammate and enemy proximity, read off the shared roster rather than by walking the
        -- entity list once per player per frame.
        local mateNear, enemyNear = false, false
        for _, entry in world.Roster do
            if entry.Player ~= plr then
                if (entry.Position - position).Magnitude <= MATE_NEAR then
                    if entry.Team ~= nil and entry.Team == context.Team then
                        mateNear = true
                    else
                        enemyNear = true
                    end
                end
            end
        end
        if mateNear and enemyNear then
            record.Teamwork.PushWindow = record.Teamwork.PushWindow + dt
        end
        observe(movement.Positioning, (nearOwn or mateNear or not enemyNear) and 1 or 0, math.min(dt, 0.5))

        -- A teammate in trouble within reach is a chance to help. Whether they took it is answered
        -- by the damage they then put on whoever was doing it, over in onDamage.
        if near and now - record.Sense.SaveChanceAt > 3 then
            for _, entry in world.Roster do
                if entry.Player ~= plr and entry.Team ~= nil and entry.Team == context.Team then
                    local mate = peek(entry.Player)
                    if mate and now - mate.Combat.LastHurt <= 2 and (entry.Position - position).Magnitude <= MATE_NEAR then
                        record.Sense.SaveChanceAt = now
                        record.Teamwork.SaveChances = record.Teamwork.SaveChances + 1
                        break
                    end
                end
            end
        end

        touch(record)
    end

    ----------------------------------------------------------------------------
    -- Terrain probes.
    ----------------------------------------------------------------------------
    -- Two rays: straight down, and down from a stride along the direction of travel. Between them
    -- they answer "are they over the void", "how far above the floor are they" and "are they
    -- walking at an edge", which is every terrain question the movement signals ask. Budgeted per
    -- frame so a full lobby can never turn edge awareness into a raycast storm.
    local probeParams = RaycastParams.new()
    probeParams.RespectCanCollide = true
    probeParams.FilterType = Enum.RaycastFilterType.Exclude
    local probeIgnore = {}

    local function probeGround(origin)
        probeParams.FilterDescendantsInstances = probeIgnore
        local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0), probeParams)
        return hit and hit.Position.Y or nil
    end

    local function probeEntity(ent, record)
        if probeBudget <= 0 then return end
        local root = ent.RootPart
        if not root or not root.Parent then return end
        probeBudget = probeBudget - 1

        table.clear(probeIgnore)
        table.insert(probeIgnore, ent.Character)
        table.insert(probeIgnore, gameCamera)
        if AntiFallPart then
            table.insert(probeIgnore, AntiFallPart)
        end

        local movement = record.Movement
        local position = root.Position
        local ground = probeGround(position)
        movement.Ground = ground
        movement.OverVoid = ground == nil

        -- Edge awareness: is there floor a stride ahead of where they are heading? If not, and
        -- they slow or turn instead of walking off it, that is a read rather than luck.
        local direction = movement.LastDir
        if direction and ground then
            if probeGround(position + direction * 5) then
                if movement.EdgeAt > 0 and tick() - movement.EdgeAt < 1 then
                    movement.EdgeStops = movement.EdgeStops + 1
                    movement.EdgeAt = 0
                end
            else
                movement.EdgeApproaches = movement.EdgeApproaches + 1
                movement.EdgeAt = tick()
            end
        end
    end

    ----------------------------------------------------------------------------
    -- Inventory deltas.
    ----------------------------------------------------------------------------
    -- Purchases, resource spend, tool preparation and gear progression all fall out of watching
    -- what the replicated inventory does between two looks at it.
    local function sampleInventory(record)
        local inv = inventoryOf(record.Player)
        if not inv then return end
        local now = tick()
        local resources = record.Resources
        if now - resources.InventoryAt < 1 then return end
        resources.InventoryAt = now

        local items = 0
        for _ in (inv.items or {}) do
            items = items + 1
        end
        local snapshot = {
            Iron = resourceCount(inv, 'iron'),
            Diamond = resourceCount(inv, 'diamond'),
            Emerald = resourceCount(inv, 'emerald'),
            Gear = swordDamage(inv) + armourValue(inv) * 30,
            Items = items
        }

        local previous = resources.LastInventory
        resources.LastInventory = snapshot
        record.Context.Gear = snapshot.Gear
        record.Context.Armour = armourValue(inv)
        if snapshot.Gear > resources.BestGear then
            resources.BestGear = snapshot.Gear
            observe(resources.GearTier, math.clamp(snapshot.Gear / 90, 0, 1))
        end

        -- Tool preparation: holding the right thing for what is about to happen. Swapping to a
        -- sword before contact, or to blocks over a gap, is reading a moment ahead.
        local hand = inv.hand
        local handType = hand and hand.itemType or nil
        if handType and handType ~= record.Sense.LastHand then
            record.Sense.LastHand = handType
            record.Sense.ToolSwaps = record.Sense.ToolSwaps + 1
            local meta = bedwars.ItemMeta[handType]
            if meta then
                local fighting = now - record.Combat.LastHit <= FIGHT_MEMORY or now - record.Combat.LastHurt <= FIGHT_MEMORY
                local right = (fighting and meta.sword ~= nil) or (not fighting and record.Movement.OverVoid and meta.block ~= nil)
                observe(resources.Prepared, right and 1 or 0)
            end
        end

        if not previous then return end
        -- Resources going up is collection; going down is spending, and whether the item count
        -- went with them says whether it was bought for themselves or given away.
        resources.Iron = resources.Iron + math.max(snapshot.Iron - previous.Iron, 0)
        resources.Diamond = resources.Diamond + math.max(snapshot.Diamond - previous.Diamond, 0)
        resources.Emerald = resources.Emerald + math.max(snapshot.Emerald - previous.Emerald, 0)

        local ironSpent = math.max(previous.Iron - snapshot.Iron, 0)
        local diamondSpent = math.max(previous.Diamond - snapshot.Diamond, 0)
        local emeraldSpent = math.max(previous.Emerald - snapshot.Emerald, 0)
        resources.IronSpent = resources.IronSpent + ironSpent
        resources.DiamondSpent = resources.DiamondSpent + diamondSpent
        resources.EmeraldSpent = resources.EmeraldSpent + emeraldSpent

        local spent = ironSpent + diamondSpent + emeraldSpent
        if spent > 0 then
            record.Context.LastAction = now
            if snapshot.Items >= previous.Items then
                resources.Purchases = resources.Purchases + 1
                if snapshot.Gear > previous.Gear then
                    addEvent(record, 'Upgrade', 0.8)
                end
            else
                -- Resources gone and items gone with them: handed to a teammate, or spent at the
                -- upgrade shop. Both are contributions rather than losses, and we cannot tell
                -- which from here - so the event says how sure we are.
                resources.Upgrades = resources.Upgrades + 1
                record.Teamwork.Shared = record.Teamwork.Shared + 1
                addEvent(record, 'TeamSpend', 0.45)
            end
        end
    end

    ----------------------------------------------------------------------------
    -- Context, threats and decisions.
    ----------------------------------------------------------------------------
    local function updateContext(record, ent)
        local plr = record.Player
        local context = record.Context
        local now = tick()
        context.Health = healthFraction(plr)
        context.Alive = ent ~= nil and ent.Health > 0

        -- The allocating reads are throttled; the cheap attribute reads above are not.
        if now - record.LastHeavy >= HEAVY_INTERVAL then
            record.LastHeavy = now
            context.Kit = kitOf(plr)
            context.Team = teamOf(plr)
            context.Trapped = statusTrapped(plr)
        end

        -- AFK is only decidable while we can actually see them: a streamed-out player is not
        -- standing still, we just are not looking. An AFK player is not playing badly, they are
        -- not playing, so this freezes the claim rather than grinding them toward New.
        local afk = context.Alive and (now - math.max(context.LastMove, context.LastAction)) > AFK_TIME
        if afk ~= context.AFK then
            context.AFK = afk
            addEvent(record, afk and 'AFK' or 'Active', 0.7)
        end
    end

    local function updateThreats(record, ent)
        local root = ent.RootPart
        if not root or not root.Parent then return end
        local plr = record.Player
        local position = root.Position
        local sense = record.Sense
        local now = tick()

        -- Threat awareness: an enemy inside striking distance. Whether they answered it - turned,
        -- moved off, or hit back - inside a couple of seconds is the read.
        local threat = nil
        for _, entry in world.Roster do
            if entry.Player ~= plr and not (entry.Team ~= nil and entry.Team == record.Context.Team) then
                if (entry.Position - position).Magnitude <= THREAT_NEAR then
                    threat = entry.Player
                    break
                end
            end
        end

        if threat and not sense.ThreatFrom then
            sense.ThreatFrom, sense.ThreatAt, sense.ThreatAnswered = threat, now, false
            sense.Threats = sense.Threats + 1
        elseif not threat then
            sense.ThreatFrom, sense.ThreatAnswered = nil, false
        end

        if sense.ThreatFrom and not sense.ThreatAnswered and now - sense.ThreatAt <= 2.5 then
            local moving = record.Movement.LastVel ~= nil
                and Vector3.new(record.Movement.LastVel.X, 0, record.Movement.LastVel.Z).Magnitude > 8
            if moving or now - record.Combat.LastHit <= 2.5 then
                sense.ThreatReactions = sense.ThreatReactions + 1
                sense.ThreatAnswered = true
            end
        end

        -- Bed under attack. Whether they turn up at all is the defence reaction; the block-place
        -- handler closes the loop when they get there and start walling it back up.
        local own = select(1, bedsFor(plr, position))
        if own then
            local underThreat = false
            for _, entry in world.Roster do
                if not (entry.Team ~= nil and entry.Team == record.Context.Team) then
                    if (entry.Position - own.Position).Magnitude <= BED_NEAR then
                        underThreat = true
                        break
                    end
                end
            end
            if underThreat and not sense.BedAlert then
                sense.BedAlert, sense.LastAlert = true, now
                sense.BedAlerts = sense.BedAlerts + 1
            elseif not underThreat and sense.BedAlert then
                if sense.LastAlert > 0 and (own.Position - position).Magnitude <= BED_NEAR then
                    sense.BedResponses = sense.BedResponses + 1
                    observe(sense.BedResponseTime, math.clamp(now - sense.LastAlert, 0.5, 30))
                end
                sense.BedAlert = false
            end
        end

        -- Retreating. Breaking off a losing fight and living is one of the clearest game-sense
        -- reads there is; dying on the spot at the same health is the other side of it.
        if now - record.Combat.LastHurt <= FIGHT_MEMORY and record.Context.Health < 0.35 then
            if not sense.RetreatFrom then
                sense.RetreatFrom, sense.RetreatAt = position, now
            end
        elseif sense.RetreatFrom then
            if now - sense.RetreatAt < 8 then
                if not record.Context.Alive then
                    sense.LowHealthDeaths = sense.LowHealthDeaths + 1
                elseif (position - sense.RetreatFrom).Magnitude > 40 then
                    sense.Retreats = sense.Retreats + 1
                    sense.LowHealthEscapes = sense.LowHealthEscapes + 1
                    record.Objectives.Escapes = record.Objectives.Escapes + 1
                    addEvent(record, 'Escape', 0.7)
                end
            end
            sense.RetreatFrom = nil
        end

        -- Chases. Running somebody down across the map, landing nothing, while the objective is
        -- somewhere else, is time nobody got anything out of.
        local victim = record.Combat.LastVictim
        local theirRoot = victim and victim.Character and victim.Character:FindFirstChild('HumanoidRootPart')
        if theirRoot and now - record.Combat.LastHit < 6 and (theirRoot.Position - position).Magnitude > 60 then
            if sense.ChaseAt == 0 then
                sense.ChaseAt = now
                sense.Chases = sense.Chases + 1
            elseif now - sense.ChaseAt > 6 then
                sense.PointlessChases = sense.PointlessChases + 1
                sense.ChaseAt = 0
            end
        else
            sense.ChaseAt = 0
        end
    end

    ----------------------------------------------------------------------------
    -- Category scoring.
    ----------------------------------------------------------------------------
    -- A note on confidence, because it is the whole design. Where absence means something - they
    -- have been on a generator for four minutes and have no diamonds - confidence comes from how
    -- long we watched, so a zero is a confident zero. Where absence means nothing - they have
    -- never fired an arrow, so we cannot say whether they can aim one - confidence comes from the
    -- count, and stays at zero until there is something to judge.
    local function watchConf(record, seconds)
        return math.clamp(record.Observed / (seconds or 90), 0, 1)
    end

    local function scoreCombat(record)
        local b = blender()
        local combat = record.Combat
        local timing = timingConfidence()
        local kitFactor = KIT_COMBAT[record.Context.Kit or ''] or 1
        local fights = combat.Kills + combat.Deaths
        local damage = combat.DamageDealt + combat.DamageTaken
        -- Kills against nobody are worth nothing. This multiplies every trade-shaped signal, and
        -- it is what keeps farming from reading as skill.
        local honesty = math.clamp(combat.KillQuality.v, 0.15, 1)

        signal(b, 'Trades',
            scale(safeDiv(combat.Kills - combat.Deaths, math.max(fights, 1)) * honesty, -0.6, 0.6),
            1.4, countConf(fights, 8))

        signal(b, 'Fight wins',
            scale(safeDiv(combat.FightsWon, combat.FightsWon + combat.FightsLost), 0.25, 0.75),
            1.2, countConf(combat.FightsWon + combat.FightsLost, 6))

        signal(b, 'Hit accuracy',
            scale(safeDiv(combat.SwingHits, combat.Swings), 0.3, 0.8),
            1.1, combat.Swings >= 8 and math.min(countConf(combat.Swings, 25), 0.55) or 0)

        signal(b, 'First hits',
            scale(safeDiv(combat.FirstHits, combat.FirstHitChances), 0.3, 0.75),
            1.0, countConf(combat.FirstHitChances, 6) * timing)

        signal(b, 'Combo consistency',
            scale(safeDiv(combat.ComboHits, math.max(combat.MeleeHits, 1)), 0.1, 0.5),
            1.0, countConf(combat.MeleeHits, 20))

        signal(b, 'Best combo',
            reward(combat.BestCombo - 2, 5),
            0.6, countConf(combat.MeleeHits, 20))

        signal(b, 'Damage traded',
            scale(safeDiv(combat.DamageDealt - combat.DamageTaken, math.max(damage, 1)), -0.4, 0.4),
            1.2, math.clamp(damage / 400, 0, 1))

        signal(b, 'Reaction time',
            -scale(combat.Reaction.v, 0.25, 1.1),
            0.9, evidence(combat.Reaction, 6) * timing)

        signal(b, 'Strafing',
            scale(combat.Strafe.v, 0.15, 0.65),
            0.8, evidence(combat.Strafe, 25) * kitFactor)

        signal(b, 'Aim tracking',
            scale(combat.Tracking.v, 0.45, 0.9),
            1.0, evidence(combat.Tracking, 25) * timing)

        signal(b, 'Target switching',
            bell(safeDiv(combat.Switches, math.max(fights, 1)), 0.8, 1.6),
            0.5, countConf(combat.Switches, 4))

        signal(b, 'Projectile accuracy',
            scale(safeDiv(combat.ProjectileHits, combat.Projectiles), 0.15, 0.6),
            0.9, combat.Projectiles >= 4 and countConf(combat.Projectiles, 12) or 0)

        signal(b, 'Void knockbacks',
            reward(combat.VoidKills, 3),
            0.6, watchConf(record, 120) * 0.7)

        signal(b, 'Against better gear',
            scale(safeDiv(combat.UphillWins, combat.UphillFights), 0.2, 0.7),
            1.3, countConf(combat.UphillFights, 5))

        return resolve(b)
    end

    local function scoreMovement(record)
        local b = blender()
        local movement = record.Movement
        local kitFactor = KIT_MOVEMENT[record.Context.Kit or ''] or 1

        signal(b, 'Bridging speed',
            scale(movement.BridgeSpeed.v, 1.2, 3.2),
            1.2, evidence(movement.BridgeSpeed, 5) * kitFactor)

        signal(b, 'Block efficiency',
            scale(safeDiv(movement.Distance, math.max(movement.Blocks, 1)), 1.5, 5),
            0.9, countConf(movement.Blocks, 25))

        signal(b, 'Hesitation',
            -scale(safeDiv(movement.Pauses, math.max(record.Observed / 60, 0.2)), 1, 8),
            0.7, watchConf(record, 90))

        signal(b, 'Unforced falls',
            -reward(movement.UnforcedFalls, 4),
            1.1, watchConf(record, 90))

        signal(b, 'Parkour',
            reward(movement.Parkour, 12),
            0.6, watchConf(record, 120) * kitFactor)

        signal(b, 'Pathing',
            scale(safeDiv(movement.Distance, math.max(record.Observed, 1)), 4, 13),
            0.7, watchConf(record, 60))

        signal(b, 'Edge awareness',
            scale(safeDiv(movement.EdgeStops, math.max(movement.EdgeApproaches, 1)), 0.2, 0.8),
            1.0, countConf(movement.EdgeApproaches, 8))

        signal(b, 'Combat positioning',
            scale(movement.Positioning.v, 0.35, 0.85),
            0.9, evidence(movement.Positioning, 20))

        signal(b, 'Knockback recovery',
            -scale(movement.Recovery.v, 0.3, 1.6),
            1.0, evidence(movement.Recovery, 5))

        signal(b, 'Block clutches',
            reward(movement.Clutches + movement.Saves, 4),
            1.1, watchConf(record, 120) * 0.8)

        return resolve(b)
    end

    local function scoreSense(record)
        local b = blender()
        local sense = record.Sense
        local exposure = sense.SafeTime + sense.ExposedTime

        signal(b, 'Threat awareness',
            scale(safeDiv(sense.ThreatReactions, math.max(sense.Threats, 1)), 0.3, 0.85),
            1.3, countConf(sense.Threats, 6))

        signal(b, 'Bed defence',
            scale(safeDiv(sense.BedResponses, math.max(sense.BedAlerts, 1)), 0.2, 0.8),
            1.2, countConf(sense.BedAlerts, 3))

        signal(b, 'Defence speed',
            -scale(sense.BedResponseTime.v, 3, 18),
            0.8, evidence(sense.BedResponseTime, 3))

        signal(b, 'Retreating',
            scale(safeDiv(sense.LowHealthEscapes, math.max(sense.LowHealthEscapes + sense.LowHealthDeaths, 1)), 0.2, 0.8),
            1.1, countConf(sense.LowHealthEscapes + sense.LowHealthDeaths, 4))

        signal(b, 'Fight selection',
            scale(safeDiv(record.Combat.FightsWon, math.max(record.Combat.FightsWon + record.Combat.FightsLost, 1)), 0.3, 0.9),
            1.0, countConf(record.Combat.FightsWon + record.Combat.FightsLost, 6))

        signal(b, 'Pointless chases',
            -scale(safeDiv(sense.PointlessChases, math.max(sense.Chases, 1)), 0.1, 0.7),
            0.8, countConf(sense.Chases, 4))

        signal(b, 'Safe positioning',
            scale(safeDiv(sense.SafeTime, math.max(exposure, 1)), 0.15, 0.6),
            0.6, math.clamp(exposure / 60, 0, 1))

        signal(b, 'Adapting tools',
            scale(record.Resources.Prepared.v, 0.3, 0.85),
            0.9, evidence(record.Resources.Prepared, 8))

        -- Adapting after failure: coming back at a bed they were pushed off, or changing the way
        -- in, rather than feeding the same approach until the match ends.
        signal(b, 'Adapting after failure',
            scale(safeDiv(record.Objectives.RushWins, math.max(record.Objectives.Rushes, 1)), 0.15, 0.7),
            1.0, countConf(record.Objectives.Rushes, 3))

        return resolve(b)
    end

    local function scoreObjectives(record)
        local b = blender()
        local objectives = record.Objectives
        local minutes = math.max(record.Observed / 60, 0.5)

        signal(b, 'Beds broken',
            reward(objectives.Beds, 2),
            1.5, watchConf(record, 150))

        signal(b, 'Bed approaches',
            scale(safeDiv(objectives.BedApproaches, minutes), 0.1, 1.2),
            0.9, watchConf(record, 120))

        signal(b, 'Rush success',
            scale(safeDiv(objectives.RushWins, math.max(objectives.Rushes, 1)), 0.1, 0.7),
            1.2, countConf(objectives.Rushes, 3))

        signal(b, 'Bed break speed',
            -scale(objectives.BedBreakTime.v, 8, 60),
            0.9, evidence(objectives.BedBreakTime, 2))

        signal(b, 'Defence broken',
            reward(objectives.DefenceBroken, 25),
            0.7, watchConf(record, 120))

        signal(b, 'Final kills',
            reward(objectives.FinalKills, 3),
            1.2, watchConf(record, 150))

        signal(b, 'Assists',
            reward(objectives.Assists, 5),
            0.7, watchConf(record, 120) * (world.TeamSize > 1 and 1 or 0))

        signal(b, 'Escapes',
            reward(objectives.Escapes, 3),
            0.6, watchConf(record, 120))

        signal(b, 'Pressure created',
            reward(objectives.Pressure, 4),
            0.8, watchConf(record, 120))

        return resolve(b)
    end

    local function scoreResources(record)
        local b = blender()
        local resources = record.Resources
        local minutes = math.max(record.Observed / 60, 0.3)
        -- Every resource read comes from the replicated inventory. Without it there is nothing
        -- here to say, and saying so is the point.
        local replicated = inventoryOf(record.Player) and 1 or 0

        signal(b, 'Generator time',
            bell(safeDiv(resources.GenTime, math.max(record.Observed, 1)), 0.25, 0.25),
            0.9, watchConf(record, 90))

        signal(b, 'Iron income',
            scale(safeDiv(resources.Iron, minutes), 4, 30),
            0.8, watchConf(record, 120) * replicated)

        signal(b, 'Diamond income',
            scale(safeDiv(resources.Diamond, minutes), 0.2, 2.5),
            1.0, watchConf(record, 150) * replicated)

        signal(b, 'Emerald income',
            scale(safeDiv(resources.Emerald, minutes), 0.05, 1.2),
            0.9, watchConf(record, 180) * replicated)

        signal(b, 'Spending',
            scale(safeDiv(resources.IronSpent + resources.DiamondSpent * 4 + resources.EmeraldSpent * 8,
                math.max(resources.Iron + resources.Diamond * 4 + resources.Emerald * 8, 1)), 0.25, 0.85),
            1.0, watchConf(record, 120) * replicated)

        signal(b, 'Resources lost on death',
            -scale(safeDiv(resources.Lost, math.max(resources.LostEvents, 1)), 5, 45),
            1.0, countConf(resources.LostEvents, 2))

        signal(b, 'Purchases',
            scale(safeDiv(resources.Purchases, minutes), 0.3, 3),
            0.7, watchConf(record, 120) * replicated)

        signal(b, 'Tool preparation',
            scale(resources.Prepared.v, 0.3, 0.85),
            0.8, evidence(resources.Prepared, 8))

        signal(b, 'Gear progression',
            scale(resources.GearTier.v, 0.15, 0.8),
            1.1, evidence(resources.GearTier, 3) * replicated)

        signal(b, 'Team upgrades',
            reward(resources.Upgrades, 3),
            0.7, watchConf(record, 150) * replicated * 0.5)

        return resolve(b)
    end

    local function scoreTeamwork(record)
        local b = blender()
        local team = record.Teamwork
        -- In a solo mode there is nobody to help. Rather than mark a solo player down for it, the
        -- whole category simply has no confidence and drops out of their overall score.
        local solo = world.TeamSize > 1 and 1 or 0
        local watched = watchConf(record, 120) * solo

        signal(b, 'Assists', reward(team.Assists, 4), 1.2, watched)

        signal(b, 'Protecting teammates',
            scale(safeDiv(team.Saves, math.max(team.SaveChances, 1)), 0.1, 0.6),
            1.1, countConf(team.SaveChances, 3) * solo)

        signal(b, 'Sharing resources', reward(team.Shared, 3), 0.8, watched * 0.6)

        signal(b, 'Defending', reward(team.Defends, 10), 1.0, watched)

        signal(b, 'Coordinated pushes',
            scale(safeDiv(team.PushWindow, math.max(record.Observed, 1)), 0.05, 0.4),
            1.0, watched)

        signal(b, 'Diamond and emerald control',
            scale(safeDiv(team.ControlTime, math.max(record.Observed, 1)), 0.03, 0.3),
            0.9, watchConf(record, 120))

        return resolve(b)
    end

    ----------------------------------------------------------------------------
    -- Roles.
    ----------------------------------------------------------------------------
    -- Each role is scored on its own evidence, and the winner has to be clearly ahead of the
    -- runner-up to be claimed. Anything else is Mixed, which is a real answer rather than a
    -- fallback: most players genuinely do a bit of everything.
    local function roleOf(record)
        local combat, sense = record.Combat, record.Sense
        local objectives, resources, team = record.Objectives, record.Resources, record.Teamwork
        local watched = math.max(record.Observed, 1)
        local minutes = math.max(watched / 60, 0.3)

        local scores = {
            Rusher = math.clamp(
                safeDiv(objectives.BedApproaches, minutes) * 0.5
                + objectives.Beds * 0.5
                + reward(objectives.DefenceBroken, 20) * 0.3
                + safeDiv(sense.ExposedTime, watched) * 0.6, 0, 2),
            Defender = math.clamp(
                safeDiv(sense.SafeTime, watched) * 1.1
                + reward(team.Defends, 10) * 0.6
                + safeDiv(sense.BedResponses, math.max(sense.BedAlerts, 1)) * 0.5, 0, 2),
            Fighter = math.clamp(
                safeDiv(combat.Kills + combat.FightsWon, minutes) * 0.35
                + reward(combat.DamageDealt, 400) * 0.4
                + reward(combat.MeleeHits, 40) * 0.3, 0, 2),
            Support = math.clamp(
                reward(team.Assists, 3) * 0.7
                + safeDiv(team.PushWindow, watched) * 0.9
                + reward(team.Shared, 4) * 0.25, 0, 2),
            Economy = math.clamp(
                safeDiv(resources.GenTime, watched) * 1.2
                + reward(resources.Purchases, 5) * 0.5
                + reward(resources.Iron, 60) * 0.4, 0, 2),
            ResourceControl = math.clamp(
                safeDiv(team.ControlTime, watched) * 1.6
                + reward(resources.Diamond + resources.Emerald * 2, 8) * 0.6, 0, 2)
        }

        local best, bestScore, second = 'Mixed', 0, 0
        for _, role in ROLES do
            local value = scores[role] or 0
            if value > bestScore then
                best, second, bestScore = role, bestScore, value
            elseif value > second then
                second = value
            end
        end

        if bestScore < 0.35 or bestScore < second * 1.35 then
            return 'Mixed', scores
        end
        return best, scores
    end

    ----------------------------------------------------------------------------
    -- Rating bands.
    ----------------------------------------------------------------------------
    -- Sliders can be dragged into any order. Read them back as a strictly descending set so a band
    -- can never swallow the one above it and every rating stays reachable.
    local function bands()
        local sweat = SweatAt.Value
        local skilled = math.min(SkilledAt.Value, sweat - 1)
        local above = math.min(AboveAt.Value, skilled - 1)
        local beginner = math.min(BeginnerBelow.Value, above - 1)
        return sweat, skilled, above, beginner, math.min(NewBelow.Value, beginner - 1)
    end

    local function ratingOf(score, confidence)
        if confidence < (MinConfidence.Value / 100) then return 'Unknown' end
        local sweat, skilled, above, beginner, fresh = bands()
        if score >= sweat then return 'Sweat' end
        if score >= skilled then return 'Skilled' end
        if score >= above then return 'Above Average' end
        if score > beginner then return 'Average' end
        if score > fresh then return 'Beginner' end
        return 'New'
    end

    ----------------------------------------------------------------------------
    -- Building the answer.
    ----------------------------------------------------------------------------
    local function blankAnalysis()
        return {
            OverallSkill = 0,
            Confidence = 0,
            Rating = 'Unknown',
            Role = 'Mixed',
            Categories = {
                Combat = 0,
                Movement = 0,
                GameSense = 0,
                Objectives = 0,
                Resources = 0,
                Teamwork = 0
            },
            Strengths = {},
            Weaknesses = {},
            RecentEvents = {}
        }
    end

    -- Strengths and weaknesses come from the named signals rather than the category totals, so the
    -- answer is "their bridging is quick" and not "movement: 71".
    local function highlights(blends)
        local pool = {}
        for _, entry in blends do
            for name, data in entry.named do
                if data.Confidence >= 0.35 and math.abs(data.Deviation) >= 0.3 then
                    table.insert(pool, {Name = name, Score = data.Deviation * data.Confidence * data.Weight})
                end
            end
        end
        table.sort(pool, function(a, b)
            return a.Score > b.Score
        end)

        local strengths, weaknesses = {}, {}
        for _, entry in pool do
            if entry.Score > 0.25 and #strengths < 4 then
                table.insert(strengths, entry.Name)
            end
        end
        for index = #pool, 1, -1 do
            if pool[index].Score < -0.25 and #weaknesses < 4 then
                table.insert(weaknesses, pool[index].Name)
            end
        end
        return strengths, weaknesses
    end

    local function round(value, places)
        local factor = 10 ^ (places or 1)
        return math.floor(value * factor + 0.5) / factor
    end

    local function rebuild(record)
        local now = tick()
        record.Dirty = false
        record.NextScore = now + RESCORE_INTERVAL

        local scores, confs, blends = {}, {}, {}
        scores.Combat, confs.Combat, blends[1] = scoreCombat(record)
        scores.Movement, confs.Movement, blends[2] = scoreMovement(record)
        scores.GameSense, confs.GameSense, blends[3] = scoreSense(record)
        scores.Objectives, confs.Objectives, blends[4] = scoreObjectives(record)
        scores.Resources, confs.Resources, blends[5] = scoreResources(record)
        scores.Teamwork, confs.Teamwork, blends[6] = scoreTeamwork(record)

        local role, roleScores = roleOf(record)
        local weights = ROLE_WEIGHTS[role] or ROLE_WEIGHTS.Mixed

        -- Overall is a confidence-weighted blend: a category we have barely observed cannot drag
        -- the answer around, and one we have watched thoroughly is what the answer is made of.
        local sum, weight, confSum, confWeight = 0, 0, 0, 0
        for _, name in CATEGORIES do
            local categoryWeight = weights[name]
            local w = categoryWeight * confs[name]
            sum = sum + scores[name] * w
            weight = weight + w
            confSum = confSum + confs[name] * categoryWeight
            confWeight = confWeight + categoryWeight
        end

        local quality = dataQuality(record)
        local confidence = math.clamp(safeDiv(confSum, confWeight) * quality, 0, 1)
        if record.Context.AFK then
            confidence = confidence * 0.6
        end
        -- Hold the overall toward Average by however much we do not know, so a thin read never
        -- comes out as a confident claim.
        local overall = math.clamp(50 + ((weight > 0 and (sum / weight) or 50) - 50) * (0.35 + 0.65 * confidence), 0, 100)
        local rating = ratingOf(overall, confidence)
        local strengths, weaknesses = highlights(blends)

        local events = {}
        for index = #record.Events, 1, -1 do
            local entry = record.Events[index]
            table.insert(events, {
                Type = entry.Type,
                Time = entry.Time,
                Age = now - entry.Time,
                Confidence = entry.Confidence,
                Detail = entry.Detail
            })
        end

        local analysis = {
            OverallSkill = round(overall, 1),
            Confidence = round(confidence, 3),
            Rating = rating,
            Role = role,
            Categories = {
                Combat = round(scores.Combat, 1),
                Movement = round(scores.Movement, 1),
                GameSense = round(scores.GameSense, 1),
                Objectives = round(scores.Objectives, 1),
                Resources = round(scores.Resources, 1),
                Teamwork = round(scores.Teamwork, 1)
            },
            Strengths = strengths,
            Weaknesses = weaknesses,
            RecentEvents = events,
            -- Past the shape the contract asks for, for anything that wants to go deeper.
            Player = record.Player,
            CategoryConfidence = confs,
            RoleScores = roleScores,
            Observed = round(record.Observed, 1),
            AFK = record.Context.AFK,
            DataQuality = round(quality, 3)
        }

        local previous = record.Cache
        record.Cache = analysis
        if not previous or previous.Rating ~= analysis.Rating or previous.Role ~= analysis.Role then
            vapeEvents.EntityAnalysed:Fire(record.Player, analysis)
            local wasHigh = previous ~= nil and (previous.Rating == 'Skilled' or previous.Rating == 'Sweat')
            local isHigh = analysis.Rating == 'Skilled' or analysis.Rating == 'Sweat'
            if Notify.Enabled and isHigh and not wasHigh then
                notif('EntityAnalyser', record.Player.Name .. ' is ' .. analysis.Rating .. ' (' .. math.floor(analysis.OverallSkill) .. ', ' .. analysis.Role .. ')', 4)
            end
        end
        return analysis
    end

    local function analysisFor(plr)
        local record = peek(plr)
        if not record then return blankAnalysis() end
        if not record.Cache then return rebuild(record) end
        -- Sampling marks a profile dirty constantly, so the throttle is what actually decides how
        -- often the maths runs. Twice a second is far faster than a rating can meaningfully move.
        if record.Dirty and tick() >= record.NextScore then return rebuild(record) end
        return record.Cache
    end

    ----------------------------------------------------------------------------
    -- Labels.
    ----------------------------------------------------------------------------
    local function removeTag(plr)
        local tag = tags[plr]
        if tag then
            tag:Destroy()
        end
        tags[plr] = nil
    end

    local function ratingShown(rating)
        if rating == 'Sweat' then return ShowSweat.Enabled end
        if rating == 'Skilled' then return ShowSkilled.Enabled end
        if rating == 'Above Average' then return ShowAbove.Enabled end
        if rating == 'Average' then return ShowAverage.Enabled end
        if rating == 'Beginner' then return ShowBeginner.Enabled end
        if rating == 'New' then return ShowNew.Enabled end
        return ShowUnknown.Enabled
    end

    local function updateTag(plr, ent, analysis)
        local adornee = ent.Head or ent.RootPart
        if not folder or not adornee or not adornee.Parent or not ratingShown(analysis.Rating) then
            removeTag(plr)
            return
        end

        local tag = tags[plr]
        if not tag or tag.Adornee ~= adornee or not tag.Parent then
            removeTag(plr)
            tag = Instance.new('BillboardGui')
            tag.Name = 'EntityAnalyser'
            tag.AlwaysOnTop = true
            tag.ClipsDescendants = false
            tag.Size = UDim2.fromOffset(260, 18)
            -- Above the +3 the other overhead tags use, so a nametag and a rating can be on
            -- together without covering each other.
            tag.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
            tag.Adornee = adornee
            tag.Parent = folder

            local label = Instance.new('TextLabel')
            label.Name = 'Label'
            label.Size = UDim2.fromScale(1, 1)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.TextSize = 13
            label.TextStrokeTransparency = 0.4
            label.Parent = tag
            tags[plr] = tag
        end

        local label = tag:FindFirstChild('Label')
        if label then
            label.TextColor3 = ratingColor[analysis.Rating] or ratingColor.Unknown
            local text = '\u{25CF} ' .. analysis.Rating
            if ShowScore.Enabled and analysis.Rating ~= 'Unknown' then
                text = text .. ' ' .. math.floor(analysis.OverallSkill)
            end
            if ShowRole.Enabled and analysis.Role ~= 'Mixed' then
                text = text .. ' \u{00B7} ' .. analysis.Role
            end
            if ShowConfidence.Enabled then
                text = text .. ' \u{00B7} ' .. math.floor(analysis.Confidence * 100) .. '%'
            end
            if analysis.AFK then
                text = text .. ' \u{00B7} AFK'
            end
            label.Text = text
        end
    end

    local function clearTags()
        for plr in tags do
            removeTag(plr)
        end
        table.clear(tags)
    end

    ----------------------------------------------------------------------------
    -- The pass.
    ----------------------------------------------------------------------------
    local function step()
        -- Each player carries their own sample clock, so the pass itself needs no frame delta -
        -- a player read twice a second must be credited with half a second, not with one frame.
        local now = tick()
        probeBudget = PROBE_BUDGET

        if store.matchState ~= lastMatchState then
            if store.matchState == 1 then
                matchStart = now
                bedsAtStart = #collectionService:GetTagged('bed')
            end
            lastMatchState = store.matchState
        end
        refreshWorld(now)

        for key, fight in engagements do
            if now - fight.Last > ENGAGE_MEMORY then
                engagements[key] = nil
            end
        end

        local origin = entitylib.isAlive and entitylib.character.RootPart and entitylib.character.RootPart.Position or nil
        local nearRange = SampleRange.Value
        local labelsOn = Labels.Enabled

        table.clear(seen)
        for _, ent in entitylib.List do
            local plr = ent.Player
            if plr and plr ~= lplr then
                seen[plr] = true
                local record = profileFor(plr)
                local root = ent.RootPart
                local distance = (origin and root and root.Parent) and (root.Position - origin).Magnitude or math.huge
                local fighting = now - record.Combat.LastHit <= FIGHT_MEMORY or now - record.Combat.LastHurt <= FIGHT_MEMORY
                local near = distance <= nearRange or fighting

                -- Adaptive: ten times a second for anyone near or fighting, twice a second for everyone
                -- else, and once every couple of seconds for somebody who is not doing anything -
                -- which is still often enough to notice the moment they start again.
                local interval = near and NEAR_INTERVAL or (record.Context.AFK and AFK_INTERVAL or FAR_INTERVAL)
                if now - record.LastSample >= interval then
                    local sampleDt = math.min(now - record.LastSample, 1)
                    record.LastSample = now
                    sampleEntity(ent, record, sampleDt, near)
                    updateContext(record, ent)
                    sampleInventory(record)
                    if near then
                        updateThreats(record, ent)
                        if now - record.LastProbe >= PROBE_INTERVAL then
                            record.LastProbe = now
                            probeEntity(ent, record)
                        end
                    end
                end

                -- Scored whether or not anything is being drawn: the labels are one consumer of
                -- this, the API and the notifications are others, and the rescore is throttled to
                -- twice a second regardless of how many of them are listening.
                local analysis = analysisFor(plr)
                if labelsOn and (Teammates.Enabled or not sameTeam(plr, lplr)) then
                    updateTag(plr, ent, analysis)
                else
                    removeTag(plr)
                end
            end
        end

        -- Anyone who has left the entity list - died, left, streamed out - loses their label but
        -- keeps their profile, so a rating survives a respawn instead of starting over.
        for plr in tags do
            if not seen[plr] then
                removeTag(plr)
            end
        end
    end

    ----------------------------------------------------------------------------
    -- Public API.
    ----------------------------------------------------------------------------
    local api
    api = {
        Enabled = false,
        -- Always the full shape, even for a player we have never seen: an unknown player is a
        -- zeroed table rated 'Unknown', never nil. The table is rebuilt on each rescore, so treat
        -- what comes back as read-only and re-ask rather than holding onto it.
        Analyse = function(plr)
            if not running or typeof(plr) ~= 'Instance' or not plr:IsA('Player') then
                return blankAnalysis()
            end
            local ok, result = pcall(analysisFor, plr)
            return ok and result or blankAnalysis()
        end,
        GetAll = function()
            local all = {}
            if not running then return all end
            for plr in profiles do
                if plr.Parent then
                    all[plr] = api.Analyse(plr)
                end
            end
            return all
        end,
        Reset = function(plr)
            if plr then
                profiles[plr] = nil
                return
            end
            table.clear(profiles)
            table.clear(engagements)
            table.clear(pendingVoid)
        end,
        Ratings = {'New', 'Beginner', 'Average', 'Above Average', 'Skilled', 'Sweat'},
        Roles = ROLES
    }
    getgenv().EntityAnalyser = api

    EntityAnalyser = vape.Categories.Utility:CreateModule({
        Name = 'EntityAnalyser',
        Function = function(callback)
            running = callback
            api.Enabled = callback
            -- Anything whose UI depends on the analyser being up listens for this rather than
            -- reaching into this module - see Killaura's 'Target skilled'.
            vapeEvents.EntityAnalyserState:Fire(callback)

            if callback then
                matchStart, lastMatchState = tick(), -1
                bedsAtStart = #collectionService:GetTagged('bed')
                folder = Instance.new('Folder')
                folder.Name = 'EntityAnalyser'
                folder.Parent = vape.gui
                EntityAnalyser:Clean(folder)

                EntityAnalyser:Clean(vapeEvents.EntityDamageEvent.Event:Connect(onDamage))
                EntityAnalyser:Clean(vapeEvents.EntityDeathEvent.Event:Connect(onDeath))
                EntityAnalyser:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(onBedBreak))
                EntityAnalyser:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(onPlaceBlock))
                EntityAnalyser:Clean(vapeEvents.BreakBlockEvent.Event:Connect(onBreakBlock))
                EntityAnalyser:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
                    table.clear(engagements)
                    table.clear(pendingVoid)
                end))
                EntityAnalyser:Clean(entitylib.Events.AnimationPlayed:Connect(function(plr, track)
                    if not running or not plr or plr == lplr then return end
                    local animation = track and track.Animation
                    if animation then
                        noteSwing(plr, animation.AnimationId)
                    end
                end))
                EntityAnalyser:Clean(workspace.ChildAdded:Connect(function(object)
                    -- The shooter attribute is written a frame after the projectile is parented.
                    task.delay(0, function()
                        if object and object.Parent then
                            pcall(onProjectile, object)
                        end
                    end)
                end))
                -- A player leaving takes their profile with them, so a rejoin is judged fresh
                -- rather than inheriting somebody else's match.
                EntityAnalyser:Clean(playersService.PlayerRemoving:Connect(function(plr)
                    profiles[plr] = nil
                    pendingVoid[plr] = nil
                    removeTag(plr)
                end))
                -- Everything above is event driven. This is the only loop, and all it does is the
                -- adaptive sampling and the label refresh - the two things that need a clock.
                local nextStep = 0
                EntityAnalyser:Clean(runService.Heartbeat:Connect(function()
                    if not running then return end
                    local now = tick()
                    if now < nextStep then return end
                    nextStep = now + NEAR_INTERVAL
                    pcall(step)
                end))
            else
                clearTags()
                table.clear(profiles)
                table.clear(engagements)
                table.clear(pendingVoid)
                folder = nil
            end
        end,
        Tooltip = 'Rates how well each player is playing and marks them overhead. Read-only, it never changes other modules'
    })

    SweatAt = EntityAnalyser:CreateSlider({
        Name = 'Sweat at',
        Min = 60,
        Max = 99,
        Default = 84,
        Tooltip = 'Score needed for the top rating. Getting here takes a spread of categories, sustained - no single thing carries anyone to it'
    })
    SkilledAt = EntityAnalyser:CreateSlider({
        Name = 'Skilled at',
        Min = 50,
        Max = 95,
        Default = 70,
        Tooltip = 'Score needed to count as skilled'
    })
    AboveAt = EntityAnalyser:CreateSlider({
        Name = 'Above average at',
        Min = 45,
        Max = 85,
        Default = 58,
        Tooltip = 'Score needed to be marked above average'
    })
    BeginnerBelow = EntityAnalyser:CreateSlider({
        Name = 'Beginner below',
        Min = 15,
        Max = 50,
        Default = 38,
        Tooltip = 'Score a player has to drop under to be marked a beginner'
    })
    NewBelow = EntityAnalyser:CreateSlider({
        Name = 'New below',
        Min = 2,
        Max = 40,
        Default = 22,
        Tooltip = 'Score a player has to drop under to be marked new. Bands are read top down'
    })
    MinConfidence = EntityAnalyser:CreateSlider({
        Name = 'Minimum confidence',
        Min = 0,
        Max = 90,
        Default = 15,
        Suffix = '%',
        Tooltip = 'How much of the rating must be evidenced before it commits. Below this everyone reads Unknown'
    })
    SampleRange = EntityAnalyser:CreateSlider({
        Name = 'Sample range',
        Min = 40,
        Max = 250,
        Default = 90,
        Suffix = ' studs',
        Tooltip = 'Inside this range players are read every frame, outside it twice a second'
    })
    Labels = EntityAnalyser:CreateToggle({
        Name = 'Labels',
        Default = true,
        Function = function(callback)
            for _, option in {ShowScore, ShowRole, ShowConfidence, ShowSweat, ShowSkilled, ShowAbove, ShowAverage, ShowBeginner, ShowNew, ShowUnknown} do
                if option and option.Object then
                    option.Object.Visible = callback
                end
            end
            if not callback then
                clearTags()
            end
        end,
        Tooltip = 'Show the rating above each player. Its own billboards, so it never clashes with ESP'
    })
    ShowScore = EntityAnalyser:CreateToggle({
        Name = 'Show score',
        Default = true,
        Darker = true,
        Tooltip = 'Put the 0-100 number next to the rating'
    })
    ShowRole = EntityAnalyser:CreateToggle({
        Name = 'Show role',
        Default = true,
        Darker = true,
        Tooltip = 'Also show the role they are playing - Rusher, Defender, Fighter, Support or Economy'
    })
    ShowConfidence = EntityAnalyser:CreateToggle({
        Name = 'Show confidence',
        Darker = true,
        Tooltip = 'Show how much of the rating is evidenced rather than assumed'
    })
    ShowSweat = EntityAnalyser:CreateToggle({Name = 'Label sweat', Default = true, Darker = true})
    ShowSkilled = EntityAnalyser:CreateToggle({Name = 'Label skilled', Default = true, Darker = true})
    ShowAbove = EntityAnalyser:CreateToggle({Name = 'Label above average', Default = true, Darker = true})
    ShowAverage = EntityAnalyser:CreateToggle({Name = 'Label average', Default = true, Darker = true})
    ShowBeginner = EntityAnalyser:CreateToggle({Name = 'Label beginner', Default = true, Darker = true})
    ShowNew = EntityAnalyser:CreateToggle({Name = 'Label new', Default = true, Darker = true})
    ShowUnknown = EntityAnalyser:CreateToggle({
        Name = 'Label unrated',
        Darker = true,
        Tooltip = 'Also label players it has not seen enough of to commit to a rating for'
    })
    Teammates = EntityAnalyser:CreateToggle({
        Name = 'Label teammates',
        Tooltip = 'Also rate your own team'
    })
    Notify = EntityAnalyser:CreateToggle({
        Name = 'Notifications',
        Tooltip = 'Say something the first time a player crosses into skilled or sweat'
    })

    vape:Clean(function()
        running = false
        api.Enabled = false
        table.clear(profiles)
        table.clear(engagements)
        table.clear(pendingVoid)
    end)
end)