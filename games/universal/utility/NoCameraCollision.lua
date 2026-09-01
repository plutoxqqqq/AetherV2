run(function()
    local NoCameraCollision
    local Mode
    local originalMode
    local renderName = 'AetherNoCameraCollision'
    local distance = 12
    local manualInput
    local cameraModule
    local nextCameraLookup = 0
    local firstPersonDistance = 1

    local function stopManual()
		runService:UnbindFromRenderStep(renderName)
		if manualInput then
			manualInput:Disconnect()
			manualInput = nil
		end
		cameraModule = nil
		nextCameraLookup = 0
	end

    local function getCameraController()
		if cameraModule then return cameraModule.activeCameraController end
		if os.clock() < nextCameraLookup then return end
		nextCameraLookup = os.clock() + 2

		pcall(function()
			local playerScripts = lplr:FindFirstChild('PlayerScripts')
			local playerModuleScript = playerScripts and playerScripts:FindFirstChild('PlayerModule')
			if not playerModuleScript then return end
			local playerModule = require(playerModuleScript)
			if type(playerModule.GetCameras) == 'function' then
				cameraModule = playerModule:GetCameras()
			end
		end)
		return cameraModule and cameraModule.activeCameraController
    end

    local function getCameraDistance()
		local controller = getCameraController()
		local firstPerson = lplr.CameraMode == Enum.CameraMode.LockFirstPerson
		local controllerDistance
		if controller then
			local success, value = pcall(function()
				firstPerson = firstPerson or controller.inFirstPerson == true
				return controller:GetCameraToSubjectDistance()
			end)
			if success and type(value) == 'number' and value == value and value < math.huge then
				controllerDistance = value
			end
		end
		return controllerDistance or distance, firstPerson
    end

    local function startManual()
		stopManual()
		distance = math.clamp((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude, 0.5, lplr.CameraMaxZoomDistance)
		manualInput = inputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				distance = math.clamp(distance - input.Position.Z * math.max(distance * 0.15, 1), 0.5, lplr.CameraMaxZoomDistance)
			end
		end)
		runService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
			-- Roblox updates character transparency from its own zoom state before this
			-- callback. Respect that state in first person instead of moving an already
			-- hidden character back into third person.
			local cameraDistance, firstPerson = getCameraDistance()
			distance = math.clamp(cameraDistance, 0.5, lplr.CameraMaxZoomDistance)
			if firstPerson or distance <= firstPersonDistance or gameCamera.CameraType == Enum.CameraType.Scriptable then return end
			local focus, look = gameCamera.Focus, gameCamera.CFrame.LookVector
			gameCamera.CFrame = CFrame.lookAlong(focus.Position - look * distance, look)
		end)
	end

    local function applyMode()
		stopManual()
		local success = pcall(function()
			lplr.DevCameraOcclusionMode = Mode.Value == 'Manual' and Enum.DevCameraOcclusionMode.Zoom or Enum.DevCameraOcclusionMode.Invisicam
		end)
		if success and Mode.Value == 'Manual' then startManual() end
		return success
    end

    NoCameraCollision = vape.Categories.Utility:CreateModule({
	Name = 'NoCameraCollision',
	Function = function(callback)
	    if callback then
		local success, currentMode = pcall(function() return lplr.DevCameraOcclusionMode end)
		if not success then
		    notif('NoCameraCollision', 'Camera occlusion mode is unavailable in this game.', 5, 'warning')
		    NoCameraCollision:Toggle()
		    return
		end
		originalMode = originalMode or currentMode
		NoCameraCollision:Clean(stopManual)
		if not applyMode() then
		    notif('NoCameraCollision', 'Camera occlusion mode is unavailable in this game.', 5, 'warning')
		    NoCameraCollision:Toggle()
		    return
		end
	    else
		stopManual()
		if originalMode then
		pcall(function() lplr.DevCameraOcclusionMode = originalMode end)
		originalMode = nil
		end
	    end
	end,
	Tooltip = 'Prevents walls from forcing the third-person camera to zoom in'
    })
    Mode = NoCameraCollision:CreateDropdown({
	Name = 'Mode',
	List = {'Manual', 'Invisicam'},
	Tooltip = 'Manual bypasses camera collision without making obstructing blocks transparent',
	Function = function()
		if NoCameraCollision.Enabled and not applyMode() then
			notif('NoCameraCollision', 'Camera occlusion mode is unavailable in this game.', 5, 'warning')
			NoCameraCollision:Toggle()
		end
	end
    })
end)