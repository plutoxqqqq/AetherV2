run(function()
    local HighJump
    local Mode
    local Value
    local AutoDisable

    local function jump()
	local state = entitylib.isAlive and Enum.HumanoidStateType.Running or nil

	if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
		local root = entitylib.character.RootPart

		if Mode.Value == 'Velocity' then
			entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			root.AssemblyLinearVelocity =
				Vector3.new(root.AssemblyLinearVelocity.X, Value.Value, root.AssemblyLinearVelocity.Z)
		elseif Mode.Value == 'Impulse' then
			entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.delay(0, function()
				root:ApplyImpulse(Vector3.new(0, Value.Value - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
			end)
		else
			local start = math.max(Value.Value - entitylib.character.Humanoid.JumpHeight, 0)
			repeat
				root.CFrame += Vector3.new(0, start * 0.016, 0)
				start = start - (workspace.Gravity * 0.016)
				if Mode.Value == 'CFrame' then
					task.wait()
				end
			until start <= 0
		end
	end
    end

    HighJump = vape.Categories.Blatant:CreateModule({
	Name = 'HighJump',
	Function = function(callback)
		if callback then
			if AutoDisable.Enabled then
				jump()
				HighJump:Toggle()
			else
				HighJump:Clean(runService.RenderStepped:Connect(function()
					if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
						jump()
					end
				end))
			end
		end
	end,
	ExtraText = function()
		return Mode.Value
	end,
	Tooltip = 'Lets you jump higher',
    })
    Mode = HighJump:CreateDropdown({
	Name = 'Mode',
	List = { 'Impulse', 'Velocity', 'CFrame', 'Instant' },
	Tooltip = 'Velocity - smooth boost up\nImpulse - the same using forces\nCFrame - moves you up\nInstant - teleport to the peak',
    })
    Value = HighJump:CreateSlider({
	Name = 'Velocity',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    AutoDisable = HighJump:CreateToggle({
	Name = 'Auto Disable',
	Default = true,
    })
end)