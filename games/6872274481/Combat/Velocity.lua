run(function()
    local Velocity
    local Horizontal
    local Vertical
    local Chance
    local TargetCheck
    local Direction
    local rand, old = Random.new()

    local function rotateY(vector, degrees)
        local radians = math.rad(degrees)
        return Vector3.new(
            vector.X * math.cos(radians) - vector.Z * math.sin(radians),
            0,
            vector.X * math.sin(radians) + vector.Z * math.cos(radians)
        )
    end

    local function getDirectionalSource(root, sourcePosition)
        local direction = Direction.Value
        if direction == 'Default' then
            return sourcePosition
        elseif direction == 'Up' then
            root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * 120, 0))
            return nil, true
        elseif direction == 'Void' then
            root:ApplyImpulse(Vector3.new(0, -root.AssemblyMass * 60, 0))
            return nil, true
        end

        local rootPosition = root.Position
        if direction == 'Left' then
            return rootPosition + root.CFrame.RightVector * 10
        elseif direction == 'Right' then
            return rootPosition - root.CFrame.RightVector * 10
        elseif direction == 'Reverse' and sourcePosition then
            return Vector3.new(2 * rootPosition.X - sourcePosition.X, sourcePosition.Y, 2 * rootPosition.Z - sourcePosition.Z)
        end

        local flatSource = sourcePosition and Vector3.new(sourcePosition.X, 0, sourcePosition.Z)
        local velocity = flatSource and ((rootPosition * Vector3.new(1, 0, 1)) - flatSource)
        if not velocity or velocity.Magnitude < 0.001 then
            return sourcePosition
        end

        velocity = velocity.Unit
        direction = direction == 'Random' and ({'Left', 'Right', 'Pull'})[rand:NextInteger(1, 3)] or direction
        local redirected = direction == 'Pull' and -velocity or table.find({'Left', 'Right'}, direction) and rotateY(velocity, direction == 'Left' and 90 or -90) or velocity
        return Vector3.new(rootPosition.X - redirected.X * 100, sourcePosition.Y, rootPosition.Z - redirected.Z * 100)
    end

    Velocity = vape.Categories.Combat:CreateModule({
        Name = 'Velocity',
        Function = function(callback)
            if callback then
                old = bedwars.KnockbackUtil.applyKnockback
                bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
                    if rand:NextNumber(0, 100) > Chance.Value then
                        return old(root, mass, dir, knockback, ...)
                    end
                    local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
                        Range = 50,
                        Part = 'RootPart',
                        Players = true
                    })

                    if check then
                        knockback = knockback or {}
                        if Horizontal.Value == 0 and Vertical.Value == 0 and Direction.Value == 'Default' then return end
                        if Horizontal.Value ~= 0 or Vertical.Value ~= 0 then
                            knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
                            knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
                        end
                        local redirectedSource, skipOriginal = getDirectionalSource(root, dir)
                        if skipOriginal then return end
                        dir = redirectedSource or dir
                    end

                    return old(root, mass, dir, knockback, ...)
                end
            else
                bedwars.KnockbackUtil.applyKnockback = old
            end
        end,
        Tooltip = 'Reduces knockback taken'
    })
    Horizontal = Velocity:CreateSlider({
        Name = 'Horizontal',
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = '%'
    })
    Vertical = Velocity:CreateSlider({
        Name = 'Vertical',
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = '%'
    })
    Chance = Velocity:CreateSlider({
        Name = 'Chance',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = '%'
    })
    TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
    Direction = Velocity:CreateDropdown({
        Name = 'Direction',
        List = {'Default', 'Backwards', 'Up', 'Void', 'Left', 'Right', 'Reverse', 'Pull', 'Random'},
        Default = 'Default',
        Tooltip = 'Redirects knockback direction inside the unified Velocity module'
    })
end)
