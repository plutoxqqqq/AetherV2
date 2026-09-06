run(function()
	local RemoveNeon = {Enabled = false}
	local neonConnection
	local safetyLoop
	local originalMaterials = {}
	local processedParts = {}
	local lastCleanup = 0

	local function cleanupDeadReferences()
		local count = 0
		for obj, _ in pairs(originalMaterials) do
			if not obj or not obj.Parent then
				originalMaterials[obj] = nil
				processedParts[obj] = nil
			end
			count = count + 1
			if count % 100 == 0 then
				task.wait()
			end
		end
	end

	local function removeNeonFromPart(obj)
		if obj:IsA("BasePart") then
			if obj.Material == Enum.Material.Neon then
				if not originalMaterials[obj] then
					originalMaterials[obj] = {
						Material = obj.Material,
						Reflectance = obj.Reflectance
					}
				end
				pcall(function()
					obj.Material = Enum.Material.Plastic
					obj.Reflectance = 0
				end)
			end
		end
	end

	local function restoreNeon()
		for obj, data in pairs(originalMaterials) do
			if obj and obj.Parent then
				pcall(function()
					obj.Material = data.Material
					obj.Reflectance = data.Reflectance
				end)
			end
		end
		table.clear(originalMaterials)
		table.clear(processedParts)
	end

	local function batchProcessParts(parts, batchSize)
		local count = 0
		for i, part in ipairs(parts) do
			if part and part.Parent then
				removeNeonFromPart(part)
				count = count + 1
			end
			if i % batchSize == 0 then
				task.wait()
			end
		end
		return count
	end

	RemoveNeon = vape.Categories.World:CreateModule({
		Name = 'RemoveNeon',
		Function = function(callback)
			if callback then
				task.spawn(function()
					local allParts = {}
					for _, v in pairs(workspace:GetDescendants()) do
						if v:IsA("BasePart") then
							table.insert(allParts, v)
						end
					end

					batchProcessParts(allParts, 200)
				end)

				neonConnection = workspace.DescendantAdded:Connect(function(obj)
					if RemoveNeon.Enabled then
						removeNeonFromPart(obj)
					end
				end)

				safetyLoop = task.spawn(function()
					while RemoveNeon.Enabled do
						task.wait(30)
						if RemoveNeon.Enabled then
							cleanupDeadReferences()
						end
					end
				end)
			else
				if neonConnection then
					neonConnection:Disconnect()
					neonConnection = nil
				end
				if safetyLoop then
					task.cancel(safetyLoop)
					safetyLoop = nil
				end
				restoreNeon()
			end
		end,
	})
end)
