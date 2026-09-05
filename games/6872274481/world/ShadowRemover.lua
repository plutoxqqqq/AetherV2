run(function()
	local ShadowRemover
	local connections = {}
	local originalShadows = {}
	local processedShadows = {}

	local function removeShadow(obj)
		if obj:IsA("BasePart") and not processedShadows[obj] then
			if not originalShadows[obj] then
				originalShadows[obj] = obj.CastShadow
			end
			obj.CastShadow = false
			processedShadows[obj] = true
		end
	end

	ShadowRemover = vape.Categories.World:CreateModule({
		Name = 'ShadowRemover',
		Function = function(callback)
			if callback then
				local descendants = workspace:GetDescendants()

				task.spawn(function()
					for i, obj in descendants do
						removeShadow(obj)
						if i % 100 == 0 then
							task.wait()
						end
					end
				end)

				local conn = workspace.DescendantAdded:Connect(function(obj)
					if ShadowRemover.Enabled then
						removeShadow(obj)
					end
				end)
				table.insert(connections, conn)
			else
				for obj, shadow in pairs(originalShadows) do
					if obj and obj.Parent then
						pcall(function()
							obj.CastShadow = shadow
						end)
					end
				end

				for _, conn in connections do
					conn:Disconnect()
				end
				table.clear(connections)
				table.clear(originalShadows)
				table.clear(processedShadows)
			end
		end,
	})
end)