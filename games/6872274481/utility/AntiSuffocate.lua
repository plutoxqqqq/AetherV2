run(function()
    local AntiSuffocate
    local Mode

    -- Burial check. Push mode needs the player fully buried (body plus the
    -- cells above and below) before nudging, but TP mode must also fire when
    -- only part of the body is inside a block - most importantly legs-only
    -- suffocation, where the body/head cells are still free.
    local function isSolidBlock(block)
		return block and block:IsA('BasePart') and block.CanCollide and block.CanQuery
			and block.Transparency < 1 and block.Size.Magnitude > 0
	end

    local function isSuffocating(root, mode)
        local body = getPlacedBlock(root.Position)
        local head = getPlacedBlock(root.Position + Vector3.new(0, 2, 0))
        local legs = getPlacedBlock(root.Position - Vector3.new(0, 2, 0))
		body, head, legs = isSolidBlock(body), isSolidBlock(head), isSolidBlock(legs)
        if mode == 'TP' then
            return (body or legs) and true or false
        end
        return (body and head and legs) and true or false
    end

    -- TP mode: pop straight up to the top of the block column we are stuck in so our
    -- feet rest on the highest ground with nothing above our head.
    local function teleportOut(root)
        local hip = entitylib.character.HipHeight or 2.5
        local base = root.Position
        for step = 1, 26 do
            local probe = base + Vector3.new(0, step, 0)
            local ground = getPlacedBlock(probe - Vector3.new(0, 2, 0))
            if isSolidBlock(ground) and not isSolidBlock(getPlacedBlock(probe)) and not isSolidBlock(getPlacedBlock(probe + Vector3.new(0, 2, 0))) then
                local topY = ground.Position.Y + ground.Size.Y / 2
                root.CFrame = CFrame.new(base.X, topY + hip + 0.1, base.Z) * root.CFrame.Rotation
                root.AssemblyLinearVelocity = Vector3.zero
                return true
            end
        end
    end

    AntiSuffocate = vape.Categories.Utility:CreateModule({
	Name = 'AntiSuffocate',
	Function = function(call)
		if call then
			repeat
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					if isSuffocating(root, Mode.Value) then
						if Mode.Value == 'TP' then
							teleportOut(root)
						else
							root.CFrame += Vector3.new(0, 0.5, 0)
							if root.AssemblyLinearVelocity.Y < -1 then
								root.AssemblyLinearVelocity = Vector3.zero
							end
						end
					end
				end
				task.wait()
			until not AntiSuffocate.Enabled
		end
	end,
	Tooltip = 'Prevents you from suffocating in blocks',
    })
    Mode = AntiSuffocate:CreateDropdown({
	Name = 'Mode',
	List = {'Push', 'TP'},
	Default = 'Push',
	Tooltip = 'Push nudges you up while fully buried. TP jumps you to the top and also fires on partial burials'
    })
end)