run(function()
	local ForcePlayerCollisions
	local Mode
	local ForceCollision

	local originals = setmetatable({}, {__mode = 'k'})
	local hitboxes = setmetatable({}, {__mode = 'k'})

	local function getBodyParts(character)
		local parts = {}

		if not character then
			return parts
		end

		for _, part in ipairs(character:GetChildren()) do
			if part:IsA('BasePart')
				and part.Name ~= 'HumanoidRootPart'
				and part.Name ~= 'Humanoid' then
				table.insert(parts, part)
			end
		end

		return parts
	end

	local function applyReal(character, state)
		if not character then return end

		for _, part in ipairs(getBodyParts(character)) do
			if originals[part] == nil then
				originals[part] = part.CanCollide
			end

			part.CanCollide = state
		end
	end

	local function restoreReal()
		for part, state in pairs(originals) do
			if part and part.Parent then
				part.CanCollide = state
			end

			originals[part] = nil
		end
	end

	local function removeHitbox(character)
		local folder = hitboxes[character]

		if folder then
			folder:Destroy()
			hitboxes[character] = nil
		end
	end

	local function createHitbox(character)
		if not character or not character.Parent then
			return
		end

		removeHitbox(character)

		local folder = Instance.new('Folder')
		folder.Name = 'PlayerCollisionHitbox'
		folder.Parent = character

		hitboxes[character] = folder

		for _, original in ipairs(getBodyParts(character)) do
			local hitbox = Instance.new('Part')
			hitbox.Name = original.Name .. '_Collision'
			hitbox.Size = original.Size
			hitbox.CFrame = original.CFrame
			hitbox.Transparency = 1
			hitbox.CanCollide = true
			hitbox.CanTouch = false
			hitbox.CanQuery = false
			hitbox.CastShadow = false
			hitbox.Massless = true
			hitbox.Anchored = false
			hitbox.Parent = folder

			local weld = Instance.new('WeldConstraint')
			weld.Part0 = hitbox
			weld.Part1 = original
			weld.Parent = hitbox
		end
	end

	local function clearHitboxes()
		for character, folder in pairs(hitboxes) do
			if folder then
				folder:Destroy()
			end

			hitboxes[character] = nil
		end
	end

	local function update()
		restoreReal()
		clearHitboxes()

		if not ForcePlayerCollisions.Enabled then
			return
		end

		for _, player in ipairs(playersService:GetPlayers()) do
			if player ~= lplr and player.Character then
				if Mode.Value == 'Real' then
					applyReal(player.Character, true)
				elseif Mode.Value == 'Hitbox' then
					createHitbox(player.Character)
				end
			end
		end
	end

	ForcePlayerCollisions = vape.Categories.World:CreateModule({
		Name = 'ForcePlayerCollisions',

		Function = function(callback)
			if callback then
				ForcePlayerCollisions:Clean(
					playersService.PlayerAdded:Connect(function(player)
						ForcePlayerCollisions:Clean(
							player.CharacterAdded:Connect(function()
								task.wait()
								update()
							end)
						)
					end)
				)

				ForcePlayerCollisions:Clean(
					runService.PreSimulation:Connect(function()
						if Mode.Value == 'Real'
							and ForceCollision.Value == 'On' then

							for _, player in ipairs(playersService:GetPlayers()) do
								if player ~= lplr and player.Character then
									applyReal(player.Character, true)
								end
							end
						end
					end)
				)

				update()
			else
				restoreReal()
				clearHitboxes()
			end
		end,

		ExtraText = function()
			return Mode.Value
		end,

		Tooltip = 'Makes other players physically collidable.'
	})

	Mode = ForcePlayerCollisions:CreateDropdown({
		Name = 'Mode',
		List = {'Real', 'Hitbox'},
		Default = 'Hitbox',
		Function = function(value)
			ForceCollision.Visible = value == 'Real'
			update()
		end
	})

	ForceCollision = ForcePlayerCollisions:CreateDropdown({
		Name = 'Force Collision',
		List = {'On', 'Off'},
		Default = 'On'
	})

	ForceCollision.Visible = Mode.Value == 'Real'
end)