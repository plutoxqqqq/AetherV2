run(function()
	local AntiMagma

	-- Magma kills through a TouchTransmitter parented under the magma part, so removing the
	-- transmitter is enough to make the part inert while leaving the world itself untouched.
	-- Both the one-shot scan and the two added connections matter: the map is streamed in and the
	-- Blocks folder keeps receiving parts after the player has already landed next to magma.
	local function disableMagmaPart(v)
		if not v:IsA('BasePart') then return end
		if not string.find(string.lower(v.Name), 'magma') then return end
		for _, stuff in v:GetDescendants() do
			if stuff:IsA('TouchTransmitter') then
				pcall(function() stuff:Destroy() end)
			end
		end
	end

	AntiMagma = vape.Categories.World:CreateModule({
		Name = 'AntiMagma',
		Tooltip = 'Prevent magma from instantly killing you',
		Function = function(callback)
			if callback then
				scanDescendants(workspace, disableMagmaPart, AntiMagma)

				AntiMagma:Clean(workspace.DescendantAdded:Connect(function(v)
					disableMagmaPart(v)
				end))

				local worldFolder = getWorldFolder()
				if not worldFolder then return end
				-- getWorldFolder only answers with a folder that already holds Blocks, so this is a
				-- lookup rather than a wait: yielding here would stall the toggle for a second.
				local blocks = worldFolder:FindFirstChild('Blocks')
				if not blocks then return end
				AntiMagma:Clean(blocks.ChildAdded:Connect(function(v)
					disableMagmaPart(v)
				end))
			end
		end
	})
end)
