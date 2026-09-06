run(function()
	local DeathSpawn
	local generation = 0
	local deathConnection
	local characterConnection
	local groundConnection

	local lastPosition
	local lastRotation

	local function disconnect(connection)
		if connection then
			connection:Disconnect()
		end
	end

	local function clearConnections()
		disconnect(deathConnection)
		disconnect(characterConnection)
		disconnect(groundConnection)

		deathConnection = nil
		characterConnection = nil
		groundConnection = nil
	end

	local function hookCharacter(character, myGeneration)
		if myGeneration ~= generation or not DeathSpawn.Enabled then return end

		local humanoid = character:FindFirstChildOfClass('Humanoid')
			or character:WaitForChild('Humanoid', 5)
		local root = character:FindFirstChild('HumanoidRootPart')
			or character:WaitForChild('HumanoidRootPart', 5)

		if not humanoid or not root then return end

		disconnect(deathConnection)
		disconnect(groundConnection)

		-- Save the last position only while standing on something.
		groundConnection = game:GetService('RunService').Heartbeat:Connect(function()
			if myGeneration ~= generation or not DeathSpawn.Enabled then return end

			if humanoid.FloorMaterial ~= Enum.Material.Air then
				lastPosition = root.Position
				lastRotation = root.CFrame.Rotation
			end
		end)

		DeathSpawn:Clean(groundConnection)

		deathConnection = humanoid.Died:Connect(function()
			if myGeneration ~= generation or not DeathSpawn.Enabled then return end
			if not lastPosition then return end

			disconnect(characterConnection)

			characterConnection = lplr.CharacterAdded:Connect(function(newCharacter)
				if myGeneration ~= generation or not DeathSpawn.Enabled then return end

				task.defer(function()
					local newRoot = newCharacter:WaitForChild('HumanoidRootPart', 5)
					if not newRoot then return end

					newRoot.CFrame = CFrame.new(lastPosition) * lastRotation
					newRoot.AssemblyLinearVelocity = Vector3.zero
					newRoot.AssemblyAngularVelocity = Vector3.zero
				end)
			end)

			DeathSpawn:Clean(characterConnection)
		end)

		DeathSpawn:Clean(deathConnection)
	end

	DeathSpawn = vape.Categories.Blatant:CreateModule({
		Name = 'DeathSpawn',
		Function = function(callback)
			generation += 1
			local myGeneration = generation

			clearConnections()

			if not callback then return end

			lastPosition = nil
			lastRotation = nil

			if lplr.Character then
				hookCharacter(lplr.Character, myGeneration)
			end

			local connection = lplr.CharacterAdded:Connect(function(character)
				hookCharacter(character, myGeneration)
			end)

			DeathSpawn:Clean(connection)
		end,
		Tooltip = 'Respawn at your last grounded position and rotation.'
	})
end)