-- Shared BedWars helpers.
--
-- Everything here was copy-pasted into two or more modules before this file existed:
--
--   * the "is a shop within N studs" scan, its range and the id that goes with a purchase
--     (AutoBuy, ShopClicker, AutoTaliyah, AutoRefill, AutoUpgrade)
--   * the BedwarsPurchaseItem bookkeeping - currency debit, purchase sound, store dispatch,
--     alreadyPurchasedMap (AutoBuy, AutoRefill, AutoUpgrade, ShopClicker, AutoTaliyah)
--   * canBuy's kit/lock/queue/team-upgrade rules (AutoBuy, AutoRefill, ShopClicker)
--   * team upgrade state lookups (AutoUpgrade, AutoRefill)
--   * inventory counting and item lookup (AutoBuy, AutoRefill, AutoBank, AutoSteal)
--   * flat and percentage health reads (AutoBank, AutoRefill, dozens of others)
--   * the personal chest folder lookup and the SetObservedChest dance around
--     ChestGiveItem/ChestGetItem (AutoBank, AutoSteal)
--   * the queue gate every match-only module waits on
--   * the slider suffixes ('stud'/'studs', 'sec'/'secs') repeated in ~100 option tables
--
-- Distances are named here instead of being sprinkled as literals: Range.Shop / Range.Chest are
-- the radii the shop and chest modules already agreed on, and a module that genuinely needs a
-- different radius passes one in. Nothing in here invents a second magic number.
--
-- Consumers reach it through vape.Libraries.bedwarsutil (loaded by the BedWars base), and the
-- game state is resolved on every call because this library loads before the pack has finished
-- building its store and bedwars tables.

local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local lplr = playersService.LocalPlayer

local helpers = {
	-- The interaction radii the pack already used; pass an explicit range to override.
	Range = {
		Shop = 20,
		Chest = 20,
	},
	-- The polling cadence the module loops share.
	PollInterval = 0.1,
	-- Item family used by refill-style modules: every wool colour is one item.
	WoolFamily = 'wool',
}

local function game_state()
	local value = getgenv().store
	return type(value) == 'table' and value or nil
end

local function game_api()
	local value = getgenv().bedwars
	return type(value) == 'table' and value or nil
end

local function entities()
	local vape = shared.vape
	return vape and vape.Libraries and vape.Libraries.entity or nil
end

--------------------------------------------------------------------------------
-- Slider suffixes (previously a closure inside every option table that used one)
--------------------------------------------------------------------------------

-- "1 stud" / "5 studs"
function helpers.Studs(val)
	return val <= 1 and 'stud' or 'studs'
end

-- "1 sec" / "5 secs"
function helpers.Seconds(val)
	return val <= 1 and 'sec' or 'secs'
end

-- "1 min" / "5 mins"
function helpers.Minutes(val)
	return val <= 1 and 'min' or 'mins'
end

helpers.Percent = '%'

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

local Utils = {}
helpers.Utils = Utils

function Utils.Notify(label, text, duration, kind)
	local vape = shared.vape
	if vape and type(vape.CreateNotification) == 'function' then
		pcall(vape.CreateNotification, vape, label, text, duration, kind)
	end
end

function Utils.Alive()
	local entitylib = entities()
	return entitylib ~= nil and entitylib.isAlive == true
end

function Utils.Root()
	local entitylib = entities()
	local character = entitylib and entitylib.character
	return character and character.RootPart or nil
end

function Utils.Position()
	local root = Utils.Root()
	return root and root.Position or nil
end

function Utils.Distance(position)
	local origin = Utils.Position()
	if not origin or not position then return nil end
	return (position - origin).Magnitude
end

function Utils.InRange(position, range)
	local distance = Utils.Distance(position)
	return distance ~= nil and distance <= range
end

-- Restarts a module the way options do when a change needs a fresh loop: toggle off and on
-- again, and leave a disabled module alone.
function Utils.Restart(module)
	if module and module.Enabled then
		module:Toggle()
		module:Toggle()
	end
end

-- Shared combat state (see libraries/combat.lua); nil when it is not loaded.
function Utils.Combat()
	return shared.AetherCombat or getgenv().AetherCombat
end

function Utils.InCombat()
	local combat = Utils.Combat()
	return (combat and combat:IsInCombat()) == true
end

--------------------------------------------------------------------------------
-- Queue
--------------------------------------------------------------------------------

local Queue = {Test = 'bedwars_test'}
helpers.Queue = Queue

function Queue.Name()
	local store = game_state()
	return store and store.queueType or Queue.Test
end

function Queue.Ready()
	return Queue.Name() ~= Queue.Test
end

