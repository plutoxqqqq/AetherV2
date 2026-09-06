run(function()
	local RecoveryTP
	local HealthThreshold
	local TeleportHeight
	local GroundTime
	local PlayerCheck
	local groundedSince = 0

	local function getCharacter()
		local character = entitylib.character
		if not entitylib.isAlive or not character then return end

		local humanoid = character.Humanoid
		local root = character.RootPart

		if not humanoid or not root then return end
		return humanoid, root
	end

	local function playerNearby(position)
		if not PlayerCheck.Enabled then return true end

		for _, entity in entitylib.List do
			local root = entity.RootPart
			local player = entity.Player

			if player and player ~= lplr
				and player.Parent == playersService
				and root and root.Parent
				and (not entity.Health or entity.Health > 0)
				and (root.Position - position).Magnitude <= 50 then
				return true
			end
		end

		return false
	end

	RecoveryTP = vape.Categories.Blatant:CreateModule({
		Name = 'RecoveryTP',

		Function = function(callback)
			groundedSince = 0

			if not callback then return end

			RecoveryTP:Clean(runService.PostSimulation:Connect(function()
				local humanoid, root = getCharacter()

				if not humanoid then
					groundedSince = 0
					return
				end

				if humanoid.Health >= HealthThreshold.Value then
					groundedSince = 0
					return
				end

				if not playerNearby(root.Position) then
					groundedSince = 0
					return
				end

				if humanoid.FloorMaterial == Enum.Material.Air then
					groundedSince = 0
					return
				end

				local ownsRoot = false
				pcall(function()
					ownsRoot = isnetworkowner(root)
				end)

				if not ownsRoot then
					groundedSince = 0
					return
				end

				local now = tick()

				if groundedSince == 0 then
					groundedSince = now
					return
				end

				if now - groundedSince < GroundTime.Value then
					return
				end

				groundedSince = 0

				root.CFrame = CFrame.new(
					root.Position.X,
					TeleportHeight.Value,
					root.Position.Z
				) * root.CFrame.Rotation

				root.AssemblyLinearVelocity = Vector3.zero
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end))
		end,

		Tooltip = 'Teleports you to a safe height when your health is critical'
	})

	HealthThreshold = RecoveryTP:CreateSlider({
		Name = 'Health threshold',
		Min = 1,
		Max = 99,
		Default = 35,
		Suffix = ' HP'
	})

	TeleportHeight = RecoveryTP:CreateSlider({
		Name = 'Safe height',
		Min = 80,
		Max = 300,
		Default = 180,
		Suffix = ' studs'
	})

	GroundTime = RecoveryTP:CreateSlider({
		Name = 'Ground time',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 100,
		Suffix = ' seconds'
	})

	PlayerCheck = RecoveryTP:CreateToggle({
		Name = 'Player check',
		Tooltip = 'Only teleports while a player is within 50 studs'
	})
end)