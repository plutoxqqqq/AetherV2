run(function()
    local GeneratorESP
    local Transparency
    local Scale
    local Whitelist
    local Whitelisted = { ListEnabled = {}, Object = nil }

    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local Reference, Strings, Cooldown = {}, {}, {}
    local Updates = {}

    local function getNumber(text)
	if not text or text == '' then
		return 0
	end
	local seconds = text:match('%[(%d+)%]')
	if seconds then
		return tonumber(seconds) or 0
	end
	local justNumber = text:match('(%d+)')
	if justNumber then
		return tonumber(justNumber) or 0
	end
	return 0
    end

    local function Added(ent)
	local App = ent.RoactTree.TeamOreGeneratorApp
	local Name = (App:FindFirstChild('GlobalOreGenerator') or App:FindFirstChild('TeamGenMain'))
	local Countdown = (Name or App):FindFirstChild('Countdown', true)
	if Name then
		Name = Name:FindFirstChild('Title')
	end

	local TierType = ''
	if Name then
		Name = Name.Text
		TierType = 'iron'
	else
		local Ore = ent:GetAttribute('Id')
		Ore = Ore:sub(0, #Ore - 2)
		TierType = (Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore)):lower()
		Name = Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore) .. ' Generator'
	end

	if Whitelist.Enabled and not table.find(Whitelisted.ListEnabled, TierType) then
		return
	end

	Strings[ent] = `{Name} %s%s`
	local nametag = Instance.new('TextLabel')
	nametag.TextSize = 14 * Scale.Value
	nametag.Font = Enum.Font.Arial
	local format = string.format(Strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, '')
	local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
	nametag.Name = Name
	nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
	nametag.AnchorPoint = Vector2.new(0.5, 1)
	nametag.BackgroundColor3 = Color3.new()
	nametag.BackgroundTransparency = 0.5
	nametag.BorderSizePixel = 0
	nametag.Visible = false
	nametag.Text = format
	nametag.TextColor3 = Color3.new(1, 1, 1)
	nametag.RichText = true
	nametag.Parent = Folder
	Reference[ent] = nametag

	local Update = function()
		Updates[ent] = true
	end
	GeneratorESP:Clean(ent:GetAttributeChangedSignal('GeneratorLevel'):Connect(Update))
	GeneratorESP:Clean(ent:GetAttributeChangedSignal('Cooldown'):Connect(Update))
	if Countdown then
		Cooldown[ent] = Countdown
		GeneratorESP:Clean(Countdown:GetPropertyChangedSignal('Text'):Connect(Update))
	end
	Update()
    end
    local function Updated(ent)
	if Reference[ent] then
		Reference[ent].TextSize = 14 * Scale.Value
		Reference[ent].BackgroundTransparency = Transparency.Value
	end
    end
    local function Removing(ent)
	if Reference[ent] then
		Reference[ent]:Destroy()
		Reference[ent] = nil
	end
    end

    GeneratorESP = vape.Categories.Render:CreateModule({
	Name = 'GeneratorESP',
	Function = function(call)
		if call then
			for _, v in collectionService:GetTagged('Generator') do
				Added(v)
			end
			GeneratorESP:Clean(collectionService:GetInstanceAddedSignal('Generator'):Connect(Added))
			GeneratorESP:Clean(collectionService:GetInstanceRemovedSignal('Generator'):Connect(Removing))
			GeneratorESP:Clean(runService.PreRender:Connect(function()
				for ent, nametag in Reference do
					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
					nametag.Visible = headVis
					if not headVis then
						continue
					end

					if Updates[ent] then
						nametag.Text = string.format(Strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, Cooldown[ent] and ` | {getNumber(Cooldown[ent].Text)}s` or '')
						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						Updates[ent] = nil
					end

					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
				end
			end))
		else
			for i in Reference do
				Removing(i)
			end
		end
	end,
	Tooltip = 'Renders generator locations and info'
    })

    Transparency = GeneratorESP:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if GeneratorESP.Enabled then
			for ent in Reference do
				Updated(ent)
			end
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 100,
    })
    Scale = GeneratorESP:CreateSlider({
	Name = 'Scale',
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10,
	Function = function()
		if GeneratorESP.Enabled then
			for ent in Reference do
				Updated(ent)
			end
		end
	end,
    })
    Whitelist = GeneratorESP:CreateToggle({
	Name = 'Use whitelist',
	Default = true,
	Function = function(call)
		if Whitelisted.Object then
			Whitelisted.Object.Visible = call
		end
	end,
    })
    Whitelisted = GeneratorESP:CreateTextList({
	Name = 'Generators',
	Darker = true,
	Default = {'diamond', 'iron'},
    })
end)
