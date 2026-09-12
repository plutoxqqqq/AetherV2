run(function()
	local InfiniteFly
	local UpSpeed
	local DownSpeed
	local state
	local generation = 0

	local function cleanup()
		local current = state
		state = nil
		if not current then return end
		if current.Connection then current.Connection:Disconnect() end
		if current.DiedConnection then current.DiedConnection:Disconnect() end
		if current.CharacterConnection then current.CharacterConnection:Disconnect() end
		if current.Character and current.Character.Parent then
			local humanoid = current.Character:FindFirstChildOfClass('Humanoid')
			local root = current.Root
			if root and root.Parent then
				root.Anchored = false
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
			if humanoid and humanoid.Health > 0 then
				humanoid:ChangeState(Enum.HumanoidStateType.Landed)
			end
		end
	end

	local function disable()
		task.defer(function()
			if InfiniteFly.Enabled then InfiniteFly:Toggle() end
		end)
	end

	local function start()
		if not entitylib.isAlive or not entitylib.character then disable(); return end
		cleanup()
		generation += 1
		local myGeneration = generation
		local character = entitylib.character.Character
		local root = entitylib.character.RootPart
		local humanoid = entitylib.character.Humanoid
		if not character or not root or not humanoid then disable(); return end

		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		humanoid.AutoRotate = true

		state = {Character = character, Root = root, Humanoid = humanoid}
		state.DiedConnection = humanoid.Died:Connect(function()
			generation += 1
			cleanup()
		end)
		state.CharacterConnection = lplr.CharacterAdded:Connect(function()
			generation += 1
			cleanup()
			if InfiniteFly.Enabled then
				task.delay(0.35, function()
					if InfiniteFly.Enabled then start() end
				end)
			end
		end)

		state.Connection = runService.Heartbeat:Connect(function()
			if myGeneration ~= generation or not InfiniteFly.Enabled then return end
			if not root.Parent or humanoid.Health <= 0 then
				generation += 1
				cleanup()
				return
			end
			if inputService:GetFocusedTextBox() then return end

			local movement = Vector3.zero
			if inputService:IsKeyDown(Enum.KeyCode.Space) then
				movement += Vector3.new(0, UpSpeed.Value / 10, 0)
			end
			if inputService:IsKeyDown(Enum.KeyCode.LeftShift) or inputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				movement -= Vector3.new(0, DownSpeed.Value / 10, 0)
			end
			if movement.Magnitude > 0 then
				root.CFrame += movement
			end
		end)
	end

	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteFly',
		Tooltip = 'Anchors you in place and lets you fly straight up and down with Space and LeftShift',
		Function = function(callback)
			generation += 1
			if callback then start() else cleanup() end
		end
	})
	UpSpeed = InfiniteFly:CreateSlider({
		Name = 'Up speed',
		Min = 1,
		Max = 25,
		Default = 5,
		Tooltip = 'How far you travel each frame while Space is held'
	})
	DownSpeed = InfiniteFly:CreateSlider({
		Name = 'Down speed',
		Min = 1,
		Max = 25,
		Default = 5,
		Tooltip = 'How far you travel each frame while LeftShift is held'
	})
	InfiniteFly:Clean(function()
		generation += 1
		cleanup()
	end)
end)
