run(function()
    local RecoveryTP
    local HealthThreshold
    local TeleportHeight
    local GroundTime
    local PlayerCheck
    local groundedSince = 0
	local trackedCharacter
	local recovered = false

	local function validCharacter()
		local character = entitylib.character
		if not entitylib.isAlive or not character or not character.Character or not character.Character.Parent then return end
		local humanoid, root = character.Humanoid, character.RootPart
		if not humanoid or humanoid.Health <= 0 or not root or not root.Parent then return end
		return character, humanoid, root
	end

	local function playerNearby(origin)
		local list = type(entitylib.List) == 'table' and entitylib.List or {}
		for _, ent in list do
			local root = ent and ent.RootPart
			local player = ent and ent.Player
			if player and player ~= lplr and player.Parent == playersService and root and root.Parent
				and (not ent.Health or ent.Health > 0) and (root.Position - origin).Magnitude <= 50 then
				return true
			end
		end
		return false
	end

    RecoveryTP = vape.Categories.Blatant:CreateModule({
        Name = 'RecoveryTP',
        Function = function(callback)
			groundedSince, trackedCharacter, recovered = 0, nil, false
			if not callback then return end
			RecoveryTP:Clean(lplr.CharacterAdded:Connect(function(character)
				trackedCharacter, groundedSince, recovered = character, 0, false
			end))
            RecoveryTP:Clean(runService.PostSimulation:Connect(function()
				if not RecoveryTP.Enabled then return end
				local character, humanoid, root = validCharacter()
				if not character then groundedSince, recovered = 0, false return end
				if trackedCharacter ~= character.Character then
					trackedCharacter, groundedSince, recovered = character.Character, 0, false
				end
				if humanoid.Health >= HealthThreshold.Value then groundedSince, recovered = 0, false return end
				if recovered then return end
				local ownsRoot = false
				pcall(function() ownsRoot = isnetworkowner(root) end)
				if not ownsRoot then groundedSince = 0 return end
				if PlayerCheck.Enabled and not playerNearby(root.Position) then groundedSince = 0 return end
				if humanoid.FloorMaterial == Enum.Material.Air then groundedSince = 0 return end
                local now = tick()
                if groundedSince == 0 then groundedSince = now return end
				if now - groundedSince < GroundTime.Value then return end
				groundedSince, recovered = 0, true
				root.CFrame = CFrame.new(root.Position.X, TeleportHeight.Value, root.Position.Z) * root.CFrame.Rotation
                root.AssemblyLinearVelocity = Vector3.zero
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            end))
        end,
        Tooltip = 'Teleports you to a safe height when your health is critical'
    })
    HealthThreshold = RecoveryTP:CreateSlider({Name = 'Health threshold', Min = 1, Max = 99, Default = 35, Suffix = ' HP'})
    TeleportHeight = RecoveryTP:CreateSlider({Name = 'Safe height', Min = 80, Max = 300, Default = 180, Suffix = ' studs'})
    GroundTime = RecoveryTP:CreateSlider({Name = 'Ground time', Min = 0.1, Max = 3, Default = 0.5, Decimal = 100, Suffix = ' seconds'})
    PlayerCheck = RecoveryTP:CreateToggle({
        Name = 'Player check',
        Tooltip = 'Only teleports while a player is within 50 studs'
    })
end)