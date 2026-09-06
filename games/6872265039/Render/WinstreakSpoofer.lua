run(function()
    local WinstreakSpoofer
    local Wins

    local oldSets = {
        Wins = nil,
        DoesExist = nil,
    }

    WinstreakSpoofer = vape.Categories.Render:CreateModule({
        Name = 'WinstreakSpoofer',
        Tooltip = 'Modifies/Adds your winstreak (client‑sided)',
        Function = function(callback)
            if callback then
                if not entitylib.isAlive then return end
                if lplr.Character.Head.Nametag then
                    local winStreakCounter = lplr.Character.Head.Nametag:FindFirstChild("WinStreakCounter")
                    if not winStreakCounter then
                        local main = Instance.new('Frame')
                        main.AnchorPoint = Vector2.new(1, 0.5)
                        main.Name = 'WinStreakCounter'
                        main.Size = UDim2.new(0.100000001, 0, 0.75, 0)
                        main.Position = UDim2.new(1.04999995, 0, 0.600000024, 0)
                        main.BackgroundTransparency = 1
                        main.Parent = lplr.Character.Head.Nametag
						main.LayoutOrder = 3
						main.BorderSizePixel =0
                        local icon = Instance.new('ImageLabel')
                        icon.BackgroundTransparency = 1
                        icon.Name = 'WinStreakFire'
                        icon.Size = UDim2.fromScale(1, 1)
                        icon.Image = 'rbxassetid://7101948108'
                        icon.ScaleType = Enum.ScaleType.Fit
						icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
                        icon.Parent = main
                        local value = Instance.new("TextLabel")
                        value.BackgroundTransparency = 1
                        value.Name = 'WinStreakValue'
                        value.Position = UDim2.fromScale(0.5, 0.375)
                        value.Size = UDim2.fromScale(0.8, 0.9)
                        value.FontFace = Font.new("Roboto", Enum.FontWeight.Bold)
                        value.TextSize = 8
                        oldSets.Wins = 0
                        value.Text = tostring(Wins.Value)
                        value.TextColor3 = Color3.fromRGB(255, 255, 255)
                        value.TextScaled = true
                        value.TextStrokeTransparency = 0.5
                        value.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        value.Parent = main
						value.AutoLocalize = false
						value.TextXAlignment = Enum.TextXAlignment.Center
						value.AnchorPoint = Vector2.new(0.5,0)
                        oldSets.DoesExist = false
                    else
                        oldSets.DoesExist = true
                        oldSets.Wins = winStreakCounter.WinStreakValue.Text
                        winStreakCounter.WinStreakValue.Text = tostring(Wins.Value)
                    end
                end
            else
                if lplr.Character.Head.Nametag then
                    local winStreakCounter = lplr.Character.Head.Nametag:FindFirstChild("WinStreakCounter")
                    if winStreakCounter then
                        if oldSets.DoesExist then
                            winStreakCounter.WinStreakValue.Text = oldSets.Wins
                        else
                            winStreakCounter:Destroy()
                        end
                    end
                end
                oldSets.Wins = nil
                oldSets.DoesExist = nil
            end
        end
    })

    Wins = WinstreakSpoofer:CreateSlider({
        Name = "Wins",
        Min = 0,
        Max = 1000,
        Default = 0,
        Decimal = 1,
        Function = function(val)
            if WinstreakSpoofer.Enabled then
                if lplr.Character.Head.Nametag then
                    local winStreakCounter = lplr.Character.Head.Nametag:FindFirstChild("WinStreakCounter")
	                if not winStreakCounter then
                        local main = Instance.new('Frame')
                        main.AnchorPoint = Vector2.new(1, 0.5)
                        main.Name = 'WinStreakCounter'
                        main.Size = UDim2.new(0.100000001, 0, 0.75, 0)
                        main.Position = UDim2.new(1.04999995, 0, 0.600000024, 0)
                        main.BackgroundTransparency = 1
                        main.Parent = lplr.Character.Head.Nametag
						main.LayoutOrder = 3
						main.BorderSizePixel =0
                        local icon = Instance.new('ImageLabel')
                        icon.BackgroundTransparency = 1
                        icon.Name = 'WinStreakFire'
                        icon.Size = UDim2.fromScale(1, 1)
                        icon.Image = 'rbxassetid://7101948108'
                        icon.ScaleType = Enum.ScaleType.Fit
						icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
                        icon.Parent = main
                        local value = Instance.new("TextLabel")
                        value.BackgroundTransparency = 1
                        value.Name = 'WinStreakValue'
                        value.Position = UDim2.fromScale(0.5, 0.375)
                        value.Size = UDim2.fromScale(0.8, 0.9)
                        value.FontFace = Font.new("Roboto", Enum.FontWeight.Bold)
                        value.TextSize = 8
                        oldSets.Wins = 0
                        value.Text = tostring(Wins.Value)
                        value.TextColor3 = Color3.fromRGB(255, 255, 255)
                        value.TextScaled = true
                        value.TextStrokeTransparency = 0.5
                        value.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        value.Parent = main
						value.AutoLocalize = false
						value.TextXAlignment = Enum.TextXAlignment.Center
						value.AnchorPoint = Vector2.new(0.5,0)
                        oldSets.DoesExist = false
                    else
                        winStreakCounter.WinStreakValue.Text = tostring(val)
                    end
                end
            end
        end
    })
end)
