run(function()
	local MotionBlur
	local MotionBlurStrength
	local motionBlurEffect = nil
	local lastLookVector = gameCamera.CFrame.LookVector
	local motionBlurConn = nil

	MotionBlur = vape.Categories.Legit:CreateModule({
		Name = 'MotionBlur',
		Function = function(callback)
			if callback then
				motionBlurEffect = Instance.new('BlurEffect')
				motionBlurEffect.Size = 0
				motionBlurEffect.Parent = gameCamera
				motionBlurConn = runService.RenderStepped:Connect(function()
					local currentLook = gameCamera.CFrame.LookVector
					local delta = (currentLook - lastLookVector).Magnitude
					lastLookVector = currentLook
					local targetSize = math.clamp(delta * (MotionBlurStrength.Value * 20), 0, 24)
					motionBlurEffect.Size = motionBlurEffect.Size + (targetSize - motionBlurEffect.Size) * 0.3
				end)
			else
				if motionBlurConn then
					motionBlurConn:Disconnect()
					motionBlurConn = nil
				end
				if motionBlurEffect then
					motionBlurEffect:Destroy()
					motionBlurEffect = nil
				end
			end
		end,
	})

	MotionBlurStrength = MotionBlur:CreateSlider({
		Name = 'Strength',
		Min = 0,
		Max = 10,
		Default = 3,
		Decimal = 10,
	})
end)