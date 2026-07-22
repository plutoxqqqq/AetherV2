local GuiLibrary = shared.GuiLibrary
local blockraycast = RaycastParams.new()
blockraycast.FilterType = Enum.RaycastFilterType.Whitelist
local players = game:GetService("Players")
local getasset = getsynasset or getcustomasset or function(location) return "rbxasset://"..location end
local textservice = game:GetService("TextService")
local repstorage = game:GetService("ReplicatedStorage")
local lplr = players.LocalPlayer
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local cam = workspace.CurrentCamera
local chatconnection
local modules = {}
local targetinfo = shared.VapeTargetInfo
local uis = game:GetService("UserInputService")
local mouse = lplr:GetMouse()
local remotes = {}
local bedwars = {}
local inventories = {}
local lagbackevent = Instance.new("BindableEvent")
local vec3 = Vector3.new
local cfnew = CFrame.new
local entity = shared.vapeentity
local uninjectflag = false
local matchstatetick = 0
local queueteleport = syn and syn.queue_on_teleport or queue_on_teleport or fluxus and fluxus.queue_on_teleport or function() end
local teleportfunc
local clients = {
	ChatStrings1 = {
		["KVOP25KYFPPP4"] = "vape",
		["IO12GP56P4LGR"] = "future",
		["RQYBPTYNURYZC"] = "rektsky"
	},
	ChatStrings2 = {
		["vape"] = "KVOP25KYFPPP4",
		["future"] = "IO12GP56P4LGR",
		["rektsky"] = "RQYBPTYNURYZC"
	},
	ClientUsers = {}
}
local requestfunc = syn and syn.request or http and http.request or http_request or fluxus and fluxus.request or getgenv().request or request
local checkpublicreponum = 0
local checkpublicrepo
checkpublicrepo = function(id)
	local suc, req = pcall(function() return requestfunc({
		Url = "https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/CustomModules/6872274481.lua",
		Method = "GET"
	}) end)
	if not suc then
		checkpublicreponum = checkpublicreponum + 1
		spawn(function()
			local textlabel = Instance.new("TextLabel")
			textlabel.Size = UDim2.new(1, 0, 0, 36)
			textlabel.Text = "Loading CustomModule Failed!, Attempts : "..checkpublicreponum
			textlabel.BackgroundTransparency = 1
			textlabel.TextStrokeTransparency = 0
			textlabel.TextSize = 30
			textlabel.Font = Enum.Font.SourceSans
			textlabel.TextColor3 = Color3.new(1, 1, 1)
			textlabel.Position = UDim2.new(0, 0, 0, -36)
			textlabel.Parent = GuiLibrary["MainGui"]
			task.wait(2)
			textlabel:Remove()
		end)
		task.wait(2)
		return checkpublicrepo(id)
	end
	if req.StatusCode == 200 then
		return req.Body
	end
	return nil
end
local publicrepo = checkpublicrepo(game.PlaceId)
if publicrepo then
    loadstring(publicrepo)()
end


local function createwarning(title, text, delay)
	local suc, res = pcall(function()
		local frame = GuiLibrary["CreateNotification"](title, text, delay, "assets/WarningNotification.png")
		frame.Frame.Frame.ImageColor3 = Color3.fromRGB(255, 215, 0)
		return frame
	end)
	return (suc and res)
end

createwarning("Snoopy", "Snoopy Private Loaded", 5)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local yes = Players.LocalPlayer.Name
local ChatTag = {}
ChatTag[yes] =
    {
        TagText = "Vape Private",
        TagColor = Color3.new(0.145098, 0.007843, 0.145098),
    }



    local oldchanneltab
    local oldchannelfunc
    local oldchanneltabs = {}


for i, v in pairs(getconnections(ReplicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent)) do
    if
        v.Function
        and #debug.getupvalues(v.Function) > 0
        and type(debug.getupvalues(v.Function)[1]) == "table"
        and getmetatable(debug.getupvalues(v.Function)[1])
        and getmetatable(debug.getupvalues(v.Function)[1]).GetChannel
    then
        oldchanneltab = getmetatable(debug.getupvalues(v.Function)[1])
        oldchannelfunc = getmetatable(debug.getupvalues(v.Function)[1]).GetChannel
        getmetatable(debug.getupvalues(v.Function)[1]).GetChannel = function(Self, Name)
            local tab = oldchannelfunc(Self, Name)
            if tab and tab.AddMessageToChannel then
                local addmessage = tab.AddMessageToChannel
                if oldchanneltabs[tab] == nil then
                    oldchanneltabs[tab] = tab.AddMessageToChannel
                end
                tab.AddMessageToChannel = function(Self2, MessageData)
                    if MessageData.FromSpeaker and Players[MessageData.FromSpeaker] then
                        if ChatTag[Players[MessageData.FromSpeaker].Name] then
                            MessageData.ExtraData = {
                                NameColor = Players[MessageData.FromSpeaker].Team == nil and Color3.new(128,0,128)
                                    or Players[MessageData.FromSpeaker].TeamColor.Color,
                                Tags = {
                                    table.unpack(MessageData.ExtraData.Tags),
                                    {
                                        TagColor = ChatTag[Players[MessageData.FromSpeaker].Name].TagColor,
                                        TagText = ChatTag[Players[MessageData.FromSpeaker].Name].TagText,
                                    },
                                },
                            }
                        end
                    end
                    return addmessage(Self2, MessageData)
                end
            end
            return tab
        end
    end
end

		local cachedassets = {}
local function getcustomassetfunc(path)
	if not betterisfile(path) then
		task.spawn(function()
			local textlabel = Instance.new("TextLabel")
			textlabel.Size = UDim2.new(1, 0, 0, 36)
			textlabel.Text = "Downloading "..path
			textlabel.BackgroundTransparency = 1
			textlabel.TextStrokeTransparency = 0
			textlabel.TextSize = 30
			textlabel.Font = Enum.Font.SourceSans
			textlabel.TextColor3 = Color3.new(1, 1, 1)
			textlabel.Position = UDim2.new(0, 0, 0, -36)
			textlabel.Parent = GuiLibrary["MainGui"]
			repeat task.wait() until betterisfile(path)
			textlabel:Remove()
		end)
		local req = requestfunc({
			Url = "https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/"..path:gsub("vape/assets", "assets"),
			Method = "GET"
		})
		writefile(path, req.Body)
	end
	if cachedassets[path] == nil then
		cachedassets[path] = getasset(path) 
	end
	return cachedassets[path]
end

