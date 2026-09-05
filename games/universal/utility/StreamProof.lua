local vape = shared.vape
local userInputService = game:GetService('UserInputService')
local runService = game:GetService('RunService')

run(function()
	local savedNotification
	local savedButton
	local savedButtonProperties = {}
	local mobileConnection

	local function setButtonHidden(button, hidden)
		if not button or not button:IsA('GuiObject') then return end
		if hidden then
			if savedButton ~= button then
				savedButton = button
				table.clear(savedButtonProperties)
				local objects = {button}
				for _, child in button:GetDescendants() do
					objects[#objects + 1] = child
				end
				local function save(object, property)
					local ok, value = pcall(function() return object[property] end)
					if ok then
						savedButtonProperties[#savedButtonProperties + 1] = {object, property, value}
						pcall(function() object[property] = 1 end)
					end
				end
				for _, object in objects do
					if object:IsA('GuiObject') then
						for _, property in {'BackgroundTransparency', 'ImageTransparency', 'TextTransparency', 'TextStrokeTransparency', 'GroupTransparency'} do
							pcall(function() save(object, property) end)
						end
						pcall(function() object.Visible = true end)
					elseif object:IsA('UIStroke') then
						save(object, 'Transparency')
					end
				end
			end
		else
			for _, entry in savedButtonProperties do
				pcall(function() entry[1][entry[2]] = entry[3] end)
			end
			table.clear(savedButtonProperties)
			savedButton = nil
		end
	end

	vape.Categories.Utility:CreateModule({
		Name = 'StreamProof',
		Tooltip = 'Hides AetherV2 visual artifacts without changing module states',
		Function = function(enabled)
			if enabled then
				savedNotification = vape.CreateNotification
				vape.CreateNotification = function() end

				pcall(function()
					if type(_G.AetherV2CloseLoadingScreen) == 'function' then
						_G.AetherV2CloseLoadingScreen()
					end
				end)

				pcall(function()
					if getgenv and type(getgenv().AetherV2DrawingController) == 'table' then
						getgenv().AetherV2DrawingController:SetSuppressed(true)
					end
				end)

				if userInputService.TouchEnabled and not userInputService.KeyboardEnabled then
					setButtonHidden(vape.VapeButton, true)
					mobileConnection = runService.RenderStepped:Connect(function()
						if vape.VapeButton ~= savedButton then
							setButtonHidden(savedButton, false)
							setButtonHidden(vape.VapeButton, true)
						end
					end)
					vape:Clean(mobileConnection)
				end
			else
				if mobileConnection then
					mobileConnection:Disconnect()
					mobileConnection = nil
				end
				setButtonHidden(savedButton, false)
				if savedNotification then
					vape.CreateNotification = savedNotification
					savedNotification = nil
				end
				pcall(function()
					if getgenv and type(getgenv().AetherV2DrawingController) == 'table' then
						getgenv().AetherV2DrawingController:SetSuppressed(false)
					end
				end)
			end
		end
	})
end)
