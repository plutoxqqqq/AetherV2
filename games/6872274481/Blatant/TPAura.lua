run(function()
    local TPAura
    local Targets
    local Range
    local TeleportRange
    local Delay
    local DodgeAttacks
    local Mode
    local HoldTime
    local SwitchAfter
    local StructureCheck
    local rand = Random.new()
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude

    local function isValidTarget(ent)
        return ent and ent.RootPart and ent.RootPart.Parent and ent.RootPart.AssemblyLinearVelocity.Y > -35
    end

    local function isClearPosition(position, targetPosition)
        local path = position - targetPosition
        if path.Magnitude > 0.1 and workspace:Raycast(targetPosition + Vector3.new(0, 2.5, 0), path.Unit * math.max(path.Magnitude - 1.5, 0), store.blockRaycast) then return false end
        if workspace:Raycast(position, Vector3.new(0, entitylib.character.HipHeight + 3, 0), store.blockRaycast) then return false end

        overlapParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
        local boxSize = Vector3.new(3.2, entitylib.character.HipHeight + 4, 3.2)
        local boxCFrame = CFrame.new(position + Vector3.new(0, boxSize.Y / 2 - 1.5, 0))
        for _, part in workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams) do
            if part.CanCollide and part.Transparency < 0.95 and not part:IsDescendantOf(lplr.Character) then
                return false
            end
        end
        return true
    end

    local function getGroundPosition(raw, targetPosition)
        local ground = workspace:Raycast(raw + Vector3.new(0, 16, 0), Vector3.new(0, -36, 0), store.blockRaycast)
        if not ground or math.abs(ground.Position.Y - targetPosition.Y) > 5 then return end
        local position = Vector3.new(raw.X, ground.Position.Y + entitylib.character.HipHeight + 2.5, raw.Z)
        
        
        if StructureCheck and StructureCheck.Enabled then
            if workspace:Raycast(position + Vector3.new(0, entitylib.character.HipHeight + 1, 0), Vector3.new(0, 12, 0), store.blockRaycast) then
                return
            end
        end
        return isClearPosition(position, targetPosition) and position or nil
    end

    
    local lockedTarget, lockedUntil, lastSwitch, switchIndex = nil, 0, 0, 0

    
    
    
    local function scanTargets(origin)
        return entitylib.AllPosition({
            Origin = origin,
            Range = Range.Value,
            Players = Targets.Players.Enabled,
            NPCs = Targets.NPCs.Enabled,
            Wallcheck = Targets.Walls.Enabled or nil,
            Part = 'RootPart',
            Sort = sortmethods.Distance
        })
    end

    
    
    local function findTeleportPosition(ent)
        local root = ent.RootPart
        local targetPosition = root.Position
        local radius = TeleportRange.Value
        local position
        if DodgeAttacks.Enabled then
            position = getGroundPosition(targetPosition - (root.CFrame.LookVector * radius), targetPosition)
        end
        for i = 1, 16 do
            if position then break end
            local angle = ((i / 16) * math.pi * 2) + rand:NextNumber(-0.15, 0.15)
            local distance = rand:NextNumber(math.max(2.5, radius - 1.5), radius)
            position = getGroundPosition(targetPosition + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance), targetPosition)
        end
        return position, targetPosition
    end

    TPAura = vape.Categories.Blatant:CreateModule({
        Name = 'TPAura',
        Function = function(callback)
            if callback then
                lockedTarget, lockedUntil, lastSwitch, switchIndex = nil, 0, 0, 0
                local homePosition
                repeat
                    if entitylib.isAlive then
                        local root = entitylib.character.RootPart
                        
                        
                        
                        
                        
                        
                        
                        local engaging = lockedTarget and isValidTarget(lockedTarget)
                            and (lockedTarget.RootPart.Position - (homePosition or root.Position)).Magnitude <= Range.Value
                        if not engaging or not homePosition then
                            homePosition = root.Position
                        end
                        local origin = homePosition
                        local targets = scanTargets(origin)
                        local target

                        if Mode.Value == 'Switch' then
                            
                            
                            local stillValid = lockedTarget and isValidTarget(lockedTarget) and (lockedTarget.RootPart.Position - origin).Magnitude <= Range.Value
                            if not stillValid or (tick() - lastSwitch) >= SwitchAfter.Value then
                                if #targets > 0 then
                                    switchIndex = (switchIndex % #targets) + 1
                                    target = targets[switchIndex]
                                    lockedTarget, lastSwitch = target, tick()
                                end
                            else
                                target = lockedTarget
                            end
                        else
                            
                            
                            local stillValid = lockedTarget and isValidTarget(lockedTarget) and (lockedTarget.RootPart.Position - origin).Magnitude <= Range.Value
                            if stillValid and tick() < lockedUntil then
                                target = lockedTarget
                            else
                                target = targets[1]
                                lockedTarget = target
                                lockedUntil = tick() + HoldTime.Value
                            end
                        end

                        if target and isValidTarget(target) then
                            local targetRoot = target.RootPart
                            
                            
                            
                            
                            local flat = (root.Position - targetRoot.Position) * Vector3.new(1, 0, 1)
                            local distance = (targetRoot.Position - root.Position).Magnitude
                            local behindOk = true
                            if DodgeAttacks.Enabled and flat.Magnitude > 0.5 then
                                behindOk = targetRoot.CFrame.LookVector:Dot(flat.Unit) > 0.15
                            end
                            if distance > TeleportRange.Value + 1.5 or not behindOk then
                                local position, targetPosition = findTeleportPosition(target)
                                if position then
                                    
                                    root.CFrame = CFrame.lookAt(position, Vector3.new(targetPosition.X, position.Y, targetPosition.Z))
                                    root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                end
                            end
                        end
                    end
                    task.wait(Delay.Value)
                until not TPAura.Enabled
            else
                lockedTarget = nil
            end
        end,
        Tooltip = 'Teleports around targets and faces them. Single locks one, Switch rotates between them'
    })
    Targets = TPAura:CreateTargets({Players = true, NPCs = true})
    Mode = TPAura:CreateDropdown({Name = 'Mode', List = {'Single', 'Switch'}, Default = 'Single'})
    Range = TPAura:CreateSlider({Name = 'Target Range', Min = 6, Max = 40, Default = 22, Suffix = 'studs'})
    TeleportRange = TPAura:CreateSlider({Name = 'Teleport Range', Min = 3, Max = 10, Default = 6, Decimal = 10, Suffix = 'studs'})
    Delay = TPAura:CreateSlider({Name = 'Teleport Delay', Min = 0.15, Max = 1, Default = 0.35, Decimal = 100, Suffix = 'seconds'})
    HoldTime = TPAura:CreateSlider({Name = 'Single Hold Time', Min = 0.5, Max = 8, Default = 3, Decimal = 10, Suffix = 'seconds'})
    SwitchAfter = TPAura:CreateSlider({Name = 'Switch Delay', Min = 0.35, Max = 4, Default = 1.25, Decimal = 100, Suffix = 'seconds'})
    StructureCheck = TPAura:CreateToggle({Name = 'Structure Check', Tooltip = 'Rejects teleport spots on roofs, bridges, or tall structures above the target', Default = true})
    DodgeAttacks = TPAura:CreateToggle({
        Name = 'Dodge attacks',
        Tooltip = 'Prioritizes teleporting behind where targets are facing'
    })
end)
