run(function()
    local ViewmodelVisuals
    local StrokeColor
    local Color

    local Instances = {}

    ViewmodelVisuals = vape.Categories.Render:CreateModule({
        Name = 'ViewmodelVisuals',
        Function = function(call)
            if call then
                local viewmodel = gameCamera:WaitForChild('Viewmodel', 9e9)
                if not ViewmodelVisuals.Enabled then
                    return
                end

                for i,v in viewmodel:GetChildren() do
                    if v:IsA('Accessory') then
                        local highlight = v.Handle:FindFirstChildOfClass('Highlight') or Instance.new('Highlight', v.Handle)
                        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        highlight.FillTransparency = Color.Opacity
                        highlight.OutlineTransparency = StrokeColor.Opacity
                        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)

                        ViewmodelVisuals:Clean(highlight)
                        table.insert(Instances, highlight)

                        break
                    end
                end

                ViewmodelVisuals:Clean(viewmodel.ChildAdded:Connect(function(visual)
                    if visual:IsA('Accessory') then
                        local highlight = visual.Handle:FindFirstChildOfClass('Highlight') or Instance.new('Highlight', visual.Handle)
                        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        highlight.FillTransparency = Color.Opacity
                        highlight.OutlineTransparency = StrokeColor.Opacity
                        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)

                        ViewmodelVisuals:Clean(highlight)
                        table.insert(Instances, highlight)
                    end
                end))

                ViewmodelVisuals:Clean(gameCamera.ChildAdded:Connect(function(visual)
                    if visual.Name == 'Viewmodel' then
                        ViewmodelVisuals:Toggle()
                        ViewmodelVisuals:Toggle()
                    end
                end))
            end
        end
    })

    Color = ViewmodelVisuals:CreateColorSlider({
        Name = 'Color',
        Default = Color3.new(1, 1, 1),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.FillColor = Color3.fromHSV(hue, sat, val)
                v.FillTransparency = opacity
            end
        end
    })
    StrokeColor = ViewmodelVisuals:CreateColorSlider({
        Name = 'Stroke Color',
        Default = Color3.new(),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.OutlineColor = Color3.fromHSV(hue, sat, val)
                v.OutlineTransparency = opacity
            end
        end
    })
end)
