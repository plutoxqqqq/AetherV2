run(function()
	local UIS = game:GetService('UserInputService')
	local CustomCursor = {Enabled = false}
	local mouseDropdown = {Value = 'Arrow'}
	local mouseIcons = {
		['CS:GO'] = 'rbxassetid://14789879068',
		['Old Roblox Mouse'] = 'rbxassetid://13546344315',
		['dx9ware'] = 'rbxassetid://12233942144',
		['Aimbot'] = 'rbxassetid://8680062686',
		['Triangle'] = 'rbxassetid://14790304072',
		['Arrow'] = 'rbxassetid://14790316561'
	}
	local customMouseIcon = {Enabled = false}
	local customIcon = {Value = ''}
	local applyingCursor = false
	local function applyCursor()
		if not CustomCursor.Enabled or applyingCursor then return end
		local wanted = customMouseIcon.Enabled and 'rbxassetid://'..customIcon.Value or mouseIcons[mouseDropdown.Value]
		if UIS.MouseIcon ~= wanted then
			applyingCursor = true
			UIS.MouseIcon = wanted
			applyingCursor = false
		end
	end
	CustomCursor = vape.Categories.Utility:CreateModule({
		Name = 'CustomCursor',
		Tooltip = 'changes your cursor\'s image',
		Function = function(callback)
			if callback then
				applyCursor()
				CustomCursor:Clean(UIS:GetPropertyChangedSignal('MouseIcon'):Connect(applyCursor))
			else
				UIS.MouseIcon = ''
				task.wait()
				UIS.MouseIcon = ''
			end
		end
	})
	mouseDropdown = CustomCursor:CreateDropdown({
		Name = 'Mouse Icon',
		List = {
			'CS:GO',
			'Old Roblox Mouse',
			'dx9ware',
			'Aimbot',
			'Triangle',
			'Arrow'
		},
		Function = applyCursor
	})
	customMouseIcon = CustomCursor:CreateToggle({
		Name = 'Custom Icon',
		Function = applyCursor
	})
	customIcon = CustomCursor:CreateTextBox({
		Name = 'Custom Mouse Icon',
		TempText = 'Image ID (not decal)',
		Function = applyCursor
	})
end)