local function getremote(tab)
	for i,v in pairs(tab) do
		if v == "Client" then
			return tab[i + 1]
		end
	end
	return ""
end
local function runcode(func)
	func()
end	
	
local function createwarning(title, text, delay)
	local suc, res = pcall(function()
		local frame = GuiLibrary["CreateNotification"](title, text, delay, "assets/WarningNotification.png")
		frame.Frame.Frame.ImageColor3 = Color3.fromRGB(201, 126, 14)
		return frame
	end)
	return (suc and res)
end

local function targetCheck(plr)
	return plr and plr.Humanoid and plr.Humanoid.Health > 0 and plr.Character:FindFirstChild("ForceField") == nil
end


local function targetCheck(plr)
	return plr and plr.Humanoid and plr.Humanoid.Health > 0 and plr.Character:FindFirstChild("ForceField") == nil
end

local function isAliveOld(plr, alivecheck)
	if plr then
		return plr and plr.Character and plr.Character.Parent ~= nil and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Head") and plr.Character:FindFirstChild("Humanoid")
	end
	return entity.isAlive
end



local betterisfile = function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil
end

local cachedassets = {}
local function getcustomassetfunc(path)
	if not betterisfile(path) then
		task.spawn(function()
			local textlabel = Instance.new("TextLabel")
			textlabel.Size = UDim2.new(1, 0, 0, 36)
			textlabel.Text = "Downloading "..path
			textlabel.BackgroundTransparency = 1
			textlabel.TextStrokeTransparency = 0
			textlabel.TextSize = 30
			textlabel.Font = Enum.Font.SourceSans
			textlabel.TextColor3 = Color3.new(1, 1, 1)
			textlabel.Position = UDim2.new(0, 0, 0, -36)
			textlabel.Parent = GuiLibrary["MainGui"]
			repeat task.wait() until betterisfile(path)
			textlabel:Remove()
		end)
		local req = requestfunc({
			Url = "https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/"..path:gsub("vape/assets", "assets"),
			Method = "GET"
		})
		writefile(path, req.Body)
	end
	if cachedassets[path] == nil then
		cachedassets[path] = getasset(path) 
	end
	return cachedassets[path]
end


local RunLoops = {RenderStepTable = {}, StepTable = {}, HeartTable = {}}
do
	function RunLoops:BindToRenderStep(name, num, func)
		if RunLoops.RenderStepTable[name] == nil then
			RunLoops.RenderStepTable[name] = game:GetService("RunService").RenderStepped:connect(func)
		end
	end

	function RunLoops:UnbindFromRenderStep(name)
		if RunLoops.RenderStepTable[name] then
			RunLoops.RenderStepTable[name]:Disconnect()
			RunLoops.RenderStepTable[name] = nil
		end
	end

	function RunLoops:BindToStepped(name, num, func)
		if RunLoops.StepTable[name] == nil then
			RunLoops.StepTable[name] = game:GetService("RunService").Stepped:connect(func)
		end
	end

	function RunLoops:UnbindFromStepped(name)
		if RunLoops.StepTable[name] then
			RunLoops.StepTable[name]:Disconnect()
			RunLoops.StepTable[name] = nil
		end
	end

	function RunLoops:BindToHeartbeat(name, num, func)
		if RunLoops.HeartTable[name] == nil then
			RunLoops.HeartTable[name] = game:GetService("RunService").Heartbeat:connect(func)
		end
	end

	function RunLoops:UnbindFromHeartbeat(name)
		if RunLoops.HeartTable[name] then
			RunLoops.HeartTable[name]:Disconnect()
			RunLoops.HeartTable[name] = nil
		end
	end
end

local workspace = game:GetService("Workspace")

       
repeat task.wait() until game:IsLoaded()
repeat task.wait() until shared.GuiLibrary
local GuiLibrary = shared.GuiLibrary
local vec3 = Vector3.new
local lplr = game:GetService("Players")
local ScriptSettings = {}
local UIS = game:GetService("UserInputService")
local COB = function(tab, argstable) 
    return GuiLibrary["ObjectsThatCanBeSaved"][tab.."Window"]["Api"].CreateOptionsButton(argstable)
end

local currentinventory = {
	["inventory"] = {
		["items"] = {},
		["armor"] = {},
		["hand"] = nil
	}
}
local repstorage = game:GetService("ReplicatedStorage")
local client = {}
local Client = require(repstorage.TS.remotes).default.Client
local function getremote(tab)
	for i,v in pairs(tab) do
		if v == "Client" then
			return tab[i + 1]
		end
	end
	return ""
end
local function runcode(func)
	func()
end	
local bedwars = {}
local arrowdodgedata
local getfunctions
						local OldClientGet 
