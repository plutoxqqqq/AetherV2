run(function()
    local Coords

    local gui, texts = nil, {}
    local division = game.GameId == 2619619496 and 3 or 1

    Coords = vape.Categories.Legit:CreateModule({
	Name = 'Coords',
	Category = 'Hud',
	Size = UDim2.fromOffset(288, 64),
	Function = function(callback)
		if gui then
			gui.Visible = callback
		end

		if callback then
			Coords:Clean(runService.PreAnimation:Connect(function()
				if entitylib.isAlive then
					local position = entitylib.character.RootPart.Position
					local size = 220
					for _, v in { 'x', 'y', 'z' } do
						local text = tostring(math.floor(position[v:upper()] / division))
						texts[v].Text = text
						size += (textService:GetTextSize(text, 20, Enum.Font.Arial, Vector2.new(1000, 56)).X * 0.1)
					end
					tweenService
						:Create(gui, TweenInfo.new(0.1), { Size = UDim2.fromOffset(math.round(size), 56) })
						:Play()
				end
			end))
		end
	end,
    })
    Coords:CreateToggle({
	Name = 'Render Background',
	Default = true,
	Function = function(callback)
		if gui then
			gui.BackgroundTransparency = callback and 0.5 or 1
		end
	end,
    })

    gui = Instance.new('Frame')
    gui.BackgroundColor3 = Color3.new()
    gui.BackgroundTransparency = 0.5
    gui.Size = UDim2.fromOffset(218, 56)
    gui.Parent = Coords.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = gui
    local semibold = Font.new('rbxasset://fonts/families/Arimo.json', Enum.FontWeight.SemiBold)
    for i, v in { 'x', 'y', 'z' } do
	local label = Instance.new('TextLabel')
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, v == 'x' and 1 or v == 'y' and 80 or 160, 0.5, -3)
	label.Size = UDim2.fromOffset(25, 25)
	label.FontFace = semibold
	label.Text = v:upper()
	label.ZIndex = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 12
	label.Parent = gui
	local labelshadow = label:Clone()
	labelshadow.Position = label.Position + UDim2.fromOffset(1, 1)
	labelshadow.ZIndex = 0
	labelshadow.Name = 'TextShadow'
	labelshadow.TextColor3 = Color3.new()
	labelshadow.Parent = gui
	local display = label:Clone()
	display.Position = UDim2.new(0, v == 'x' and 26 or v == 'y' and 104 or 186, 0.5, -6)
	display.Size = UDim2.fromOffset(40, 20)
	display.FontFace = semibold
	display.Text = '-0'
	display.TextXAlignment = Enum.TextXAlignment.Left
	display.TextSize = 19
	display.Parent = gui
	local shadow = display:Clone()
	shadow.Position = shadow.Position + UDim2.fromOffset(1, 1)
	shadow.Name = 'TextShadow'
	shadow.ZIndex = 0
	shadow.TextColor3 = Color3.new()
	shadow.Parent = gui
	vape:Clean(display:GetPropertyChangedSignal('Text'):Connect(function()
		shadow.Text = display.Text
	end))
	texts[v] = display
    end
    for _, v in { 68, 150 } do
	local spacing = Instance.new('Frame')
	spacing.AnchorPoint = Vector2.new(0, 0.5)
	spacing.Name = 'Spacing'
	spacing.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
	spacing.BackgroundTransparency = 0.5
	spacing.Position = UDim2.new(0, v, 0.5, -5)
	spacing.BorderSizePixel = 0
	spacing.Size = UDim2.fromOffset(2, 20)
	spacing.Parent = gui
    end
end)