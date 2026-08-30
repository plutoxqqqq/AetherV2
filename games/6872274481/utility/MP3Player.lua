run(function()
    local MP3Player
    local Volume
    local Speed
    local Shuffle
    local Loop
    local AutoRefresh
    local PlayField
    local Playlist
    local ShowHUD
    local HUDProgress
    local HUDTime
    local HUDColor

    local SONGS = 'aetherv2/songs'
    local SPOTIFY = 'aetherv2/spotify'

    local sound
    local tracks, index = {}, 0
    local hudName, hudTime, hudBarFill, hudBackground
    local lastScan = 0
    local scanKey = ''
    -- When the current track was started, so the watchdog below can tell a song that has
    -- finished from one that has only just been asked to start.
    local lastPlay = 0

    -- Every filesystem call is optional: some executors ship none of them, and the module has to
    -- degrade to "no songs found" rather than erroring on load.
    local function fsList(path)
        local ok, res = pcall(function()
            if isfolder and not isfolder(path) then
                if makefolder then makefolder(path) end
                return {}
            end
            return listfiles and listfiles(path) or {}
        end)
        return ok and res or {}
    end

    local function isAudio(path)
        path = tostring(path):lower()
        return path:sub(-4) == '.mp3' or path:sub(-4) == '.wav' or path:sub(-4) == '.ogg'
    end

    local function fileName(path)
        local normalised = tostring(path):gsub('\\', '/')
        local name = normalised:match('([^/]+)$') or normalised
        return (name:gsub('%.[^%.]+$', ''))
    end

    local function scan(announce)
        local found = {}
        for _, file in fsList(SONGS) do
            if isAudio(file) then
                table.insert(found, {Name = fileName(file), Path = tostring(file):gsub('\\', '/')})
            end
        end
        for _, file in fsList(SPOTIFY) do
            if isAudio(file) then
                table.insert(found, {Name = fileName(file), Path = tostring(file):gsub('\\', '/')})
            end
        end
        table.sort(found, function(a, b)
            return a.Name:lower() < b.Name:lower()
        end)

        -- Playlist, when you have filled one in, is both the filter and the order.
        local wanted = Playlist and Playlist.ListEnabled or {}
        if #wanted > 0 then
            local ordered = {}
            for _, entry in wanted do
                local needle = entry:lower()
                for _, track in found do
                    if track.Name:lower():find(needle, 1, true) then
                        table.insert(ordered, track)
                        break
                    end
                end
            end
            if #ordered > 0 then
                found = ordered
            end
        end

        local key = ''
        for _, track in found do
            key = key .. track.Path .. ';'
        end
        local changed = key ~= scanKey
        scanKey = key
        tracks = found
        if changed and announce and MP3Player.Enabled then
            notif('MP3Player', #tracks > 0 and (#tracks .. ' song' .. (#tracks == 1 and '' or 's') .. ' loaded') or 'No songs in the songs folder yet', 3)
        end
        return changed
    end

    local function assetFor(path)
        local ok, asset = pcall(function()
            return getcustomasset(path)
        end)
        return ok and asset or nil
    end

    local function refreshHUD()
        if not hudName then return end
        local track = tracks[index]
        local colour = HUDColor and Color3.fromHSV(HUDColor.Hue, HUDColor.Sat, HUDColor.Value) or Color3.new(1, 1, 1)
        hudName.TextColor3 = colour
        hudName.Text = track and track.Name or 'No song loaded'
        if hudBackground then
            hudBackground.BackgroundTransparency = HUDColor and (1 - (HUDColor.Opacity * 0.65)) or 0.35
        end

        local length = sound and sound.TimeLength or 0
        local at = sound and sound.TimePosition or 0
        if hudTime then
            hudTime.Visible = HUDTime == nil or HUDTime.Enabled
            hudTime.TextColor3 = colour
            local function clock(t)
                t = math.max(math.floor(t), 0)
                return string.format('%d:%02d', t // 60, t % 60)
            end
            hudTime.Text = track and (clock(at) .. ' / ' .. clock(length)) or ''
        end
        if hudBarFill then
            hudBarFill.Parent.Visible = HUDProgress == nil or HUDProgress.Enabled
            hudBarFill.BackgroundColor3 = colour
            hudBarFill.Size = UDim2.fromScale(length > 0 and math.clamp(at / length, 0, 1) or 0, 1)
        end
    end

    local function stop()
        if sound then
            pcall(function()
                sound:Stop()
            end)
        end
    end

    -- Looping is the engine's job, not ours.
    --
    -- Repeating a song used to mean replaying it from the Ended handler, which is two
    -- problems at once: it leaves an audible gap at every repeat, and Ended is not
    -- something to depend on - a sound whose asset was still loading when Play ran can
    -- fire it immediately or never, and then the music just stops. Looped restarts the
    -- track inside the engine with no gap and no event involved.
    --
    -- Called on every play AND from the two toggles, so turning Loop on part way through a
    -- song loops that song rather than quietly waiting for the next one - which is what
    -- made the toggle look like it did nothing at all.
    local function applyLoop()
        if not (sound and Loop and Shuffle) then return end
        sound.Looped = Loop.Enabled and not Shuffle.Enabled
    end

    local function play(newIndex)
        if #tracks <= 0 then
            index = 0
            refreshHUD()
            return
        end
        -- Stamped before the asset is resolved, not after: a track the executor cannot load
        -- returns below, and leaving the stamp stale would have the watchdog walk the
        -- playlist several times a second complaining about each one.
        lastPlay = tick()
        index = ((newIndex - 1) % #tracks) + 1
        local track = tracks[index]
        local asset = track and assetFor(track.Path)
        if not asset then
            notif('MP3Player', 'Could not load ' .. (track and track.Name or 'that song'), 4, 'warning')
            return
        end
        if not sound then return end
        sound.SoundId = asset
        sound.Volume = Volume.Value / 100
        sound.PlaybackSpeed = Speed.Value
        sound.TimePosition = 0
        applyLoop()
        pcall(function()
            sound:Play()
        end)
        refreshHUD()
    end

    local function advance(step)
        if #tracks <= 0 then return end
        if Shuffle.Enabled and #tracks > 1 then
            local pick = index
            for _ = 1, 8 do
                pick = math.random(1, #tracks)
                if pick ~= index then break end
            end
            play(pick)
            return
        end
        play(index + step)
    end

    MP3Player = vape.Categories.Utility:CreateModule({
        Name = 'MP3Player',
        Function = function(callback)
            if callback then
                if not (listfiles and getcustomasset) then
                    notif('MP3Player', 'Your executor cannot read local files, so there is nothing to play', 6, 'warning')
                    return task.spawn(function()
                        if MP3Player.Enabled then MP3Player:Toggle() end
                    end)
                end
                if isfolder and makefolder then
                    if not isfolder(SONGS) then makefolder(SONGS) end
                end

                sound = Instance.new('Sound')
                sound.Name = 'AetherMP3'
                sound.Volume = Volume.Value / 100
                sound.PlaybackSpeed = Speed.Value
                sound.Parent = vape.gui
                MP3Player:Clean(sound)
                -- Only ever advances: a looping track never ends, because Looped keeps it
                -- going inside the engine.
                MP3Player:Clean(sound.Ended:Connect(function()
                    if not MP3Player.Enabled then return end
                    advance(1)
                end))

                -- Toggle() shows the HUD frame for any module with a Size, so put Show HUD back in
                -- charge of it now that the module is on.
                if MP3Player.Children then
                    MP3Player.Children.Visible = ShowHUD.Enabled
                end

                scan(true)
                if #tracks > 0 then
                    play(Shuffle.Enabled and math.random(1, #tracks) or 1)
                end

                MP3Player:Clean(task.spawn(function()
                    while MP3Player.Enabled do
                        if AutoRefresh.Enabled and tick() - lastScan > 3 then
                            lastScan = tick()
                            local changed = scan(true)
                            -- Nothing playing and songs have just appeared: start on them.
                            if changed and sound and not sound.IsPlaying and #tracks > 0 then
                                play(index > 0 and index or 1)
                            end
                        end
                        -- Backstop for a track that finished without Ended firing, which is
                        -- what left the playlist sitting in silence part way through. A
                        -- looping track is still playing, so this never touches it, and the
                        -- second since the last start keeps it off a song that is loading.
                        if sound and #tracks > 0 and sound.SoundId ~= '' and sound.IsLoaded
                            and not sound.IsPlaying and not sound.IsPaused
                            and (tick() - lastPlay) > 1 then
                            advance(1)
                        end
                        refreshHUD()
                        task.wait(0.2)
                    end
                end))
            else
                stop()
                sound = nil
                index = 0
                scanKey = ''
                refreshHUD()
            end
        end,
        Tooltip = 'Plays your own mp3 files from the aetherv2/songs folder, with a HUD and a live-refreshing playlist',
        Size = UDim2.fromOffset(236, 66),
        ExtraText = function()
            local track = tracks[index]
            return track and track.Name or nil
        end
    })

    -- HUD, built into the draggable frame the GUI hands us (same pattern AutoWin uses).
    if MP3Player.Children then
        local hud = MP3Player.Children
        if hud.Position == UDim2.new() then
            hud.Position = UDim2.fromOffset(16, 340)
        end
        hudBackground = Instance.new('Frame')
        hudBackground.Size = UDim2.fromScale(1, 1)
        hudBackground.BackgroundColor3 = Color3.new()
        hudBackground.BackgroundTransparency = 0.35
        hudBackground.BorderSizePixel = 0
        hudBackground.Parent = hud
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = hudBackground

        local title = Instance.new('TextLabel')
        title.Size = UDim2.new(1, -14, 0, 16)
        title.Position = UDim2.fromOffset(9, 5)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(170, 170, 170)
        title.Text = 'MP3Player'
        title.Parent = hudBackground

        hudName = Instance.new('TextLabel')
        hudName.Size = UDim2.new(1, -18, 0, 18)
        hudName.Position = UDim2.fromOffset(9, 21)
        hudName.BackgroundTransparency = 1
        hudName.Font = Enum.Font.GothamMedium
        hudName.TextSize = 13
        hudName.TextXAlignment = Enum.TextXAlignment.Left
        hudName.TextTruncate = Enum.TextTruncate.AtEnd
        hudName.TextColor3 = Color3.new(1, 1, 1)
        hudName.Text = 'No song loaded'
        hudName.Parent = hudBackground

        hudTime = Instance.new('TextLabel')
        hudTime.Size = UDim2.new(1, -18, 0, 14)
        hudTime.Position = UDim2.fromOffset(-9, 5)
        hudTime.BackgroundTransparency = 1
        hudTime.Font = Enum.Font.Gotham
        hudTime.TextSize = 11
        hudTime.TextXAlignment = Enum.TextXAlignment.Right
        hudTime.TextColor3 = Color3.new(1, 1, 1)
        hudTime.Text = ''
        hudTime.Parent = hudBackground

        local bar = Instance.new('Frame')
        bar.Size = UDim2.new(1, -18, 0, 4)
        bar.Position = UDim2.fromOffset(9, 46)
        bar.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        bar.BorderSizePixel = 0
        bar.Parent = hudBackground
        local barCorner = Instance.new('UICorner')
        barCorner.CornerRadius = UDim.new(1, 0)
        barCorner.Parent = bar

        hudBarFill = Instance.new('Frame')
        hudBarFill.Size = UDim2.fromScale(0, 1)
        hudBarFill.BackgroundColor3 = Color3.new(1, 1, 1)
        hudBarFill.BorderSizePixel = 0
        hudBarFill.Parent = bar
        local fillCorner = Instance.new('UICorner')
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = hudBarFill
    end

    MP3Player:CreateButton({
        Name = 'Play / Pause',
        Function = function()
            if not sound then return end
            if sound.IsPlaying then
                sound:Pause()
            elseif sound.SoundId ~= '' then
                sound:Resume()
            else
                play(index > 0 and index or 1)
            end
        end,
        Tooltip = 'Pause or resume the current song'
    })
    MP3Player:CreateButton({
        Name = 'Next song',
        Function = function()
            advance(1)
        end
    })
    MP3Player:CreateButton({
        Name = 'Previous song',
        Function = function()
            advance(-1)
        end
    })
    MP3Player:CreateButton({
        Name = 'Refresh songs',
        Function = function()
            lastScan = tick()
            scan(true)
            refreshHUD()
        end,
        Tooltip = 'Re-read the songs folder right now'
    })
    Volume = MP3Player:CreateSlider({
        Name = 'Volume',
        Min = 0,
        Max = 100,
        Default = 40,
        Suffix = '%',
        Function = function(val)
            if sound then
                sound.Volume = val / 100
            end
        end
    })
    Speed = MP3Player:CreateSlider({
        Name = 'Speed',
        Min = 0.5,
        Max = 2,
        Default = 1,
        Decimal = 100,
        Suffix = 'x',
        Function = function(val)
            if sound then
                sound.PlaybackSpeed = val
            end
        end,
        Tooltip = 'Playback speed'
    })
    Shuffle = MP3Player:CreateToggle({
        Name = 'Shuffle',
        Function = applyLoop,
        Tooltip = 'Pick the next song at random instead of in order'
    })
    Loop = MP3Player:CreateToggle({
        Name = 'Loop song',
        Function = applyLoop,
        Tooltip = 'Repeat the current song instead of moving on'
    })
    AutoRefresh = MP3Player:CreateToggle({
        Name = 'Auto refresh',
        Default = true,
        Tooltip = 'Watch the songs folder and pick up new or deleted files while you play'
    })
    PlayField = MP3Player:CreateTextBox({
        Name = 'Play song',
        Placeholder = 'song name',
        -- TextBox hands us `enter`, not the text, and fires on every keystroke - so only act once
        -- the name has actually been submitted.
        Function = function(enter)
            if not enter then return end
            local val = PlayField and PlayField.Value or ''
            if val == '' then return end
            scan(false)
            local needle = val:lower()
            for i, track in tracks do
                if track.Name:lower():find(needle, 1, true) then
                    play(i)
                    return
                end
            end
            notif('MP3Player', 'No song matching "' .. val .. '"', 4, 'warning')
        end,
        Tooltip = 'Type part of a song name to jump straight to it'
    })
    Playlist = MP3Player:CreateTextList({
        Name = 'Playlist',
        Placeholder = 'song name',
        Function = function()
            scan(true)
        end,
        Tooltip = 'Leave empty to play everything in the folder. Add names and only those play, in the order you list them'
    })
    ShowHUD = MP3Player:CreateToggle({
        Name = 'Show HUD',
        Default = true,
        Tooltip = 'Show the now-playing panel. Drag it by its own frame to move it',
        Function = function(callback)
            pcall(function()
                HUDProgress.Object.Visible = callback
                HUDTime.Object.Visible = callback
                HUDColor.Object.Visible = callback
            end)
            if MP3Player.Children then
                MP3Player.Children.Visible = callback and MP3Player.Enabled
            end
        end
    })
    HUDProgress = MP3Player:CreateToggle({
        Name = 'Progress bar',
        Default = true,
        Darker = true,
        Tooltip = 'Show how far through the song you are'
    })
    HUDTime = MP3Player:CreateToggle({
        Name = 'Show time',
        Default = true,
        Darker = true,
        Tooltip = 'Show elapsed and total time'
    })
    HUDColor = MP3Player:CreateColorSlider({
        Name = 'HUD color',
        Darker = true,
        DefaultOpacity = 0.55,
        Function = refreshHUD
    })
end)
