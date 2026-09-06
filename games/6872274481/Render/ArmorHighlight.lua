run(function()
    local ArmorHighlight
    local Boots, Helmet, Chestplate, UseParts

    local Instances, Decoys = {}, {}
    local Properties = {
        OutlineTransparency = 'Slider',
        FillTransparency = 'Slider',
        FillColor = 'ColorSlider',
        OutlineColor = 'ColorSlider'
    }

    local function getArmor(v)
        if v:GetAttribute('ArmorSlot') == 0 and Helmet.Enabled then
            return 'Helmet'
        elseif v:GetAttribute('ArmorSlot') == 1 and Chestplate.Enabled then
            return 'Chestplate'
        elseif v:GetAttribute('ArmorSlot') == 2 and Boots.Enabled then
            return 'Boots'
        end
        return nil
    end

    ArmorHighlight = vape.Categories.Render:CreateModule({
        Name = 'ArmorHighlight',
        Function = function(call)
            if call then
                ArmorHighlight:Clean(lplr.CharacterAdded:Connect(function(char)
                    ArmorHighlight:Clean(char.ChildAdded:Connect(function(part)
                        task.wait(1)
                        local armor = getArmor(part)
                        if armor then
                            if false then
                                local v = Instance.new('Part')
                                v.CanCollide = false
                                for name, prop in getproperties(part:WaitForChild('Handle')) do
                                    pcall(function()
                                        v[name] = prop
                                    end)
                                end
                                v.Anchored = true
                                part.Handle.Transparency = 1
                                v.Material = Enum.Material.Neon
                                for _, child in part.Handle:GetChildren() do
                                    child.Parent = v
                                end
                                v.Parent = part
                                table.insert(Decoys, {
                                    TP = part.Handle,
                                    Main = v
                                })
                            else
                                local highlight = Instance.new('Highlight', part:WaitForChild('Handle'))
                                for i,v in Properties do
                                    highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value
                                end

                                table.insert(Instances, highlight)
                            end
                        end
                    end))
                    for _, part in char:GetChildren() do
                        local armor = getArmor(part)
                        if armor then
                            if UseParts.Enabled then
                                local v = Instance.new('Part')
                                v.CanCollide = false
                                for name, prop in getproperties(part:WaitForChild('Handle')) do
                                    pcall(function()
                                        v[name] = prop
                                    end)
                                end
                                part.Handle.Transparency = 1
                                v.Anchored = true
                                v.Material = Enum.Material.Neon
                                for _, child in part.Handle:GetChildren() do
                                    child.Parent = v
                                end
                                table.insert(Decoys, {
                                    TP = part.Handle,
                                    Main = v
                                })
                            else
                                local highlight = Instance.new('Highlight', part:WaitForChild('Handle'))
                                for i,v in Properties do
                                    highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value
                                end

                                table.insert(Instances, highlight)
                            end
                        end
                    end
                end))

                ArmorHighlight:Clean(runService.PreRender:Connect(function()
                    for _, data in Decoys do
                        if data.Main and data.Main.Parent and data.TP and data.TP.Parent then
                            data.Main.Velocity = Vector3.new(0, 1, 0)
                            data.Main.CFrame = data.TP.CFrame
                        end
                    end
                end))

                if entitylib.isAlive then
                    ArmorHighlight:Clean(lplr.Character.ChildAdded:Connect(function(part)
                        task.wait(1)
                        local armor = getArmor(part)
                        if armor then
                            if UseParts.Enabled then
                                local v = Instance.new('Part')
                                v.CanCollide = false
                                for name, prop in getproperties(part:WaitForChild('Handle')) do
                                    pcall(function()
                                        v[name] = prop
                                    end)
                                end
                                v.Anchored = true
                                part.Handle.Transparency = 1
                                v.Material = Enum.Material.Neon
                                for _, child in part.Handle:GetChildren() do
                                    child.Parent = v
                                end
                                v.Parent = part
                                table.insert(Decoys, {
                                    TP = part.Handle,
                                    Main = v
                                })
                            else
                                local highlight = Instance.new('Highlight', part:WaitForChild('Handle'))
                                for i,v in Properties do
                                    highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value
                                end

                                table.insert(Instances, highlight)
                            end
                        end
                    end))

                    for _, part in lplr.Character:GetChildren() do
                        local armor = getArmor(part)
                        if armor then
                            if UseParts.Enabled then
                                local v = Instance.new('Part')
                                v.CanCollide = false
                                for name, prop in getproperties(part:WaitForChild('Handle')) do
                                    pcall(function()
                                        v[name] = prop
                                    end)
                                end
                                part.Handle.Transparency = 1
                                v.Anchored = true
                                v.Material = Enum.Material.Neon
                                for _, child in part.Handle:GetChildren() do
                                    child.Parent = v
                                end
                                table.insert(Decoys, {
                                    TP = part.Handle,
                                    Main = v
                                })
                            else
                                local highlight = Instance.new('Highlight', part:WaitForChild('Handle'))
                                for i,v in Properties do
                                    highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value
                                end

                                table.insert(Instances, highlight)
                            end
                        end
                    end
                end
            else
                for i,v in Instances do
                    v:Destroy()
                end
                table.clear(Decoys)
                table.clear(Instances)
            end
        end
    })

    for i,v in Properties do
        local name = i

        Properties[name] = ArmorHighlight['Create'.. v](ArmorHighlight, {
            Name = i,
            Min = 0,
            Max = 1,
            Decimal = 35,
            Function = function(hue, sat, val)
                pcall(function()
                    for _, ins in Instances do
                        ins[name] = sat and Color3.fromHSV(hue, sat, val) or hue
                    end
                end)

                if sat then
                    for _, ins in Decoys do
                        ins.Main.Color = Color3.fromHSV(hue, sat, val)
                    end
                end
            end
        })
    end

    Helmet = ArmorHighlight:CreateToggle({
        Name = 'Helmet',
        Function = function()
            if ArmorHighlight.Enabled then
                ArmorHighlight:Toggle()
                ArmorHighlight:Toggle()
            end
        end
    })

    Chestplate = ArmorHighlight:CreateToggle({
        Name = 'Chestplate',
        Function = function()
            if ArmorHighlight.Enabled then
                ArmorHighlight:Toggle()
                ArmorHighlight:Toggle()
            end
        end
    })

    Boots = ArmorHighlight:CreateToggle({
        Name = 'Boots',
        Default = true,
        Function = function()
            if ArmorHighlight.Enabled then
                ArmorHighlight:Toggle()
                ArmorHighlight:Toggle()
            end
        end
    })

    UseParts = ArmorHighlight:CreateToggle({
        Name = 'Use Parts',
        Default = true,
        Function = function()
            if ArmorHighlight.Enabled then
                ArmorHighlight:Toggle()
                ArmorHighlight:Toggle()
            end
        end
    })
end)
