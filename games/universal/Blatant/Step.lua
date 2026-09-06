run(function()
    local Step
    local Mode
    local StepHeight
	local ExtraHeight
    local activeTween
    local busy = false
    local nextStep = 0

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    rayCheck.RespectCanCollide = true
    local overlapCheck = OverlapParams.new()
    overlapCheck.FilterType = Enum.RaycastFilterType.Exclude
    overlapCheck.RespectCanCollide = true

    local function clearance(character)
	return character.HipHeight
		or ((character.Humanoid and character.Humanoid.HipHeight or 2) + (character.RootPart.Size.Y * 0.5))
    end

    local function findStep(character)
	local root, humanoid = character.RootPart, character.Humanoid
	local direction = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.05 or humanoid.FloorMaterial == Enum.Material.Air then return nil end
	direction = direction.Unit

	rayCheck.FilterDescendantsInstances = {character.Character, gameCamera}
	pcall(function() rayCheck.CollisionGroup = root.CollisionGroup end)
	local standHeight = clearance(character)
	local ground = workspace:Raycast(
		root.Position + Vector3.new(0, 0.5, 0),
		Vector3.new(0, -(standHeight + 3), 0),
		rayCheck
	)
	if not ground or ground.Normal.Y <= 0.15 then return nil end

	local castHeight = math.max(root.Size.Y, 2)
	local wallOrigin = root.Position - Vector3.new(0, math.max(standHeight - (castHeight * 0.5), 0), 0)
	local wall = workspace:Blockcast(
		CFrame.new(wallOrigin),
		Vector3.new(math.max(root.Size.X * 0.8, 1.4), castHeight, math.max(root.Size.Z * 0.8, 1.4)),
		direction * 2.75,
		rayCheck
	)
	if not wall or math.abs(wall.Normal.Y) > 0.25 then return nil end

	local wallNormal = wall.Normal * Vector3.new(1, 0, 1)
	if wallNormal.Magnitude < 0.1 then return nil end
	wallNormal = wallNormal.Unit
	local sample = wall.Position - (wallNormal * 0.75)
	local top = workspace:Raycast(
		Vector3.new(sample.X, ground.Position.Y + StepHeight.Value + 3, sample.Z),
		Vector3.new(0, -(StepHeight.Value + 4), 0),
		rayCheck
	)
	if not top or top.Normal.Y <= 0.15 then return nil end

	local height = top.Position.Y - ground.Position.Y
	if height <= 0.1 or height > StepHeight.Value + 0.05 then return nil end
	local landing = wall.Position - (wallNormal * (math.max(root.Size.X, root.Size.Z) * 0.55 + 0.65))
	local target = Vector3.new(landing.X, top.Position.Y + standHeight, landing.Z)

	overlapCheck.FilterDescendantsInstances = {character.Character, top.Instance}
	pcall(function() overlapCheck.CollisionGroup = root.CollisionGroup end)
	local occupied = workspace:GetPartBoundsInBox(
		CFrame.new(target),
		Vector3.new(math.max(root.Size.X * 0.85, 1.5), math.max(root.Size.Y * 0.9, 1.8), math.max(root.Size.Z * 0.85, 1.5)),
		overlapCheck
	)
	for _, part in ipairs(occupied) do
		if part.CanCollide then return nil end
	end
	return target, height
    end

    local function clearMotion()
	busy = false
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
    end

	local function jumpVelocity(height)
		return math.sqrt(2 * workspace.Gravity * math.max(height, 0.1))
	end

    Step = vape.Categories.Blatant:CreateModule({
	Name = 'Step',
	Function = function(callback)
		if callback then
			nextStep = 0
			Step:Clean(clearMotion)
			Step:Clean(runService.PreSimulation:Connect(function()
				if busy or tick() < nextStep or not entitylib.isAlive then return end
				local character = entitylib.character
				local target, height = findStep(character)
				if not target then return end

				local root, humanoid = character.RootPart, character.Humanoid
				local rotation = root.CFrame.Rotation
				nextStep = tick() + 0.2
				if Mode.Value == 'TP' then
					character.Character:PivotTo(CFrame.new(target) * rotation)
					local velocity = root.AssemblyLinearVelocity
					-- Pivoting gets the character onto the surface; the derived vertical velocity then
					-- clears its lip by the requested margin instead of relying on a fixed JumpPower
					-- that is too small for tall walls and excessive for short ones.
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, jumpVelocity(ExtraHeight.Value)), velocity.Z)
				elseif Mode.Value == 'Glide' then
					busy = true
					activeTween = tweenService:Create(
						root,
						TweenInfo.new(math.clamp(height / 18, 0.12, 0.45), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{CFrame = CFrame.new(target) * rotation}
					)
					activeTween.Completed:Once(function()
						activeTween = nil
						busy = false
					end)
					activeTween:Play()
				else
					busy = true
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					humanoid.Jump = true
					local velocity = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, jumpVelocity(height + ExtraHeight.Value), velocity.Z)
					task.delay(0.25, function() busy = false end)
				end
			end))
		else
			clearMotion()
		end
	end,
	ExtraText = function() return Mode.Value end,
	Tooltip = 'Moves onto walls only when their top is within the configured height above the real ground',
    })
    Mode = Step:CreateDropdown({
	Name = 'Mode',
	List = {'TP', 'Glide', 'Jump'},
	Default = 'TP',
	Function = function(value)
		if ExtraHeight and ExtraHeight.Object then ExtraHeight.Object.Visible = value ~= 'Glide' end
	end,
    })
    StepHeight = Step:CreateSlider({
	Name = 'Step height',
	Min = 1,
	Max = 50,
	Default = 20,
	Suffix = function(value) return value == 1 and 'stud' or 'studs' end,
    })
    ExtraHeight = Step:CreateSlider({
	Name = 'Extra height',
	Min = 0,
	Max = 15,
	Default = 5,
	Darker = true,
	Visible = function() return Mode and Mode.Value ~= 'Glide' end,
	Suffix = function(value) return value == 1 and 'stud' or 'studs' end,
	Tooltip = 'Additional apex clearance above the detected wall; jump velocity is calculated automatically',
    })
end)
