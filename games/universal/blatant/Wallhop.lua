run(function()
	local Wallhop
	local Offset
	local Mode
	local CameraTime
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	local cameraRestore
	local cameraTurn
	local timeout = 0

	local function updateCamera()
		if cameraRestore then
			gameCamera.CFrame = CFrame.new(
				gameCamera.CFrame.Position.X,
				gameCamera.CFrame.Position.Y,
				gameCamera.CFrame.Position.Z,
				unpack(cameraRestore, 4, cameraRestore.n)
			)
			cameraRestore = nil
		end
		if not cameraTurn then return false end

		local alpha = math.clamp((os.clock() - cameraTurn.StartedAt) / cameraTurn.Duration, 0, 1)
		-- Ease in and out so the turn has no visible snap at either end.  Apply only the
		-- incremental yaw, which preserves both the live camera position and player input.
		local progress = alpha * alpha * (3 - (2 * alpha))
		local delta = progress - cameraTurn.Progress
		if delta ~= 0 then
			gameCamera.CFrame *= CFrame.Angles(0, math.rad(cameraTurn.Offset * delta), 0)
			cameraTurn.Progress = progress
		end
		if alpha >= 1 then cameraTurn = nil end
		return cameraTurn ~= nil
	end

	local function doCheck()
		if updateCamera() then return end

		if not entitylib.isAlive then
			return
		end

		local hum = entitylib.character.Humanoid
		local root = entitylib.character.RootPart
		if hum.MoveDirection.Magnitude <= 0 then
			return
		end
		if root.AssemblyLinearVelocity.Y >= 0 or hum.FloorMaterial ~= Enum.Material.Air then
			return
		end

		params.CollisionGroup = root.CollisionGroup
		params.FilterDescendantsInstances = { lplr.Character }

		local parts = workspace:GetPartBoundsInBox(
			CFrame.new(root.Position - Vector3.new(0, entitylib.character.HipHeight / 2, 0)),
			Vector3.new(3, entitylib.character.HipHeight, 3),
			params
		)
		local wall = false

		for _, part in parts do
			if part:IsA('BasePart') and part.CanCollide then
				local pos = part:GetClosestPointOnSurface(root.Position)
				if root.Position.Y - pos.Y > root.Size.Y / 2 then
					wall = true
					break
				end
			end
		end

		if wall and os.clock() - timeout > 0.2 then
			-- The original logic only rotated the camera. Actually request a jump here.
			hum.Jump = true
			hum:ChangeState(Enum.HumanoidStateType.Jumping)

			if Mode.Value == 'Legit' then
				cameraTurn = {
					StartedAt = os.clock(),
					Duration = math.max(CameraTime.Value, 0.01),
					Offset = Offset.Value,
					Progress = 0
				}
			else
				cameraRestore = table.pack(gameCamera.CFrame:GetComponents())
				gameCamera.CFrame *= CFrame.Angles(0, math.rad(Offset.Value), 0)
			end
			timeout = os.clock()
		end
	end

	Wallhop = vape.Categories.Blatant:CreateModule({
		Name = 'Wallhop',
		Function = function(callback)
			if callback then
				if workspace.AuthorityMode == Enum.AuthorityMode.Server then
					Wallhop:Clean(runService:BindToSimulation(doCheck))
				else
					Wallhop:Clean(runService.RenderStepped:Connect(doCheck))
				end
			else
				cameraRestore = nil
				cameraTurn = nil
			end
		end,
		Tooltip = 'Automatically jumps and rotates the camera for wallhopping.'
	})

	Offset = Wallhop:CreateSlider({
		Name = 'Offset',
		Min = -45,
		Max = 45,
		Default = 45,
		Suffix = 'degrees'
	})
	Mode = Wallhop:CreateDropdown({
		Name = 'Mode',
		List = {'Instant', 'Legit'},
		Default = 'Instant',
		Function = function(value)
			if CameraTime and CameraTime.Object then CameraTime.Object.Visible = value == 'Legit' end
			if value ~= 'Legit' then cameraTurn = nil end
		end,
		Tooltip = 'Instant applies the offset for one frame. Legit turns the camera over the selected time.'
	})
	CameraTime = Wallhop:CreateSlider({
		Name = 'Camera Time',
		Min = 0.05,
		Max = 2,
		Default = 0.25,
		Decimal = 100,
		Suffix = 's',
		Visible = false,
		Tooltip = 'How long Legit mode takes to reach the wallhop camera angle.'
	})
end)
