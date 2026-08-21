local SoundManager = {}
SoundManager.__index = SoundManager

local cloneref = cloneref or function(obj)
    return obj
end

local ContentProvider = cloneref(game:GetService('ContentProvider'))
local TweenService = cloneref(game:GetService('TweenService'))
local SoundService = cloneref(game:GetService('SoundService'))
local Players = cloneref(game:GetService('Players'))
local lplr = Players.LocalPlayer

SoundManager.soundConfigs = {}
function SoundManager:registerSound(soundId, config)
    self.soundConfigs[soundId] = config or {}
end

function SoundManager:createSound(soundId)
    local config = self.soundConfigs[soundId] or {}

    local sound = Instance.new('Sound')
    sound.SoundId = soundId
    sound.Volume = config.volume or 0.5
    sound.RollOffMinDistance = config.rollOffMinDistance or 10
    sound.RollOffMaxDistance = config.rollOffMaxDistance or 60
    sound.RollOffMode = Enum.RollOffMode.InverseTapered

    if config.playbackSpeed then
        sound.PlaybackSpeed = config.playbackSpeed.Min + math.random() * (config.playbackSpeed.Max - config.playbackSpeed.Min)
    end

    if (workspace.CurrentCamera.CFrame.Position - lplr.Character.Head.Position).Magnitude < 1 then
        sound.Volume = sound.Volume / 2
    end

    return sound
end

function SoundManager:setPlayConfig(sound, config)
    config = config or {}

    if config.looped ~= nil then
        sound.Looped = config.looped
    end

    if config.volumeMultiplier then
        sound.Volume *= config.volumeMultiplier
    end

    if config.playbackSpeedMultiplier then
        sound.PlaybackSpeed *= config.playbackSpeedMultiplier
    end

    if config.rollOffMinDistance then
        sound.RollOffMinDistance = config.rollOffMinDistance
    end

    if config.rollOffMaxDistance then
        sound.RollOffMaxDistance = config.rollOffMaxDistance
    end

    if config.rollOffMode then
        sound.RollOffMode = config.rollOffMode
    end
end

function SoundManager:tweenSoundVolume(sound, volume, time)
    return TweenService:Create(sound, TweenInfo.new(time or 0.25), {Volume = volume})
end

function SoundManager:playSound(soundOrId, config)
    config = config or {}

    local sound
    if typeof(soundOrId) == 'Instance' then
        sound = soundOrId
    else
        sound = self:createSound(soundOrId)
    end
    self:setPlayConfig(sound, config)

    if config.position then
        local part = Instance.new('Part')
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.Transparency = 1
        part.Size = Vector3.new(1, 1, 1)
        part.Position = config.position
        part.Parent = workspace

        sound.Parent = part

        sound.Ended:Once(function()
            part:Destroy()
        end)
    else
        sound.Parent = config.parent or SoundService
    end

    if config.fadeInTime then
        local original = sound.Volume
        sound.Volume = 0

        sound:Play()
        self:tweenSoundVolume(sound, original, config.fadeInTime):Play()
    else
        sound:Play()
    end

    if config.fadeOutTime then
        task.spawn(function()
            if not sound.IsLoaded then
                sound.Loaded:Wait()
            end

            repeat
                task.wait(0.1)
            until (sound.TimeLength - sound.TimePosition) / sound.PlaybackSpeed <= config.fadeOutTime

            self:tweenSoundVolume(sound, 0, config.fadeOutTime):Play()
        end)
    end

    sound.Ended:Once(function()
        sound:Destroy()
    end)

    return sound
end

function SoundManager:playRandomSound(list, config)
    return self:playSound(list[math.random(#list)], config)
end

function SoundManager:preload()
    local sounds = {}

    for _, v in self.soundConfigs do
        local sound = Instance.new('Sound')
        sound.SoundId = v

        table.insert(sounds, sound)
    end

    if #sounds > 0 then
        ContentProvider:PreloadAsync(sounds)
    end

    for _, v in sounds do
        v:Destroy()
    end
end

return SoundManager