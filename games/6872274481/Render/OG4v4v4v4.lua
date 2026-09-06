run(function()
	local OG4v4v4v4
	local OldMaterials = {}
	local OldColors = {}
	local oldTexture = {}
	local oldColor = {}
	local deletedNumTeamMembers = {}

	local worldFolder = getWorldFolder()
	if not worldFolder then return end
	local blocks = worldFolder:FindFirstChild('Blocks')
	if not blocks then return end

	local function isValidWoolBlock(obj)
		if not obj:IsA("BasePart") then
			return false
		end
		if obj.Name ~= "wool_orange" and obj.Name ~= "wool_pink" then
			return false
		end
		local parent = obj.Parent
		if parent then
			if parent.Name == "Viewmodel" or parent.Parent and parent.Parent.Name == "Viewmodel" then
				return false
			end

			if parent:IsA("Accessory") or parent:IsA("Tool") then
				return false
			end

			local ancestor = parent
			while ancestor do
				if ancestor:IsA("Model") and playersService:GetPlayerFromCharacter(ancestor) then
					return false
				end
				ancestor = ancestor.Parent
			end
		end

		return true
	end

	local function removeNumTeamMembers(gui)
		if not gui then return end

		local topBarApp = gui:FindFirstChild("TopBarApp")
		if not topBarApp then return end

		local frame5 = topBarApp:FindFirstChild("5")
		if not frame5 then return end

		local frame4 = frame5:FindFirstChild("4")
		if not frame4 then return end

		for _, frameName in pairs({"2", "3", "4", "5"}) do
			local targetFrame = frame4:FindFirstChild(frameName)
			if targetFrame and targetFrame:IsA("Frame") then
				local numLabel = targetFrame:FindFirstChild("NumTeamMembers")
				if numLabel and numLabel:IsA("TextLabel") then
					deletedNumTeamMembers[numLabel] = {
						Parent = numLabel.Parent,
						Name = numLabel.Name,
						Text = numLabel.Text,
						Position = numLabel.Position,
						Size = numLabel.Size,
						Visible = numLabel.Visible
					}
					numLabel:Destroy()
				end
			end
		end
	end

	local function restoreNumTeamMembers()
		for label, data in pairs(deletedNumTeamMembers) do
			if data.Parent and data.Parent.Parent then
				local newLabel = Instance.new("TextLabel")
				newLabel.Name = data.Name
				newLabel.Text = data.Text
				newLabel.Position = data.Position
				newLabel.Size = data.Size
				newLabel.Visible = data.Visible
				newLabel.Parent = data.Parent
			end
		end
		table.clear(deletedNumTeamMembers)
	end

	OG4v4v4v4 = vape.Categories.Render:CreateModule({
		Name = 'OG4v4v4v4',
		Function = function(callback)
			if callback then
				local OrangeMaterial = Instance.new('MaterialVariant')
				OrangeMaterial.Parent = cloneref(game:GetService('MaterialService'))
				OrangeMaterial.Name = 'rbxassetid://16991768606_red'
				OrangeMaterial.ColorMap = 'rbxassetid://16991768606'
				OrangeMaterial.StudsPerTile = 3
				OrangeMaterial.RoughnessMap = 'rbxassetid://16991768606'
				OrangeMaterial.BaseMaterial = 'Fabric'
				OG4v4v4v4:Clean(OrangeMaterial)

				local PinkMaterial = Instance.new('MaterialVariant')
				PinkMaterial.Parent = cloneref(game:GetService('MaterialService'))
				PinkMaterial.Name = 'rbxassetid://16991768606_green'
				PinkMaterial.ColorMap = 'rbxassetid://16991768606'
				PinkMaterial.StudsPerTile = 3
				PinkMaterial.RoughnessMap = 'rbxassetid://16991768606'
				PinkMaterial.BaseMaterial = 'Fabric'
				OG4v4v4v4:Clean(PinkMaterial)

				local topBarGui = lplr.PlayerGui:FindFirstChild('TopBarAppGui')
				if topBarGui then
					removeNumTeamMembers(topBarGui)
				end

				OG4v4v4v4:Clean(lplr.PlayerGui.ChildAdded:Connect(function(gui)
					if gui.Name == "TopBarAppGui" then
						removeNumTeamMembers(gui)

						OG4v4v4v4:Clean(gui.DescendantAdded:Connect(function(descendant)
							if descendant:IsA("Frame") and
							   (descendant.Name == "2" or descendant.Name == "3" or
							    descendant.Name == "4" or descendant.Name == "5") then
								local frame4 = descendant.Parent
								if frame4 and frame4.Name == "4" then
									local frame5 = frame4.Parent
									if frame5 and frame5.Name == "5" then
										local topBarApp = frame5.Parent
										if topBarApp and topBarApp.Name == "TopBarApp" then
											task.wait(0.1)
											local numLabel = descendant:FindFirstChild("NumTeamMembers")
											if numLabel and numLabel:IsA("TextLabel") then
												deletedNumTeamMembers[numLabel] = {
													Parent = numLabel.Parent,
													Name = numLabel.Name,
													Text = numLabel.Text,
													Position = numLabel.Position,
													Size = numLabel.Size,
													Visible = numLabel.Visible
												}
												numLabel:Destroy()
											end
										end
									end
								end
							end
						end))
					end
				end))

				local viewmodel = gameCamera:FindFirstChild("Viewmodel")
				if viewmodel then
					OG4v4v4v4:Clean(viewmodel.ChildAdded:Connect(function(obj)
						if obj.Name == "wool_orange" then
							task.wait(0.01)
							if obj:FindFirstChild('Handle') then
								for i, texture in obj:FindFirstChild('Handle'):GetChildren() do
									if texture:IsA('Texture') then
										oldTexture[texture] = texture.Texture
										oldColor[texture] = texture.Color3
										texture.Texture = "rbxassetid://16991768606"
										texture.Color3 = Color3.fromRGB(196, 40, 28)
									end
								end
							end
						elseif obj.Name == "wool_pink" then
							task.wait(0.01)
							if obj:FindFirstChild('Handle') then
								for i, texture in obj:FindFirstChild('Handle'):GetChildren() do
									if texture:IsA('Texture') then
										oldTexture[texture] = texture.Texture
										oldColor[texture] = texture.Color3
										texture.Texture = "rbxassetid://16991768606"
										texture.Color3 = Color3.fromRGB(15, 185, 55)
									end
								end
							end
						end
					end))
				end

				local character = lplr.Character
				if character then OG4v4v4v4:Clean(character.ChildAdded:Connect(function(obj)
					if obj.Name == "wool_orange" then
						task.wait(0.01)
						if obj:FindFirstChild('Handle') then
							for i, texture in obj:FindFirstChild('Handle'):GetChildren() do
								if texture:IsA('Texture') then
									oldTexture[texture] = texture.Texture
									oldColor[texture] = texture.Color3
									texture.Texture = "rbxassetid://16991768606"
									texture.Color3 = Color3.fromRGB(196, 40, 28)
								end
							end
						end
					elseif obj.Name == "wool_pink" then
						task.wait(0.01)
						if obj:FindFirstChild('Handle') then
							for i, texture in obj:FindFirstChild('Handle'):GetChildren() do
								if texture:IsA('Texture') then
									oldTexture[texture] = texture.Texture
									oldColor[texture] = texture.Color3
									texture.Texture = "rbxassetid://16991768606"
									texture.Color3 = Color3.fromRGB(15, 185, 55)
								end
							end
						end
					end
				end)) end

				OG4v4v4v4:Clean(blocks.ChildAdded:Connect(function(obj)
					if obj.Name == "wool_orange" and isValidWoolBlock(obj) then
						OldMaterials[obj] = obj.MaterialVariant
						OldColors[obj] = obj.Color
						obj.MaterialVariant = 'rbxassetid://16991768606_red'
						obj.Color = Color3.fromRGB(196, 40, 28)
					elseif obj.Name == "wool_pink" and isValidWoolBlock(obj) then
						OldMaterials[obj] = obj.MaterialVariant
						OldColors[obj] = obj.Color
						obj.MaterialVariant = 'rbxassetid://16991768606_green'
						obj.Color = Color3.fromRGB(15, 185, 55)
					end
				end))

				OG4v4v4v4:Clean(workspace.ChildAdded:Connect(function(obj)
					if obj.Name == "wool_orange" and isValidWoolBlock(obj) then
						OldMaterials[obj] = obj.MaterialVariant
						OldColors[obj] = obj.Color
						obj.MaterialVariant = 'rbxassetid://16991768606_red'
						obj.Color = Color3.fromRGB(196, 40, 28)
					elseif obj.Name == "wool_pink" and isValidWoolBlock(obj) then
						OldMaterials[obj] = obj.MaterialVariant
						OldColors[obj] = obj.Color
						obj.MaterialVariant = 'rbxassetid://16991768606_green'
						obj.Color = Color3.fromRGB(15, 185, 55)
					end
				end))

				for _, obj in blocks:GetChildren() do
					if obj.Name == "wool_orange" and isValidWoolBlock(obj) then
						OldMaterials[obj] = obj.MaterialVariant
						OldColors[obj] = obj.Color
						obj.MaterialVariant = 'rbxassetid://16991768606_red'
						obj.Color = Color3.fromRGB(196, 40, 28)
					elseif obj.Name == "wool_pink" and isValidWoolBlock(obj) then
						OldMaterials[obj] = obj.MaterialVariant
						OldColors[obj] = obj.Color
						obj.MaterialVariant = 'rbxassetid://16991768606_green'
						obj.Color = Color3.fromRGB(15, 185, 55)
					end
				end

				task.spawn(function()
					while OG4v4v4v4.Enabled do
						local topBarGui = lplr.PlayerGui:FindFirstChild('TopBarAppGui')
						if topBarGui then
							for i, v in topBarGui:GetDescendants() do
								if v:IsA("Frame") and v.Name == "3" then
									if v.BackgroundColor3 == Color3.fromRGB(242, 142, 41) then
										v.BackgroundColor3 = Color3.fromRGB(196, 40, 28)
										if v.Parent then
											for _, sibling in v.Parent:GetChildren() do
												if sibling:IsA("UIStroke") then
													sibling.Color = Color3.fromRGB(196, 40, 28)
												end
											end
										end
									elseif v.BackgroundColor3 == Color3.fromRGB(255, 102, 204) or
										   v.BackgroundColor3 == Color3.fromRGB(255, 85, 255) or
										   v.BackgroundColor3 == Color3.fromRGB(218, 133, 222) then
										v.BackgroundColor3 = Color3.fromRGB(15, 185, 55)
										if v.Parent then
											for _, sibling in v.Parent:GetChildren() do
												if sibling:IsA("UIStroke") then
													sibling.Color = Color3.fromRGB(15, 185, 55)
												end
											end
										end
									end
								end
							end
						end
						task.wait(0.5)
					end
				end)

				OG4v4v4v4:Clean(lplr.PlayerGui.ChildAdded:Connect(function(obj)
					if obj.Name == "TabListScreenGui" then
						for i, v in obj:GetDescendants() do
							if v:IsA("Frame") and v.Name == "2" then
								if v.BackgroundColor3 == Color3.fromRGB(242, 142, 41) then
									v.BackgroundColor3 = Color3.fromRGB(196, 40, 28)
									if v.Parent then
										for _, sibling in v.Parent:GetChildren() do
											if sibling:IsA("UIStroke") then
												sibling.Color = Color3.fromRGB(196, 40, 28)
											end
										end
									end
									if v:FindFirstChild("TeamName") then
										v:FindFirstChild("TeamName").RichText = true
										v:FindFirstChild("TeamName").Text = "<b>Red Team</b>"
									end
								elseif v.BackgroundColor3 == Color3.fromRGB(255, 102, 204) or
									   v.BackgroundColor3 == Color3.fromRGB(255, 85, 255) or
									   v.BackgroundColor3 == Color3.fromRGB(218, 133, 222) then
									v.BackgroundColor3 = Color3.fromRGB(15, 185, 55)
									if v.Parent then
										for _, sibling in v.Parent:GetChildren() do
											if sibling:IsA("UIStroke") then
												sibling.Color = Color3.fromRGB(15, 185, 55)
											end
										end
									end
									if v:FindFirstChild("TeamName") then
										v:FindFirstChild("TeamName").RichText = true
										v:FindFirstChild("TeamName").Text = "<b>Green Team</b>"
									end
								end
							end
						end
					end
				end))
			else
				local topBarGui = lplr.PlayerGui:FindFirstChild('TopBarAppGui')
				for i, v in topBarGui and topBarGui:GetDescendants() or {} do
					if v:IsA("Frame") and v.Name == "3" then
						if v.BackgroundColor3 == Color3.fromRGB(196, 40, 28) then
							v.BackgroundColor3 = Color3.fromRGB(242, 142, 41)
							if v.Parent then
								for _, sibling in v.Parent:GetChildren() do
									if sibling:IsA("UIStroke") then
										sibling.Color = Color3.fromRGB(242, 142, 41)
									end
								end
							end
						elseif v.BackgroundColor3 == Color3.fromRGB(15, 185, 55) then
							v.BackgroundColor3 = Color3.fromRGB(255, 102, 204)
							if v.Parent then
								for _, sibling in v.Parent:GetChildren() do
									if sibling:IsA("UIStroke") then
										sibling.Color = Color3.fromRGB(255, 102, 204)
									end
								end
							end
						end
					end
				end

				restoreNumTeamMembers()

				for texture, oldTex in pairs(oldTexture) do
					if texture and texture.Parent then
						texture.Texture = oldTex
					end
				end
				for texture, oldCol in pairs(oldColor) do
					if texture and texture.Parent then
						texture.Color3 = oldCol
					end
				end

				for obj, oldMaterial in pairs(OldMaterials) do
					if obj and obj.Parent then
						obj.MaterialVariant = oldMaterial
						if OldColors[obj] then
							obj.Color = OldColors[obj]
						end
					end
				end

				table.clear(OldMaterials)
				table.clear(OldColors)
				table.clear(oldTexture)
				table.clear(oldColor)
			end
		end,
		Tooltip = 'koli shit'
	})
end)