-- Modules that only make sense inside a real match wait here. `module` is polled so a module
-- disabled while waiting still leaves, and a bare function is accepted as the stop check.
function Queue.Await(module)
	local shouldStop = module
	if type(module) == 'table' then
		shouldStop = function()
			return module.Enabled ~= true
		end
	end
	repeat
		task.wait()
	until Queue.Ready() or (shouldStop and shouldStop())
	return Queue.Ready()
end

--------------------------------------------------------------------------------
-- Inventory
--------------------------------------------------------------------------------

local Inventory = {}
helpers.Inventory = Inventory

function Inventory.Container()
	local store = game_state()
	local inventory = store and store.inventory and store.inventory.inventory
	return type(inventory) == 'table' and inventory or nil
end

function Inventory.Items()
	local inventory = Inventory.Container()
	return (inventory and inventory.items) or {}
end

-- Mirrors the pack's getItem: an exact item type, or a substring match when `find` is set.
function Inventory.Item(name, find)
	for slot, item in Inventory.Items() do
		local itemType = item and item.itemType
		if itemType and ((find and itemType:find(name, 1, true)) or itemType == name) then
			return item, slot
		end
	end
	return nil
end

function Inventory.Amount(name, find)
	local item = Inventory.Item(name, find)
	return item and tonumber(item.amount) or 0
end

-- Total amount across every item the predicate accepts, which is how a whole family of items
-- (wool colours, for example) is counted as one.
function Inventory.Total(predicate)
	local total = 0
	for _, item in Inventory.Items() do
		if item and item.itemType and (not predicate or predicate(item.itemType, item)) then
			total += tonumber(item.amount) or 1
		end
	end
	return total
end

function Inventory.Meta(itemType)
	local bedwars = game_api()
	local meta = bedwars and bedwars.ItemMeta and bedwars.ItemMeta[itemType]
	return type(meta) == 'table' and meta or nil
end

-- The game caps a handful of items through ItemMeta.maxStackSize. nil means uncapped.
function Inventory.StackCap(itemType)
	local meta = Inventory.Meta(itemType)
	local capacity = meta and meta.maxStackSize
	if type(capacity) == 'table' then
		capacity = tonumber(capacity.amount)
	end
	return capacity and capacity > 0 and capacity or nil
end

--------------------------------------------------------------------------------
-- Item families (wool_white, wool_blue, ... are all "wool")
--------------------------------------------------------------------------------

local Families = {}
helpers.Families = Families

function Families.Name(entry)
	entry = tostring(entry or ''):lower():gsub('%s+', '')
	if entry == '' then return nil end
	if entry:find(helpers.WoolFamily, 1, true) then return helpers.WoolFamily end
	return entry
end

function Families.Matches(itemType, family)
	itemType = tostring(itemType or ''):lower()
	if family == helpers.WoolFamily then
		return itemType:find(helpers.WoolFamily, 1, true) ~= nil
	end
	return itemType == family
end

function Families.Label(family)
	return family:sub(1, 1):upper()..family:sub(2)
end

-- The neutral shop entry that hands back your own team's colour.
function Families.ShopType(family)
	return family == helpers.WoolFamily and 'wool_white' or family
end

--------------------------------------------------------------------------------
-- Health
--------------------------------------------------------------------------------

local Health = {}
helpers.Health = Health

local function characterOf(character)
	return character or lplr.Character
end

-- Flat health, taken from the attribute the game keeps in sync and falling back to the
-- Humanoid, exactly like the modules it replaces.
function Health.Current(character)
	character = characterOf(character)
	if not character then return nil end
	local health = character:GetAttribute('Health')
	local humanoid = character:FindFirstChildOfClass('Humanoid')
	if type(health) ~= 'number' then health = humanoid and humanoid.Health end
	return type(health) == 'number' and health or nil
end

function Health.Maximum(character)
	character = characterOf(character)
	if not character then return nil end
	local maximum = character:GetAttribute('MaxHealth')
	local humanoid = character:FindFirstChildOfClass('Humanoid')
	if type(maximum) ~= 'number' or maximum <= 0 then maximum = humanoid and humanoid.MaxHealth end
	return type(maximum) == 'number' and maximum > 0 and maximum or nil
end

function Health.Percent(character)
	local health, maximum = Health.Current(character), Health.Maximum(character)
	if not health or not maximum then return nil end
	return math.clamp((health / maximum) * 100, 0, 100)
end

--------------------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------------------

local Shop = {}
helpers.Shop = Shop

Shop.Range = helpers.Range.Shop
Shop.ItemApp = 'BedwarsItemShopApp'
Shop.UpgradeApp = 'TeamUpgradeApp'
Shop.ChestApp = 'ChestApp'

function Shop.Entries()
	local store = game_state()
	local entries = store and store.shop
	return type(entries) == 'table' and entries or {}
end

