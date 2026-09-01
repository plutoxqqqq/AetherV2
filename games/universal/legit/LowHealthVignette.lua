run(function()
    local LowHealthVignette, Threshold, WarningColor, Intensity, Pulse, Heartbeat
    local gui, heartbeatSound
    local edges = {}

    local function cleanup()
        if heartbeatSound then
            heartbeatSound:Stop()
            heartbeatSound:Destroy()
            heartbeatSound = nil
        end
        if gui then
            gui:Destroy()
            gui = nil
        end
        table.clear(edges)
    end

    local function effectiveHealth(character, humanoid)
        local shield = 0
        for _, attribute in {'Shield', 'HealthShield', 'Absorption', 'ExtraHealth'} do
            shield = math.max(shield, tonumber(character:GetAttribute(attribute)) or 0)
        end
        return humanoid.Health + shield, humanoid.MaxHealth + shield
    end

    local function createEdge(name, size, position, rotation)
        local edge = Instance.new('Frame')
        edge.Name = name
        edge.Size = size
        edge.Position = position
        edge.BorderSizePixel = 0
        edge.BackgroundTransparency = 1
		edge.ZIndex = 50
        edge.Parent = gui

        local gradient = Instance.new('UIGradient')
        gradient.Rotation = rotation
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
        gradient.Parent = edge
        table.insert(edges, edge)
    end

    local function localHumanoid()
        local character = lplr.Character
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        if not character or not humanoid or humanoid.Health <= 0 then return end
        -- A camera following another humanoid means the player is spectating.
        local subject = gameCamera and gameCamera.CameraSubject
        if subject and subject:IsA('Humanoid') and subject ~= humanoid then return end
        return character, humanoid
    end

    LowHealthVignette = vape.Categories.Legit:CreateModule({
        Name = 'LowHealthVignette',
        Function = function(enabled)
            cleanup()
            if not enabled then return end

            gui = Instance.new('Frame')
            gui.Name = 'AetherLowHealthVignette'
			gui.Size = UDim2.fromScale(1, 1)
			gui.BackgroundTransparency = 1
			gui.ZIndex = 50
            gui.Parent = vape.gui

            createEdge('Top', UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0), 90)
            createEdge('Bottom', UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0.82), 270)
            createEdge('Left', UDim2.new(0.14, 0, 0.64, 0), UDim2.fromScale(0, 0.18), 0)
            createEdge('Right', UDim2.new(0.14, 0, 0.64, 0), UDim2.fromScale(0.86, 0.18), 180)

            heartbeatSound = Instance.new('Sound')
            heartbeatSound.Name = 'Heartbeat'
            heartbeatSound.SoundId = 'rbxassetid://9114221327'
            heartbeatSound.Looped = true
            heartbeatSound.Volume = 0
            heartbeatSound.Parent = gui

            local accumulator, strength, warningColor = 0, 0, Color3.fromHSV(WarningColor.Hue, WarningColor.Sat, WarningColor.Value)
            LowHealthVignette:Clean(runService.RenderStepped:Connect(function(delta)
                accumulator += delta
                -- Health, attributes and camera subject do not need a 144/240Hz query. Keep the
                -- inexpensive pulse smooth, but sample gameplay state at no more than 30Hz.
                if accumulator >= 1 / 30 then
                    accumulator = 0
                    warningColor = Color3.fromHSV(WarningColor.Hue, WarningColor.Sat, WarningColor.Value)
                    for _, edge in edges do edge.BackgroundColor3 = warningColor end
                    local character, humanoid = localHumanoid()
                    strength = 0
                    if character and humanoid then
                        local health, maximum = effectiveHealth(character, humanoid)
                        local threshold = Threshold.Value / 100
                        local ratio = maximum > 0 and health / maximum or 1
                        if ratio <= threshold then
                            strength = math.clamp((threshold - ratio) / math.max(threshold, 0.01), 0, 1)
                            strength *= Intensity.Value / 100
                        end
                    end
                end
                local visibleStrength = Pulse.Enabled and strength * (0.75 + math.sin(os.clock() * 6) * 0.25) or strength
                for _, edge in edges do
                    edge.BackgroundTransparency = 1 - visibleStrength
                end

                heartbeatSound.Volume = visibleStrength > 0 and Heartbeat.Enabled and visibleStrength / 3 or 0
                if heartbeatSound.Volume > 0 and not heartbeatSound.IsPlaying then
                    heartbeatSound:Play()
                elseif heartbeatSound.Volume == 0 and heartbeatSound.IsPlaying then
                    heartbeatSound:Stop()
                end
            end))
        end,
        Tooltip = 'Shows a shield-aware screen-edge warning while your effective health is low'
    })
    Threshold = LowHealthVignette:CreateSlider({Name = 'Health percentage', Min = 1, Max = 100, Default = 30, Suffix = '%'})
    WarningColor = LowHealthVignette:CreateColorSlider({Name = 'Color', DefaultValue = 0, DefaultOpacity = 1})
    Intensity = LowHealthVignette:CreateSlider({Name = 'Intensity', Min = 1, Max = 100, Default = 70, Suffix = '%'})
    Pulse = LowHealthVignette:CreateToggle({Name = 'Pulse', Default = true})
    Heartbeat = LowHealthVignette:CreateToggle({Name = 'Heartbeat'})
end)