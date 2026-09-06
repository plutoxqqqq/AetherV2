run(function()
    local BlockSelectorColor
    local OutlineColor
    local FillColor
    local originals = {}
    local applying = {}

    local function apply(selector)
        if not (selector:IsA('SelectionBox') or selector:IsA('Highlight')) then return end
        if not originals[selector] then
            if selector:IsA('SelectionBox') then
                originals[selector] = {selector.Color3, selector.Transparency, selector.SurfaceColor3, selector.SurfaceTransparency}
            else
                originals[selector] = {selector.OutlineColor, selector.OutlineTransparency, selector.FillColor, selector.FillTransparency}
            end
            BlockSelectorColor:Clean(selector.AncestryChanged:Connect(function(_, parent)
                if not parent then originals[selector], applying[selector] = nil, nil end
            end))
        end
        applying[selector] = true
        if selector:IsA('SelectionBox') then
            selector.Color3 = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
            selector.Transparency = 1 - OutlineColor.Opacity
            selector.SurfaceColor3 = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
            selector.SurfaceTransparency = 1 - FillColor.Opacity
        else
            selector.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
            selector.OutlineTransparency = 1 - OutlineColor.Opacity
            selector.FillColor = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
            selector.FillTransparency = 1 - FillColor.Opacity
        end
        applying[selector] = nil
    end

    local function refresh()
        if not BlockSelectorColor.Enabled then return end
        for selector in originals do apply(selector) end
    end

    BlockSelectorColor = vape.Categories.Legit:CreateModule({
        Name = 'BlockSelectorColor',
        Tooltip = 'Changes block selector outline and fill colours and transparency',
        Function = function(enabled)
            if enabled then
                BlockSelectorColor:Clean(workspace.DescendantAdded:Connect(apply))
                for _, selector in workspace:GetDescendants() do apply(selector) end
            else
                for selector, values in originals do
                    if selector.Parent then
                        applying[selector] = true
                        if selector:IsA('SelectionBox') then
                            selector.Color3, selector.Transparency = values[1], values[2]
                            selector.SurfaceColor3, selector.SurfaceTransparency = values[3], values[4]
                        else
                            selector.OutlineColor, selector.OutlineTransparency = values[1], values[2]
                            selector.FillColor, selector.FillTransparency = values[3], values[4]
                        end
                        applying[selector] = nil
                    end
                    originals[selector] = nil
                end
                table.clear(applying)
            end
        end
    })
    OutlineColor = BlockSelectorColor:CreateColorSlider({Name = 'Outline colour', DefaultOpacity = 1, Function = refresh})
    FillColor = BlockSelectorColor:CreateColorSlider({Name = 'Fill colour', DefaultOpacity = 0.5, Function = refresh})
end)
