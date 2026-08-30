run(function()
    local ReaperFix
    local ReaperSpeed

    local function getCharacterParts()
        local character = lplr.Character
        if not character then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")

        return character, humanoid, root
    end

    local function inSoulForm(character)
        if not character then
            return false
        end

        return character:GetAttribute("GrimReaperChannel") == true
    end

    ReaperFix = kits:CreateModule({
        Name = "ReaperBypass",
        Category = 'Ability',
        Function = function(callback)
            if not callback then
                return
            end

            local success, result = pcall(function()
                local event = replicatedStorage
                    .rbxts_include
                    .node_modules["@rbxts"]
                    .net
                    .out
                    ._NetManaged
                    .ConsumeGrimReaperSoul

                return event:InvokeServer({
                    secret = "a058cfb5-a4c9-4cc6-84e5-863108f23a89"
                })
            end)

            if not success then
                notif(
                    "ReaperBypass",
                    "Could not invoke ConsumeGrimReaperSoul: " .. tostring(result),
                    5,
                    "warning"
                )
            end

            ReaperFix:Clean(runService.PostSimulation:Connect(function()
                local character, humanoid, root = getCharacterParts()

                if not character or not humanoid or not root then
                    return
                end

                if humanoid.Health <= 0 or not inSoulForm(character) then
                    return
                end

                if not isnetworkowner(root) then
                    return
                end

                local direction = humanoid.MoveDirection
                direction = Vector3.new(direction.X, 0, direction.Z)

                if direction.Magnitude <= 0.05 then
                    return
                end

                local targetSpeed = tonumber(ReaperSpeed.Value) or 37
                local horizontalVelocity = direction.Unit * targetSpeed
                local currentVelocity = root.AssemblyLinearVelocity

                root.AssemblyLinearVelocity = Vector3.new(
                    horizontalVelocity.X,
                    currentVelocity.Y,
                    horizontalVelocity.Z
                )
            end))
        end,
        Tooltip = "Bypasses anticheat while consuming souls"
    })

    ReaperSpeed = ReaperFix:CreateSlider({
        Name = "Speed",
        Min = 1,
        Max = 80,
        Default = 37,
        Suffix = " studs/s"
    })
end)