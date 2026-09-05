local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService'))
local httpService = cloneref(game:GetService('HttpService'))
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

-- NOTE: This upload path cannot carry the 83KB lobby in one shot from this session.
-- Keep a valid parseable stub that fails loudly rather than a silent PLACEHOLDER.
-- The complete lobby with NameTagSpoofer + LARPKits defaults is in the workspace copy.
warn('[AetherV2] games/6872265039.lua on GitHub is incomplete. Use the local artifacts/6872265039.lua copy.')
