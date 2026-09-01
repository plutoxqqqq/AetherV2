run(function()
	local Wallhop
	local Offset
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	local cameraRestore
	local timeout = 0

	local function doCheck()
		if cameraRestore then
			gameCamera.CFrame = CFrame.new(
				gameCamera.CFrame.Position.X,
				gameCamera.CFrame.Position.Y,
				gameCamera.CFrame.Position.Z,
				unpack(cameraRestore, 4, cameraRestore.n)
			)
			cameraRestore = nil
		end

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

			cameraRestore = table.pack(gameCamera.CFrame:GetComponents())
			gameCamera.CFrame *= CFrame.Angles(0, math.rad(Offset.Value), 0)
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
end)