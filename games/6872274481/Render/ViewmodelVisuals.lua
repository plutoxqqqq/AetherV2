run(function()
    local ViewmodelVisuals
    local StrokeColor
    local Color

    local Instances = {}

    ViewmodelVisuals = vape.Categories.Render:CreateModule({
        Name = 'ViewmodelVisuals',
        Function = function(call)
            if call then
                local viewmodel = gameCamera:WaitForChild('Viewmodel', 9e9)
                if not ViewmodelVisuals.Enabled then
                    return
                end

                for i,v in viewmodel:GetChildren() do
                    if v:IsA('Accessory') then
                        local highlight = v.Handle:FindFirstChildOfClass('Highlight') or Instance.new('Highlight', v.Handle)
                        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        highlight.FillTransparency = Color.Opacity
                        highlight.OutlineTransparency = StrokeColor.Opacity
                        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)

                        ViewmodelVisuals:Clean(highlight)
                        table.insert(Instances, highlight)

                        break
                    end
                end

                ViewmodelVisuals:Clean(viewmodel.ChildAdded:Connect(function(visual)
                    if visual:IsA('Accessory') then
                        local highlight = visual.Handle:FindFirstChildOfClass('Highlight') or Instance.new('Highlight', visual.Handle)
                        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        highlight.FillTransparency = Color.Opacity
                        highlight.OutlineTransparency = StrokeColor.Opacity
                        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)

                        ViewmodelVisuals:Clean(highlight)
                        table.insert(Instances, highlight)
                    end
                end))

                ViewmodelVisuals:Clean(gameCamera.ChildAdded:Connect(function(visual)
                    if visual.Name == 'Viewmodel' then
                        ViewmodelVisuals:Toggle()
                        ViewmodelVisuals:Toggle()
                    end
                end))
            end
        end
    })

    Color = ViewmodelVisuals:CreateColorSlider({
        Name = 'Color',
        Default = Color3.new(1, 1, 1),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.FillColor = Color3.fromHSV(hue, sat, val)
                v.FillTransparency = opacity
            end
        end
    })
    StrokeColor = ViewmodelVisuals:CreateColorSlider({
        Name = 'Stroke Color',
        Default = Color3.new(),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.OutlineColor = Color3.fromHSV(hue, sat, val)
                v.OutlineTransparency = opacity
            end
        end
    })
end)


