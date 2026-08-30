run(function()
	local RemovePlayerLevel

	local function removePlayerLevels(gui)
		for _, descendant in gui:GetDescendants() do
			if descendant:IsA("TextLabel") and descendant.Name == "PlayerLevel" then
				descendant:Destroy()
			end
		end
	end

	RemovePlayerLevel = vape.Categories.Render:CreateModule({
		Name = 'RemovePlayerLevelUI',
		Function = function(callback)
			if callback then
				local existingTabList = lplr.PlayerGui:FindFirstChild("TabListScreenGui")
				if existingTabList then
					removePlayerLevels(existingTabList)
				end

				RemovePlayerLevel:Clean(lplr.PlayerGui.ChildAdded:Connect(function(gui)
					if gui.Name == "TabListScreenGui" then
						removePlayerLevels(gui)

						RemovePlayerLevel:Clean(gui.DescendantAdded:Connect(function(descendant)
							if descendant:IsA("TextLabel") and descendant.Name == "PlayerLevel" then
								descendant:Destroy()
							end
						end))
					end
				end))

			end
		end,
		Tooltip = 'Removes player levels from the TabList'
	})
end)