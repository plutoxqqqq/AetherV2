run(function()
	local Spider
	local SpiderShift = false
    local Mode
    local Animation
    local Value
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local Active, Truss, Loaded

    local climbAnimation = Instance.new('Animation')
    climbAnimation.AnimationId = 'rbxassetid://11344417710'

    Spider = vape.Categories.Blatant:CreateModule({
	Name = 'Spider',
	Function = function(callback)
		if callback then
			if Truss then
				Truss.Parent = gameCamera
			end

			Spider:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local chars = { gameCamera, lplr.Character, Truss }
					for _, v in entitylib.List do
						table.insert(chars, v.Character)
					end
					SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
					rayCheck.FilterDescendantsInstances = chars
					rayCheck.CollisionGroup = root.CollisionGroup

                        local dir, stop = entitylib.character.Humanoid.MoveDirection, false
                        if dir.Magnitude <= 0 then
                            dir, stop = root.CFrame.LookVector, true
                        end
                        local vec = dir * 2.5
                        local ray = workspace:Raycast(
                            root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0),
                            vec,
                            rayCheck
                        )
                        if Active then
                            if not Loaded and Animation.Enabled then
                                Loaded = entitylib.character.Humanoid:LoadAnimation(climbAnimation)
                                Loaded:Play()
                            end
                            if Loaded then
                                Loaded:AdjustSpeed((not stop) and 2 or 0)
                            end
                            -- Only cancel downward velocity while actively climbing (to stop
                            -- overshoot once we reach the top). When there is no movement input
                            -- (stop) we must NOT zero the Y velocity, otherwise the player just
                            -- hovers/slides down the wall very slowly while stuck in the falling
                            -- animation. Letting gravity through makes idle descent feel normal.
                            if not ray and not stop then
                                root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
                            end
                        end

                        Active = ray
                        if Active and ray.Normal.Y == 0 and not stop then
                            if not (vape.Modules.Phase and vape.Modules.Phase.Enabled) or not SpiderShift then
                                if Animation.Enabled then
                                    entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                                end

                                root.Velocity *= Vector3.new(1, 0, 1)
                                if Mode.Value == 'CFrame' then
                                    root.CFrame += Vector3.new(0, Value.Value * dt, 0)
                                elseif Mode.Value == 'Impulse' then
                                    root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
                                else
                                    root.Velocity += Vector3.new(0, Value.Value, 0)
                                end
                            end
                        elseif not Active then
                            if Loaded then
                                Loaded:Stop()
                            end
                            Loaded = nil
                        end
                    else
                        if Loaded then
                            Loaded:Stop()
                        end
                        Loaded = nil
				end
			end))
		else
			if Truss then
				Truss.Parent = nil
			end
                if Loaded then
                    Loaded:Stop()
                end
                Loaded = nil
			SpiderShift = false
		end
	end,
	Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)',
    })
    Mode = Spider:CreateDropdown({
	Name = 'Mode',
	List = {'Velocity', 'Impulse', 'CFrame'},
	Function = function(val)
		Value.Object.Visible = val ~= 'Part'
            if Truss then
			Truss:Destroy()
			Truss = nil
		end
		if val == 'Part' then
			Truss = Instance.new('TrussPart')
			Truss.Size = Vector3.new(2, 2, 2)
			Truss.Transparency = 1
			Truss.Anchored = true
			Truss.Parent = Spider.Enabled and gameCamera or nil
		end
	end,
	Tooltip = 'Velocity - smooth boost up\nCFrame - moves you up\nPart - a climbable part in front of you',
    })
    Value = Spider:CreateSlider({
	Name = 'Speed',
	Min = 0,
	Max = 100,
	Default = 30,
	Darker = true,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    Animation = Spider:CreateToggle({
        Name = 'Use bedwars climbing',
        Tooltip = 'Makes you look like you are climbing with a kit (e.g. Yamini)'
    })
end)