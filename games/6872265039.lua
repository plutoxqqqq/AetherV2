-- Each module registers through run(). A bare func() meant one bad module aborted the whole chunk
-- part-way through; isolate them so a single failure only costs that module.
local run = function(func)
	local success, result = xpcall(func, debug and debug.traceback or tostring)
	if not success then
		warn('[AetherV2] Skipped a module during startup: '..tostring(result))
	end
	return success
end
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

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end
	-- Bounded: this runs on the loader's thread, so a wait with no exit is a load that never ends.
	local KnitInit, Knit
	local knitDeadline = tick() + 45
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit and Knit then break end
		task.wait(0.1)
	until tick() > knitDeadline
	if not (KnitInit and Knit) then
		error('Knit never became available - the game has not finished loading')
	end

	if not debug.getupvalue(Knit.Start, 1) then
		local upvalueDeadline = tick() + 15
		repeat task.wait(0.1) until debug.getupvalue(Knit.Start, 1) or tick() > upvalueDeadline
		if not debug.getupvalue(Knit.Start, 1) then
			error('debug.getupvalue is unavailable on this executor')
		end
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get
	local function safeGetProto(func, index)
		if not func then return nil end
		local success, proto = pcall(safeGetProto, func, index)
		if success then
			return proto
		else
			warn("function:", func, "index:", index) 
			return nil
		end
	end

	bedwars = setmetatable({
	 	MatchHistroyApp = require(lplr.PlayerScripts.TS.controllers.global["match-history"].ui["match-history-moderation-app"]).MatchHistoryModerationApp,
	 	MatchHistroyController = Knit.Controllers.MatchHistoryController,
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		MatchHistoryController = require(lplr.PlayerScripts.TS.controllers.global['match-history']['match-history-controller']),
		PlayerProfileUIController = require(lplr.PlayerScripts.TS.controllers.global['player-profile']['player-profile-ui-controller']),
		TitleTypes = require(game.ReplicatedStorage.TS.locker.title['title-type']).TitleType,
		TitleTypesMeta =  require(game.ReplicatedStorage.TS.locker.title['title-meta']).TitleMeta,
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		NotificationController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network),
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	vape:Clean(function()
		table.clear(bedwars)
	end)
end)


getgenv()._aeroTierReady = true
local function getAccountTier(player)
    return 0
end

getgenv().getAeroTier = function(player)
    return getAccountTier(player)
end  
for _, v in vape.Modules do
	if v.Category == 'Combat' or v.Category == 'Render' then
		vape:Remove(i)
	end
end

run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = false end) end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() bedwars.SprintController:stopSprinting() end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end) end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true'
	})
end)
	
run(function()
	local AutoGamble
	
	AutoGamble = vape.Categories.Minigames:CreateModule({
		Name = 'AutoGamble',
		Function = function(callback)
			if callback then
				AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
					if data.openingPlayer == lplr then
						local tab = bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
						notif('AutoGamble', 'Won '..tab.displayName, 5)
					end
				end))
	
				repeat
					if not bedwars.CrateAltarController.activeCrates[1] then
						for _, v in bedwars.Store:getState().Consumable.inventory do
							if v.consumable:find('crate') then
								bedwars.CrateAltarController:pickCrate(v.consumable, 1)
								task.wait(1.2)
								if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][1] then
									bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
										crateId = bedwars.CrateAltarController.activeCrates[1][1].attributes.crateId,
										altarId = 1
									})
								end
								break
							end
						end
					end
					task.wait(1)
				until not AutoGamble.Enabled
			end
		end,
		Tooltip = 'Automatically opens lucky crates, piston inspired!'
	})
end)
	
run(function()
    local ok, err = pcall(function()
        repeat task.wait() until vape and vape.Categories and vape.Categories.Render
        local ClanModule
        local ClanColor = Color3.new(1, 1, 1)
        local enabledFlag = false
        local EquippedTag = nil
    
        local SavedTags = {}
        local TagToggles = {}
        
        local function safeSet(attr, value)
            local lp = game.Players.LocalPlayer
            if lp and lp.SetAttribute then
                pcall(function()
                    lp:SetAttribute(attr, value)
                end)
            end
        end
        
        local function buildTag()
            if not EquippedTag then return "" end
            local hex = string.format("#%02X%02X%02X",
                ClanColor.R * 255,
                ClanColor.G * 255,
                ClanColor.B * 255
            )
            return "<font color='"..hex.."'>"..EquippedTag.."</font>"
        end
        
        local function updateClanTag()
            if enabledFlag then
                safeSet("ClanTag", buildTag())
            else
                safeSet("ClanTag", "")
            end
        end
        
        local function createTagToggles()
            for i, toggle in pairs(TagToggles) do
                if toggle and toggle.Object then
                    toggle.Object:Remove()
                end
            end
            TagToggles = {}
            
            for i, tag in ipairs(SavedTags) do
                if tag and tag ~= "" then
                    TagToggles[i] = ClanModule:CreateToggle({
                        Name = tag,
                        Function = function(callback)
                            if callback then
                                EquippedTag = tag
                                for j, otherToggle in pairs(TagToggles) do
                                    if j ~= i and otherToggle and otherToggle.Enabled then
                                        otherToggle:Toggle()
                                    end
                                end
                            else
                                if EquippedTag == tag then
                                    EquippedTag = nil
                                end
                            end
                            updateClanTag()
                        end
                    })
                end
            end
        end
        
        ClanModule = vape.Categories.Render:CreateModule({
            Name = "CustomClanTag",
            HoverText = "Click tags to equip/unequip",
            Function = function(state)
                enabledFlag = state
                if state then
                    createTagToggles()
                end
                updateClanTag()
            end
        })
        
        ClanModule:CreateColorSlider({
            Name = "Tag Color",
            Function = function(h, s, v)
                ClanColor = Color3.fromHSV(h, s, v)
                updateClanTag()
            end
        })
        
        ClanModule:CreateTextList({
            Name = "Clan Tags",
            Placeholder = "Add tags here",
            Function = function(list)
                SavedTags = {}
                for i, tag in ipairs(list) do
                    if tag and tag ~= "" then
                        table.insert(SavedTags, tag)
                    end
                end
                createTagToggles()
            end
        })
        
    end)
    if not ok then
        warn("CustomClanTag error:", err)
    end
end)

run(function()
	local ViewMatchHistory
	ViewMatchHistory = vape.Categories.Utility:CreateModule({
		Name = "ViewMatchHistory",
		Function = function(callback)
			if callback then
				ViewMatchHistory:Toggle(false)
				local d = nil
				bedwars.MatchHistroyController:requestMatchHistory(lplr.Name):andThen(function(Data)
					if Data then
						bedwars.AppController:openApp({app = bedwars.MatchHistroyApp,appId = "MatchHistoryApp",},Data)
					end
				end)
			else
				return
			end
		end,
		Tooltip = "matchhisory"
	})																								
end)

