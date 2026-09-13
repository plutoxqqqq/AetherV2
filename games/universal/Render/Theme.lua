run(function()
    local Theme, Preset, LockTime, ClockTime, RemoveClouds, Custom
    local Brightness, Exposure, ShadowSoftness, Diffuse, Specular
    local Ambient, OutdoorAmbient, TopShift, BottomShift
    local AtmosphereEnabled, AtmosphereColor, AtmosphereDecay, Density, Offset, Glare, Haze
    local BloomEnabled, BloomIntensity, BloomSize, BloomThreshold
    local ColorEnabled, Tint, Saturation, Contrast, ColorBrightness
    local RaysEnabled, RaysIntensity, RaysSpread, DepthEnabled, FarIntensity, FocusDistance, NearIntensity
    local CloudsEnabled, CloudCover, CloudDensity, CloudColor, CloudSize, CloudTransparency
    local GlobalShadows, Latitude, Technology
    local SkyEnabled, Skybox, SunTexture, MoonTexture, Stars, SunSize, MoonSize
    local WaterColor, WaterReflectance, WaterTransparency, WaterWaveSize, WaterWaveSpeed, UnderMapWater
    local created, preserved, lightingOriginal = {}, {}, {}
	local cloudOriginal
    local terrainOriginal, waterPart
    local cloudParts = setmetatable({}, {__mode = 'k'})
    local applying = false

    local lightingProperties = {'Ambient', 'Brightness', 'ColorShift_Bottom', 'ColorShift_Top', 'EnvironmentDiffuseScale', 'EnvironmentSpecularScale', 'ExposureCompensation', 'GlobalShadows', 'OutdoorAmbient', 'ShadowSoftness', 'ClockTime', 'GeographicLatitude', 'Technology'}
    local terrainProperties = {'WaterColor', 'WaterReflectance', 'WaterTransparency', 'WaterWaveSize', 'WaterWaveSpeed'}
    local effectClasses = {Sky = true, Atmosphere = true, BloomEffect = true, DepthOfFieldEffect = true, ColorCorrectionEffect = true, SunRaysEffect = true}
    local presets = {
        Default = {ClockTime = 14, Brightness = 2, Exposure = 0, Ambient = Color3.fromRGB(128,128,128), Outdoor = Color3.fromRGB(128,128,128), Atmosphere = false, Bloom = false},
        Shader = {ClockTime = 14, Brightness = 2.5, Exposure = -0.5, Ambient = Color3.fromRGB(20,20,20), Outdoor = Color3.fromRGB(30,30,30), Atmosphere = true, AtmosphereColor = Color3.fromRGB(103,103,103), Decay = Color3.fromRGB(80,80,80), Density = .3, Glare = .8, Bloom = true, BloomIntensity = 1, BloomSize = 56, BloomThreshold = .5, Contrast = .3, Saturation = -.2},
        Realistic = {ClockTime = 6.47, Brightness = 2.5, Exposure = .05, Ambient = Color3.fromRGB(55,55,55), Outdoor = Color3.fromRGB(55,55,55), Atmosphere = true, AtmosphereColor = Color3.fromRGB(185,185,185), Decay = Color3.fromRGB(95,102,115), Density = .35, Offset = .3, Bloom = true, BloomIntensity = .4, BloomSize = 22, BloomThreshold = 2.2},
        Blavish = {ClockTime = 6.1, Brightness = 2, Exposure = 0, Ambient = Color3.fromRGB(30,45,75), Outdoor = Color3.fromRGB(45,65,100), Atmosphere = true, AtmosphereColor = Color3.fromRGB(55,125,255), Decay = Color3.fromRGB(25,255,190), Density = .1, Glare = .1, Bloom = false},
        Aurora = {ClockTime = 1.5, Brightness = 1.4, Exposure = .1, Ambient = Color3.fromRGB(30,45,75), Outdoor = Color3.fromRGB(45,65,90), Atmosphere = true, AtmosphereColor = Color3.fromRGB(80,145,190), Decay = Color3.fromRGB(25,65,85), Density = .28, Haze = 1.2, Bloom = true, BloomIntensity = .5, BloomSize = 32, BloomThreshold = 1.4, Saturation = .2},
        Storm = {ClockTime = 15.5, Brightness = 1.1, Exposure = -.35, Ambient = Color3.fromRGB(38,43,52), Outdoor = Color3.fromRGB(48,55,65), Atmosphere = true, AtmosphereColor = Color3.fromRGB(95,105,120), Decay = Color3.fromRGB(42,48,60), Density = .48, Haze = 2.5, Bloom = true, BloomIntensity = .18, BloomSize = 18, BloomThreshold = 1.8, Saturation = -.35, Contrast = .18},
        Abyssal = {ClockTime = 0, Brightness = .7, Exposure = -.55, Ambient = Color3.fromRGB(5,18,28), Outdoor = Color3.fromRGB(8,28,38), Atmosphere = true, AtmosphereColor = Color3.fromRGB(10,70,85), Decay = Color3.fromRGB(0,18,30), Density = .62, Haze = 3.5, Bloom = true, BloomIntensity = .35, BloomSize = 30, BloomThreshold = 1.1, Saturation = -.1, Contrast = .3},
        Sunset = {ClockTime = 18.2, Brightness = 2.1, Exposure = .08, Ambient = Color3.fromRGB(105,70,85), Outdoor = Color3.fromRGB(150,95,75), Atmosphere = true, AtmosphereColor = Color3.fromRGB(255,155,110), Decay = Color3.fromRGB(95,45,85), Density = .3, Glare = .35, Bloom = true, BloomIntensity = .32, BloomSize = 24, BloomThreshold = 1.5, Saturation = .15},
        Night = {ClockTime = 0, Brightness = 1, Exposure = -.2, Ambient = Color3.fromRGB(20,25,55), Outdoor = Color3.fromRGB(25,35,65), Atmosphere = true, AtmosphereColor = Color3.fromRGB(55,70,125), Decay = Color3.fromRGB(15,20,45), Density = .25, Bloom = true, BloomIntensity = .2, BloomSize = 20, BloomThreshold = 1.8}
    }

    local function safeSet(object, property, value) if value ~= nil then pcall(function() object[property] = value end) end end
    local function colorValue(option) return Color3.fromHSV(option.Hue, option.Sat, option.Value) end
    local function remember(object, property, destination)
        if destination[property] == nil then pcall(function() destination[property] = object[property] end) end
    end
    local function removeEffects()
        for _, object in created do pcall(function() object:Destroy() end) end
        table.clear(created)
    end
    local function restore()
        removeEffects()
        for _, state in preserved do if state.Object then pcall(function() state.Object.Parent = state.Parent end) end end
        table.clear(preserved)
        for property, value in lightingOriginal do safeSet(lightingService, property, value) end
        table.clear(lightingOriginal)
		if terrainOriginal and terrainOriginal.Object then for property, value in terrainOriginal.Properties do safeSet(terrainOriginal.Object, property, value) end end
		terrainOriginal = nil
		if waterPart then waterPart:Destroy(); waterPart = nil end
		for part, state in cloudParts do if part.Parent then safeSet(part, 'Size', state.Size); safeSet(part, 'Color', state.Color); safeSet(part, 'Transparency', state.Transparency) end end
		table.clear(cloudParts)
		if cloudOriginal and cloudOriginal.Object then
			for property, value in cloudOriginal.Properties do
				safeSet(cloudOriginal.Object, property, value)
			end
		end
		cloudOriginal = nil
    end
    local function add(class, properties)
        local object = Instance.new(class)
        object.Name = 'AetherTheme'..class
        for property, value in properties do safeSet(object, property, value) end
        object.Parent = lightingService
        table.insert(created, object)
        return object
    end
    local function profileValue(profile, key, custom)
        if Custom.Enabled or Preset.Value == 'Custom' then return custom end
        local value = profile[key]
        return value == nil and custom or value
    end
    local function apply()
        if not Theme or not Theme.Enabled or applying then return end
        applying = true
        removeEffects()
        local profile = presets[Preset.Value] or presets.Default
        safeSet(lightingService, 'ClockTime', profileValue(profile, 'ClockTime', ClockTime.Value))
        safeSet(lightingService, 'Brightness', profileValue(profile, 'Brightness', Brightness.Value))
        safeSet(lightingService, 'ExposureCompensation', profileValue(profile, 'Exposure', Exposure.Value))
        safeSet(lightingService, 'ShadowSoftness', ShadowSoftness.Value)
        safeSet(lightingService, 'EnvironmentDiffuseScale', Diffuse.Value)
        safeSet(lightingService, 'EnvironmentSpecularScale', Specular.Value)
        safeSet(lightingService, 'GlobalShadows', GlobalShadows.Enabled)
		safeSet(lightingService, 'GeographicLatitude', Latitude.Value)
		if Technology.Value ~= 'Automatic' then safeSet(lightingService, 'Technology', Enum.Technology[Technology.Value]) end
        safeSet(lightingService, 'Ambient', profileValue(profile, 'Ambient', colorValue(Ambient)))
        safeSet(lightingService, 'OutdoorAmbient', profileValue(profile, 'Outdoor', colorValue(OutdoorAmbient)))
        safeSet(lightingService, 'ColorShift_Top', colorValue(TopShift))
        safeSet(lightingService, 'ColorShift_Bottom', colorValue(BottomShift))
		if SkyEnabled.Enabled then
			local faces = Skybox.Value ~= '' and Skybox.Value or nil
			add('Sky', {SkyboxBk = faces, SkyboxDn = faces, SkyboxFt = faces, SkyboxLf = faces, SkyboxRt = faces, SkyboxUp = faces,
				SunTextureId = SunTexture.Value, MoonTextureId = MoonTexture.Value, StarCount = Stars.Value, SunAngularSize = SunSize.Value, MoonAngularSize = MoonSize.Value})
		end

        if profileValue(profile, 'Atmosphere', AtmosphereEnabled.Enabled) then
            add('Atmosphere', {Color = profileValue(profile, 'AtmosphereColor', colorValue(AtmosphereColor)), Decay = profileValue(profile, 'Decay', colorValue(AtmosphereDecay)), Density = profileValue(profile, 'Density', Density.Value), Offset = profileValue(profile, 'Offset', Offset.Value), Glare = profileValue(profile, 'Glare', Glare.Value), Haze = profileValue(profile, 'Haze', Haze.Value)})
        end
        if profileValue(profile, 'Bloom', BloomEnabled.Enabled) then
            add('BloomEffect', {Intensity = profileValue(profile, 'BloomIntensity', BloomIntensity.Value), Size = profileValue(profile, 'BloomSize', BloomSize.Value), Threshold = profileValue(profile, 'BloomThreshold', BloomThreshold.Value)})
        end
        if ColorEnabled.Enabled then add('ColorCorrectionEffect', {TintColor = colorValue(Tint), Saturation = profileValue(profile, 'Saturation', Saturation.Value), Contrast = profileValue(profile, 'Contrast', Contrast.Value), Brightness = ColorBrightness.Value}) end
        if RaysEnabled.Enabled then add('SunRaysEffect', {Intensity = RaysIntensity.Value, Spread = RaysSpread.Value}) end
        if DepthEnabled.Enabled then add('DepthOfFieldEffect', {FarIntensity = FarIntensity.Value, FocusDistance = FocusDistance.Value, InFocusRadius = FocusDistance.Value, NearIntensity = NearIntensity.Value}) end

        local terrain = workspace:FindFirstChildOfClass('Terrain')
        if terrain then
			safeSet(terrain, 'WaterColor', colorValue(WaterColor)); safeSet(terrain, 'WaterReflectance', WaterReflectance.Value)
			safeSet(terrain, 'WaterTransparency', WaterTransparency.Value); safeSet(terrain, 'WaterWaveSize', WaterWaveSize.Value); safeSet(terrain, 'WaterWaveSpeed', WaterWaveSpeed.Value)
            local clouds = terrain:FindFirstChildOfClass('Clouds')
            if RemoveClouds.Enabled then
                if clouds then safeSet(clouds, 'Enabled', false) end
            elseif CloudsEnabled.Enabled then
                if not clouds then clouds = Instance.new('Clouds'); clouds.Name = 'AetherThemeClouds'; clouds.Parent = terrain; table.insert(created, clouds) end
                safeSet(clouds, 'Enabled', true); safeSet(clouds, 'Cover', CloudCover.Value); safeSet(clouds, 'Density', CloudDensity.Value); safeSet(clouds, 'Color', colorValue(CloudColor))
            end
			if UnderMapWater.Enabled and not waterPart then
				waterPart = Instance.new('Part'); waterPart.Name = 'AetherThemeUnderMapWater'; waterPart.Anchored = true; waterPart.CanCollide = false
				waterPart.Material = Enum.Material.Glass; waterPart.Color = colorValue(WaterColor); waterPart.Transparency = math.clamp(WaterTransparency.Value, 0, 1)
				waterPart.Size = Vector3.new(4096, 2, 4096); waterPart.Position = Vector3.new(0, -25, 0); waterPart.Parent = workspace
			elseif not UnderMapWater.Enabled and waterPart then waterPart:Destroy(); waterPart = nil end
        end
		local cloudFolder = workspace:FindFirstChild('Clouds')
		if cloudFolder then
			for _, part in cloudFolder:GetDescendants() do
				if part:IsA('BasePart') then
					cloudParts[part] = cloudParts[part] or {Size = part.Size, Color = part.Color, Transparency = part.Transparency}
					local original = cloudParts[part]
					safeSet(part, 'Size', original.Size * CloudSize.Value); safeSet(part, 'Color', colorValue(CloudColor)); safeSet(part, 'Transparency', CloudTransparency.Value)
				end
			end
		end
        applying = false
    end
    local function changed() if Theme and Theme.Enabled then apply() end end
	local function populatePreset()
		local profile = presets[Preset.Value]
		if not profile then return end
		local function set(option, value)
			if not option or value == nil or not option.SetValue then return end
			-- Color3 exposes ToHSV as an instance method. Calling the non-existent
			-- static variant aborted preset application before the lighting pass.
			if typeof(value) == 'Color3' then option:SetValue(value:ToHSV()) else option:SetValue(value) end
		end
		set(ClockTime, profile.ClockTime); set(Brightness, profile.Brightness); set(Exposure, profile.Exposure)
		set(Ambient, profile.Ambient); set(OutdoorAmbient, profile.Outdoor); set(AtmosphereEnabled, profile.Atmosphere)
		set(AtmosphereColor, profile.AtmosphereColor); set(AtmosphereDecay, profile.Decay); set(Density, profile.Density)
		set(Offset, profile.Offset); set(Glare, profile.Glare); set(Haze, profile.Haze); set(BloomEnabled, profile.Bloom)
		set(BloomIntensity, profile.BloomIntensity); set(BloomSize, profile.BloomSize); set(BloomThreshold, profile.BloomThreshold)
		set(Saturation, profile.Saturation); set(Contrast, profile.Contrast)
	end

    Theme = vape.Categories.Render:CreateModule({Name = 'Theme', Function = function(enabled)
        if enabled then
            for _, property in lightingProperties do remember(lightingService, property, lightingOriginal) end
            for _, object in lightingService:GetChildren() do if effectClasses[object.ClassName] then table.insert(preserved, {Object = object, Parent = object.Parent}); object.Parent = game end end
            local terrain = workspace:FindFirstChildOfClass('Terrain')
			if terrain then terrainOriginal = {Object = terrain, Properties = {}}; for _, property in terrainProperties do remember(terrain, property, terrainOriginal.Properties) end end
            local clouds = terrain and terrain:FindFirstChildOfClass('Clouds')
			if clouds then
				cloudOriginal = {Object = clouds, Properties = {}}
				for _, property in {'Enabled','Cover','Density','Color'} do
					remember(clouds, property, cloudOriginal.Properties)
				end
			end
            apply()
            Theme:Clean(lightingService:GetPropertyChangedSignal('ClockTime'):Connect(function()
                if not Theme.Enabled or not LockTime.Enabled or applying then return end
                -- Roblox advances ClockTime frequently. Rebuilding every post-processing object,
                -- rescanning clouds and rewriting terrain for a clock tick caused avoidable spikes.
                local profile = presets[Preset.Value] or presets.Default
                applying = true
                safeSet(lightingService, 'ClockTime', profileValue(profile, 'ClockTime', ClockTime.Value))
                applying = false
            end))
			Theme:Clean(workspace.ChildAdded:Connect(function(child) if child.Name == 'Clouds' or child:IsA('Terrain') then task.defer(apply) end end))
			Theme:Clean(lplr.CharacterAdded:Connect(function() task.defer(apply) end))
        else restore() end
    end, Tooltip = 'One customizable world-lighting, atmosphere, sky and post-processing theme'})
    Preset = Theme:CreateDropdown({Name = 'Preset', List = {'Realistic','Blavish','Custom'}, Default = 'Realistic', Function = function() if UnderMapWater then populatePreset() end; changed() end})
    Custom = Theme:CreateToggle({Name = 'Custom overrides', Tooltip = 'Use every slider and color below instead of the selected preset values', Function = changed})
    LockTime = Theme:CreateToggle({Name = 'Lock time', Default = true, Function = changed})
    ClockTime = Theme:CreateSlider({Name = 'Clock time', Min = 0, Max = 24, Default = 14, Decimal = 10, Suffix = 'h', Function = changed})
    Brightness = Theme:CreateSlider({Name = 'Brightness', Min = 0, Max = 10, Default = 2, Decimal = 100, Function = changed})
    Exposure = Theme:CreateSlider({Name = 'Exposure', Min = -3, Max = 3, Default = 0, Decimal = 100, Function = changed})
    ShadowSoftness = Theme:CreateSlider({Name = 'Shadow softness', Min = 0, Max = 1, Default = .2, Decimal = 100, Function = changed})
    Diffuse = Theme:CreateSlider({Name = 'Diffuse scale', Min = 0, Max = 1, Default = .8, Decimal = 100, Function = changed})
    Specular = Theme:CreateSlider({Name = 'Specular scale', Min = 0, Max = 1, Default = .8, Decimal = 100, Function = changed})
    GlobalShadows = Theme:CreateToggle({Name = 'Shadows', Default = true, Function = changed})
    Latitude = Theme:CreateSlider({Name = 'Latitude', Min = -180, Max = 180, Default = 41, Function = changed})
    Technology = Theme:CreateDropdown({Name = 'Technology', List = {'Automatic','Compatibility','Voxel','ShadowMap','Future'}, Default = 'Automatic', Function = changed})
    Ambient = Theme:CreateColorSlider({Name = 'Ambient', DefaultValue = .6, Function = changed})
    OutdoorAmbient = Theme:CreateColorSlider({Name = 'Outdoor ambient', DefaultValue = .6, Function = changed})
    TopShift = Theme:CreateColorSlider({Name = 'Top color shift', DefaultValue = 0, Function = changed})
    BottomShift = Theme:CreateColorSlider({Name = 'Bottom color shift', DefaultValue = 0, Function = changed})
    SkyEnabled = Theme:CreateToggle({Name = 'Sky', Default = true, Function = changed})
    Skybox = Theme:CreateTextBox({Name = 'Skybox', Placeholder = 'rbxassetid://', Function = changed})
    SunTexture = Theme:CreateTextBox({Name = 'Sun texture', Placeholder = 'rbxasset://sky/sun.jpg', Function = changed})
    MoonTexture = Theme:CreateTextBox({Name = 'Moon texture', Placeholder = 'rbxasset://sky/moon.jpg', Function = changed})
    Stars = Theme:CreateSlider({Name = 'Stars', Min = 0, Max = 5000, Default = 3000, Function = changed})
    SunSize = Theme:CreateSlider({Name = 'Sun size', Min = 0, Max = 21, Default = 21, Decimal = 10, Function = changed})
    MoonSize = Theme:CreateSlider({Name = 'Moon size', Min = 0, Max = 21, Default = 11, Decimal = 10, Function = changed})
    AtmosphereEnabled = Theme:CreateToggle({Name = 'Atmosphere', Default = true, Function = changed})
    AtmosphereColor = Theme:CreateColorSlider({Name = 'Atmosphere color', DefaultValue = .55, Function = changed})
    AtmosphereDecay = Theme:CreateColorSlider({Name = 'Atmosphere decay', DefaultValue = .5, Function = changed})
    Density = Theme:CreateSlider({Name = 'Atmosphere density', Min = 0, Max = 1, Default = .3, Decimal = 100, Function = changed})
    Offset = Theme:CreateSlider({Name = 'Atmosphere offset', Min = -1, Max = 1, Default = 0, Decimal = 100, Function = changed})
    Glare = Theme:CreateSlider({Name = 'Atmosphere glare', Min = 0, Max = 10, Default = 0, Decimal = 100, Function = changed})
    Haze = Theme:CreateSlider({Name = 'Atmosphere haze', Min = 0, Max = 10, Default = 0, Decimal = 100, Function = changed})
    BloomEnabled = Theme:CreateToggle({Name = 'Bloom', Default = true, Function = changed})
    BloomIntensity = Theme:CreateSlider({Name = 'Bloom intensity', Min = 0, Max = 5, Default = .4, Decimal = 100, Function = changed})
    BloomSize = Theme:CreateSlider({Name = 'Bloom size', Min = 0, Max = 100, Default = 24, Function = changed})
    BloomThreshold = Theme:CreateSlider({Name = 'Bloom threshold', Min = 0, Max = 5, Default = 1.5, Decimal = 100, Function = changed})
    ColorEnabled = Theme:CreateToggle({Name = 'Color correction', Default = true, Function = changed})
    Tint = Theme:CreateColorSlider({Name = 'Tint', DefaultValue = 0, Function = changed})
    Saturation = Theme:CreateSlider({Name = 'Saturation', Min = -2, Max = 2, Default = 0, Decimal = 100, Function = changed})
    Contrast = Theme:CreateSlider({Name = 'Contrast', Min = -2, Max = 2, Default = 0, Decimal = 100, Function = changed})
    ColorBrightness = Theme:CreateSlider({Name = 'Color brightness', Min = -1, Max = 1, Default = 0, Decimal = 100, Function = changed})
    RaysEnabled = Theme:CreateToggle({Name = 'Sun rays', Function = changed})
    RaysIntensity = Theme:CreateSlider({Name = 'Ray intensity', Min = 0, Max = 1, Default = .1, Decimal = 100, Function = changed})
    RaysSpread = Theme:CreateSlider({Name = 'Ray spread', Min = 0, Max = 1, Default = .8, Decimal = 100, Function = changed})
    DepthEnabled = Theme:CreateToggle({Name = 'Depth of field', Function = changed})
    FarIntensity = Theme:CreateSlider({Name = 'Far blur', Min = 0, Max = 1, Default = .1, Decimal = 100, Function = changed})
    FocusDistance = Theme:CreateSlider({Name = 'Focus distance', Min = 0, Max = 200, Default = 30, Function = changed})
    NearIntensity = Theme:CreateSlider({Name = 'Near blur', Min = 0, Max = 1, Default = 0, Decimal = 100, Function = changed})
    RemoveClouds = Theme:CreateToggle({Name = 'Remove clouds', Function = changed})
    CloudsEnabled = Theme:CreateToggle({Name = 'Custom clouds', Default = true, Function = changed})
    CloudCover = Theme:CreateSlider({Name = 'Cloud cover', Min = 0, Max = 1, Default = .5, Decimal = 100, Function = changed})
    CloudDensity = Theme:CreateSlider({Name = 'Cloud density', Min = 0, Max = 1, Default = .7, Decimal = 100, Function = changed})
    CloudSize = Theme:CreateSlider({Name = 'Cloud size', Min = .1, Max = 3, Default = 1, Decimal = 10, Function = changed})
    CloudTransparency = Theme:CreateSlider({Name = 'Cloud transparency', Min = 0, Max = 1, Default = .3, Decimal = 100, Function = changed})
    CloudColor = Theme:CreateColorSlider({Name = 'Cloud color', DefaultValue = 0, Function = changed})
    WaterColor = Theme:CreateColorSlider({Name = 'Water color', DefaultValue = .55, Function = changed})
    WaterReflectance = Theme:CreateSlider({Name = 'Water reflectance', Min = 0, Max = 1, Default = 1, Decimal = 100, Function = changed})
    WaterTransparency = Theme:CreateSlider({Name = 'Water transparency', Min = 0, Max = 1, Default = .3, Decimal = 100, Function = changed})
    WaterWaveSize = Theme:CreateSlider({Name = 'Water wave size', Min = 0, Max = 1, Default = .15, Decimal = 100, Function = changed})
    WaterWaveSpeed = Theme:CreateSlider({Name = 'Water wave speed', Min = 0, Max = 100, Default = 10, Decimal = 10, Function = changed})
    UnderMapWater = Theme:CreateToggle({Name = 'Below-map water', Function = changed, Tooltip = 'Adds a removable visual water plane below the map without editing terrain voxels.'})
	populatePreset()
    vape.Libraries.aetherTheme = Theme
end)
