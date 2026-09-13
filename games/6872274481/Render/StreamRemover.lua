run(function()
    local StreamRemover
    local hooks, controllerHooks, originalText = {}, {}, setmetatable({}, {__mode = 'k'})
    local refreshQueued = false
    local replacementCache = {}
    local runService = cloneref(game:GetService('RunService'))
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
        if type(players) ~= 'table' then return end
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
    local function installControllerHooks()
        local controller = (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.StreamerModeController) or bedwars.StreamerModeController
        if type(controller) ~= 'table' then return end
        local names = {'getDisplayName', 'getPlayerName', 'getUserName', 'getLevel', 'getPlayerLevel', 'getDisguisedName', 'isEnabled', 'isStreamerMode', 'isStreamerModeEnabled', 'isDisguised', 'shouldHide', 'shouldDisguise'}
        for _, name in names do
            local fn = controller[name]
            if type(fn) == 'function' and not controllerHooks[name] then
                controllerHooks[name] = fn
                controller[name] = function(self, ...)
                    local lower = name:lower()
                    if lower:find('isenabled') or lower:find('isstreamer') or lower:find('shouldhide') or lower:find('shoulddisguise') then
                        return false
                    end
                    if lower:find('isdisguised') then return false end
                    local player = playerFromArgs(...)
                    if player then
                        if lower:find('level') then
                            return tonumber(player:GetAttribute('PlayerLevel')) or fn(self, ...)
                        end
                        if lower:find('display') or lower:find('disguised') then return player.DisplayName end
                        if lower:find('user') or lower:find('name') then return player.Name end
                    end
                    return fn(self, ...)
                end
            end
        end
    end
    local function restoreControllerHooks()
        local controller = (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.StreamerModeController) or bedwars.StreamerModeController
        if type(controller) ~= 'table' then return end
        for name, fn in controllerHooks do controller[name] = fn end
        table.clear(controllerHooks)
    end
    local function installHooks()
        local gamePlayer = require(replicatedStorage.TS.player['game-player'])
        if type(gamePlayer) ~= 'table' then return end
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
        installControllerHooks()
    end
    StreamRemover = vape.Categories.Render:CreateModule({
        Name = 'StreamRemover',
        Function = function(enabled)
            if enabled then
                installHooks(); replacements(); refreshController(); refreshGui(lplr.PlayerGui)
                -- React re-renders keep overwriting labels with the disguised text without
                -- changing any attribute, so re-scan once a second while enabled.
                local lastRefresh = 0
                StreamRemover:Clean(runService.Heartbeat:Connect(function()
                    local now = os.clock()
                    if now - lastRefresh < 1 then return end
                    lastRefresh = now
                    if StreamRemover.Enabled then
                        replacements()
                        refreshController()
                        refreshGui(lplr.PlayerGui)
                    end
                end))
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
                    
                    
                    
                    if object:IsA('TextLabel') or object:IsA('TextButton') then refreshObject(object, replacementCache) end
                end))
            else
                local gamePlayer = bedwars.GamePlayer
                if type(gamePlayer) == 'table' then
                    for name, fn in hooks do gamePlayer[name] = fn end
                end
                table.clear(hooks)
                restoreControllerHooks()
                for object, text in originalText do if object.Parent then object.Text = text end end
                table.clear(originalText); refreshController()
            end
        end,
        Tooltip = 'Reversibly reveals real display names, usernames, and player levels in streamer-mode UI'
    })
end)