run(function()
	local OGNameTags
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")
	local LP = Players.LocalPlayer
	local FLAME_IMAGE = "rbxassetid://7101948108"
	local BedwarsImageId = require(ReplicatedStorage.TS.image["image-id"]).BedwarsImageId
	local TITLE_STROKE_TRANSP = nil
	local WIN_TEXT_PULL_LEFT = 14
	local ORIGINAL_NAMETAG_SCALE = 1.17
	local TITLE_TEXT_SIZE = 14
	local FLAME_ASPECT_RATIO = 0.8
	
	local KnitClient
	do
		local ok, knitMod = pcall(function()
			return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
		end)
		if ok then KnitClient = knitMod end
	end
	
	local function divisionToRankKey(division)
		if division >= 0 and division <= 3 then return "BRONZE_RANK"
		elseif division >= 4 and division <= 7 then return "SILVER_RANK"
		elseif division >= 8 and division <= 11 then return "GOLD_RANK"
		elseif division >= 12 and division <= 15 then return "PLATINUM_RANK"
		elseif division >= 16 and division <= 19 then return "DIAMOND_RANK"
		elseif division >= 20 and division <= 23 then return "EMERALD_RANK"
		elseif division == 24 then return "NIGHTMARE_RANK"
		end
		return "RANDOM_KIT_RENDER"
	end
	
	local function requestNametagData(callback)
		if not KnitClient or not KnitClient.Controllers or not KnitClient.Controllers.NametagController then return end
		local ctrl = KnitClient.Controllers.NametagController
		local ok, promise = pcall(function()
			return ctrl:requestNametagData(LP)
		end)
		if not ok or not promise then return end
		if typeof(promise) == "table" and promise.andThen then
			promise:andThen(function(data) callback(data) end)
		end
	end
	
	local function findLocalOriginalNametag(char)
		local head = char:FindFirstChild("Head")
		if not head then return nil end
		
		local direct = head:FindFirstChild("Nametag")
		if direct and direct:IsA("BillboardGui") then
			return direct
		end
		
		for _, gui in ipairs(CollectionService:GetTagged("EntityNameTag")) do
			if gui:IsA("BillboardGui") and (gui.Adornee == head or gui:IsDescendantOf(char)) then
				return gui
			end
		end
		
		return nil
	end
	
	local function scaleOriginalNametagSlightly(originalGui)
		if not originalGui then return end
		
		local attrW = originalGui:GetAttribute("BaseSizeW")
		local attrH = originalGui:GetAttribute("BaseSizeH")
		
		if type(attrW) ~= "number" or type(attrH) ~= "number" then
			originalGui:SetAttribute("BaseSizeW", originalGui.Size.X.Scale)
			originalGui:SetAttribute("BaseSizeH", originalGui.Size.Y.Scale)
			attrW = originalGui.Size.X.Scale
			attrH = originalGui.Size.Y.Scale
		end
		
		local w = (attrW or originalGui.Size.X.Scale) * ORIGINAL_NAMETAG_SCALE
		local h = (attrH or originalGui.Size.Y.Scale) * ORIGINAL_NAMETAG_SCALE
		
		originalGui.Size = UDim2.fromScale(w, h)
	end
	
	local function hideMiddleNameAndLevel(originalGui)
		if not originalGui then return end
		
		local container = originalGui:FindFirstChild("DisplayNameContainer", true)
		if container and container:IsA("GuiObject") then container.Visible = false end
		
		local nameLabel = originalGui:FindFirstChild("DisplayName", true)
		if nameLabel and nameLabel:IsA("TextLabel") then nameLabel.Visible = false end
		
		for _, d in ipairs(originalGui:GetDescendants()) do
			if d:IsA("TextLabel") then
				local t = tostring(d.Text or "")
				if t:match("^%(%d+%)") then d.Visible = false end
			end
		end
	end
	
	local function hideOldWinStreakOnly(originalGui)
		if not originalGui then return end
		
		for _, d in ipairs(originalGui:GetDescendants()) do
			if d:IsA("TextLabel") then
				local name = string.lower(d.Name or "")
				local txt = tostring(d.Text or "")
				if name:find("winstreak") or name:find("streak") or txt:find("🔥") then
					d.Visible = false
				end
			elseif d:IsA("ImageLabel") then
				local name = string.lower(d.Name or "")
				local img = tostring(d.Image or "")
				if name:find("winstreak") or name:find("streak") or img == FLAME_IMAGE then
					d.Visible = false
				end
			end
		end
	end
	
	local RANK_ICON_IMAGES = {}
	do
		local keys = {
			"BRONZE_RANK","SILVER_RANK","GOLD_RANK","PLATINUM_RANK",
			"DIAMOND_RANK","EMERALD_RANK","NIGHTMARE_RANK",
		}
		for _, k in ipairs(keys) do
			local img = BedwarsImageId[k]
			if type(img) == "string" and img ~= "" then
				RANK_ICON_IMAGES[img] = true
			end
		end
	end
	
	local function hideOldRankIconOnly(originalGui)
		if not originalGui then return end
		
		for _, d in ipairs(originalGui:GetDescendants()) do
			if d:IsA("ImageLabel") then
				local name = string.lower(d.Name or "")
				local img = tostring(d.Image or "")
				
				if RANK_ICON_IMAGES[img] then
					d.Visible = false
				elseif name:find("rank") or name:find("division") or name:find("elo") then
					d.Visible = false
				end
			end
		end
	end
	
	local function fixRoleTextScaling(originalGui)
		if not originalGui then return end
		
		for _, d in ipairs(originalGui:GetDescendants()) do
			if d:IsA("TextLabel") then
				local name = string.lower(d.Name or "")
				
				if name:find("title") or name:find("playertitle") or name:find("role") then
					d.TextScaled = true
					
					if TITLE_STROKE_TRANSP ~= nil then
						d.TextStrokeTransparency = TITLE_STROKE_TRANSP
					end
				end
			end
		end
	end
	
	local function hideOtherLocalBillboards(char)
		for _, inst in ipairs(char:GetDescendants()) do
			if inst:IsA("BillboardGui") and not CollectionService:HasTag(inst, "EntityNameTag") then
				if inst.Name ~= "LocalRankStreakGui" then
					inst.Enabled = false
				end
			end
		end
	end
	
	local function createHeadLockedGui(head)
		local existing = head:FindFirstChild("LocalRankStreakGui")
		if existing and existing:IsA("BillboardGui") then
			return existing
		end
		
		local bb = Instance.new("BillboardGui")
		bb.Name = "LocalRankStreakGui"
		bb.Parent = head
		bb.Adornee = head
		bb.AlwaysOnTop = true
		bb.ResetOnSpawn = false
		bb.MaxDistance = 1000
		
		bb.Size = UDim2.fromScale(7.2, 0.9)
		bb.StudsOffset = Vector3.new(0.44, 1.45, 0)
		
		local main = Instance.new("Frame")
		main.BackgroundTransparency = 1
		main.Size = UDim2.fromScale(1, 1)
		main.Parent = bb
		
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.525, 0.5)
		row.Size = UDim2.fromScale(1, 1)
		row.Parent = main
		
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 10)  
		layout.Parent = row
		
		local rank = Instance.new("ImageLabel")
		rank.Name = "RankIcon"
		rank.BackgroundTransparency = 1
		rank.Size = UDim2.fromScale(0.16, 0.95)
		rank.Parent = row
		local rAspect = Instance.new("UIAspectRatioConstraint")
		rAspect.AspectRatio = 1
		rAspect.Parent = rank
		
		local winGroup = Instance.new("Frame")
		winGroup.Name = "WinGroup"
		winGroup.BackgroundTransparency = 1
		winGroup.Size = UDim2.fromScale(0.28, 1.05)  
		winGroup.Parent = row
		
		local flame = Instance.new("ImageLabel")
		flame.Name = "WinFlame"
		flame.BackgroundTransparency = 1
		flame.Image = FLAME_IMAGE
		flame.AnchorPoint = Vector2.new(0, 0.5)
		flame.Position = UDim2.fromScale(0, 0.5)
		flame.Size = UDim2.fromScale(0.24, 1.05)
		flame.Parent = winGroup
		
		local fAspect = Instance.new("UIAspectRatioConstraint")
		fAspect.AspectRatio = FLAME_ASPECT_RATIO  
		fAspect.Parent = flame
		
		local num = Instance.new("TextLabel")
		num.Name = "WinStreak"
		num.BackgroundTransparency = 1
		num.Font = Enum.Font.Gotham
		num.TextColor3 = Color3.fromRGB(255, 255, 255)
		num.TextStrokeTransparency = 1
		num.TextXAlignment = Enum.TextXAlignment.Left
		num.TextYAlignment = Enum.TextYAlignment.Center
		
		num.TextScaled = true
		
		num.AnchorPoint = Vector2.new(0, 0.5)
		num.Position = UDim2.fromScale(0.28, 0.5) 
		num.Size = UDim2.new(0.72, 0, 0.94, 0)   
		num.Parent = winGroup
		
		local winLayout = Instance.new("UIListLayout")
		winLayout.FillDirection = Enum.FillDirection.Horizontal
		winLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		winLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		winLayout.Padding = UDim.new(0, 2)
		winLayout.Parent = winGroup
		
		return bb
	end
	
	local function forceWinTextStyle(gui) end
	
	local function updateGui(gui, data)
		if not gui then return end
		
		local streak = 0
		local division = -1
		if data then
			if data.winstreak ~= nil then streak = tonumber(data.winstreak) or 0 end
			if data.rankDivision ~= nil then division = tonumber(data.rankDivision) or -1 end
		end
		
		local rank = gui:FindFirstChild("RankIcon", true)
		if rank and rank:IsA("ImageLabel") then
			local key = divisionToRankKey(division)
			rank.Image = BedwarsImageId[key] or ""
		end
		
		local flame = gui:FindFirstChild("WinFlame", true)
		if flame and flame:IsA("ImageLabel") then
			flame.Image = FLAME_IMAGE
		end
		
		local num = gui:FindFirstChild("WinStreak", true)
		if num and num:IsA("TextLabel") then
			num.Text = tostring(streak)
		end
		
		forceWinTextStyle(gui)
	end
	
	local activeLoop = nil
	
	local function setup(char)
		local head = char:WaitForChild("Head", 5)
		if not head then return end
		
		local headGui = createHeadLockedGui(head)
		
		activeLoop = task.spawn(function()
			while char.Parent and OGNameTags.Enabled do
				task.wait(0.25)
				
				hideOtherLocalBillboards(char)
				
				local original = findLocalOriginalNametag(char)
				if original then
					hideMiddleNameAndLevel(original)
					hideOldWinStreakOnly(original)
					hideOldRankIconOnly(original)
				end
				
				requestNametagData(function(data)
					updateGui(headGui, data)
				end)
				
				forceWinTextStyle(headGui)
			end
		end)
	end
	
	local function cleanup()
		if activeLoop then
			task.cancel(activeLoop)
			activeLoop = nil
		end
		
		if LP.Character then
			local head = LP.Character:FindFirstChild("Head")
			if head then
				local customGui = head:FindFirstChild("LocalRankStreakGui")
				if customGui then
					customGui:Destroy()
				end
			end
		end
		
		if LP.Character then
			local original = findLocalOriginalNametag(LP.Character)
			if original then
				local attrW = original:GetAttribute("BaseSizeW")
				local attrH = original:GetAttribute("BaseSizeH")
				if attrW and attrH then
					original.Size = UDim2.fromScale(attrW, attrH)
				end
				
				for _, d in ipairs(original:GetDescendants()) do
					if d:IsA("GuiObject") then
						d.Visible = true
					end
				end
			end
		end
	end
	
	OGNameTags = vape.Categories.Render:CreateModule({
		Name = 'OGNameTags',
		Function = function(callback)
			if callback then
				if LP.Character then
					setup(LP.Character)
				end
				
				OGNameTags:Clean(LP.CharacterAdded:Connect(function(char)
					setup(char)
				end))
			else
				cleanup()
			end
		end,
		Tooltip = 'Custom nametag with rank icon and winstreak (lobby only)'
	})
	
	local TitleSizeSlider = OGNameTags:CreateSlider({
		Name = 'Title Scale',
		Min = 1.0,
		Max = 1.5,
		Default = 1.17,
		Decimal = 100,
		Function = function(val)
			ORIGINAL_NAMETAG_SCALE = val
			if LP.Character and OGNameTags.Enabled then
				local original = findLocalOriginalNametag(LP.Character)
				if original then
					scaleOriginalNametagSlightly(original)
					fixRoleTextScaling(original)
				end
			end
		end,
		Tooltip = 'Scale original nametag to make title/role bigger'
	})
