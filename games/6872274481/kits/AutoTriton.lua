run(function()
	local AutoTriton
	local Legit
	local Back
	local BackDelay
	local Limit

	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local projectileRemote = {InvokeServer = function(self, ...) end}
	task.spawn(function()
		projectileRemote = bedwars.Handler:Get('ProjectileFire').Remote.instance
	end)

	local function firePearl(pos, spot, item)
		local hotbar, old = getHotbar(item.tool), store.hand

		switchItem(item.tool)
		if Legit.Enabled and hotbar then
			hotbarSwitch(hotbar)
		end

		local meta = bedwars.ProjectileMeta.harpoon_projectile
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
		local landed = false

		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'harpoon_projectile', 'harpoon_projectile', pos, nil, dir, {drawDurationSeconds = 1})
			local res = projectileRemote:InvokeServer(
				item.tool,
				'harpoon_projectile',
				'harpoon_projectile',
				pos,
				pos,
				dir,
				httpService:GenerateGUID(true),
				{
					drawDurationSeconds = 1,
					shotId = httpService:GenerateGUID(false)
				},
				workspace:GetServerTimeNow() - 0.045
			)
			task.spawn(function()
				local timeout = tick() + 10
				repeat
					task.wait()
				until not AutoTriton.Enabled or not projectile or not projectile.Parent or tick() >= timeout
				landed = true
			end)
			if res then
				pcall(function()
					res.Parent = replicatedStorage
				end)
			end
		else
			landed = true
		end

		repeat
			task.wait()
		until landed or not AutoTriton.Enabled
		if Back.Enabled and old and old.tool then
			task.wait(BackDelay:GetRandomValue())
			switchItem(old.tool)
			if Legit.Enabled and getHotbar(old.tool) then
				hotbarSwitch(getHotbar(old.tool))
			end
		end
	end

	local function findNearGround(origin)
		for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
			for i = 1, 24 do
				local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), rayCheck)
				if ray then
					return ray.Position
				end
			end
		end
		return nil
	end

	AutoTriton = kits:CreateModule({
		Name = 'AutoTriton',
		Function = function(callback)
			if callback then
				local check, lasty
				repeat
					if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'harpoon') then
						local root = entitylib.character.RootPart
						local pearl = getItem('harpoon')
						rayCheck.FilterDescendantsInstances = {store.map}
						rayCheck.CollisionGroup = root.CollisionGroup

						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							lasty = root.CFrame
						end

						if pearl and root.Velocity.Y < -60 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							if not check then
								check = true
								local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
								if ground then
									firePearl(root.Position, ground, pearl)
								end
							end
						else
							check = false
						end
					end
					task.wait(0.1)
				until not AutoTriton.Enabled
			end
		end,
		Tooltip = 'Automatically throws triton trident onto nearby ground after\nfalling a certain distance.'
	})
	Legit = AutoTriton:CreateToggle({
		Name = 'Legit Switch',
		Tooltip = 'Visualizes the switching clientside',
		Default = true
	})
	Back = AutoTriton:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Function = function(callback)
			if BackDelay then
				BackDelay.Object.Visible = callback
			end
		end,
		Tooltip = 'Switches back to the last slot before pearl'
	})
	BackDelay = AutoTriton:CreateTwoSlider({
		Name = 'Switch Back Delay',
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	Limit = AutoTriton:CreateToggle({
		Name = 'Limit to item',
		Tooltip = 'Only throws pearl when holding a pearl'
	})
end)