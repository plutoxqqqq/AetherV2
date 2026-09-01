-- AETHER_MODULE_NAME: CatExtender
--[[
    Kit extenders

    Four modules, one per kit mobility ability: JadeExtender, VoidRegentExtender, CatExtender
    and YuziExtender. Each hooks the single controller method that performs its ability and
    pushes the character on with an extra impulse the moment that method fires.

    Hooking the controller (rather than watching velocity or ability cooldowns) is what makes
    this exact: the impulse lands on the frame the game itself performs the move, so it can
    never fire on knockback, an explosion or a hotbar change, and an ability the server
    refuses never produces one either.

    They share `createKitExtender` below because only four things actually differ between
    them - the controller, the method, the kit and the impulse - but each is registered as its
    own module with its own Multiplier, so one of them failing to register cannot take the
    other three out with it.
]]

-- `spec` is everything that differs between the four:
--   Name       - module name.
--   Kit        - store.equippedKit value the ability belongs to.
--   Controller - field on `bedwars` holding the controller to hook.
--   Method     - method on that controller which performs the move.
--   Argument   - index into the call's arguments holding the move direction, when it takes one.
--   Impulse    - (root, direction, multiplier) -> impulse to apply, or nil to apply none.
--   Tooltip    - module tooltip.
local function createKitExtender(spec)
    local Extender
    local Multiplier
    local controller, original, hooked

    -- Kit controllers are built when the match starts, so a module switched on in the lobby
    -- has nothing to hook yet: wait for it rather than give up, and stop the moment the module
    -- is switched off again.
    local function install()
        local target = bedwars[spec.Controller]
        while not target and Extender.Enabled do
            task.wait(0.1)
            target = bedwars[spec.Controller]
        end
        if not Extender.Enabled or not target then return end

        local method = target[spec.Method]
        if typeof(method) ~= 'function' then return end
        -- A second install racing the first (a fast off/on) would otherwise capture our own
        -- hook as `original`, and disabling would then restore the hook rather than the
        -- game's method.
        if hooked and method == hooked then return end

        controller, original = target, method
        hooked = function(...)
            -- Read out of the varargs here: the guarded block below is a closure, which
            -- cannot see `...` of the function it sits in.
			local direction = spec.Argument and select(spec.Argument, ...) or nil
			if spec.Argument and typeof(direction) ~= 'Vector3' then
				for index = 1, select('#', ...) do
					local candidate = select(index, ...)
					if typeof(candidate) == 'Vector3' then direction = candidate end
				end
			end
            local results = table.pack(method(...))

            if Extender.Enabled and entitylib.isAlive
				and (not spec.Argument or typeof(direction) == 'Vector3') then
				-- Controllers spend their cooldown before returning and several of them
				-- write velocity again at the end of the same frame. A deferred impulse
				-- therefore both proves the ability ran and cannot be overwritten by it.
				task.defer(function()
					pcall(function()
						if not Extender.Enabled or not entitylib.isAlive then return end
						local root = entitylib.character.RootPart
						local impulse = spec.Impulse(root, direction, Multiplier.Value)
						if impulse then root:ApplyImpulse(impulse) end
					end)
				end)
            end

            return table.unpack(results, 1, results.n)
        end

        controller[spec.Method] = hooked
    end

    Extender = kits:CreateModule({
        Name = spec.Name,
        Category = 'Ability',
        Function = function(callback)
            if callback then
                Extender:Clean(task.spawn(install))
            else
                -- Only put the method back if it is still ours; something else may have
                -- re-hooked it since, and restoring over that would undo their hook.
                if controller and original and controller[spec.Method] == hooked then
                    controller[spec.Method] = original
                end
                controller, original, hooked = nil, nil, nil
            end
        end,
        Tooltip = spec.Tooltip
    })

    Multiplier = Extender:CreateSlider({
        Name = 'Multiplier',
        Min = 1,
        Max = 5,
        Default = 2,
        Decimal = 10,
        Suffix = 'x',
        Tooltip = 'How much further than normal the ability carries you. 1x is the game\'s own distance'
    })

    return Extender
end

run(function()
    createKitExtender({
        Name = 'CatExtender',
        Kit = 'cat',
        Controller = 'CatController',
        Method = 'leap',
        -- leap(self, character, direction): the direction is the third argument.
        Argument = 3,
        Impulse = function(root, direction, multiplier)
            local flat = direction * Vector3.new(1, 0, 1)
            if flat.Magnitude <= 0 then return nil end
            return flat.Unit * root.AssemblyMass * (multiplier - 1) * 70
        end,
        Tooltip = 'Extends how far the Cat/Yamini pounce launches you'
    })
end)
