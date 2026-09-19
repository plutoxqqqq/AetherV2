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
	local Beds = createSection()
	local BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			Beds:Set(callback)
			for _, setting in {} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders beds through walls'
	})
	--------------------------------------------------------------------
	-- Beds
	--------------------------------------------------------------------
	Beds.Start = function(self)
		local function added(bed)
			if not self.Enabled or self.Reference[bed] then return end
			local bedFolder = Instance.new('Folder')
			bedFolder.Parent = self.Folder
			self.Reference[bed] = bedFolder
			local parts = bed:GetChildren()
			table.sort(parts, function(a, b)
				return a.Name > b.Name
			end)
			for _, part in parts do
				if part:IsA('BasePart') and part.Name ~= 'Blanket' then
					local handle = Instance.new('BoxHandleAdornment')
					handle.Size = part.Size + Vector3.new(0.01, 0.01, 0.01)
					handle.AlwaysOnTop = true
					handle.ZIndex = 2
					handle.Visible = true
					handle.Adornee = part
					handle.Color3 = part.Color
					if part.Name == 'Legs' then
						handle.Color3 = Color3.fromRGB(167, 112, 64)
						handle.Size = part.Size + Vector3.new(0.01, -1, 0.01)
						handle.CFrame = CFrame.new(0, -0.4, 0)
						handle.ZIndex = 0
					end
					handle.Parent = bedFolder
				end
			end
			table.clear(parts)
		end
		self:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
			task.delay(0.2, added, bed)
		end))
		self:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
			if self.Reference[bed] then
				self.Reference[bed]:Destroy()
				self.Reference[bed] = nil
			end
		end))
		for _, bed in collectionService:GetTagged('bed') do
			added(bed)
		end
	end
end)
