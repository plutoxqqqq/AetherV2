run(function()
    local KitDisplay

    local function getKitMeta(player)
	local kit = player:GetAttribute('PlayingAsKits') or player:GetAttribute('PlayingAsKit') or 'none'
	return bedwars.BedwarsKitMeta[kit] or bedwars.BedwarsKitMeta.none
    end

    local function getPlayerFromDraft(render, name)
	local id = render and render:match('id=(%d+)')
	if id then
		local player = playersService:GetPlayerByUserId(tonumber(id))
		if player then
			return player
		end
	end

	for _, v in playersService:GetPlayers() do
		if render and render:find('id=' .. v.UserId, 1, true) then
			return v
		end

		if name and (v.Name == name or v.DisplayName == name or v:GetAttribute('DisguiseDisplayName') == name) then
			return v
		end

		local displayName
		pcall(function()
			displayName = bedwars.StreamerModeController:getDisplayName(v)
		end)
		if name and displayName == name then
			return v
		end
	end
	return nil
    end

    local waitForChild = function(start, ...)
	local parent = start
	for _, v in {...} do
		parent = parent and parent:WaitForChild(v, 5)
		if not parent then
			break
		end
	end
	return parent
    end

    local function getPlayerName(card)
	local textbar = card and card:FindFirstChild('TextBackgroundBar')
	local label = textbar and textbar:FindFirstChild('PlayerName') or card and card:FindFirstChild('PlayerName', true)
	return label and label.Text or ''
    end

    local function getDraftCard(container)
	if not container then
		return
	end
	return container.Name == 'MatchDraftPlayerCard' and container or container:FindFirstChild('MatchDraftPlayerCard', true)
    end

    local function callback5v5(v, plr)
	if not v then
		return
	end
	local render = v:FindFirstChild('PlayerRender', true)
	local player = plr or getPlayerFromDraft(render and render.Image or '', getPlayerName(v))

	if player then
		local kitImage = getKitMeta(player)
		local roact = v:FindFirstChild('KitImage')

		if not roact then
			roact = Instance.new('ImageLabel', v)
			roact.BackgroundTransparency = 1
			roact.AnchorPoint = Vector2.new(1, 0.5)
			roact.Position = UDim2.fromScale(1.05, 0.5)
			roact.Name = 'KitImage'
			roact.Size = UDim2.fromScale(1.5, 1.5)
			roact.ZIndex = 1
			roact.ImageTransparency = 0.4
			roact.SliceCenter = Rect.new(0, 0, 0, 0)
			roact.SliceScale = 1
			roact.ScaleType = Enum.ScaleType.Crop

			KitDisplay:Clean(roact)

			local ratio = Instance.new('UIAspectRatioConstraint', roact)
			ratio.Name = '1'
			ratio.AspectRatio = 1
			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
			ratio.DominantAxis = Enum.DominantAxis.Width
		end

		roact.Image = kitImage.renderImage
		roact.Position = UDim2.fromScale(1.05, 0)
		tweenService:Create(roact, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.fromScale(1.05, 0.4)}):Play()

		local function update()
			kitImage = getKitMeta(player)
			roact.Image = kitImage.renderImage
		end

		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(update))
		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKit'):Connect(update))
	end
    end

    local function callbacksquad(v)
	if not v then
		return
	end
	local render = v:FindFirstChild('PlayerRender', true)
	local player = render and getPlayerFromDraft(render.Image, '') or nil

	if player then
		local kitImage = getKitMeta(player)
		local Roact = v:FindFirstChild('Kitcvrender')

		if not Roact then
			local base = v:FindFirstChild('3') or v:WaitForChild('3', 5)
			if not base then
				return
			end
			Roact = base:Clone()
			Roact.Parent = v
			Roact.Name = 'Kitcvrender'
			KitDisplay:Clean(Roact)
		end

		Roact.Image = kitImage.renderImage

		KitDisplay:Clean(render:GetPropertyChangedSignal('Image'):Connect(function()
			local newplayer = getPlayerFromDraft(render.Image, '')
			if newplayer then
				player = newplayer
				kitImage = getKitMeta(player)
				Roact.Image = kitImage.renderImage
			end
		end))

		local function update()
			kitImage = getKitMeta(player)
			Roact.Image = kitImage.renderImage
		end

		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(update))
		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKit'):Connect(update))
	end
    end

    local function setup5v5(DraftApp)
	local Background = DraftApp:FindFirstChild('DraftAppBackground')
	local BodyContainer = Background and Background:FindFirstChild('1') and Background['1']:FindFirstChild('BodyContainer')
	local hooked = false

	for i = 1, 2 do
		local dtc = BodyContainer and BodyContainer:FindFirstChild('Team' .. i .. 'Column')
		if dtc then
			hooked = true
			KitDisplay:Clean(dtc.ChildAdded:Connect(function(child)
				task.delay(0.2, function()
					if KitDisplay.Enabled then
						callback5v5(getDraftCard(child))
					end
				end)
			end))

			for _, v in dtc:GetChildren() do
				if v:IsA('Frame') then
					callback5v5(getDraftCard(v))
				end
			end
		end
	end

	if not hooked then
		for _, label in DraftApp:GetDescendants() do
			if label:IsA('TextLabel') and label.Name == 'PlayerName' then
				local container = label.Parent
				for _ = 1, 3 do
					container = container and container.Parent
				end
				if container then
					callback5v5(getDraftCard(container))
				end
			end
		end

		KitDisplay:Clean(DraftApp.DescendantAdded:Connect(function(child)
			if child:IsA('TextLabel') and child.Name == 'PlayerName' then
				task.delay(0.2, function()
					local container = child.Parent
					for _ = 1, 3 do
						container = container and container.Parent
					end
					if KitDisplay.Enabled and container then
						callback5v5(getDraftCard(container))
					end
				end)
			end
		end))
	end

	return hooked
    end

    local function setupSquad(DraftApp)
	local Background = DraftApp:FindFirstChild('DraftAppBackground')
	local BodyContainer = Background and Background:FindFirstChild('1') and Background['1']:FindFirstChild('BodyContainer')
	local TeamsColumn = BodyContainer and BodyContainer:FindFirstChild('TeamsColumn')
	if not TeamsColumn then
		return
	end

	for _, v: Instance in TeamsColumn:GetChildren() do
		if v:IsA('Frame') then
			local plrframe = waitForChild(v, '1', '2', '4')
			if plrframe then
				for _, plr in plrframe:GetChildren() do
					callbacksquad(plr)
				end

				KitDisplay:Clean(plrframe.ChildAdded:Connect(function(plr)
					KitDisplay:Toggle()
					KitDisplay:Toggle()
				end))
			end
		end
	end
    end

    KitDisplay = kits:CreateModule({
	Name = 'KitDisplay',
	Category = 'Visual',
	Function = function(call)
		if call then
			local DraftApp = lplr.PlayerGui:WaitForChild('MatchDraftApp', 9e9)
			setup5v5(DraftApp)
			setupSquad(DraftApp)
		end
	end,
	Tooltip = 'Allows you to see the other opponent kits'
    })
end)
