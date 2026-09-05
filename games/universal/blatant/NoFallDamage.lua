run(function()
    local NoFallDamage
    local Mode
    local hook
    local spoofFalling = false
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    rayCheck.RespectCanCollide = true

    local function removeHook()
	spoofFalling = false
	if hook then
		pcall(raknet.remove_send_hook, hook)
		hook = nil
	end
    end

    local function installHook()
	if hook then return true end
	if not rakNetCheck('NoFallDamage') then return false end
	hook = function(packet)
		if not spoofFalling then return end
		pcall(function()
			local data = packet.AsBuffer
			local packetId = packet.AsArray and packet.AsArray[1]
			if not packetId and data and buffer.len(data) > 0 then packetId = buffer.readu8(data, 0) end
			if packetId == 0x1b and data and buffer.len(data) >= 26 then
				buffer.writeu8(data, 25, Enum.HumanoidStateType.Landed.Value + 32)
				packet:SetData(data)
			end
		end)
	end
	raknet.add_send_hook(hook)
	return true
    end

    local function standClearance(character)
	return character.HipHeight
		or ((character.Humanoid and character.Humanoid.HipHeight or 2) + (character.RootPart.Size.Y * 0.5))
    end

    local function groundBelow(character, distance)
	local root = character.RootPart
	rayCheck.FilterDescendantsInstances = {character.Character, gameCamera}
	pcall(function() rayCheck.CollisionGroup = root.CollisionGroup end)
	local result = workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), rayCheck)
	return result and result.Normal.Y > 0.15 and result or nil
    end

    NoFallDamage = vape.Categories.Blatant:CreateModule({
	Name = 'NoFallDamage',
	Function = function(callback)
		if callback then
			if Mode.Value == 'State' and not installHook() then
				NoFallDamage:Toggle()
				return
			end

			NoFallDamage:Clean(runService.PostSimulation:Connect(function()
				if not entitylib.isAlive then
					spoofFalling = false
					return
				end

				local character = entitylib.character
				local root, humanoid = character.RootPart, character.Humanoid
				local velocity = root.AssemblyLinearVelocity
				local falling = humanoid.FloorMaterial == Enum.Material.Air and velocity.Y < -1
				spoofFalling = Mode.Value == 'State' and falling
				if not falling or Mode.Value == 'State' or velocity.Y > -20 then return end

				local ground = groundBelow(character, 2000)
				if not ground then return end
				local floorY = ground.Position.Y + standClearance(character)
				local remaining = root.Position.Y - floorY
				if remaining <= 1 then return end

				if Mode.Value == 'TP' and velocity.Y <= -55 then
					character.Character:PivotTo(root.CFrame - Vector3.new(0, remaining, 0))
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
					humanoid:ChangeState(Enum.HumanoidStateType.Landed)
				elseif Mode.Value == 'Velocity' and velocity.Y <= -45 then
					local impactTime = remaining / math.max(math.abs(velocity.Y), 1)
					if remaining <= 8 or impactTime <= 0.2 then
						root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, -18), velocity.Z)
					end
				end
			end))
		else
			removeHook()
		end
	end,
	ExtraText = function() return Mode.Value end,
	Tooltip = 'Prevents universal fall damage with a ground teleport, impact slowdown, or landed-state spoof',
    })
    Mode = NoFallDamage:CreateDropdown({
	Name = 'Mode',
	List = {'TP', 'Velocity', 'State'},
	Default = 'TP',
	Function = function()
		if NoFallDamage.Enabled then
			NoFallDamage:Toggle()
			NoFallDamage:Toggle()
		end
	end,
    })
    vape:Clean(removeHook)
end)