local function matchesKind(entry, kind)
	if kind == nil then return entry.Shop == true or entry.Upgrades == true end
	if kind == 'item' then return entry.Shop == true end
	if kind == 'upgrade' then return entry.Upgrades == true end
	return true
end

-- The closest shopkeeper of the requested kind inside `range` ('item', 'upgrade' or nil for
-- either). Returns the store.shop entry so callers can read its Id and tags.
function Shop.Nearby(kind, range)
	local origin = Utils.Position()
	if not origin then return nil end
	range = range or Shop.Range
	local closest, closestDistance
	for _, entry in Shop.Entries() do
		local part = entry.RootPart
		if part and part.Parent and matchesKind(entry, kind) then
			local distance = (part.Position - origin).Magnitude
			if distance <= range and (not closestDistance or distance < closestDistance) then
				closest, closestDistance = entry, distance
			end
		end
	end
	return closest
end

-- The id to send with a purchase at the shopkeeper of the requested kind.
function Shop.Id(kind, range)
	local entry = Shop.Nearby(kind, range)
	return entry and entry.Id or nil
end

function Shop.ScreenOpen(appId)
	local bedwars = game_api()
	local app = bedwars and bedwars.AppController
	if not app or type(app.isAppOpen) ~= 'function' then return false end
	local ok, opened = pcall(app.isAppOpen, app, appId)
	return ok and opened == true
end

function Shop.ItemScreenOpen()
	return Shop.ScreenOpen(Shop.ItemApp)
end

function Shop.UpgradeScreenOpen()
	return Shop.ScreenOpen(Shop.UpgradeApp)
end

-- Either buying screen: what AutoBank treats as "at a shop".
function Shop.BuyScreenOpen()
	return Shop.ItemScreenOpen() or Shop.UpgradeScreenOpen()
end

function Shop.ChestScreenOpen()
	return Shop.ScreenOpen(Shop.ChestApp)
end

-- The live shop item, preferring the runtime capability and falling back to the game's own
-- shop module. `shopId` is optional: AutoBuy's proven path omits it.
function Shop.Item(itemType, shopId)
	local runtime = shared.AetherBedWarsRuntime
	local capability = runtime and runtime.BedWarsAPI and runtime.BedWarsAPI.Shop
	if capability and type(capability.GetItem) == 'function' then
		local item = capability:GetItem(itemType, shopId)
		if item then return item end
	end
	local bedwars = game_api()
	if bedwars and bedwars.Shop and type(bedwars.Shop.getShopItem) == 'function' then
		local ok, item = pcall(bedwars.Shop.getShopItem, itemType, lplr, shopId and {shopId = shopId} or nil)
		if ok then return item end
	end
	return nil
end

function Shop.Owned(itemType)
	local bedwars = game_api()
	local shopController = bedwars and bedwars.BedwarsShopController
	local purchased = shopController and shopController.alreadyPurchasedMap
	return purchased ~= nil and purchased[itemType] ~= nil
end

-- The team upgrade state the server keeps in sync.
function Shop.TeamUpgrades()
	local bedwars = game_api()
	local ok, state = pcall(function()
		return bedwars.Store:getState()
	end)
	local bedwarsState = ok and type(state) == 'table' and state.Bedwars or nil
	local upgrades = type(bedwarsState) == 'table' and bedwarsState.teamUpgrades or nil
	if type(upgrades) ~= 'table' then return {} end
	local team = upgrades[lplr:GetAttribute('Team')]
	return type(team) == 'table' and team or upgrades
end

-- Mirrors AutoBuy's purchase rules: kit restrictions, locked or disabled entries, queue
-- availability and team upgrade requirements all still apply.
function Shop.CanBuy(item, currencytable, amount)
	amount = amount or 1
	currencytable = currencytable or {}
	if not currencytable[item.currency] then
		currencytable[item.currency] = Inventory.Amount(item.currency)
	end
	local store = game_state()
	if item.ignoredByKit and table.find(item.ignoredByKit, store and store.equippedKit or '') then return false end
	if item.lockedByForge or item.disabled then return false end
	if item.disabledInQueue and store and table.find(item.disabledInQueue, store.queueType or '') then return false end
	if item.require and item.require.teamUpgrade then
		local required = item.require.teamUpgrade
		if (Shop.TeamUpgrades()[required.upgradeId] or -1) < required.lowestTierIndex then return false end
	end
	return currencytable[item.currency] >= (item.price * amount)
end