run(function()
    local Water
    local Mode
    local Size
    local Depth
    local Waves
    local Color
    local part
    local filled
    local oldWater
    local fx        
    local oldFog    
    local submerged 

    local function barrierHeight()
        if AntiFallPart and AntiFallPart.Parent then
            return AntiFallPart.Position.Y
        end
        local mag = math.huge
        pcall(function()
            for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
                pos = pos * 3
                if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
                    mag = pos.Y
                end
            end
        end)
        if mag == math.huge then return nil end
        return mag - 2
    end

    local function clearTerrain()
        if not filled then return end
        pcall(function()
            workspace.Terrain:FillBlock(filled.CFrame, filled.Size, Enum.Material.Air)
        end)
        filled = nil
    end

    local function applyWaterLook()
        local terrain = workspace.Terrain
        if not oldWater then
            oldWater = {
                Color = terrain.WaterColor,
                Transparency = terrain.WaterTransparency,
                Reflectance = terrain.WaterReflectance,
                WaveSize = terrain.WaterWaveSize,
                WaveSpeed = terrain.WaterWaveSpeed
            }
        end
        terrain.WaterColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        terrain.WaterTransparency = math.clamp(1 - Color.Opacity, 0, 1)
        terrain.WaterWaveSize = Waves.Enabled and 0.15 or 0
        terrain.WaterWaveSpeed = Waves.Enabled and 12 or 0
    end

    local function restoreWaterLook()
        if not oldWater then return end
        local terrain = workspace.Terrain
        pcall(function()
            terrain.WaterColor = oldWater.Color
            terrain.WaterTransparency = oldWater.Transparency
            terrain.WaterReflectance = oldWater.Reflectance
            terrain.WaterWaveSize = oldWater.WaveSize
            terrain.WaterWaveSpeed = oldWater.WaveSpeed
        end)
        oldWater = nil
    end

    local function makePart(height)
        if part then
            part.Position = Vector3.new(0, height, 0)
            return
        end
        part = Instance.new('Part')
        part.Name = 'AetherWater'
        part.Size = Vector3.new(10000, Depth.Value, 10000)
        part.Position = Vector3.new(0, height, 0)
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Material = Enum.Material.Water
        part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        part.Transparency = math.clamp(1 - Color.Opacity, 0, 1)
        part.Parent = workspace
        
        
        local texture = Instance.new('Texture')
        texture.Name = 'WaterSurface'
        texture.Face = Enum.NormalId.Top
        texture.Texture = 'rbxasset://textures/water/normal_1.dds'
        texture.StudsPerTileU = 24
        texture.StudsPerTileV = 24
        texture.Transparency = 0.35
        texture.Parent = part
        pcall(function()
            bedwars.QueryUtil:setQueryIgnored(part, true)
        end)
    end

    local function removePart()
        if part then
            part:Destroy()
            part = nil
        end
    end

    
    
    
    
    
    
    local FX_NAME = 'AetherWaterFX'

    local function applyRealisticLook()
        local terrain = workspace.Terrain
        if not oldWater then
            oldWater = {
                Color = terrain.WaterColor,
                Transparency = terrain.WaterTransparency,
                Reflectance = terrain.WaterReflectance,
                WaveSize = terrain.WaterWaveSize,
                WaveSpeed = terrain.WaterWaveSpeed
            }
        end
        terrain.WaterColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        terrain.WaterTransparency = math.clamp(1 - Color.Opacity, 0, 1)
        
		terrain.WaterReflectance = Waves.Enabled and 0.18 or 0.08
		terrain.WaterWaveSize = Waves.Enabled and 0.09 or 0.025
		terrain.WaterWaveSpeed = Waves.Enabled and 7 or 2
    end

    local function ensureFX()
        if fx then return end
        fx = {}
        local cc = Instance.new('ColorCorrectionEffect')
        cc.Name = FX_NAME
        cc.Enabled = false
        cc.Parent = lightingService
        fx.cc = cc
        local blur = Instance.new('BlurEffect')
        blur.Name = FX_NAME..'Blur'
        blur.Enabled = false
        blur.Size = 0
        blur.Parent = lightingService
        fx.blur = blur
        local rays = Instance.new('SunRaysEffect')
        rays.Name = FX_NAME..'Rays'
        rays.Enabled = false
        rays.Parent = lightingService
        fx.rays = rays
    end

    local function restoreFog()
        if not oldFog then return end
        pcall(function()
            lightingService.FogStart = oldFog.Start
            lightingService.FogEnd = oldFog.End
            lightingService.FogColor = oldFog.Color
        end)
        oldFog = nil
    end

    
    
    local function surfaced()
        if not submerged then return end
        submerged = false
        restoreFog()
        if fx then
            pcall(function()
                fx.cc.Enabled = false
                fx.blur.Enabled = false
                fx.rays.Enabled = false
            end)
        end
    end

    local function removeFX()
        surfaced()
        if fx then
            for _, effect in fx do
                pcall(function() effect:Destroy() end)
            end
            fx = nil
        end
    end

    
    local function updateRealistic(surface)
        ensureFX()
        local cam = gameCamera
        local under = cam and cam.CFrame.Position.Y < surface

        if under then
            if not submerged then
                submerged = true
                if not oldFog then
                    oldFog = {Start = lightingService.FogStart, End = lightingService.FogEnd, Color = lightingService.FogColor}
                end
            end
            local col = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            local sway = 0.5 + 0.5 * math.sin(tick() * 1.4)
            
            
            lightingService.FogColor = col
            lightingService.FogStart = 0
            lightingService.FogEnd = 55 + Color.Opacity * 55 + sway * 6
            fx.cc.Enabled = true
            fx.cc.TintColor = col:Lerp(Color3.new(1, 1, 1), 0.05 + 0.04 * sway)
            fx.cc.Brightness = -0.04
            fx.cc.Contrast = 0.12
            fx.cc.Saturation = -0.08
			
			
			
			fx.blur.Enabled = false
			fx.rays.Enabled = false
        else
            surfaced()
        end

        
        
        if entitylib.isAlive then
            local root = entitylib.character.RootPart
            if root and isnetworkowner(root) and root.Position.Y < surface then
                local vel = root.AssemblyLinearVelocity
                local lift = math.clamp(vel.Y * 0.6 + 6, -8, 10)
                root.AssemblyLinearVelocity = Vector3.new(vel.X * 0.85, lift, vel.Z * 0.85)
            end
        end
    end

    local function refresh()
        local height = barrierHeight()
        if not height then return end

        if Mode.Value == 'Part' then
            clearTerrain()
            restoreWaterLook()
            makePart(height)
            part.Size = Vector3.new(10000, Depth.Value, 10000)
            part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            part.Transparency = math.clamp(1 - Color.Opacity, 0, 1)
            return
        end

        removePart()
        if Mode.Value == 'Realistic' then
            applyRealisticLook()
        else
            applyWaterLook()
        end

        local centre = Vector3.new(0, height, 0)
        if entitylib.isAlive then
            local root = entitylib.character.RootPart
            centre = Vector3.new(root.Position.X, height, root.Position.Z)
        end
        
        centre = Vector3.new(math.floor(centre.X / 4) * 4, math.floor(centre.Y / 4) * 4, math.floor(centre.Z / 4) * 4)
        local size = Vector3.new(Size.Value, math.max(Depth.Value, 4), Size.Value)

        if filled and (filled.CFrame.Position - centre).Magnitude < (Size.Value * 0.25) and filled.Size == size then
            return
        end
        clearTerrain()
        local cframe = CFrame.new(centre)
        local ok = pcall(function()
            workspace.Terrain:FillBlock(cframe, size, Enum.Material.Water)
        end)
        if ok then
            filled = {CFrame = cframe, Size = size}
        else
            
            makePart(height)
        end
    end

    Water = (vape.Categories.Visuals or vape.Categories.Render):CreateModule({
        Name = 'Water',
        Function = function(callback)
            if callback then
                repeat task.wait() until (store.matchState ~= 0 and store.map) or not Water.Enabled
                if not Water.Enabled then return end
                Water:Clean(function()
                    clearTerrain()
                    restoreWaterLook()
                    removePart()
                    removeFX()
                end)
                Water:Clean(task.spawn(function()
                    while Water.Enabled do
                        refresh()
                        task.wait(0.5)
                    end
                end))
                
                
                
				local nextRealisticUpdate = 0
				Water:Clean(runService.Heartbeat:Connect(function()
					if not Water.Enabled or Mode.Value ~= 'Realistic' then
						surfaced()
						return
					end
					if tick() < nextRealisticUpdate then return end
					nextRealisticUpdate = tick() + 0.1
                    local height = barrierHeight()
                    if not height then return end
                    updateRealistic(height + math.max(Depth.Value, 4) / 2)
                end))
            else
                clearTerrain()
                restoreWaterLook()
                removePart()
                removeFX()
            end
        end,
        Tooltip = 'Fills the void with Roblox water at AntiFall\'s barrier height',
        ExtraText = function()
            return Mode.Value
        end
    })
    Mode = Water:CreateDropdown({
        Name = 'Mode',
        List = {'Terrain', 'Part', 'Realistic'},
        Default = 'Terrain',
        Tooltip = 'Terrain - real Roblox water\nPart - one cheap plane across the map\nRealistic - reflective water with underwater effects',
        Function = function()
            if Water.Enabled then
                clearTerrain()
                restoreWaterLook()
                removePart()
                removeFX()
                task.spawn(refresh)
            end
        end
    })
    Size = Water:CreateSlider({
        Name = 'Area',
        Min = 128,
        Max = 2048,
        Default = 768,
        Suffix = ' studs',
        Tooltip = 'How wide a patch of water to keep filled around you, in Terrain mode'
    })
    Depth = Water:CreateSlider({
        Name = 'Depth',
        Min = 4,
        Max = 60,
        Default = 12,
        Suffix = ' studs',
        Tooltip = 'How deep the water goes below the surface'
    })
    Waves = Water:CreateToggle({
        Name = 'Waves',
        Default = true,
        Tooltip = 'Animate the surface. Off gives you a still, flat sheet',
        Function = function()
            if Water.Enabled and Mode.Value == 'Terrain' then
                applyWaterLook()
            end
        end
    })
    Color = Water:CreateColorSlider({
        Name = 'Color',
        DefaultOpacity = 0.7,
        Function = function()
            if not Water.Enabled then return end
            if Mode.Value == 'Terrain' then
                applyWaterLook()
            elseif part then
                part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                part.Transparency = math.clamp(1 - Color.Opacity, 0, 1)
            end
        end
    })
end)
