run(function()
    local StreamRemover
    local hooks, originalText = {}, setmetatable({}, {__mode = 'k'})
    local refreshQueued = false
    local replacementCache = {}
    local function playerFromArgs(...)
        for i = 1, select('#', ...) do
            local value = select(i, ...)
            if typeof(value) == 'Instance' then
                if value:IsA('Player') then return value end
                local player = playersService:GetPlayerFromCharacter(value); if player then return player end
            elseif type(value) == 'table' then
                local candidate = rawget(value, 'player') or rawget(value, 'Player')
                if typeof(candidate) == 'Instance' and candidate:IsA('Player') then return candidate end
            end
        end
    end
    local function realValue(method, player, value)
        local lower = method:lower()
        if lower:find('display') and lower:find('name') then return player.DisplayName end
        if lower:find('user') and lower:find('name') or lower == 'getname' then return player.Name end
        if lower:find('level') then return tonumber(player:GetAttribute('PlayerLevel')) or value end
        return value
    end
    local function refreshController()
        local controller = (bedwars.Knit.Controllers and bedwars.Knit.Controllers.StreamerModeController) or bedwars.StreamerModeController
        if controller then pcall(function() controller:updateNametags(true) end) end
    end
    local function replacements()
        local result = {}
        for _, player in playersService:GetPlayers() do
            table.insert(result, {
                Player = player,
                Display = player:GetAttribute('DisguiseDisplayName'),
                Username = player:GetAttribute('DisguiseUsername'),
                Level = tostring(tonumber(player:GetAttribute('PlayerLevel')) or 0)
            })
        end
        replacementCache = result
        return result
    end
    local function refreshObject(object, players)
        if not object:IsA('TextLabel') and not object:IsA('TextButton') then return end
        local text = object.Text
        for _, data in players do
                local player = data.Player
                local disguised, username, level = data.Display, data.Username, data.Level
                local relevant = text == 'Me' or text == '[?]' or (disguised and disguised ~= '' and text:find(disguised, 1, true)) or (username and username ~= '' and text:find(username, 1, true))
                if relevant then
                    originalText[object] = originalText[object] or text
                    object.Text = text == '[?]' and '['..level..']' or text == 'Me' and player.DisplayName or text:gsub(disguised or '\0', player.DisplayName):gsub(username or '\0', player.Name)
                end
        end
    end
    local function refreshGui(root)
        for _, object in root:GetDescendants() do refreshObject(object, replacementCache) end
    end
    local function queueRefresh()
        if refreshQueued then return end
        refreshQueued = true
        task.defer(function()
            refreshQueued = false
            if StreamRemover.Enabled then replacements(); refreshController(); refreshGui(lplr.PlayerGui) end
        end)
    end
    local function installHooks()
        local gamePlayer = require(replicatedStorage.TS.player['game-player'])
        for name, fn in gamePlayer do
            if type(fn) == 'function' and (name:lower():find('name') or name:lower():find('level') or name:lower():find('disguise')) then
                hooks[name] = fn
                gamePlayer[name] = function(...)
                    local result = fn(...)
                    local player = playerFromArgs(...)
                    return player and realValue(name, player, result) or result
                end
            end
        end
        bedwars.GamePlayer = gamePlayer
    end
    StreamRemover = vape.Categories.Render:CreateModule({
        Name = 'StreamRemover',
        Function = function(enabled)
            if enabled then
                installHooks(); replacements(); refreshController(); refreshGui(lplr.PlayerGui)
                local function watch(player)
                    for _, attribute in {'DisguiseDisplayName', 'DisguiseUsername', 'PlayerLevel'} do
                        StreamRemover:Clean(player:GetAttributeChangedSignal(attribute):Connect(queueRefresh))
                    end
                    StreamRemover:Clean(player.CharacterAdded:Connect(function() task.defer(refreshController) end))
                end
                for _, player in playersService:GetPlayers() do watch(player) end
                StreamRemover:Clean(playersService.PlayerAdded:Connect(function(player) replacements(); watch(player) end))
                StreamRemover:Clean(playersService.PlayerRemoving:Connect(function() task.defer(replacements) end))
                StreamRemover:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(object)
                    -- Process only the new text object. Attribute changes use the coalesced full
                    -- refresh above, so a kill-feed tree being constructed cannot trigger dozens
                    -- of complete PlayerGui scans in the same frame.
                    if object:IsA('TextLabel') or object:IsA('TextButton') then refreshObject(object, replacementCache) end
                end))
            else
                local gamePlayer = bedwars.GamePlayer
                for name, fn in hooks do gamePlayer[name] = fn end
                table.clear(hooks)
                for object, text in originalText do if object.Parent then object.Text = text end end
                table.clear(originalText); refreshController()
            end
        end,
        Tooltip = 'Reversibly reveals real display names, usernames, and player levels in streamer-mode UI'
    })
end)
