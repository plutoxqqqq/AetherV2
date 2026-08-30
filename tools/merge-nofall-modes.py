#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
BED = ROOT / 'games' / '6872274481'
NOFALL = BED / 'blatant' / 'NoFallDamage.lua'
V2 = BED / 'blatant' / 'NoFallDamageV2.lua'
MAIN = BED / 'main.lua'


def read(path):
    return path.read_text(encoding='utf-8')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def merge_nofall():
    text = read(NOFALL)

    # Replace only the final module/controller section. All of Aether's Legit helpers above
    # remain untouched; the merged module simply selects which runtime owns the fall.
    start = text.find('\tlocal function setSettingsVisible()')
    if start < 0:
        start = text.find('    local function setSettingsVisible()')
    end = text.find('\tMode = NoFall:CreateDropdown({', start)
    if end < 0:
        end = text.find('    Mode = NoFall:CreateDropdown({', start)
    if start < 0 or end < 0:
        raise RuntimeError('Could not locate NoFallDamage controller section')

    replacement = r'''    local cvStateConnections = {}
    local v2Busy = false
    local modeGeneration = 0

    local function restoreCvStateConnections()
        for _, connection in cvStateConnections do
            pcall(function()
                if connection.Enable then connection:Enable() end
            end)
        end
        table.clear(cvStateConnections)
    end

    local function disableCvStateConnections(humanoid)
        restoreCvStateConnections()
        if not humanoid or type(getconnections) ~= 'function' then return end
        local ok, connections = pcall(getconnections, humanoid.StateChanged)
        if not ok or type(connections) ~= 'table' then return end
        for _, connection in connections do
            if connection and connection.Disable then
                local disabled = pcall(connection.Disable, connection)
                if disabled then table.insert(cvStateConnections, connection) end
            end
        end
    end

    local function startCvBlatant(generation)
        if entitylib.isAlive then
            disableCvStateConnections(entitylib.character.Humanoid)
        end

        local trackedVelocity = 0
        local groundHit
        pcall(function()
            groundHit = bedwars.Handler:Get('GroundHit')
        end)

        NoFall:Clean(runService.PostSimulation:Connect(function()
            if generation ~= modeGeneration or not NoFall.Enabled or Mode.Value ~= 'Blatant' then return end
            if not entitylib.isAlive or store.matchState ~= 1 or store.infinitefly then return end

            local root = entitylib.character.RootPart
            local humanoid = entitylib.character.Humanoid
            local velocity = root.Velocity
            if trackedVelocity < -45 then
                -- cv behaviour: briefly report a landed state, preserve the fall's previous
                -- velocity, and settle the GroundHit record immediately.
                root.Velocity = Vector3.new(0, 2.5, 0)
                humanoid:ChangeState(Enum.HumanoidStateType.Landed)
                runService.PreRender:Wait()
                if generation == modeGeneration and NoFall.Enabled and Mode.Value == 'Blatant' and root.Parent then
                    root.Velocity = velocity
                    if groundHit then
                        pcall(groundHit.Fire, groundHit, 'SendToServer', nil, Vector3.new(0, trackedVelocity, 0), workspace:GetServerTimeNow())
                    end
                end
            end
            trackedVelocity = velocity.Y
        end))

        NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
            if generation ~= modeGeneration or not NoFall.Enabled or Mode.Value ~= 'Blatant' then return end
            task.defer(function()
                if generation == modeGeneration and NoFall.Enabled and Mode.Value == 'Blatant' then
                    disableCvStateConnections(ent.Humanoid)
                end
            end)
        end))
    end

    local function startV2(generation)
        v2Busy = false
        NoFall:Clean(runService.PostSimulation:Connect(function()
            if v2Busy or generation ~= modeGeneration or not NoFall.Enabled or Mode.Value ~= 'V2' then return end
            if not entitylib.isAlive or store.matchState ~= 1 or store.infinitefly then return end
            local highJump = vape.Modules and vape.Modules.HighJump
            if highJump and highJump.Enabled then return end

            local root = entitylib.character.RootPart
            local humanoid = entitylib.character.Humanoid
            local velocity = root.AssemblyLinearVelocity
            if velocity.Y >= -45 then return end

            v2Busy = true
            task.spawn(function()
                local oldY = velocity.Y
                if generation ~= modeGeneration or not NoFall.Enabled or Mode.Value ~= 'V2' or not root.Parent then
                    v2Busy = false
                    return
                end

                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 44, root.AssemblyLinearVelocity.Z)
                pcall(humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Landed)
                runService.PreSimulation:Wait()

                if generation == modeGeneration and NoFall.Enabled and Mode.Value == 'V2' and root.Parent then
                    local current = root.AssemblyLinearVelocity
                    root.AssemblyLinearVelocity = Vector3.new(current.X, oldY, current.Z)
                end
                v2Busy = false
            end)
        end))
    end

    local function setSettingsVisible()
        local legit = Mode and Mode.Value == 'Legit'
        if MinVelocity and MinVelocity.Object then MinVelocity.Object.Visible = legit end
        if GroundDistance and GroundDistance.Object then GroundDistance.Object.Visible = legit end
        if HealthCheck and HealthCheck.Object then HealthCheck.Object.Visible = legit end
        if DamagePercent and DamagePercent.Object then DamagePercent.Object.Visible = legit end
        for _, option in {BlockClutch, TelepearlClutch, DaoClutch, JadeHammerClutch, VoidAxeClutch, Zephyr} do
            if option and option.Object then option.Object.Visible = legit end
        end
        -- Legacy experimental controls are intentionally hidden after the merge.
        for _, option in {AnchorAttempts, FallThreshold, SpoofState} do
            if option and option.Object then option.Object.Visible = false end
        end
    end

    NoFall = vape.Categories.Blatant:CreateModule({
        Name = 'NoFallDamage',
        Function = function(callback)
            modeGeneration += 1
            local generation = modeGeneration

            if callback then
                restoreCvStateConnections()
                v2Busy = false

                if Mode.Value == 'Blatant' then
                    startCvBlatant(generation)
                elseif Mode.Value == 'V2' then
                    startV2(generation)
                end

                repeat
                    local waitDelay = 0.1
                    local character, root, humanoid = validCharacter()
                    if character then
                        updateTrackedFall(root, humanoid)
                        if humanoid.FloorMaterial ~= Enum.Material.Air then
                            usedPearl = false
                        elseif Mode.Value == 'Legit' then
                            local ground = getGround(root, character, HealthCheck and HealthCheck.Enabled and 300 or (GroundDistance and GroundDistance.Value or 30))
                            local zephyred = false
                            if Zephyr and Zephyr.Enabled then
                                zephyred = zephyrClutch(root, humanoid, ground)
                                if zephyred then waitDelay = 0.05 end
                            end
                            if not zephyred then legitClutch(root, humanoid, ground) end
                        end
                    end
                    task.wait(waitDelay)
                until not NoFall.Enabled or generation ~= modeGeneration
            else
                restoreCvStateConnections()
                v2Busy = false
                usedPearl = false
                lastAnchor = 0
                lastLegitUse = 0
                clutchBusyUntil = 0
                lastBlockPlace = 0
                lastZephyrJump = 0
                zephyrFired = false
                fallAnchorY = nil
                trackedFall = 0
                removeRakHook()
            end
        end,
        Tooltip = 'Prevents fall damage. Blatant uses cv; V2 preserves the previous landed-state method; Legit keeps Aether clutch logic.'
    })
'''

    text = text[:start] + replacement + text[end:]

    text = text.replace("List = {'Blatant', 'Legit'}", "List = {'Blatant', 'V2', 'Legit'}", 1)
    text = text.replace(
        "Tooltip = 'Blatant - uses idk\\'s landed-state method\\nLegit - clutches with blocks, telepearls, or tools'",
        "Tooltip = 'Blatant - cv landed/GroundHit behaviour\\nV2 - previous Aether landed-state velocity method\\nLegit - Aether clutch logic'",
        1
    )
    text = text.replace(
        "Tooltip = 'How fast the drop has to be before Legit clutches or TP floors you. Blatant ignores it'",
        "Tooltip = 'How fast the drop has to be before Legit uses a clutch. Blatant and V2 ignore it'",
        1
    )

    write(NOFALL, text)

    # One GUI module only. Remove the old V2 registration/file and its bundle marker.
    if V2.exists():
        V2.unlink()
    main = read(MAIN)
    main = main.replace('--[[AETHER_MODULE:blatant/NoFallDamageV2.lua]]\n', '')
    main = main.replace('--[[AETHER_MODULE:blatant/NoFallDamageV2.lua]]', '')
    write(MAIN, main)


def validate():
    text = read(NOFALL)
    main = read(MAIN)
    assert "List = {'Blatant', 'V2', 'Legit'}" in text
    assert "Mode.Value == 'V2'" in text
    assert "Mode.Value == 'Legit'" in text
    assert "groundHit.Fire" in text
    assert not V2.exists()
    assert 'AETHER_MODULE:blatant/NoFallDamageV2.lua' not in main
    print('Merged NoFallDamage, V2 and cv behavior into one module; preserved Aether Legit mode')


if __name__ == '__main__':
    merge_nofall()
    validate()
