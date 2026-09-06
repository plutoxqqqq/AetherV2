run(function()
    local FakeLag
    local TransmissionOffset
    local Mode
    local Delay

    local rng
    local num = 0

    FakeLag = vape.Categories.Utility:CreateModule({
        Name = 'FakeLag',
        Function = function(callback)
            if callback then
                rng = Random.new()

                local clock, restore, after = os.clock(), os.clock(), 0
                repeat
                    local ms = Delay.Value / 1000

                    if Mode.Value == 'Dynamic' then
                        if (os.clock() - clock) >= ms or restore > os.clock() then
                            if clock ~= 9e9 then
                                
                                
                                
                                restore = os.clock() + (TransmissionOffset.Value / 1000)
                                clock = 9e9
                            end
                            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                        else
                            if clock == 9e9 then
                                clock = os.clock()
                                restore = 0
                            end
                            setfflag('PhysicsSenderMaxBandwidthBps', '0')
                        end
                    elseif Mode.Value == 'Repel' then
                        if store.update > tick() then
                            setfflag('PhysicsSenderMaxBandwidthBps', '0')
                            setfflag('S2PhysicsSenderRate', '0')
                            setfflag('DataSenderRate', '-1')
                            task.wait(rng:NextNumber(70, 150) / 1000)
                            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                            setfflag('DataSenderRate', '60')
                            setfflag('S2PhysicsSenderRate', '15')
                            after = os.clock() + rng:NextNumber(0.001, (Delay.Value / 1000))
                            store.update = 0
                            num = rng:NextNumber()
                        end
                        if os.clock() > after then
                            num = rng:NextNumber()
                            after = os.clock() + rng:NextNumber(0.001, (Delay.Value / 1000))
                        end
                    elseif Mode.Value == 'Latency' then
                        setfflag('PhysicsSenderMaxBandwidthBps', '0')
                        task.wait(Delay.Value / 1500)
                        setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                        task.wait(ms)
                    end
                    runService.PreRender:Wait()
                until not FakeLag.Enabled
            else
                setfflag('DataSenderRate', '60')
                setfflag('PhysicsSenderMaxBandwidthBps', '38760')
            end
        end,
        Tooltip = 'Delays packets, simulating lag',
        ExtraText = function()
            return Mode and Mode.Value or 'Dynamic'
        end
    })
    getgenv().FakeLag = FakeLag

    TransmissionOffset = FakeLag:CreateSlider({
        Name = 'Transmission Offset',
        Min = 1,
        Max = 10,
        Default = 3,
        Decimal = 5,
        Darker = true,
    })
    Mode = FakeLag:CreateDropdown({
        Name = 'Mode',
        List = { 'Dynamic', 'Repel', 'Latency' },
        Default = 'Dynamic',
        Function = function(val)
            TransmissionOffset.Object.Visible = val == 'Dynamic'
            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
        end,
    })
    Delay = FakeLag:CreateSlider({
        Name = 'Delay',
        Suffix = function()
            return 'ms'
        end,
        Min = 1,
        Max = 500,
        Default = 100,
    })
end)

run(function()
	local Headless
	local headlessLoop = nil

	local headAttachments = {HatAttachment=true,HairAttachment=true,FaceFrontAttachment=true,FaceCenterAttachment=true,FaceBackAttachment=true}
	local removeAccs = false

	local function applyHeadless(char)
		if not char then return end
		local head = char:FindFirstChild("Head")
		if not head then return end
		head.Transparency = 1
		local face = head:FindFirstChild('face')
		if face and face:IsA("Decal") then
			face.Transparency = 1
		end
		if removeAccs then
			for _, acc in ipairs(char:GetChildren()) do
				if acc:IsA("Accessory") then
					local handle = acc:FindFirstChild("Handle")
					if handle then
						for _, att in ipairs(handle:GetChildren()) do
							if att:IsA("Attachment") and headAttachments[att.Name] then
								handle.Transparency = 1
								for _, d in ipairs(handle:GetChildren()) do
									if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
								end
								break
							end
						end
					end
				end
			end
		end
	end

	Headless = vape.Categories.Utility:CreateModule({
		PerformanceModeBlacklisted = true,
		Name = 'Headless',
		Tooltip = 'free headless 2026!!',
		Function = function(callback)
			if callback then
				if headlessLoop then task.cancel(headlessLoop) end
				headlessLoop = task.spawn(function()
					while Headless.Enabled do
						applyHeadless(lplr.Character)
						task.wait(0.1)
					end
				end)
				Headless:Clean(lplr.CharacterAdded:Connect(function(char)
					applyHeadless(char)
				end))
			else
				if headlessLoop then
					task.cancel(headlessLoop)
					headlessLoop = nil
				end
				local char = lplr.Character
				if char then
					local head = char:FindFirstChild("Head")
					if head then
						head.Transparency = 0
						local face = head:FindFirstChild('face')
						if face and face:IsA("Decal") then
							face.Transparency = 0
						end
					end
					for _, acc in ipairs(char:GetChildren()) do
						if acc:IsA("Accessory") then
							local handle = acc:FindFirstChild("Handle")
							if handle then
								handle.Transparency = 0
								for _, d in ipairs(handle:GetChildren()) do
									if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
								end
							end
						end
					end
				end
			end
		end,
		Default = false
	})

	Headless:CreateToggle({
		Name = "Remove Accessories",
		Default = false,
		Function = function(state)
			removeAccs = state
			if Headless.Enabled then
				applyHeadless(lplr.Character)
			end
		end
	})
end)
