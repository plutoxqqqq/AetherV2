local cloneref = cloneref or function(obj)
    return obj
end

local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local Players = cloneref(game:GetService('Players'))
local lplr = Players.LocalPlayer

local Loader = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))()
local Client, matchController
do
    Client = Loader:GetMain('Client')
    matchController = Loader:GetController('MatchController')
end

local Settings = setmetatable({
    enable_auto_deposit = true,
    ambient_lighting_brightness = 0,
    audio_master_volume = 1,
    mobile_interact_button = true,
    show_tips = false,
    audio_cosmetics_volume = 1,
    global_chat_system_messages = false,
    enable_on_screen_effects = false,
    audio_effects_volume = 1,
    mobile_auto_bridge_button = true,
    pc_shift_lock = true,
    audio_gameplay_volume = 1,
    friendNotifications = true,
    streamer_mode = false,
    friendSpectating = false,
    audio_ambience_volume = 1,
    show_recommended_shop = true,
    mobile_block_break_button = true,
    mobileShiftLock = false,
    audio_music_volume = 1,
    audio_ui_volume = 1,
    lock_camaera = false,
    mobile_sword_hold = true,
    profile_visibility = 'public',
    show_resources_in_hud = true,
    fov = workspace.CurrentCamera.FieldOfView - 10,
    clan_invites = false,
    mobile_projectile_button = true,
    pictureMode = false,
    exposure_compensation = 0
}, {
    __newindex = function(tbl, key, value)
        rawset(tbl, key, value)

        ReplicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.SetSettings:FireServer(tbl)
    end
})

local Game, Bedwars = {
    matchState = matchController:getMatchState(),
    queueType = workspace:GetAttribute('QueueType'),
    customMatch = {},
    myTeam = {
        id = lplr:GetAttribute('Team')
    }
}, {
    kit = lplr:GetAttribute('PlayingAsKits')
}

task.spawn(function()
    repeat
        Game.matchState = matchController:getMatchState()
        task.wait()
    until false
end)

local Kits = {
    angelProgress = 0
}

do
    Client:OnEvent('AngelProgress', function(prog)
        Kits.angelProgress = prog.newProgress
    end)
end

local Store = {
    Game = Game,
    Settings = Settings,
    Bedwars = Bedwars,
    Kit = Kits
}

return {
    getState = function(self)
        return Store
    end
}