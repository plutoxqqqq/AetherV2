run(function()
	local DaveyAim
	local Mode
	local Position
	local Range
	local LaunchCannon
	local ShowTarget
	local PlaceCannon
	local LandingColor
	local SafeLand
	local nextCannonPlacement = 0

	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local aimRayCheck = RaycastParams.new()
	aimRayCheck.FilterType = Enum.RaycastFilterType.Exclude
	aimRayCheck.RespectCanCollide = true
	local safeLandingRayCheck = RaycastParams.new()
	safeLandingRayCheck.FilterType = Enum.RaycastFilterType.Exclude
	safeLandingRayCheck.RespectCanCollide = true

	local function getLaunchVelocity(delta, velocity, time)
		return (delta + Vector3.new(0, workspace.Gravity * time * time * 0.5, 0)) / time - velocity
	end

	local function softenLanding(root)
		local velocity = root.AssemblyLinearVelocity
		if velocity.Y < 0 then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		end
	end

	local function getCannon()
		local cannons = {}
		local localPosition = entitylib.character.RootPart.Position
		for _, v in store.blocks do
			if v.Name == 'cannon' and (localPosition - v.Position).Magnitude <= Range.Value then
				table.insert(cannons, v)
			end
		end
		if #cannons > 1 then
			table.sort(cannons, function(a, b)
				return (localPosition - a.Position).Magnitude < (localPosition - b.Position).Magnitude
			end)
		end
		return cannons[1] or nil
	end

	local function placeCannon()
		if tick() < nextCannonPlacement or not entitylib.isAlive then return nil end
		local item = getItem('cannon')
		if not (item and item.tool and item.tool.Parent) then return nil end
		local root = entitylib.character.RootPart
		local foot = entitylib.character.HipHeight + (root.Size.Y / 2) - 3
		local base = roundPos(root.Position - Vector3.new(0, foot, 0))
		local candidates = {base, base + Vector3.new(3, 0, 0), base + Vector3.new(-3, 0, 0), base + Vector3.new(0, 0, 3), base + Vector3.new(0, 0, -3)}
		local target
		for _, position in candidates do
			if not getPlacedBlock(position) and getPlacedBlock(position - Vector3.new(0, 3, 0)) and (position - root.Position).Magnitude <= Range.Value then
				target = position
				break
			end
		end
		if not target then return nil end
		nextCannonPlacement = tick() + 1.5
		local slot, previous = getHotbar(item.tool), store.inventory.hotbarSlot
		if slot ~= nil then pcall(hotbarSwitch, slot) end
		pcall(switchItem, item.tool, 0.1)
		pcall(bedwars.placeBlock, target, 'cannon')
		if previous ~= nil then pcall(hotbarSwitch, previous) end
		local deadline = tick() + 1.5
		repeat
			local block = getPlacedBlock(target)
			if block and block.Parent and block.Name == 'cannon' then return block end
			task.wait(0.05)
		until tick() >= deadline or not entitylib.isAlive
		return nil
	end

	local function isPathBlocked(origin, velocity, time)
		local previous = origin

		for i = 1, 11 do
			local elapsed = time * i / 12
			local point = origin + velocity * elapsed - Vector3.new(0, workspace.Gravity * elapsed * elapsed * 0.5, 0)
			if workspace:Spherecast(previous, 2, point - previous, rayCheck) then
				return true
			end
			previous = point
		end

		return false
	end

	local function getLaunchTime(origin, delta, velocity, ceiling)
		local low, up = 0.0001, 20

		for _ = 1, 50 do
			local first, second = low + (up - low) / 3, up - (up - low) / 3
			if getLaunchVelocity(delta, velocity, first).Magnitude < getLaunchVelocity(delta, velocity, second).Magnitude then
				up = second
			else
				low = first
			end
		end

		local middle = (low + up) / 2
		if getLaunchVelocity(delta, velocity, middle).Magnitude > ceiling then return end
		if not isPathBlocked(origin, getLaunchVelocity(delta, Vector3.zero, middle), middle) then return middle end

		for i = 1, 20 do
			for _, time in {middle * (1 + i * 0.15), middle * (1 - i * 0.045)} do
				if getLaunchVelocity(delta, velocity, time).Magnitude <= ceiling and not isPathBlocked(origin, getLaunchVelocity(delta, Vector3.zero, time), time) then
					return time
				end
			end
		end

		return middle
	end

	local function findSafeLanding(aimPosition, cannon)
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end

		local ignored = {lplr.Character, gameCamera}
		if cannon then
			table.insert(ignored, cannon)
		end
		safeLandingRayCheck.FilterDescendantsInstances = ignored

		local directions = {
			Vector3.zero,
			Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
			Vector3.new(1, 0, 1).Unit, Vector3.new(1, 0, -1).Unit,
			Vector3.new(-1, 0, 1).Unit, Vector3.new(-1, 0, -1).Unit
		}
		local height = math.max(aimPosition.Y, root.Position.Y) + 72

		
		
		
		for distance = 0, 18, 3 do
			for index, direction in ipairs(directions) do
				if distance > 0 or index == 1 then
					local origin = Vector3.new(aimPosition.X, height, aimPosition.Z) + direction * distance
					local hit = workspace:Raycast(origin, Vector3.new(0, -180, 0), safeLandingRayCheck)
					local instance = hit and hit.Instance
					if hit and hit.Position.Y >= aimPosition.Y - 18 and hit.Normal.Y > 0.65 and (not instance:IsA('BasePart') or instance.CanCollide) then
						return hit
					end
				end
			end
		end
	end

	local function getAimRay(origin, direction)
		local ignored = {lplr.Character, gameCamera}
		
		
		for _, block in store.blocks do
			if block.Name == 'cannon' then table.insert(ignored, block) end
		end
		aimRayCheck.FilterDescendantsInstances = ignored
		return workspace:Raycast(origin, direction * 10000, aimRayCheck)
	end

	local function makeVisual(target, blockPosition)
		local part = Instance.new('Part')
		part.Size = Vector3.new(3, 3, 3)
		part.CFrame = CFrame.new(blockPosition)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		local selection = Instance.new('SelectionBox')
		selection.Adornee = part
		selection.LineThickness = 0.04
		selection.Color3 = Color3.new(1, 1, 1)
		selection.SurfaceColor3 = Color3.new(1, 1, 1)
		selection.SurfaceTransparency = 0.75
		selection.Parent = part
		
		
		
		local tagSize = getfontsize('Landing (000 studs)', 14, uipallet.Font, Vector2.new(1000, 1000))
		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'Tag'
		billboard.Size = UDim2.fromOffset(tagSize.X + 8, tagSize.Y + 7)
		billboard.StudsOffsetWorldSpace = (target - blockPosition) + Vector3.new(0, 2, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = part
		local tag = Instance.new('TextLabel')
		tag.Size = billboard.Size
		tag.BackgroundColor3 = Color3.new()
		tag.BackgroundTransparency = 0.5
		tag.BorderSizePixel = 0
		tag.RichText = true
		tag.FontFace = uipallet.Font
		tag.TextSize = 14
		tag.TextColor3 = Color3.fromHSV(LandingColor.Hue, LandingColor.Sat, LandingColor.Value)
		tag.Parent = billboard
		bedwars.QueryUtil:setQueryIgnored(part, true)
		part.Parent = gameCamera
		return part
	end

	local function aimCannon(cannon, direction)
		local blockPosition = bedwars.BlockController:getBlockPosition(cannon.Position)
		local aimed
		local timeout = tick() + 1

		repeat
			bedwars.Handler:Get('AimCannon'):Fire('SendToServer', {
				cannonBlockPos = blockPosition,
				lookVector = direction
			})
			task.wait(0.15)
			local look = cannon:GetAttribute('LookVector')
			aimed = look and (look - direction).Magnitude < 0.0001
		until aimed or tick() > timeout or not cannon.Parent

		return aimed
	end

	local daveyLandingGeneration = 0
	local daveyLanded = false

	local function stopDaveyHorizontal(root)
		if not root or not root.Parent then return end
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
	end

	local function getCannonLaunchSpeed()
		local speed = 200
		local controller = bedwars.CannonHandController
		if canDebug and debug and type(debug.getconstant) == 'function' and controller and type(controller.launchSelf) == 'function' then
			local ok, value = pcall(debug.getconstant, controller.launchSelf, 15)
			if ok and type(value) == 'number' and value > 0 and value < 1000 then speed = value end
		end
		return speed
	end

	local function ensureCannonMovement(cannon, launchDirection)
		local generation = daveyLandingGeneration
		task.spawn(function()
			local character = entitylib.isAlive and entitylib.character
			local root = character and character.RootPart
			if not root then return end
			local startPosition = root.Position
			local direction = launchDirection and launchDirection.Magnitude > 0.001 and launchDirection.Unit or nil
			if not direction and cannon and cannon.Parent then
				local look = cannon:GetAttribute('LookVector')
				direction = typeof(look) == 'Vector3' and look.Magnitude > 0.001 and look.Unit or cannon.CFrame.LookVector
			end
			if not direction then return end

			
			
			for _ = 1, 3 do
				runService.PreSimulation:Wait()
				if generation ~= daveyLandingGeneration or daveyLanded or not root.Parent then return end
				local velocity = root.AssemblyLinearVelocity
				if velocity:Dot(direction) > 20 or (root.Position - startPosition).Magnitude > 1 then return end
			end
			root.AssemblyLinearVelocity = direction * getCannonLaunchSpeed()
		end)
	end

	local function cancelHorizontalOnLanding()
		daveyLandingGeneration += 1
		local generation = daveyLandingGeneration
		daveyLanded = false
		task.spawn(function()
			local character = entitylib.isAlive and entitylib.character
			local humanoid = character and character.Humanoid
			local root = character and character.RootPart
			if not humanoid or not root then return end

			local startPosition = root.Position
			local armed, finished = false, false
			local floorConnection, stateConnection

			local function cleanup()
				if floorConnection then floorConnection:Disconnect(); floorConnection = nil end
				if stateConnection then stateConnection:Disconnect(); stateConnection = nil end
			end

			local function landed()
				if finished or generation ~= daveyLandingGeneration then return end
				finished = true
				daveyLanded = true
				stopDaveyHorizontal(root)
				cleanup()
				
				
				task.spawn(function()
					local settleUntil = tick() + 0.35
					repeat
						runService.PreSimulation:Wait()
						if generation ~= daveyLandingGeneration or not root.Parent then return end
						stopDaveyHorizontal(root)
					until tick() >= settleUntil
				end)
			end

			floorConnection = humanoid:GetPropertyChangedSignal('FloorMaterial'):Connect(function()
				if armed and humanoid.FloorMaterial ~= Enum.Material.Air then landed() end
			end)
			stateConnection = humanoid.StateChanged:Connect(function(_, newState)
				if armed and humanoid.FloorMaterial ~= Enum.Material.Air and (newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics) then
					landed()
				end
			end)

			local timeout = tick() + 15
			repeat
				runService.PreSimulation:Wait()
				if generation ~= daveyLandingGeneration or not entitylib.isAlive or entitylib.character ~= character or not root.Parent then
					cleanup()
					return
				end
				local velocity = root.AssemblyLinearVelocity
				local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if not armed and humanoid.FloorMaterial == Enum.Material.Air and ((root.Position - startPosition).Magnitude > 0.75 or math.abs(velocity.Y) > 8 or horizontal > 20) then
					armed = true
				end
				if armed and humanoid.FloorMaterial ~= Enum.Material.Air then landed() end
			until finished or tick() >= timeout
			cleanup()
		end)
	end

	DaveyAim = kits:CreateModule({
		Name = 'DaveyAim',
		Function = function(callback)
			if callback then
				DaveyAim:Toggle()
				if not entitylib.isAlive then return end
				local mouseRay = cloneref(lplr:GetMouse()).UnitRay
				local origin = Position.Value == 'Camera' and gameCamera.CFrame.Position or mouseRay.Origin
				local direction = Position.Value == 'Camera' and gameCamera.CFrame.LookVector or mouseRay.Direction
				local ray = getAimRay(origin, direction)
				if not ray then
					notif('DaveyAim', 'No position found.', 5, 'warning')
					return
				end

				local cannon = getCannon()
				if not cannon then
					cannon = PlaceCannon.Enabled and placeCannon() or nil
					if not cannon then
						notif('DaveyAim', PlaceCannon.Enabled and 'No legal cannon placement found.' or 'No cannon in range.', 5, 'warning')
						return
					end
				end

				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, cannon}
				if SafeLand.Enabled then
					local safeRay = findSafeLanding(ray.Position, cannon)
					if not safeRay then
						notif('DaveyAim', 'No safe landing surface was found near your aim.', 5, 'warning')
						return
					end
					ray = safeRay
				end

				local localPosition = entitylib.character.RootPart.Position
				local target = ray.Position + Vector3.new(0, entitylib.character.HipHeight, 0)
				local velocity = entitylib.character.RootPart.AssemblyLinearVelocity
				if (target - localPosition).Magnitude > 300 then
					notif('DaveyAim', `Too far away ({math.floor((target - localPosition).Magnitude)} studs away, 300 max).`, 5, 'warning')
					return
				end

				local time = getLaunchTime(localPosition, target - localPosition, velocity, math.sqrt(320 * workspace.Gravity))
				if not time then
					notif('DaveyAim', `Out of cannon range ({math.floor((target - localPosition).Magnitude)} studs away, 300 max).`, 5, 'warning')
					return
				end

				local launchDirection = getLaunchVelocity(target - localPosition, velocity, time).Unit
				local blockPosition = bedwars.BlockController:getBlockPosition(cannon.Position)
				local visual = ShowTarget.Enabled and makeVisual(target, roundPos(ray.Position - ray.Normal * 1.5)) or nil
				if visual then
					visual.Tag.TextLabel.Text = `Landing ({math.floor((target - localPosition).Magnitude)} studs)`
				end

				if Mode.Value == 'Legit' then
					cannon.AimPrompt:InputHoldBegin()
					task.wait(cannon.AimPrompt.HoldDuration)

					local timeout = tick() + 0.3
					repeat
						gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.Position, gameCamera.CFrame.Position + launchDirection), 22 * runService.PostSimulation:Wait())
						bedwars.Handler:Get('AimCannon'):Fire('SendToServer', {
							cannonBlockPos = blockPosition,
							lookVector = gameCamera.CFrame.LookVector
						})
					until tick() > timeout
				end

				if not aimCannon(cannon, launchDirection) then
					notif('DaveyAim', 'Cannon refused the aim.', 5, 'warning')
					if visual then
						visual:Destroy()
					end
					return
				end

				if Mode.Value == 'Legit' then
					cannon.StopAimingPrompt:InputHoldBegin()
				end
				task.wait((cannon.StopAimingPrompt.HoldDuration + (0.2 + store.ping.total)) + runService.PostSimulation:Wait())

				if LaunchCannon.Enabled then
					if Mode.Value == 'Legit' then
						cannon.LaunchSelfPrompt:InputHoldBegin()
						task.wait(cannon.LaunchSelfPrompt.HoldDuration + runService.PostSimulation:Wait())
					else
						bedwars.CannonHandController:launchSelf(cannon)
					end
					cancelHorizontalOnLanding()
					ensureCannonMovement(cannon, launchDirection)
				else
					local launched, aimed = false, true
					local connection = cannon.LaunchSelfPrompt.Triggered:Connect(function(plr)
						if plr == lplr then
							launched = true
							cancelHorizontalOnLanding()
							ensureCannonMovement(cannon, launchDirection)
						end
					end)
					local timeout = tick() + 30

					repeat
						runService.PostSimulation:Wait()
						local look = cannon.Parent and cannon:GetAttribute('LookVector')
						aimed = look and (look - launchDirection).Magnitude < 0.0001
					until launched or not aimed or tick() > timeout or not entitylib.isAlive

					connection:Disconnect()
					if not launched then
						if not aimed then
							notif('DaveyAim', 'Cannon was re-aimed before you launched.', 5, 'warning')
						end
						if visual then
							visual:Destroy()
						end
						return
					end
				end

				local landing = tick() + time
				local root
				repeat
					runService.PreSimulation:Wait()
					root = entitylib.isAlive and entitylib.character.RootPart
					if daveyLanded then break end
					if root then
						local remaining = landing - tick()
						if remaining > 0.03 then
							local correction = getLaunchVelocity(target - root.Position, Vector3.zero, remaining)
							root.AssemblyLinearVelocity = correction.Magnitude > 600 and correction.Unit * 600 or correction
						else
							softenLanding(root)
						end
						if visual then
							visual.Tag.TextLabel.Text = `Landing ({math.floor((target - root.Position).Magnitude)} studs)`
						end
					end
				until not root or tick() > landing or daveyLanded

				if entitylib.isAlive then
					softenLanding(entitylib.character.RootPart)
				end

				if visual then
					visual:Destroy()
				end
			end
		end,
		Tooltip = 'Aims a nearby cannon at your cursor and launches you onto it'
	})
	Mode = DaveyAim:CreateDropdown({
		Name = 'Aim Mode',
		List = {'Blatant', 'Legit'},
		Default = 'Blatant'
	})
	Position = DaveyAim:CreateDropdown({
		Name = 'Position Mode',
		List = {'Mouse', 'Camera'},
		Default = 'Mouse'
	})
	Range = DaveyAim:CreateSlider({
		Name = 'Search Range',
		Min = 1,
		Max = 18,
		Default = 10,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	LaunchCannon = DaveyAim:CreateToggle({
		Name = 'Launch Cannon',
		Default = true,
		Tooltip = 'Launches you itself, turn this off to aim only and still land on target when you launch yourself'
	})
	ShowTarget = DaveyAim:CreateToggle({
		Name = 'Show Target',
		Default = true,
		Tooltip = 'Highlights the block you are landing on until you land'
	})
	LandingColor = DaveyAim:CreateColorSlider({
		Name = 'Landing text color',
		DefaultHue = 0,
		DefaultSat = 0.001,
		DefaultValue = 1,
		Darker = true,
		Visible = function() return ShowTarget and ShowTarget.Enabled end
	})
	SafeLand = DaveyAim:CreateToggle({
		Name = 'Safe land',
		Tooltip = 'Moves the target to the nearest supported ground near your aim instead of risking a void landing'
	})
	PlaceCannon = DaveyAim:CreateToggle({
		Name = 'Place cannon',
		Tooltip = 'Places and confirms a cannon from your inventory when none is already nearby'
	})
end)
