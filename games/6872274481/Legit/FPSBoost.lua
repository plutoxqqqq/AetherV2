run(function()
    local FPSBoost
    local Profile
    local Systems
	local changed, killEffects, visualizers = {}, {}, {}
	local profiles = {
		Quality = {},
		Balanced = {'Particles', 'Bloom', 'Weather'},
		Performance = {'Particles', 'Bloom', 'Weather', 'Shadows', 'Kill effects', 'Projectile effects', 'Lights', 'Atmosphere'},
		Potato = {'Particles', 'Bloom', 'Weather', 'Shadows', 'Kill effects', 'Projectile effects', 'Textures', 'Materials', 'Lighting', 'Lights', 'Atmosphere'},
		
		Minimal = {'Particles'}, Competitive = {'Particles', 'Bloom', 'Weather', 'Shadows', 'Kill effects', 'Projectile effects'}, Max = {'Particles', 'Bloom', 'Weather', 'Shadows', 'Kill effects', 'Projectile effects', 'Textures', 'Materials', 'Lighting'}
    }

    local function selected(name)
        return table.find(Systems.ListEnabled, name) ~= nil
    end

    local function setProperty(object, property, value)
        if not object or changed[object] and changed[object][property] then return end
        local ok, original = pcall(function() return object[property] end)
        if not ok or original == value then return end
        changed[object] = changed[object] or {}
        changed[object][property] = {Original = original, Applied = value}
        pcall(function() object[property] = value end)
    end

    local function applyObject(object)
        if object:IsDescendantOf(coreGui) or (lplr.PlayerGui and object:IsDescendantOf(lplr.PlayerGui)) then return end
        if selected('Particles') and (object:IsA('ParticleEmitter') or object:IsA('Trail') or object:IsA('Beam')) then
            setProperty(object, 'Enabled', false)
        elseif selected('Bloom') and object:IsA('PostEffect') then
            setProperty(object, 'Enabled', false)
        end
        if selected('Lights') and object:IsA('Light') then setProperty(object, 'Enabled', false) end
        if selected('Atmosphere') and object:IsA('Atmosphere') then
            setProperty(object, 'Density', 0)
            setProperty(object, 'Haze', 0)
            setProperty(object, 'Glare', 0)
        end
        if selected('Weather') and (object:GetAttribute('WeatherEffect') or object.Name:lower():find('weather')) then
            if object:IsA('ParticleEmitter') or object:IsA('Trail') or object:IsA('Beam') then setProperty(object, 'Enabled', false) end
        end
		if Profile.Value == 'Potato' or Profile.Value == 'Max' then
            if object:IsA('BasePart') then
                setProperty(object, 'CastShadow', false)
                setProperty(object, 'Reflectance', 0)
                setProperty(object, 'Material', Enum.Material.SmoothPlastic)
                if object:IsA('MeshPart') then
                    setProperty(object, 'TextureID', '')
                    setProperty(object, 'RenderFidelity', Enum.RenderFidelity.Performance)
                end
            elseif object:IsA('Texture') or object:IsA('Decal') then
                setProperty(object, 'Transparency', 1)
            elseif object:IsA('SurfaceAppearance') then
                setProperty(object, 'ColorMap', '')
                setProperty(object, 'MetalnessMap', '')
                setProperty(object, 'NormalMap', '')
                setProperty(object, 'RoughnessMap', '')
            elseif object:IsA('Explosion') then
                setProperty(object, 'Visible', false)
            elseif object:IsA('Smoke') or object:IsA('Fire') or object:IsA('Sparkles') then
                setProperty(object, 'Enabled', false)
            end
        end
    end

    -- Effects, damage numbers and projectiles arrive by the hundred in a fight, so new instances are queued
    -- and worked through on a short tick instead of the moment each one is added.
    local queue, queued = {}, {}
    local function queueObject(object)
        if queued[object] then return end
        queued[object] = true
        table.insert(queue, object)
    end

    local function drain()
        local processed = 0
        while #queue > 0 and processed < 400 do
            local object = table.remove(queue, 1)
            queued[object] = nil
            if object and object.Parent then
                pcall(applyObject, object)
            end
            processed += 1
        end
    end

    local function restore()
        for object, properties in changed do
            for property, state in properties do
                pcall(function()
                    if object.Parent and object[property] == state.Applied then object[property] = state.Original end
                end)
            end
        end
        for name, effect in killEffects do
            if bedwars.KillEffectController.killEffects[name] then bedwars.KillEffectController.killEffects[name] = effect end
        end
        for name, fn in visualizers do
            if bedwars.VisualizerUtils[name] then bedwars.VisualizerUtils[name] = fn end
        end
        table.clear(changed); table.clear(killEffects); table.clear(visualizers)
    end

    local function apply()
        if selected('Shadows') then setProperty(game:GetService('Lighting'), 'GlobalShadows', false) end
		if Profile.Value == 'Potato' or Profile.Value == 'Max' then
            local lighting = game:GetService('Lighting')
            local terrain = workspace:FindFirstChildOfClass('Terrain')
            setProperty(lighting, 'Brightness', 1)
            setProperty(lighting, 'EnvironmentDiffuseScale', 0)
            setProperty(lighting, 'EnvironmentSpecularScale', 0)
            if terrain then
                setProperty(terrain, 'Decoration', false)
                setProperty(terrain, 'WaterReflectance', 0)
                setProperty(terrain, 'WaterTransparency', 1)
                setProperty(terrain, 'WaterWaveSize', 0)
                setProperty(terrain, 'WaterWaveSpeed', 0)
            end
        end
        -- Only the two containers that hold visual systems are walked: the DataModel walk this used to do
        -- pulled in every service, GUI and script in the game for nothing.
        local lighting = game:GetService('Lighting')
        for _, root in {workspace, lighting} do
            for _, object in root:GetDescendants() do applyObject(object) end
        end
        if selected('Kill effects') then
            for name, effect in bedwars.KillEffectController.killEffects do
                if not name:find('Custom') then
                    killEffects[name] = effect
                    bedwars.KillEffectController.killEffects[name] = {new = function() return {onKill = function() end, isPlayDefaultKillEffect = function() return true end} end}
                end
            end
        end
        if selected('Projectile effects') then
            for name, fn in bedwars.VisualizerUtils do visualizers[name] = fn; bedwars.VisualizerUtils[name] = function() end end
        end
    end

    FPSBoost = vape.Categories.Legit:CreateModule({
        Name = 'FPSBoost',
        Function = function(callback)
            restore()
            if not callback then return end
            apply()

            local lighting = game:GetService('Lighting')
            FPSBoost:Clean(game.DescendantAdded:Connect(function(object)
                if not object:IsDescendantOf(workspace) and not object:IsDescendantOf(lighting) then return end
                queueObject(object)
            end))
            task.spawn(function()
                repeat
                    drain()
                    task.wait(0.25)
                until not FPSBoost.Enabled
                table.clear(queue)
                table.clear(queued)
            end)
        end,
        Tooltip = 'Reversibly reduces expensive visual effects'
    })
	Profile = FPSBoost:CreateDropdown({
		Name = 'Profile', List = {'Quality', 'Balanced', 'Performance', 'Potato'}, Default = 'Balanced',
		Function = function(value)
			local canonical = ({Minimal = 'Performance', Competitive = 'Performance', Max = 'Potato'})[value] or value
			shared.AetherPerformancePreset = canonical
			if not Systems then return end
			Systems.ListEnabled = table.clone(profiles[canonical] or profiles.Balanced)
			Systems:ChangeValue()
            if FPSBoost.Enabled then FPSBoost:Toggle(); FPSBoost:Toggle() end
        end
    })
	
	
	local loadProfile = Profile.Load
	function Profile:Load(tab)
		if tab and type(tab.Value) == 'string' then
			local legacy = ({Minimal = 'Quality', Competitive = 'Performance', Max = 'Potato'})[tab.Value]
			if legacy then
				local migrated = table.clone(tab)
				migrated.Value = legacy
				return loadProfile(self, migrated)
			end
		end
		return loadProfile(self, tab)
	end
    Systems = FPSBoost:CreateTextList({
        Name = 'Visual systems', Default = profiles.Balanced,
        Function = function() if FPSBoost.Enabled then FPSBoost:Toggle(); FPSBoost:Toggle() end end
    })
end)