-- Fires one shop purchase and applies the bookkeeping every shop module repeats: the
-- currency is debited locally, the purchase sound plays, the store is told what was bought
-- and the shop remembers it. `options.Label` adds a notification naming the module and
-- `options.TieredOnly` keeps consumables out of alreadyPurchasedMap, which is what
-- ShopClicker's quick buys rely on. Returns false when the purchase never went out.
function Shop.Purchase(item, shopId, currencytable, options)
	options = options or {}
	local bedwars = game_api()
	if not bedwars then return false end
	local meta = bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
	if options.Label then
		Utils.Notify(options.Label, 'Bought '..(meta and meta.displayName or item.itemType), 3)
	end

	-- A missing remote must not kill the calling module's loop, so the fire itself is
	-- guarded and reports whether the purchase went out.
	local fired = pcall(function()
		bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {
			shopItem = item,
			shopId = shopId
		}):andThen(function(suc)
			if not suc then return end
			bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
			bedwars.Store:dispatch({
				type = 'BedwarsAddItemPurchased',
				itemType = item.itemType
			})
			if not options.TieredOnly or item.tiered then
				bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
			end
		end)
	end)
	if not fired then return false end

	if currencytable then
		currencytable[item.currency] = (currencytable[item.currency] or 0) - item.price
	end
	return true
end

--------------------------------------------------------------------------------
-- Personal chest
--------------------------------------------------------------------------------

local Chest = {}
helpers.Chest = Chest

Chest.Tag = 'personal-chest'
Chest.Range = helpers.Range.Chest

function Chest.Remotes()
	local bedwars = game_api()
	local client = bedwars and bedwars.Client
	if not client or type(client.GetNamespace) ~= 'function' then return nil end
	local ok, remotes = pcall(function()
		return client:GetNamespace('Inventory')
	end)
	return ok and remotes or nil
end

function Chest.OwnFolder(plr)
	plr = plr or lplr
	local inventories = replicatedStorage:FindFirstChild('Inventories')
	return inventories and inventories:FindFirstChild(plr.Name..'_personal') or nil
end

-- The folder a chest part points at, via its ChestFolderValue.
function Chest.FolderOf(chest)
	if not chest then return nil end
	local value = chest:FindFirstChild('ChestFolderValue')
	return value and value.Value or nil
end

function Chest.Part(object)
	if not object then return nil end
	if object:IsA('Model') then return object.PrimaryPart end
	return object:IsA('BasePart') and object or nil
end

function Chest.Tagged()
	return collectionService:GetTagged(Chest.Tag)
end

function Chest.IsPersonal(chest)
	if not chest then return false end
	if collectionService:HasTag(chest, Chest.Tag) then return true end
	if tostring(chest.Name):lower():find('personal', 1, true) then return true end
	if chest:GetAttribute('PersonalChest') or chest:GetAttribute('IsPersonalChest') then return true end
	local folder = Chest.FolderOf(chest)
	if not folder then return false end
	local name = tostring(folder.Name):lower()
	return name:sub(-#'_personal') == '_personal' or name == 'personal'
end

-- Same in-range test AutoBank and AutoSteal both wrote out by hand.
function Chest.InRange(range, origin)
	origin = origin or Utils.Position()
	if not origin then return false end
	for _, chest in Chest.Tagged() do
		local part = Chest.Part(chest)
		if part and part.Parent and (part.Position - origin).Magnitude <= (range or Chest.Range) then
			return true
		end
	end
	return false
end

-- The stacks stored in a chest folder (ignore anything that is not an item entry).
function Chest.Entries(folder)
	local entries = {}
	if not folder then return entries end
	for _, child in folder:GetChildren() do
		if child:IsA('Accessory') then
			table.insert(entries, child)
		end
	end
	return entries
end

-- Name -> amount totals for a chest folder.
function Chest.Totals(folder)
	local totals = {}
	for _, entry in Chest.Entries(folder) do
		totals[entry.Name] = (totals[entry.Name] or 0) + (entry:GetAttribute('Amount') or 1)
	end
	return totals
end

-- Runs `body` with the server observing this chest, and always stops observing again.
-- Every chest transfer has to happen inside this window, which is why it is shared.
function Chest.Observe(folder, body)
	local remotes = Chest.Remotes()
	if not remotes then return false end
	pcall(function()
		remotes:Get('SetObservedChest'):SendToServer(folder)
	end)
	local results = table.pack(pcall(body, remotes))
	pcall(function()
		remotes:Get('SetObservedChest'):SendToServer(nil)
	end)
	return table.unpack(results, 1, results.n)
end

-- Hands one item to the chest. Returns false when the server refuses it, so a caller can
-- back off instead of hammering the same item.
function Chest.Give(folder, tool)
	local remotes = Chest.Remotes()
	if not remotes or not tool then return false end
	local ok, given = pcall(function()
		return remotes:Get('ChestGiveItem'):CallServer(folder, tool)
	end)
	return ok and given == true
end

function Chest.Take(folder, entry)
	local remotes = Chest.Remotes()
	if not remotes or not entry then return false end
	local ok, taken = pcall(function()
		return remotes:Get('ChestGetItem'):CallServer(folder, entry)
	end)
	return ok and taken == true
end

return helpers
