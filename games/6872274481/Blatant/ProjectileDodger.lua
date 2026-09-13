run(function()
	local ProjectileDodger
	local Range
	local Strength
	local Mode
	local TeleportDistance
	local EdgeCheck

	local projectiles = {}
	local history = {}
	local dodgeUntil = 0
	local dodgeDirection = Vector3.zero

	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getPart(obj)
		return obj:IsA('BasePart') and obj or obj.PrimaryPart
	end

	local function isProjectile(obj)
		local shooter = obj:GetAttribute('ProjectileShooter')
		return shooter and shooter ~= lplr.UserId and getPart(obj)
	end

	local function getVelocity(obj, part)
		local now = os.clock()
		local old = history[obj]
		local velocity = part.AssemblyLinearVelocity

		if velocity.Magnitude < 2 and old then
			local elapsed = now - old.time
			if elapsed > 0 then
				velocity = (part.Position - old.position) / elapsed
			end
		end

		history[obj] = {
			position = part.Position,
			time = now,
			velocity = velocity
		}

		return velocity
	end

	local function hasGround(position)
		if not EdgeCheck.Enabled then return true end

		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
		return workspace:Raycast(
			position + Vector3.new(0, 2, 0),
			Vector3.new(0, -14, 0),
			rayCheck
		) ~= nil
	end

	local function getSafeDirection(root, direction)
		direction = Vector3.new(direction.X, 0, direction.Z)

		if direction.Magnitude < 0.01 then
			direction = root.CFrame.RightVector
		else
			direction = direction.Unit
		end

		if hasGround(root.Position + direction * 6) then
			return direction
		end

		if hasGround(root.Position - direction * 6) then
			return -direction
		end
	end

	local function getIncoming(obj, root)
		local part = getPart(obj)
		if not part then return end

		local offset = root.Position - part.Position
		local distance = offset.Magnitude

		if distance > math.max(Range.Value, 70) then return end

		local velocity = getVelocity(obj, part)
		if velocity.Magnitude < 2 then return end

		local direction = velocity.Unit
		local closing = direction:Dot(offset.Unit)

		if closing <= 0 then return end

		local time = distance / math.max(velocity.Magnitude * closing, 0.01)
		time = math.clamp(time, 0, 1.4)

		local meta = bedwars.ProjectileMeta[obj.Name]
		local gravity = meta and meta.gravitationalAcceleration or workspace.Gravity

		local predicted = part.Position
			+ velocity * time
			- Vector3.new(0, 0.5 * gravity * time * time, 0)

		local missDistance = (predicted - root.Position).Magnitude

		if missDistance >= 12 then return end

		local side = direction:Cross(Vector3.yAxis)
		side = getSafeDirection(root, side)

		return side, time
	end

	local function teleportDodge(root, direction)
		local distance = TeleportDistance.Value * 3

		for _, side in {direction, -direction} do
			local target = root.Position + side * distance

			if hasGround(target) then
				root.CFrame = CFrame.new(target, target + root.CFrame.LookVector)
				root.AssemblyLinearVelocity = Vector3.new(
					0,
					root.AssemblyLinearVelocity.Y,
					0
				)
				return true
			end
		end

		return false
	end

	ProjectileDodger = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileDodger',
		Function = function(callback)
			if callback then
				table.clear(projectiles)
				table.clear(history)

				for _, obj in workspace:GetChildren() do
					if isProjectile(obj) then
						projectiles[obj] = true
					end
				end

				ProjectileDodger:Clean(workspace.ChildAdded:Connect(function(obj)
					if isProjectile(obj) then
						projectiles[obj] = true
					end
				end))

				ProjectileDodger:Clean(runService.PostSimulation:Connect(function(dt)
					if Mode.Value ~= 'Legit' or os.clock() >= dodgeUntil then
						return
					end

					if not entitylib.isAlive then return end

					local root = entitylib.character.RootPart
					if not root then return end

					local speed = math.clamp(Strength.Value, 10, 80)
					local movement = dodgeDirection * speed * dt
					local nextPosition = root.Position + movement

					if not hasGround(nextPosition) then
						dodgeUntil = 0
						dodgeDirection = Vector3.zero
						return
					end

					root.CFrame += movement
				end))

				repeat
					if entitylib.isAlive and os.clock() >= dodgeUntil then
						local root = entitylib.character.RootPart

						if root then
							local bestDirection
							local bestTime = math.huge
							local bestProjectile

							for projectile in projectiles do
								if not projectile.Parent then
									projectiles[projectile] = nil
									history[projectile] = nil
									continue
								end

								local direction, time = getIncoming(projectile, root)

								if direction and time < bestTime then
									bestDirection = direction
									bestTime = time
									bestProjectile = projectile
								end
							end

							local ping = 0
							pcall(function()
								ping = lplr:GetNetworkPing()
							end)

							local reactionWindow = Mode.Value == 'Teleport'
								and math.min(ping * 1.4 + 0.45, 0.9)
								or math.min(ping + 0.45, 0.6)

							if bestDirection and bestTime <= reactionWindow then
								if Mode.Value == 'Teleport' then
									if teleportDodge(root, bestDirection) then
										dodgeUntil = os.clock() + math.clamp(bestTime, 0.12, 0.35)
									end
								else
									dodgeDirection = bestDirection
									dodgeUntil = os.clock() + math.clamp(bestTime + 0.15, 0.25, 0.6)
								end
							end
						end
					end

					task.wait()
				until not ProjectileDodger.Enabled
			else
				table.clear(projectiles)
				table.clear(history)

				dodgeUntil = 0
				dodgeDirection = Vector3.zero
			end
		end,

		Tooltip = 'Dodges incoming projectiles without stepping off edges'
	})

	Range = ProjectileDodger:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 80,
		Default = 45,
		Suffix = ' studs'
	})

	Mode = ProjectileDodger:CreateDropdown({
		Name = 'Mode',
		List = {'Teleport', 'Legit'},
		Default = 'Teleport',
		Function = function(value)
			TeleportDistance.Object.Visible = value == 'Teleport'
			Strength.Object.Visible = value == 'Legit'
		end
	})

	TeleportDistance = ProjectileDodger:CreateSlider({
		Name = 'Teleport Distance',
		Min = 1,
		Max = 2,
		Default = 2,
		Decimal = 1,
		Suffix = ' blocks'
	})

	Strength = ProjectileDodger:CreateSlider({
		Name = 'Dodge Strength',
		Min = 10,
		Max = 80,
		Default = 38,
		Suffix = ' studs',
		Visible = false
	})

	EdgeCheck = ProjectileDodger:CreateToggle({
		Name = 'Edge Check',
		Default = true
	})
end)