local oldbreakremote
local oldbob
runcode(function()
    getfunctions = function()
		local Flamework = require(repstorage["rbxts_include"]["node_modules"]["@flamework"].core.out).Flamework
		repeat task.wait() until Flamework.isInitialized
        local KnitClient = debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 6)
        local Client = require(repstorage.TS.remotes).default.Client
        local InventoryUtil = require(repstorage.TS.inventory["inventory-util"]).InventoryUtil
        OldClientGet = getmetatable(Client).Get
        getmetatable(Client).Get = function(Self, remotename)
			local res = OldClientGet(Self, remotename)
			if uninjectflag then return res end
			if remotename == "DamageBlock" then
				return {
					["CallServerAsync"] = function(Self, tab)
						local block = bedwars["BlockController"]:getStore():getBlockAt(tab.blockRef.blockPosition)
						if block and block.Name == "bed" then
							if getWhitelistedBed(block) then
								return {andThen = function(self, func) 
									func("failed")
								end}
							end
						end
						return res:CallServerAsync(tab)
					end,
					["CallServer"] = function(Self, tab)
						local block = bedwars["BlockController"]:getStore():getBlockAt(tab.blockRef.blockPosition)
						if block and block.Name == "bed" then
							if getWhitelistedBed(block) then
								return {andThen = function(self, func) 
									func("failed")
								end}
							end
						end
						return res:CallServer(tab)
					end
				}
			elseif remotename == bedwars["AttackRemote"] then
				return {
					["instance"] = res["instance"],
					["SendToServer"] = function(Self, tab)
						local suc, plr = pcall(function() return players:GetPlayerFromCharacter(tab.entityInstance) end)
						if suc and plr then
							local playertype, playerattackable = WhitelistFunctions:CheckPlayerType(plr)
							if not playerattackable then 
								return nil
							end
						end
						if Reach["Enabled"] then
							local mag = (tab.validate.selfPosition.value - tab.validate.targetPosition.value).magnitude
							local newres = hashvec(tab.validate.selfPosition.value + (mag > 14.4 and (CFrame.lookAt(tab.validate.selfPosition.value, tab.validate.targetPosition.value).lookVector * 4) or Vector3.zero))
							tab.validate.selfPosition = newres
						end
						return res:SendToServer(tab)
					end
				}
			end
            return res
        end
		bedwars = {
			["AnimationUtil"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out["shared"].util["animation-util"]).AnimationUtil,
			["AngelUtil"] = require(repstorage.TS.games.bedwars.kit.kits.angel["angel-kit"]),
			["AppController"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out.client.controllers["app-controller"]).AppController,
			["AttackRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.SwordController)["attackEntity"])),
			["BatteryRemote"] = getremote(debug.getconstants(debug.getproto(debug.getproto(KnitClient.Controllers.BatteryController.KnitStart, 1), 1))),
			["BatteryEffectController"] = KnitClient.Controllers.BatteryEffectsController,
            ["BalloonController"] = KnitClient.Controllers.BalloonController,
            ["BlockController"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["block-engine"].out).BlockEngine,
            ["BlockController2"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["block-engine"].out.client.placement["block-placer"]).BlockPlacer,
            ["BlockEngine"] = require(lplr.PlayerScripts.TS.lib["block-engine"]["client-block-engine"]).ClientBlockEngine,
            ["BlockEngineClientEvents"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["block-engine"].out.client["block-engine-client-events"]).BlockEngineClientEvents,
			["BlockPlacementController"] = KnitClient.Controllers.BlockPlacementController,
            ["BedwarsKits"] = require(repstorage.TS.games.bedwars.kit["bedwars-kit-shop"]).BedwarsKitShop,
            ["BlockBreaker"] = KnitClient.Controllers.BlockBreakController.blockBreaker,
            ["BowTable"] = KnitClient.Controllers.ProjectileController,
			["BowConstantsTable"] = debug.getupvalue(KnitClient.Controllers.ProjectileController.enableBeam, 5),
			["ChestController"] = KnitClient.Controllers.ChestController,
			["ClickHold"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out.client.ui.lib.util["click-hold"]).ClickHold,
            ["ClientHandler"] = Client,
			["SharedConstants"] = require(repstorage.TS["shared-constants"]),
            ["ClientHandlerDamageBlock"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["block-engine"].out.remotes).BlockEngineRemotes.Client,
            ["ClientStoreHandler"] = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
			["ClientHandlerSyncEvents"] = require(lplr.PlayerScripts.TS["client-sync-events"]).ClientSyncEvents,
            ["CombatConstant"] = require(repstorage.TS.combat["combat-constant"]).CombatConstant,
			["CombatController"] = KnitClient.Controllers.CombatController,
			["ConsumeSoulRemote"] = getremote(debug.getconstants(KnitClient.Controllers.GrimReaperController.consumeSoul)),
			["ConstantManager"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out["shared"].constant["constant-manager"]).ConstantManager,
			["CooldownController"] = KnitClient.Controllers.CooldownController,
            ["damageTable"] = KnitClient.Controllers.DamageController,
			["DinoRemote"] = getremote(debug.getconstants(debug.getproto(KnitClient.Controllers.DinoTamerController.KnitStart, 3))),
			["DaoRemote"] = getremote(debug.getconstants(debug.getprotos(KnitClient.Controllers.DaoController.onEnable)[4])),
			["DamageController"] = KnitClient.Controllers.DamageController,
			["DamageIndicator"] = KnitClient.Controllers.DamageIndicatorController.spawnDamageIndicator,
			["DamageIndicatorController"] = KnitClient.Controllers.DamageIndicatorController,
			["DetonateRavenRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.RavenController).detonateRaven)),
            ["DropItem"] = getmetatable(KnitClient.Controllers.ItemDropController).dropItemInHand,
            ["DropItemRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.ItemDropController).dropItemInHand)),
            ["EatRemote"] = getremote(debug.getconstants(debug.getproto(getmetatable(KnitClient.Controllers.ConsumeController).onEnable, 1))),
            ["EquipItemRemote"] = getremote(debug.getconstants(debug.getprotos(shared.oldequipitem or require(repstorage.TS.entity.entities["inventory-entity"]).InventoryEntity.equipItem)[3])),
			["FishermanTable"] = KnitClient.Controllers.FishermanController,
			["FovController"] = KnitClient.Controllers.FovController,
			["GameAnimationUtil"] = require(repstorage.TS.animation["animation-util"]).GameAnimationUtil,
			["GamePlayerUtil"] = require(repstorage.TS.player["player-util"]).GamePlayerUtil,
            ["getEntityTable"] = require(repstorage.TS.entity["entity-util"]).EntityUtil,
            ["getIcon"] = function(item, showinv)
                local itemmeta = bedwars["ItemTable"][item.itemType]
                if itemmeta and showinv then
                    return itemmeta.image
                end
                return ""
            end,
			["getInventory2"] = function(plr)
                local suc, result = pcall(function() 
					return InventoryUtil.getInventory(plr) 
				end)
                return (suc and result or {
                    ["items"] = {},
                    ["armor"] = {},
                    ["hand"] = nil
                })
            end,
            ["getItemMetadata"] = require(repstorage.TS.item["item-meta"]).getItemMeta,
			["GrimReaperController"] = KnitClient.Controllers.GrimReaperController,
			["GuitarHealRemote"] = getremote(debug.getconstants(KnitClient.Controllers.GuitarController.performHeal)),
			["HangGliderController"] = KnitClient.Controllers.HangGliderController,
			["HighlightController"] = KnitClient.Controllers.EntityHighlightController,
            ["ItemTable"] = debug.getupvalue(require(repstorage.TS.item["item-meta"]).getItemMeta, 1),
			["JuggernautRemote"] = getremote(debug.getconstants(debug.getprotos(debug.getprotos(KnitClient.Controllers.JuggernautController.KnitStart)[1])[4])),
			["KatanaController"] = KnitClient.Controllers.DaoController,
			["KatanaRemote"] = getremote(debug.getconstants(debug.getproto(KnitClient.Controllers.DaoController.onEnable, 4))),
            ["KnockbackTable"] = debug.getupvalue(require(repstorage.TS.damage["knockback-util"]).KnockbackUtil.calculateKnockbackVelocity, 1),
			["LobbyClientEvents"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"].lobby.out.client.events).LobbyClientEvents,
			["MapMeta"] = require(repstorage.TS.game.map["map-meta"]),
			["MissileController"] = KnitClient.Controllers.GuidedProjectileController,
			["MinerRemote"] = getremote(debug.getconstants(debug.getprotos(debug.getproto(getmetatable(KnitClient.Controllers.MinerController).onKitEnabled, 1))[2])),
			["MinerController"] = KnitClient.Controllers.MinerController,
			["ProdAnimations"] = require(repstorage.TS.animation.definitions["prod-animations"]).ProdAnimations,
            ["PickupRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.ItemDropController).checkForPickup)),
            ["PlayerUtil"] = require(repstorage.TS.player["player-util"]).GamePlayerUtil,
			["ProjectileMeta"] = require(repstorage.TS.projectile["projectile-meta"]).ProjectileMeta,
			["QueueMeta"] = require(repstorage.TS.game["queue-meta"]).QueueMeta,
			["QueueCard"] = require(lplr.PlayerScripts.TS.controllers.global.queue.ui["queue-card"]).QueueCard,
			["QueryUtil"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out).GameQueryUtil,
			["PaintRemote"] = getremote(debug.getconstants(KnitClient.Controllers.PaintShotgunController.fire)),
            ["prepareHashing"] = require(repstorage.TS["remote-hash"]["remote-hash-util"]).RemoteHashUtil.prepareHashVector3,
			["ProjectileRemote"] = getremote(debug.getconstants(debug.getupvalues(getmetatable(KnitClient.Controllers.ProjectileController)["launchProjectileWithValues"])[2])),
			["ProjectileHitRemote"] = getremote(debug.getconstants(debug.getproto(KnitClient.Controllers.ProjectileController.createLocalProjectile, 1))),
            ["RavenTable"] = KnitClient.Controllers.RavenController,
			["RespawnController"] = KnitClient.Controllers.BedwarsRespawnController,
			["RespawnTimer"] = require(lplr.PlayerScripts.TS.controllers.games.bedwars.respawn.ui["respawn-timer"]).RespawnTimerWrapper,
			["ResetRemote"] = getremote(debug.getconstants(debug.getproto(KnitClient.Controllers.ResetController.createBindable, 1))),
			["Roact"] = require(repstorage["rbxts_include"]["node_modules"]["roact"].src),
			["RuntimeLib"] = require(repstorage["rbxts_include"].RuntimeLib),
            ["Shop"] = require(repstorage.TS.games.bedwars.shop["bedwars-shop"]).BedwarsShop,
			["ShopItems"] = debug.getupvalue(require(repstorage.TS.games.bedwars.shop["bedwars-shop"]).BedwarsShop.getShopItem, 2),
            ["ShopRight"] = require(lplr.PlayerScripts.TS.controllers.games.bedwars.shop.ui["item-shop"]["shop-left"]["shop-left"]).BedwarsItemShopLeft,
			["SpawnRavenRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.RavenController).spawnRaven)),
            ["SoundManager"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out).SoundManager,
			["SoundList"] = require(repstorage.TS.sound["game-sound"]).GameSound,
            ["sprintTable"] = KnitClient.Controllers.SprintController,
			["StopwatchController"] = KnitClient.Controllers.StopwatchController,
            ["SwingSword"] = getmetatable(KnitClient.Controllers.SwordController).swingSwordAtMouse,
            ["SwingSwordRegion"] = getmetatable(KnitClient.Controllers.SwordController).swingSwordInRegion,
            ["SwordController"] = KnitClient.Controllers.SwordController,
            ["TreeRemote"] = getremote(debug.getconstants(debug.getprotos(debug.getprotos(KnitClient.Controllers.BigmanController.KnitStart)[2])[1])),
			["TrinityRemote"] = getremote(debug.getconstants(debug.getproto(getmetatable(KnitClient.Controllers.AngelController).onKitEnabled, 1))),
            ["VictoryScreen"] = require(lplr.PlayerScripts.TS.controllers["game"].match.ui["victory-section"]).VictorySection,
            ["ViewmodelController"] = KnitClient.Controllers.ViewmodelController,
			["VehicleController"] = KnitClient.Controllers.VehicleController,
			["WeldTable"] = require(repstorage.TS.util["weld-util"]).WeldUtil,
        }
	end
end)

				

local function LaunchDirection(start, target, v, g, higherArc: boolean)

local horizontal = vec3(target.X - start.X, 0, target.Z - start.Z)

local h = target.Y - start.Y
local d = horizontal.Magnitude
local a = LaunchAngle(v, g, d, h, higherArc)


if a ~= a then return nil end


local vec = horizontal.Unit * v


local rotAxis = vec3(-horizontal.Z, 0, horizontal.X)


return CFrame.fromAxisAngle(rotAxis, a) * vec
end

local function FindLeadShot(targetPosition: Vector3, targetVelocity: Vector3, projectileSpeed: Number, shooterPosition: Vector3, shooterVelocity: Vector3, gravity: Number)
local distance = (targetPosition - shooterPosition).Magnitude

local p = targetPosition - shooterPosition
local v = targetVelocity - shooterVelocity
local a = Vector3.zero

local timeTaken = (distance / projectileSpeed)

if gravity > 0 then
local timeTaken = projectileSpeed/gravity+math.sqrt(2*distance/gravity+projectileSpeed^2/gravity^2)
end

local goalX = targetPosition.X + v.X*timeTaken + 0.5 * a.X * timeTaken^2
local goalY = targetPosition.Y + v.Y*timeTaken + 0.5 * a.Y * timeTaken^2
local goalZ = targetPosition.Z + v.Z*timeTaken + 0.5 * a.Z * timeTaken^2

return vec3(goalX, goalY, goalZ)
end

local function addvectortocframe(cframe, vec)
local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cframe:GetComponents()
return cfnew(x + vec.X, y + vec.Y, z + vec.Z, R00, R01, R02, R10, R11, R12, R20, R21, R22)
end

local function addvectortocframe2(cframe, newylevel)
local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cframe:GetComponents()
return cfnew(x, newylevel, z, R00, R01, R02, R10, R11, R12, R20, R21, R22)
end
local oldcloneroot
function notify(text)
    local frame = GuiLibrary["CreateNotification"]("", text, 5, "assets/WarningNotification.png")
    frame.Frame.Frame.ImageColor3 = Color3.fromRGB(255, 64, 64)
end
function boxnotify(text)
    if messagebox then
        messagebox(text, "", 0)
     end
end

local clone

local oldchar
AnticheatBypassArrowDodge = GuiLibrary["ObjectsThatCanBeSaved"]["AnticheatBypassOptionsButton"]["Api"].CreateToggle({
        ["Name"] = "Arrow Dodge",
        ["Function"] = function(callback)
            if callback then
                Client = {
                    WaitFor = function(self6, remote)
                task.spawn(function()
                    oldcloneroot = entity.character.HumanoidRootPart
lplr.Character.Parent = game
clone = oldcloneroot:Clone()
clone.Parent = lplr.Character
oldcloneroot.Parent = cam
bedwars["QueryUtil"]:setQueryIgnored(oldcloneroot, true)
oldcloneroot.Transparency = 1
clone.CFrame = oldcloneroot.CFrame

lplr.Character.PrimaryPart = clone
lplr.Character.Parent = workspace
                    bedwars["ClientHandler"]:WaitFor("ProjectileLaunch"):andThen(function(p6)
                        arrowdodgeconnection = p6:Connect(function(data)
                            if oldchar and clone and GuiLibrary["ObjectsThatCanBeSaved"]["AnticheatBypassOptionsButton"]["Api"]["Enabled"] and (arrowdodgedata == nil or arrowdodgedata.launchVelocity ~= data.launchVelocity) and entity.isAlive and tostring(data.projectile):find("arrow") then
                                arrowdodgedata = data
                                local projmetatab = bedwars["ProjectileMeta"][tostring(data.projectile)]
                                local prediction = (projmetatab.predictionLifetimeSec or projmetatab.lifetimeSec or 3)
                                local gravity = (projmetatab.gravitationalAcceleration or 196.2)
                                local multigrav = gravity
                                local offsetshootpos = data.position
                                local pos = (oldchar.HumanoidRootPart.Position + vec3(0, 0.8, 0)) 
                                local calculated2 = FindLeadShot(pos, Vector3.zero, (Vector3.zero - data.launchVelocity).magnitude, offsetshootpos, Vector3.zero, multigrav) 
                                local calculated = LaunchDirection(offsetshootpos, pos, (Vector3.zero - data.launchVelocity).magnitude, gravity, false)
                                local initialvelo = calculated--(calculated - offsetshootpos).Unit * launchvelo
                                local initialvelo2 = (calculated2 - offsetshootpos).Unit * (Vector3.zero - data.launchVelocity).magnitude
                                local calculatedvelo = vec3(initialvelo2.X, (initialvelo and initialvelo.Y or initialvelo2.Y), initialvelo2.Z).Unit * (Vector3.zero - data.launchVelocity).magnitude
                                if (calculatedvelo - data.launchVelocity).magnitude <= 20 then 
                                    oldchar.HumanoidRootPart.CFrame = oldchar.HumanoidRootPart.CFrame:lerp(clone.HumanoidRootPart.CFrame, 0.6)
                                end
                            end
                        end)
                    end)
                end)
            end
            }
            end
        end,
        ["Default"] = true,
        ["HoverText"] = ""
})




local function getWhitelistedBed(bed)
	for i,v in pairs(players:GetChildren()) do
		if v:GetAttribute("Team") and bed and bed:GetAttribute("Team"..v:GetAttribute("Team").."NoBreak") and bedwars["CheckWhitelisted"](v) then
			return true
		end
	end
	return false
end
local getfunctions
local OldClientGet 
local oldbreakremote
local oldbob
runcode(function()
    getfunctions = function()
		local Flamework = require(repstorage["rbxts_include"]["node_modules"]["@flamework"].core.out).Flamework
		repeat task.wait() until Flamework.isInitialized
        local KnitClient = debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 6)
        local Client = require(repstorage.TS.remotes).default.Client
        local InventoryUtil = require(repstorage.TS.inventory["inventory-util"]).InventoryUtil
        OldClientGet = getmetatable(Client).Get
        getmetatable(Client).Get = function(Self, remotename)
			local res = OldClientGet(Self, remotename)
			if uninjectflag then return res end
			if remotename == "DamageBlock" then
				return {
					["CallServerAsync"] = function(Self, tab)
						local block = bedwars["BlockController"]:getStore():getBlockAt(tab.blockRef.blockPosition)
						if block and block.Name == "bed" then
							if getWhitelistedBed(block) then
								return {andThen = function(self, func) 
									func("failed")
								end}
							end
						end
						return res:CallServerAsync(tab)
					end,
					["CallServer"] = function(Self, tab)
						local block = bedwars["BlockController"]:getStore():getBlockAt(tab.blockRef.blockPosition)
						if block and block.Name == "bed" then
							if getWhitelistedBed(block) then
								return {andThen = function(self, func) 
									func("failed")
								end}
							end
						end
						return res:CallServer(tab)
					end
				}
			elseif remotename == bedwars["AttackRemote"] then
				return {
					["instance"] = res["instance"],
					["SendToServer"] = function(Self, tab)
						local suc, plr = pcall(function() return players:GetPlayerFromCharacter(tab.entityInstance) end)
						if suc and plr then
							local playertype, playerattackable = bedwars["CheckPlayerType"](plr)
							if not playerattackable then 
								return nil
							end
						end
						if Reach["Enabled"] then
							local mag = (tab.validate.selfPosition.value - tab.validate.targetPosition.value).magnitude
							local newres = hashvec(tab.validate.selfPosition.value + (mag > 14.4 and (CFrame.lookAt(tab.validate.selfPosition.value, tab.validate.targetPosition.value).lookVector * 4) or Vector3.zero))
							tab.validate.selfPosition = newres
						end
						return res:SendToServer(tab)
					end
				}
			end
            return res
        end

		bedwars = {
			["AnimationUtil"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out["shared"].util["animation-util"]).AnimationUtil,
			["AngelUtil"] = require(repstorage.TS.games.bedwars.kit.kits.angel["angel-kit"]),
			["AppController"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out.client.controllers["app-controller"]).AppController,
			["AttackRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.SwordController)["attackEntity"])),
			["BatteryRemote"] = getremote(debug.getconstants(debug.getproto(debug.getproto(KnitClient.Controllers.BatteryController.KnitStart, 1), 1))),
			["BatteryEffectController"] = KnitClient.Controllers.BatteryEffectsController,
            ["BalloonController"] = KnitClient.Controllers.BalloonController,
            ["BlockController"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["block-engine"].out).BlockEngine,
            ["BlockController2"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["block-engine"].out.client.placement["block-placer"]).BlockPlacer,
            ["BlockEngine"] = require(lplr.PlayerScripts.TS.lib["block-engine"]["client-block-engine"]).ClientBlockEngine,
            ["BlockEngineClientEvents"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["block-engine"].out.client["block-engine-client-events"]).BlockEngineClientEvents,
			["BlockPlacementController"] = KnitClient.Controllers.BlockPlacementController,
            ["BedwarsKits"] = require(repstorage.TS.games.bedwars.kit["bedwars-kit-shop"]).BedwarsKitShop,
            ["BlockBreaker"] = KnitClient.Controllers.BlockBreakController.blockBreaker,
            ["BowTable"] = KnitClient.Controllers.ProjectileController,
			["BowConstantsTable"] = debug.getupvalue(KnitClient.Controllers.ProjectileController.enableBeam, 5),
			["ChestController"] = KnitClient.Controllers.ChestController,
			["ClickHold"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out.client.ui.lib.util["click-hold"]).ClickHold,
            ["ClientHandler"] = Client,
			["SharedConstants"] = require(repstorage.TS["shared-constants"]),
            ["ClientHandlerDamageBlock"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["block-engine"].out.remotes).BlockEngineRemotes.Client,
            ["ClientStoreHandler"] = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
			["ClientHandlerSyncEvents"] = require(lplr.PlayerScripts.TS["client-sync-events"]).ClientSyncEvents,
            ["CombatConstant"] = require(repstorage.TS.combat["combat-constant"]).CombatConstant,
			["CombatController"] = KnitClient.Controllers.CombatController,
			["ConsumeSoulRemote"] = getremote(debug.getconstants(KnitClient.Controllers.GrimReaperController.consumeSoul)),
			["ConstantManager"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out["shared"].constant["constant-manager"]).ConstantManager,
			["CooldownController"] = KnitClient.Controllers.CooldownController,
            ["damageTable"] = KnitClient.Controllers.DamageController,
			["DinoRemote"] = getremote(debug.getconstants(debug.getproto(KnitClient.Controllers.DinoTamerController.KnitStart, 3))),
			["DaoRemote"] = getremote(debug.getconstants(debug.getprotos(KnitClient.Controllers.DaoController.onEnable)[4])),
			["DamageController"] = KnitClient.Controllers.DamageController,
			["DamageIndicator"] = KnitClient.Controllers.DamageIndicatorController.spawnDamageIndicator,
			["DamageIndicatorController"] = KnitClient.Controllers.DamageIndicatorController,
			["DetonateRavenRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.RavenController).detonateRaven)),
            ["DropItem"] = getmetatable(KnitClient.Controllers.ItemDropController).dropItemInHand,
            ["DropItemRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.ItemDropController).dropItemInHand)),
            ["EatRemote"] = getremote(debug.getconstants(debug.getproto(getmetatable(KnitClient.Controllers.ConsumeController).onEnable, 1))),
            ["EquipItemRemote"] = getremote(debug.getconstants(debug.getprotos(shared.oldequipitem or require(repstorage.TS.entity.entities["inventory-entity"]).InventoryEntity.equipItem)[3])),
			["FishermanTable"] = KnitClient.Controllers.FishermanController,
			["FovController"] = KnitClient.Controllers.FovController,
			["GameAnimationUtil"] = require(repstorage.TS.animation["animation-util"]).GameAnimationUtil,
			["GamePlayerUtil"] = require(repstorage.TS.player["player-util"]).GamePlayerUtil,
            ["getEntityTable"] = require(repstorage.TS.entity["entity-util"]).EntityUtil,
            ["getIcon"] = function(item, showinv)
                local itemmeta = bedwars["ItemTable"][item.itemType]
                if itemmeta and showinv then
                    return itemmeta.image
                end
                return ""
            end,
			["getInventory2"] = function(plr)
                local suc, result = pcall(function() 
					return InventoryUtil.getInventory(plr) 
				end)
                return (suc and result or {
                    ["items"] = {},
                    ["armor"] = {},
                    ["hand"] = nil
                })
            end,
            ["getItemMetadata"] = require(repstorage.TS.item["item-meta"]).getItemMeta,
			["GrimReaperController"] = KnitClient.Controllers.GrimReaperController,
			["GuitarHealRemote"] = getremote(debug.getconstants(KnitClient.Controllers.GuitarController.performHeal)),
			["HangGliderController"] = KnitClient.Controllers.HangGliderController,
			["HighlightController"] = KnitClient.Controllers.EntityHighlightController,
            ["ItemTable"] = debug.getupvalue(require(repstorage.TS.item["item-meta"]).getItemMeta, 1),
			["JuggernautRemote"] = getremote(debug.getconstants(debug.getprotos(debug.getprotos(KnitClient.Controllers.JuggernautController.KnitStart)[1])[4])),
			["KatanaController"] = KnitClient.Controllers.DaoController,
			["KatanaRemote"] = getremote(debug.getconstants(debug.getproto(KnitClient.Controllers.DaoController.onEnable, 4))),
            ["KnockbackTable"] = debug.getupvalue(require(repstorage.TS.damage["knockback-util"]).KnockbackUtil.calculateKnockbackVelocity, 1),
			["LobbyClientEvents"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"].lobby.out.client.events).LobbyClientEvents,
			["MapMeta"] = require(repstorage.TS.game.map["map-meta"]),
			["MissileController"] = KnitClient.Controllers.GuidedProjectileController,
			["MinerRemote"] = getremote(debug.getconstants(debug.getprotos(debug.getproto(getmetatable(KnitClient.Controllers.MinerController).onKitEnabled, 1))[2])),
			["MinerController"] = KnitClient.Controllers.MinerController,
			["ProdAnimations"] = require(repstorage.TS.animation.definitions["prod-animations"]).ProdAnimations,
            ["PickupRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.ItemDropController).checkForPickup)),
            ["PlayerUtil"] = require(repstorage.TS.player["player-util"]).GamePlayerUtil,
			["ProjectileMeta"] = require(repstorage.TS.projectile["projectile-meta"]).ProjectileMeta,
			["QueueMeta"] = require(repstorage.TS.game["queue-meta"]).QueueMeta,
			["QueueCard"] = require(lplr.PlayerScripts.TS.controllers.global.queue.ui["queue-card"]).QueueCard,
			["QueryUtil"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out).GameQueryUtil,
			["PaintRemote"] = getremote(debug.getconstants(KnitClient.Controllers.PaintShotgunController.fire)),
            ["prepareHashing"] = require(repstorage.TS["remote-hash"]["remote-hash-util"]).RemoteHashUtil.prepareHashVector3,
			["ProjectileRemote"] = getremote(debug.getconstants(debug.getupvalues(getmetatable(KnitClient.Controllers.ProjectileController)["launchProjectileWithValues"])[2])),
			["ProjectileHitRemote"] = getremote(debug.getconstants(debug.getproto(KnitClient.Controllers.ProjectileController.createLocalProjectile, 1))),
            ["RavenTable"] = KnitClient.Controllers.RavenController,
			["RespawnController"] = KnitClient.Controllers.BedwarsRespawnController,
			["RespawnTimer"] = require(lplr.PlayerScripts.TS.controllers.games.bedwars.respawn.ui["respawn-timer"]).RespawnTimerWrapper,
			["ResetRemote"] = getremote(debug.getconstants(debug.getproto(KnitClient.Controllers.ResetController.createBindable, 1))),
			["Roact"] = require(repstorage["rbxts_include"]["node_modules"]["roact"].src),
			["RuntimeLib"] = require(repstorage["rbxts_include"].RuntimeLib),
            ["Shop"] = require(repstorage.TS.games.bedwars.shop["bedwars-shop"]).BedwarsShop,
			["ShopItems"] = debug.getupvalue(require(repstorage.TS.games.bedwars.shop["bedwars-shop"]).BedwarsShop.getShopItem, 2),
            ["ShopRight"] = require(lplr.PlayerScripts.TS.controllers.games.bedwars.shop.ui["item-shop"]["shop-left"]["shop-left"]).BedwarsItemShopLeft,
			["SpawnRavenRemote"] = getremote(debug.getconstants(getmetatable(KnitClient.Controllers.RavenController).spawnRaven)),
            ["SoundManager"] = require(repstorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out).SoundManager,
			["SoundList"] = require(repstorage.TS.sound["game-sound"]).GameSound,
            ["sprintTable"] = KnitClient.Controllers.SprintController,
			["StopwatchController"] = KnitClient.Controllers.StopwatchController,
            ["SwingSword"] = getmetatable(KnitClient.Controllers.SwordController).swingSwordAtMouse,
            ["SwingSwordRegion"] = getmetatable(KnitClient.Controllers.SwordController).swingSwordInRegion,
            ["SwordController"] = KnitClient.Controllers.SwordController,
            ["TreeRemote"] = getremote(debug.getconstants(debug.getprotos(debug.getprotos(KnitClient.Controllers.BigmanController.KnitStart)[2])[1])),
			["TrinityRemote"] = getremote(debug.getconstants(debug.getproto(getmetatable(KnitClient.Controllers.AngelController).onKitEnabled, 1))),
            ["VictoryScreen"] = require(lplr.PlayerScripts.TS.controllers["game"].match.ui["victory-section"]).VictorySection,
            ["ViewmodelController"] = KnitClient.Controllers.ViewmodelController,
			["VehicleController"] = KnitClient.Controllers.VehicleController,
			["WeldTable"] = require(repstorage.TS.util["weld-util"]).WeldUtil,
        }
	end
end)
local lplr = game:GetService("Players").LocalPlayer
local queueType = "bedwars_test"
local currentinventory = {
	["inventory"] = {
		["items"] = {},
		["armor"] = {},
		["hand"] = nil
	}
}
local function getSpeedMultiplier(reduce)
	local speed = 1
	if lplr.Character then 
		local speedboost = lplr.Character:GetAttribute("SpeedBoost")
		if speedboost and speedboost > 1 then 
			speed = speed + (speedboost - 1)
		end
		if lplr.Character:GetAttribute("GrimReaperChannel") then 
			speed = speed + 0.6
		end
		if lplr.Character:GetAttribute("SpeedPieBuff") then 
			speed = speed + (queueType == "SURVIVAL" and 0.15 or 0.3)
		end
		local armor = currentinventory.inventory.armor[3]
		if type(armor) ~= "table" then armor = {itemType = ""} end
		if armor.itemType == "speed_boots" then 
			speed = speed + 1
		end
	end
	return reduce and speed ~= 1 and speed * (0.9 - (0.15 * math.floor(speed))) or speed
end

local networkownerfunc = isnetworkowner or function(part)
	if gethiddenproperty(part, "NetworkOwnershipRule") == Enum.NetworkOwnership.Manual then 
		sethiddenproperty(part, "NetworkOwnershipRule", Enum.NetworkOwnership.Automatic)
		networkownertick = tick() + 8
	end
	return networkownertick <= tick()
end

repeat task.wait() until game:IsLoaded()
repeat task.wait() until shared.GuiLibrary
local GuiLibrary = shared.GuiLibrary
local ScriptSettings = {}
local UIS = game:GetService("UserInputService")
local COB = function(tab, argstable) 
    return GuiLibrary["ObjectsThatCanBeSaved"][tab.."Window"]["Api"].CreateOptionsButton(argstable)
end

local InfJump = COB("Blatant", {
    Name = "Infinite Jump",
    Function = function(callback) 
        if callback then
local InfiniteJumpEnabled = true
game:GetService("UserInputService").JumpRequest:connect(function()
	if InfiniteJumpEnabled then
		game:GetService"Players".LocalPlayer.Character:FindFirstChildOfClass'Humanoid':ChangeState("Jumping")
	end
end)
        end
    end,
    Default = false,
    HoverText = "Risky Inf Jump"
})

local testing
local partthingy	
local ChillLight = COB("Render", {
    Name = "ChillLighting",
    Function = function(callback) 
        if callback then
    game.Lighting.Ambient = Color3.fromRGB(32, 212, 212)
            game.Lighting.OutdoorAmbient = Color3.fromRGB(32, 212, 212)
        end
    end,
    Default = false,
    HoverText = "ChillLighting"
})

local Chat = COB("Render", {
	["Name"] = "Chat Postition",
	["HoverText"] = "Changes Chat Position",
	["Function"] = function(callback)
		if callback then
			game:GetService("StarterGui"):SetCore('ChatWindowPosition', UDim2.new(0.0, 0, 0.0, 200))
		else
			game:GetService("StarterGui"):SetCore('ChatWindowPosition', UDim2.new(0.0, 0, 0.0, 0))
		end
	end
})

local ChatCrasher = COB("Utility", {
    Name = "ChatCrasher",
    Function = function(callback) 
        if callback then
			while true do
				wait(1.7)
				local args = {
				    [1] = " ",
				    [2] = "All"
				}
				game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(unpack(args))
			end
        end
    end,
    Default = false,
    HoverText = "Disables Chat"
})

runcode(function()
	local Multiaura = {["Enabled"] = false}
	Multiaura = GuiLibrary["ObjectsThatCanBeSaved"]["BlatantWindow"]["Api"].CreateOptionsButton({
		["Name"] = "MultiAura",
		["Function"] = function(callback)
			if callback then
				task.spawn(function()
					repeat
						task.wait(0.5)
						if (GuiLibrary["ObjectsThatCanBeSaved"]["Lobby CheckToggle"]["Api"]["Enabled"] == false) and Multiaura["Enabled"] then
							local plrs = GetAllNearestHumanoidToPosition(true, 17, 1, false)
							for i,plr in pairs(plrs) do
								local selfpos = entity.character.HumanoidRootPart.Position
								local newpos = plr.RootPart.Position
								bedwars["ClientHandler"]:Get(bedwars["PaintRemote"]):SendToServer(selfpos, CFrame.lookAt(selfpos, newpos).lookVector)
							end
						end
					until not Multiaura["Enabled"]
				end)
			end
		end,
		["HoverText"] = "Its Better KillAura"
	})
end)

local bypassed = false
runcode(function()
	local anticheatdisabler = {["Enabled"] = false}
	local anticheatdisablerauto = {["Enabled"] = false}
	local anticheatdisablerconnection
	local anticheatdisablerconnection2
	anticheatdisabler = GuiLibrary["ObjectsThatCanBeSaved"]["UtilityWindow"]["Api"].CreateOptionsButton({
		["Name"] = "Balloon AC Disabler",
		["Function"] = function(callback)
			if callback then
				local balloonitem = getItem("balloon")
				if balloonitem then
					local oldfunc3 = bedwars["BalloonController"].hookBalloon
					local oldfunc4 = bedwars["BalloonController"].enableBalloonPhysics
					local oldfunc5 = bedwars["BalloonController"].deflateBalloon
					bedwars["BalloonController"].inflateBalloon()
					bedwars["BalloonController"].enableBalloonPhysics = function() end
					bedwars["BalloonController"].deflateBalloon = function() end
					bedwars["BalloonController"].hookBalloon = function(Self, plr, attachment, balloon)
						if tostring(plr) == lplr.Name then
							balloon:WaitForChild("Balloon").CFrame = CFrame.new(0, -1995, 0)
							balloon.Balloon:ClearAllChildren()
							local threadidentity = syn and syn.set_thread_identity or setidentity
							threadidentity(7)
							spawn(function()
								wait(0.5)
								createwarning("AnticheatDisabler", "Disabled Anticheat!", 5)
								bypassed = true
							end)
							threadidentity(2)
							bedwars["BalloonController"].hookBalloon = oldfunc3
							bedwars["BalloonController"].enableBalloonPhysics = oldfunc4
						end
					end
				end
				anticheatdisabler["ToggleButton"](true)
			end
		end
	})
	anticheatdisablerauto = anticheatdisabler.CreateToggle({
		["Name"] = "Auto Disable",
		["Function"] = function(callback)
			if callback then
				anticheatdisablerconnection = repstorage.Inventories.DescendantAdded:connect(function(p3)
					if p3.Parent.Name == lplr.Name then
						if p3.Name == "balloon" then
							repeat task.wait() until getItem("balloon")
							anticheatdisabler["ToggleButton"](false)
						end
					end
				end)
			else
				if anticheatdisablerconnection then
					anticheatdisablerconnection:Disconnect()
				end
			end
		end,
	})
end)


local YTSD = GuiLibrary["ObjectsThatCanBeSaved"]["UtilityWindow"]["Api"].CreateOptionsButton({
	["Name"] = "Star Detector", 
	["Function"] = function(callback)
		if callback then
			for i, plr in pairs(players:GetChildren()) do
				if plr:IsInGroup(4199740) and plr:GetRankInGroup(4199740) >= 1 then
					createwarning("Vape", "Youtuber found " .. plr.Name .. "(" .. plr.DisplayName .. ")", 20)
					end
				end
			end
		end
})

local BedTpMabye = {["Enabled"] = false}
    BedTpMabye = GuiLibrary["ObjectsThatCanBeSaved"]["BlatantWindow"]["Api"].CreateOptionsButton({
        ["Name"] = "Bed TPv2",
        ["Function"] = function(callback)
            if callback then

            local mybed
local pteam = game.Players.LocalPlayer.Team
local myteam = game.Players.LocalPlayer.Team
for i, v in pairs(game.Workspace:GetChildren()) do
if v.Name == "bed" and v.Covers.BrickColor == myteam.TeamColor then
mybed = v
end

end



local otherbed
for i, v in pairs(game.Workspace:GetChildren()) do
if v.Name == "bed" and v ~= mybed then
otherbed = v
end

end
repeat wait(0.1) 
for i, v in pairs(game.Workspace:GetChildren()) do
    if v.Name == "bed" and v ~= mybed then
    otherbed = v
    end

    end
if otherbed and otherbed.Name and otherbed.Transparency and otherbed.Parent == game.Workspace then
     if game.Players.LocalPlayer.Character ~= nil and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = otherbed.CFrame + Vector3.new(0,5,0)
end
else
    otherbed = nil
    break;
end


until otherbed == nil



            else
                wait(0.1)
            end
        end
    })
    
	local Crosshair = COB("Render", {
		["Name"] = "Crosshair",
		["Function"] = function(callback)
			if callback then
				pcall(function()
					ScriptSettings.Crosshair = true
					local mouse = game:GetService("Players").LocalPlayer:GetMouse()
					mouse.Icon = "rbxassetid://9943168532"
					mouse:GetPropertyChangedSignal("Icon"):Connect(function()
						if not ScriptSettings.Crosshair == true then return end
						mouse.Icon = "rbxassetid://9943168532"
					end)
				end)
			else
				pcall(function()
					ScriptSettings.Crosshair = false
					local mouse = game:GetService("Players").LocalPlayer:GetMouse()
					mouse.Icon = ""
				end)
			end
		end,
		["Default"] = false,
		["HoverText"] = "Custom crosshair"
	})

	BoostAirJump = GuiLibrary["ObjectsThatCanBeSaved"]["BlatantWindow"]["Api"].CreateOptionsButton({
		["Name"] = "BoostAirJump",
		["Function"] = function(callback)
			if callback then
				task.spawn(function()
					repeat
						task.wait(0.1)
						if BoostAirJump["Enabled"] == false then break end
						entity.character.HumanoidRootPart.Velocity = entity.character.HumanoidRootPart.Velocity + Vector3.new(0,35,0)
					until BoostAirJump["Enabled"] == false
				end)
			end
		end,
		["HoverText"] = "Bypasses High Jump"
	})