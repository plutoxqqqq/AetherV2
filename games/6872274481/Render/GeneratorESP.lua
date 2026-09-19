run(function()
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local function createSection()
		local section = {
			Enabled = false,
			Connections = {},
			Reference = {},
			Folder = Instance.new('Folder')
		}
		section.Folder.Parent = Folder
		function section:Clean(item)
			if type(item) == 'function' then
				table.insert(self.Connections, {Disconnect = item})
			elseif item then
				table.insert(self.Connections, item)
			end
		end
		function section:Clear()
			for _, connection in self.Connections do
				pcall(function() connection:Disconnect() end)
			end
			table.clear(self.Connections)
			if self.Stop then self.Stop(self) end
			for instance in self.Reference do
				pcall(function() instance:Destroy() end)
			end
			table.clear(self.Reference)
			self.Folder:ClearAllChildren()
		end
		function section:Set(callback)
			if callback == self.Enabled then return end
			self.Enabled = callback
			self:Clear()
			if callback and self.Start then self.Start(self) end
		end
		return section
	end
	local Generators = createSection()
	local GeneratorESP = vape.Categories.Render:CreateModule({
		Name = 'GeneratorESP',
		Function = function(callback)
			Generators:Set(callback)
			for _, setting in {GeneratorTransparency,
				GeneratorScale,
				GeneratorWhitelist,
				GeneratorList} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders generator locations and info'
	})
	local GeneratorTransparency = GeneratorESP:CreateSlider({Name = 'Generator transparency', Default = 0.5, Min = 0, Max = 1, Decimal = 100})
	local GeneratorScale = GeneratorESP:CreateSlider({Name = 'Generator scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10})
	local GeneratorWhitelist = GeneratorESP:CreateToggle({Name = 'Generator whitelist', Default = true})
	local GeneratorList = GeneratorESP:CreateTextList({Name = 'Generators list', Darker = true, Default = {'diamond', 'iron'}})
	--------------------------------------------------------------------
	-- Generators
	--------------------------------------------------------------------

	Generators.Start = function(self)
		local strings, cooldown, updates = {}, {}, {}
		local function getNumber(text)
			if not text or text == '' then return 0 end
			local seconds = text:match('%[(%d+)%]')
			if seconds then return tonumber(seconds) or 0 end
			local justNumber = text:match('(%d+)')
			if justNumber then return tonumber(justNumber) or 0 end
			return 0
		end
		local function updated(ent)
			local nametag = self.Reference[ent]
			if nametag then
				nametag.TextSize = 14 * GeneratorScale.Value
				nametag.BackgroundTransparency = GeneratorTransparency.Value
			end
		end
		local function removing(ent)
			if self.Reference[ent] then
				self.Reference[ent]:Destroy()
				self.Reference[ent] = nil
			end
		end
		local function added(ent)
			local app = ent.RoactTree.TeamOreGeneratorApp
			local name = (app:FindFirstChild('GlobalOreGenerator') or app:FindFirstChild('TeamGenMain'))
			local countdown = (name or app):FindFirstChild('Countdown', true)
			if name then
				name = name:FindFirstChild('Title')
			end
			local tierType = ''
			if name then
				name = name.Text
				tierType = 'iron'
			else
				local ore = ent:GetAttribute('Id')
				ore = ore:sub(0, #ore - 2)
				tierType = (ore:sub(0, 1):upper() .. ore:sub(2, #ore)):lower()
				name = ore:sub(0, 1):upper() .. ore:sub(2, #ore) .. ' Generator'
			end
			if GeneratorWhitelist.Enabled and not table.find(GeneratorList.ListEnabled, tierType) then return end
			strings[ent] = `{name} %s%s`
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * GeneratorScale.Value
			nametag.Font = Enum.Font.Arial
			local format = string.format(strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, '')
			local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = 0.5
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = format
			nametag.TextColor3 = Color3.new(1, 1, 1)
			nametag.RichText = true
			nametag.Parent = self.Folder
			self.Reference[ent] = nametag
			local update = function()
				updates[ent] = true
			end
			self:Clean(ent:GetAttributeChangedSignal('GeneratorLevel'):Connect(update))
			self:Clean(ent:GetAttributeChangedSignal('Cooldown'):Connect(update))
			if countdown then
				cooldown[ent] = countdown
				self:Clean(countdown:GetPropertyChangedSignal('Text'):Connect(update))
			end
			update()
		end
		self.Stop = function()
			table.clear(strings)
			table.clear(cooldown)
			table.clear(updates)
		end
		for _, v in collectionService:GetTagged('Generator') do
			added(v)
		end
		self:Clean(collectionService:GetInstanceAddedSignal('Generator'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('Generator'):Connect(removing))
		self:Clean(runService.PreRender:Connect(function()
			for ent, nametag in self.Reference do
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
				nametag.Visible = headVis
				if not headVis then continue end
				if updates[ent] then
					nametag.Text = string.format(strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, cooldown[ent] and ` | {getNumber(cooldown[ent].Text)}s` or '')
					local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
					nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
					updates[ent] = nil
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end))
	end
	GeneratorTransparency.Function = function()
		if Generators.Enabled then
			for ent in Generators.Reference do
				local nametag = Generators.Reference[ent]
				nametag.TextSize = 14 * GeneratorScale.Value
				nametag.BackgroundTransparency = GeneratorTransparency.Value
			end
		end
	end
	GeneratorScale.Function = GeneratorTransparency.Function
	GeneratorWhitelist.Function = function(callback)
		if GeneratorList.Object then
			GeneratorList.Object.Visible = callback
		end
		Generators:Restart()
	end
	GeneratorList.Function = function()
		Generators:Restart()
	end
end)