end)

run(function()
	local TC
	local list
	local TABLE = {}
	local old
	TC = vape.Categories.Render:CreateModule({
	Name = "TitleChanger",
	Function = function(callback)
		if callback then
			if old then else old = lplr:GetAttribute("TitleType") end
				local att = list.Value or ""
				lplr:SetAttribute("TitleType",att)
				task.wait(.85) 
				if lplr:GetAttribute("TitleType") == old then
					att = list.Value or ""
					lplr:SetAttribute("TitleType",att)
				end
			else
				lplr:SetAttribute("TitleType",old)
				old = nil
			end
		end,
		Tooltip ='Client Sided Titles :D'
	})
	for _, v in pairs(bedwars.TitleTypes) do
		TABLE[#TABLE+1] = v
	end
	list = TC:CreateDropdown({
		Name = "Titles",
		List = TABLE,
		Function = function()
			if old then else old = lplr:GetAttribute("TitleType") end
				lplr:SetAttribute("TitleType",list.Value)
			end,
		})
end)

run(function()
	local LeaderboardSpoof
	local RS = game.ReplicatedStorage

	local CURRENT_BOARD = "Ranked"
	local CUSTOM_POSITION = 1
	local CUSTOM_STAT = 5000
	local SHOW_IN_LIST = true
	local savedFullLeaderboards = nil

	local ClientStore
	pcall(function() ClientStore = bedwars.Store end)

	local function getBoardKey()
		if CURRENT_BOARD == "Ranked" then
			local key = "RankPoints_S15"
			pcall(function()
				key = require(RS.TS.rank["rank-util"]).RankUtil.activeRankMeta.leaderboard
			end)
			return key, true
		elseif CURRENT_BOARD == "Overall Wins" then
			return "OverallWins", false
		elseif CURRENT_BOARD == "Monthly Wins" then
			return "Wins", false
		elseif CURRENT_BOARD == "Top Gifters" then
			return "gift_leaderboard", false
		end
		return nil, false
	end

	local function computeRankDisplay(totalRP)
		local result = nil
		pcall(function()
			local RankMeta = require(RS.TS.rank["rank-meta"]).RankMeta
			local divisionIndex = math.min(math.floor(totalRP / 100), 24) 
			local remainder = totalRP - divisionIndex * 100            
			local rankInfo = RankMeta[divisionIndex]
			if rankInfo then
				result = {
					image = rankInfo.image,
					rankName = rankInfo.name,
					rankStatValue = remainder,   
				}
			end
		end)
		return result
	end

	local function doDispatch()
		if not ClientStore then return end
		local boardKey, isRanked = getBoardKey()
		if not boardKey then return end

		local state = ClientStore:getState()
		local currentLeaderboards = state.Leaderboard and state.Leaderboard.leaderboards

		if not savedFullLeaderboards and currentLeaderboards then
			savedFullLeaderboards = {}
			for k, v in pairs(currentLeaderboards) do
				savedFullLeaderboards[k] = v
			end
		end

		local lp = game.Players.LocalPlayer
		local rankDisplay = isRanked and computeRankDisplay(CUSTOM_STAT) or nil

		local localUser = {
			username = lp.Name,
			avatarImage = "rbxthumb://type=AvatarHeadShot&id=" .. lp.UserId .. "&w=60&h=60",
			statValue = rankDisplay and rankDisplay.rankStatValue or CUSTOM_STAT,  
			userId = lp.UserId,
		}
		if rankDisplay then
			localUser.statRank = rankDisplay
		end

		local newLeaderboards = {}
		if currentLeaderboards then
			for k, v in pairs(currentLeaderboards) do
				newLeaderboards[k] = v
			end
		end

		local currentBoardData = currentLeaderboards and currentLeaderboards[boardKey]
		local users = {}
		if currentBoardData and currentBoardData.users then
			for _, u in ipairs(currentBoardData.users) do
				if u.userId ~= lp.UserId then
					table.insert(users, u)
				end
			end
		end

		if SHOW_IN_LIST then
			local pos = math.max(1, math.min(CUSTOM_POSITION, #users + 1))
			table.insert(users, pos, localUser)
		end

		local newData = {
			lastRefresh = os.time(),
			users = users,
			leaderboardPosition = CUSTOM_POSITION,
			localStatValue = rankDisplay and rankDisplay.rankStatValue or CUSTOM_STAT,  
		}
		if rankDisplay then
			newData.localStatRank = rankDisplay
		end
		if currentBoardData and currentBoardData.nextReset then
			newData.nextReset = currentBoardData.nextReset
		end

		newLeaderboards[boardKey] = newData

		ClientStore:dispatch({
			type = "UpdateAllLeaderboards",
			leaderboards = newLeaderboards,
		})
	end

	local function doRevert()
		if not ClientStore or not savedFullLeaderboards then return end
		ClientStore:dispatch({
			type = "UpdateAllLeaderboards",
			leaderboards = savedFullLeaderboards,
		})
		savedFullLeaderboards = nil
	end

	LeaderboardSpoof = vape.Categories.Minigames:CreateModule({
		Name = "LeaderboardSpoof",
		Function = function(enabled)
			if enabled then doDispatch() else doRevert() end
		end,
		Tooltip = "Spoof your leaderboard stats (client sided only)"
	})

	LeaderboardSpoof:CreateDropdown({
		Name = "Board",
		List = {"Ranked", "Overall Wins", "Monthly Wins", "Top Gifters"},
		Default = "Ranked",
		Function = function(val)
			CURRENT_BOARD = val
			if LeaderboardSpoof.Enabled then doDispatch() end
		end
	})

	LeaderboardSpoof:CreateSlider({
		Name = "Position",
		Min = 1,
		Max = 200,
		Default = 1,
		Decimal = 1,
		Function = function(val)
			CUSTOM_POSITION = math.floor(val)
			if LeaderboardSpoof.Enabled then doDispatch() end
		end
	})

	LeaderboardSpoof:CreateSlider({
		Name = "Stat Value",
		Min = 1,
		Max = 4000,
		Default = 2400,
		Decimal = 1,
		Function = function(val)
			CUSTOM_STAT = math.floor(val)
			if LeaderboardSpoof.Enabled then doDispatch() end
		end
	})

	LeaderboardSpoof:CreateToggle({
		Name = "Show In List",
		Default = true,
		Function = function(state)
			SHOW_IN_LIST = state
			if LeaderboardSpoof.Enabled then doDispatch() end
		end
	})
end)

run(function()
	local NametagSpoof
	local SpoofRankDropdown

	local lplr = game.Players.LocalPlayer
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")

	local BedwarsImageId = require(ReplicatedStorage.TS.image["image-id"]).BedwarsImageId

	local RANK_MAP = {
		Bronze = "BRONZE_RANK",
		Silver = "SILVER_RANK",
		Gold = "GOLD_RANK",
		Platinum = "PLATINUM_RANK",
		Diamond = "DIAMOND_RANK",
		Emerald = "EMERALD_RANK",
		Nightmare = "NIGHTMARE_RANK"
	}

	local loop

	local function findNametag(char)
		local head = char:FindFirstChild("Head")
		if not head then return nil end

		for _, gui in ipairs(CollectionService:GetTagged("EntityNameTag")) do
			if gui:IsA("BillboardGui") and (gui.Adornee == head or gui:IsDescendantOf(char)) then
				return gui
			end
		end

		local direct = head:FindFirstChild("Nametag")
		if direct and direct:IsA("BillboardGui") then
			return direct
		end

		return nil
	end

	local function waitForNametag(char)
		for i = 1, 50 do 
			local tag = findNametag(char)
			if tag then return tag end
			task.wait(0.1)
		end
	end

	local function applySpoof(char)
		local head = char:WaitForChild("Head", 5)
		if not head then return end

		local original = waitForNametag(char)
		if not original then return end
		local old = head:FindFirstChild("NSSpoofGui")
		if old then old:Destroy() end
		local clone = original:Clone()
		clone.Name = "NSSpoofGui"
		clone.Adornee = head
		clone.Parent = head

		original.Enabled = false

		return clone
	end

	local function updateRank(spoof)
		if not spoof then return end

		for _, d in ipairs(spoof:GetDescendants()) do
			if d:IsA("ImageLabel") then
				for _, rankKey in pairs(RANK_MAP) do
					if d.Image == BedwarsImageId[rankKey] then
						d.Image = BedwarsImageId[RANK_MAP[SpoofRankDropdown.Value]]
					end
				end
			end
		end
	end

	local function startLoop(char)
		if loop then task.cancel(loop) end

		loop = task.spawn(function()
			local head = char:WaitForChild("Head", 5)
			if not head then return end

			while NametagSpoof.Enabled and char.Parent do
				task.wait(0.05)

				local spoof = head:FindFirstChild("NSSpoofGui")
				if spoof then
					updateRank(spoof)
				end
			end
		end)
	end

	local function cleanup(char)
		if loop then
			task.cancel(loop)
			loop = nil
		end

		if not char then return end
		local head = char:FindFirstChild("Head")
		if not head then return end

		local spoof = head:FindFirstChild("NSSpoofGui")
		if spoof then spoof:Destroy() end

		local original = findNametag(char)
		if original then
			original.Enabled = true
		end
	end

	NametagSpoof = vape.Categories.Render:CreateModule({
		Name = "NametagSpoof",
		Function = function(callback)
			if callback then
				if lplr.Character then
					task.spawn(function()
						local spoof = applySpoof(lplr.Character)
						if spoof then
							updateRank(spoof)
							startLoop(lplr.Character)
						end
					end)
				end

				NametagSpoof:Clean(lplr.CharacterAdded:Connect(function(char)
					task.spawn(function()
						local spoof = applySpoof(char)
						if spoof then
							updateRank(spoof)
							startLoop(char)
						end
					end)
				end))
			else
				cleanup(lplr.Character)
			end
		end
	})

	SpoofRankDropdown = NametagSpoof:CreateDropdown({
		Name = "Rank",
		List = {"Bronze","Silver","Gold","Platinum","Diamond","Emerald","Nightmare"},
		Default = "Nightmare"
	})
end)

run(function()
    local anim
    local asset
    local trackingConnection
    local lastPosition
    local NightmareEmote
    local cachedRootPart
    local cachedHumanoid
    local lastValidationCheck = 0
    
    NightmareEmote = vape.Categories.World:CreateModule({
        Name = "NightmareEmote",
        Function = function(call)
            if call then
                local l__GameQueryUtil__8
                if (not shared.CheatEngineMode) then 
                    l__GameQueryUtil__8 = require(game:GetService("ReplicatedStorage")['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil 
                else
                    local backup = {}; function backup:setQueryIgnored() end; l__GameQueryUtil__8 = backup;
                end
                local l__TweenService__9 = tweenService
                local player = playersService.LocalPlayer
                local character = player.Character
                
                if not character then 
                    NightmareEmote:Toggle() 
                    return 
                end
                
                local humanoid = character:WaitForChild("Humanoid")
                local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                
                if not rootPart then 
                    NightmareEmote:Toggle() 
                    return 
                end
                
                cachedRootPart = rootPart
                cachedHumanoid = humanoid
                lastPosition = rootPart.Position
                lastValidationCheck = 0
                
                local v10 = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("NightmareEmote"):Clone()
                asset = v10
                v10.Parent = game.Workspace
                
                local descendants = v10:GetDescendants()
                for _, part in ipairs(descendants) do
                    if part:IsA("BasePart") then
                        l__GameQueryUtil__8:setQueryIgnored(part, true)
                        part.CanCollide = false
                        part.Anchored = true
                    end
                end
                
                local l__Outer__15 = v10:FindFirstChild("Outer")
                if l__Outer__15 then
                    l__TweenService__9:Create(l__Outer__15, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
                        Orientation = l__Outer__15.Orientation + Vector3.new(0, 360, 0)
                    }):Play()
                end
                
                local l__Middle__16 = v10:FindFirstChild("Middle")
                if l__Middle__16 then
                    l__TweenService__9:Create(l__Middle__16, TweenInfo.new(12.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
                        Orientation = l__Middle__16.Orientation + Vector3.new(0, -360, 0)
                    }):Play()
                end
                
                anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://9191822700"
                anim = humanoid:LoadAnimation(anim)
                anim:Play()
                
                local movementThresholdSq = 0.1 * 0.1
                
                trackingConnection = runService.RenderStepped:Connect(function()
                    if not asset or not asset.Parent then 
                        if trackingConnection then
                            trackingConnection:Disconnect()
                        end
                        return 
                    end
                    
                    local currentTime = tick()
                    
                    if (currentTime - lastValidationCheck) > 0.5 then
                        if not character or not character.Parent then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        if not cachedRootPart or not cachedRootPart.Parent then
                            cachedRootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                        end
                        
                        if not cachedHumanoid or not cachedHumanoid.Parent then
                            cachedHumanoid = character:FindFirstChildOfClass("Humanoid")
                        end
                        
                        if not cachedRootPart or not cachedHumanoid or cachedHumanoid.Health <= 0 then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        lastValidationCheck = currentTime
                    end
                    
                    if lastPosition and cachedRootPart then
                        local currentPosition = cachedRootPart.Position
                        local dx = currentPosition.X - lastPosition.X
                        local dy = currentPosition.Y - lastPosition.Y
                        local dz = currentPosition.Z - lastPosition.Z
                        local distanceMovedSq = dx * dx + dy * dy + dz * dz
                        
                        if distanceMovedSq > movementThresholdSq then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        lastPosition = currentPosition
                    end
                    
                    if cachedRootPart then
                        v10:SetPrimaryPartCFrame(cachedRootPart.CFrame * CFrame.new(0, -3, 0))
                    end
                end)
                
                NightmareEmote:Clean(trackingConnection)
                
            else 
                if trackingConnection then
                    trackingConnection:Disconnect()
                    trackingConnection = nil
                end
                
                if anim then 
                    anim:Stop()
                    anim = nil
                end
                
                if asset then
                    asset:Destroy() 
                    asset = nil
                end
                
                lastPosition = nil
                cachedRootPart = nil
                cachedHumanoid = nil
                lastValidationCheck = 0
            end
        end
    })
end)

run(function()
	local PlayerProfileSpoof
	local PPSRankDropdown
	local PPSRpSlider
	local PPSLeaderboardSlider

	local lplr = game.Players.LocalPlayer
	local PP_ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PP_BedwarsImageId = require(PP_ReplicatedStorage.TS.image["image-id"]).BedwarsImageId

	local PP_RANK_MAP = {
		["Bronze 1"] = "BRONZE_RANK",   ["Bronze 2"] = "BRONZE_RANK",   ["Bronze 3"] = "BRONZE_RANK",
		["Silver 1"] = "SILVER_RANK",   ["Silver 2"] = "SILVER_RANK",   ["Silver 3"] = "SILVER_RANK",
		["Gold 1"]   = "GOLD_RANK",     ["Gold 2"]   = "GOLD_RANK",     ["Gold 3"]   = "GOLD_RANK",
		["Platinum 1"]= "PLATINUM_RANK",["Platinum 2"]= "PLATINUM_RANK",["Platinum 3"]= "PLATINUM_RANK",
		["Diamond 1"] = "DIAMOND_RANK", ["Diamond 2"] = "DIAMOND_RANK", ["Diamond 3"] = "DIAMOND_RANK",
		["Emerald 1"] = "EMERALD_RANK", ["Emerald 2"] = "EMERALD_RANK", ["Emerald 3"] = "EMERALD_RANK",
		["Nightmare"] = "NIGHTMARE_RANK"
	}

	local PP_RANK_COLORS = {
		Bronze   = Color3.fromRGB(188, 110, 60),
		Silver   = Color3.fromRGB(180, 180, 190),
		Gold     = Color3.fromRGB(255, 200, 0),
		Platinum = Color3.fromRGB(60, 220, 255),
		Diamond  = Color3.fromRGB(90, 150, 255),
		Emerald  = Color3.fromRGB(0, 200, 100),
	}

	local PP_RANK_IMAGES = {}
	for _, key in ipairs({"BRONZE_RANK","SILVER_RANK","GOLD_RANK","PLATINUM_RANK","DIAMOND_RANK","EMERALD_RANK","NIGHTMARE_RANK"}) do
		local img = PP_BedwarsImageId[key]
		if img and img ~= "" then PP_RANK_IMAGES[img] = true end
	end

	local ALL_RANK_NAMES = {}
	for k in pairs(PP_RANK_MAP) do ALL_RANK_NAMES[k] = true end

	local ppLoop = nil

	local function getBaseRank(rankName)
		return rankName:match("^(%a+)")
	end

	local function ppDoSpoof()
		local playerGui = lplr:FindFirstChild("PlayerGui")
		if not playerGui then return end

		local rankName    = PPSRankDropdown.Value
		local rankKey     = PP_RANK_MAP[rankName]
		local rpValue     = PPSRpSlider.Value
		local lbRank      = PPSLeaderboardSlider.Value
		local isNightmare = rankName == "Nightmare"
		local fillColor   = PP_RANK_COLORS[getBaseRank(rankName)]
		local fillScale   = math.clamp(rpValue / 100, 0, 1)

		for _, v in ipairs(playerGui:GetDescendants()) do
			if v:IsA("ImageLabel") and PP_RANK_IMAGES[v.Image] then
				v.Image = PP_BedwarsImageId[rankKey]

			elseif v:IsA("TextLabel") then
				local name = v.Name
				local txt  = v.Text
				if name == "CurrentRP" then
					if isNightmare then
						v.Visible = false
					else
						v.Visible = true
						v.Text = rpValue .. " RP / 100"
					end
				elseif name == "RankName" then
					v.Text = rankName
				elseif txt:find("Leaderboard Rank:") then
					v.Text = "Leaderboard Rank: " .. lbRank
				end

			elseif v:IsA("Frame") then
				local name = v.Name
				if name == "ProgressBar" then
					if isNightmare then
						v.Visible = false
					else
						v.Visible = true
						if fillColor then
							v.BackgroundColor3 = fillColor
						end
						v.Size = UDim2.new(fillScale, 0, v.Size.Y.Scale, v.Size.Y.Offset)
					end
				elseif name == "ProgressBarContainer" then
					v.Visible = not isNightmare
				end
			end
		end
	end

	local function ppStartLoop()
		if ppLoop then task.cancel(ppLoop) end
		ppLoop = task.spawn(function()
			while PlayerProfileSpoof.Enabled do
				task.wait(0.1)
				ppDoSpoof()
			end
		end)
	end

	local function ppCleanup()
		if ppLoop then task.cancel(ppLoop) ppLoop = nil end
	end

	PlayerProfileSpoof = vape.Categories.Minigames:CreateModule({
		Name = "PlayerProfileSpoof",
		Function = function(callback)
			if callback then ppStartLoop() else ppCleanup() end
		end,
		Tooltip = "Spoofs rank, RP bar color and leaderboard rank in your profile UI (client sided)"
	})

	PPSRankDropdown = PlayerProfileSpoof:CreateDropdown({
		Name = "Rank",
		List = {
			"Bronze 1","Bronze 2","Bronze 3",
			"Silver 1","Silver 2","Silver 3",
			"Gold 1","Gold 2","Gold 3",
			"Platinum 1","Platinum 2","Platinum 3",
			"Diamond 1","Diamond 2","Diamond 3",
			"Emerald 1","Emerald 2","Emerald 3",
			"Nightmare"
		},
		Default = "Nightmare"
	})

	PPSRpSlider = PlayerProfileSpoof:CreateSlider({
		Name = "RP", Min = 0, Max = 100, Default = 50
	})

	PPSLeaderboardSlider = PlayerProfileSpoof:CreateSlider({
		Name = "Leaderboard Rank", Min = 1, Max = 10000, Default = 1
	})
end)

run(function()
    local SetPlayerLevel
    local originalLevel = nil
    local customLevel = 1

    SetPlayerLevel = vape.Categories.Render:CreateModule({
        Name = "SetPlayerLevel",
        Function = function(state)
            if state then
                originalLevel = lplr:GetAttribute("PlayerLevel")
                lplr:SetAttribute("PlayerLevel", customLevel)
            else
                lplr:SetAttribute("PlayerLevel", originalLevel)
                originalLevel = nil
            end
        end,
        Tooltip = "Spoof your player level (client-sided)"
    })

    SetPlayerLevel:CreateSlider({
        Name = "Level",
        Min = 1,
        Max = 1000,
        Default = 1,
        Decimal = 1,
        Function = function(val)
            customLevel = math.floor(val)
            if SetPlayerLevel.Enabled then
                lplr:SetAttribute("PlayerLevel", customLevel)
            end
        end
    })
end)

run(function()
    local SetPlayerWins
    local originalWins = nil
    local customWins = 0
    local winsValue = nil 

    local function findWinsValue()
        local leaderstats = lplr:FindFirstChild("leaderstats")
        if leaderstats then
            return leaderstats:FindFirstChild("Wins") or leaderstats:FindFirstChild("OverallWins")
        end
        return nil
    end

    local function applyWinsOverride()
        winsValue = findWinsValue()
        if winsValue and winsValue:IsA("IntValue") then
            if originalWins == nil then
                originalWins = winsValue.Value
            end
            winsValue.Value = customWins
        else
            notif("SetPlayerWins", "Could not find Wins value", 3)
        end
    end

    local function restoreWins()
        if winsValue and winsValue:IsA("IntValue") and originalWins ~= nil then
            winsValue.Value = originalWins
        end
        winsValue = nil
        originalWins = nil
    end

    SetPlayerWins = vape.Categories.Minigames:CreateModule({
        Name = "SetPlayerWins",
        Function = function(state)
            if state then
                applyWinsOverride()
                SetPlayerWins:Clean(lplr.ChildAdded:Connect(function(child)
                    if child.Name == "leaderstats" and SetPlayerWins.Enabled then
                        applyWinsOverride()
                    end
                end))
            else
                restoreWins()
            end
        end,
        Tooltip = "Modify your wins in leaderstats (client‑sided)"
    })

    SetPlayerWins:CreateSlider({
        Name = "Wins",
        Min = 0,
        Max = 10000,
        Default = 0,
        Decimal = 1,
        Function = function(val)
            customWins = math.floor(val)
            if SetPlayerWins.Enabled and winsValue then
                winsValue.Value = customWins
            end
        end
    })
end)

run(function()
    local WinstreakSpoofer
    local Wins

    local oldSets = {
        Wins = nil,
        DoesExist = nil,
    }

    WinstreakSpoofer = vape.Categories.Minigames:CreateModule({
        Name = 'WinstreakSpoofer',
        Tooltip = 'Modifies/Adds your winstreak (client‑sided)',
        Function = function(callback)
            if callback then
                if not entitylib.isAlive then return end
                if lplr.Character.Head.Nametag then
                    local winStreakCounter = lplr.Character.Head.Nametag:FindFirstChild("WinStreakCounter")
                    if not winStreakCounter then
                        local main = Instance.new('Frame')
                        main.AnchorPoint = Vector2.new(1, 0.5)
                        main.Name = 'WinStreakCounter'
                        main.Size = UDim2.new(0.100000001, 0, 0.75, 0)
                        main.Position = UDim2.new(1.04999995, 0, 0.600000024, 0)
                        main.BackgroundTransparency = 1
                        main.Parent = lplr.Character.Head.Nametag
						main.LayoutOrder = 3
						main.BorderSizePixel =0
                        local icon = Instance.new('ImageLabel')
                        icon.BackgroundTransparency = 1
                        icon.Name = 'WinStreakFire'
                        icon.Size = UDim2.fromScale(1, 1)
                        icon.Image = 'rbxassetid://7101948108'
                        icon.ScaleType = Enum.ScaleType.Fit
						icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
                        icon.Parent = main
                        local value = Instance.new("TextLabel")
                        value.BackgroundTransparency = 1
                        value.Name = 'WinStreakValue'
                        value.Position = UDim2.fromScale(0.5, 0.375)
                        value.Size = UDim2.fromScale(0.8, 0.9)
                        value.FontFace = Font.new("Roboto", Enum.FontWeight.Bold)
                        value.TextSize = 8
                        oldSets.Wins = 0
                        value.Text = tostring(Wins.Value)
                        value.TextColor3 = Color3.fromRGB(255, 255, 255)
                        value.TextScaled = true
                        value.TextStrokeTransparency = 0.5
                        value.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        value.Parent = main
						value.AutoLocalize = false
						value.TextXAlignment = Enum.TextXAlignment.Center
						value.AnchorPoint = Vector2.new(0.5,0)
                        oldSets.DoesExist = false
                    else
                        oldSets.DoesExist = true
                        oldSets.Wins = winStreakCounter.WinStreakValue.Text
                        winStreakCounter.WinStreakValue.Text = tostring(Wins.Value)
                    end
                end
            else
                if lplr.Character.Head.Nametag then
                    local winStreakCounter = lplr.Character.Head.Nametag:FindFirstChild("WinStreakCounter")
                    if winStreakCounter then
                        if oldSets.DoesExist then
                            winStreakCounter.WinStreakValue.Text = oldSets.Wins
                        else
                            winStreakCounter:Destroy()
                        end
                    end
                end
                oldSets.Wins = nil
                oldSets.DoesExist = nil
            end
        end
    })

    Wins = WinstreakSpoofer:CreateSlider({
        Name = "Wins",
        Min = 0,
        Max = 1000,
        Default = 0,
        Decimal = 1,
        Function = function(val)
            if WinstreakSpoofer.Enabled then
                if lplr.Character.Head.Nametag then
                    local winStreakCounter = lplr.Character.Head.Nametag:FindFirstChild("WinStreakCounter")
	                if not winStreakCounter then
                        local main = Instance.new('Frame')
                        main.AnchorPoint = Vector2.new(1, 0.5)
                        main.Name = 'WinStreakCounter'
                        main.Size = UDim2.new(0.100000001, 0, 0.75, 0)
                        main.Position = UDim2.new(1.04999995, 0, 0.600000024, 0)
                        main.BackgroundTransparency = 1
                        main.Parent = lplr.Character.Head.Nametag
						main.LayoutOrder = 3
						main.BorderSizePixel =0
                        local icon = Instance.new('ImageLabel')
                        icon.BackgroundTransparency = 1
                        icon.Name = 'WinStreakFire'
                        icon.Size = UDim2.fromScale(1, 1)
                        icon.Image = 'rbxassetid://7101948108'
                        icon.ScaleType = Enum.ScaleType.Fit
						icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
                        icon.Parent = main
                        local value = Instance.new("TextLabel")
                        value.BackgroundTransparency = 1
                        value.Name = 'WinStreakValue'
                        value.Position = UDim2.fromScale(0.5, 0.375)
                        value.Size = UDim2.fromScale(0.8, 0.9)
                        value.FontFace = Font.new("Roboto", Enum.FontWeight.Bold)
                        value.TextSize = 8
                        oldSets.Wins = 0
                        value.Text = tostring(Wins.Value)
                        value.TextColor3 = Color3.fromRGB(255, 255, 255)
                        value.TextScaled = true
                        value.TextStrokeTransparency = 0.5
                        value.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        value.Parent = main
						value.AutoLocalize = false
						value.TextXAlignment = Enum.TextXAlignment.Center
						value.AnchorPoint = Vector2.new(0.5,0)
                        oldSets.DoesExist = false
                    else
                        winStreakCounter.WinStreakValue.Text = tostring(val)
                    end
                end
            end
        end
    })
end)

run(function()
	local Headless
	local headlessLoop = nil

	local headAttachments = {HatAttachment=true,HairAttachment=true,FaceFrontAttachment=true,FaceCenterAttachment=true,FaceBackAttachment=true}
	local removeAccs = false

	local function applyHeadless(char)
		if not char then return end
		local head = char:FindFirstChild("Head")
		if not head then return end
		head.Transparency = 1
		local face = head:FindFirstChild('face')
		if face and face:IsA("Decal") then
			face.Transparency = 1
		end
		if removeAccs then
			for _, acc in ipairs(char:GetChildren()) do
				if acc:IsA("Accessory") then
					local handle = acc:FindFirstChild("Handle")
					if handle then
						for _, att in ipairs(handle:GetChildren()) do
							if att:IsA("Attachment") and headAttachments[att.Name] then
								handle.Transparency = 1
								for _, d in ipairs(handle:GetChildren()) do
									if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
								end
								break
							end
						end
					end
				end
			end
		end
	end

	Headless = vape.Categories.Utility:CreateModule({
		PerformanceModeBlacklisted = true,
		Name = 'Headless',
		Tooltip = 'free headless 2026',
		Function = function(callback)
			if callback then
				if headlessLoop then task.cancel(headlessLoop) end
				headlessLoop = task.spawn(function()
					while Headless.Enabled do
						applyHeadless(lplr.Character)
						task.wait(0.1)
					end
				end)
				Headless:Clean(lplr.CharacterAdded:Connect(function(char)
					applyHeadless(char)
				end))
			else
				if headlessLoop then
					task.cancel(headlessLoop)
					headlessLoop = nil
				end
				local char = lplr.Character
				if char then
					local head = char:FindFirstChild("Head")
					if head then
						head.Transparency = 0
						local face = head:FindFirstChild('face')
						if face and face:IsA("Decal") then
							face.Transparency = 0
						end
					end
					for _, acc in ipairs(char:GetChildren()) do
						if acc:IsA("Accessory") then
							local handle = acc:FindFirstChild("Handle")
							if handle then
								handle.Transparency = 0
								for _, d in ipairs(handle:GetChildren()) do
									if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
								end
							end
						end
					end
				end
			end
		end,
		Default = false
	})

	Headless:CreateToggle({
		Name = "Remove Accessories",
		Default = false,
		Function = function(state)
			removeAccs = state
			if Headless.Enabled then
				applyHeadless(lplr.Character)
			end
		end
	})
end)

run(function()
	local StatsBoardSpoof
	local RANK_NAME, LB_RANK, RP, PLAYER_LEVEL, XP_CURRENT, XP_MAX, WINS, BED_BREAKS, FINAL_KILLS, HONOR

	local originals = {}
	local SBS_RS = game:GetService("ReplicatedStorage")
	local SBS_ImageId = require(SBS_RS.TS.image["image-id"]).BedwarsImageId
	local RANK_TO_IMAGE = {
		["Bronze 1"]="BRONZE_RANK",["Bronze 2"]="BRONZE_RANK",["Bronze 3"]="BRONZE_RANK",["Bronze 4"]="BRONZE_RANK",
		["Silver 1"]="SILVER_RANK",["Silver 2"]="SILVER_RANK",["Silver 3"]="SILVER_RANK",["Silver 4"]="SILVER_RANK",
		["Gold 1"]="GOLD_RANK",["Gold 2"]="GOLD_RANK",["Gold 3"]="GOLD_RANK",["Gold 4"]="GOLD_RANK",
		["Platinum 1"]="PLATINUM_RANK",["Platinum 2"]="PLATINUM_RANK",["Platinum 3"]="PLATINUM_RANK",["Platinum 4"]="PLATINUM_RANK",
		["Diamond 1"]="DIAMOND_RANK",["Diamond 2"]="DIAMOND_RANK",["Diamond 3"]="DIAMOND_RANK",["Diamond 4"]="DIAMOND_RANK",
		["Emerald 1"]="EMERALD_RANK",["Emerald 2"]="EMERALD_RANK",["Emerald 3"]="EMERALD_RANK",["Emerald 4"]="EMERALD_RANK",
		["Nightmare"]="NIGHTMARE_RANK",
	}

	local RANK_LIST = {
		"Bronze 1","Bronze 2","Bronze 3","Bronze 4",
		"Silver 1","Silver 2","Silver 3","Silver 4",
		"Gold 1","Gold 2","Gold 3","Gold 4",
		"Platinum 1","Platinum 2","Platinum 3","Platinum 4",
		"Diamond 1","Diamond 2","Diamond 3","Diamond 4",
		"Emerald 1","Emerald 2","Emerald 3","Emerald 4",
		"Nightmare"
	}

	local RANK_BAR_COLORS = {
		Bronze    = Color3.fromRGB(188, 110, 60),
		Silver    = Color3.fromRGB(180, 180, 190),
		Gold      = Color3.fromRGB(255, 200, 0),
		Platinum  = Color3.fromRGB(60, 220, 255),
		Diamond   = Color3.fromRGB(90, 150, 255),
		Emerald   = Color3.fromRGB(0, 200, 100),
		Nightmare = Color3.fromRGB(180, 0, 255),
	}
	local function getBaseRankSBS(rankName)
		return rankName:match("^(%a+)")
	end
	local function formatNumber(n)
		local s = tostring(n)
		local result = ""
		local len = #s
		for i = 1, len do
			result = result .. s:sub(i, i)
			if (len - i) % 3 == 0 and i ~= len then
				result = result .. ","
			end
		end
		return result
	end

	local function getBoard()
		local lobby = workspace:FindFirstChild("Lobby")
		if not lobby then return nil end
		local boards = lobby:FindFirstChild("Boards")
		if not boards then return nil end
		local sb = boards:FindFirstChild("StatsBoard")
		if not sb then return nil end
		local board = sb:FindFirstChild("Board")
		if not board then return nil end
		return board:FindFirstChild("StatsBoard")
	end

	local function getElements(gui)
		if not gui then return nil end
		local outer = gui:FindFirstChild("1")
		if not outer then return nil end
		local inner = outer:FindFirstChild("1")
		if not inner then return nil end
		local header = inner:FindFirstChild("1")
		local scroll = inner:FindFirstChild("AutoCanvasScrollingFrame")
		if not scroll or not header then return nil end

		local levelSection = scroll:FindFirstChild("3")
		local lvlPB = levelSection and levelSection:FindFirstChild("ProgressBar")

		local rankedSection = scroll:FindFirstChild("4")
		local rankDisplay = rankedSection and rankedSection:FindFirstChild("3")
		local rankInfoArea = rankDisplay and rankDisplay:FindFirstChild("3")
		local rankNameFrame = rankInfoArea and rankInfoArea:FindFirstChild("2")
		local rpFrame = rankInfoArea and rankInfoArea:FindFirstChild("3")
		local pbContainer = rpFrame and rpFrame:FindFirstChild("ProgressBarContainer")

		local globalSection = scroll:FindFirstChild("5")
		local statsContent = globalSection and globalSection:FindFirstChild("3")
		local basicStats = statsContent and statsContent:FindFirstChild("2")

		return {
			rankImage   = rankDisplay and rankDisplay:FindFirstChild("2"),
			levelLabel  = levelSection and levelSection:FindFirstChild("2"),
			xpLabel     = levelSection and levelSection:FindFirstChild("3"),
			lvlProgress = lvlPB and lvlPB:FindFirstChild("CurrProgress"),
			rankName    = rankNameFrame and rankNameFrame:FindFirstChild("RankName"),
			lbRank      = rankNameFrame and rankNameFrame:FindFirstChild("LeaderboardRank"),
			rpBar       = pbContainer and pbContainer:FindFirstChild("ProgressBar"),
			currentRP   = rpFrame and rpFrame:FindFirstChild("CurrentRP"),
			honorVal    = basicStats and basicStats:FindFirstChild("2") and basicStats:FindFirstChild("2"):FindFirstChild("5"),
			winsVal     = basicStats and basicStats:FindFirstChild("3") and basicStats:FindFirstChild("3"):FindFirstChild("5"),
			bedVal      = basicStats and basicStats:FindFirstChild("4") and basicStats:FindFirstChild("4"):FindFirstChild("5"),
			killsVal    = basicStats and basicStats:FindFirstChild("5") and basicStats:FindFirstChild("5"):FindFirstChild("5"),
		}
	end

	local function readRealStats()
		local gui = getBoard()
		if not gui then return end
		local e = getElements(gui)
		if not e then return end
		if e.levelLabel then PLAYER_LEVEL = tonumber(e.levelLabel.Text:match("(%d+)")) or 1 end
		if e.xpLabel then
			local cur, max = e.xpLabel.Text:match("(%d+)%s*/%s*(%d+)")
			XP_CURRENT = tonumber(cur) or 0
			XP_MAX = tonumber(max) or 1
		end
		if e.rankName then RANK_NAME = e.rankName.Text end
		if e.lbRank then LB_RANK = tonumber(e.lbRank.Text:gsub(",",""):match("(%d+)")) or 1 end
		if e.currentRP then RP = tonumber(e.currentRP.Text:match("(%d+)")) or 0 end
		if e.honorVal then HONOR = tonumber(e.honorVal.Text) or 0 end
		if e.winsVal then WINS = tonumber(e.winsVal.Text) or 0 end
		if e.bedVal then BED_BREAKS = tonumber(e.bedVal.Text) or 0 end
		if e.killsVal then FINAL_KILLS = tonumber(e.killsVal.Text) or 0 end
	end

	local function applySpoof()
		local gui = getBoard()
		if not gui then
			notif({Title = "StatsBoardSpoof", Message = "Board not found! Make sure you are in the Lobby.", Duration = 3})
			return
		end
		local e = getElements(gui)
		if not e then return end

		for k, v in pairs(e) do
			if v and v:IsA("TextLabel") then
				originals[k] = v.Text
			elseif v and v:IsA("Frame") then
				originals[k] = v.Size
			elseif v and v:IsA("ImageLabel") then
				originals[k] = v.Image
			end
		end

		if e.rankImage then
			local imgKey = RANK_TO_IMAGE[RANK_NAME]
			if imgKey then e.rankImage.Image = SBS_ImageId[imgKey] end
		end
		if e.levelLabel  then e.levelLabel.Text  = "Player Level " .. PLAYER_LEVEL end
		if e.xpLabel     then e.xpLabel.Text     = XP_CURRENT .. " / " .. XP_MAX end
		if e.lvlProgress then e.lvlProgress.Size = UDim2.new(math.clamp(XP_CURRENT / XP_MAX, 0, 1), 0, 1, 0) end
		if e.rankName    then e.rankName.Text    = RANK_NAME end
		if e.lbRank      then e.lbRank.Text      = 'Leaderboard Rank: <b><font color="rgb(185,188,255)">' .. formatNumber(LB_RANK) .. "</font></b>" end
		local isNightmare = RANK_NAME == "Nightmare"
		if e.currentRP then
			if isNightmare then
				e.currentRP.Visible = false
			else
				e.currentRP.Visible = true
				e.currentRP.Text = '<b><font color="#ffffff">' .. RP .. " RP</font></b> / 100"
			end
		end
		if e.rpBar then
			if isNightmare then
				e.rpBar.Parent.Visible = false
			else
				e.rpBar.Parent.Visible = true
				e.rpBar.Size = UDim2.new(RP / 100, 0, 1, 0)
				local barColor = RANK_BAR_COLORS[getBaseRankSBS(RANK_NAME or "")]
				if barColor then e.rpBar.BackgroundColor3 = barColor end
			end
		end
		if e.honorVal    then e.honorVal.Text    = tostring(HONOR) end
		if e.winsVal     then e.winsVal.Text     = tostring(WINS) end
		if e.bedVal      then e.bedVal.Text      = tostring(BED_BREAKS) end
		if e.killsVal    then e.killsVal.Text    = tostring(FINAL_KILLS) end
	end

	local function revertSpoof()
		local gui = getBoard()
		if not gui then return end
		local e = getElements(gui)
		if not e then return end
		for k, v in pairs(originals) do
			local elem = e[k]
			if elem then
				if elem:IsA("TextLabel") then elem.Text = v
				elseif elem:IsA("Frame") then elem.Size = v
				elseif elem:IsA("ImageLabel") then elem.Image = v end
			end
		end
		originals = {}
	end

	local sbsLoop = nil
	StatsBoardSpoof = vape.Categories.Minigames:CreateModule({
		Name = "StatsBoardSpoof",
		Tooltip = "Spoof your StatsBoard display (client-sided only)",
		Function = function(enabled)
			if enabled then
				readRealStats()
				if sbsLoop then task.cancel(sbsLoop) end
				sbsLoop = task.spawn(function()
					while StatsBoardSpoof.Enabled do
						applySpoof()
						task.wait(0.5)
					end
				end)
			else
				if sbsLoop then task.cancel(sbsLoop) sbsLoop = nil end
				revertSpoof()
				RANK_NAME, LB_RANK, RP, PLAYER_LEVEL, XP_CURRENT, XP_MAX, WINS, BED_BREAKS, FINAL_KILLS, HONOR = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
			end
		end
	})

	StatsBoardSpoof:CreateDropdown({
		Name = "Rank",
		List = RANK_LIST,
		Default = "Silver 3",
		Function = function(val)
			RANK_NAME = val
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Leaderboard Rank",
		Min = 1,
		Max = 100000,
		Default = 11469,
		Decimal = 1,
		Function = function(val)
			LB_RANK = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "RP",
		Min = 0,
		Max = 100,
		Default = 26,
		Decimal = 1,
		Function = function(val)
			RP = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Player Level",
		Min = 1,
		Max = 200,
		Default = 40,
		Decimal = 1,
		Function = function(val)
			PLAYER_LEVEL = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Wins",
		Min = 0,
		Max = 50000,
		Default = 621,
		Decimal = 1,
		Function = function(val)
			WINS = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Bed Breaks",
		Min = 0,
		Max = 50000,
		Default = 269,
		Decimal = 1,
		Function = function(val)
			BED_BREAKS = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Final Kills",
		Min = 0,
		Max = 100000,
		Default = 457,
		Decimal = 1,
		Function = function(val)
			FINAL_KILLS = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Honor",
		Min = 0,
		Max = 10000,
		Default = 2,
		Decimal = 1,
		Function = function(val)
			HONOR = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})
end)

run(function()
    local LARPKits
    local KITS_TO_OWN = {}
    local active = true
    local connection = nil
    local textList = nil

    -- [[ COMPLETE KIT LIST FROM OFFICIAL WIKI ]]
    local ALL_KITS = {
        "None", "Builder", "Barbarian", "Farmer Cletus", "Baker", "Archer",
        "Infernal Shielder", "Melody", "Pirate Davey", "Eldertree", "Lassy",
        "Grim Reaper", "Zeno", "Vulcan", "Trinity", "Axolotl Amy", "Vanessa",
        "Freiya", "Yuzi", "Miner", "Cyber", "Evelynn", "Hannah",
        "Warrior", "Bounty Hunter", "Beekeeper Beatrix", "Jade", "Raven",
        "Spirit Catcher", "Pyro", "Trapper", "Gompy", "Fisherman", "Jack",
        "Ares", "Santa", "Gingerbread Man", "Smoke", "Yeti", "Frosty",
        "Aery", "Metal Detector", "Alchemist", "Sheep Herder", "Crocowolf",
        "Conqueror", "Nyx", "Lucía", "Merchant Marco", "Dino Tamer Dom",
        "Cobalt", "Star Collector Stella", "Zephyr", "Void Regent", "Ember",
        "Lumen", "Lani", "Adetunde", "Agni", "Bekzat", "Caitlyn", "Davey",
        "Death Adder", "Kaida", "Marina", "Milo", "Nazar", "Noelle",
        "Nyoka", "Sheila", "Silas", "Spirit Assassin", "Styx", "Taliyah",
        "Terra", "Umbra", "Umeko", "Warden", "Whim", "Whisper", "Wizard",
        "Wren", "Xu'rot", "Yamini", "Zenith", "Zola"
    }

    local function getKitName(btn)
        local tag = btn:FindFirstChild("KitNameTag")
        if not tag then return nil end
        local lbl = tag:FindFirstChild("5") or tag:FindFirstChild("4")
        if lbl and lbl:IsA("TextLabel") then
            return lbl.Text
        end
        return nil
    end

    local function moveOwnedKits(notOwned, owned)
        if not notOwned or not owned then return 0 end
        local moved = 0
        for _, btn in ipairs(notOwned:GetChildren()) do
            if btn:IsA("ImageButton") then
                local name = getKitName(btn)
                if name then
                    for _, wantedKit in ipairs(KITS_TO_OWN) do
                        if string.lower(name) == string.lower(wantedKit) then
                            btn.Parent = owned
                            moved = moved + 1
                            break
                        end
                    end
                end
            end
        end
        return moved
    end

    local function applyKits()
        local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local app = pg:FindFirstChild("KitShopApp")
        if not app then return end
        local list = app:FindFirstChild("LobbyKitShopItemList", true)
        if not list then return end
        local notOwned = list:FindFirstChild("NotUnlockedKits")
        local owned = list:FindFirstChild("UnlockedKits")
        if notOwned and owned then
            moveOwnedKits(notOwned, owned)
        end
    end

    local function startAutoMove()
        if connection then return end
        connection = game:GetService("RunService").Stepped:Connect(function()
            if not active then return end
            applyKits()
        end)
    end

    local function stopAutoMove()
        if connection then
            connection:Disconnect()
            connection = nil
        end
    end

    LARPKits = vape.Categories.Minigames:CreateModule({
        Name = "LARPKits",
        Tooltip = "Client‑side only – moves kits visually to 'Owned' in lobby",
        Function = function(callback)
            active = callback
            if callback then
                startAutoMove()
                applyKits()
            else
                stopAutoMove()
            end
        end
    })

    textList = LARPKits:CreateTextList({
        Name = "Kits To Own",
        Placeholder = "Type kit names here e.g. Ragnar",
        Default = ALL_KITS,
        Function = function(list)
            KITS_TO_OWN = {}
            for _, name in ipairs(list) do
                if name and name ~= "" then
                    table.insert(KITS_TO_OWN, name)
                end
            end
            if active then
                applyKits()
            end
        end
    })

    startAutoMove()
    applyKits()
end)

run(function()
    ----------------------------------------------------------------------------------------------
    -- AutoQueue - the lobby half of AutoWin.
    --
    -- BedWars plays matches in a different place to this one, so games/6872274481.lua (and the
    -- AutoWin module inside it) is not loaded here at all, and the two places do not even share a
    -- config file. Being teleported back to the lobby at the end of a match therefore used to end
    -- an unattended run outright: nothing on this side knew a run was in progress, so nothing
    -- queued the next game.
    --
    -- AutoWin leaves a note on disk saying it is running and which queue it wants. This reads that
    -- note, and with Resume from AutoWin on it switches itself on off the back of it - which is
    -- what actually closes the loop and lets the script keep playing for hours without anyone at
    -- the keyboard.
    ----------------------------------------------------------------------------------------------
    local AutoQueue
    local Mode
    local Resume
    local Delay
    local Notify

    local STATE_FILE = 'aetherv2/profiles/autowin.json'

    local function readState()
        if not isfile or not isfile(STATE_FILE) then return nil end
        local ok, data = pcall(function()
            return httpService:JSONDecode(readfile(STATE_FILE))
        end)
        if ok and type(data) == 'table' then return data end
        return nil
    end

    local function queueList()
        local list = {'From AutoWin', 'Random'}
        pcall(function()
            local ids = {}
            for id, meta in bedwars.QueueMeta do
                if not meta.disabled and not meta.voiceChatOnly then
                    table.insert(ids, id)
                end
            end
            table.sort(ids)
            for _, id in ipairs(ids) do
                table.insert(list, id)
            end
        end)
        return list
    end

    local function randomMode()
        local modes = {}
        pcall(function()
            for id, meta in bedwars.QueueMeta do
                if not meta.disabled and not meta.voiceChatOnly and not meta.rankCategory then
                    table.insert(modes, id)
                end
            end
        end)
        if #modes == 0 then return nil end
        return modes[math.random(1, #modes)]
    end

    -- Which queue to join. 'From AutoWin' follows whatever the match side asked for, including the
    -- queue it was last actually playing, so the mode only has to be set in one place.
    local function resolveMode()
        local wanted = Mode.Value
        if wanted == 'From AutoWin' then
            local state = readState()
            wanted = state and state.queue or 'Random'
            if wanted == 'Current' then
                wanted = (state and state.fallback) or 'Random'
            end
        end
        if wanted == 'Random' or wanted == nil then
            return randomMode()
        end
        return wanted
    end

    -- BedWars only accepts a queue request from the party leader, and only when the party is not
    -- already queued or in a custom match. Firing it blind does nothing but produce errors, so all
    -- three are checked and the loop simply waits when any of them says no.
    local function canQueue()
        local ok, allowed = pcall(function()
            local state = bedwars.Store:getState()
            if state.Game and state.Game.customMatch then return false end
            if not state.Party or not state.Party.leader then return false end
            if state.Party.leader.userId ~= lplr.UserId then return false end
            return state.Party.queueState == 0
        end)
        return ok and allowed
    end

    AutoQueue = vape.Categories.Utility:CreateModule({
        Name = 'AutoQueue',
        Function = function(callback)
            if callback then
                AutoQueue:Clean(task.spawn(function()
                    -- Settle first. Landing in the lobby straight off a match teleport means the
                    -- party and queue state are still arriving, and a request sent into that is
                    -- simply dropped.
                    task.wait(Delay.Value)
                    while AutoQueue.Enabled do
                        if canQueue() then
                            local mode = resolveMode()
                            if mode then
                                if Notify.Enabled then
                                    notif('AutoQueue', 'Queueing for '..tostring(mode), 4)
                                end
                                pcall(function()
                                    bedwars.QueueController:joinQueue(mode)
                                end)
                                -- Give the request time to be accepted before asking again;
                                -- canQueue goes false the moment it is, so this only ever retries
                                -- a request that genuinely did not land.
                                task.wait(8)
                            else
                                task.wait(2)
                            end
                        else
                            task.wait(2)
                        end
                    end
                end))
            end
        end,
        Tooltip = 'Queues a match from the lobby on its own, which is what lets AutoWin keep playing'
    })
    Mode = AutoQueue:CreateDropdown({
        Name = 'Gamemode',
        List = queueList(),
        Tooltip = 'Which queue to join. From AutoWin follows the gamemode set on the match side'
    })
    Delay = AutoQueue:CreateSlider({
        Name = 'Queue delay',
        Min = 1,
        Max = 30,
        Default = 5,
        Suffix = ' seconds',
        Tooltip = 'How long to settle in the lobby before queueing, so the party state has arrived'
    })
    Resume = AutoQueue:CreateToggle({
        Name = 'Resume from AutoWin',
        Default = true,
        Tooltip = 'Turns AutoQueue on by itself when AutoWin was running as you left the match'
    })
    Notify = AutoQueue:CreateToggle({
        Name = 'Notifications',
        Default = true,
        Tooltip = 'Say which mode is being queued'
    })

    -- Pick the run back up. Deferred because the config load runs after modules are registered and
    -- would otherwise toggle this straight back off; a re-check of the note afterwards means the
    -- user's own saved state still wins if they had explicitly turned AutoQueue off.
    task.delay(6, function()
        if not Resume.Enabled or AutoQueue.Enabled then return end
        local state = readState()
        if state and state.enabled and state.resume then
            if Notify.Enabled then
                notif('AutoQueue', 'AutoWin was running - queueing the next match', 6)
            end
            AutoQueue:Toggle()
        end
    end)
end)
