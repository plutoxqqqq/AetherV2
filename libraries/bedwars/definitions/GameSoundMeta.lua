-- Script Path: game:GetService(ReplicatedStorage).TS.sound[game-sound-meta]
-- Took 3.53s to decompile.
-- Executor: Nexomia.win (0.0.1)

-- https://lua.expert/

local Loader = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))()
local AudioCategory, SoundManager, ObjectUtil
do
    SoundManager = Loader:GetController('SoundManager')
    AudioCategory = Loader:GetMeta('AudioCategory').AudioCategory
    ObjectUtil = Loader:GetController('ObjectUtil')
end

local BedWarsAudioBuses = {
    LOBBY_MUSIC = {},
    MATCH_MUSIC = {},
    EMOTE_MUSIC = {},
    RAIN = {},
    WINTER_AMBIENCE = {},
    WINTER_MUSIC = {}
}

local t = {
	QUEUE_JOIN = {
		category = AudioCategory.UI
	},
	QUEUE_MATCH_FOUND = {
		category = AudioCategory.GAMEPLAY
	},
	UI_HOVER = {
		category = AudioCategory.UI
	},
	UI_CLICK = {
		category = AudioCategory.UI
	},
	UI_CLICK_2 = {
		category = AudioCategory.UI
	},
	UI_OPEN = {
		category = AudioCategory.UI
	},
	UI_OPEN_2 = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.UI
	},
	UI_CLOSE_2 = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.UI
	},
	UI_ERROR = {
		category = AudioCategory.UI
	},
	UI_REWARD = {
		category = AudioCategory.UI
	},
	PARTY_INCOMING_INVITE = {
		category = AudioCategory.UI
	},
	ERROR_NOTIFICATION = {
		category = AudioCategory.UI
	},
	INFO_NOTIFICATION = {
		category = AudioCategory.UI
	},
	PICKUP_ITEM_DROP = {
		volume = 0.4,
		preloadPriority = 90,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	DROP_ITEM = {
		category = AudioCategory.GAMEPLAY
	},
	END_GAME = {
		category = AudioCategory.GAMEPLAY
	},
	EQUIP_DEFAULT = {
		volume = 0.18,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EQUIP_SWORD = {
		volume = 0.38,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EQUIP_BOW = {
		category = AudioCategory.GAMEPLAY
	},
	BEDWARS_UPGRADE_SUCCESS = {
		category = AudioCategory.GAMEPLAY
	},
	BEDWARS_PURCHASE_ITEM = {
		category = AudioCategory.UI
	},
	SWORD_SWING_1 = {
		volume = 0.2,
		preloadPriority = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SWORD_SWING_2 = {
		volume = 0.2,
		preloadPriority = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	DAMAGE_1 = {
		volume = 1,
		preloadPriority = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	DAMAGE_2 = {
		volume = 1,
		preloadPriority = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	DAMAGE_3 = {
		volume = 1,
		preloadPriority = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	DAMAGE_HIT_HARD = {
		category = AudioCategory.GAMEPLAY
	},
	ARMOR_EQUIP = {
		category = AudioCategory.GAMEPLAY
	},
	ARMOR_UNEQUIP = {
		category = AudioCategory.GAMEPLAY
	},
	GRASS_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	STONE_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	WOOD_BREAK = {
		volume = 0.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WOOL_BREAK = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WOOL_PLACE = {
		category = AudioCategory.GAMEPLAY
	},
	GENERIC_BLOCK_PLACE = {
		category = AudioCategory.GAMEPLAY
	},
	GENERIC_BLOCK_HIT = {
		volume = 0.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TNT_EXPLODE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	TNT_HISS_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SIEGE_TNT_EXPLODE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SIEGE_TNT_HISS_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_BLOCK_PLACE = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_BLOCK_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_BLOCK_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_BLOCK_BOUNCE = {
		category = AudioCategory.GAMEPLAY
	},
	BOW_FIRE = {
		category = AudioCategory.COSMETICS
	},
	BOW_DRAW = {
		category = AudioCategory.GAMEPLAY
	},
	ARROW_HIT = {
		volume = 0.7,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TELEPEARL_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	TELEPEARL_LAND = {
		category = AudioCategory.GAMEPLAY
	},
	CROSSBOW_RELOAD = {
		category = AudioCategory.GAMEPLAY
	},
	VOICE_1 = {
		volume = 0.09,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOICE_2 = {
		volume = 0.09,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOICE_HONK = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOICE_ARF = {
		volume = 0.04,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CROP_HARVEST = {
		category = AudioCategory.GAMEPLAY
	},
	CROP_PLANT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CROP_PLANT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CROP_PLANT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FORTIFY_BLOCK = {
		category = AudioCategory.EFFECTS
	},
	EAT_FOOD_1 = {
		category = AudioCategory.GAMEPLAY
	},
	KILL = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ZIPLINE_TRAVEL = {
		category = AudioCategory.EFFECTS
	},
	ZIPLINE_LATCH = {
		category = AudioCategory.EFFECTS
	},
	ZIPLINE_UNLATCH = {
		category = AudioCategory.EFFECTS
	},
	SHIELD_BLOCKED = {
		category = AudioCategory.EFFECTS
	},
	GUITAR_LOOP = {
		volume = 0.15,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	GUITAR_HEAL_1 = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	GUITAR_LOOP_ROCKSTAR = {
		volume = 0.15,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	GUITAR_HEAL_1_ROCKSTAR = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	GUITAR_LOOP_HOLIDAY_COZY = {
		volume = 1.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GUITAR_HEAL_1_HOLIDAY_COZY = {
		volume = 1.1,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	GUITAR_LOOP_SIREN = {
		category = AudioCategory.GAMEPLAY
	},
	GUITAR_HEAL_1_SIREN = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIRIT_ASSASSIN_LOOP = {
		preload = false,
		category = AudioCategory.GAMEPLAY
	},
	CANNON_MOVE = {
		category = AudioCategory.GAMEPLAY
	},
	CANNON_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	OASIS_HEAL_PROJECTILE_1 = {
		category = AudioCategory.EFFECTS
	},
	OASIS_HEAL_PROJECTILE_2 = {
		category = AudioCategory.EFFECTS
	},
	OASIS_HEAL_PROJECTILE_3 = {
		category = AudioCategory.EFFECTS
	},
	OASIS_HEAL_PROJECTILE_4 = {
		category = AudioCategory.EFFECTS
	},
	OASIS_BUFF_PROJECTILE_1 = {
		category = AudioCategory.EFFECTS
	},
	OASIS_BUFF_PROJECTILE_2 = {
		category = AudioCategory.EFFECTS
	},
	OASIS_BUFF_PROJECTILE_3 = {
		category = AudioCategory.EFFECTS
	},
	OASIS_BUFF_PROJECTILE_4 = {
		category = AudioCategory.EFFECTS
	},
	OASIS_SWAP_HEAL = {
		category = AudioCategory.EFFECTS
	},
	OASIS_SWAP_BUFF = {
		category = AudioCategory.EFFECTS
	},
	OASIS_CANNOT_TARGET = {
		category = AudioCategory.EFFECTS
	},
	OASIS_WATER_VEIL_APPLY = {
		category = AudioCategory.EFFECTS
	},
	OASIS_WATER_VEIL_LOOP = {
		category = AudioCategory.EFFECTS
	},
	CANNON_FIRE_VICTORIOUS_NIGHTMARE = {
		category = AudioCategory.GAMEPLAY
	},
	CANNON_FIRE_VICTORIOUS_EMERALD = {
		category = AudioCategory.GAMEPLAY
	},
	CANNON_FIRE_VICTORIOUS_DIAMOND = {
		category = AudioCategory.GAMEPLAY
	},
	CANNON_FIRE_VICTORIOUS_PLATINUM = {
		category = AudioCategory.GAMEPLAY
	},
	CANNON_FIRE_VICTORIOUS_GOLD = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_INFLATE = {
		category = AudioCategory.COSMETICS
	},
	BALLOON_POP = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_POP_GHOSTLY = {
		category = AudioCategory.GAMEPLAY
	},
	FIREBALL_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	FIREBALL_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	LASSO_SWING = {
		category = AudioCategory.GAMEPLAY
	},
	LASSO_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	LASSO_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_CONSUME = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_CHANNEL = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BLOOD_HARVEST_GRIM_REAPER_CONSUME = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BLOOD_HARVEST_GRIM_REAPER_CHANNEL = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EASTER_GRIM_REAPER_CONSUME = {
		category = AudioCategory.GAMEPLAY
	},
	EASTER_GRIM_REAPER_CHANNEL = {
		category = AudioCategory.GAMEPLAY
	},
	TV_STATIC = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	TURRET_ON = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_OFF = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_ROTATE = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_SHOOT = {
		rollOffMaxDistance = 200,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TURRET_VAMPIRE_ON = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_VAMPIRE_OFF = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_VAMPIRE_ROTATE = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_VAMPIE_SHOOT = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_CREAM_SODA_ON = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_CREAM_SODA_OFF = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_CREAM_SODA_ROTATE = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_CREAM_SODA_SHOOT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_CREAM_SODA_SHOOT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_CREAM_SODA_SHOOT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_CREAM_SODA_SHOOT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_STARRYSOLDIER_ON = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_STARRYSOLDIER_OFF = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_STARRYSOLDIER_ROTATE = {
		category = AudioCategory.GAMEPLAY
	},
	TURRET_STARRYSOLDIER_SHOOT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DEFENDER_UPGRADE_DEFENSE_01 = {
		category = AudioCategory.GAMEPLAY
	},
	DEFENDER_UPGRADE_DEFENSE_02 = {
		category = AudioCategory.GAMEPLAY
	},
	DEFENDER_UPGRADE_DEFENSE_03 = {
		category = AudioCategory.GAMEPLAY
	},
	DEFENDER_UPGRADE_DEFENSE_04 = {
		category = AudioCategory.GAMEPLAY
	},
	DEFENDER_SUBZERO_UPGRADE_DEFENSE_01 = {
		category = AudioCategory.GAMEPLAY
	},
	DEFENDER_SUBZERO_UPGRADE_DEFENSE_02 = {
		category = AudioCategory.GAMEPLAY
	},
	DEFENDER_SUBZERO_UPGRADE_DEFENSE_03 = {
		category = AudioCategory.GAMEPLAY
	},
	DEFENDER_SUBZERO_UPGRADE_DEFENSE_04 = {
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_LIGHTNING_CAST = {
		category = AudioCategory.COSMETICS
	},
	WIZARD_LIGHTNING_LAND = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_ORB_CAST = {
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_ORB_TRAVEL_LOOP = {
		category = AudioCategory.COSMETICS
	},
	WIZARD_ORB_CONTACT_LOOP = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BATTLE_PASS_PROGRESS_LEVEL_UP = {
		category = AudioCategory.UI
	},
	BATTLE_PASS_PROGRESS_EXP_GAIN = {
		category = AudioCategory.UI
	},
	FLAMETHROWER_USE = {
		category = AudioCategory.GAMEPLAY
	},
	FLAMETHROWER_UPGRADE = {
		category = AudioCategory.EFFECTS
	},
	BRITTLE_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	EXTINGUISH = {
		category = AudioCategory.EFFECTS
	},
	RAVEN_SPACE_AMBIENT = {
		volume = 0.25,
		preload = false,
		category = AudioCategory.AMBIENCE
	},
	RAVEN_WING_FLAP = {
		category = AudioCategory.GAMEPLAY
	},
	RAVEN_CAW = {
		category = AudioCategory.COSMETICS
	},
	JADE_HAMMER_SLAM_TIER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	JADE_HAMMER_SLAM_TIER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	JADE_HAMMER_SLAM_TIER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	JADE_JUMP = {
		category = AudioCategory.GAMEPLAY
	},
	FALLEN_JADE_HAMMER_SLAM_TIER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FALLEN_JADE_HAMMER_SLAM_TIER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FALLEN_JADE_HAMMER_SLAM_TIER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FALLEN_JADE_JUMP = {
		category = AudioCategory.GAMEPLAY
	},
	STATUE = {
		category = AudioCategory.COSMETICS
	},
	CONFETTI = {
		rollOffMaxDistance = 80,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HEART = {
		category = AudioCategory.COSMETICS
	},
	SPRAY = {
		category = AudioCategory.GAMEPLAY
	},
	BEEHIVE_PRODUCE = {
		category = AudioCategory.EFFECTS
	},
	CATCH_BEE = {
		category = AudioCategory.GAMEPLAY
	},
	DEPOSIT_BEE = {
		category = AudioCategory.GAMEPLAY
	},
	BEE_NET_SWING = {
		category = AudioCategory.GAMEPLAY
	},
	PLACE_BEEHIVE = {
		category = AudioCategory.GAMEPLAY
	},
	HIVE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	BEE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	MEADOW_PLACE_BEEHIVE = {
		category = AudioCategory.GAMEPLAY
	},
	MEADOW_BEEHIVE_PRODUCE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MEADOW_BEEHIVE_PRODUCE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MEADOW_BEEHIVE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	ASCEND = {
		category = AudioCategory.COSMETICS
	},
	BED_ALARM = {
		category = AudioCategory.GAMEPLAY
	},
	BED_BREAK = {
		volume = 0.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BOUNTY_CLAIMED = {
		category = AudioCategory.EFFECTS
	},
	BOUNTY_ASSIGNED = {
		category = AudioCategory.EFFECTS
	},
	BAGUETTE_SWING = {
		category = AudioCategory.GAMEPLAY
	},
	BAGUETTE_HIT = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	TESLA_ZAP = {
		category = AudioCategory.EFFECTS
	},
	TESLA_SHORT_CIRCUIT_1 = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TESLA_SHORT_CIRCUIT_2 = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TESLA_SHORT_CIRCUIT_3 = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TESLA_SHORT_CIRCUIT_4 = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TRIGGERED = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	SIREN_SPIRIT_TRIGGERED = {
		category = AudioCategory.GAMEPLAY
	},
	SIREN_SPIRIT_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_LIGHT_ORB_CREATE = {
		volume = 0.6,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_LIGHT_ORB_HEAL = {
		volume = 0.6,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	TRINITY_VOID_ORB_CREATE = {
		volume = 0.6,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_VOID_ORB_HEAL = {
		volume = 0.6,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	DODO_BIRD_JUMP = {
		category = AudioCategory.GAMEPLAY
	},
	DODO_BIRD_DOUBLE_JUMP = {
		category = AudioCategory.GAMEPLAY
	},
	DODO_BIRD_MOUNT = {
		category = AudioCategory.GAMEPLAY
	},
	DODO_BIRD_DISMOUNT = {
		category = AudioCategory.GAMEPLAY
	},
	DODO_BIRD_SQUAWK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DODO_BIRD_SQUAWK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELD_CHARGE_START = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELD_CHARGE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELD_CHARGE_BASH = {
		category = AudioCategory.GAMEPLAY
	},
	ROCKET_LAUNCHER_FIRE = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ROCKET_LAUNCHER_FLYING_LOOP = {
		category = AudioCategory.EFFECTS
	},
	SMOKE_GRENADE_POP = {
		rollOffMaxDistance = 250,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SMOKE_GRENADE_EMIT_LOOP = {
		category = AudioCategory.EFFECTS
	},
	GOO_SPIT = {
		category = AudioCategory.EFFECTS
	},
	GOO_SPLAT = {
		category = AudioCategory.GAMEPLAY
	},
	GOO_EAT = {
		category = AudioCategory.EFFECTS
	},
	LUCKY_BLOCK_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	AXOLOTL_SWITCH_TARGETS = {
		rollOffMaxDistance = 80,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	KINGDOM_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	CHRISTMAS_MUSIC = {
		preload = false,
		volume = 0.35,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	HALLOWEEN_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	SUSPENSE_MUSIC = {
		preload = false,
		volume = 0.35,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	LOBBY_MUSIC_DRUMS = {
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	LOBBY_MUSIC = {
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	LOBBY_MUSIC_SUMMER = {
		volume = 0.1,
		preload = true,
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	LOBBY_MUSIC_FOREST = {
		preload = false,
		volume = 0.8,
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	LOBBY_MUSIC_HEAVEN = {
		preload = false,
		volume = 0.6,
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	LOBBY_MUSIC_CRYSTALMOUNT = {
		preload = false,
		volume = 0.7,
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	DESERT_LOBBY_MUSIC = {
		volume = 0.45,
		preload = true,
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	DESERT_BOSS_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	DESERT_TRAILER_MUSIC = {
		volume = 0.6,
		preload = true,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	SNAP_TRAP_SETUP = {
		category = AudioCategory.EFFECTS
	},
	SNAP_TRAP_CLOSE = {
		category = AudioCategory.EFFECTS
	},
	SNAP_TRAP_CONSUME_MARK = {
		category = AudioCategory.EFFECTS
	},
	GHOST_VACUUM_SUCKING_LOOP = {
		category = AudioCategory.EFFECTS
	},
	GHOST_VACUUM_SHOOT = {
		category = AudioCategory.EFFECTS
	},
	GHOST_VACUUM_CATCH = {
		category = AudioCategory.EFFECTS
	},
	FISHERMAN_GAME_START = {
		category = AudioCategory.UI
	},
	FISHERMAN_GAME_PULLING_LOOP = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	FISHERMAN_GAME_PROGRESS_INCREASE = {
		category = AudioCategory.UI
	},
	FISHERMAN_GAME_FISH_MOVE = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	FISHERMAN_GAME_LOOP = {
		volume = 0.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	FISHING_ROD_CAST = {
		category = AudioCategory.GAMEPLAY
	},
	FISHING_ROD_SPLASH = {
		category = AudioCategory.GAMEPLAY
	},
	SPEAR_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	SPEAR_THROW = {
		category = AudioCategory.COSMETICS
	},
	STOPWATCH_TICKING = {
		category = AudioCategory.EFFECTS
	},
	STOPWATCH_REWINDING = {
		category = AudioCategory.AMBIENCE
	},
	STOPWATCH_ACTIVATED = {
		category = AudioCategory.EFFECTS
	},
	PROMOTION_INDICATION = {
		category = AudioCategory.UI
	},
	PROMOTION_RANKUP = {
		category = AudioCategory.UI
	},
	PROMOTION_SHINE_LOOP = {
		category = AudioCategory.UI
	},
	BONK = {
		category = AudioCategory.GAMEPLAY
	},
	DANCE_PARTY = {
		category = AudioCategory.GAMEPLAY
	},
	CHARGE_TRIPLE_SHOT = {
		category = AudioCategory.EFFECTS
	},
	INFECTED_INITIAL_SPREAD = {
		category = AudioCategory.GAMEPLAY
	},
	INFECTED_HUMAN_DEATH = {
		category = AudioCategory.GAMEPLAY
	},
	GUIDED_MISSILE_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	GUIDED_MISSILE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	GUIDED_MISSILE_EXPLOSION = {
		category = AudioCategory.GAMEPLAY
	},
	FREIYA_PROC = {
		category = AudioCategory.GAMEPLAY
	},
	FREIYA_STRONG_PROC = {
		category = AudioCategory.GAMEPLAY
	},
	FREIYA_PASSIVE_UNLOCKED = {
		category = AudioCategory.GAMEPLAY
	},
	BUNNY_FREIYA_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	BUNNY_FREIYA_STACK = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_GOLD_FREIYA_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_PLATINUM_FREIYA_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_DIAMOND_FREIYA_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_EMERALD_FREIYA_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_NIGHTMARE_FREIYA_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_FREIYA_STACK = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	BURN_HIT = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BURN_LOOP = {
		category = AudioCategory.EFFECTS
	},
	STATIC_HIT = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ENCHANT_VOID_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	ENCHANT_VOID_EXPLODE = {
		category = AudioCategory.EFFECTS
	},
	ENCHANT_TABLE_REPAIR_HAMMER_1 = {
		category = AudioCategory.EFFECTS
	},
	ENCHANT_TABLE_REPAIR_HAMMER_2 = {
		category = AudioCategory.EFFECTS
	},
	ENCHANT_TABLE_REPAIR_HAMMER_3 = {
		category = AudioCategory.EFFECTS
	},
	ENCHANT_TABLE_REPAIR_HAMMER_4 = {
		category = AudioCategory.EFFECTS
	},
	ENCHANT_TABLE_REPAIRED = {
		volume = 1.4,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ENCHANT_TABLE_RESEARCH_IMPLODE = {
		volume = 1.4,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ENCHANT_TABLE_RESEARCH_CONSUME = {
		category = AudioCategory.EFFECTS
	},
	MINER_STONE_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MINER_STONE_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MINER_STONE_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	MINER_STONE_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_SQUISH = {
		volume = 2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SLIME_SQUISH_2 = {
		volume = 5,
		rollOffMaxDistance = 80,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GLIDER_GLIDE = {
		volume = 1,
		preloadPriority = 20,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GLIDER_OPEN = {
		volume = 0.7,
		preloadPriority = 20,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	YETI_ROAR = {
		category = AudioCategory.EFFECTS
	},
	BREAK_FROZEN_BLOCK = {
		category = AudioCategory.GAMEPLAY
	},
	HIT_FROZEN_BLOCK = {
		category = AudioCategory.GAMEPLAY
	},
	AERY_BUTTERFLY_SPAWN = {
		volume = 1.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	AERY_BUTTERFLY_CONSUME = {
		category = AudioCategory.GAMEPLAY
	},
	SANTA_BELLS = {
		volume = 0.2,
		preloadPriority = 20,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_AXE_LEAP = {
		category = AudioCategory.COSMETICS
	},
	VOID_AXE_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	COFFIN_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	UFO_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	GIFT_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	USE_SMOKE_CHARGE = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SMOKE_CHARGE_LOOP = {
		category = AudioCategory.EFFECTS
	},
	EMOTE_OPEN = {
		volume = 1.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EMOTE_CLOSE = {
		preload = false,
		volume = 0.35,
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	FIREWORK_LAUNCH = {
		category = AudioCategory.GAMEPLAY
	},
	FIREWORK_TRAIL = {
		category = AudioCategory.GAMEPLAY
	},
	FIREWORK_EXPLODE_1 = {
		volume = 1.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	FIREWORK_EXPLODE_2 = {
		volume = 1.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	FIREWORK_EXPLODE_3 = {
		volume = 1.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	FIREWORK_CRACKLE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FIREWORK_CRACKLE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FIREWORK_CRACKLE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_CHARGING = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_CHARGE_COMPLETE = {
		category = AudioCategory.EFFECTS
	},
	DAO_DASH = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_SLASH = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_CURSED_DASH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_CURSED_DASH_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_CURSED_DASH_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_CURSED_CHARGING = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_SNOW_RABBIT_DASH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_SNOW_RABBIT_DASH_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_SNOW_RABBIT_DASH_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DAO_SNOW_RABBIT_CHARGING = {
		category = AudioCategory.GAMEPLAY
	},
	DUCK_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DUCK_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DUCK_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DUCK_QUACK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DUCK_QUACK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DUCK_QUACK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DUCK_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	DUCK_ATTACK_2 = {
		category = AudioCategory.EFFECTS
	},
	DUCK_JUMP = {
		category = AudioCategory.GAMEPLAY
	},
	GLOVE_FLICK = {
		category = AudioCategory.COSMETICS
	},
	BROOM_SWEEP_EFFECT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BROOM_SWEEP_EFFECT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BROOM_SWEEP_EFFECT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BROOM_SWEEP_EFFECT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELD_GEN_LOOP = {
		preloadPriority = 1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TWIRLBLADE_SPIN = {
		category = AudioCategory.EFFECTS
	},
	ROCK_CRUMBLE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	ROCK_CRUMBLE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	ROCK_CRUMBLE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	TURN_TO_STONE = {
		category = AudioCategory.GAMEPLAY
	},
	MIDNIGHT_ACTIVATE = {
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	MIDNIGHT_FOLLOWING_TRAIL = {
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PAINT_SHOTGUN_BLAST = {
		volume = 0.2,
		preloadPriority = 20,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	MIDNIGHT_ATTACK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MIDNIGHT_ATTACK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MIDNIGHT_ATTACK_3 = {
		category = AudioCategory.EFFECTS
	},
	MIDNIGHT_ATTACK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	MIDNIGHT_ATTACK_5 = {
		category = AudioCategory.GAMEPLAY
	},
	CARROT_LAUNCHER_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	CARROT_LAUNCHER_IMPACT = {
		category = AudioCategory.GAMEPLAY
	},
	SHEEP_ALIEN_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SHEEP_ALIEN_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SHEEP_ALIEN_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VENDING_ROLL_TICK = {
		preload = false,
		category = AudioCategory.EFFECTS
	},
	VENDING_ROLL_PRIZE = {
		preload = false,
		category = AudioCategory.EFFECTS
	},
	SHEEP_TAME_1 = {
		preload = false,
		volume = 0.2,
		category = AudioCategory.GAMEPLAY
	},
	SHEEP_TAME_2 = {
		preload = false,
		volume = 0.2,
		category = AudioCategory.GAMEPLAY
	},
	SHEEP_TAME_3 = {
		preload = false,
		volume = 0.2,
		category = AudioCategory.GAMEPLAY
	},
	WHITE_RAVEN_FLYING_LOOP = {
		category = AudioCategory.COSMETICS
	},
	WHITE_RAVEN_SNATCH = {
		category = AudioCategory.COSMETICS
	},
	BEAST_ROAR = {
		category = AudioCategory.EFFECTS
	},
	ROCKET_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	BOBA_IMPACT = {
		category = AudioCategory.GAMEPLAY
	},
	BOBA_SHOOT = {
		category = AudioCategory.GAMEPLAY
	},
	BEEPING = {
		category = AudioCategory.GAMEPLAY
	},
	TORNADO_LAUNCHER_SHOOT = {
		category = AudioCategory.GAMEPLAY
	},
	TORNADO_LOOP = {
		category = AudioCategory.EFFECTS
	},
	FRYING_PAN_CHARGE = {
		category = AudioCategory.EFFECTS
	},
	FRYING_PAN_HIT = {
		category = AudioCategory.COSMETICS
	},
	DISASTER_TORNADO_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	INVISIBLE_LANDMINE_BEEP_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	INVISIBLE_LANDMINE_LONG_BEEP = {
		category = AudioCategory.GAMEPLAY
	},
	INVISIBLE_LANDMINE_EXPLOSION = {
		volume = 1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BEAR_CLAWS_SWIPE = {
		category = AudioCategory.GAMEPLAY
	},
	BEAR_CLAWS_FLURRY = {
		category = AudioCategory.EFFECTS
	},
	TELEPORT_ACTIVATION = {
		category = AudioCategory.EFFECTS
	},
	METAL_DETECTOR_BEEP = {
		volume = 0.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	LIGHT_SWORD_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHT_SWORD_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	INFERNAL_SWORD_CHARGE = {
		volume = 1.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	INFERNAL_SWORD_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	COIN_COLLECT = {
		category = AudioCategory.GAMEPLAY
	},
	DRONE_DAMAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DRONE_DAMAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DRONE_DAMAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DRONE_DEPLOY = {
		category = AudioCategory.EFFECTS
	},
	DRONE_EXPLODE = {
		category = AudioCategory.EFFECTS
	},
	DRONE_PROPELLER_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	GRAPPLING_HOOK_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	GRAPPLING_HOOK_EXTEND_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	GRAPPLING_HOOK_RETRACT_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	FLAG_DROP = {
		category = AudioCategory.EFFECTS
	},
	FLAG_BUFF = {
		category = AudioCategory.EFFECTS
	},
	MINICOPTER_LOOP = {
		volume = 0.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	MINICOPTER_START = {
		volume = 0.4,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	MINICOPTER_STOP = {
		volume = 0.4,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	MINICOPTER_EXPLODE = {
		category = AudioCategory.EFFECTS
	},
	MINICOPTER_DAMAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MINICOPTER_DAMAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MINICOPTER_DAMAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	MINICOPTER_BOUNCE_3 = {
		category = AudioCategory.EFFECTS
	},
	LIFE_STEAL_HEAL = {
		category = AudioCategory.EFFECTS
	},
	LIFE_STEAL_OVERHEAL = {
		preload = false,
		volume = 1.5,
		category = AudioCategory.EFFECTS
	},
	EXECUTE = {
		category = AudioCategory.GAMEPLAY
	},
	CRITICAL_STRIKE = {
		category = AudioCategory.GAMEPLAY
	},
	FLAG_CAPTURE = {
		category = AudioCategory.GAMEPLAY
	},
	VACUUM_CATCH = {
		category = AudioCategory.EFFECTS
	},
	ACTIVE_VACUUM_LOOP = {
		category = AudioCategory.EFFECTS
	},
	VOID_SHIELD_BREAK = {
		preload = false,
		volume = 0.35,
		category = AudioCategory.EFFECTS
	},
	VOID_HEALTH_DECAY = {
		category = AudioCategory.EFFECTS
	},
	VOID_THEME_SONG = {
		preload = false,
		volume = 0.2,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	VOID_CRAB_FOOTSTEPS = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_CRAB_BEAM_ATTACK = {
		category = AudioCategory.EFFECTS
	},
	VOID_CRAB_LUNGE_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_CRAB_BASIC_ATTACK = {
		category = AudioCategory.EFFECTS
	},
	VOID_CRAB_DAMAGED = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_CRAB_DEATH = {
		category = AudioCategory.GAMEPLAY
	},
	DINO_CHARGE_START = {
		category = AudioCategory.EFFECTS
	},
	DINO_CHARGE_LOOP = {
		category = AudioCategory.EFFECTS
	},
	DINO_CHARGE_STOP = {
		category = AudioCategory.EFFECTS
	},
	ELK_SUMMON = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ELK_DISMISS = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ELK_CHARGING_LOOP = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ELK_UPPERCUT = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_PORTAL_TELEPORT = {
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_PORTAL_LOOP = {
		preload = false,
		volume = 0.1,
		category = AudioCategory.GAMEPLAY
	},
	WIND_ORB_SPAWN = {
		category = AudioCategory.AMBIENCE
	},
	WIND_ORB_GET = {
		category = AudioCategory.AMBIENCE
	},
	WIND_LOOP = {
		category = AudioCategory.AMBIENCE
	},
	CELESTIAL_WIND_WALKER_ORB_SPAWN = {
		category = AudioCategory.AMBIENCE
	},
	CELESTIAL_WIND_WALKER_ORB_GET = {
		category = AudioCategory.AMBIENCE
	},
	CELESTIAL_WIND_WALKER_DOUBLE_JUMP_1 = {
		category = AudioCategory.AMBIENCE
	},
	CELESTIAL_WIND_WALKER_DOUBLE_JUMP_2 = {
		category = AudioCategory.AMBIENCE
	},
	STAR_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	STAR_CRUSH = {
		category = AudioCategory.EFFECTS
	},
	STAR_IDLE = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	GLITCH_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	WAVE_UPDATE = {
		category = AudioCategory.GAMEPLAY
	},
	SNIPER_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_POP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_POP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_POP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_POP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_STAGE_INCREASE = {
		category = AudioCategory.EFFECTS
	},
	PINATA_AMBIENT_LOOP = {
		category = AudioCategory.AMBIENCE
	},
	PINATA_COLLECT_CANDY = {
		category = AudioCategory.GAMEPLAY
	},
	PINATA_DEPOSIT_CANDY = {
		category = AudioCategory.EFFECTS
	},
	TOAD_CROAK = {
		preload = false,
		volume = 0.35,
		playbackSpeed = NumberRange.new(1.2, 1.3),
		category = AudioCategory.GAMEPLAY
	},
	TOY_HAMMER_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BLOCK_SLAM = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_DAGGER_CHARGE = {
		category = AudioCategory.EFFECTS
	},
	SPIRIT_DAGGER_SLASH = {
		category = AudioCategory.EFFECTS
	},
	SILENTNIGHT_DAGGER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	SILENTNIGHT_DAGGER_SLASH = {
		category = AudioCategory.GAMEPLAY
	},
	HANNAH_UNSHEATH_SWORD = {
		category = AudioCategory.GAMEPLAY
	},
	HANNAH_EXECUTE = {
		category = AudioCategory.GAMEPLAY
	},
	HANNAH_EXECUTE_VICTORIOUS = {
		category = AudioCategory.GAMEPLAY
	},
	HANNAH_EXECUTE_BUNNY = {
		category = AudioCategory.GAMEPLAY
	},
	HANNAH_EXECUTE_LUNAR = {
		category = AudioCategory.GAMEPLAY
	},
	OVERLOAD_LOOP = {
		category = AudioCategory.EFFECTS
	},
	OVERLOAD_BEEP = {
		category = AudioCategory.EFFECTS
	},
	PENGUIN_SURVIVAL_WAVE_TRACK = {
		volume = 0.2,
		preload = false,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	PENGUIN_SURVIVAL_INTERMISSION_TRACK = {
		volume = 0.2,
		preload = false,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	PENGUIN_SURVIVAL_BOSS_TRACK = {
		volume = 0.2,
		preload = false,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	PENGUIN_SURVIVAL_VICTORY_TRACK = {
		volume = 0.25,
		preload = false,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	PENGUIN_PIRATE = {
		category = AudioCategory.GAMEPLAY
	},
	PENGUIN_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	PENGUIN_ATTACK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	PENGUIN_ATTACK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	PENGUIN_SQUAWK_1 = {
		category = AudioCategory.COSMETICS
	},
	KING_PENGUIN_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	PENGUIN_DAMAGED_5 = {
		category = AudioCategory.GAMEPLAY
	},
	PENGUIN_DAMAGED_6 = {
		category = AudioCategory.GAMEPLAY
	},
	PENGUIN_DAMAGED_7 = {
		category = AudioCategory.GAMEPLAY
	},
	PENGUIN_DAMAGED_8 = {
		category = AudioCategory.GAMEPLAY
	},
	TENNIS_BALL_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	TENNIS_BALL_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	PIANO_CRASH = {
		category = AudioCategory.GAMEPLAY
	},
	SLIDE_WHISTLE_FALLING = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_CONE_MACHINE_MAKING = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_CONE_MACHINE_MAKING_FINISH = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_CONE_MACHINE_REPAIRED = {
		volume = 1.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SNOW_CONE_MACHINE_REPAIR_HAMMER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_CONE_MACHINE_REPAIR_HAMMER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_CONE_MACHINE_REPAIR_HAMMER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_CONE_MACHINE_REPAIR_HAMMER_4 = {
		category = AudioCategory.GAMEPLAY
	},
	HEALING_BACKPACK_USED = {
		category = AudioCategory.EFFECTS
	},
	EQUIP_JET_PACK = {
		category = AudioCategory.COSMETICS
	},
	EQUIP_TURTLE_SHELL = {
		category = AudioCategory.EFFECTS
	},
	JETPACK_LAUNCH = {
		category = AudioCategory.COSMETICS
	},
	JETPACK_COOLDOWN_READY = {
		category = AudioCategory.COSMETICS
	},
	NEW_DIAMOND_PICKUP = {
		volume = 1,
		preloadPriority = 90,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	NEW_EMERALD_PICKUP = {
		volume = 1,
		preloadPriority = 90,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_GENERATOR_AURA = {
		volume = 0.8,
		preloadPriority = 90,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EMERALD_GENERATOR_AURA = {
		volume = 0.8,
		preloadPriority = 90,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	RAVEN_WING_FLAP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	RAVEN_WING_FLAP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	RAVEN_WING_FLAP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	WIND_AMBIENCE = {
		volume = 3.8,
		preload = false,
		category = AudioCategory.AMBIENCE
	},
	FOREST_AMBIENCE = {
		volume = 0.3,
		preload = false,
		category = AudioCategory.AMBIENCE
	},
	DEATH = {
		volume = 0.5,
		preload = false,
		category = AudioCategory.GAMEPLAY
	},
	DEATH_FINAL = {
		volume = 0.5,
		preload = false,
		category = AudioCategory.GAMEPLAY
	},
	NEW_BOW_FIRE = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	NEW_ARROW_IMPACT = {
		category = AudioCategory.GAMEPLAY
	},
	VOLLEY_BOW_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	VOLLEY_ARROW_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	BUBBLE_POP1 = {
		category = AudioCategory.GAMEPLAY
	},
	BUBBLE_POP2 = {
		category = AudioCategory.GAMEPLAY
	},
	BUBBLE_POP3 = {
		category = AudioCategory.GAMEPLAY
	},
	BUBBLE_POP4 = {
		category = AudioCategory.GAMEPLAY
	},
	BUBBLE_POP5 = {
		category = AudioCategory.GAMEPLAY
	},
	BUBBLE_POP6 = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_SHIP_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	BLUNDERBUSS_SHOOT = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	PIRATE_EVENT_LOBBY_MUSIC = {
		preload = false,
		volume = 0.3,
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	PIRATE_EVENT_FIRST_ENTRY = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_MOTHERSHIP = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_THUNDER = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_SHIP_CREAK = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_SHIP_CRASH = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_MOTHERSHIP_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_MOTHERSHIP_IMPACT = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_DAZED = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_RAIN_LOOP = {
		category = AudioCategory.AMBIENCE
	},
	PIRATE_MOTHERSHIP_CANNON = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_MOTHERSHIP_CANNON_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_CANNON_1 = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_CANNON_2 = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_CANNON_3 = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_CANNON_EXPLODE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_CANNON_EXPLODE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_CANNON_EXPLODE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_EVENT_BIRD_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_SHOVEL_DIG = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_SHOVEL_DIG_TREASURE_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	PIRATE_SHOVEL_DIG_TREASURE_FOUND = {
		category = AudioCategory.GAMEPLAY
	},
	TREASURE_CHEST_SPAWN = {
		category = AudioCategory.GAMEPLAY
	},
	TREASURE_CHEST_UNLOCKING = {
		category = AudioCategory.GAMEPLAY
	},
	TREASURE_CHEST_UNLOCK = {
		category = AudioCategory.GAMEPLAY
	},
	TRUMPET_PLAY = {
		preload = false,
		volume = 0.7,
		category = AudioCategory.EFFECTS
	},
	GLITCHED_LUCKY_BLOCK_TELEPORT = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCHED_LUCKY_BLOCK_DAMAGE = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_OVERLAY_2 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_BASE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_BASE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_BASE_3 = {
		volume = 0.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_FIRE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_FIRE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_FIRE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_ICE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_ICE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_ICE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_NATURE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_NATURE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_CAST_NATURE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_LEARN_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_LEARN_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	WHIM_LEARN_NATURE = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_ASPECT_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_AMBIENT_1 = {
		category = AudioCategory.AMBIENCE
	},
	GLITCH_AMBIENT_2 = {
		category = AudioCategory.AMBIENCE
	},
	GLITCH_PARTICLE = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_SCREEN_GLITCH = {
		category = AudioCategory.GAMEPLAY
	},
	RELIC_APPLIED = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_ETABLE_IMPLOSION = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_ETABLE_ORB_CONSUME = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_ETABLE_REPAIR_HAMMER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_ETABLE_REPAIR_HAMMER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_ETABLE_REPAIR_HAMMER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GLITCH_ETABLE_REPAIR_HAMMER_4 = {
		category = AudioCategory.GAMEPLAY
	},
	STOMPER_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	XUROT_TRANSFORM = {
		category = AudioCategory.EFFECTS
	},
	XUROT_BREATH = {
		category = AudioCategory.EFFECTS
	},
	XUROT_FLAP_WING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	XUROT_FLAP_WING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	RECORD_PLAYER_LOOP = {
		volume = 0.3,
		rollOffMaxDistance = 70,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BLACKHOLE_END = {
		category = AudioCategory.GAMEPLAY
	},
	KALIYAH_WALL_HIT = {
		category = AudioCategory.EFFECTS
	},
	KALIYAH_PUNCH = {
		preload = false,
		volume = 0.8,
		category = AudioCategory.EFFECTS
	},
	KALIYAH_BLOCK_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	KALIYAH_EXPLOSION = {
		preload = false,
		volume = 1.2,
		category = AudioCategory.EFFECTS
	},
	DRAGON_ROAR = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_WING_FLAP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_WING_FLAP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	KNIFE_RAIN_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	MIRROR_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	SPIRIT_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	SPIRITORB_PULL_1 = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRITORB_PULL_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRITORB_PULL_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRITORB_ABSORB_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRITORB_ABSORB_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRITORB_ABSORB_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GRAVESTONE_USE = {
		category = AudioCategory.GAMEPLAY
	},
	GRAVESTONE_LOWER = {
		category = AudioCategory.EFFECTS
	},
	CRYPT_SUMMON_SKELETON = {
		category = AudioCategory.EFFECTS
	},
	CRYPT_SUMMON_SKELETON_XMAS = {
		category = AudioCategory.EFFECTS
	},
	CRYPT_SUMMON_SKELETON_CRYPTWRECKED = {
		category = AudioCategory.EFFECTS
	},
	GRAVESTONE_USE_CRYPTWRECKED = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_EMERGE = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_IDLE_1 = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_IDLE_2 = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_IDLE_3 = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_IDLE_4 = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_ATTACK_2 = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_ATTACK_3 = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_TAKE_DAMAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_TAKE_DAMAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_TAKE_DAMAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_DEATH = {
		category = AudioCategory.EFFECTS
	},
	WORMHOLE_TELEPORT = {
		category = AudioCategory.GAMEPLAY
	},
	WORMHOLE_USE = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	LANI_LANDING = {
		category = AudioCategory.EFFECTS
	},
	LANI_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	LANI_ASCEND = {
		category = AudioCategory.EFFECTS
	},
	LANI_USE_STAFF = {
		category = AudioCategory.GAMEPLAY
	},
	LANI_DASH = {
		category = AudioCategory.EFFECTS
	},
	COUNTDOWN_TICK = {
		category = AudioCategory.GAMEPLAY
	},
	COUNTDOWN_TICK_5 = {
		category = AudioCategory.GAMEPLAY
	},
	COUNTDOWN_TICK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	COUNTDOWN_TICK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	COUNTDOWN_TICK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	COUNTDOWN_TICK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	COUNTDOWN_GAMESTART = {
		category = AudioCategory.GAMEPLAY
	},
	ROLLING_BOULDER_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAVE_DEBRIS_FALL_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CAVE_DEBRIS_FALL_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CAVE_DEBRIS_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CAVE_DEBRIS_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GHOST_PILLAR_ERUPT = {
		category = AudioCategory.GAMEPLAY
	},
	GHOST_PILLAR_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	USE_HALLOWEEN_KEY = {
		category = AudioCategory.UI
	},
	GRAVEYARD_MUSIC_LOOP = {
		volume = 0.25,
		preload = true,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	GRAVEYARD_AMBIENCE_LOOP = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.AMBIENCE
	},
	GATE_OPENING = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	KEEPER_ATTACK = {
		volume = 0.3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	KEEPER_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	KEEPER_ROAR = {
		category = AudioCategory.GAMEPLAY
	},
	KEEPER_AMBIENT_LOOP = {
		category = AudioCategory.AMBIENCE
	},
	KEEPER_LOOP = {
		volume = 0.3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LTM_LOST = {
		category = AudioCategory.UI
	},
	HALLOWEEN_LTM_WIN = {
		category = AudioCategory.GAMEPLAY
	},
	CLUE_DISCOVERED = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CAVE_AMBIENCE = {
		category = AudioCategory.AMBIENCE
	},
	FOOTSTEP_CAVES_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FOOTSTEP_CAVES_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FOOTSTEP_CAVES_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FOOTSTEP_CAVES_4 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_2022_BOSS_MUSIC = {
		preload = false,
		volume = 0.4,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	HALLOWEEN_RAVENS_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_RAVENS_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_BOSS_BEAM = {
		category = AudioCategory.EFFECTS
	},
	HALLOWEEN_BOSS_RUNE_EXPLODE = {
		category = AudioCategory.EFFECTS
	},
	HALLOWEEN_BOSS_SPAWN = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_BOSS_FOG_LOOP = {
		volume = 2.5,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	HALLOWEEN_BOSS_ROCK_CRUMBLE = {
		category = AudioCategory.EFFECTS
	},
	HALLOWEEN_BOSS_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_BOSS_AMBIENT_LOOP = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.AMBIENCE
	},
	HALLOWEEN_BOSS_CAST = {
		category = AudioCategory.EFFECTS
	},
	HALLOWEEN_2022_LOBBY_MUSIC = {
		preload = false,
		volume = 0.08,
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	METEOR_LOBBY_MUSIC = {
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	ROCK_RUMBLE = {
		category = AudioCategory.GAMEPLAY
	},
	MAZE_FALL_INTO_CAVE = {
		category = AudioCategory.GAMEPLAY
	},
	MAZE_PULSING_LIGHT = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_BRIDGE_NPC_ENABLED = {
		category = AudioCategory.GAMEPLAY
	},
	SATELLITE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SATELLITE_ACTIVATE = {
		category = AudioCategory.GAMEPLAY
	},
	SATELLITE_DEACTIVATE = {
		category = AudioCategory.GAMEPLAY
	},
	SATELLITE_INTERACT = {
		volume = 2.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GLUE_ENCHANT_01 = {
		category = AudioCategory.EFFECTS
	},
	GLUE_ENCHANT_02 = {
		category = AudioCategory.EFFECTS
	},
	GLOOP_POP = {
		volume = 0.9,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GLOOP_LANDED = {
		category = AudioCategory.EFFECTS
	},
	GLOOP_LOOP = {
		category = AudioCategory.EFFECTS
	},
	GLOOP_TRIGGER = {
		volume = 0.7,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ORE_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	ORE_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	ORE_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	ORE_FAIL = {
		category = AudioCategory.GAMEPLAY
	},
	ORE_TRACK = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	ZOMBIE_GROWL_1 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ZOMBIE_GROWL_2 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ZOMBIE_GROWL_4 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ZOMBIE_GROWL_6 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	BLOCK_WOOL_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_WOOL_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_WOOL_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_WOOL_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_WOOD_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_WOOD_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_WOOD_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_WOOD_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_STONE_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_STONE_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_STONE_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_STONE_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_GRASS_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_GRASS_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_GRASS_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_GRASS_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SLEDGEHAMMER_SWING = {
		category = AudioCategory.GAMEPLAY
	},
	SLEDGEHAMMER_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SLEDGEHAMMER_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SLEDGEHAMMER_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	REPAIR_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SOLAR_PANEL_GENERATE = {
		category = AudioCategory.GAMEPLAY
	},
	SOLAR_PANEL_ENERGY = {
		category = AudioCategory.EFFECTS
	},
	JUGGERNAUT_GROUND_SMASH = {
		category = AudioCategory.GAMEPLAY
	},
	JUGGERNAUT_LEAP = {
		category = AudioCategory.EFFECTS
	},
	JUGGERNAUT_SPIN = {
		category = AudioCategory.EFFECTS
	},
	JUGGERNAUT_EXPLOSION_1 = {
		category = AudioCategory.GAMEPLAY
	},
	JUGGERNAUT_SPIN_LOOP = {
		category = AudioCategory.EFFECTS
	},
	JUGG_BARB_COOLDOWN_COMPLETE = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_SWORD_EQUIP = {
		category = AudioCategory.COSMETICS
	},
	LASER_SWORD_DEEQUIP = {
		preload = false,
		volume = 0.35,
		category = AudioCategory.COSMETICS
	},
	LASER_SWORD_HUM_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_SWORD_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_SWORD_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_SWORD_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_SWORD_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	JAILOR_SOUL_CONSUME = {
		category = AudioCategory.EFFECTS
	},
	JAILOR_IMPRISON_SLAM = {
		category = AudioCategory.UI
	},
	JUGGERNAUT_ATTACK_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	JUGGERNAUT_ATTACK_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	JUGGERNAUT_ATTACK_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	JUGGERNAUT_ATTACK_IMPACT_1 = {
		category = AudioCategory.EFFECTS
	},
	JUGGERNAUT_ATTACK_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	JUGGERNAUT_ATTACK_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_DEBRIS_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_DEBRIS_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_DEBRIS_3 = {
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_KILL_1 = {
		preloadPriority = 80,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_KILL_2 = {
		preloadPriority = 10,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_KILL_3 = {
		preloadPriority = 10,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_KILL_4 = {
		preloadPriority = 10,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_KILL_5 = {
		preloadPriority = 10,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_KILL_6 = {
		preloadPriority = 10,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_MULTIKILL_LOOP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_MULTIKILL_LOOP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_MULTIKILL_LOOP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_MULTIKILL_LOOP_5 = {
		category = AudioCategory.GAMEPLAY
	},
	PLAYER_MULTIKILL_LOOP_6 = {
		category = AudioCategory.GAMEPLAY
	},
	ATTACK_INDICATOR_1 = {
		volume = 0.15,
		preloadPriority = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ATTACK_INDICATOR_2 = {
		volume = 0.15,
		preloadPriority = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ATTACK_INDICATOR_3 = {
		volume = 0.15,
		preloadPriority = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SNOW_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	MOUNTAIN_DEBRIS_FALL_1 = {
		category = AudioCategory.GAMEPLAY
	},
	ICICLE_IMPACT_1 = {
		category = AudioCategory.EFFECTS
	},
	ICICLE_IMPACT_2 = {
		category = AudioCategory.EFFECTS
	},
	ICICLE_BREAK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	ICICLE_BREAK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	PRESENT_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	PRESENT_FOUND = {
		category = AudioCategory.GAMEPLAY
	},
	AMBIENCE_SNOW = {
		preload = false,
		volume = 0.12,
		bus = BedWarsAudioBuses.WINTER_AMBIENCE
	},
	FROST_SHIELD_EXPLOSION = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_HAMMER_SLAM = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_SHIELD_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	FROST_STORM = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_STORM_START = {
		category = AudioCategory.EFFECTS
	},
	FROST_STORM_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_STORM_END = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_EVENT_INTRO_MUSIC = {
		preload = false,
		volume = 0.85,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	WINTER_EVENT_BACKGROUND_MUSIC = {
		bus = BedWarsAudioBuses.WINTER_MUSIC
	},
	WINTER_MINIGAME_VICTORY = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_MINIGAME_DEFEAT = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_EVENT_LIGHT_SHINE = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_EVENT_MINIGAME_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	WINTER_EVENT_BOSS_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	WINTER_BOSS_ICE_BREAK = {
		category = AudioCategory.COSMETICS
	},
	WINTER_BOSS_ICICLE_IMPACT = {
		category = AudioCategory.EFFECTS
	},
	WINTER_BOSS_DEBRIS_FALL = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_BOSS_SPIN_LOOP = {
		category = AudioCategory.EFFECTS
	},
	WINTER_BOSS_SLAM = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_BOSS_FROST_LOOP = {
		category = AudioCategory.COSMETICS
	},
	WINTER_BOSS_AXE_SLAM = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_BOSS_DASH_ATTACK = {
		category = AudioCategory.EFFECTS
	},
	WINTER_BOSS_TRACK = {
		preload = false,
		volume = 1.25,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	WINTER_BOSS_VICTORY_TRACK = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	SNOWBALL_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	STRING_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	BLACKHOLE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	BLACKHOLE_COLLAPSE = {
		category = AudioCategory.EFFECTS
	},
	BLACKHOLE_BLOCKPULL_1 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BLACKHOLE_BLOCKPULL_2 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BLACKHOLE_BLOCKPULL_3 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BLACKHOLE_BLOCKPULL_4 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	METEOR_COSMIC_LOOP = {
		volume = 2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	METEOR_COSMIC_IMPACT = {
		volume = 2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	METEOR_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	METEOR_HITS = {
		category = AudioCategory.GAMEPLAY
	},
	STAR_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	STAR_FIRE = {
		volume = 0.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	COSMIC_LUCKY_BLOCK_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	COSMIC_LUCKY_BLOCK_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	COSMIC_LUCKY_BLOCK_BOUNCE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	COSMIC_LUCKY_BLOCK_BOUNCE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	COSMIC_LUCKY_BLOCK_BOUNCE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	COSMIC_LUCKY_BLOCK_FLY_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	TRACTOR_BEAM_LOOP = {
		category = AudioCategory.EFFECTS
	},
	UFO_HOLDING_ABDUCTEE = {
		category = AudioCategory.EFFECTS
	},
	UFO_EXIT = {
		category = AudioCategory.EFFECTS
	},
	UFO_ENTER = {
		category = AudioCategory.EFFECTS
	},
	UFO_ENGINE_LOOP = {
		category = AudioCategory.EFFECTS
	},
	UFO_EJECT_PLAYER = {
		category = AudioCategory.EFFECTS
	},
	ORB_SAT_ACTIVATE = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ORB_SAT_LASER_AMBIENT_LOOP = {
		category = AudioCategory.AMBIENCE
	},
	ORB_SAT_LASER_CHARGE = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ORB_SAT_LASER_FIRE_LOOP = {
		volume = 1.7,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ORB_SAT_LASER_IMPACT_LOOP = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ORB_SAT_LASER_POWER_DOWN = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPARKLER_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SEAHORSE_DAMAGE_BEAM = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_HEAL_BEAM = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_EVOLVE_1 = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_EVOLVE_2 = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_EVOLVE_3 = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_DAMAGE_SHOT_1 = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_DAMAGE_SHOT_2 = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_HEAL_SHOT_1 = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_HEAL_SHOT_2 = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_FREEZE = {
		category = AudioCategory.EFFECTS
	},
	SEAHORSE_SPEEDUP = {
		category = AudioCategory.EFFECTS
	},
	CHRISTMAS_ELDERTREE_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	CHRISTMAS_ELDERTREE_PICKUP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CHRISTMAS_ELDERTREE_PICKUP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CHRISTMAS_ELDERTREE_PICKUP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	CHRISTMAS_ELDERTREE_PICKUP_5 = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_MINER_ICE_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_MINER_ICE_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_MINER_ICE_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	WINTER_MINER_ICE_BREAK = {
		category = AudioCategory.COSMETICS
	},
	CONFETTI_POPPER = {
		category = AudioCategory.GAMEPLAY
	},
	NYE_COUNTDOWN = {
		category = AudioCategory.GAMEPLAY
	},
	BALL_DROP_COMPLETE = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_OPEN = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_CLOSE = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_SHIMMER = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_REVEAL_COMMON = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_REVEAL_UNCOMMON = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_REVEAL_RARE = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_REVEAL_EPIC = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_REVEAL_LEGENDARY = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_REVEAL_MYTHIC = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_PREVIEW_COMMON = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_PREVIEW_UNCOMMON = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_PREVIEW_RARE = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_PREVIEW_EPIC = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_PREVIEW_LEGENDARY = {
		category = AudioCategory.GAMEPLAY
	},
	LUCKY_BOX_PREVIEW_MYTHIC = {
		category = AudioCategory.GAMEPLAY
	},
	CLOUD_ENCHANT_SPAWN = {
		category = AudioCategory.EFFECTS
	},
	CLOUD_ENCHANT_DESPAWN = {
		category = AudioCategory.EFFECTS
	},
	CLOUD_ENCHANT_LOOP = {
		category = AudioCategory.EFFECTS
	},
	WIND_HIT_SHOUD_1 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_HIT_SHOUD_2 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_HIT_SHOUD_3 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_HIT_SHOUD_4 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_HIT_SHOUD_5 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_ENCHANT_LOOP_1 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_ENCHANT_LOOP_2 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_ENCHANT_LOOP_3 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_ENCHANT_LOOP_4 = {
		category = AudioCategory.AMBIENCE
	},
	WIND_ENCHANT_APPLY = {
		preload = false,
		volume = 1.75,
		category = AudioCategory.AMBIENCE
	},
	FOREST_ENCHANT_APPLY = {
		preload = false,
		volume = 1.75,
		category = AudioCategory.AMBIENCE
	},
	CLOUD_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	FIRE_ENCHANT_APPLY = {
		preload = false,
		volume = 1.75,
		category = AudioCategory.EFFECTS
	},
	STATIC_ENCHANT_APPLY = {
		preload = false,
		volume = 1.75,
		category = AudioCategory.EFFECTS
	},
	PLUNDER_ENCHANT_APPLY = {
		preload = false,
		volume = 1.75,
		category = AudioCategory.EFFECTS
	},
	GROUNDED_EFFECT_APPLY = {
		preload = false,
		volume = 1.9,
		category = AudioCategory.GAMEPLAY
	},
	SOUND_BARRIER_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	EXECUTE_ENCHANT_APPLY = {
		preload = false,
		volume = 1.75,
		category = AudioCategory.EFFECTS
	},
	CRIT_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	SOUL_REAVER_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	FORTUNE_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	CLEAVE_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	BERSERKER_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	BERSERKER_KIT_ACTIVATE = {
		category = AudioCategory.EFFECTS
	},
	BERSERKER_KIT_LOOP = {
		category = AudioCategory.EFFECTS
	},
	BERSERKER_DAMAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BERSERKER_DAMAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BERSERKER_DAMAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FOREST_ENCHANT_ACTIVATE = {
		category = AudioCategory.AMBIENCE
	},
	SHATTER_STRIKE_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	BLOCKING_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	ABSORPTION_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	FROST_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	HEAVY_HITTER_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	EXPLOSIVE_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	ENDURANCE_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	SWIFT_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	EFFICIENCY_ENCHANT_APPLY = {
		category = AudioCategory.EFFECTS
	},
	ENDURANCE_ROCK_HIT_1 = {
		category = AudioCategory.EFFECTS
	},
	ENDURANCE_ROCK_HIT_2 = {
		category = AudioCategory.EFFECTS
	},
	ENDURANCE_ROCK_HIT_3 = {
		category = AudioCategory.EFFECTS
	},
	EFFICIENCY_TOOL_ENCHANT_HIT_1 = {
		category = AudioCategory.EFFECTS
	},
	EFFICIENCY_TOOL_ENCHANT_HIT_2 = {
		category = AudioCategory.EFFECTS
	},
	EFFICIENCY_TOOL_ENCHANT_HIT_3 = {
		category = AudioCategory.EFFECTS
	},
	EFFICIENCY_TOOL_ENCHANT_HIT_4 = {
		category = AudioCategory.EFFECTS
	},
	CLEAVE_ENCHANT_HIT = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SWIFT_ENCHANT_PULSE_ACTIVATE = {
		category = AudioCategory.EFFECTS
	},
	SOUL_REAVER_LOOP = {
		category = AudioCategory.EFFECTS
	},
	ABSORPTION_BUBBLE_ABSORB_1 = {
		category = AudioCategory.GAMEPLAY
	},
	ABSORPTION_BUBBLE_ABSORB_2 = {
		category = AudioCategory.GAMEPLAY
	},
	ABSORPTION_BUBBLE_ABSORB_3 = {
		category = AudioCategory.GAMEPLAY
	},
	ABSORPTION_BUBBLE_ABSORB_4 = {
		category = AudioCategory.GAMEPLAY
	},
	ABSORPTION_BUBBLE_ABSORB_5 = {
		category = AudioCategory.GAMEPLAY
	},
	ABSORPTION_BUBBLE_POP = {
		category = AudioCategory.EFFECTS
	},
	SOUND_BARRIER_CD_OFF = {
		category = AudioCategory.EFFECTS
	},
	SOUND_BARRIER_PULSE = {
		category = AudioCategory.EFFECTS
	},
	ARMOR_BLOCK_CD_OFF = {
		category = AudioCategory.GAMEPLAY
	},
	ARMOR_BLOCK_HIT_BLOCKED = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_ARMOR_CD_OFF = {
		category = AudioCategory.EFFECTS
	},
	FROST_ARMOR_ICY_BLAST = {
		category = AudioCategory.EFFECTS
	},
	SHATTER_STRIKE_BREAK_1 = {
		category = AudioCategory.COSMETICS
	},
	SHATTER_STRIKE_BREAK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SHATTER_STRIKE_BREAK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	HEAVY_HITTER_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HEAVY_HITTER_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HEAVY_HITTER_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOIDIFY_ARMOR = {
		category = AudioCategory.EFFECTS
	},
	BRIDGE_RETRACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_RETRACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_RETRACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_EXPAND_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_EXPAND_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_EXPAND_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_DESTROY_1 = {
		volume = 0.12,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_DESTROY_2 = {
		volume = 0.12,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_DESTROY_3 = {
		volume = 0.12,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_FORTIFY_BLOCK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_FORTIFY_BLOCK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_FORTIFY_BLOCK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_RETRACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_RETRACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_RETRACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_EXPAND_1 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_EXPAND_2 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_EXPAND_3 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_DESTROY_1 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_DESTROY_2 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_BRIDGE_DESTROY_3 = {
		category = AudioCategory.GAMEPLAY
	},
	NUTCRACKER_BUILDER_OVERLAY_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_SPAWN = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_ROTATE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_ROTATE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_ROTATE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_FLAMETHROWER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_FLAMETHROWER_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_TARGET = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_UPGRADE = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_SHEEP_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	UMBRA_HAT_ATTACHED = {
		category = AudioCategory.EFFECTS
	},
	UMBRA_HAT_THROW = {
		category = AudioCategory.EFFECTS
	},
	UMBRA_HAT_THROW_LOOP = {
		category = AudioCategory.EFFECTS
	},
	UMBRA_PEEKING_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	UMBRA_TELEPORT_DEPART = {
		category = AudioCategory.EFFECTS
	},
	UMBRA_TELEPORT_LOOP = {
		category = AudioCategory.EFFECTS
	},
	UMBRA_TELEPORT_ARRIVE = {
		category = AudioCategory.EFFECTS
	},
	UMBRA_TELEPORT_BOUNCE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	UMBRA_TELEPORT_BOUNCE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	UMBRA_TELEPORT_BOUNCE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	UMBRA_TELEPORT_BOUNCE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	UMBRA_INVULNERABILITY_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	GUARDIAN_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GUARDIAN_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GUARDIAN_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GUARDIAN_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	GUARDIAN_DEATH = {
		category = AudioCategory.GAMEPLAY
	},
	GUARDIAN_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_FIST_SLAM = {
		volume = 2,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_HAMMER_SLAM = {
		volume = 2,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_BLOCK_DISLODGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_BLOCK_DISLODGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_BLOCK_DISLODGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_BLOCK_DISLODGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_IDLE_SPAWN = {
		volume = 3,
		rollOffMaxDistance = 300,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_IDLE_1 = {
		volume = 3,
		rollOffMaxDistance = 300,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_IDLE_2 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_IDLE_3 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_IDLE_4 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_DEATH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	TITAN_DEATH_2 = {
		volume = 3,
		rollOffMaxDistance = 300,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_SUMMON_PILLARS = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	TITAN_FORCEFIELD = {
		volume = 2,
		rollOffMaxDistance = 60,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TITAN_ZAP = {
		volume = 1.5,
		rollOffMaxDistance = 60,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_FIST_SLAM = {
		volume = 2,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_HAMMER_SLAM = {
		volume = 2,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_BLOCK_DISLODGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_BLOCK_DISLODGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_BLOCK_DISLODGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_BLOCK_DISLODGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_IDLE_SPAWN = {
		volume = 3,
		rollOffMaxDistance = 300,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_IDLE_1 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_IDLE_2 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_IDLE_3 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_IDLE_4 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_DEATH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_DEATH_2 = {
		volume = 3,
		rollOffMaxDistance = 300,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_SUMMON_PILLARS = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	VOID_TITAN_FORCEFIELD = {
		volume = 2,
		rollOffMaxDistance = 60,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_ZAP = {
		volume = 1.5,
		rollOffMaxDistance = 60,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_PORTAL_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_PORTAL_OPEN_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_PORTAL_OPEN_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_PORTAL_OPEN_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_PORTAL_OPEN_4 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_RECALL = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_TITAN_RECALL_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_FIST_SLAM = {
		volume = 2,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_HAMMER_SLAM = {
		volume = 2,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_BLOCK_DISLODGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_BLOCK_DISLODGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_BLOCK_DISLODGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_BLOCK_DISLODGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_IDLE_SPAWN = {
		volume = 3,
		rollOffMaxDistance = 300,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_IDLE_1 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_IDLE_2 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_IDLE_3 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_IDLE_4 = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_DEATH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_DEATH_2 = {
		volume = 3,
		rollOffMaxDistance = 300,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_SUMMON_PILLARS = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIRIT_TITAN_FORCEFIELD = {
		volume = 2,
		rollOffMaxDistance = 60,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_ZAP = {
		volume = 1.5,
		rollOffMaxDistance = 60,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_RECALL = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_TITAN_RECALL_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	OWL_HOOT = {
		category = AudioCategory.EFFECTS
	},
	OWL_FLY = {
		category = AudioCategory.EFFECTS
	},
	OWL_SHOOT_1 = {
		category = AudioCategory.EFFECTS
	},
	OWL_SHOOT_2 = {
		category = AudioCategory.EFFECTS
	},
	OWL_SHOOT_3 = {
		category = AudioCategory.EFFECTS
	},
	OWL_HOOT_1 = {
		category = AudioCategory.EFFECTS
	},
	OWL_HOOT_2 = {
		category = AudioCategory.EFFECTS
	},
	OWL_HOOT_3 = {
		category = AudioCategory.EFFECTS
	},
	OWL_HOOT_4 = {
		category = AudioCategory.EFFECTS
	},
	OWL_CUTE_1 = {
		category = AudioCategory.EFFECTS
	},
	OWL_CUTE_2 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_HOOT = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_FLY = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_SHOOT_1 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_SHOOT_2 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_SHOOT_3 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_HOOT_1 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_HOOT_2 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_HOOT_3 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_HOOT_4 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_CUTE_1 = {
		category = AudioCategory.EFFECTS
	},
	FIRE_OWL_CUTE_2 = {
		category = AudioCategory.EFFECTS
	},
	HAND_CLAP = {
		category = AudioCategory.GAMEPLAY
	},
	DISCO_BEAT = {
		category = AudioCategory.EFFECTS
	},
	ATOMIC_SHRINK = {
		category = AudioCategory.COSMETICS
	},
	SWORD_SPARKLE = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.COSMETICS
	},
	RAVE_MUSIC = {
		category = AudioCategory.COSMETICS
	},
	CAITLYN_CONTRACT_ACCEPT = {
		category = AudioCategory.EFFECTS
	},
	CAITLYN_CONTRACT_FINISH = {
		category = AudioCategory.EFFECTS
	},
	RAINBOW_BACKPACK_PRISM_HIT_1 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_BACKPACK_PRISM_HIT_2 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_BACKPACK_PRISM_HIT_3 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_BACKPACK_PRISM_HIT_4 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_EXPLODE = {
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_BRIDGE_AURA = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	RAINBOW_BRIDGE_CREATE = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.AMBIENCE
	},
	QUEEN_BEE_GLIDE = {
		category = AudioCategory.EFFECTS
	},
	BEEHIVE_GRENADE_EXPLODE = {
		category = AudioCategory.EFFECTS
	},
	MURDER_GAME_SHEEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MURDER_GAME_SHEEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MURDER_GAME_SHEEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	MURDER_GAME_SHEEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLD_SPIRIT_DAGGER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	GOLD_SPIRIT_DAGGER_SLASH = {
		category = AudioCategory.GAMEPLAY
	},
	PLAT_SPIRIT_DAGGER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	PLAT_SPIRIT_DAGGER_SLASH = {
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_SPIRIT_DAGGER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_SPIRIT_DAGGER_SLASH = {
		category = AudioCategory.GAMEPLAY
	},
	NIGHTMARE_SPIRIT_DAGGER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	NIGHTMARE_SPIRIT_DAGGER_SLASH = {
		category = AudioCategory.GAMEPLAY
	},
	RAINBOW_AXE_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	RAINBOW_AXE_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	RAINBOW_AXE_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	RAINBOW_AXE_HIT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	RAINBOW_AXE_HIT_5 = {
		category = AudioCategory.GAMEPLAY
	},
	RAINBOW_AXE_HIT_6 = {
		category = AudioCategory.GAMEPLAY
	},
	RAINBOW_AXE_HIT_7 = {
		category = AudioCategory.GAMEPLAY
	},
	RAINBOW_AXE_ABILITY = {
		category = AudioCategory.EFFECTS
	},
	RAINBOW_INIT = {
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_OPEN_POT_OF_GOLD = {
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_AMBIENT_LOOP = {
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_LB_AMBIENT_LOOP = {
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_LB_HIT_1 = {
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_LB_HIT_2 = {
		category = AudioCategory.AMBIENCE
	},
	RAINBOW_LB_HIT_3 = {
		category = AudioCategory.AMBIENCE
	},
	DRILL_DEPLOY = {
		category = AudioCategory.EFFECTS
	},
	DRILL_LOOP = {
		category = AudioCategory.EFFECTS
	},
	DRILL_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	BLOSSOM_SPIRIT_ATTACK_IDLE = {
		category = AudioCategory.GAMEPLAY
	},
	BLOSSOM_SPIRIT_DEFENSE_IDLE = {
		category = AudioCategory.GAMEPLAY
	},
	BLOSSOM_SPIRIT_KNOCKBACK_IDLE = {
		category = AudioCategory.GAMEPLAY
	},
	BLOSSOM_SPIRIT_HEAL_IDLE = {
		category = AudioCategory.EFFECTS
	},
	BLOSSOM_SPIRIT_ATTACK_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	BLOSSOM_SPIRIT_DEFENSE_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	BLOSSOM_SPIRIT_KNOCKBACK_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	BLOSSOM_SPIRIT_HEAL_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	BLOSSOM_SPIRIT_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	BLOSSOM_SPIRIT_DEFENSE = {
		category = AudioCategory.GAMEPLAY
	},
	BLOSSOM_SPIRIT_KNOCKBACK = {
		category = AudioCategory.GAMEPLAY
	},
	BLOSSOM_SPIRIT_HEAL = {
		category = AudioCategory.EFFECTS
	},
	SAND_SPEAR_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	SAND_SPEAR_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	SAND_SPEAR_BOUNCE = {
		category = AudioCategory.EFFECTS
	},
	SAND_SPEAR_LOOP = {
		category = AudioCategory.EFFECTS
	},
	EGG_EXPLOSION = {
		category = AudioCategory.EFFECTS
	},
	EGG_LAUNCH = {
		category = AudioCategory.COSMETICS
	},
	EGG_FOUND = {
		category = AudioCategory.GAMEPLAY
	},
	WEB_LAUNCH = {
		category = AudioCategory.GAMEPLAY
	},
	WEB_CAUGHT = {
		category = AudioCategory.COSMETICS
	},
	ANGRY_BEE = {
		volume = 1.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	FLOWER_BLOOM = {
		category = AudioCategory.COSMETICS
	},
	FLOWER_PLANT = {
		category = AudioCategory.GAMEPLAY
	},
	POT_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELDER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELDER_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELDER_SMASH = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELDER_CHARGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SHIELDER_SMASH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_LIGHTNING_STRIKE_CAST = {
		category = AudioCategory.EFFECTS
	},
	WIZARD_LIGHTNING_STRIKE = {
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_LIGHTNING_STRIKE_02 = {
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_LIGHTNING_STRIKE_03 = {
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_LIGHTNING_STRIKE_04 = {
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_LIGHTNING_STORM = {
		category = AudioCategory.GAMEPLAY
	},
	WIZARD_SHOCKWAVE = {
		category = AudioCategory.GAMEPLAY
	},
	GIFT_BOX_UNWRAP = {
		category = AudioCategory.GAMEPLAY
	},
	GIFT_BOX_OPEN = {
		category = AudioCategory.GAMEPLAY
	},
	HEADSHOT = {
		volume = 1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HEADHUNTER_SHOOT_1 = {
		volume = 1.1,
		preload = false,
		category = AudioCategory.GAMEPLAY
	},
	HEADHUNTER_SHOOT_2 = {
		volume = 1.1,
		preload = false,
		category = AudioCategory.GAMEPLAY
	},
	HEADHUNTER_SHOOT_3 = {
		volume = 1.1,
		preload = false,
		category = AudioCategory.GAMEPLAY
	},
	HEADHUNTER_SHOOT_4 = {
		volume = 1.1,
		preload = false,
		category = AudioCategory.GAMEPLAY
	},
	TRAVELING_MERCHANT_PURCHASE_RARE = {
		preload = true,
		category = AudioCategory.UI
	},
	TRAVELING_MERCHANT_PURCHASE_EPIC = {
		preload = true,
		category = AudioCategory.UI
	},
	TRAVELING_MERCHANT_PURCHASE_UNIQUE = {
		preload = true,
		category = AudioCategory.UI
	},
	SKULL_DROP_ITEM_MERGE = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_DROP_ITEM_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_DROP_SKULL_PICKUP = {
		preload = false,
		volume = 0.38,
		category = AudioCategory.GAMEPLAY
	},
	SKULL_DROP_SKULL_DEPOSIT_01 = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_DROP_SKULL_DEPOSIT_02 = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_DROP_SKULL_DEPOSIT_03 = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_DROP_SKULL_DEPOSIT_04 = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_DROP_ROUND_ENDING_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	UNDERWORLD_BOSS_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	SKULL_LOOP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_LOOP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_LOOP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_LOOP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	LTM_GOAL_MOVING_SOUND = {
		category = AudioCategory.GAMEPLAY
	},
	IMPULSE_GUN_FIRE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	IMPULSE_GUN_FIRE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	IMPULSE_GUN_FIRE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SKY_SCYTHE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SKY_SCYTHE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SKY_SCYTHE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FLYING_LUCKY_BLOCK_WING_FLAP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FLYING_LUCKY_BLOCK_WING_FLAP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FLYING_CLOUD_DISMOUNT = {
		category = AudioCategory.EFFECTS
	},
	FLYING_CLOUD_MOUNT = {
		category = AudioCategory.EFFECTS
	},
	FLYING_CLOUD_DAMAGE_01 = {
		category = AudioCategory.GAMEPLAY
	},
	FLYING_CLOUD_DAMAGE_02 = {
		category = AudioCategory.GAMEPLAY
	},
	FLYING_CLOUD_DAMAGE_03 = {
		category = AudioCategory.GAMEPLAY
	},
	HOT_AIR_BALLOON_MOUNT = {
		category = AudioCategory.EFFECTS
	},
	HOT_AIR_BALLOON_DISMOUNT = {
		category = AudioCategory.EFFECTS
	},
	HOT_AIR_BALLOON_THRUSTER_START = {
		category = AudioCategory.EFFECTS
	},
	HOT_AIR_BALLOON_THRUSTER_LOOP = {
		category = AudioCategory.EFFECTS
	},
	SPIRIT_BRIDGE_AOE_ACTIVATED = {
		category = AudioCategory.EFFECTS
	},
	SPIRIT_BRIDGE_AOE_ARMOR_APPLIED = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_CHARGE_01 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_CHARGE_02 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_CHARGE_03 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_CHARGE_04 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_CHARGE_05 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_CHARGE_06 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_CHARGE_07 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_LOOP = {
		category = AudioCategory.EFFECTS
	},
	SPIRIT_BRIDGE_PROJECTILE_LAND = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_PROJECTILE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_BRIDGE_SPIRIT_HEAL = {
		category = AudioCategory.EFFECTS
	},
	ELECTRIC_DASH = {
		category = AudioCategory.EFFECTS
	},
	ELECTRIC_DASH_DAMAGE = {
		category = AudioCategory.GAMEPLAY
	},
	ELECTRIC_DASH_READY = {
		category = AudioCategory.EFFECTS
	},
	ELECTRIC_DASH_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	ELECTRIC_DASH_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	ELECTRIC_DASH_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	ELECTRIC_DASH_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	EXPERIENCE_ORB_GAIN = {
		category = AudioCategory.GAMEPLAY
	},
	MAX_EXPERIENCE_ORB_GAIN = {
		category = AudioCategory.GAMEPLAY
	},
	CARD_UPGRADE_AVAILABLE = {
		category = AudioCategory.EFFECTS
	},
	CARD_UPGRADE_SELECT = {
		category = AudioCategory.EFFECTS
	},
	CARD_TURN = {
		category = AudioCategory.EFFECTS
	},
	CARD_THROW_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CARD_THROW_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CARD_THROW_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CARD_THROW_4 = {
		category = AudioCategory.GAMEPLAY
	},
	CARD_THROW_5 = {
		category = AudioCategory.GAMEPLAY
	},
	MATCH_MUSIC_EARLY = {
		preload = false,
		volume = 0.225,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	MATCH_MUSIC_LATE = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	MATCH_MUSIC_FORGE = {
		preload = false,
		volume = 0.14,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	MATCH_MUSIC_HALLOWEEN = {
		preload = false,
		volume = 0.035,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	SWORD_CHARGE_READY = {
		category = AudioCategory.COSMETICS
	},
	MATCH_LEVEL_UP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MATCH_LEVEL_UP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DAGGER_READY = {
		category = AudioCategory.EFFECTS
	},
	DAGGER_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DAGGER_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DAGGER_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DAGGER_SWING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SCYTHE_SPIN_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SCYTHE_SPIN_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SCYTHE_SPIN_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SCYTHE_SWING_1 = {
		category = AudioCategory.COSMETICS
	},
	SCYTHE_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SCYTHE_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SCYTHE_PULL_1 = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	SCYTHE_PULL_2 = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	SCYTHE_SPIRIT_STATE = {
		category = AudioCategory.EFFECTS
	},
	BOXING_GLOVE_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	BUBBLE_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	STAR_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	CAN_OF_BEANS_FART_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CAN_OF_BEANS_FART_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CAN_OF_BEANS_FART_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CHICKEN_DEPLOY = {
		category = AudioCategory.COSMETICS
	},
	CHICKEN_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	CHICKEN_ATTACK_2 = {
		category = AudioCategory.EFFECTS
	},
	CHICKEN_ATTACK_3 = {
		category = AudioCategory.EFFECTS
	},
	CHICKEN_WALK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CHICKEN_WALK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CHICKEN_WALK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CHICKEN_WALK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	CHICKEN_DEATH = {
		category = AudioCategory.GAMEPLAY
	},
	CHICKEN_EGG_CRACK = {
		category = AudioCategory.EFFECTS
	},
	FORGE_HAMMER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_HAMMER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_COMPLETE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_COMPLETE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_COMPLETE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_COMPLETE_5 = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_COMPLETE_6 = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_VOLCANIC_SUCCESS = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_VOLCANIC_UI_TICK = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_AMBIENT = {
		category = AudioCategory.AMBIENCE
	},
	FORGE_AMBIENT_UPGRADE_AVAILABLE = {
		category = AudioCategory.AMBIENCE
	},
	FORGE_CRYSTAL_EXPLODE = {
		category = AudioCategory.COSMETICS
	},
	FORGE_VOLCANIC_FAIL = {
		category = AudioCategory.GAMEPLAY
	},
	FORGE_VOLCANIC_NEAR_SUCCESS = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_SPLATTER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_SPLATTER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_SPLATTER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_SHOT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_SHOT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_SHOT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_JUMP_STUCK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_JUMP_STUCK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GUMBALL_LAUNCHER_JUMP_STUCK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GUM_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GUM_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GUM_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GUM_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	CHOMP = {
		category = AudioCategory.EFFECTS
	},
	CRAB_BOSS_SPAWN_GLOBAL = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_SPAWN_LOCAL = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_FLIP = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_FLIP_BUILDUP = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_DEATH = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_POISON_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_BURROW_IN = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_BURROW_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_BURROW_OUT = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_STAB_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_CLAW_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_IMPACT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_LAUNCH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_LAUNCH_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_LAUNCH_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_LAUNCH_4 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CRAB_BOSS_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CONDIMENT_GUN_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CONDIMENT_GUN_SHOT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CONDIMENT_GUN_SHOT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CONDIMENT_GUN_SHOT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	HOTDOG_BAT_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HOTDOG_BAT_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HOTDOG_BAT_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FORK_TRIDENT_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	FORK_TRIDENT_STAB = {
		category = AudioCategory.GAMEPLAY
	},
	FORK_TRIDENT_RETURN = {
		category = AudioCategory.EFFECTS
	},
	RADIOACTIVE_PLANT_PLACED = {
		category = AudioCategory.GAMEPLAY
	},
	RADIOACTIVE_PLANT_IRON_INPUT = {
		category = AudioCategory.GAMEPLAY
	},
	RADIOACTIVE_PLANT_DIAMOND_INPUT = {
		category = AudioCategory.GAMEPLAY
	},
	RADIOACTIVE_PLANT_AOE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	RAGEBLADE_KILL_EFFECT = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EMERALD_SHIELD_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	EMERALD_SHIELD_REACTIVE = {
		category = AudioCategory.GAMEPLAY
	},
	WOOD_SHIELD_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	WOOD_SHIELD_REACTIVE = {
		category = AudioCategory.GAMEPLAY
	},
	STONE_SHIELD_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	STONE_SHIELD_REACTIVE = {
		category = AudioCategory.GAMEPLAY
	},
	IRON_SHIELD_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	IRON_SHIELD_REACTIVE = {
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_SHIELD_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_SHIELD_REACTIVE = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_JAB_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_JAB_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_JAB_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_JAB_IMPACT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CROSS_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CROSS_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CROSS_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CROSS_IMPACT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_HOOK_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_HOOK_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_HOOK_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_HOOK_IMPACT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_UPPERCUT_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_UPPERCUT_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_UPPERCUT_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_UPPERCUT_IMPACT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_JAB_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_JAB_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_JAB_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_JAB_SWING_4 = {
		category = AudioCategory.EFFECTS
	},
	GAUNTLETS_CROSS_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CROSS_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CROSS_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CROSS_SWING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_HOOK_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_HOOK_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_HOOK_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_HOOK_SWING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_UPPERCUT_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_UPPERCUT_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_UPPERCUT_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_UPPERCUT_SWING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CHARGE_PUNCH_IMPACT = {
		category = AudioCategory.EFFECTS
	},
	GAUNTLETS_CHARGE_PUNCH_SWING = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_CHARGE_PUNCH_CHARGE = {
		category = AudioCategory.EFFECTS
	},
	GAUNTLETS_CHARGING_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	GAUNTLETS_COMBO_ACTIVATE = {
		category = AudioCategory.GAMEPLAY
	},
	MIMIC_HIDE = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	MIMIC_REVEAL = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	MIMIC_PICKPOCKET_1 = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	MIMIC_PICKPOCKET_2 = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	MIMIC_PICKPOCKET_3 = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	SPIDER_ATTACK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_ATTACK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_HIDER_KILLED_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_HIDER_KILLED_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_HIDER_KILLED_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_HIDER_KILLED_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_HIDER_KILLED_5 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_HIDER_KILLED_6 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_HIDER_KILLED_7 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_ONE_MIN_REMAINING = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_RADAR_FAR = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_RADAR_NEAR = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_DISGUISE = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_HUNT_SEEKERS_RELEASED = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_HIT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_SWING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_DRIP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_DRIP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_DRIP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_DRIP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_DRIP_5 = {
		category = AudioCategory.GAMEPLAY
	},
	BACON_BLADE_DRIP_6 = {
		category = AudioCategory.GAMEPLAY
	},
	WARLOCK_SIPHON_START = {
		category = AudioCategory.EFFECTS
	},
	WARLOCK_SIPHON_LOOP = {
		category = AudioCategory.EFFECTS
	},
	WARLOCK_HEAL_START = {
		category = AudioCategory.EFFECTS
	},
	WARLOCK_HEAL_LOOP = {
		category = AudioCategory.EFFECTS
	},
	DARK_BOLT_SHOOT = {
		category = AudioCategory.GAMEPLAY
	},
	DARK_BOLT_HIT = {
		volume = 3,
		rollOffMaxDistance = 100,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CURSE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CURSE_INFLICT = {
		category = AudioCategory.GAMEPLAY
	},
	CURSE_ACTIVATE = {
		category = AudioCategory.EFFECTS
	},
	CURSE_SUMMON_MOB_PORTAL_LOOP = {
		category = AudioCategory.EFFECTS
	},
	CURSE_SUMMON_MOB_PORTAL_CLOSE = {
		category = AudioCategory.EFFECTS
	},
	CURSE_SUMMON_MOB_PORTAL_SPAWN = {
		category = AudioCategory.EFFECTS
	},
	MAGIC_CIRCLE_SPAWN = {
		category = AudioCategory.EFFECTS
	},
	MAGIC_CIRCLE_FLAME_ERUPT = {
		category = AudioCategory.EFFECTS
	},
	WARLOCK_ALTAR_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	DRAIN_HEALTH_LOOP = {
		category = AudioCategory.EFFECTS
	},
	WEREWOLF_CHARGE = {
		category = AudioCategory.EFFECTS
	},
	WEREWOLF_HOWL = {
		category = AudioCategory.EFFECTS
	},
	WEREWOLF_HEARTBEAT = {
		category = AudioCategory.GAMEPLAY
	},
	CURSED_COFFIN_PLACE = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CURSED_COFFIN_DESTROY = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CURSED_COFFIN_ACTIVATE = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CURSED_COFFIN_DEACTIVATE = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CURSED_COFFIN_HUNGRY = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CURSED_COFFIN_LIFESTEAL_HIT = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CURSED_COFFIN_OPEN_ANIMATION = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GHOST_ORB_ACTIVE_LOOPED = {
		category = AudioCategory.GAMEPLAY
	},
	WITCH_BROOM_CURSED_ITEM_EXPLOSION = {
		category = AudioCategory.EFFECTS
	},
	WITCH_BROOM_DAMAGE_01 = {
		category = AudioCategory.GAMEPLAY
	},
	WITCH_BROOM_DAMAGE_02 = {
		category = AudioCategory.GAMEPLAY
	},
	WITCH_BROOM_DAMAGE_03 = {
		category = AudioCategory.GAMEPLAY
	},
	WITCH_BROOM_DISMOUNT = {
		category = AudioCategory.EFFECTS
	},
	WITCH_BROOM_MOUNT = {
		category = AudioCategory.EFFECTS
	},
	WITCH_BROOM_FLYING_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	WITCH_BROOM_SPAWN = {
		category = AudioCategory.EFFECTS
	},
	WITCH_BROOM_TRAIL_LOOP = {
		category = AudioCategory.EFFECTS
	},
	FRANKEN_LIGHTNING_CHARGE = {
		category = AudioCategory.EFFECTS
	},
	FRANKEN_LIGHTNING_STRIKE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FRANKEN_LIGHTNING_STRIKE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FRANKEN_LIGHTNING_STRIKE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FRANKEN_LIGHTNING_HIT_PLAYER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FRANKEN_LIGHTNING_HIT_PLAYER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FRANKEN_LIGHTNING_HIT_PLAYER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_PLANT = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_GROW_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_GROW_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_GROW_3 = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_BOUNCE = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_LUCKY_BLOCK_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	GRIMOIRE_CASTING = {
		category = AudioCategory.GAMEPLAY
	},
	GRIMOIRE_CAST_COMPLETE = {
		category = AudioCategory.GAMEPLAY
	},
	CATALOG_DISCOVERY = {
		category = AudioCategory.GAMEPLAY
	},
	SKULL_ALTAR = {
		category = AudioCategory.GAMEPLAY
	},
	CAT_SCRATCH_1 = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CAT_SCRATCH_2 = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CAT_SCRATCH_3 = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CAT_POUNCE_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CAT_POUNCE_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CAT_POUNCE_3 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CAT_LAND = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_DIAMOND_GENERATED = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_GOAL_REACHED = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_DECREASE_STAGE_1_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_DECREASE_STAGE_2_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_DECREASE_STAGE_3_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_DECREASE_STAGE_4_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_DECREASE_STAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_DECREASE_STAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_DECREASE_STAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_DECREASE_STAGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_INCREASE_STAGE_1_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_INCREASE_STAGE_2_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_INCREASE_STAGE_3_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_INCREASE_STAGE_4_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_INCREASE_STAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_INCREASE_STAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_INCREASE_STAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CAPTURE_POINT_PROGRESS_INCREASE_STAGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GATHER_BOT_CONSTRUCTION = {
		category = AudioCategory.GAMEPLAY
	},
	GATHER_BOT_DEATH = {
		category = AudioCategory.EFFECTS
	},
	GATHER_BOT_TAKE_DAMAGE = {
		category = AudioCategory.GAMEPLAY
	},
	GATHER_BOT_OVERCLOCK = {
		category = AudioCategory.EFFECTS
	},
	GATHER_BOT_MOVING = {
		category = AudioCategory.GAMEPLAY
	},
	GATHER_BOT_STOP = {
		category = AudioCategory.GAMEPLAY
	},
	STEAM_ENGINEER_OVERCLOCK_ACTIVATE = {
		category = AudioCategory.EFFECTS
	},
	SLIME_RECALL = {
		category = AudioCategory.EFFECTS
	},
	SLIME_DIRECT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_DIRECT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_DIRECT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_DIRECT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_ALERT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_ALERT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_ALERT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_ALERT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_OK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_OK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_OK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_OK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_BOUNCE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_BOUNCE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_BOUNCE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SLIME_BOUNCE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	IRON_AGE_ANNOUNCEMENT = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_AGE_ANNOUNCEMENT = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EMERALD_AGE_ANNOUNCEMENT = {
		volume = 0.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ENLIGHTENED_AGE_ANNOUNCEMENT = {
		category = AudioCategory.GAMEPLAY
	},
	POPCORN_EAT = {
		category = AudioCategory.GAMEPLAY
	},
	POPCORN_GRAB = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	CAMERA_FLASH = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_FLAP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_FLAP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_HONK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_HONK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_HONK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_HONK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_EGG_LAY = {
		category = AudioCategory.GAMEPLAY
	},
	GOLDEN_GOOSE_AMBIENT = {
		category = AudioCategory.AMBIENCE
	},
	BLOCK_KICKER_KIT_STOMP = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCKS_ORBITING = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_KICK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_KICK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_KICK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_KICK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_KICK_5 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_BLOCK_IMPACT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_MITIGATE_DAMAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_MITIGATE_DAMAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_MITIGATE_DAMAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_MITIGATE_DAMAGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BLOCK_KICKER_KIT_MITIGATE_DAMAGE_5 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_HIT_BLOCK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_HIT_BLOCK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_HIT_BLOCK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_HIT_PLAYER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_HIT_PLAYER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_HIT_PLAYER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_RETURN_1 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_RETURN_2 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_RETURN_3 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_THROW_1 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_THROW_2 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_CHAKRAM_THROW_3 = {
		category = AudioCategory.GAMEPLAY
	},
	NINJA_SMOKE_1 = {
		category = AudioCategory.EFFECTS
	},
	NINJA_SMOKE_2 = {
		category = AudioCategory.EFFECTS
	},
	NINJA_SMOKE_3 = {
		category = AudioCategory.EFFECTS
	},
	GRIM_REAPER_VICTORIOUS_GOLD_START = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_GOLD_LOOP = {
		volume = 1.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_PLAT_START = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_PLAT_LOOP = {
		volume = 1.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_DIAMOND_START = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_DIAMOND_LOOP = {
		volume = 1.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_EMERALD_START = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_EMERALD_LOOP = {
		volume = 1.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_NIGHTMARE_START = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRIM_REAPER_VICTORIOUS_NIGHTMARE_LOOP = {
		volume = 1.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CHARGING_GLOOP_LOOP = {
		category = AudioCategory.EFFECTS
	},
	CHARGING_GLOOP_ALERT = {
		category = AudioCategory.EFFECTS
	},
	FLETCHERY_UPGRADE_BOARD_PLACE = {
		category = AudioCategory.GAMEPLAY
	},
	FLETCHERY_CONSTRUCTION_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_ALERT = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_SOLO_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_RANGED_ATTACK_FLY = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_RANGED_ATTACK_LAND = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_SWORD_SPAWN = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_SPIN_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_DAMAGED = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_DESTROYED = {
		category = AudioCategory.EFFECTS
	},
	TARGET_DUMMY_PLACED = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_SPAWN = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_UPGRADE_DIAMOND_TO_EMERALD = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_UPGRADE_EMERALD_TO_ENLIGHTENED = {
		category = AudioCategory.GAMEPLAY
	},
	TARGET_DUMMY_UPGRADE_IRON_TO_DIAMOND = {
		category = AudioCategory.GAMEPLAY
	},
	HOT_CHOCOLATE_SIP_1 = {
		volume = 1.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HOT_CHOCOLATE_SIP_2 = {
		volume = 1.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HOT_CHOCOLATE_SIP_3 = {
		volume = 1.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HOT_CHOCOLATE_SIGH = {
		volume = 1.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_LAUNCHER_SWITCH_MODE = {
		category = AudioCategory.EFFECTS
	},
	SNOWBALL_LAUNCHER_SINGLE_SHOT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_LAUNCHER_SINGLE_SHOT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_LAUNCHER_SINGLE_SHOT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_LAUNCHER_SINGLE_SHOT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_LAUNCHER_POWER_SHOT = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_LAUNCHER_SPREAD_SHOT = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_LAUNCHER_RAPID_SHOT = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBALL_LAUNCHER_CHARGE_UP = {
		category = AudioCategory.GAMEPLAY
	},
	ELDRIC_CHRISTMAS_DRAIN_LOOP = {
		category = AudioCategory.EFFECTS
	},
	ELDRIC_CHRISTMAS_DRAIN_CAST = {
		category = AudioCategory.EFFECTS
	},
	GRINCH_MILO_REVEAL = {
		volume = 2.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	GRINCH_MILO_DISGUISE = {
		volume = 2.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TRAIN_MOVEMENT_LOOP = {
		category = AudioCategory.COSMETICS
	},
	TRAIN_WHISTLE = {
		category = AudioCategory.COSMETICS
	},
	KRAMPUS_EMBER_SWORD_CHARGE = {
		volume = 1.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	KRAMPUS_EMBER_SWORD_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	FROSTQUEEN_LYLA_ANGRYBEES = {
		volume = 1.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	FROSTQUEEN_LYLA_FLOWERPLANT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FROSTQUEEN_LYLA_FLOWERPLANT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FROSTQUEEN_LYLA_FLOWERPLANT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FROSTQUEEN_LYLA_FLOWERBLOOM = {
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_DUEL_WHISTLE = {
		category = AudioCategory.GAMEPLAY
	},
	BRIDGE_DUEL_CHEER = {
		category = AudioCategory.GAMEPLAY
	},
	COMET_VOLLEY_HERO_CONSUME = {
		category = AudioCategory.EFFECTS
	},
	COMET_VOLLEY_VILLAIN_CONSUME = {
		category = AudioCategory.EFFECTS
	},
	COMET_VOLLEY_HERO_ASCEND = {
		category = AudioCategory.GAMEPLAY
	},
	COMET_VOLLEY_VILLAIN_ASCEND = {
		category = AudioCategory.GAMEPLAY
	},
	COMET_VOLLEY_FIRED = {
		category = AudioCategory.EFFECTS
	},
	COMET_VOLLEY_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	COMET_VOLLEY_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	COMET_VOLLEY_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	COMET_VOLLEY_IMPACT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	COMET_VOLLEY_HERO_ORE = {
		category = AudioCategory.EFFECTS
	},
	COMET_VOLLEY_VILLAIN_ORE = {
		category = AudioCategory.EFFECTS
	},
	WIND_TUNNEL_FLYING = {
		category = AudioCategory.COSMETICS
	},
	DRAGON_SWORD_SHOOT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_SHOOT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_SHOOT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_ULT_CAST = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_ULT_FALL = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_ULT_LAND = {
		category = AudioCategory.GAMEPLAY
	},
	FREYA_EXPLOSION = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_BITE_HIT1 = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_BITE_HIT2 = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_BITE_HIT3 = {
		category = AudioCategory.GAMEPLAY
	},
	WAND_CAST_1 = {
		volume = 0.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WAND_CAST_2 = {
		volume = 0.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WAND_CAST_3 = {
		volume = 0.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WAND_HEAL = {
		volume = 0.75,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	WAND_BUBBLE_SPAWN = {
		volume = 0.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WAND_BUBBLE_POP = {
		volume = 0.75,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_SCEPTER_SHOT_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_SCEPTER_SHOT_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_SCEPTER_SHOT_3 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_SCEPTER_SHOT_4 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_SCEPTER_CHARGE = {
		category = AudioCategory.EFFECTS
	},
	LUNAR_VENOM_TICK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	LUNAR_VENOM_TICK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	LUNAR_VENOM_TICK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	LUNAR_VENOM_TICK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	LUNAR_VENOM_INFECTION = {
		category = AudioCategory.EFFECTS
	},
	HERO_SCEPTER_SHOT_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HERO_SCEPTER_SHOT_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HERO_SCEPTER_SHOT_3 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HERO_SCEPTER_SHOT_4 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HERO_SCEPTER_CHARGE = {
		category = AudioCategory.EFFECTS
	},
	SOLAR_FLARE_AFTERSHOCK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SOLAR_FLARE_AFTERSHOCK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SOLAR_FLARE_AFTERSHOCK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SOLAR_FLARE_AFTERSHOCK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SOLAR_FLARE_EXPLOSION = {
		category = AudioCategory.EFFECTS
	},
	RAPIER_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	RAPIER_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	RAPIER_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	RAPIER_HIT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	RAPIER_PROJECTILE_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	HERO_RAPIER_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HERO_RAPIER_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HERO_RAPIER_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	HERO_RAPIER_SWING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	HERO_RAPIER_THRUST_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HERO_RAPIER_THRUST_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_RAPIER_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_RAPIER_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_RAPIER_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_RAPIER_SWING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_RAPIER_THRUST_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VILLAIN_RAPIER_THRUST_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MAGICAL_HERO_LB_SPAWN = {
		category = AudioCategory.EFFECTS
	},
	MAGICAL_VILLAIN_LB_SPAWN = {
		category = AudioCategory.EFFECTS
	},
	MAGICAL_HERO_LB_BREAK = {
		category = AudioCategory.EFFECTS
	},
	MAGICAL_HERO_LB_HIT_1 = {
		category = AudioCategory.EFFECTS
	},
	MAGICAL_HERO_LB_HIT_2 = {
		category = AudioCategory.EFFECTS
	},
	MAGICAL_HERO_LB_HIT_3 = {
		category = AudioCategory.EFFECTS
	},
	SCISSOR_SWORD_CHARGE_UP = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SCISSOR_SWORD_PROJECTILE_INTERCEPT = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SCISSOR_SWORD_SLASH_FAST_HERO = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SCISSOR_SWORD_SLASH_SLOW_HERO = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SCISSOR_SWORD_SLASH_FAST_VILLAIN = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SCISSOR_SWORD_SLASH_SLOW_VILLAIN = {
		volume = 0.25,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TOP_ASSASSIN_EMOTE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	KIT_MASTERY_EMOTE_BRONZE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	KIT_MASTERY_EMOTE_SILVER = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	KIT_MASTERY_EMOTE_GOLD = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	KIT_MASTERY_EMOTE_PLATINUM = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	KIT_MASTERY_EMOTE_DIAMOND = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	KIT_MASTERY_EMOTE_EMERALD = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	KIT_MASTERY_EMOTE_NIGHTMARE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	SPIRIT_ASSASSIN_GHOST_DRAG = {
		category = AudioCategory.COSMETICS
	},
	COIN_FOUNTAIN_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	COIN_FOUNTAIN_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	COIN_FOUNTAIN_3 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	COIN_FOUNTAIN_4 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	COIN_FOUNTAIN_5 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	COIN_FOUNTAIN_LOOP = {
		volume = 0.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PING = {
		category = AudioCategory.GAMEPLAY
	},
	PING_ON_MY_WAY = {
		category = AudioCategory.GAMEPLAY
	},
	PING_HELP = {
		category = AudioCategory.GAMEPLAY
	},
	PING_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	PING_DANGER = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_LONG_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_LONG_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_LONG_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_LONG_4 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_5 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_6 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_7 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_8 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_9 = {
		category = AudioCategory.GAMEPLAY
	},
	FIRECRACKER_BANG_SHORT_10 = {
		category = AudioCategory.GAMEPLAY
	},
	HEALTH_DROP_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	TROPHY_SPARKLES = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_SMELTING_TIER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_SMELTING_TIER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_SMELTING_TIER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_SMELTING_TIER_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_SMELTING_TIER_5 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_ITEM_REVEAL_TIER_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_ITEM_REVEAL_TIER_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_ITEM_REVEAL_TIER_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_ITEM_REVEAL_TIER_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_ITEM_REVEAL_TIER_5 = {
		category = AudioCategory.GAMEPLAY
	},
	SMELTER_MOVE_ITEM = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_5 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_6 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_7 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_8 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_9 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURING_10 = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURED_BY_ENEMY = {
		category = AudioCategory.GAMEPLAY
	},
	DOMINATION_CAPTURED_BY_TEAM = {
		category = AudioCategory.GAMEPLAY
	},
	NYOKA_MENDING_STAFF_CHARGING = {
		category = AudioCategory.EFFECTS
	},
	NYOKA_MENDING_RADIUS_LOOP = {
		category = AudioCategory.EFFECTS
	},
	NYOKA_HEAL_APPLIED_0 = {
		category = AudioCategory.EFFECTS
	},
	NYOKA_HEAL_APPLIED_1 = {
		category = AudioCategory.EFFECTS
	},
	NYOKA_HEAL_APPLIED_2 = {
		category = AudioCategory.EFFECTS
	},
	NYOKA_HEAL_APPLIED_3 = {
		category = AudioCategory.EFFECTS
	},
	NYOKA_MENDING_STAFF_GLIDE_AVAILABLE = {
		category = AudioCategory.EFFECTS
	},
	NYOKA_MENDING_STAFF_OVERCHARGE = {
		category = AudioCategory.EFFECTS
	},
	TEAM_UPGRADE_PURCHASE = {
		category = AudioCategory.COSMETICS
	},
	ROULETTE_TICK = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.UI
	},
	PREGAME_VOTE_WINNER_CHOSEN = {
		category = AudioCategory.UI
	},
	PREGAME_VOTE_CAST = {
		category = AudioCategory.GAMEPLAY
	},
	PUZZLE_SOLVED = {
		category = AudioCategory.GAMEPLAY
	},
	PUZZLE_CHALLENGE_SOLVED = {
		category = AudioCategory.GAMEPLAY
	},
	EGG_HUNT_EGG_COLLECT = {
		category = AudioCategory.GAMEPLAY
	},
	EGG_HUNT_EGG_DEPOSIT = {
		category = AudioCategory.COSMETICS
	},
	SPEED_BOOST = {
		category = AudioCategory.GAMEPLAY
	},
	DOOR_OPEN = {
		category = AudioCategory.GAMEPLAY
	},
	PYRO_CLUSTER_SPAWN_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PYRO_CLUSTER_SPAWN_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PYRO_CLUSTER_SPAWN_3 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PYRO_CLUSTER_EXPLODE_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PYRO_CLUSTER_EXPLODE_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PYRO_CLUSTER_EXPLODE_3 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	PYRO_ROCKET = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HEAVEN_ASCEND = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TERRA_VOID_BLOCK_KICK = {
		category = AudioCategory.GAMEPLAY
	},
	TERRA_VOID_BLOCK_KICK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	TERRA_VOID_BLOCK_KICK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	TERRA_VOID_BLOCK_KICK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	TERRA_VOID_STOMP = {
		category = AudioCategory.EFFECTS
	},
	BLASTING_OFF_SPARKLE = {
		category = AudioCategory.COSMETICS
	},
	BLASTING_OFF_YELL = {
		category = AudioCategory.COSMETICS
	},
	BLASTING_OFF_JINGLE = {
		preload = false,
		volume = 0.35,
		category = AudioCategory.COSMETICS
	},
	FALCON_SCREECH = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_SCREECH_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_SCREECH_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_WING_FLAP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_WING_FLAP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_WING_FLAP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_CHIRP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_CHIRP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_CHIRP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_CRY = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_CRY_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_CRY_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCON_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	FALCON_DESUMMON = {
		category = AudioCategory.EFFECTS
	},
	FALCONER_SEND_FALCON = {
		category = AudioCategory.GAMEPLAY
	},
	FALCONER_RECALL_FALCON = {
		category = AudioCategory.GAMEPLAY
	},
	SEAGULL_CHIRP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SEAGULL_CHIRP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SEAGULL_CHIRP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SEAGULL_CRY_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SEAGULL_CRY_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SEAGULL_SCREECH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SEAGULL_SCREECH_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FALCONER_RECALL_SEAGULL = {
		category = AudioCategory.GAMEPLAY
	},
	FALCONER_SEND_SEAGULL = {
		category = AudioCategory.GAMEPLAY
	},
	SEAGULL_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	SEAGULL_DESUMMON = {
		category = AudioCategory.EFFECTS
	},
	TOILET_FLUSH = {
		category = AudioCategory.COSMETICS
	},
	SQUAD_LAUNCH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SQUAD_LAUNCH_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SQUAD_LAUNCH_3 = {
		category = AudioCategory.GAMEPLAY
	},
	CONGA_LINE = {
		volume = 1.3,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TINKER_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	TINKER_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	TINKER_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	TINKER_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	TINKER_HEAVY_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	TINKER_EXIT = {
		category = AudioCategory.GAMEPLAY
	},
	TINKER_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	TINKER_MACHINE_DEPLOY = {
		category = AudioCategory.GAMEPLAY
	},
	SILLY_LEGS_DANCE = {
		volume = 1.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EPIC_SHINE = {
		category = AudioCategory.GAMEPLAY
	},
	RARE_FIND = {
		volume = 1.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SUMMONER_SUMMON_CHANNEL_LOOP = {
		category = AudioCategory.EFFECTS
	},
	SUMMONER_SUMMON_FINISH = {
		category = AudioCategory.EFFECTS
	},
	SUMMONER_CLAW_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	SUMMONER_CLAW_ATTACK_2 = {
		category = AudioCategory.EFFECTS
	},
	SUMMONER_CLAW_ATTACK_3 = {
		category = AudioCategory.EFFECTS
	},
	SUMMONER_CLAW_ATTACK_4 = {
		category = AudioCategory.EFFECTS
	},
	SNOWANGEL_SUMMONER_SUMMON_CHANNEL_LOOP = {
		category = AudioCategory.EFFECTS
	},
	SNOWANGEL_SUMMONER_SUMMON_FINISH = {
		category = AudioCategory.EFFECTS
	},
	SNOWANGEL_SUMMONER_CLAW_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	SNOWANGEL_SUMMONER_CLAW_ATTACK_2 = {
		category = AudioCategory.EFFECTS
	},
	SNOWANGEL_SUMMONER_CLAW_ATTACK_3 = {
		category = AudioCategory.EFFECTS
	},
	SNOWANGEL_SUMMONER_CLAW_ATTACK_4 = {
		category = AudioCategory.EFFECTS
	},
	VICTORIOUS_LYLA_GOLD_FLOWERBLOOM = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_GOLD_FLOWERPLANT = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_GOLD_ANGRYBEES = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_PLATINUM_FLOWERBLOOM = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_PLATINUM_FLOWERPLANT = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_PLATINUM_ANGRYBEES = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_EMERALD_FLOWERBLOOM = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_EMERALD_FLOWERPLANT = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_EMERALD_ANGRYBEES = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_DIAMOND_FLOWERBLOOM = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_DIAMOND_FLOWERPLANT = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_DIAMOND_ANGRYBEES = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_NIGHTMARE_FLOWERBLOOM = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_NIGHTMARE_FLOWERPLANT = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_LYLA_NIGHTMARE_ANGRYBEES = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_PORTAL_ENTER = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_PORTAL_EXIT = {
		category = AudioCategory.EFFECTS
	},
	LIGHTNING_STRIKE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHTNING_STRIKE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHTNING_STATIC_1 = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHTNING_STATIC_2 = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHTNING_STATIC_3 = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHTNING_STATIC_4 = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHTNING_STATIC_5 = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHTNING_STATIC_6 = {
		category = AudioCategory.GAMEPLAY
	},
	LIGHTNING_THUNDER_STORM_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_ASCEND = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_CONSUME = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_1 = {
		category = AudioCategory.EFFECTS
	},
	VOID_KNIGHT_LEVEL_UP_2 = {
		category = AudioCategory.EFFECTS
	},
	VOID_KNIGHT_LEVEL_UP_3 = {
		category = AudioCategory.EFFECTS
	},
	VOID_KNIGHT_LEVEL_UP_4 = {
		category = AudioCategory.EFFECTS
	},
	VOID_KNIGHT_SHIELD_DAMAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_ASCEND_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_CONSUME_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_1_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_2_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_3_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_4_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_1_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_2_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_3_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_4_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_BREAK_ICE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_ASCEND_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_CONSUME_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_1_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_2_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_3_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_LEVEL_UP_4_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_1_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_2_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_3_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_DAMAGE_4_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_SHIELD_BREAK_PUMPKIN = {
		category = AudioCategory.GAMEPLAY
	},
	SORCERER_SPELL_CHARGING_LOOP = {
		category = AudioCategory.EFFECTS
	},
	SORCERER_SPELL_UPGRADES = {
		category = AudioCategory.EFFECTS
	},
	SORCERER_PROJECTILE_SHOOT = {
		category = AudioCategory.GAMEPLAY
	},
	SORCERER_PROJECTILE_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	DIALOGUE = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TASK_COMPLETE = {
		volume = 1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	TASK_START = {
		category = AudioCategory.GAMEPLAY
	},
	TASK_STAGE = {
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_SWORD_LUNGE = {
		volume = 0.025,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_SWORD_SLASH = {
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_BLOXY_COLA_DRINK = {
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_BLOXY_COLA_OPEN = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_CHEEZBURGER = {
		volume = 0.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_MMM_CHEEZBURGER = {
		volume = 0.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_ROBLOX_BOMB_EXPLOSION = {
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_ROBLOX_RUBBER_SLING = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CLASSIC_ROBLOX_VICTORY_SOUND = {
		volume = 0.4,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	QUEST_COMPLETE = {
		volume = 1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_DRILL_LOOP = {
		category = AudioCategory.EFFECTS
	},
	MULTI_BREAK_TOOL_DRILL_STOP = {
		category = AudioCategory.EFFECTS
	},
	MULTI_BREAK_TOOL_WOOL_BREAK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_WOOL_BREAK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_WOOL_BREAK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_WOOL_BREAK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_WOOD_BREAK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_WOOD_BREAK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_WOOD_BREAK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_WOOD_BREAK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_STONE_BREAK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_STONE_BREAK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_STONE_BREAK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	MULTI_BREAK_TOOL_STONE_BREAK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	EVIL_LAUGH = {
		category = AudioCategory.COSMETICS
	},
	HARPOON_HIT_PART = {
		category = AudioCategory.GAMEPLAY
	},
	HARPOON_HIT_ENEMY = {
		category = AudioCategory.GAMEPLAY
	},
	HARPOON_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	HARPOON_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_DEPLOY_1 = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_DEPLOY_2 = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_DEPLOY_3 = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_ZAP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_ZAP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_PULSE_1 = {
		category = AudioCategory.EFFECTS
	},
	JELLYFISH_PULSE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_PULSE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_PULSE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	JELLYFISH_PULSE_5 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_DEPLOY_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_DEPLOY_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_DEPLOY_3 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_ZAP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_ZAP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_PULSE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_PULSE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_PULSE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_PULSE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	HOLIDAY_JELLYFISH_PULSE_5 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_DEPLOY_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_DEPLOY_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_DEPLOY_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_ZAP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_ZAP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_PULSE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_PULSE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_PULSE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_PULSE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	DESSERT_JELLYFISH_PULSE_5 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLISTA_FIRE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLISTA_FIRE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLISTA_FIRE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLISTA_FIRE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLISTA_RELOAD = {
		category = AudioCategory.GAMEPLAY
	},
	INFERNAL_SURFER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	INFERNAL_SURFER_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	INFERNAL_SURFER_LAND = {
		category = AudioCategory.GAMEPLAY
	},
	AQUATIC_MILO_REVEAL = {
		category = AudioCategory.GAMEPLAY
	},
	AQUATIC_MILO_DISGUISE = {
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_SHIELD = {
		category = AudioCategory.EFFECTS
	},
	DEEPSEA_CANNON_LAUNCH = {
		category = AudioCategory.GAMEPLAY
	},
	ICY_DELIGHT_LICK = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CRAB_DANCE_EMOTE = {
		volume = 0.8,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BED_SHIELD_ACTIVATE = {
		category = AudioCategory.GAMEPLAY
	},
	BED_SHIELD_IMPACT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BED_SHIELD_IMPACT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BED_SHIELD_IMPACT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BED_SHIELD_IMPACT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BED_SHIELD_DEACTIVATE = {
		category = AudioCategory.GAMEPLAY
	},
	BED_ALARM_ACTIVATE = {
		category = AudioCategory.GAMEPLAY
	},
	BED_ALARM_TRIGGERED = {
		category = AudioCategory.GAMEPLAY
	},
	BED_ALARM_TRIGGERED_FAR = {
		category = AudioCategory.GAMEPLAY
	},
	BED_PLATING_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BED_PLATING_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BED_PLATING_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BED_PLATING_BREAK_PLAYER = {
		category = AudioCategory.GAMEPLAY
	},
	BED_PLATING_BREAK_NATURAL = {
		category = AudioCategory.GAMEPLAY
	},
	KILL_EFFECT_SLASH = {
		category = AudioCategory.COSMETICS
	},
	PVP_ARENA_INTERMISSION_TRACK = {
		volume = 0.3,
		preload = true,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	PVP_ARENA_ROUND_END = {
		category = AudioCategory.GAMEPLAY
	},
	PVP_ARENA_ROUND_WIN_CHEER = {
		category = AudioCategory.GAMEPLAY
	},
	PVP_ARENA_COUNTDOWN = {
		category = AudioCategory.GAMEPLAY
	},
	CRYSTALLIZE_BED = {
		category = AudioCategory.COSMETICS
	},
	CRYSTALLIZE_BED_BREAK = {
		category = AudioCategory.COSMETICS
	},
	SORCERER_ICE_CHARGE_UPGRADE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SORCERER_ICE_CHARGE_UPGRADE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SORCERER_ICE_CHARGE_UPGRADE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SORCERER_ICE_CHARGE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SORCERER_ICE_PROJECTILE_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	SORCERER_ICE_PROJECTILE_SHOT = {
		category = AudioCategory.GAMEPLAY
	},
	BANANARANG_THROW = {
		category = AudioCategory.EFFECTS
	},
	BANANARANG_FLYING_LOOP = {
		category = AudioCategory.EFFECTS
	},
	BANANARANG_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BANANARANG_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BANANARANG_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_CONTACT_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_WOOD_BREAK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_WOOD_BREAK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_WOOD_BREAK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_WOOD_BREAK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_STONE_BREAK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_STONE_BREAK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_STONE_BREAK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_STONE_BREAK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_WOOL_BREAK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_WOOL_BREAK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_WOOL_BREAK_3 = {
		category = AudioCategory.GAMEPLAY
	},
	LASER_PICKAXE_WOOL_BREAK_4 = {
		category = AudioCategory.GAMEPLAY
	},
	CRYSTAL_BED_IMPALE = {
		category = AudioCategory.COSMETICS
	},
	REBELLION_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	REBELLION_HEAL = {
		category = AudioCategory.EFFECTS
	},
	REBELLION_SHIELD = {
		category = AudioCategory.GAMEPLAY
	},
	REBELLION_GAIN_STACK = {
		category = AudioCategory.GAMEPLAY
	},
	WOLF_REBELLION_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	WOLF_REBELLION_HEAL = {
		category = AudioCategory.EFFECTS
	},
	WOLF_REBELLION_SHIELD = {
		category = AudioCategory.GAMEPLAY
	},
	WOLF_REBELLION_GAIN_STACK = {
		category = AudioCategory.GAMEPLAY
	},
	GRIDDY_EMOTE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	WREN_PANFLUTE_SUMMON = {
		volume = 0.4,
		preload = true,
		playbackSpeed = NumberRange.new(1.3, 1.5),
		category = AudioCategory.EFFECTS
	},
	WREN_PANFLUTE_UNSUMMON = {
		volume = 0.4,
		preload = true,
		playbackSpeed = NumberRange.new(1.3, 1.5),
		category = AudioCategory.EFFECTS
	},
	FUNKY_DANCE_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	GOODNIGHT_DANCE_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	TRIUMPH_WIN_EFFECT_LIGHT = {
		category = AudioCategory.COSMETICS
	},
	TRIUMPH_WIN_EFFECT_STATUE = {
		category = AudioCategory.COSMETICS
	},
	TRIUMPH_WIN_EFFECT_PURIFY = {
		category = AudioCategory.COSMETICS
	},
	CONSUME_ACTIVATE = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EMPOWER_ENABLE = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EMPOWER_DISABLE = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EMPOWER_HIT_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	EMPOWER_HIT_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	LIFE_ARROW_HIT_1 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	LIFE_ARROW_HIT_2 = {
		volume = 0.1,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	LIFE_BOW_SHOT = {
		volume = 0.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	LIFE_HEADHUNTER_SHOT = {
		volume = 0.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_CONSUME_ACTIVATE = {
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_EMPOWER_ENABLE = {
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_EMPOWER_DISABLE = {
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_EMPOWER_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_EMPOWER_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_LIFE_ARROW_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_LIFE_ARROW_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_LIFE_BOW_SHOT = {
		category = AudioCategory.GAMEPLAY
	},
	MUMMY_LIFE_HEADHUNTER_SHOT = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_EXIT = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_SPAWN = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_SPIN = {
		category = AudioCategory.GAMEPLAY
	},
	FISH_TANK_TINKER_ATTACK = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_WIZARD_CAST = {
		category = AudioCategory.GAMEPLAY
	},
	GOLD_VICTORIOUS_WIZARD_SHOCKWAVE = {
		category = AudioCategory.GAMEPLAY
	},
	PLATINUM_VICTORIOUS_WIZARD_SHOCKWAVE = {
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_VICTORIOUS_WIZARD_SHOCKWAVE = {
		category = AudioCategory.GAMEPLAY
	},
	EMERALD_VICTORIOUS_WIZARD_SHOCKWAVE = {
		category = AudioCategory.GAMEPLAY
	},
	NIGHTMARE_VICTORIOUS_WIZARD_SHOCKWAVE = {
		category = AudioCategory.GAMEPLAY
	},
	GOLD_VICTORIOUS_WIZARD_LIGHTNING_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	PLATINUM_VICTORIOUS_WIZARD_LIGHTNING_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_VICTORIOUS_WIZARD_LIGHTNING_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	EMERALD_VICTORIOUS_WIZARD_LIGHTNING_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	NIGHTMARE_VICTORIOUS_WIZARD_LIGHTNING_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	PLATINUM_VICTORIOUS_WIZARD_STATIC_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	DIAMOND_VICTORIOUS_WIZARD_STATIC_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	EMERALD_VICTORIOUS_WIZARD_STATIC_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	NIGHTMARE_VICTORIOUS_WIZARD_STATIC_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	SWORD_TWIRL = {
		category = AudioCategory.GAMEPLAY
	},
	LAUNCH_PAD_ACTIVATE = {
		category = AudioCategory.GAMEPLAY
	},
	INVISIBLE_CLOAK = {
		category = AudioCategory.EFFECTS
	},
	SPEAR_CHARGE = {
		category = AudioCategory.EFFECTS
	},
	SPEAR_STAB_1 = {
		category = AudioCategory.EFFECTS
	},
	SPEAR_STAB_2 = {
		category = AudioCategory.EFFECTS
	},
	SPEAR_STAB_3 = {
		category = AudioCategory.EFFECTS
	},
	SPRING_PUNCH_SHOT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SPRING_PUNCH_SHOT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SPRING_PUNCH_SHOT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SPRING_PUNCH_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SPRING_PUNCH_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SPRING_PUNCH_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SPRING_PUNCH_RETRACT = {
		category = AudioCategory.GAMEPLAY
	},
	PIT_PLACE = {
		category = AudioCategory.EFFECTS
	},
	PIT_OPEN = {
		category = AudioCategory.EFFECTS
	},
	POGO_BOUNCE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	POGO_STOMP = {
		category = AudioCategory.GAMEPLAY
	},
	TOURNAMENT_WINNER_EMOTE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	LAVA_AMBIENT = {
		category = AudioCategory.AMBIENCE
	},
	GUARDIAN_OF_DREAM_PERISH = {
		category = AudioCategory.GAMEPLAY
	},
	GUARDIAN_OF_DREAM_ATTACK_1 = {
		category = AudioCategory.GAMEPLAY
	},
	GUARDIAN_OF_DREAM_ATTACK_2 = {
		category = AudioCategory.GAMEPLAY
	},
	STORM_EDGE = {
		category = AudioCategory.GAMEPLAY
	},
	STORM_INSIDE = {
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB_BLOCK_CREATED = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB_BLOCK_BROKEN = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIKE_ERUPT = {
		category = AudioCategory.GAMEPLAY
	},
	FALLING_ROCKS = {
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB_BRIDGE_FIRE = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB_BRIDGE_IMPACT = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB_BLOCK_SPAWN_1 = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB_BLOCK_SPAWN_2 = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB_BLOCK_SPAWN_3 = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_WEB_BLOCK_SPAWN_4 = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_QUEEN_SPIDERLING_SUMMON_1 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_SPIDERLING_SUMMON_2 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_SPIDERLING_SUMMON_3 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_SPIDERLING_SUMMON_4 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_SPIDERLING_ATTACK_1 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_SPIDERLING_ATTACK_2 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_SPIDERLING_ATTACK_3 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_SPIDERLING_ATTACK_4 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_SPIDERLING_RUN_LOOP = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SILAS_HALLOWEEN_HEX = {
		category = AudioCategory.EFFECTS
	},
	SILAS_HALLOWEEN_BUFF = {
		category = AudioCategory.EFFECTS
	},
	SPIDER_QUEEN_BOSS_SHRIEK = {
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_QUEEN_BOSS_DEATH = {
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_QUEEN_BOSS_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	HALLOWEEN_LOBBY_MUSIC_S11 = {
		volume = 1.25,
		preload = true,
		bus = BedWarsAudioBuses.LOBBY_MUSIC
	},
	SPITTER_SPIDER_SHOOT = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPITTER_SPIDER_WEB_IMPACT = {
		volume = 1.15,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIDER_GUARD_DEATH = {
		category = AudioCategory.GAMEPLAY
	},
	HALLOWEEN_BLACK_MARKET_SHOP_SUMMON = {
		category = AudioCategory.UI
	},
	HALLOWEEN_BLACK_MARKET_SHOP_UPGRADE = {
		category = AudioCategory.UI
	},
	HOLIDAY_BLACK_MARKET_SHOP_SUMMON = {
		category = AudioCategory.UI
	},
	HOLIDAY_BLACK_MARKET_SHOP_UPGRADE = {
		category = AudioCategory.UI
	},
	KNIGHT_SHIELD_DAMAGED_1 = {
		category = AudioCategory.GAMEPLAY
	},
	KNIGHT_SHIELD_DAMAGED_2 = {
		category = AudioCategory.GAMEPLAY
	},
	KNIGHT_SHIELD_BROKEN = {
		category = AudioCategory.EFFECTS
	},
	WITHERED_ELDERTREE_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	INFECTED_HALLOWEEN_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	ELDERREEF_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	ELDERREEF_AMBIENT = {
		category = AudioCategory.AMBIENCE
	},
	TREE_ORB_AMBIENT = {
		category = AudioCategory.AMBIENCE
	},
	SPIRIT_GARDENER_CHANNELING_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_GARDENER_SPIRIT_ORB_COLLECTED = {
		category = AudioCategory.EFFECTS
	},
	SPIRIT_GARDENER_SPIRIT_ORB_START_COLLECT = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_GARDENER_BUFF_APPLIED = {
		category = AudioCategory.EFFECTS
	},
	MAGIC_GLASS_PLACE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MAGIC_GLASS_PLACE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MAGIC_GLASS_PLACE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	MAGIC_GLASS_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	MAGIC_GLASS_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	MAGIC_GLASS_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	MAGIC_GLASS_HIT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	MAGIC_GLASS_BREAK = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	FIRE_START = {
		category = AudioCategory.COSMETICS
	},
	PARACHUTE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SKYDIVING_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	JINGLE_BELLS = {
		category = AudioCategory.EFFECTS
	},
	COOKIE_BITE_01 = {
		category = AudioCategory.GAMEPLAY
	},
	COOKIE_BITE_02 = {
		category = AudioCategory.GAMEPLAY
	},
	COOKIE_BITE_03 = {
		category = AudioCategory.GAMEPLAY
	},
	FESTIVE_LUMEN_SWORD_ATTACK = {
		category = AudioCategory.GAMEPLAY
	},
	FESTIVE_LUMEN_SWORD_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	WRANGLER_REINDEER_LASSO_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	WRANGLER_REINDEER_LASSO_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	WRANGLER_REINDEER_LASSO_HIT = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_SUMMONING = {
		category = AudioCategory.EFFECTS
	},
	ATTACK_SPIRIT_THROW = {
		volume = 0.9,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	HEAL_SPIRIT_THROW = {
		volume = 0.9,
		preload = true,
		category = AudioCategory.EFFECTS
	},
	ATTACK_SPIRIT_APPEAR = {
		category = AudioCategory.GAMEPLAY
	},
	HEAL_SPIRIT_APPEAR = {
		category = AudioCategory.EFFECTS
	},
	SPIRIT_DISPEL = {
		category = AudioCategory.EFFECTS
	},
	SPIRIT_SUMMONER_CHANGE_AFFINITY = {
		category = AudioCategory.EFFECTS
	},
	HEAL_SPIRIT_EASTER_APPEAR = {
		category = AudioCategory.EFFECTS
	},
	ATTACK_SPIRIT_EASTER_APPEAR = {
		category = AudioCategory.GAMEPLAY
	},
	HEAL_SPIRIT_EASTER_THROW = {
		category = AudioCategory.EFFECTS
	},
	ATTACK_SPIRIT_EASTER_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_EASTER_SUMMON = {
		category = AudioCategory.EFFECTS
	},
	RABBIT_HAT_EMOTE_DRUMROLL = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	RABBIT_HAT_EMOTE_TADA = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	DUCK_WALK_EMOTE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	SPLIT_BED_BREAK_FALL_APART = {
		category = AudioCategory.COSMETICS
	},
	BUTTERFLY_SWARM_BED_BREAK_FLUTTER = {
		category = AudioCategory.COSMETICS
	},
	TUCK_IN_KILL_EFFECT_MUSIC = {
		category = AudioCategory.COSMETICS
	},
	SPIRIT_ISLAND = {
		volume = 0.65,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VOID_INVASION_FORCAST = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_INVASION_START = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_PORTAL_SPAWN = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HOUND_ATTACK_1 = {
		category = AudioCategory.EFFECTS
	},
	VOID_HOUND_ATTACK_2 = {
		category = AudioCategory.EFFECTS
	},
	VOID_HOUND_SLAM = {
		category = AudioCategory.EFFECTS
	},
	VOID_HOUND_TAIL_ATTACK = {
		category = AudioCategory.EFFECTS
	},
	VOID_HOUND_WALKING_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_ISLAND_WINTER = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_SKATING_FOOTSTEP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_SKATING_FOOTSTEP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_SKATING_FOOTSTEP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_SKATING_FOOTSTEP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_SKATING_FOOTSTEP_5 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_SKATING_FOOTSTEP_6 = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_SKATING_DODGE = {
		category = AudioCategory.GAMEPLAY
	},
	ICE_SKATING_FOOTSTEP_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_GOLD_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_PLATINUM_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_DIAMOND_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_EMERALD_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_NIGHTMARE_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_GOLD_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_PLATINUM_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_DIAMOND_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_EMERALD_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_TRITON_NIGHTMARE_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	DEMON_TRITON_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	DEMON_TRITON_LEAP = {
		category = AudioCategory.GAMEPLAY
	},
	DEMON_TRITON_HIT_PART = {
		category = AudioCategory.GAMEPLAY
	},
	DEMON_TRITON_HIT_ENEMY = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_PROJECTILE_FIRE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_PROJECTILE_FIRE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_PROJECTILE_FIRE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_PROJECTILE_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_PROJECTILE_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_PROJECTILE_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_CHASING_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_DETONATE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_DETONATE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	LANTERN_RELEASE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	SNAKE_SHRINE_TRIBUTE = {
		category = AudioCategory.GAMEPLAY
	},
	SNAKE_BUFF = {
		category = AudioCategory.EFFECTS
	},
	SNAKE_BED_BREAK = {
		category = AudioCategory.COSMETICS
	},
	VOID_WALKER_PORTAL_OPEN_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_PORTAL_OPEN_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_PORTAL_OPEN_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_PORTAL_CLOSE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_PORTAL_CLOSE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_PORTAL_CLOSE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VALENTINE_CROP_HARVEST = {
		category = AudioCategory.GAMEPLAY
	},
	VALENTINE_CROP_PLANT = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_WEE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_HEHE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_LAUGH = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_WOOHOO = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_GIGGLE = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_WEE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_UHH = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_SASSY_LAUGH = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_WALKER_WOOP = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_DETONATE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_DETONATE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_PROJECTILE_FIRE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_PROJECTILE_FIRE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_PROJECTILE_FIRE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_PROJECTILE_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_PROJECTILE_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_PROJECTILE_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_HUNTER_BONE_CHASING_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	DUST_DEVIL_BLOCK_DISLODGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DUST_DEVIL_BLOCK_DISLODGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DUST_DEVIL_BLOCK_DISLODGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DUST_DEVIL_BLOCK_DISLODGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	RADIO_EGG = {
		category = AudioCategory.GAMEPLAY
	},
	GROVE_EASTER_BUFF = {
		category = AudioCategory.EFFECTS
	},
	GROVE_EASTER_COLLECTED = {
		category = AudioCategory.GAMEPLAY
	},
	GROVE_EASTER_CHANNEL_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	GROVE_EASTER_COLLECT_START = {
		category = AudioCategory.GAMEPLAY
	},
	GROVE_ELYSIUM_BUFF = {
		category = AudioCategory.EFFECTS
	},
	GROVE_ELYSIUM_COLLECTED = {
		category = AudioCategory.GAMEPLAY
	},
	GROVE_ELYSIUM_CHANNEL_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	GROVE_ELYSIUM_COLLECT_START = {
		category = AudioCategory.GAMEPLAY
	},
	CACTUS_ABSORB_1 = {
		volume = 0.7,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CACTUS_ABSORB_2 = {
		volume = 0.7,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CACTUS_ABSORB_3 = {
		volume = 0.7,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CACTUS_ABSORB_4 = {
		volume = 0.7,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	CACTUS_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	CACTUS_THROW = {
		category = AudioCategory.GAMEPLAY
	},
	CACTUS_ATTACH = {
		category = AudioCategory.GAMEPLAY
	},
	DAY_OF_THE_DEAD_CACTUS_ATTACH = {
		category = AudioCategory.GAMEPLAY
	},
	DAY_OF_THE_DEAD_CACTUS_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	DAY_OF_THE_DEAD_CACTUS_ABSORB_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DAY_OF_THE_DEAD_CACTUS_ABSORB_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DAY_OF_THE_DEAD_CACTUS_ABSORB_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DAY_OF_THE_DEAD_CACTUS_ABSORB_4 = {
		category = AudioCategory.GAMEPLAY
	},
	AIRBENDER_SANDSTORM_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SHARK_RAMIL_TORNADO_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	FLASK_UNSCREW = {
		category = AudioCategory.GAMEPLAY
	},
	FLYING_CARPET_DEPLOY = {
		category = AudioCategory.GAMEPLAY
	},
	FLYING_CARPET_IDLE = {
		category = AudioCategory.COSMETICS
	},
	DUST_DEVIL_LOOP = {
		category = AudioCategory.COSMETICS
	},
	DUST_DEVIL_PICKUP_LOOP = {
		category = AudioCategory.COSMETICS
	},
	SARCOPHAGUS_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	GENIE_LAMP_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	WALK_LIKE_EGYPTIAN = {
		category = AudioCategory.GAMEPLAY
	},
	RAIN_DANCE = {
		category = AudioCategory.AMBIENCE
	},
	AMY_VICTORIOUS_BUFF_GOLD = {
		category = AudioCategory.EFFECTS
	},
	AMY_VICTORIOUS_BUFF_PLATINUM = {
		category = AudioCategory.EFFECTS
	},
	AMY_VICTORIOUS_BUFF_DIAMOND = {
		category = AudioCategory.EFFECTS
	},
	AMY_VICTORIOUS_BUFF_EMERALD = {
		category = AudioCategory.EFFECTS
	},
	AMY_VICTORIOUS_BUFF_NIGHTMARE = {
		category = AudioCategory.EFFECTS
	},
	SPIRIT_AGNI_SATCHEL = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_AGNI_CLUSTER_EXPLOSION_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_AGNI_CLUSTER_EXPLOSION_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_AGNI_CLUSTER_EXPLOSION_3 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_AGNI_CLUSTER_SPAWN_1 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_AGNI_CLUSTER_SPAWN_2 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_AGNI_CLUSTER_SPAWN_3 = {
		volume = 0.5,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	BHAA_GRUNT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BHAA_GRUNT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BHAA_SPIKE_WARMUP = {
		category = AudioCategory.GAMEPLAY
	},
	BHAA_SPIKE = {
		category = AudioCategory.GAMEPLAY
	},
	BHAA_SPAWN = {
		category = AudioCategory.GAMEPLAY
	},
	SACROPHAGUS_REVIVE = {
		category = AudioCategory.GAMEPLAY
	},
	DODO_OWL_FLAPPING_LOOP = {
		category = AudioCategory.EFFECTS
	},
	DODO_OWL_HOOT_1 = {
		category = AudioCategory.EFFECTS
	},
	DODO_OWL_HOOT_2 = {
		category = AudioCategory.EFFECTS
	},
	DODO_OWL_HOOT_3 = {
		category = AudioCategory.EFFECTS
	},
	DODO_OWL_CUTE_HOOT_1 = {
		category = AudioCategory.EFFECTS
	},
	DODO_OWL_CUTE_HOOT_2 = {
		category = AudioCategory.EFFECTS
	},
	DODO_OWL_PROJECTILE_SHOT_1 = {
		category = AudioCategory.EFFECTS
	},
	DODO_OWL_PROJECTILE_SHOT_2 = {
		category = AudioCategory.EFFECTS
	},
	DODO_OWL_PROJECTILE_SHOT_3 = {
		category = AudioCategory.EFFECTS
	},
	DODO_SPIRIT_ASSASSIN_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	DODO_SPIRIT_ASSASSIN_SLASH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DODO_SPIRIT_ASSASSIN_SLASH_2 = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_FALLEN_SKIN_LIGHT_TRANSFORM = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_FALLEN_SKIN_DARK_TRANSFORM = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_FALLEN_SKIN_LIGHT_ORB_CREATE = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_FALLEN_SKIN_DARK_ORB_CREATE = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_FALLEN_SKIN_LIGHT_ORB_HEAL = {
		category = AudioCategory.EFFECTS
	},
	TRINITY_FALLEN_SKIN_DARK_ORB_HEAL = {
		category = AudioCategory.EFFECTS
	},
	TRINITY_ICECREAM_SKIN_LIGHT_TRANSFORM = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_ICECREAM_SKIN_DARK_TRANSFORM = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_ICECREAM_SKIN_LIGHT_ORB_CREATE = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_ICECREAM_SKIN_DARK_ORB_CREATE = {
		category = AudioCategory.GAMEPLAY
	},
	TRINITY_ICECREAM_SKIN_LIGHT_ORB_HEAL = {
		category = AudioCategory.EFFECTS
	},
	TRINITY_ICECREAM_SKIN_DARK_ORB_HEAL = {
		category = AudioCategory.EFFECTS
	},
	WATER_SHOT_1 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WATER_SHOT_2 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WATER_SHOT_3 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WATER_SHOT_4 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WATER_HIT_1 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WATER_HIT_2 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WATER_HIT_3 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	WATER_HIT_4 = {
		volume = 1.2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	SCARAB_ATTACK = {
		category = AudioCategory.EFFECTS
	},
	SCARAB_SPAWN = {
		category = AudioCategory.EFFECTS
	},
	SCARAB_DEATH_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SCARAB_DEATH_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SCARAB_DEATH_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SCARAB_EXPLODE = {
		category = AudioCategory.GAMEPLAY
	},
	SCARAB_FLY = {
		category = AudioCategory.EFFECTS
	},
	VOID_ADETUNDE_SKIN_SHIELD = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_ADETUNDE_SKIN_SHIELD_BLAST = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_ADETUNDE_SKIN_SLAM = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_ADETUNDE_SKIN_STORM_START = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_ADETUNDE_SKIN_STORM_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_ADETUNDE_SKIN_STORM_END = {
		category = AudioCategory.GAMEPLAY
	},
	SNOW_OWL_SKIN_ADETUNDE_SHIELD = {
		category = AudioCategory.EFFECTS
	},
	SNOW_OWL_SKIN_ADETUNDE_SHIELD_BLAST = {
		category = AudioCategory.EFFECTS
	},
	SNOW_OWL_SKIN_ADETUNDE_SLAM = {
		category = AudioCategory.EFFECTS
	},
	SNOW_OWL_SKIN_ADETUNDE_STORM_START = {
		category = AudioCategory.EFFECTS
	},
	SNOW_OWL_SKIN_ADETUNDE_STORM_LOOP = {
		category = AudioCategory.EFFECTS
	},
	SNOW_OWL_SKIN_ADETUNDE_STORM_END = {
		category = AudioCategory.EFFECTS
	},
	TIDAL_BLACK_MARKET_SHOP_SUMMON = {
		category = AudioCategory.UI
	},
	TIDAL_BLACK_MARKET_SHOP_UPGRADE = {
		category = AudioCategory.UI
	},
	TREASURE_PILE_EMOTE = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	BEACH_VOLLEY_BALL_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BEACH_VOLLEY_BALL_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BEACH_VOLLEY_BALL_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BEACH_VOLLEY_BALL_HIT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SHARK_BITE = {
		category = AudioCategory.COSMETICS
	},
	ANGEL_WING_WIN_EFFECT_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	GUN_BLADE_SHOT = {
		category = AudioCategory.GAMEPLAY
	},
	GUN_BLADE_TRIGGER = {
		category = AudioCategory.GAMEPLAY
	},
	GUN_BLADE_SHOT_SUMMER = {
		category = AudioCategory.GAMEPLAY
	},
	GUN_BLADE_TRIGGER_SUMMER = {
		category = AudioCategory.GAMEPLAY
	},
	PILLOW_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	PILLOW_HIT_2 = {
		category = AudioCategory.COSMETICS
	},
	PILLOW_HIT_3 = {
		category = AudioCategory.COSMETICS
	},
	WOOD_BLOCK_BREAK = {
		category = AudioCategory.COSMETICS
	},
	EXPLODING_TANK_BLOCK_ON_FIRE = {
		category = AudioCategory.GAMEPLAY
	},
	EXPLODING_TANK_BLOCK_EXPLODE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	EXPLODING_TANK_BLOCK_EXPLODE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	EXPLODING_TANK_BLOCK_EXPLODE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BED_DAMAGED_ALERT = {
		category = AudioCategory.GAMEPLAY
	},
	BED_DAMAGED_ALERT_OVERLAY = {
		category = AudioCategory.GAMEPLAY
	},
	AERY_BUTTERFLY_SOUND_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	VICTORIOUS_PROJECTILE_LAUNCHOVERLAY_GOLD = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_PROJECTILE_LAUNCHOVERLAY_PLATINUM = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_PROJECTILE_LAUNCHOVERLAY_DIAMOND = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_PROJECTILE_LAUNCHOVERLAY_EMERALD = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	VICTORIOUS_PROJECTILE_LAUNCHOVERLAY_NIGHTMARE = {
		volume = 0.85,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	ACHIEVEMENT_UNLOCK_COMMON = {
		category = AudioCategory.GAMEPLAY
	},
	ACHIEVEMENT_UNLOCK_RARE = {
		category = AudioCategory.GAMEPLAY
	},
	ACHIEVEMENT_UNLOCK_EPIC = {
		category = AudioCategory.GAMEPLAY
	},
	ACHIEVEMENT_UNLOCK_LEGENDARY = {
		category = AudioCategory.GAMEPLAY
	},
	BAT_EXPLOSION = {
		category = AudioCategory.COSMETICS
	},
	POTION_IMPACT = {
		category = AudioCategory.GAMEPLAY
	},
	SKELETON_KIT_SMOKE_LOOP = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_KIT_DISASSEMBLE = {
		category = AudioCategory.EFFECTS
	},
	SKELETON_KIT_REASSEMBLE = {
		category = AudioCategory.EFFECTS
	},
	THRILLER_DANCE_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	DRAGON_SWORD_JIANG_SHI_SHOOT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_JIANG_SHI_SHOOT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_JIANG_SHI_SHOOT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_JIANG_SHI_ULT_CAST = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_JIANG_SHI_ULT_FALL = {
		category = AudioCategory.GAMEPLAY
	},
	DRAGON_SWORD_JIANG_SHI_ULT_LAND = {
		category = AudioCategory.GAMEPLAY
	},
	CENTIPEDE_STEP = {
		category = AudioCategory.COSMETICS
	},
	CENTIPEDE_LEG_POP_OUT = {
		category = AudioCategory.COSMETICS
	},
	DESERT_ISLAND_MUSIC = {
		volume = 0.75,
		preload = true,
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	DEER_STOMP_1 = {
		category = AudioCategory.GAMEPLAY
	},
	DEER_STOMP_2 = {
		category = AudioCategory.GAMEPLAY
	},
	DEER_STOMP_3 = {
		category = AudioCategory.GAMEPLAY
	},
	DEER_STOMP_4 = {
		category = AudioCategory.GAMEPLAY
	},
	DEER_SLEIGH_LOOP = {
		category = AudioCategory.COSMETICS
	},
	DEER_SLEIGH_CRUSH = {
		category = AudioCategory.COSMETICS
	},
	SNOWBALL_FALL = {
		category = AudioCategory.COSMETICS
	},
	SNOWBALL_CRUSH = {
		category = AudioCategory.COSMETICS
	},
	SNOWBOARD_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBOARD_AVALANCHE_LOOP = {
		category = AudioCategory.GAMEPLAY
	},
	SNOWBOARD_MUSIC = {
		bus = BedWarsAudioBuses.MATCH_MUSIC
	},
	FROST_STAFF_LOOP = {
		category = AudioCategory.COSMETICS
	},
	FROST_STAFF_FREEZE = {
		category = AudioCategory.COSMETICS
	},
	FROST_STAFF_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	FROST_STAFF_SHOOT = {
		category = AudioCategory.GAMEPLAY
	},
	CHRISMAS_CAROL = {
		volume = 2,
		preload = true,
		category = AudioCategory.GAMEPLAY
	},
	REWARD_CLAIM = {
		category = AudioCategory.GAMEPLAY
	},
	ELDERTREE_VICTORIOUS_GOLD_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	ELDERTREE_VICTORIOUS_PLATINUM_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	ELDERTREE_VICTORIOUS_DIAMOND_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	ELDERTREE_VICTORIOUS_EMERALD_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	ELDERTREE_VICTORIOUS_NIGHTMARE_PICKUP = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_ASSASSIN_KURO_DAGGER_CHARGE = {
		category = AudioCategory.GAMEPLAY
	},
	SPIRIT_ASSASSIN_KURO_DAGGER_SLASH = {
		category = AudioCategory.GAMEPLAY
	},
	AERY_BUTTERFLY_SPAWN_VALENTINE = {
		category = AudioCategory.GAMEPLAY
	},
	AERY_BUTTERFLY_CONSUME_VALENTINE = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_SWORD_SWING_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_SWORD_SWING_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_SWORD_SWING_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_SWORD_SWING_4 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_SWORD_DAMAGE_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_SWORD_DAMAGE_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_SWORD_DAMAGE_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_SWORD_DAMAGE_4 = {
		category = AudioCategory.GAMEPLAY
	},
	PIXEL_SWORD_DAMAGE = {
		category = AudioCategory.GAMEPLAY
	},
	PIXEL_SWORD_SWING = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_KNIGHT_KILL_EFFECT = {
		category = AudioCategory.COSMETICS
	},
	ROTTEN_EGG_EMOTE_SOUND = {
		bus = BedWarsAudioBuses.EMOTE_MUSIC
	},
	BED_INFLATE_SOUND = {
		category = AudioCategory.COSMETICS
	},
	BED_POP_SOUND = {
		category = AudioCategory.COSMETICS
	},
	BALLOON_TOOL_BLOCK_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_TOOL_BLOCK_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_TOOL_BLOCK_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	BALLOON_TOOL_BLOCK_HIT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_EYE_HUMMING = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_EYE_CLOSE_UP = {
		category = AudioCategory.GAMEPLAY
	},
	SOUL_LINK_APPLY_ENEMY = {
		category = AudioCategory.GAMEPLAY
	},
	SOUL_LINK_APPLY_ALLY = {
		category = AudioCategory.GAMEPLAY
	},
	SOUL_LINK_DAMAGE_ENEMY = {
		category = AudioCategory.GAMEPLAY
	},
	SOUL_LINK_DAMAGE_ALLY = {
		category = AudioCategory.GAMEPLAY
	},
	WARRIOR_FINAL_STAND_LOOP = {
		category = AudioCategory.EFFECTS
	},
	WARRIOR_FINAL_STAND_KILL = {
		category = AudioCategory.EFFECTS
	},
	WATER_FILL_UP = {
		category = AudioCategory.GAMEPLAY
	},
	HAIR_DRYER_START = {
		category = AudioCategory.EFFECTS
	},
	HAIR_DRYER_LOOP = {
		category = AudioCategory.EFFECTS
	},
	HAIR_DRYER_END = {
		category = AudioCategory.EFFECTS
	},
	SAND_HIT_1 = {
		category = AudioCategory.GAMEPLAY
	},
	SAND_HIT_2 = {
		category = AudioCategory.GAMEPLAY
	},
	SAND_HIT_3 = {
		category = AudioCategory.GAMEPLAY
	},
	SAND_HIT_4 = {
		category = AudioCategory.GAMEPLAY
	},
	SAND_FALLING = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_JACK_CONSUME = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_JACK_SPIT = {
		category = AudioCategory.GAMEPLAY
	},
	VOID_JACK_SPLASH = {
		category = AudioCategory.GAMEPLAY
	},
	JACK_CONSUME = {
		category = AudioCategory.GAMEPLAY
	},
	BOUNTYHUNTER_LEVEL_UP = {
		category = AudioCategory.GAMEPLAY
	},
	BOUNTYHUNTER_TRACK = {
		category = AudioCategory.GAMEPLAY
	},
	WANDERER_BOUNTYHUNTER_LEVEL_UP = {
		category = AudioCategory.GAMEPLAY
	},
	WANDERER_BOUNTYHUNTER_TRACK = {
		category = AudioCategory.GAMEPLAY
	}
}

return {
    registerGameSounds = function(p1)
        local t2 = {}

        for _, v22 in ObjectUtil.entries(p1) do
            local v3 = v22[1]
            local v4 = v22[2]

            if v4 ~= '' then
                local t3 = {
                    preload = false
                }

                if t[v3] then
                    for v5, v6 in t[v3] do
                        if v5 ~= 'category' and v5 ~= 'bus' then
                            t3[v5] = v6
                        end
                    end
                end

                if not t2[v4] then
                    t2[v4] = t3
                end
            end
        end

        for v14, v15 in t2 do
            SoundManager:registerSound(v14, v15)
        end
    end,

    GameSoundMeta = t
}
