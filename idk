local CollectionService

local license = ... or {}
local REPO = "https://raw.githubusercontent.com/MaxlaserTech/CatV6/main/"

local function fetchModule(path)
    return game:HttpGet(REPO .. path, true)
end

local BRANCH = "main"

local function ensureFolder(path)
    if not isfolder(path) then
        makefolder(path)
    end
end

local function ensureCacheTree()
    ensureFolder("catsix")
    ensureFolder("catsix/profiles")
    ensureFolder("catsix/assets")
    ensureFolder("catsix/assets/new")
    ensureFolder("catsix/games")
    ensureFolder("catsix/guis")
    ensureFolder("catsix/libraries")
    local commit = "catsix/profiles/commit.txt"
    local ok, current = pcall(readfile, commit)
    if not ok or current == nil or current == "" then
        writefile(commit, BRANCH)
    end
end

ensureCacheTree()

local vape = shared.vape or _G.vape
if not vape then
    vape = loadstring(fetchModule("guis/new.lua"), "gui")(license)
    shared.vape = vape
    _G.vape = vape
end

if not shared.VapeIndependent and not getgenv().bedwars then
    local okUniversal, errUniversal = pcall(function()
        loadstring(fetchModule("games/universal.lua"), "universal")(license)
    end)
    if not okUniversal then
        warn("[premium] universal module failed: " .. tostring(errUniversal))
    end

    local placePath = "games/" .. tostring(game.PlaceId) .. ".lua"
    local okFetch, body = pcall(fetchModule, placePath)
    if okFetch and body and body ~= "404: Not Found" then
        local okPlace, errPlace = pcall(function()
            loadstring(body, tostring(game.PlaceId))(license)
        end)
        if not okPlace then
            warn("[premium] place module " .. placePath .. " failed: " .. tostring(errPlace))
        end
    else
        warn("[premium] no module for PlaceId " .. tostring(game.PlaceId))
    end
end

local bedwars = getgenv().bedwars
local store = getgenv().store
if not bedwars then
    warn("[premium] bedwars is not defined; PlaceId=" .. tostring(game.PlaceId)
        .. " vape.Place=" .. tostring(vape and vape.Place))
    return
end

local targetSorts = {}
local sortFunctions = targetSorts
local signals = {}
local clientEvents = {}
local userConfig = {}
local WebSocket = _G.WebSocket or {connect = function() end}

local collectionService = game:GetService("CollectionService")
local teleportService = game:GetService("TeleportService")

local function notify(title, text, duration, kind)
    if vape and vape.CreateNotification then
        vape:CreateNotification(title or "Cat", text or "", duration or 10, kind or "alert")
    end
end

local createNotification = notify

local function debugPrint(...)
    if shared.CatV6Debug then
        print("[premium]", ...)
    end
end

local reportedMissing = {}
local function missing(name)
    return function()
        if not reportedMissing[name] then
            reportedMissing[name] = true
            warn("[premium] " .. name .. " was not recovered from the listing")
        end
        return nil
    end
end

local getBlockAt = missing("getBlockAt")
local getItemSlot = missing("getItemSlot")
local switchItem = missing("switchItem")
local equipItem = missing("equipItem")
local getItem = missing("getItem")
local findItemForTool = missing("findItemForTool")
local equipTool = missing("equipTool")
local getSharedState = missing("getSharedState")
local getTrackedTable = missing("getTrackedTable")
local formatNumber = missing("formatNumber")
local getInstanceList = missing("getInstanceList")
local isPaidUser = false
local authFinished = false
local authDeadline = os.clock() + 7
local Players, ReplicatedStorage, RunService, UserInputService, TweenService, HttpService
local TextChatService, CollectionService, ContextActionService, ProximityPromptService
local GuiService, CoreGui, StarterGui
local currentCamera, localPlayer, entity, targetinfo, prediction

if vape.Place == 6872274481 then
    Players = cloneref(game:GetService("Players"))
    ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
    RunService = cloneref(game:GetService("RunService"))
    UserInputService = cloneref(game:GetService("UserInputService"))
    TweenService = cloneref(game:GetService("TweenService"))
    HttpService = cloneref(game:GetService("HttpService"))
    TextChatService = cloneref(game:GetService("TextChatService"))
    CollectionService = cloneref(game:GetService("CollectionService"))
    ContextActionService = cloneref(game:GetService("ContextActionService"))
    ProximityPromptService = cloneref(game:GetService("ProximityPromptService"))
    GuiService = cloneref(game:GetService("GuiService"))
    CoreGui = cloneref(game:GetService("CoreGui"))
    StarterGui = cloneref(game:GetService("StarterGui"))

    currentCamera = workspace.CurrentCamera
    localPlayer = Players.LocalPlayer
    entity = vape.Libraries.entity
    targetinfo = vape.Libraries.targetinfo
    prediction = vape.Libraries.prediction
end
local BYTE_TO_CHAR = {}
for byte = 0, 255 do
    BYTE_TO_CHAR[byte] = string.char(byte)
end
local Crypto = {}
Crypto.hmac = {}
Crypto.aes = {}
local AES_SBOX = {
    99, 124, 119, 123, 242, 107, 111, 197, 48, 1, 103, 43, 254, 215, 171, 118,
    202, 130, 201, 125, 250, 89, 71, 240, 173, 212, 162, 175, 156, 164, 114, 192,
    183, 253, 147, 38, 54, 63, 247, 204, 52, 165, 229, 241, 113, 216, 49, 21,
    4, 199, 35, 195, 24, 150, 5, 154, 7, 18, 128, 226, 235, 39, 178, 117,
    9, 131, 44, 26, 27, 110, 90, 160, 82, 59, 214, 179, 41, 227, 47, 132,
    83, 209, 0, 237, 32, 252, 177, 91, 106, 203, 190, 57, 74, 76, 88, 207,
    208, 239, 170, 251, 67, 77, 51, 133, 69, 249, 2, 127, 80, 60, 159, 168,
    81, 163, 64, 143, 146, 157, 56, 245, 188, 182, 218, 33, 16, 255, 243, 210,
    205, 12, 19, 236, 95, 151, 68, 23, 196, 167, 126, 61, 100, 93, 25, 115,
    96, 129, 79, 220, 34, 42, 144, 136, 70, 238, 184, 20, 222, 94, 11, 219,
    224, 50, 58, 10, 73, 6, 36, 92, 194, 211, 172, 98, 145, 149, 228, 121,
    231, 200, 55, 109, 141, 213, 78, 169, 108, 86, 244, 234, 101, 122, 174, 8,
    186, 120, 37, 46, 28, 166, 180, 198, 232, 221, 116, 31, 75, 189, 139, 138,
    112, 62, 181, 102, 72, 3, 246, 14, 97, 53, 87, 185, 134, 193, 29, 158,
    225, 248, 152, 17, 105, 217, 142, 148, 155, 30, 135, 233, 206, 85, 40, 223,
    140, 161, 137, 13, 191, 230, 66, 104, 65, 153, 45, 15, 176, 84, 187, 22,
}
local AES_RCON = { 1, 2, 4, 8, 16, 32, 64, 128, 27, 54 }
local PAYLOAD_FIELD_ALIASES = {}

PAYLOAD_FIELD_ALIASES.ciphertext = {"h3", "h4", "xt", "cx", "l5", "cn", "FOCAT WHAT ME"}
PAYLOAD_FIELD_ALIASES.iv = {"xyq", "XD LOL", "xy43", "1dn", "o26", "s61", "sss", "ah4"}
PAYLOAD_FIELD_ALIASES.tag = {"ta", "sl", "b33", "l27", "dec", "rin", "linux"}
PAYLOAD_FIELD_ALIASES.wrappedkey = {"316", "xt213", "2315", "x25", "xsww", "326", "ps4"}
PAYLOAD_FIELD_ALIASES.yea = {"yea", "read me", "stop debug"}
PAYLOAD_FIELD_ALIASES.keytag = {"bnn", "bnc", "x2l", "ldb", "dbw", "xlg"}
PAYLOAD_FIELD_ALIASES.keyiv = {"asx", "lkh", "lxg", "ngi", "nin", "c31"}
PAYLOAD_FIELD_ALIASES.masterkey = {"xk9", "mk2", "zp7", "qw3", "rt8", "ux5", "vb1"}
local KEY_PROGRAM_SOURCE = {9, 1, 6, 2, 1, 7, 10, 2}
local function appendValue(list, value)
    list[#list + 1] = value
end
local function tableAddressChecksum()
    local address = tostring({})
    local total = 0
    for index = 6, #address do
        local byte = address:byte(index) or 0
        total = (total + byte * index) % 2147483648
    end
    return total
end
local function seededRandom()
    local seed = tableAddressChecksum() % 2147483648
    math.randomseed(seed)
    return math.random
end
local DECOY_STRINGS = {
    "all rights reserved to catvape.dev",
    "tampering with this message is prohibited",
    "<https://catvape.dev>"
}

for _ = 1, 13 do
    appendValue(DECOY_STRINGS, ("%d.%d.%d.%d"):format(
        seededRandom()(0, 255),
        seededRandom()(0, 255),
        seededRandom()(0, 255),
        seededRandom()(0, 255)
    ))
end
local silentAura
local auraTargets
local aimSpeedSlider
local extraSwingDistanceSlider
local maxAngleSlider
local targetModeDropdown
local targetAreaDropdown
local swingOnlyToggle
local mouseDownToggle
local dynamicHitsToggle
local limitToItemsToggle
local silentAimToggle
local swingTimeSlider
local perfectSwingToggle
local showTargetToggle
local targetColorSlider
local attackColorSlider
local characterPartCache = {}
local targetAdornment = Instance.new("BoxHandleAdornment")
targetAdornment.Adornee = nil
targetAdornment.AlwaysOnTop = false
targetAdornment.Size = Vector3.new(3, 5, 3)
targetAdornment.CFrame = CFrame.new(0, -0.5, 0)
targetAdornment.ZIndex = 0
targetAdornment.Parent = vape.gui
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local killauraRequireMouseDownToggle
local killauraAttackableCheckToggle
local killauraGuiCheckToggle
local killauraLimitToItemsToggle
local killauraSwingOnlyToggle
local killauraProjectilesList

local killauraTargetTimes = {}
local killauraLastSwing = tick()

local killauraRaycastParams = RaycastParams.new()
killauraRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

local swordHitRemote = {FireServer = function() end}
local swordSwingMissRemote = {FireServer = function() end}
local projectileFireRemote = bedwars.Handler:Get("ProjectileFire")

local killauraLastTarget = nil
local killauraHitCount = 0
local killauraProjectileCache = {}

task.spawn(function()
    swordHitRemote = bedwars.Handler:Get("SwordHit")
    swordSwingMissRemote = bedwars.Handler:Get("SwordSwingMiss")
end)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local function run(callback)
    callback()
end
local function toStringValue(value)
    return ("%*"):format(value)
end
local function repeatString(text, count, separator)
    local source = "" .. text
    local total = count + 0
    if total <= 0 then
        return ""
    end
    local glue = (separator and ("" .. separator)) or ""
    local out = source
    for _ = 2, total do
        out = out .. glue .. source
    end
    return out
end
local function byteOf(text, index)
    return string.byte(text, index or 1)
end
local function formatString(pattern, ...)
    return string.format(pattern, ...)
end
local function bytesToString(...)
    local bytes = { ... }
    local count = #bytes
    if count == 0 then
        return ""
    end
    if count == 1 then
        return BYTE_TO_CHAR[bytes[1]] or ""
    end
    local out = ""
    for i = 1, count do
        local char = BYTE_TO_CHAR[bytes[i]]
        if char then
            out = out .. char
        end
    end
    return out
end
local function quickSortRange(list, low, high, comparator)
    if high <= low then
        return
    end
    local middle = low + (high - low) / 2
    local pivot = list[middle - middle % 1]
    local left = low
    local right = high
    while left <= right do
        while comparator(list[left], pivot) do
            left = left + 1
        end
        while comparator(pivot, list[right]) do
            right = right - 1
        end
        if left <= right then
            local swapped = list[left]
            list[left] = list[right]
            list[right] = swapped
            left = left + 1
            right = right - 1
        end
    end
    quickSortRange(list, low, right, comparator)
    quickSortRange(list, left, high, comparator)
end
local function sortList(list, comparator)
    if not comparator then
        comparator = function(a, b)
            return a < b
        end
    end
    quickSortRange(list, 1, #list, comparator)
end
local function arrayNext(list, index)
    local nextIndex = index + 1
    local value = list[nextIndex]
    if value ~= nil then
        return nextIndex, value
    end
end
local function arrayPairs(list)
    return arrayNext, list, 0
end
local function indexOfValue(list, value, from)
    for i = from or 1, #list do
        if list[i] == value then
            return i
        end
    end
end
local function floorOf(number)
    return number - number % 1
end
local function absOf(number)
    if number < 0 then
        return -number
    end
    return number
end
local function joinStrings(list, separator)
    local out = ""
    for index, value in next, list do
        local glue = ""
        if separator and index ~= #list then
            glue = separator
        end
        out = out .. value .. glue
    end
    return out
end
local function parseInteger(text)
    local digits = {
        ["0"] = 0,
        ["1"] = 1,
        ["2"] = 2,
        ["3"] = 3,
        ["4"] = 4,
        ["5"] = 5,
        ["6"] = 6,
        ["7"] = 7,
        ["8"] = 8,
        ["9"] = 9,
    }
    local total = 0
    local negative = false
    for index, char in next, text:split("") do
        if index == 1 and char == "-" then
            negative = true
        else
            local digit = digits[char]
            if digit == nil then
                return nil
            end
            total = total * 10 + digit
        end
    end
    if negative then
        return -total
    end
    return total
end
local function jsonEncode(value, pretty, depth)
    local valueType = type(value)

    if value == nil then
        return "null"
    end

    if valueType == "boolean" then
        return toStringValue(value)
    end

    if valueType == "number" then
        if absOf(value) == math.huge then
            return "null"
        end
        if value ~= floorOf(value) or not (absOf(value) < 1000000000000000) then
            return formatString("%.14g", value)
        end
        return formatString("%d", value)
    end

    if valueType == "string" then
        local escaped = value:gsub("\\", "\\\\")
        escaped = escaped:gsub("\"", "\\\"")
        escaped = escaped:gsub("\n", "\\n")
        escaped = escaped:gsub("\r", "\\r")
        escaped = escaped:gsub("\t", "\\t")
        escaped = escaped:gsub("%c", function(control)
            return formatString("\\u%04x", byteOf(control))
        end)
        return "\"" .. escaped .. "\""
    end

    if valueType ~= "table" then
        return
    end

    local isArray = true
    local maxIndex = 0
    for key in next, value do
        if type(key) ~= "number" then
            isArray = false
            break
        end
        if key ~= floorOf(key) or not (1 <= key) then
            isArray = false
            break
        end
        if maxIndex < key then
            maxIndex = key
        end
    end
    if maxIndex ~= #value then
        isArray = false
    end

    if next(value) == nil then
        return (isArray and "[]") or "{}"
    end

    local childDepth = depth + 1
    local innerPad = (pretty and repeatString("  ", childDepth)) or ""
    local outerPad = (pretty and repeatString("  ", depth)) or ""
    local entrySeparator = (pretty and ",\n") or ","
    local parts = {}

    if isArray then
        for _, item in arrayPairs(value) do
            appendValue(parts, innerPad .. jsonEncode(item, pretty, childDepth))
        end
    else
        local keys = {}
        for key in next, value do
            appendValue(keys, key)
        end
        sortList(keys, function(a, b)
            return toStringValue(a) < toStringValue(b)
        end)
        local keySeparator = (pretty and ": ") or ":"
        for _, key in arrayPairs(keys) do
            local encodedKey = jsonEncode(toStringValue(key), pretty, childDepth)
            local encodedValue = jsonEncode(value[key], pretty, childDepth)
            appendValue(parts, innerPad .. encodedKey .. keySeparator .. encodedValue)
        end
    end

    local open
    local close
    if isArray then
        open = (pretty and "[\n") or "["
        close = (pretty and ("\n" .. outerPad .. "]")) or "]"
    else
        open = (pretty and "{\n") or "{"
        close = (pretty and ("\n" .. outerPad .. "}")) or "}"
    end

    return open .. joinStrings(parts, entrySeparator) .. close
end
local function createJsonParser(source)
    local position = 1
    local parseValue

    local function peek()
        return source:sub(position, position)
    end

    local function advance(count)
        position = position + (count or 1)
    end

    local function skipWhitespace()
        while position <= #source do
            local char = source:sub(position, position)
            if not char:match("%s") then
                break
            end
            position = position + 1
        end
    end

    local function expect(expected)
        skipWhitespace()
        if source:sub(position, position) ~= expected then
            error(string.format("[JSON] Expected '%s' at pos %d, got '%s'", expected, position, source:sub(position, position)))
        end
        advance()
    end

    local function parseString()
        expect("\"")
        local parts = {}
        local escapes = {
            ["\""] = "\"",
            ["\\"] = "\\",
            ["/"] = "/",
            n = "\n",
            r = "\r",
            t = "\t",
            b = "\b",
            f = "\f",
        }
        while position <= #source do
            local char = peek()
            if char == "\"" then
                advance()
                return table.concat(parts)
            elseif char ~= "\\" then
                table.insert(parts, char)
                advance()
            else
                advance()
                local escape = peek()
                advance()
                if escapes[escape] then
                    table.insert(parts, escapes[escape])
                elseif escape ~= "u" then
                    error("[JSON] Unknown escape: \\" .. escape)
                else
                    local hex = source:sub(position, position + 3)
                    advance(4)
                    local codepoint = tonumber(hex, 16)
                    if not codepoint then
                        error("[JSON] Invalid unicode: \\u" .. hex)
                    end
                    if codepoint < 128 then
                        table.insert(parts, string.char(codepoint))
                    elseif codepoint < 2048 then
                        table.insert(parts, string.char(192 + math.floor(codepoint / 64), 128 + codepoint % 64))
                    else
                        table.insert(parts, string.char(224 + math.floor(codepoint / 4096), 128 + math.floor(codepoint % 4096 / 64), 128 + codepoint % 64))
                    end
                end
            end
        end
        error("[JSON] Unterminated string")
    end

    local function parseNumber()
        local start = position
        if peek() == "-" then
            advance()
        end
        while position <= #source and peek():match("%d") do
            advance()
        end
        if peek() == "." then
            advance()
            while position <= #source and peek():match("%d") do
                advance()
            end
        end
        if peek():lower() == "e" then
            advance()
            if peek() == "+" then
                advance()
            elseif peek() == "-" then
                advance()
            end
            while position <= #source and peek():match("%d") do
                advance()
            end
        end
        local value = tonumber(source:sub(start, position - 1))
        if not value then
            error("[JSON] Invalid number at pos " .. start)
        end
        return value
    end

    local function parseArray()
        expect("[")
        skipWhitespace()
        local items = {}
        if peek() ~= "]" then
            while true do
                table.insert(items, parseValue())
                skipWhitespace()
                if peek() == "]" then
                    break
                end
                expect(",")
            end
        end
        advance()
        return items
    end

    local function parseObject()
        expect("{")
        skipWhitespace()
        local object = {}
        if peek() ~= "}" then
            while true do
                skipWhitespace()
                local key = parseString()
                expect(":")
                object[key] = parseValue()
                skipWhitespace()
                if peek() == "}" then
                    break
                end
                expect(",")
            end
        end
        advance()
        return object
    end

    parseValue = function()
        skipWhitespace()
        local char = peek()
        if char == "\"" then
            return parseString()
        end
        if char == "{" then
            return parseObject()
        end
        if char == "[" then
            return parseArray()
        end
        if char == "t" and source:sub(position, position + 3) == "true" then
            advance(4)
            return true
        end
        if char == "f" and source:sub(position, position + 4) == "false" then
            advance(5)
            return false
        end
        if char == "n" and source:sub(position, position + 3) == "null" then
            advance(4)
            return nil
        end
        if char == "-" or char:match("%d") then
            return parseNumber()
        end
        error(string.format("[JSON] Unexpected '%s' at pos %d", char, position))
    end

    return parseValue, function()
        return position
    end
end
local function jsonDecode(text)
    assert(type(text) == "string", "[JSON] decode() expects a string")
    local parseValue, getPosition = createJsonParser(text)
    local value = parseValue()
    local trailing = text:sub(getPosition()):match("^%s*(.-)%s*$")
    return value
end
local bit = bit32

local function bxor(a, b)
    return bit.bxor(a, b)
end

local function band(a, b)
    return bit.band(a, b)
end

local function bnot(value)
    return bit.bnot(value)
end

local function rshift(value, amount)
    return bit.rshift(value, amount)
end

local function lshift(value, amount)
    return bit.lshift(value, amount)
end
local function subWord(word)
    return bxor(
        bxor(
            bxor(
                lshift(AES_SBOX[band(rshift(word, 24), 255) + 1], 24),
                lshift(AES_SBOX[band(rshift(word, 16), 255) + 1], 16)
            ),
            lshift(AES_SBOX[band(rshift(word, 8), 255) + 1], 8)
        ),
        AES_SBOX[band(word, 255) + 1]
    )
end
local function rotWord(word)
    return bxor(
        bxor(
            bxor(
                lshift(band(rshift(word, 16), 255), 24),
                lshift(band(rshift(word, 8), 255), 16)
            ),
            lshift(band(word, 255), 8)
        ),
        band(rshift(word, 24), 255)
    )
end
local function expandKey(keyBytes)
    local schedule = {}
    local wordCount = #keyBytes / 4
    local rounds = wordCount + 6
    for index = 0, wordCount - 1 do
        schedule[index] = bxor(
            bxor(
                bxor(
                    lshift(keyBytes[index * 4 + 1], 24),
                    lshift(keyBytes[index * 4 + 2], 16)
                ),
                lshift(keyBytes[index * 4 + 3], 8)
            ),
            keyBytes[index * 4 + 4]
        )
    end
    for index = wordCount, 4 * (rounds + 1) - 1 do
        local temp = schedule[index - 1]
        if index % wordCount == 0 then
            temp = bxor(subWord(rotWord(temp)), lshift(AES_RCON[index / wordCount], 24))
        elseif wordCount > 6 and index % wordCount == 4 then
            temp = subWord(temp)
        end
        schedule[index] = bxor(schedule[index - wordCount], temp)
    end
    return schedule, rounds
end
local function addRoundKey(state, roundKey)
    for index = 0, 15 do
        state[index + 1] = bxor(state[index + 1], roundKey[index + 1])
    end
end
local function subBytes(state)
    for index = 1, 16 do
        state[index] = AES_SBOX[state[index] + 1]
    end
end
local function shiftRows(state)
    local carry = state[2]
    state[2] = state[6]
    state[6] = state[10]
    state[10] = state[14]
    state[14] = carry

    carry = state[3]
    state[3] = state[11]
    state[11] = carry

    carry = state[7]
    state[7] = state[15]
    state[15] = carry

    carry = state[4]
    state[4] = state[16]
    state[16] = state[12]
    state[12] = state[8]
    state[8] = carry
end
local function xtime(value)
    local doubled = lshift(value, 1)
    if value >= 128 then
        doubled = bxor(doubled, 27)
    end
    return band(doubled, 255)
end
local function mixColumns(state)
    for column = 0, 3 do
        local b0 = state[column * 4 + 1]
        local b1 = state[column * 4 + 2]
        local b2 = state[column * 4 + 3]
        local b3 = state[column * 4 + 4]
        local all = bxor(bxor(bxor(b0, b1), b2), b3)
        state[column * 4 + 1] = bxor(bxor(b0, xtime(bxor(b0, b1))), all)
        state[column * 4 + 2] = bxor(bxor(b1, xtime(bxor(b1, b2))), all)
        state[column * 4 + 3] = bxor(bxor(b2, xtime(bxor(b2, b3))), all)
        state[column * 4 + 4] = bxor(bxor(b3, xtime(bxor(b3, b0))), all)
    end
end
local function encryptBlock(block, schedule, rounds)
    local state = {}
    for index = 1, 16 do
        state[index] = block[index]
    end

    local roundKey = {}
    for index = 1, 16 do
        local word = math.floor((index - 1) / 4)
        local byte = (index - 1) % 4
        roundKey[index] = band(rshift(schedule[word], (3 - byte) * 8), 255)
    end
    addRoundKey(state, roundKey)

    for round = 1, rounds - 1 do
        subBytes(state)
        shiftRows(state)
        mixColumns(state)
        for index = 1, 16 do
            local word = math.floor((index - 1) / 4 + round * 4)
            local byte = (index - 1) % 4
            roundKey[index] = band(rshift(schedule[word], (3 - byte) * 8), 255)
        end
        addRoundKey(state, roundKey)
    end

    subBytes(state)
    shiftRows(state)
    for index = 1, 16 do
        local word = math.floor((index - 1) / 4 + rounds * 4)
        local byte = (index - 1) % 4
        roundKey[index] = band(rshift(schedule[word], (3 - byte) * 8), 255)
    end
    addRoundKey(state, roundKey)

    return state
end
local function incrementCounter(counter)
    for index = 16, 1, -1 do
        counter[index] = counter[index] + 1
        if counter[index] <= 255 then
            return
        end
        counter[index] = 0
    end
end
local function gmul(a, b)
    local product = 0
    for _ = 0, 7 do
        if band(b, 1) ~= 0 then
            product = bxor(product, a)
        end
        local highBitSet = band(a, 128) ~= 0
        a = lshift(a, 1)
        if highBitSet then
            a = bxor(a, 27)
        end
        a = band(a, 255)
        b = rshift(b, 1)
    end
    return product
end
local function bor(a, b)
    return bnot(band(bnot(a), bnot(b)))
end
local function ghashMultiply(hashSubkey, accumulator, block)
    for index = 1, 16 do
        accumulator[index] = bxor(accumulator[index], block[index])
    end

    local result = {}
    for index = 1, 16 do
        result[index] = 0
    end

    local shifted = {}
    for index = 1, 16 do
        shifted[index] = hashSubkey[index]
    end

    for bitIndex = 1, 128 do
        local byteIndex = math.floor((bitIndex - 1) / 8) + 1
        local bitOffset = 7 - (bitIndex - 1) % 8
        if band(rshift(accumulator[byteIndex], bitOffset), 1) ~= 0 then
            for index = 1, 16 do
                result[index] = bxor(result[index], shifted[index])
            end
        end
        local lowBit = band(shifted[16], 1)
        for index = 16, 2, -1 do
            shifted[index] = bor(rshift(shifted[index], 1), lshift(band(shifted[index - 1], 1), 7))
        end
        shifted[1] = rshift(shifted[1], 1)
        if lowBit ~= 0 then
            shifted[1] = bxor(shifted[1], 225)
        end
    end

    for index = 1, 16 do
        accumulator[index] = result[index]
    end
end
local function gcmEncrypt(key, iv, plaintext, additionalData)
    if #key ~= 32 then
        error("Key must be 32 bytes for AES-256")
    end

    local schedule, rounds = expandKey(key)

    local zeroBlock = {}
    for index = 1, 16 do
        zeroBlock[index] = 0
    end
    local hashSubkey = encryptBlock(zeroBlock, schedule, rounds)

    local initialCounter = {}
    if #iv ~= 12 then
        for index = 1, 16 do
            initialCounter[index] = 0
        end

        local ivBlocks = math.ceil(#iv / 16)
        for blockIndex = 1, ivBlocks do
            local block = {}
            for index = 1, 16 do
                local position = (blockIndex - 1) * 16 + index
                block[index] = (position <= #iv and iv[position]) or 0
            end
            ghashMultiply(hashSubkey, initialCounter, block)
        end

        local lengthBlock = {}
        for index = 1, 8 do
            lengthBlock[index] = 0
        end
        local ivBitLength = #iv * 8
        for index = 0, 7 do
            lengthBlock[9 + index] = band(rshift(ivBitLength, (7 - index) * 8), 255)
        end
        ghashMultiply(hashSubkey, initialCounter, lengthBlock)
    else
        for index = 1, 12 do
            initialCounter[index] = iv[index]
        end
        initialCounter[13] = 0
        initialCounter[14] = 0
        initialCounter[15] = 0
        initialCounter[16] = 1
    end

    local counter = {}
    for index = 1, 16 do
        counter[index] = initialCounter[index]
    end
    incrementCounter(counter)

    local ciphertext = {}
    local plaintextBlocks = math.ceil(#plaintext / 16)
    for blockIndex = 1, plaintextBlocks do
        local keystream = encryptBlock(counter, schedule, rounds)
        for index = 1, 16 do
            local position = (blockIndex - 1) * 16 + index
            if position <= #plaintext then
                ciphertext[position] = bxor(plaintext[position], keystream[index])
            end
        end
        if blockIndex < plaintextBlocks then
            incrementCounter(counter)
        end
    end

    local accumulator = {}
    for index = 1, 16 do
        accumulator[index] = 0
    end

    if additionalData then
        local aadBlocks = math.ceil(#additionalData / 16)
        for blockIndex = 1, aadBlocks do
            local block = {}
            for index = 1, 16 do
                local position = (blockIndex - 1) * 16 + index
                block[index] = (position <= #additionalData and additionalData[position]) or 0
            end
            ghashMultiply(hashSubkey, accumulator, block)
        end
    end

    local cipherBlocks = math.ceil(#ciphertext / 16)
    for blockIndex = 1, cipherBlocks do
        local block = {}
        for index = 1, 16 do
            local position = (blockIndex - 1) * 16 + index
            block[index] = (position <= #ciphertext and ciphertext[position]) or 0
        end
        ghashMultiply(hashSubkey, accumulator, block)
    end

    local lengthBlock = {}
    local aadBitLength = (additionalData and #additionalData * 8) or 0
    local cipherBitLength = #ciphertext * 8
    for index = 0, 7 do
        lengthBlock[1 + index] = band(rshift(aadBitLength, (7 - index) * 8), 255)
        lengthBlock[9 + index] = band(rshift(cipherBitLength, (7 - index) * 8), 255)
    end
    ghashMultiply(hashSubkey, accumulator, lengthBlock)

    local tag = encryptBlock(initialCounter, schedule, rounds)
    for index = 1, 16 do
        tag[index] = bxor(tag[index], accumulator[index])
    end

    return ciphertext, tag
end
local function gcmDecrypt(key, iv, ciphertext, tag, additionalData)
    if #key ~= 32 then
        error("Key must be 32 bytes for AES-256")
    end

    local schedule, rounds = expandKey(key)

    local zeroBlock = {}
    for index = 1, 16 do
        zeroBlock[index] = 0
    end
    local hashSubkey = encryptBlock(zeroBlock, schedule, rounds)

    local initialCounter = {}
    if #iv ~= 12 then
        for index = 1, 16 do
            initialCounter[index] = 0
        end

        local ivBlocks = math.ceil(#iv / 16)
        for blockIndex = 1, ivBlocks do
            local block = {}
            for index = 1, 16 do
                local position = (blockIndex - 1) * 16 + index
                block[index] = (position <= #iv and iv[position]) or 0
            end
            ghashMultiply(hashSubkey, initialCounter, block)
        end

        local lengthBlock = {}
        for index = 1, 8 do
            lengthBlock[index] = 0
        end
        local ivBitLength = #iv * 8
        for index = 0, 7 do
            lengthBlock[9 + index] = band(rshift(ivBitLength, (7 - index) * 8), 255)
        end
        ghashMultiply(hashSubkey, initialCounter, lengthBlock)
    else
        for index = 1, 12 do
            initialCounter[index] = iv[index]
        end
        initialCounter[13] = 0
        initialCounter[14] = 0
        initialCounter[15] = 0
        initialCounter[16] = 1
    end

    local accumulator = {}
    for index = 1, 16 do
        accumulator[index] = 0
    end

    if additionalData then
        local aadBlocks = math.ceil(#additionalData / 16)
        for blockIndex = 1, aadBlocks do
            local block = {}
            for index = 1, 16 do
                local position = (blockIndex - 1) * 16 + index
                block[index] = (position <= #additionalData and additionalData[position]) or 0
            end
            ghashMultiply(hashSubkey, accumulator, block)
        end
    end

    local cipherBlocks = math.ceil(#ciphertext / 16)
    for blockIndex = 1, cipherBlocks do
        local block = {}
        for index = 1, 16 do
            local position = (blockIndex - 1) * 16 + index
            block[index] = (position <= #ciphertext and ciphertext[position]) or 0
        end
        ghashMultiply(hashSubkey, accumulator, block)
    end

    local lengthBlock = {}
    local aadBitLength = (additionalData and #additionalData * 8) or 0
    local cipherBitLength = #ciphertext * 8
    for index = 0, 7 do
        lengthBlock[1 + index] = band(rshift(aadBitLength, (7 - index) * 8), 255)
        lengthBlock[9 + index] = band(rshift(cipherBitLength, (7 - index) * 8), 255)
    end
    ghashMultiply(hashSubkey, accumulator, lengthBlock)

    local expectedTag = encryptBlock(initialCounter, schedule, rounds)
    for index = 1, 16 do
        expectedTag[index] = bxor(expectedTag[index], accumulator[index])
    end

    local tagMatches = true
    for index = 1, 16 do
        if expectedTag[index] ~= tag[index] then
            tagMatches = false
            break
        end
    end
    if not tagMatches then
        return nil
    end

    local counter = {}
    for index = 1, 16 do
        counter[index] = initialCounter[index]
    end
    incrementCounter(counter)

    local plaintext = {}
    local plaintextBlocks = math.ceil(#ciphertext / 16)
    for blockIndex = 1, plaintextBlocks do
        local keystream = encryptBlock(counter, schedule, rounds)
        for index = 1, 16 do
            local position = (blockIndex - 1) * 16 + index
            if position <= #ciphertext then
                plaintext[position] = bxor(ciphertext[position], keystream[index])
            end
        end
        if blockIndex < plaintextBlocks then
            incrementCounter(counter)
        end
    end

    return plaintext
end
local aes = Crypto.aes

aes.new = function(...)
    return gcmEncrypt(...)
end

aes.decrypt = function(...)
    return gcmDecrypt(...)
end
local function randomBytes(count)
    local bytes = {}
    local index = 1
    while index <= count do
        bytes[index] = seededRandom()(0, 255)
        index = index + 1
    end
    return bytes
end
local function bytesToString(bytes)
    local characters = {}
    for index = 1, #bytes do
        characters[index] = string.char(bytes[index])
    end
    return table.concat(characters)
end
local RANDOM_STRING_CHARSET = "abcdefghijklmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ123456789"

local function randomString(length)
    local result = ""
    for _ = 1, length do
        local position = seededRandom()(1, 60)
        result = result .. RANDOM_STRING_CHARSET:sub(position, position)
    end
    return result
end
local function stringToBytes(text)
    local bytes = {}
    local index = 1
    while index <= #text do
        bytes[index] = text:byte(index)
        index = index + 1
    end
    return bytes
end
local function newByteCipher(seed)
    local key = band(seed, 255)
    local cipher = {}

    cipher.dec = function(byte)
        return bxor(byte, key)
    end

    cipher.enc = function(byte)
        key = band(bxor(lshift(key, 1), rshift(key, 7)), 255)
        return bxor(byte, key)
    end

    cipher.key = function()
        return key
    end

    return cipher
end
local function timeSeed()
    local now = DateTime.now()
    return math.floor(now.UnixTimestampMillis * 1000000) % 2147483647
end
local function deriveOpcodeTable(seed)
    local opcodes = {}
    local used = {}
    local index = 1
    while index <= 10 do
        local value = (seededRandom()(30, 240) + seed * index) % 251
        if not used[value] then
            opcodes[index] = value
            used[value] = true
            index = index + 1
        end
    end
    return opcodes
end
local function readProgramOperand(program, index, cipher, mask)
    if program[index] then
        local value = cipher.dec(program[index])
        program[index] = cipher.enc(bxor(value, mask))
        return program[index]
    end
    return nil
end
local function runKeyProgram(program, seed)
    local cipher = newByteCipher(seed)
    local opcodes = deriveOpcodeTable(seed)
    local slots = {}
    local counter = 1
    local mask = seed
    local unresolvedSlotValue

    while counter <= #program do
        local opcode = readProgramOperand(program, counter, cipher, mask)
        if not opcode then
            break
        end
        counter = counter + 1

        if opcode == opcodes[1] then
            local target = readProgramOperand(program, counter, cipher, mask)
            local value = readProgramOperand(program, counter + 1, cipher, mask)
            if not target or not value then
                break
            end
            counter = counter + 2
            slots[target] = value
        elseif opcode == opcodes[2] then
            local target = readProgramOperand(program, counter, cipher, mask)
            local source = readProgramOperand(program, counter + 1, cipher, mask)
            if not target or not source then
                break
            end
            counter = counter + 2
            slots[target] = bxor(slots[target] or 0, slots[source] or 0)
        elseif opcode == opcodes[3] then
            mask = bxor(mask, cipher.key())
            opcodes = deriveOpcodeTable(mask)
        elseif opcode == opcodes[4] then
            local target = readProgramOperand(program, counter, cipher, mask)
            local source = readProgramOperand(program, counter + 1, cipher, mask)
            if not target or not source then
                break
            end
            counter = counter + 2
            if not slots[1] or not slots[2] or not slots[3] or not slots[4] then
                break
            end
            slots[5], slots[6] = Crypto.aes.new(slots[1], slots[2], slots[3], slots[4])
        elseif opcode == opcodes[5] then
            if not slots[1] or not slots[2] or not slots[3] or not slots[6] or not slots[4] then
                break
            end
            slots[5], slots[6] = Crypto.aes.decrypt(slots[1], slots[2], slots[3], slots[6], slots[4])
        elseif opcode == opcodes[6] then
            local target = readProgramOperand(program, counter, cipher, mask)
            local source = readProgramOperand(program, counter + 1, cipher, mask)
            if not target or not source then
                break
            end
            counter = counter + 2
            slots[target] = slots[source]
        elseif opcode == opcodes[7] then
            opcodes = deriveOpcodeTable(bxor(mask, opcode))
            mask = bxor(mask, opcode * 131)
        elseif opcode == opcodes[8] then
            local random = seededRandom()
            if mask % 7 == 0 then
                slots[random(1, 12)] = unresolvedSlotValue
            end
        elseif opcode == opcodes[9] then
            local target = readProgramOperand(program, counter, cipher, mask)
            if not target then
                break
            end
            counter = counter + 1
            slots[target] = randomBytes(32)
        elseif opcode == opcodes[10] then
            local source = readProgramOperand(program, counter, cipher, mask)
            if source then
                counter = counter + 1
            end
            return slots[source]
        end
    end

    return nil
end
local function encodeKeyProgram(seed, source)
    local opcodes = deriveOpcodeTable(seed)
    local cipher = newByteCipher(seed)
    local encoded = {}
    local writeIndex = 1
    local readIndex = 1

    while readIndex <= #source do
        local opcodeIndex = source[readIndex]
        encoded[writeIndex] = cipher.enc(opcodes[opcodeIndex])
        writeIndex = writeIndex + 1
        readIndex = readIndex + 1

        if opcodeIndex == 9 or opcodeIndex == 10 then
            encoded[writeIndex] = cipher.enc(source[readIndex])
            writeIndex = writeIndex + 1
            readIndex = readIndex + 1
        elseif opcodeIndex ~= 3 and opcodeIndex ~= 7 and opcodeIndex ~= 8 then
            encoded[writeIndex] = cipher.enc(source[readIndex])
            encoded[writeIndex + 1] = cipher.enc(source[readIndex + 1])
            writeIndex = writeIndex + 2
            readIndex = readIndex + 2
        end
    end

    return encoded
end
local function encryptPayload(plaintext, additionalData)
    local seed = timeSeed()
    local program = encodeKeyProgram(seed, KEY_PROGRAM_SOURCE)

    local sessionKey = runKeyProgram(program, seed)
    if not sessionKey then
        sessionKey = randomBytes(32)
    elseif #sessionKey ~= 32 then
        sessionKey = randomBytes(32)
    end

    local iv = randomBytes(12)
    local aadBytes = additionalData
    if additionalData then
        aadBytes = stringToBytes(additionalData)
    end
    local ciphertext, tag = Crypto.aes.new(sessionKey, iv, stringToBytes(plaintext), aadBytes)

    local masterKey = randomBytes(32)
    local keyIv = randomBytes(12)
    local wrappedKey, keyTag = Crypto.aes.new(masterKey, keyIv, sessionKey, nil)

    local payload = {}
    payload.yea = "have fun decrypting this my guy"
    payload.ciphertext = ciphertext
    payload.tag = tag
    payload.wrappedkey = wrappedKey
    payload.keytag = keyTag
    payload.keyiv = keyIv
    payload.masterkey = masterKey
    return payload
end
local function decryptPayload(envelope)
    local additionalData

    if not envelope.masterkey then
        return
    end

    local sessionKey, keyError = Crypto.aes.decrypt(envelope.masterkey, envelope.wrappedkey, envelope.keyiv, envelope.keytag, nil)
    if not sessionKey then
        return nil, keyError or "unknown error"
    end

    if additionalData then
        additionalData = stringToBytes(additionalData)
    end

    local plainBytes, plainError = Crypto.aes.decrypt(sessionKey, envelope.ciphertext, envelope.iv, envelope.tag, additionalData)
    if not plainBytes then
        return nil, plainError
    end

    local plaintext = bytesToString(plainBytes)
    local decoded = jsonDecode(plaintext)

    if decoded.time and 15 < absOf(DateTime.now().UnixTimestamp - decoded.time) then
        return
    end

    return plaintext
end
local function buildRequestBody(payload)
    local envelope = encryptPayload(jsonEncode({data = payload, time = DateTime.now().UnixTimestamp}, false, 0))

    local body = {hoodauth = "focat what ME?"}
    body.yea = envelope.yea

    for field, aliases in next, PAYLOAD_FIELD_ALIASES do
        for _, alias in next, aliases do
            body[alias] = envelope[field]
        end
    end

    for _ = 1, seededRandom()(6, 9) do
        body[randomString(1)] = randomBytes(seededRandom()(8, 22))
    end

    for _ = 1, seededRandom()(12, 17) do
        body[randomString(4)] = DECOY_STRINGS[seededRandom()(1, #DECOY_STRINGS)]
    end

    return body
end
local function unpackResponseBody(body)
    if type(body) == "string" then
        body = jsonDecode(body)
    end

    local envelope = {}

    for key, value in next, body do
        for field, aliases in next, PAYLOAD_FIELD_ALIASES do
            if indexOfValue(aliases, key) then
                envelope[field] = value
            end
        end
    end

    return envelope
end
local function authenticate()
    local nonce = randomString(10) .. "-" .. randomString(6) .. "-" .. randomString(6) .. "-" .. randomString(14)

    local hwidResponse = request({
        Url = "https://api.catvape.dev/gethwid",
        Method = "POST",
        Body = jsonEncode({response = buildRequestBody(jsonEncode({nonce = nonce}, false, 0))}, false, 0)
    })

    if hwidResponse.StatusCode ~= 200 then
        notify("Cat", "Failed to grab hwid.", 20, "alert")
        return
    end

    local hwidPayload = jsonDecode(decryptPayload(unpackResponseBody(jsonDecode(hwidResponse.Body, false, 0).response)))

    if not hwidPayload.success then
        notify("Cat", "Couldn't process login request.", 20, "alert")
        return
    end

    if hwidPayload.nonce ~= nonce then
        notify("Cat", "Couldn't process login request.", 20, "alert")
        return
    end

    local teleportData = teleportService:GetLocalPlayerTeleportData() or {}
    local startedAt = DateTime.now().UnixTimestampMillis
    local executorName, executorVersion = identifyexecutor()
    local players = game:GetService("Players")
    local player = players.LocalPlayer

    nonce = randomString(8) .. randomString(4) .. randomString(4) .. randomString(12)

    local loginResponse = request({
        Url = "https://api.catvape.dev/login",
        Method = "POST",
        Body = jsonEncode({
            response = buildRequestBody(jsonEncode({
                key = (userConfig and userConfig.Key) or "_key",
                nonce = nonce,
                executor = ("%*%*"):format(executorName, (executorVersion and " " .. executorVersion) or "")
            }, false, 0))
        }, false, 0)
    })

    local socket

    local socketThread = task.spawn(function()
        while true do
            local closed = false

            socket = WebSocket.connect("wss://api.catvape.dev/usercount")
            socket.OnClose:Connect(function()
                closed = false
            end)

            local handshake = {}
            handshake.hash = vape.Libraries.whitelist.hashes[player.Name .. toStringValue(player.UserId)]

            local matchId = teleportData and teleportData.match
            if matchId then
                matchId = teleportData.match.matchId
            end
            handshake.key = vape.Libraries.hash.sha512(matchId or game.JobId)

            socket:Send(jsonEncode({
                type = "ping",
                data = buildRequestBody(jsonEncode(handshake, false, 0))
            }, false, 0))

            debugPrint("connected to ws")

            local lastPing = os.clock()

            while true do
                if 20 <= os.clock() - lastPing then
                    socket:Send(jsonEncode({type = "ping"}, false, 0))
                    lastPing = os.clock()
                end

                task.wait()

                if closed or vape.Loaded == nil then
                    break
                end
            end

            socket = nil

            if vape.Loaded == nil then
                break
            end

            task.wait(2)

            if vape.Loaded == nil then
                break
            end
        end
    end)

    vape:Clean(function()
        if socket then
            socket:Close()
            socket = nil
        end
        task.cancel(socketThread)
    end)

    if loginResponse.StatusCode == 200 then
        local payload = jsonDecode(decryptPayload(unpackResponseBody(jsonDecode(loginResponse.Body).response)))

        if payload and typeof(payload) == "table" and payload.success then
            if payload.nonce ~= nonce then
                notify("Cat", "We couldn't process ur premium request.", 20, "alert")
            else
                debugPrint("Authenticated in", (DateTime.now().UnixTimestampMillis - startedAt) / 1000 .. "s")

                local role = payload.role
                getSharedState().catrole = role:sub(0, 1):upper() .. role:sub(2, #role)
                getSharedState().catname = payload.discord_username

                if role == "paid" and vape.Place == 6872274481 then
                    isPaidUser = false
                end

                authFinished = false
            end
        end
    elseif loginResponse.StatusCode == 400 then
        for _, message in jsonDecode(loginResponse.Body).errors[1] do
            if not message:find("using a key") then
                notify("Cat", "Authentication error: " .. message, 20, "alert")
                task.spawn(function()
                    error(message, 8)
                end)
            end
        end
    elseif loginResponse.StatusCode == 404 then
        local body = jsonDecode(loginResponse.Body, nil)

        if typeof(body) == "table" then
            local firstError = body.errors[1]

            if firstError.HWID_MISMATCH then
                getSharedState().catrole = "HWID MISMATCH"
            elseif firstError.umightbeblacklisted then
                for _, module in vape.Modules do
                    pcall(vape.Remove, vape, module)
                end

                player:Kick("you may be blacklisted from cv")
                return
            end
        end
    end
end
local function getAuraWeapon()
    if not entity.isAlive then
        return
    end

    if mouseDownToggle.Enabled and not UserInputService:IsMouseButtonPressed(0) and 0.3 < tick() - bedwars.SwordController.lastSwing then
        return
    end

    if swingOnlyToggle.Enabled and 0.3 < tick() - bedwars.SwordController.lastSwing then
        return
    end

    local stunnedUntil = localPlayer.Character:GetAttribute("StunnedUntilTime") or 0
    if 0 < stunnedUntil - workspace:GetServerTimeNow() then
        return
    end

    if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
        return
    end

    local slot = limitToItemsToggle.Enabled and store.hand
    if not slot then
        slot = store.tools.sword
    end

    if not slot or not slot.tool then
        return
    end

    local itemMeta = bedwars.ItemMeta[slot.tool.Name]

    if not limitToItemsToggle.Enabled then
        return slot, itemMeta
    end

    if store.hand.toolType == "sword" and not bedwars.DaoController.chargingMaid then
        return slot, itemMeta
    end
end
local function getDynamicHitDelay(target, itemMeta)
    local delay = ((itemMeta.displayName:find(" Chainsaw") and 0.11) or 0.29) + 0.03

    if dynamicHitsToggle.Enabled then
        local distance = math.min(14.4, (entity.character.RootPart.Position - target.RootPart.Position).Magnitude)
        return delay * distance / 14.4
    end

    return delay
end
local function getAuraAimPoint(target)
    if targetAreaDropdown.Value ~= "Closest" then
        return target.RootPart.Position
    end

    if not characterPartCache[target.Character] then
        characterPartCache[target.Character] = target.Character:GetChildren()
    end

    local mouseLocation = UserInputService:GetMouseLocation()
    local closestDistance = 9000000000
    local closestPart = nil

    for _, part in characterPartCache[target.Character] do
        if part and part.Parent and part:IsA("BasePart") then
            local screenPoint, onScreen = currentCamera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (mouseLocation - Vector2.new(screenPoint.x, screenPoint.y)).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestPart = part
                end
            end
        end
    end

    if not closestPart then
        return target.RootPart.Position
    end

    return closestPart.Position
end
local function easeInOutCubic(alpha)
    if alpha < 0.5 then
        return 4 * alpha * alpha * alpha
    end

    return 1 - math.pow(-2 * alpha + 2, 3) / 2
end
local function getAuraCameraCFrame(cameraCFrame, target, deltaTime, aimStartTime)
    local progress = easeInOutCubic(math.min((tick() - aimStartTime) / (1 / (aimSpeedSlider.Value * 0.5)), 1))
    local generator = Random.new()
    local aimRate = aimSpeedSlider.Value * progress

    local jitter = Vector3.new(
        (generator:NextNumber() - 0.5) * 15 * deltaTime,
        (generator:NextNumber() - 0.5) * 15 * deltaTime,
        (generator:NextNumber() - 0.5) * 15 * deltaTime
    )

    local goal = CFrame.lookAt(cameraCFrame.p, getAuraAimPoint(target) + jitter)

    return cameraCFrame:Lerp(goal, aimRate * deltaTime), aimRate
end
local function runSilentAura(enabled)
    if not enabled then
        entity.character.Humanoid.AutoRotate = false
        targetAdornment.Adornee = nil
        return
    end

    local aimTarget = nil
    local lastTargetTime = 0
    local aimStartTime = tick()
    local lastAttackVisualTime = tick()

    silentAura:Clean(RunService.PostSimulation:Connect(function(deltaTime)
        if not entity.isAlive or not aimTarget then
            if entity.isAlive then
                entity.character.Humanoid.AutoRotate = false
            end
            return
        end

        if not aimTarget.RootPart or not aimTarget.RootPart.Parent or not (tick() - lastTargetTime < 0.5) then
            if entity.isAlive then
                entity.character.Humanoid.AutoRotate = false
            end
            return
        end

        targetinfo.Targets[aimTarget] = tick() + 0.5
        entity.character.Humanoid.AutoRotate = not silentAimToggle.Enabled

        local aimedCFrame, aimRate = getAuraCameraCFrame(workspace.CurrentCamera.CFrame, aimTarget, deltaTime, aimStartTime)
        if not silentAimToggle.Enabled then
            workspace.CurrentCamera.CFrame = aimedCFrame
        else
            local rootPart = entity.character.RootPart
            local targetRoot = aimTarget.RootPart
            local flatDirection = Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z - rootPart.Position.Z)
            if flatDirection.Magnitude > 0 then
                rootPart.CFrame = rootPart.CFrame:Lerp(
                    CFrame.lookAlong(rootPart.Position, flatDirection),
                    math.clamp((aimRate + 2) * deltaTime, 0, 1)
                )
            end
        end
    end))

    local lastAttackTime = 0
    local swingCounter = 9000000000

    repeat
        task.wait()

        local heldItem, itemMeta = getAuraWeapon()
        if not heldItem then
            targetAdornment.Adornee = nil
            lastTargetTime = 0
            swingCounter = 0
        else
            local origin = entity.character.RootPart.Position

            local query = {Origin = origin}
            query.Range = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE + extraSwingDistanceSlider.Value
            query.Wallcheck = auraTargets.Walls.Enabled or nil
            query.Part = "RootPart"
            query.Players = auraTargets.Players.Enabled
            query.NPCs = auraTargets.NPCs.Enabled
            query.Limit = 1
            query.Sort = sortFunctions[targetModeDropdown.Value or "Distance"]

            local target = entity.EntityPosition(query)

            local activeColor = (tick() - lastAttackVisualTime < 0.1 and attackColorSlider) or targetColorSlider
            targetAdornment.Adornee = (showTargetToggle.Enabled and target and target.RootPart) or nil
            targetAdornment.Transparency = 1 - activeColor.Opacity
            targetAdornment.Color3 = Color3.fromHSV(activeColor.Hue, activeColor.Sat, activeColor.Value)

            if not target then
                lastTargetTime = 0
                swingCounter = 0
            else
                local hand = store.hand
                if not hand or hand.tool ~= heldItem.tool then
                    local slot = findItemForTool(heldItem.tool)
                    if slot then
                        equipItem(slot)
                    end
                end

                hand = store.hand
                if hand and hand.tool == heldItem.tool then
                    if 50 < swingCounter then
                        swingCounter = 0
                    end
                    swingCounter = swingCounter + 1

                    local aimSource = (UserInputService.KeyboardEnabled and workspace.CurrentCamera) or entity.character.RootPart
                    local lookDirection = aimSource.CFrame.LookVector * Vector3.new(1, 0, 1)
                    local toTarget = target.RootPart.Position - origin
                    local flatToTarget = (target.RootPart.Position - origin) * Vector3.new(1, 0, 1)

                    local facing
                    if flatToTarget.Magnitude > 0 and lookDirection.Magnitude > 0 then
                        facing = (lookDirection / lookDirection.Magnitude):Dot(flatToTarget / flatToTarget.Magnitude)
                    end
                    facing = facing or 0

                    if not (facing < math.cos(math.rad(maxAngleSlider.Value) / 2)) then
                        if not swingOnlyToggle.Enabled then
                            local sinceSwing = tick() - bedwars.SwordController.lastSwing
                            local swingDelay
                            if perfectSwingToggle.Enabled then
                                swingDelay = itemMeta.sword.attackSpeed or 0.11
                            end
                            if not swingDelay then
                                swingDelay = math.max(swingTimeSlider.Value, 0.11)
                            end
                            if swingDelay <= sinceSwing then
                                bedwars.SwordController:playSwordEffect(itemMeta, false)
                                bedwars.SwordController.lastSwing = tick()
                            end
                        end

                        aimTarget = target
                        lastTargetTime = tick()

                        if not (bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE < toTarget.Magnitude) then
                            lastAttackVisualTime = tick()

                            local readyToHit
                            if dynamicHitsToggle.Enabled then
                                readyToHit = tick() - lastAttackTime >= getDynamicHitDelay(target, itemMeta)
                            end
                            if not readyToHit then
                                readyToHit = bedwars.SwordController:getRemainingSwingCooldown(heldItem.tool.Name) <= 0
                            end

                            if readyToHit then
                                local cursorDirection = CFrame.lookAt(origin, target.RootPart.Position).LookVector
                                local selfPosition = origin + cursorDirection * math.max(toTarget.Magnitude - 14.4, 0)

                                bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                                lastAttackTime = tick()

                                bedwars.Handler:Get("SwordHit"):Fire("SendToServer", {
                                    weapon = heldItem.tool,
                                    chargedAttack = {chargeRatio = 0},
                                    entityInstance = target.Character,
                                    validate = {
                                        raycast = {
                                            cameraPosition = {value = workspace.CurrentCamera.CFrame.Position},
                                            cursorDirection = {value = cursorDirection},
                                        },
                                        targetPosition = {value = target.Character:GetPivot().Position},
                                        selfPosition = {value = selfPosition},
                                    },
                                })
                            end
                        end
                    end
                end
            end
        end
    until not silentAura.Enabled
end
local function getKillauraWeapon()
    if killauraRequireMouseDownToggle.Enabled and not UserInputService:IsMouseButtonPressed(0) then
        return
    end

    if killauraGuiCheckToggle.Enabled and bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
        return
    end

    if killauraAttackableCheckToggle.Enabled then
        if not entity.isAlive then
            return
        end
        if workspace:GetServerTimeNow() < (localPlayer.Character:GetAttribute("StunnedUntilTime") or 0) then
            return
        end
        if localPlayer.Character:FindFirstChild("elk") then
            return
        end
        if bedwars.StatusEffectUtil:isActive(localPlayer.Character, "frozen") then
            return
        end
    end

    local held = (killauraLimitToItemsToggle.Enabled and store.hand) or store.tools.sword
    if not held or not held.tool then
        return
    end

    local itemMeta = bedwars.ItemMeta[held.tool.Name]

    if killauraLimitToItemsToggle.Enabled then
        local hand = store.hand
        if hand.toolType ~= "sword" or bedwars.DaoController.chargingMaid then
            return held, itemMeta
        end
    end

    local manualSwing = killauraSwingOnlyToggle.Enabled and 0.2 < tick() - bedwars.SwordController.lastSwing
    return held, itemMeta, not manualSwing
end
local function findAmmoForProjectile(projectileSource)
    for _, item in store.inventory.inventory.items do
        if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, item.itemType) then
            return item.itemType
        end
    end
end
local function collectProjectileLaunchers()
    local launchers = {}

    for _, item in store.inventory.inventory.items do
        local meta = bedwars.ItemMeta[item.itemType]
        local projectileSource = meta and meta.projectileSource

        local ammoType = projectileSource
        if projectileSource then
            ammoType = findAmmoForProjectile(projectileSource)
        end

        if ammoType then
            local enabledList = killauraProjectilesList.ListEnabled
            if table.find(enabledList, ammoType)
                or table.find(enabledList, item.itemType)
                or table.find(enabledList, meta.displayName) then
                table.insert(launchers, {
                    item,
                    ammoType,
                    projectileSource.projectileType(ammoType),
                    projectileSource,
                })
            end
        end
    end

    return launchers
end
local function sampleTargetMotion(targetEntity, part)
    local now = tick()
    local velocity = part.AssemblyLinearVelocity
    local lastSample = targetEntity.KillauraSample
    local acceleration = Vector3.zero

    if lastSample then
        local elapsed = now - lastSample.Time
        if 0.004 < elapsed and elapsed < 0.4 then
            acceleration = (velocity - lastSample.Velocity) / elapsed
            if 320 < acceleration.Magnitude then
                acceleration = acceleration.Unit * 320
            end
        end
    end

    targetEntity.KillauraSample = {Time = now, Velocity = velocity}
    return velocity, acceleration
end
local function predictHitPoint(targetEntity, part, aimPoint)
    local velocity, acceleration = sampleTargetMotion(targetEntity, part)
    local lead = math.clamp(store.ping.total or 0, 0, 0.4)

    local predictedPosition = part.Position + velocity * lead + acceleration * (0.5 * lead * lead)
    local predictedCFrame = part.CFrame + (predictedPosition - part.Position)
    local halfSize = part.Size * 0.5
    local localPoint = predictedCFrame:PointToObjectSpace(aimPoint)

    return predictedCFrame * Vector3.new(
        math.clamp(localPoint.X, -halfSize.X, halfSize.X),
        math.clamp(localPoint.Y, -halfSize.Y, halfSize.Y),
        math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
    )
end
local function setupKillaura()
    local killaura
    local targets
    local targetModeDropdown
    local fastHitsToggle
    local swingRangeSlider
    local attackRangeSlider
    local maxAngleSlider
    local hitChanceSlider
    local swingTimeSlider
    local attackSpeedSlider
    local maxTargetsSlider
    local requireMouseDownToggle
    local attackableCheckToggle
    local noSwingToggle
    local guiCheckToggle
    local targetColorSlider
    local attackColorSlider
    local boxAnimationDropdown
    local startAnimationSpeedSlider
    local endAnimationSpeedSlider
    local textureBox
    local colorBeginSlider
    local colorEndSlider
    local particleSizeSlider
    local faceTargetToggle
    local customAnimationToggle
    local animationModeDropdown
    local animationSpeedSlider
    local noTweenToggle
    local limitToItemsToggle
    local swingOnlyToggle
    local projectilesList
    local legitSwitchToggle
    local fireRateSlider
    local particleParts = {}
    local targetBoxes = {}
    local auraAnims = vape.Libraries.auraanims
    local currentTween
    local defaultWristC0

    local function runCustomAnimation()
        local resetWrist = false
        while true do
            if not killauraAnimating then
                if resetWrist then
                    resetWrist = false
                    currentTween = TweenService:Create(
                        currentCamera.Viewmodel.RightHand.RightWrist,
                        TweenInfo.new(noTweenToggle.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential),
                        {C0 = defaultWristC0}
                    )
                    currentTween:Play()
                end
            else
                if not defaultWristC0 then
                    defaultWristC0 = currentCamera.Viewmodel.RightHand.RightWrist.C0
                end
                local snapToPose = not resetWrist
                resetWrist = false
                if animationModeDropdown.Value == "Random" then
                    auraAnims.Random = {
                        {
                            CFrame = CFrame.Angles(
                                math.rad(math.random(1, 360)),
                                math.rad(math.random(1, 360)),
                                math.rad(math.random(1, 360))
                            ),
                            Time = 0.12,
                        },
                    }
                end
                for _, pose in auraAnims[animationModeDropdown.Value] do
                    local duration
                    if snapToPose then
                        duration = noTweenToggle.Enabled and 0.001 or 0.1
                    end
                    if not duration then
                        duration = pose.Time / animationSpeedSlider.Value
                    end
                    currentTween = TweenService:Create(
                        currentCamera.Viewmodel.RightHand.RightWrist,
                        TweenInfo.new(duration, Enum.EasingStyle.Linear),
                        {C0 = defaultWristC0 * pose.CFrame}
                    )
                    currentTween:Play()
                    currentTween.Completed:Wait()
                    snapToPose = false
                    if not killaura.Enabled then
                        break
                    end
                end
            end
            if not resetWrist then
                task.wait()
            end
            if not (killaura.Enabled and customAnimationToggle.Enabled) then
                break
            end
        end
    end

    local function onKillauraToggled(enabled)
        if not enabled then
            store.KillauraTarget = nil
            for _, box in targetBoxes do
                box.Adornee = nil
                box.Size = Vector3.zero
            end
            for _, part in particleParts do
                part.Parent = nil
            end
            debug.setupvalue(originalPlaySwordEffect or bedwars.SwordController.playSwordEffect, 7, bedwars.Knit)
            debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
            killauraAnimating = false
            if defaultWristC0 then
                currentTween = TweenService:Create(
                    currentCamera.Viewmodel.RightHand.RightWrist,
                    TweenInfo.new(noTweenToggle.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential),
                    {C0 = defaultWristC0}
                )
                currentTween:Play()
            end
        elseif customAnimationToggle.Enabled then
            local executor = identifyexecutor and identifyexecutor()
            if not executor or not table.find({"Argon", "Delta"}, executor) then
                local viewmodelHook = {
                    Controllers = {
                        ViewmodelController = {
                            isVisible = function() end,
                            playAnimation = function() end,
                        },
                    },
                }
                debug.setupvalue(originalPlaySwordEffect or bedwars.SwordController.playSwordEffect, 7, viewmodelHook)
                debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, viewmodelHook)
                task.spawn(runCustomAnimation)
            end
        end
    end

    killaura = vape.Categories.Blatant:CreateModule({
        Name = "Killaura",
        Function = onKillauraToggled,
        Tooltip = "Attack players around you\nwithout aiming at them.",
    })

    targets = killaura:CreateTargets({Players = false, NPCs = false})

    local targetModes = {"Damage", "Distance"}

    swingRangeSlider = killaura:CreateSlider({
        Name = "Swing range",
        Min = 1,
        Max = 28,
        Default = 28,
        Suffix = function(value)
            return value == 1 and "stud" or "studs"
        end,
    })

    attackRangeSlider = killaura:CreateSlider({
        Name = "Attack range",
        Min = 1,
        Max = 20,
        Default = 20,
        Suffix = function(value)
            return value == 1 and "stud" or "studs"
        end,
    })

    maxAngleSlider = killaura:CreateSlider({
        Name = "Max angle",
        Min = 1,
        Max = 360,
        Default = 360,
    })

    hitChanceSlider = killaura:CreateSlider({
        Name = "Hit chance",
        Min = 1,
        Max = 100,
        Default = 100,
        Suffix = "%",
    })

    swingTimeSlider = killaura:CreateSlider({
        Name = "Swing time",
        Min = 0.11,
        Max = 2,
        Decimal = 100,
        Default = 0.11,
        Suffix = function(value)
            return value == 1 and "second" or "seconds"
        end,
    })

    attackSpeedSlider = killaura:CreateSlider({
        Name = "Attack speed",
        Min = 0,
        Max = 1,
        Decimal = 100,
        Default = 0,
        Suffix = function(value)
            return value == 1 and "second" or "seconds"
        end,
    })

    maxTargetsSlider = killaura:CreateSlider({
        Name = "Max targets",
        Min = 1,
        Max = 5,
        Default = 5,
    })

    targetModeDropdown = killaura:CreateDropdown({
        Name = "Target Mode",
        List = targetModes,
    })

    fastHitsToggle = killaura:CreateToggle({
        Name = "Fast Hits",
        Default = false,
        Function = function(enabled)
            pcall(function()
                projectilesList.Object.Visible = enabled
                legitSwitchToggle.Object.Visible = enabled
                fireRateSlider.Object.Visible = enabled
            end)
        end,
        Tooltip = "Deals more damage quicker using projectiles",
    })

    projectilesList = killaura:CreateTextList({
        Name = "Projectiles",
        Default = {"arrow", "snowball"},
        Darker = false,
        Visible = false,
        Tooltip = "Projectiles to use for fasthits",
    })

    legitSwitchToggle = killaura:CreateToggle({
        Name = "Legit Switch",
        Darker = false,
        Visible = false,
    })

    fireRateSlider = killaura:CreateSlider({
        Name = "Fire rate",
        Suffix = "seconds",
        Min = 0,
        Max = 2,
        Decimal = 100,
        Darker = false,
        Visible = false,
        Default = 0.05,
    })

    requireMouseDownToggle = killaura:CreateToggle({Name = "Require mouse down"})
    attackableCheckToggle = killaura:CreateToggle({Name = "Attackable check"})
    noSwingToggle = killaura:CreateToggle({Name = "No Swing"})
    guiCheckToggle = killaura:CreateToggle({Name = "GUI check"})

    killaura:CreateToggle({
        Name = "Show target",
        Function = function(enabled)
            targetColorSlider.Object.Visible = enabled
            attackColorSlider.Object.Visible = enabled
            boxAnimationDropdown.Object.Visible = enabled
            startAnimationSpeedSlider.Object.Visible = enabled
            endAnimationSpeedSlider.Object.Visible = enabled
            if not enabled then
                for _, box in targetBoxes do
                    box:Destroy()
                end
                table.clear(targetBoxes)
            else
                for i = 1, 10 do
                    local box = Instance.new("BoxHandleAdornment")
                    box.Adornee = nil
                    box.AlwaysOnTop = false
                    box.Size = Vector3.zero
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    targetBoxes[i] = box
                end
            end
        end,
    })

    local boxAnimationModes = {"Bounce"}
    for _, easingStyle in Enum.EasingStyle:GetEnumItems() do
        if not table.find(boxAnimationModes, easingStyle.Name) then
            table.insert(boxAnimationModes, easingStyle.Name)
        end
    end

    boxAnimationDropdown = killaura:CreateDropdown({
        Name = "Box Animation",
        List = boxAnimationModes,
        Darker = false,
        Visible = false,
    })

    startAnimationSpeedSlider = killaura:CreateSlider({
        Name = "Start Animation Speed",
        Min = 0,
        Max = 10,
        Default = 0.9,
        Decimal = 30,
        Darker = false,
        Visible = false,
    })

    endAnimationSpeedSlider = killaura:CreateSlider({
        Name = "End Animation Speed",
        Min = 0,
        Max = 10,
        Default = 1.4,
        Decimal = 30,
        Darker = false,
        Visible = false,
    })

    targetColorSlider = killaura:CreateColorSlider({
        Name = "Target Color",
        Darker = false,
        DefaultHue = 0.6,
        DefaultOpacity = 0.5,
        Visible = false,
    })

    attackColorSlider = killaura:CreateColorSlider({
        Name = "Attack Color",
        Darker = false,
        DefaultOpacity = 0.5,
        Visible = false,
    })

    killaura:CreateToggle({
        Name = "Target particles",
        Function = function(enabled)
            textureBox.Object.Visible = enabled
            colorBeginSlider.Object.Visible = enabled
            colorEndSlider.Object.Visible = enabled
            particleSizeSlider.Object.Visible = enabled
            if not enabled then
                for _, part in particleParts do
                    part:Destroy()
                end
                table.clear(particleParts)
            else
                for i = 1, 10 do
                    local part = Instance.new("Part")
                    part.Size = Vector3.new(2, 4, 2)
                    part.Anchored = false
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CanQuery = false
                    part.Parent = killaura.Enabled and currentCamera or nil

                    local emitter = Instance.new("ParticleEmitter")
                    emitter.Brightness = 1.5
                    emitter.Size = NumberSequence.new(particleSizeSlider.Value)
                    emitter.Shape = Enum.ParticleEmitterShape.Sphere
                    emitter.Texture = textureBox.Value
                    emitter.Transparency = NumberSequence.new(0)
                    emitter.Lifetime = NumberRange.new(0.4)
                    emitter.Speed = NumberRange.new(16)
                    emitter.Rate = 128
                    emitter.Drag = 16
                    emitter.ShapePartial = 1
                    emitter.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(
                            colorBeginSlider.Hue,
                            colorBeginSlider.Sat,
                            colorBeginSlider.Value
                        )),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(
                            colorEndSlider.Hue,
                            colorEndSlider.Sat,
                            colorEndSlider.Value
                        )),
                    })
                    emitter.Parent = part

                    particleParts[i] = part
                end
            end
        end,
    })

    textureBox = killaura:CreateTextBox({
        Name = "Texture",
        Default = "rbxassetid://14736249347",
        Function = function()
            for _, part in particleParts do
                part.ParticleEmitter.Texture = textureBox.Value
            end
        end,
        Darker = false,
        Visible = false,
    })

    colorBeginSlider = killaura:CreateColorSlider({
        Name = "Color Begin",
        Function = function(hue, sat, value)
            for _, part in particleParts do
                part.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, value)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(
                        colorEndSlider.Hue,
                        colorEndSlider.Sat,
                        colorEndSlider.Value
                    )),
                })
            end
        end,
        Darker = false,
        Visible = false,
    })

    colorEndSlider = killaura:CreateColorSlider({
        Name = "Color End",
        Function = function(hue, sat, value)
            for _, part in particleParts do
                part.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(
                        colorBeginSlider.Hue,
                        colorBeginSlider.Sat,
                        colorBeginSlider.Value
                    )),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, value)),
                })
            end
        end,
        Darker = false,
        Visible = false,
    })

    particleSizeSlider = killaura:CreateSlider({
        Name = "Size",
        Min = 0,
        Max = 1,
        Default = 0.2,
        Decimal = 100,
        Function = function(value)
            for _, part in particleParts do
                part.ParticleEmitter.Size = NumberSequence.new(value)
            end
        end,
        Darker = false,
        Visible = false,
    })

    faceTargetToggle = killaura:CreateToggle({Name = "Face target"})

    customAnimationToggle = killaura:CreateToggle({
        Name = "Custom Animation",
        Function = function(enabled)
            animationModeDropdown.Object.Visible = enabled
            noTweenToggle.Object.Visible = enabled
            animationSpeedSlider.Object.Visible = enabled
            if killaura.Enabled then
                killaura:Toggle()
                killaura:Toggle()
            end
        end,
    })

    local animationModes = {}
    for animationName in auraAnims do
        table.insert(animationModes, animationName)
    end

    animationModeDropdown = killaura:CreateDropdown({
        Name = "Animation Mode",
        List = animationModes,
        Darker = false,
        Visible = false,
    })

    animationSpeedSlider = killaura:CreateSlider({
        Name = "Animation Speed",
        Min = 0,
        Max = 2,
        Default = 1,
        Decimal = 10,
        Darker = false,
        Visible = false,
    })

    noTweenToggle = killaura:CreateToggle({
        Name = "No Tween",
        Darker = false,
        Visible = false,
    })

    limitToItemsToggle = killaura:CreateToggle({
        Name = "Limit to items",
        Function = function(enabled)
            if UserInputService.TouchEnabled and killaura.Enabled then
                pcall(function()
                    localPlayer.PlayerGui.MobileUI["2"].Visible = enabled
                end)
            end
        end,
        Tooltip = "Only attacks when the sword is held",
    })

    swingOnlyToggle = killaura:CreateToggle({
        Name = "Swing only",
        Tooltip = "Only attacks while swinging manually",
    })
end
local function setupSkinChanger()
    local skinChanger
    local skinDropdowns = {}
    local itemKinds = {
        {Name = "Pickaxe", Match = "pickaxe$"},
        {Name = "Axe", Match = "axe$"},
        {Name = "Crossbow", Match = "crossbow$"},
        {Name = "Bow", Match = "bow$"},
        {Name = "Headhunter", Match = "headhunter$"},
        {Name = "Sword", Match = "sword$"},
        {Name = "Dao", Match = "dao$"},
        {Name = "Harpoon", Match = "harpoon$"},
        {Name = "Lasso", Match = "lasso$"},
        {Name = "Staff", Match = "staff"},
    }
    local skinsByKind = {}
    local skinTagsByDisplayName = {}

    local function prettifyName(text)
        return (text:gsub("_", " "):gsub("%a+", function(word)
            return word:sub(1, 1):upper() .. word:sub(2)
        end))
    end

    local function getItemKind(itemType)
        for _, kind in itemKinds do
            if itemType:find(kind.Match) then
                return kind.Name
            end
        end
        return nil
    end

    for _, skinType in bedwars.ItemSkinType do
        local skinMeta = bedwars.getItemSkinMeta(skinType)
        local kind = skinMeta and skinMeta.itemType
        if kind then
            kind = getItemKind(skinMeta.itemType)
        end
        if kind then
            local skinTag = tostring(skinMeta.skinTag)
            skinsByKind[kind] = skinsByKind[kind] or {}
            skinsByKind[kind][skinTag] = skinsByKind[kind][skinTag] or {}
            skinsByKind[kind][skinTag][skinMeta.itemType] = skinType
            skinTagsByDisplayName[kind] = skinTagsByDisplayName[kind] or {}
            skinTagsByDisplayName[kind][prettifyName(skinTag)] = skinTag
        end
    end

    local function getSelectedSkin(itemType)
        local kind = skinChanger.Enabled and getItemKind(itemType)
        local skinTag = kind
        if kind then
            skinTag = skinTagsByDisplayName[kind][skinDropdowns[kind].Value]
        end
        local skinType = skinTag
        if skinTag then
            skinType = skinsByKind[kind][skinTag][itemType]
        end
        return skinType
    end

    local function applySkins()
        local inventory = store.inventory.inventory
        for _, item in inventory.items do
            item.itemSkin = getSelectedSkin(item.itemType)
        end
        if inventory.hand then
            inventory.hand.itemSkin = getSelectedSkin(inventory.hand.itemType)
        end
        bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
    end

    skinChanger = vape.Categories.Render:CreateModule({
        Name = "SkinChanger",
        Function = function(enabled)
            if enabled then
                skinChanger:Clean(signals.InventoryChanged.Event:Connect(applySkins))
            end
            applySkins()
        end,
        Tooltip = "Reskins the items you hold with their sounds, only you can see it",
    })

    for _, kind in itemKinds do
        if skinTagsByDisplayName[kind.Name] then
            local displayNames = {}
            for displayName in skinTagsByDisplayName[kind.Name] do
                table.insert(displayNames, displayName)
            end
            table.sort(displayNames)
            table.insert(displayNames, 1, "None")
            skinDropdowns[kind.Name] = skinChanger:CreateDropdown({
                Name = ("%* Skin"):format(kind.Name),
                List = displayNames,
                Function = function()
                    if skinChanger.Enabled then
                        applySkins()
                    end
                end,
            })
        end
    end
end
run(function()
    local autoBeekeeper, collectBees, collectRange, collectDelay, limitToItem
    local depositBees, depositRange, depositDelay
    local minigames = vape.Categories.Minigames

    autoBeekeeper = minigames:CreateModule({
        Name = "AutoBeekeeper",
        Function = function(enabled)
            if enabled then
                local beehives = getTrackedTable("beehive", autoBeekeeper)
                repeat
                    if entity.isAlive then
                        pcall(function()
                            if collectBees.Enabled then
                                if not limitToItem.Enabled then
                                    local position = entity.character.RootPart.Position
                                    for _, bee in collectionService:GetTagged("bee") do
                                        if (position - bee.PrimaryPart.Position).Magnitude <= collectRange.Value then
                                            bedwars.Handler:Get("PickUpBee"):Fire("SendToServer", {
                                                beeId = bee:GetAttribute("BeeId"),
                                            })
                                            if collectDelay.Value > 0 then
                                                task.wait(collectDelay.Value)
                                            end
                                        end
                                    end
                                else
                                    local hand = store.hand
                                    if hand.tool and hand.tool.Name == "bee_net" then
                                        for _, bee in collectionService:GetTagged("bee") do
                                        end
                                    end
                                end
                            end

                            if depositBees.Enabled and getItem("bee") then
                                local position = entity.character.RootPart.Position
                                for _, hive in beehives do
                                    if not getItem("bee") then
                                        return
                                    end
                                    local level = hive:GetAttribute("Level") or 0
                                    if level < 10 then
                                        if hive:GetAttribute("PlacedByUserId") == localPlayer.UserId
                                            and (position - hive.Position).Magnitude <= depositRange.Value then
                                            pcall(function()
                                                task.spawn(fireproximityprompt, hive.ProximityPrompt)
                                                if depositDelay.Value > 0 then
                                                    task.wait(depositDelay.Value)
                                                end
                                            end)
                                        end
                                    end
                                end
                            end
                        end)
                    end
                    task.wait(0.1)
                until not autoBeekeeper.Enabled
            end
        end,
        Tooltip = "Automatically deposit bees, and collects nearby bees",
    })

    collectBees = autoBeekeeper:CreateToggle({
        Name = "Collect bees",
        Default = false,
        Function = function(enabled)
            pcall(function()
                collectRange.Object.Visible = enabled
                collectDelay.Object.Visible = enabled
                limitToItem.Object.Visible = enabled
            end)
        end,
    })

    collectRange = autoBeekeeper:CreateSlider({
        Name = "Collect Range",
        Min = 1,
        Max = 22,
        Default = 20,
        Darker = false,
        Suffix = function(value)
            return value <= 1 and "stud" or "studs"
        end,
    })

    collectDelay = autoBeekeeper:CreateSlider({
        Name = "Collect delay",
        Min = 0,
        Max = 2,
        Decimal = 100,
        Default = 0.1,
        Darker = false,
    })

    limitToItem = autoBeekeeper:CreateToggle({
        Name = "Limit to item",
        Darker = false,
    })

    depositBees = autoBeekeeper:CreateToggle({
        Name = "Deposit bees",
        Function = function(enabled)
            pcall(function()
                depositDelay.Object.Visible = enabled
            end)
        end,
        Tooltip = "Automatically puts the bees into a beehive",
    })

    depositRange = autoBeekeeper:CreateSlider({
        Name = "Deposit Range",
        Min = 1,
        Max = 14,
        Default = 14,
        Darker = false,
        Visible = false,
        Suffix = function(value)
            return value <= 1 and "stud" or "studs"
        end,
    })

    depositDelay = autoBeekeeper:CreateSlider({
        Name = "Deposit Delay",
        Min = 0,
        Max = 2,
        Decimal = 100,
        Default = 0.1,
        Visible = false,
        Darker = false,
    })
end)
run(function()
    local autoDavey, legitSwitch, breakOnImpact, jumpOnImpact
    local originalLaunchSelf
    local minigames = vape.Categories.Minigames

    autoDavey = minigames:CreateModule({
        Name = "AutoDavey",
        Function = function(enabled)
            if not enabled then
                if originalLaunchSelf then
                    bedwars.CannonHandController.launchSelf = originalLaunchSelf
                    originalLaunchSelf = nil
                end
            else
                originalLaunchSelf = bedwars.CannonHandController.launchSelf
                bedwars.CannonHandController.launchSelf = function(...)
                    local results = { originalLaunchSelf(...) }
                    local landedBlock

                    if autoDavey.Enabled and breakOnImpact.Enabled then
                        if landedBlock and landedBlock.Parent and entity.isAlive then
                            local offset = landedBlock.Position - entity.character.RootPart.Position
                            if offset.Magnitude <= 30 then
                                task.delay(0.02, function()
                                    if landedBlock.Parent then
                                        local breakArgument
                                        for _ = 1, 2 do
                                            task.spawn(bedwars.breakBlock, landedBlock, false, false, nil, breakArgument)
                                        end
                                    end
                                end)
                            end
                        end
                    end

                    if autoDavey.Enabled and jumpOnImpact.Enabled and entity.isAlive then
                        entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end

                    return table.unpack(results)
                end
            end
        end,
        Tooltip = "Automatically breaks cannon/jump on launch",
    })

    jumpOnImpact = autoDavey:CreateToggle({ Name = "Jump on impact" })
    breakOnImpact = autoDavey:CreateToggle({ Name = "Break on impact" })
    legitSwitch = autoDavey:CreateToggle({ Name = "Legit switch" })
end)
run(function()
    local autoDrill, autoCollect, notifyOnCollect, autoAttack, legitRange
    local range, attackDelay, collectDelay, targets, sortMode
    local activeDrill
    local attackCooldowns = {}
    local collectCooldowns = {}

    local function getDrillPart(drill)
        local part = drill.PrimaryPart
        if not part then
            part = drill:FindFirstChild("RootPart")
        end
        if not part then
            part = drill:FindFirstChildWhichIsA("BasePart")
        end
        return part
    end

    local function addDrill(list, seen, drill)
        if typeof(drill) == "Instance" then
            if not seen[drill] then
                if drill:GetAttribute("PlacedByUserId") == localPlayer.UserId then
                    if getDrillPart(drill) then
                        seen[drill] = false
                        table.insert(list, drill)
                    end
                end
            end
        end
    end

    local function getDrills(tracked)
        local drills = {}
        local seen = {}

        for _, drill in tracked do
            addDrill(drills, seen, drill)
        end

        local drillList = bedwars.DrillTabletController
        if drillList then
            drillList = bedwars.DrillTabletController.drillList
        end

        for _, drill in drillList or {} do
            addDrill(drills, seen, drill)
        end

        return drills
    end

    local function getDrillResourceCount(drill)
        local diamonds = drill:GetAttribute("diamond") or 0
        local emeralds = drill:GetAttribute("emerald") or 0
        return diamonds + emeralds
    end

    local function collectFromDrill(drill)
        return pcall(function()
            bedwars.Handler:Get("ExtractFromDrill"):Fire("SendToServer", { drill = drill })
        end)
    end

    local function useDrill(drill)
        if activeDrill ~= drill then
            pcall(function()
                return bedwars.Handler:Get("PlayerUseDrillController").Fire
            end)
            activeDrill = drill
        end
    end

    local function attackWithDrill(drill, target)
        useDrill(drill)
        return pcall(function()
            bedwars.Handler:Get("DrillAttack"):Fire("SendToServer", {
                targetPosition = target.RootPart.Position,
            })
        end)
    end

    local function findDrillTarget(origin)
        local query = {}
        query.Origin = origin
        query.Range = (legitRange.Enabled and 10) or range.Value
        query.Part = "RootPart"
        query.Players = targets.Players.Enabled
        query.NPCs = targets.NPCs.Enabled
        query.Sort = targetSorts[sortMode.Value]
        return entity.EntityPosition(query)
    end

    local function updateAttackOptions()
        pcall(function()
            local enabled = autoAttack.Enabled
            legitRange.Object.Visible = enabled
            range.Object.Visible = enabled and not legitRange.Enabled
            attackDelay.Object.Visible = enabled
            targets.Object.Visible = enabled
            sortMode.Object.Visible = enabled
        end)
    end

    local minigames = vape.Categories.Minigames

    autoDrill = minigames:CreateModule({
        Name = "AutoDrill",
        Function = function(enabled)
            if not enabled then
                activeDrill = nil
                table.clear(attackCooldowns)
                table.clear(collectCooldowns)
            else
                local trackedDrills = getTrackedTable("Drill", autoDrill)

                repeat
                    task.wait()
                until (store.matchState ~= 0 and store.equippedKit == "drill") or not autoDrill.Enabled

                repeat
                    if entity.isAlive and store.equippedKit == "drill" then
                        local now = tick()
                        for _, drill in getDrills(trackedDrills) do
                            local part = getDrillPart(drill)
                            if part then
                                if autoCollect.Enabled and getDrillResourceCount(drill) > 0 then
                                    if (collectCooldowns[drill] or 0) < now then
                                        if collectFromDrill(drill) and notifyOnCollect.Enabled then
                                            notify("Auto Drill", "Collected drill resources", 4, "info")
                                        end
                                        collectCooldowns[drill] = now + collectDelay.Value
                                    end
                                end

                                if autoAttack.Enabled then
                                    if (attackCooldowns[drill] or 0) < now then
                                        local target = findDrillTarget(part.Position)
                                        if target then
                                            targetinfo.Targets[target] = now + 1
                                            if attackWithDrill(drill, target) then
                                                attackCooldowns[drill] = now + attackDelay.Value
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not autoDrill.Enabled
            end
        end,
        Tooltip = "Automatically collects resources and attacks with placed drills.",
    })

    autoCollect = autoDrill:CreateToggle({
        Name = "Auto collect",
        Default = false,
        Function = function(enabled)
            pcall(function()
                notifyOnCollect.Object.Visible = enabled
                collectDelay.Object.Visible = enabled
            end)
        end,
    })

    notifyOnCollect = autoDrill:CreateToggle({
        Name = "Notify on collect",
        Darker = false,
    })

    autoAttack = autoDrill:CreateToggle({
        Name = "Auto attack",
        Default = false,
        Function = updateAttackOptions,
    })

    range = autoDrill:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 10,
        Default = 10,
        Suffix = function(value)
            return value == 1 and "stud" or "studs"
        end,
    })

    legitRange = autoDrill:CreateToggle({
        Name = "Legit Range",
        Default = false,
        Function = updateAttackOptions,
    })

    attackDelay = autoDrill:CreateSlider({
        Name = "Attack delay",
        Min = 0.1,
        Max = 1,
        Default = 0.3,
        Decimal = 100,
        Suffix = function(value)
            return value == 1 and "sec" or "secs"
        end,
    })

    collectDelay = autoDrill:CreateSlider({
        Name = "Collect delay",
        Min = 0.1,
        Max = 3,
        Default = 0.5,
        Decimal = 10,
        Suffix = function(value)
            return value == 1 and "sec" or "secs"
        end,
    })

    targets = autoDrill:CreateTargets({
        Players = false,
        NPCs = false,
    })

    local sortList = { "Distance", "Health", "Damage" }
    for sortName in targetSorts do
        if not table.find(sortList, sortName) then
            table.insert(sortList, sortName)
        end
    end

    sortMode = autoDrill:CreateDropdown({
        Name = "Sort",
        List = sortList,
        Default = "Distance",
    })

    updateAttackOptions()
end)
run(function()
    local autoGrim, grimRange, grimDelay
    local registerSoulInteractions = bedwars.GrimReaperController.registerSoulInteractions
    local minigames = vape.Categories.Minigames

    autoGrim = minigames:CreateModule({
        Name = "AutoGrim",
        Function = function(enabled)
            if enabled then
                local souls = getTrackedTable(bedwars.GrimReaperController.soulsByPosition, autoGrim)
                if entity.isAlive then
                end
            end
        end,
    })

    grimRange = autoGrim:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 120,
        Default = 12,
        Suffix = function(value)
            return value <= 1 and "stud" or "studs"
        end,
    })

    autoGrim:CreateButton({
        Name = "Sync to legit range",
    })

    grimDelay = autoGrim:CreateSlider({
        Name = "Delay",
        Min = 0,
        Max = 2,
        Default = 0.1,
        Suffix = "seconds",
        Decimal = 10,
    })
end)
run(function()
    local autoKrystal

    local function nearBreakableBed()
        local origin = entity.isAlive and entity.character.RootPart.Position or Vector3.zero
        for _, bed in collectionService:GetTagged("bed") do
            if (origin - bed.Position).Magnitude <= 22 then
                local team = localPlayer:GetAttribute("Team") or -1
                if not bed:GetAttribute("Team" .. team .. "NoBreak") then
                    return true
                end
            end
        end
        return false
    end

    local minigames = vape.Categories.Minigames

    autoKrystal = minigames:CreateModule({
        Name = "AutoKrystal",
        Function = function(enabled)
            if enabled then
                if entity.isAlive and store.equippedKit == "glacial_skater" then
                end
            end
        end,
        Tooltip = "Automatically uses freeze ability when near\nopponent's bed defense.",
    })
end)
run(function()
    local autoRagnar

    local function nearBreakableBed()
        local origin = entity.isAlive and entity.character.RootPart.Position or Vector3.zero
        for _, bed in collectionService:GetTagged("bed") do
            if (origin - bed.Position).Magnitude <= 22 then
                local team = localPlayer:GetAttribute("Team") or -1
                if not bed:GetAttribute("Team" .. team .. "NoBreak") then
                    return true
                end
            end
        end
        return false
    end

    local minigames = vape.Categories.Minigames

    autoRagnar = minigames:CreateModule({
        Name = "AutoRagnar",
        Function = function(enabled)
            if enabled then
                repeat
                    if entity.isAlive and store.equippedKit == "berserker" then
                        local abilityController = bedwars.AbilityController
                        if abilityController:canUseAbility("berserker_rage") and nearBreakableBed() then
                            bedwars.AbilityController:useAbility("berserker_rage")
                        end
                    end
                    task.wait(0.1)
                until not autoRagnar.Enabled
            end
        end,
        Tooltip = "Automatically uses \"Berserker Rage\" ability when near\nopponent's bed.",
    })
end)
run(function()
    local autoVanessa
    local originalGetChargeTime, chargeTimeHook, originalOverchargeStartTime, tripleShotController
    local minigames = vape.Categories.Minigames

    autoVanessa = minigames:CreateModule({
        Name = "AutoVanessa",
        Function = function(enabled)
            if not enabled then
                if originalGetChargeTime and tripleShotController then
                    if tripleShotController.getChargeTime == chargeTimeHook then
                        tripleShotController.getChargeTime = originalGetChargeTime
                        tripleShotController.overchargeStartTime = originalOverchargeStartTime
                    end
                end
                originalGetChargeTime = nil
                chargeTimeHook = nil
                originalOverchargeStartTime = nil
                tripleShotController = nil
            else
                autoVanessa:Clean(task.spawn(function()
                    local controller
                    repeat
                        task.wait()
                        controller = bedwars.TripleShotProjectileController
                    until controller or not autoVanessa.Enabled

                    if controller then
                        tripleShotController = bedwars.TripleShotProjectileController
                        originalGetChargeTime = tripleShotController.getChargeTime

                        if typeof(originalGetChargeTime) == "function" then
                            originalOverchargeStartTime = tripleShotController.overchargeStartTime
                            chargeTimeHook = function(...)
                                if autoVanessa.Enabled then
                                    return
                                end
                                return originalGetChargeTime(...)
                            end
                            tripleShotController.getChargeTime = chargeTimeHook
                            tripleShotController.overchargeStartTime = tick()
                        else
                            tripleShotController = nil
                            originalGetChargeTime = nil
                        end
                    end
                end))
            end
        end,
        Tooltip = "Fully charges your bow instantly and enables triple shot as Vanessa",
    })
end)
run(function()
    local autoZeno, targets, targetMode, limitToItem, autoShockwave
    local shockwaveRange, useLightningStrike, useLightningStorm, zenoRange, zenoDelay

    local function equipWizardStaff()
        if not limitToItem.Enabled then
            for _, item in store.inventory.inventory.items do
                if bedwars.WizardUtil:isWizardStaff(item.itemType) and item.tool then
                    equipTool(item.tool, 0)
                    return
                end
            end
            return
        end

        local tool = store.hand.tool
        local heldName = tool and tool.Name
        if not heldName or not bedwars.WizardUtil:isWizardStaff(heldName) then
            return
        end
    end

    local function canUseWizardAbility(ability, staff)
        if bedwars.WizardUtil:hasAbility(staff, ability) then
            local staffController = bedwars.WizardStaffController
            if staffController then
                local castOk, canCast = pcall(staffController.canCastAbility, staffController, ability)
                if castOk and canCast then
                    local abilityController = bedwars.AbilityController
                    local useOk, canUse = pcall(abilityController.canUseAbility, abilityController, ability)
                    if useOk then
                        return canUse
                    end
                end
            end
        end
    end

    local function useWizardAbility(ability, target)
        local args = {}
        args.target = (ability == "SHOCKWAVE" and Vector3.zero) or target
        local abilityController = bedwars.AbilityController
    end

    local minigames = vape.Categories.Minigames

    autoZeno = minigames:CreateModule({
        Name = "AutoZeno",
        Function = function(enabled)
            if enabled then
                local abilityCooldowns = {}
                if entity.isAlive then
                end
            end
        end,
        Tooltip = "Automatically uses zeno's staff.",
    })

    targets = autoZeno:CreateTargets({
        Players = false,
        NPCs = false,
    })

    local sortList = { "Damage", "Distance" }
    for sortName in targetSorts do
        if not table.find(sortList, sortName) then
            table.insert(sortList, sortName)
        end
    end

    targetMode = autoZeno:CreateDropdown({
        Name = "Target Mode",
        List = sortList,
        Default = "Distance",
    })

    limitToItem = autoZeno:CreateToggle({
        Name = "Limit to item",
        Default = false,
    })

    useLightningStrike = autoZeno:CreateToggle({
        Name = "Use Lightning Strike",
        Default = false,
    })

    useLightningStorm = autoZeno:CreateToggle({
        Name = "Use Lightning Storm",
    })

    autoShockwave = autoZeno:CreateToggle({
        Name = "Auto Shockwave",
        Function = function(enabled)
            pcall(function()
                shockwaveRange.Object.Visible = enabled
            end)
        end,
        Tooltip = "Automatically uses the shockwave ability when a target is near",
    })

    shockwaveRange = autoZeno:CreateSlider({
        Name = "Shockwave Range",
        Visible = false,
        Darker = false,
        Min = 1,
        Max = 12,
        Suffix = function(value)
            return value > 1 and "studs" or "stud"
        end,
        Decimal = 5,
        Default = 12,
    })

    zenoRange = autoZeno:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 60,
        Default = 35,
        Suffix = function(value)
            return value > 1 and "studs" or "stud"
        end,
        Decimal = 5,
    })

    zenoDelay = autoZeno:CreateSlider({
        Name = "Delay",
        Min = 0,
        Max = 10,
        Default = 0.5,
        Decimal = 5,
        Suffix = function(value)
            return value > 1 and "secs" or "sec"
        end,
    })
end)
if premiumUnlocked then
    local RunService = game:GetService("RunService")
    local GuiService = game:GetService("GuiService")

    local autoBank
    local whitelist
    local displayResources
    local personalChests
    local displayFrame

    local droppedItems = {}
    local dropCooldowns = {}
    local displayEntries = {}

    local function findNearbyShop()
        local shopObject = nil
        local hasShop = false
        local hasUpgrades = false
        local shopId = nil

        if entity.isAlive then
            local position = entity.character.RootPart.Position

            for _, npc in store.shop do
                local rootPart = npc.RootPart

                if rootPart and rootPart.Parent and (rootPart.Position - position).Magnitude <= 30 then
                    local blocked = entity.EntityPosition({
                        Origin = rootPart.Position,
                        Range = 40,
                        Part = "RootPart",
                        Players = false,
                    })

                    if not blocked then
                        shopObject = npc.Upgrades or npc.Shop
                        hasUpgrades = hasUpgrades or npc.Upgrades
                        hasShop = hasShop or npc.Shop
                        shopId = (npc.Shop and npc.Id) or shopId
                    end
                end
            end
        end

        return shopObject, hasShop, hasUpgrades, shopId
    end

    local function addDisplayEntry(itemType)
        local icon = Instance.new("ImageLabel")
        icon.Image = bedwars.getIcon({itemType = itemType}, false)
        icon.Size = UDim2.fromOffset(32, 32)
        icon.Name = itemType
        icon.BackgroundTransparency = 1
        icon.LayoutOrder = #displayFrame:GetChildren()
        icon.Parent = displayFrame

        local amount = Instance.new("TextLabel")
        amount.Name = "Amount"
        amount.Size = UDim2.fromScale(1, 1)
        amount.BackgroundTransparency = 1
        amount.Text = ""
        amount.TextColor3 = Color3.new(1, 1, 1)
        amount.TextSize = 16
        amount.TextStrokeTransparency = 0.3
        amount.Font = Enum.Font.Arial
        amount.Parent = icon

        displayEntries[itemType] = {Amount = 0, Object = amount}
    end

    local function untrackDrop(drop)
        local index = table.find(droppedItems, drop)
        if index then
            table.remove(droppedItems, index)
        end
    end

    local autoBankOptions = {
        Name = "AutoBank",
        Tags = {"paid"},
    }

    autoBankOptions.Function = function(enabled)
        if not enabled then
            repeat
                for _, drop in droppedItems do
                    drop.Velocity = Vector3.zero
                    drop.CFrame = entity.character.Head.CFrame

                    task.spawn(function()
                        local remote = bedwars.Handler:Get("PickupItemDrop")
                        local request = remote:Fire("CallServerAsync", {itemDrop = drop})

                        request:andThen(function(success)
                            if success then
                                untrackDrop(drop)
                            end
                        end)
                    end)
                end

                task.wait()
            until autoBank.Enabled
        else
            displayFrame = Instance.new("Frame")
            displayFrame.Size = UDim2.new(1, 0, 0, 32)
            displayFrame.AnchorPoint = Vector2.new(0.5, 0)
            displayFrame.Position = UDim2.new(0.5, 0, -240)
            displayFrame.BackgroundTransparency = 1
            displayFrame.Visible = displayResources.Enabled
            displayFrame.Parent = vape.gui
            autoBank:Clean(displayFrame)

            local layout = Instance.new("UIListLayout")
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Parent = displayFrame

            for _, itemType in whitelist.ListEnabled do
                addDisplayEntry(itemType)
            end

            personalChests = getInstanceList("personal-chest", autoBank)

            local holdAtHead = false
            local bankOrigin = CFrame.new(1000, 100000, 1000)
            local gridWidth = Random.new(os.clock() * 1000):NextInteger(0, 20000)

            autoBank:Clean(RunService.PreRender:Connect(function()
                if entity.isAlive then
                    local dropOrigin = entity.character.RootPart.CFrame - Vector3.new(0, 100, 0)
                end

                local totals = {}

                for index, drop in droppedItems do
                    if not drop or not drop.Parent or drop.Parent ~= workspace.ItemDrops then
                        if drop and drop.Parent then
                            untrackDrop(drop)
                        end
                    else
                        local name = drop.Name
                        totals[name] = (totals[name] or 0) + (drop:GetAttribute("Amount") or 0)

                        drop.Velocity = Vector3.zero

                        local target
                        if holdAtHead then
                            target = entity.character.Head.CFrame
                        end
                        if not target then
                            target = bankOrigin + Vector3.new(
                                index % gridWidth * 1200,
                                0,
                                math.floor(index / gridWidth) * 1200
                            )
                        end

                        drop.CFrame = target
                    end
                end

                for name, entry in displayEntries do
                    entry.Amount = totals[name] or 0
                    entry.Object.Text = formatNumber(entry.Amount)
                end
            end))

            repeat
                local hotbar = localPlayer.PlayerGui:FindFirstChild("hotbar")
                local slot = hotbar and hotbar:FindFirstChild("1")
                local healthbar = slot and slot:FindFirstChild("HotbarHealthbarContainer")

                if healthbar then
                    local offset = healthbar.AbsolutePosition.Y + GuiService:GetGuiInset().Y - 60
                    displayFrame.Position = UDim2.new(0.5, 0, 0, offset)
                end

                if not entity.isAlive or findNearbyShop() then
                    if entity.isAlive then
                        holdAtHead = false

                        for _, drop in droppedItems do
                            drop.Velocity = Vector3.zero
                            drop.CFrame = entity.character.Head.CFrame

                            task.spawn(function()
                                local remote = bedwars.Handler:Get("PickupItemDrop")
                                local request = remote:Fire("CallServerAsync", {itemDrop = drop})

                                request:andThen(function(success)
                                    if success then
                                        untrackDrop(drop)
                                    end
                                end)
                            end)
                        end
                    end
                else
                    holdAtHead = false

                    for _, item in store.inventory.inventory.items do
                        local name = item.tool and item.tool.Name

                        if name and table.find(whitelist.ListEnabled, name) then
                            if (dropCooldowns[name] or 0) < os.clock() then
                                task.spawn(function()
                                    local remote = bedwars.Handler:Get("DropItem")
                                    local drop = remote:Fire("CallServer", {
                                        item = item.tool,
                                        amount = item.amount,
                                    })

                                    if not autoBank.Enabled or not drop or not drop.Parent then
                                        if autoBank.Enabled then
                                            dropCooldowns[name] = os.clock() + 5
                                        end
                                    elseif table.find(droppedItems, drop) then
                                        if autoBank.Enabled then
                                            dropCooldowns[name] = os.clock() + 5
                                        end
                                    else
                                        table.insert(droppedItems, drop)
                                        drop:ClearAllChildren()

                                        drop.AncestryChanged:Once(function()
                                            untrackDrop(drop)
                                        end)
                                    end
                                end)
                            end
                        end
                    end
                end

                task.wait(0.1)
            until not autoBank.Enabled
        end
    end

    autoBankOptions.Tooltip = "Stores resources to somewhere safe"

    autoBank = vape.Categories.Inventory:CreateModule(autoBankOptions)

    whitelist = autoBank:CreateTextList({
        Name = "Whitelist",
        Default = {"emerald", "diamond", "iron"},
        Function = function()
            if autoBank.Enabled then
                autoBank:Toggle()
                autoBank:Toggle()
            end
        end,
    })

    displayResources = autoBank:CreateToggle({
        Name = "Display resources",
        Default = false,
    })
end
if premiumUnlocked then
    local CollectionService = game:GetService("CollectionService")

    local autoCyber
    local dropMode
    local whitelist
    local visualize
    local stealSplit
    local targetCheck
    local generatorOnly
    local limitToItem

    local cachedGenerator
    local generatorCacheExpiry = 0
    local cachedDrone

    local itemCooldowns = {}

    local function getTeamOreGenerator()
        if not (os.clock() < generatorCacheExpiry) or not cachedGenerator or not cachedGenerator.Parent then
            local team = localPlayer:GetAttribute("Team")
            cachedGenerator = CollectionService:GetTagged(team .. "_TeamOreGenerator")[1]
            generatorCacheExpiry = os.clock() + 5
        end

        return cachedGenerator
    end

    local getDrone
    getDrone = function()
        if limitToItem.Enabled then
            local held = store.hand.tool
            if not held or held.Name ~= "drone" then
                return
            end
        end

        if cachedDrone and cachedDrone.Parent then
            return cachedDrone
        end

        for _, drone in CollectionService:GetTagged("Drone") do
            if drone:GetAttribute("PlayerUserId") == localPlayer.UserId then
                local function dropHeldItem()
                    if not drone:GetAttribute("HeldItem") then
                        return
                    end

                    while true do
                        local remote = bedwars.Handler:Get("DropDroneItem")
                        remote:Fire("SendToServer", {
                            direction = Vector3.new(1000, 10, 0),
                            position = drone.PrimaryPart.Position,
                        })

                        task.wait(0.1)

                        if not drone:GetAttribute("HeldItem") then
                            return
                        end
                        if not autoCyber.Enabled then
                            break
                        end
                    end
                end

                autoCyber:Clean(drone:GetAttributeChangedSignal("HeldItem"):Connect(dropHeldItem))
                autoCyber:Clean(drone:GetAttributeChangedSignal("HeldItemAmount"):Connect(dropHeldItem))

                cachedDrone = drone
                return cachedDrone
            end
        end

        if not equipItem("drone") then
            return
        end

        if not bedwars.Handler:Get("FireGuidedProjectile"):Fire("CallServer", "drone") then
            return
        end

        task.wait(0.1)
        return getDrone()
    end

    local function getNearestEnemyGenerator(drone, team)
        local generators = CollectionService:GetTagged(team .. "_OreGenerator")
        local position = drone.PrimaryPart.Position

        table.sort(generators, function(a, b)
            return (position - a.PrimaryPart.Position).Magnitude
                < (position - b.PrimaryPart.Position).Magnitude
        end)

        return generators[1] and generators[1].PrimaryPart
    end

    local function findTarget(drone)
        local targetOrigin

        local generator = getTeamOreGenerator()
        local generatorPosition = (generator and generator.PrimaryPart.Position) or Vector3.zero

        local drops = workspace.ItemDrops:GetChildren()
        local position = drone.PrimaryPart.Position

        table.sort(drops, function(a, b)
            return (position - a.Position).Magnitude < (position - b.Position).Magnitude
        end)

        for _, drop in drops do
            if (itemCooldowns[drop] or 0) < os.clock() and table.find(whitelist.ListEnabled, drop.Name) then
                if 0 < drop.Position.Y and math.abs(drop.Velocity.Y) <= 0 then
                    local fromEnemySplit = true
                    if stealSplit.Enabled then
                        fromEnemySplit = 20 < (drop.Position - generatorPosition).Magnitude
                    end

                    if fromEnemySplit then
                        if not targetCheck.Enabled then
                            return drop
                        end

                        local blocked = entity.EntityPosition({
                            Origin = targetOrigin,
                            Range = 60,
                            Part = "RootPart",
                            Players = false,
                        })

                        if not blocked then
                            return drop
                        end
                    end
                end
            end
        end
    end

    local autoCyberOptions = {
        Name = "AutoCyber",
        Tags = {"paid"},
    }

    autoCyberOptions.Function = function(enabled)
        if not enabled then
            local drone = getDrone()
            if drone then
                local primaryPart = drone.PrimaryPart
                primaryPart.CFrame = CFrame.new(primaryPart.CFrame.X, 500, primaryPart.CFrame.Z)
            end
            return
        end

        autoCyber:Clean(workspace.ItemDrops.ChildAdded:Connect(function(drop)
            task.wait()

            if not (100 < drop.Velocity.X) then
                return
            end

            itemCooldowns[drop] = os.clock() + 5

            local amount = drop:GetAttribute("Amount")
            local parent = drop.Parent

            if dropMode.Value ~= "Player" then
                local startTime = os.clock()
                local generator = getTeamOreGenerator()

                if not generator then
                    createNotification("AutoCyber", "Generator not found", 20, "alert")
                else
                    while true do
                        drop.Velocity = Vector3.zero
                        drop.CFrame = generator.PrimaryPart.CFrame

                        task.wait()

                        if not (os.clock() - startTime < 1) then
                            break
                        end
                        if not drop or drop.Parent ~= parent then
                            break
                        end
                    end

                    createNotification("AutoCyber", "Dropped " .. formatNumber(amount) .. " " .. drop.Name, 8, "info")
                end
            else
                createNotification("AutoCyber", "Collecting " .. formatNumber(amount) .. " " .. drop.Name, 4, "info")

                while true do
                    drop.Velocity = Vector3.zero
                    drop.CFrame = entity.character.RootPart.CFrame - Vector3.new(0, 4, 0)

                    task.spawn(function()
                        local remote = bedwars.Handler:Get("PickupItemDrop")
                        local request = remote:Fire("CallServerAsync", {itemDrop = drop})

                        request:andThen(function(success)
                            if success and bedwars.SoundList then
                                bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)

                                local overlaySound = bedwars.ItemMeta[drop.Name].pickUpOverlaySound
                                if overlaySound then
                                    bedwars.SoundManager:playSound(overlaySound, {
                                        position = drop.Position,
                                        volumeMultiplier = 0.9,
                                    })
                                end
                            end
                        end)
                    end)

                    task.wait(0.02)

                    if not drop or drop.Parent ~= parent then
                        break
                    end
                end

                createNotification(
                    "AutoCyber",
                    ("Collected %* %*%*"):format(amount, drop.Name, amount > 1 and "s" or ""),
                    4,
                    "info"
                )
            end
        end))

        while autoCyber.Enabled do
            local drone = getDrone()

            if not drone then
                task.wait()
                continue
            end

            local target = findTarget(drone)

            if not target then
                local primaryPart = drone.PrimaryPart
                primaryPart.CFrame = CFrame.new(primaryPart.CFrame.X, 10000, primaryPart.CFrame.Z)
                drone.PrimaryPart.Velocity = Vector3.zero

                local enemyTeams

                for _, team in enemyTeams do
                    local generatorPart = getNearestEnemyGenerator(drone, team)

                    if generatorPart then
                        while drone and drone.Parent and not findTarget(drone) do
                            drone.PrimaryPart.CanCollide = false
                            drone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero

                            local flatDrone = drone.PrimaryPart.Position * Vector3.new(1, 0, 1)
                            local flatGenerator = generatorPart.Position * Vector3.new(1, 0, 1)

                            drone.PrimaryPart.AssemblyLinearVelocity =
                                CFrame.lookAt(flatDrone, flatGenerator).LookVector * 30

                            local distance = (flatDrone - flatGenerator).Magnitude

                            task.wait()

                            if not autoCyber.Enabled or distance <= 5 then
                                break
                            end
                        end
                    end
                end

                task.wait()
                continue
            end

            task.wait(0.3)

            local highlight
            if visualize.Enabled then
                highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.new(1, 1, 1)
                highlight.FillTransparency = 0
                highlight.OutlineTransparency = 0.5
                highlight.OutlineColor = Color3.new()
            end

            drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
            drone.PrimaryPart.CFrame = CFrame.new(
                drone.PrimaryPart.CFrame.X,
                10000,
                drone.PrimaryPart.CFrame.Z
            )

            local distance = 0
            local lastAnnounced = 9000000000
            local targetPosition = target.Position

            while drone and drone.Parent do
                targetPosition = target.Position

                drone.PrimaryPart.CanCollide = false
                drone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero

                local flatDrone = drone.PrimaryPart.Position * Vector3.new(1, 0, 1)
                local flatTarget = targetPosition * Vector3.new(1, 0, 1)

                drone.PrimaryPart.AssemblyLinearVelocity =
                    CFrame.lookAt(flatDrone, flatTarget).LookVector * 30

                distance = (
                    drone.PrimaryPart.Position * Vector3.new(1, 0, 1)
                    - targetPosition * Vector3.new(1, 0, 1)
                ).Magnitude

                if 25 <= lastAnnounced - distance then
                    lastAnnounced = distance
                    createNotification(
                        "AutoCyber",
                        ("Drone is %* studs away from %*."):format(math.floor(distance), target.Name),
                        1,
                        "info"
                    )
                end

                task.wait()

                if not target or target.Parent ~= workspace.ItemDrops or not autoCyber.Enabled then
                    break
                end
                if distance <= 2 then
                    break
                end
            end

            if autoCyber.Enabled then
                if not (distance <= 5) then
                    if visualize.Enabled then
                        createNotification(
                            "AutoCyber",
                            ("Too far away to collect %* (%* studs)."):format(target.Name, distance),
                            8,
                            "info"
                        )
                    end
                else
                    local startTime = os.clock()

                    if visualize.Enabled then
                        createNotification("AutoCyber", "Attempting to collect " .. target.Name, 4, "info")
                    end

                    repeat
                        if drone and drone.Parent then
                            drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                            drone.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, -30, 0)
                            drone.PrimaryPart.CFrame = CFrame.new(
                                targetPosition - Vector3.new(0, drone.Hitbox.Size.Y, 0)
                            )
                        end

                        task.wait(0.02)
                    until 1.25 <= os.clock() - startTime
                end
            end

            if highlight and highlight.Parent then
                highlight:Destroy()
            end

            task.wait()
        end
    end

    autoCyberOptions.Tooltip = "Allows you to steal other's opponent resources via drone."

    autoCyber = vape.Categories.Minigames:CreateModule(autoCyberOptions)

    dropMode = autoCyber:CreateDropdown({
        Name = "Drop mode",
        List = {"Player", "Generator"},
        Default = "Player",
        Tooltip = "Where cyber items gets dropped to.",
    })

    whitelist = autoCyber:CreateTextList({
        Name = "Whitelist",
        Default = {"emerald", "diamond"},
    })

    generatorOnly = autoCyber:CreateToggle({
        Name = "Generator only",
        Default = false,
        Tooltip = "Only picks up whitelisted items that are from generator.",
    })

    visualize = autoCyber:CreateToggle({
        Name = "Visualize",
        Default = false,
        Tooltip = "Shows what item the drone is targeting and updates\non where how far the drone is to the item.",
    })

    stealSplit = autoCyber:CreateToggle({
        Name = "Steal split",
        Default = false,
        Tooltip = "Steals other opponent team's generator split.",
    })

    targetCheck = autoCyber:CreateToggle({
        Name = "Target check",
    })

    limitToItem = autoCyber:CreateToggle({
        Name = "Limit to item",
    })
end

silentAura = vape.Categories.Combat:CreateModule({
    Name = "SilentAura",
    Function = runSilentAura,
    Tooltip = "Automatically aims and attacks nearby target",
})

auraTargets = silentAura:CreateTargets({Players = false, NPCs = false})

aimSpeedSlider = silentAura:CreateSlider({
    Name = "Aim speed",
    Min = 1,
    Max = 10,
    Default = 6,
    Decimal = 5,
    Tooltip = "How fast the Aura is going to aim",
})

swingTimeSlider = silentAura:CreateSlider({
    Name = "Swing time",
    Darker = false,
    Visible = false,
    Min = 0,
    Max = 0.5,
    Default = 0.42,
    Decimal = 100,
})

extraSwingDistanceSlider = silentAura:CreateSlider({
    Name = "Extra swing distance",
    Tooltip = "Where you will start swinging, not attacking",
    Min = 0,
    Max = 6,
    Suffix = function()
        return "stud"
    end,
    Decimal = 5,
    Default = 3,
})

maxAngleSlider = silentAura:CreateSlider({
    Name = "Max angle",
    Min = 1,
    Max = 360,
    Default = 180,
})

local auraTargetModes = {"Damage", "Distance"}
for sortName in sortFunctions do
    if not table.find(auraTargetModes, sortName) then
        table.insert(auraTargetModes, sortName)
    end
end

targetModeDropdown = silentAura:CreateDropdown({
    Name = "Target mode",
    Default = "Health",
    List = auraTargetModes,
    Tooltip = "How Aura should prioritize targets",
})

targetAreaDropdown = silentAura:CreateDropdown({
    Name = "Target area",
    List = {"Center", "Closest"},
    Default = "Center",
    Visible = false,
    Tooltip = "Where the Aura will aim towards",
})

perfectSwingToggle = silentAura:CreateToggle({
    Name = "Perfect Swing",
    Function = function(enabled)
    end,
    Default = false,
    Tooltip = "Follows sword item's swing time",
})

mouseDownToggle = silentAura:CreateToggle({Name = "Require mouse down"})

dynamicHitsToggle = silentAura:CreateToggle({
    Name = "Dynamic hits",
    Default = false,
    Tooltip = "Calculates the best hitreg for you, based off how far you are to the opponent.",
})

swingOnlyToggle = silentAura:CreateToggle({Name = "Swing only"})

silentAimToggle = silentAura:CreateToggle({
    Name = "Silent Aim",
    Function = function(enabled)
        targetAreaDropdown.Object.Visible = not enabled
    end,
    Default = false,
    Tooltip = "Uses catvape's aiming technology to silently aim while looking legit",
})

showTargetToggle = silentAura:CreateToggle({
    Name = "Show target",
    Default = false,
    Function = function(enabled)
        if targetColorSlider and targetColorSlider.Object then
            targetColorSlider.Object.Visible = enabled
        end
        if attackColorSlider and attackColorSlider.Object then
            attackColorSlider.Object.Visible = enabled
        end
    end,
})

targetColorSlider = silentAura:CreateColorSlider({
    Name = "Target color",
    Darker = false,
    DefaultOpacity = 0.5,
    DefaultHue = 1,
})

attackColorSlider = silentAura:CreateColorSlider({
    Name = "Attack color",
    Darker = false,
    DefaultOpacity = 0.5,
})

limitToItemsToggle = silentAura:CreateToggle({Name = "Limit to items"})
do
    local cheatDetector
    local checks = {}

    checks.Speed = function()
        local positions = {}
        repeat
            if store.ping.incoming > 0.5 then
                task.wait(0.2)
                table.clear(positions)
            else
                for _, target in entity.List do
                    local player = target.Player
                    if player and (not positions[player] or positions[player].Time < tick()) then
                        local flatPosition = target.RootPart.Position * Vector3.new(1, 0, 1)
                        local previous = positions[player]
                        if previous then
                            local lastTeleported = player:GetAttribute("LastTeleported") or 0
                            if workspace:GetServerTimeNow() - lastTeleported > 0.4 then
                                local travelled = (flatPosition - previous.Position) / previous.Delta
                                if travelled.Magnitude > 23 then
                                    notify(
                                        "CheatDetector",
                                        player.Name .. " may be speeding (exceeded 22 studs per secs)",
                                        10,
                                        "alert"
                                    )
                                end
                            end
                        end

                        positions[player] = {
                            Time = tick() + 0.2,
                            Position = flatPosition
                        }

                        task.spawn(function()
                            positions[player].Delta = task.wait(0.2)
                        end)
                    end
                end
                task.wait()
            end
        until not cheatDetector.Enabled
    end

    checks.Killaura = function()
        local lastHit = {}
        local hits = {}

        cheatDetector:Clean(clientEvents.EntityDamageEvent.Event:Connect(function(damage)
            if damage.damageType == 0 and damage.fromEntity then
                local player = Players:GetPlayerFromCharacter(damage.fromEntity)
                if player and player ~= localPlayer then
                    if os.clock() - (lastHit[player] or 0) <= 0.28 then
                        hits[player] = (hits[player] or 0) + 1

                        task.delay(60, function()
                            if cheatDetector.Enabled and hits[player] then
                                hits[player] = math.max(hits[player] - 1, 0)
                            end
                        end)

                        if hits[player] > 2 then
                            notify(
                                "CheatDetector",
                                damage.fromEntity.Name .. " may be using killaura (went over 34 hits)",
                                10,
                                "alert"
                            )
                        end
                    end
                    lastHit[player] = os.clock()
                end
            end
        end))
    end

    checks.Reach = function()
        cheatDetector:Clean(clientEvents.EntityDamageEvent.Event:Connect(function(damage)
            if damage.damageType == 0 and damage.fromEntity then
                local player = Players:GetPlayerFromCharacter(damage.fromEntity)
                if player and player ~= localPlayer then
                    local attackerPosition = damage.fromEntity.PrimaryPart.Position
                    local victimPosition = damage.entityInstance.PrimaryPart.Position
                    local distance = (attackerPosition - victimPosition).Magnitude

                    local hand = (store.inventories[player] or {}).hand
                    local sword = hand and bedwars.ItemMeta[hand.tool.Name].sword or nil
                    local range = (sword and sword.attackRange or 14.4) + 4

                    if range * (0.99 + store.ping.total) < distance then
                        notify(
                            "CheatDetector",
                            damage.fromEntity.Name .. " may be using reach (went over 15 studs of range)",
                            10,
                            "alert"
                        )
                    end
                end
            end
        end))
    end

    local utility = vape.Categories.Utility

    cheatDetector = utility:CreateModule({
        Name = "CheatDetector",
        Function = function(enabled)
            if enabled then
                for _, check in checks do
                    task.spawn(check)
                end
            end
        end,
        Tooltip = "Detects possible cheaters in ur game"
    })

    for name in checks do
        cheatDetector:CreateToggle({
            Name = name,
            Default = false
        })
    end
end
do
    local deviceSpoofer
    local device
    local realInputType
    local realGetUserInputType

    local utility = vape.Categories.Utility

    deviceSpoofer = utility:CreateModule({
        Name = "DeviceSpoofer",
        Function = function(enabled)
            if enabled then
                realInputType = bedwars.UserInputController:getUserInputType()
                realGetUserInputType = bedwars.UserInputController.getUserInputType

                bedwars.UserInputController.getUserInputType = function()
                    return device.Value:upper()
                end

                bedwars.Handler:Get("SendUserInputType"):Fire("SendToServer", {
                    userInputType = device.Value:upper()
                })
            else
                bedwars.UserInputController.getUserInputType = realGetUserInputType

                bedwars.Handler:Get("SendUserInputType"):Fire("SendToServer", {
                    userInputType = realInputType
                })

                realGetUserInputType = nil
            end
        end,
        ExtraText = function()
        end,
        Tooltip = "Spoofs the device you show up as to the server"
    })

    device = deviceSpoofer:CreateDropdown({
        Name = "Device",
        List = {"Mobile", "PC", "Gamepad"},
        Function = function(value)
            if deviceSpoofer.Enabled then
                bedwars.Handler:Get("SendUserInputType"):Fire("SendToServer", {
                    userInputType = value:upper()
                })
            end
        end
    })
end
do
    local bedPatcher
    local placeRange
    local whitelist
    local mode
    local autoSwitch
    local limitToItem

    local function findBed()
        local origin = entity.isAlive and entity.character.RootPart.Position or Vector3.zero

        for _, bed in CollectionService:GetTagged("bed") do
            if (origin - bed.Position).Magnitude < 14 then
                local team = localPlayer:GetAttribute("Team") or -1
                if bed:GetAttribute("Team" .. team .. "NoBreak") then
                    return bed
                end
            end
        end
    end

    local function getBlock()
        if limitToItem.Enabled and store.hand.toolType == "block" then
            local handName = store.hand.tool.Name
            if table.find(whitelist.ListEnabled, handName:find("wool") and "wool" or store.hand.tool.Name) then
                return {store.hand.tool.Name}
            end
        end

        local blocks = {}

        for _, item in store.inventory.inventory.items do
            local block = bedwars.ItemMeta[item.itemType].block
            if block then
                if table.find(whitelist.ListEnabled, item.itemType:find("wool") and "wool" or item.itemType) then
                    table.insert(blocks, {item.itemType, block.health, item.tool})
                end
            end
        end

        if #blocks > 1 then
            table.sort(blocks, function(a, b)
                return a[2] > b[2]
            end)
        end

        return blocks[1] or {}
    end

    local function ringOffsets(radius, spacing)
        local offsets = {}

        for i = radius, 0, -1 do
            for j = i, 0, -1 do
                table.insert(offsets, Vector3.new(j, radius - i, i + 1 - j) * spacing)
                table.insert(offsets, Vector3.new(j * -1, radius - i, i + 1 - j) * spacing)
                table.insert(offsets, Vector3.new(j, radius - i, (i - j) * -1) * spacing)
                table.insert(offsets, Vector3.new(j * -1, radius - i, (i - j) * -1) * spacing)
            end
        end

        return offsets
    end

    local world = vape.Categories.World

    bedPatcher = world:CreateModule({
        Name = "BedPatcher",
        Function = function(enabled)
            if not enabled then
                return
            end

            while true do
                local bed = findBed()

                if bed then
                    for i = 0, 6 do
                        local up = Vector3.yAxis * (3 * i)

                        if getBlockAt(bed.Position + up) then
                            for _, offset in ringOffsets(i, 3) do
                                local blockName, _, blockTool = table.unpack(getBlock())

                                if blockName then
                                    local position = (bed.CFrame * CFrame.new(offset)).Position

                                    if not getBlockAt(position) then
                                        local rootPosition = entity.character.RootPart.Position

                                        if (rootPosition - position).Magnitude <= placeRange.Value then
                                            if autoSwitch.Enabled and getItemSlot(blockTool) then
                                                if switchItem(getItemSlot(blockTool)) then
                                                    task.wait()
                                                end
                                            end

                                            task.spawn(bedwars.placeBlock, position, blockName, false)
                                            task.wait(0.1)
                                        end
                                    end
                                end
                            end
                        else
                            local front = ((bed.CFrame + up) * CFrame.new(0, 0, 3)).Position
                            if getBlockAt(front) then
                                ringOffsets(i, 3)
                            end
                        end
                    end
                elseif mode.Value == "On Key" then
                    notify("BedPatcher", "Unable to locate bed", 5)
                    bedPatcher:Toggle()
                end

                task.wait(0.5)

                if mode.Value == "On Key" then
                    bedPatcher:Toggle()
                    break
                end

                if not bedPatcher.Enabled then
                    break
                end
            end
        end,
        Tooltip = "Automatically replaces missing blocks near bed."
    })

    mode = bedPatcher:CreateDropdown({
        Name = "Mode",
        List = {"Toggle", "On Key"},
        Default = "Toggle"
    })

    whitelist = bedPatcher:CreateTextList({
        Name = "Whitelist",
        Default = {"wool", "obsidian"}
    })

    placeRange = bedPatcher:CreateSlider({
        Name = "Place Range",
        Min = 1,
        Max = 60,
        Default = 15
    })

    bedPatcher:CreateToggle({
        Name = "Wool only",
        Tooltip = "Only uses wools to patch."
    })

    autoSwitch = bedPatcher:CreateToggle({
        Name = "Auto Switch"
    })

    limitToItem = bedPatcher:CreateToggle({
        Name = "Limit to item"
    })
end
do
    local blockIn
    local placeDelay
    local blockPriority
    local returnToLastSlot
    local woolOnly
    local blacklist

    local WALL_DIRECTIONS = {
        Vector3.new(1, 0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1),
        Vector3.new(0, 0, -1)
    }

    local blockSorters = {
        ["Lowest cost"] = function(a, b)
            return a[2] < b[2]
        end,
        Hardest = function(a, b)
            return a[2] > b[2]
        end
    }

    local function roundToGrid(position)
        return Vector3.new(
            math.floor(position.X / 3 + 0.5) * 3,
            math.floor(position.Y / 3 + 0.5) * 3,
            math.floor(position.Z / 3 + 0.5) * 3
        )
    end

    local function findSupportY(hasBlock, position, topY)
        local y = topY
        local lowestY = topY - 30

        while lowestY <= y do
            if hasBlock(roundToGrid(Vector3.new(position.X, y, position.Z))) then
                return y
            end
            y = y - 3
        end
    end

    local function collectColumn(hasBlock, origin, direction, height)
        local offsets = {}
        local base = origin + direction * 3
        local topY = origin.Y + 6
        local supportY = findSupportY(hasBlock, base, topY)
        local startY

        if supportY then
            startY = supportY + 3
        end

        local y = startY
        while y <= topY do
            table.insert(offsets, Vector3.new(direction.X * 3, y - origin.Y, direction.Z * 3))
            y = y + 3
        end

        return offsets
    end

    local function buildWallOffsets(origin, hasBlock)
        local wall = {}
        local candidates = {}

        for _, direction in ipairs(WALL_DIRECTIONS) do
            local column = collectColumn(hasBlock, origin, direction, 2)
            table.insert(candidates, {
                dir = direction,
                out = column,
                cost = #column
            })
        end

        table.sort(candidates, function(a, b)
            return a.cost < b.cost
        end)

        local best = candidates[1]
        best.out = collectColumn(hasBlock, origin, candidates[1].dir, 2)
        candidates[1].cost = #candidates[1].out

        local highestY = 0
        for _, candidate in ipairs(candidates) do
            if #candidate.out > 0 then
                local top = candidate.out[#candidate.out]
                if highestY < top.Y then
                    highestY = top.Y
                end
            end
        end

        for _, offset in ipairs(candidates[1].out) do
            table.insert(wall, offset)
        end

        table.insert(wall, Vector3.new(0, highestY, 0))

        for i = 2, #candidates do
            for _, offset in ipairs(candidates[i].out) do
                if offset.Y ~= highestY then
                    table.insert(wall, offset)
                end
            end
        end

        return wall
    end

    local function getBlocks()
        local blocks = {}

        for _, item in store.inventory.inventory.items do
            local block = bedwars.ItemMeta[item.itemType].block
            if block then
                if woolOnly.Enabled then
                    if item.itemType:find("wool") then
                        table.insert(blocks, {item.itemType, block.health, item.tool})
                    end
                elseif not table.find(blacklist.ListEnabled, item.itemType:find("wool") and "wool" or item.itemType) then
                    table.insert(blocks, {item.itemType, block.health, item.tool})
                end
            end
        end

        if #blocks > 1 then
            table.sort(blocks, blockSorters[blockPriority.Value])
        end

        return blocks
    end

    local world = vape.Categories.World

    blockIn = world:CreateModule({
        Name = "Block-In",
        Function = function(enabled)
            if not enabled then
                return
            end

            blockIn:Toggle()

            if not entity.isAlive then
                return
            end

            local lastSlot = (store.hand.tool and getItemSlot(store.hand.tool)) or 0
            local position = entity.character.RootPart.Position
            local wall = buildWallOffsets(position, getBlockAt)

            if #wall > 0 then
                for _, block in getBlocks() do
                    local slot = getItemSlot(block[3])

                    if slot then
                        switchItem(slot)

                        for _, offset in wall do
                            debugPrint(offset)

                            if entity.isAlive then
                                if not getBlockAt(position + offset) then
                                    task.spawn(bedwars.placeBlock, position + offset, block[1], false)
                                    debugPrint("yo", offset)

                                    local delay = placeDelay:GetRandomValue() / 1000
                                    if delay > 0 then
                                        task.wait(delay)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if lastSlot then
                switchItem(lastSlot)
            end
        end,
        Tooltip = "Automatically blocks you in by building walls around you"
    })

    placeDelay = blockIn:CreateTwoSlider({
        Name = "Place delay",
        Min = 1,
        Max = 250,
        DefaultMin = 30,
        DefaultMax = 50
    })

    blockPriority = blockIn:CreateDropdown({
        Name = "Block priority",
        List = {"Lowest cost", "Hardest"},
        Default = "Lowest cost"
    })

    returnToLastSlot = blockIn:CreateToggle({
        Name = "Return to last slot",
        Default = false
    })

    woolOnly = blockIn:CreateToggle({
        Name = "Wool only"
    })

    blacklist = blockIn:CreateTextList({
        Name = "Blacklist",
        Default = {"cannon", "siege_tnt", "tnt"}
    })
end
do
    local RunService = game:GetService("RunService")

    local daveyAim
    local searchRange
    local aimMode
    local launchCannon

    local raycastParams = RaycastParams.new()
    raycastParams.RespectCanCollide = false

    local minigames = vape.Categories.Minigames

    daveyAim = minigames:CreateModule({
        Name = "DaveyAim",
        Function = function(enabled)
            if not enabled then
                return
            end

            daveyAim:Toggle()

            if not entity.isAlive then
                return
            end

            local unitRay = cloneref(localPlayer:GetMouse()).UnitRay
            raycastParams.FilterDescendantsInstances = {localPlayer.Character, currentCamera}

            local hit = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000000, raycastParams)
            local aimPosition
            if hit then
                aimPosition = hit.Position
            end
            if not aimPosition then
                return
            end

            local searchDistance

            for _, block in store.blocks do
                local rootPosition = entity.character.RootPart.Position
                local distance = (rootPosition - block.Position).Magnitude

                if block.Name ~= "cannon" or not (distance < searchDistance) then
                    continue
                end

                local cannonBlockPos = bedwars.BlockController:getBlockPosition(block.Position)

                if aimMode.Value ~= "Legit" then
                    local aimRemote = bedwars.Handler:Get("AimCannonw")
                    aimRemote:Fire("SendToServer", {
                        cannonBlockPos = cannonBlockPos,
                        lookVector = CFrame.lookAt(block.Position, aimPosition).LookVector * 200
                    })

                    task.wait(0.5)

                    if launchCannon.Enabled then
                        bedwars.CannonHandController:launchSelf(block)
                    end
                else
                    block.AimPrompt:InputHoldBegin()
                    task.wait(block.AimPrompt.HoldDuration)

                    local finishTime = tick() + 0.3
                    repeat
                        local cameraCFrame = currentCamera.CFrame
                        local aimCFrame = CFrame.lookAt(currentCamera.CFrame.p, aimPosition)
                        local step = RunService.PostSimulation:Wait()
                        currentCamera.CFrame = cameraCFrame:Lerp(aimCFrame, 22 * step)

                        local aimRemote = bedwars.Handler:Get("AimCannon")
                        aimRemote:Fire("SendToServer", {
                            cannonBlockPos = cannonBlockPos,
                            lookVector = currentCamera.CFrame.LookVector
                        })
                    until finishTime < tick()

                    block.StopAimingPrompt:InputHoldBegin()
                    task.wait(block.StopAimingPrompt.HoldDuration + RunService.PostSimulation:Wait())

                    if launchCannon.Enabled then
                        block.LaunchSelfPrompt:InputHoldBegin()
                        task.wait(block.LaunchSelfPrompt.HoldDuration + RunService.PostSimulation:Wait())
                    end
                end

                return
            end
        end,
        Tooltip = "Automatically aims cannon"
    })

    aimMode = daveyAim:CreateDropdown({
        Name = "Aim Mode",
        List = {"Fast", "Legit"},
        Default = "Fast"
    })

    daveyAim:CreateDropdown({
        Name = "Position Mode",
        List = {"Mouse", "Camera"},
        Default = "Mouse"
    })

    searchRange = daveyAim:CreateSlider({
        Name = "Search Range",
        Min = 1,
        Max = 30,
        Default = 10,
        Suffix = function(value)
            return value <= 1 and "stud" or "studs"
        end
    })

    launchCannon = daveyAim:CreateToggle({
        Name = "Launch Cannon",
        Default = false
    })
end
do
    local infiniteKrystal
    local originalUpdateMomentum
    local hookedUpdateMomentum

    local minigames = vape.Categories.Minigames

    infiniteKrystal = minigames:CreateModule({
        Name = "InfiniteKrystal",
        Tooltip = "Gives you max momentum forever",
        Function = function(enabled)
            if not enabled then
                if originalUpdateMomentum then
                    if bedwars.GlacialSkaterController.updateMomentum == hookedUpdateMomentum then
                        bedwars.GlacialSkaterController.updateMomentum = originalUpdateMomentum
                    end
                end

                originalUpdateMomentum = nil
                hookedUpdateMomentum = nil
            else
                originalUpdateMomentum = bedwars.GlacialSkaterController.updateMomentum

                hookedUpdateMomentum = function(skater)
                    if infiniteKrystal.Enabled then
                        skater.momentum = 1000
                        skater.lastMomentumReport = workspace:GetServerTimeNow()
                    end
                end

                bedwars.GlacialSkaterController.updateMomentum = hookedUpdateMomentum
            end
        end
    })
end
do
    local jadeExtender
    local multiplier
    local originalUseJadeHammer
    local hookedUseJadeHammer
    local jadeHammerController

    local minigames = vape.Categories.Minigames

    local function installHook()
        while true do
            task.wait()
            if bedwars.JadeHammerController then
                break
            end
            if not jadeExtender.Enabled then
                break
            end
        end

        if not jadeExtender.Enabled then
            return
        end
        if not bedwars.JadeHammerController then
            return
        end

        local useJadeHammer = bedwars.JadeHammerController.useJadeHammer
        if typeof(useJadeHammer) ~= "function" then
            return
        end

        originalUseJadeHammer = useJadeHammer
        jadeHammerController = bedwars.JadeHammerController

        hookedUseJadeHammer = function(controller)
            local canUseAbility = bedwars.AbilityController:canUseAbility("jade_hammer_jump")

            useJadeHammer(controller)

            if jadeExtender.Enabled and canUseAbility then
                if store.equippedKit == "jade" and entity.isAlive then
                    local rootPart = entity.character.RootPart
                    local impulse = rootPart.AssemblyMass * (multiplier.Value - 1) * 20.5
                    rootPart:ApplyImpulse(Vector3.new(0, impulse, 0))
                end
            end
        end

        jadeHammerController.useJadeHammer = hookedUseJadeHammer
    end

    jadeExtender = minigames:CreateModule({
        Name = "JadeExtender",
        Function = function(enabled)
            if not enabled then
                if originalUseJadeHammer and jadeHammerController then
                    if jadeHammerController.useJadeHammer == hookedUseJadeHammer then
                        jadeHammerController.useJadeHammer = originalUseJadeHammer
                    end
                end

                originalUseJadeHammer = nil
                hookedUseJadeHammer = nil
                jadeHammerController = nil
            else
                jadeExtender:Clean(task.spawn(installHook))
            end
        end,
        Tooltip = "Extends how far the Jade Hammer jump launches you"
    })

    multiplier = jadeExtender:CreateSlider({
        Name = "Multiplier",
        Min = 1,
        Max = 5,
        Default = 2,
        Decimal = 10,
        Suffix = "x"
    })
end
do
    local phaseMine
    local ignoredParts = {}

    local function ignoreCharacter(character)
        for _, part in character:QueryDescendants("BasePart") do
            table.insert(ignoredParts, part)
            bedwars.QueryUtil:setQueryIgnored(part, false)
        end

        phaseMine:Clean(character.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                table.insert(ignoredParts, child)
                bedwars.QueryUtil:setQueryIgnored(child, false)
            end
        end))
    end

    local minigames = vape.Categories.Minigames

    phaseMine = minigames:CreateModule({
        Name = "PhaseMine",
        Function = function(enabled)
            if not enabled then
                for _, part in ignoredParts do
                    if part and part.Parent then
                        bedwars.QueryUtil:setQueryIgnored(part, false)
                    end
                end

                table.clear(ignoredParts)
            else
                phaseMine:Clean(entity.Events.EntityAdded:Connect(function(newEntity)
                    if newEntity.Player then
                        task.delay(1, ignoreCharacter, newEntity.Character)
                    end
                end))

                for _, listedEntity in entity.List do
                    if listedEntity.Character then
                        ignoreCharacter(listedEntity.Character)
                    end
                end
            end
        end,
        Tooltip = "Allows you to mine through opponents"
    })
end
do
    local voidRegentExtender
    local multiplier
    local originalUseVoidAxe
    local hookedUseVoidAxe
    local voidAxeController

    local minigames = vape.Categories.Minigames

    local function installHook()
        while true do
            task.wait()
            if bedwars.VoidAxeController then
                break
            end
            if not voidRegentExtender.Enabled then
                break
            end
        end

        if not voidRegentExtender.Enabled then
            return
        end
        if not bedwars.VoidAxeController then
            return
        end

        local useVoidAxe = bedwars.VoidAxeController.useVoidAxe
        if typeof(useVoidAxe) ~= "function" then
            return
        end

        originalUseVoidAxe = useVoidAxe
        voidAxeController = bedwars.VoidAxeController

        hookedUseVoidAxe = function(controller)
            local canUseAbility = bedwars.AbilityController:canUseAbility("void_axe_jump")

            useVoidAxe(controller)

            if voidRegentExtender.Enabled then
                if canUseAbility and store.equippedKit == "regent" and entity.isAlive then
                    local rootPart = entity.character.RootPart
                    local direction = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                    local impulse = direction * rootPart.AssemblyMass * (multiplier.Value - 1)
                    rootPart:ApplyImpulse(impulse * 70)
                end
            end
        end

        voidAxeController.useVoidAxe = hookedUseVoidAxe
    end

    voidRegentExtender = minigames:CreateModule({
        Name = "VoidRegentExtender",
        Function = function(enabled)
            if not enabled then
                if originalUseVoidAxe and voidAxeController and voidAxeController.useVoidAxe == hookedUseVoidAxe then
                    voidAxeController.useVoidAxe = originalUseVoidAxe
                end

                originalUseVoidAxe = nil
                hookedUseVoidAxe = nil
                voidAxeController = nil
            else
                voidRegentExtender:Clean(task.spawn(installHook))
            end
        end,
        Tooltip = "Extends how far the Void Regent axe dash launches you"
    })

    multiplier = voidRegentExtender:CreateSlider({
        Name = "Multiplier",
        Min = 1,
        Max = 5,
        Default = 2,
        Decimal = 10,
        Suffix = "x"
    })
end
do
    local vulcanAssist
    local targets
    local range
    local targetMode

    local minigames = vape.Categories.Minigames

    vulcanAssist = minigames:CreateModule({
        Name = "VulcanAssist",
        Function = function(enabled)
            if not enabled then
                return
            end

            repeat
                if entity.isAlive then
                    local selectedTurret = bedwars.Store:getState().Game.selectedTurret

                    if selectedTurret then
                        local origin = selectedTurret.Rotate.Position

                        local target = entity.EntityMouse({
                            Range = range.Value,
                            Origin = origin,
                            Wallcheck = targets.Walls.Enabled or nil,
                            Part = "RootPart",
                            Players = targets.Players.Enabled,
                            NPCs = targets.NPCs.Enabled,
                            Sort = targetSorts[targetMode.Value]
                        })

                        if target then
                            local airborne = target.Humanoid.FloorMaterial == Enum.Material.Air
                            if not airborne then
                                airborne = math.abs(target.RootPart.AssemblyLinearVelocity.Y) > 0.01
                            end

                            local solved = prediction.SolveTrajectory(
                                origin,
                                320,
                                10,
                                target.RootPart.Position,
                                target.RootPart.AssemblyLinearVelocity,
                                workspace.Gravity,
                                target.HipHeight,
                                nil,
                                store.airRay,
                                airborne,
                                target.RootPart.Position,
                                target.RootPart
                            )

                            if solved then
                                local offset = solved - origin

                                bedwars.TurretCameraController.angleX = math.atan2(-offset.X, -offset.Z)

                                local flat = math.sqrt(offset.X ^ 2 + offset.Z ^ 2)
                                bedwars.TurretCameraController.angleY = math.clamp(math.atan2(offset.Y, flat), -0.8, 0.8)
                            end
                        end
                    end
                end

                task.wait(0.1)
            until not vulcanAssist.Enabled
        end,
        Tooltip = "Automatically aims turret camera toward opponents"
    })

    targets = vulcanAssist:CreateTargets({
        Walls = false,
        Players = false
    })

    local sortModes = {"Distance", "Damage"}
    for sortName in targetSorts do
        if not table.find(sortModes, sortName) then
            table.insert(sortModes, sortName)
        end
    end

    targetMode = vulcanAssist:CreateDropdown({
        Name = "Target mode",
        List = sortModes,
        Default = sortModes[1]
    })

    range = vulcanAssist:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 1000,
        Default = 500
    })
end
do
    local catExtender
    local multiplier
    local originalLeap
    local hookedLeap
    local catController

    local minigames = vape.Categories.Minigames

    local function installHook()
        while true do
            task.wait()
            if bedwars.CatController then
                break
            end
            if not catExtender.Enabled then
                break
            end
        end

        if not catExtender.Enabled then
            return
        end
        if not bedwars.CatController then
            return
        end

        local leap = bedwars.CatController.leap
        if typeof(leap) ~= "function" then
            return
        end

        originalLeap = leap
        catController = bedwars.CatController

        hookedLeap = function(controller, character, direction)
            leap(controller, character, direction)

            if catExtender.Enabled and store.equippedKit == "cat" then
                if typeof(direction) == "Vector3" and 0 < direction.Magnitude then
                    local rootPart = character:FindFirstChild("HumanoidRootPart")

                    if rootPart then
                        local flatDirection = direction * Vector3.new(1, 0, 1)

                        if 0 < flatDirection.Magnitude then
                            local impulse = flatDirection.Unit * rootPart.AssemblyMass * (multiplier.Value - 1)
                            rootPart:ApplyImpulse(impulse * 70)
                        end
                    end
                end
            end
        end

        catController.leap = hookedLeap
    end

    catExtender = minigames:CreateModule({
        Name = "CatExtender",
        Function = function(enabled)
            if not enabled then
                if originalLeap and catController then
                    if catController.leap == hookedLeap then
                        catController.leap = originalLeap
                    end
                end

                originalLeap = nil
                hookedLeap = nil
                catController = nil
                return
            end

            catExtender:Clean(task.spawn(installHook))
        end,
        Tooltip = "Extends how far the Cat/Yamini pounce launches you"
    })

    multiplier = catExtender:CreateSlider({
        Name = "Multiplier",
        Min = 1,
        Max = 5,
        Default = 2,
        Decimal = 10,
        Suffix = "x"
    })
end
do
    local yuziExtender
    local multiplier
    local originalDashForward
    local hookedDashForward
    local daoController

    local minigames = vape.Categories.Minigames

    local function installHook()
        while true do
            task.wait()
            if bedwars.DaoController then
                break
            end
            if not yuziExtender.Enabled then
                break
            end
        end

        if not yuziExtender.Enabled then
            return
        end
        if not bedwars.DaoController then
            return
        end

        local dashForward = bedwars.DaoController.dashForward
        if typeof(dashForward) ~= "function" then
            return
        end

        originalDashForward = dashForward
        daoController = bedwars.DaoController

        hookedDashForward = function(controller, direction)
            dashForward(controller, direction)

            if yuziExtender.Enabled and store.equippedKit == "dasher" and entity.isAlive then
                if typeof(direction) == "Vector3" then
                    local rootPart = entity.character.RootPart
                    local flatDirection = direction * Vector3.new(1, 0, 1)

                    if 0 < flatDirection.Magnitude then
                        local impulse = flatDirection.Unit * rootPart.AssemblyMass * (multiplier.Value - 1)
                        rootPart:ApplyImpulse(impulse * 70)
                    end
                end
            end
        end

        daoController.dashForward = hookedDashForward
    end

    yuziExtender = minigames:CreateModule({
        Name = "YuziExtender",
        Function = function(enabled)
            if not enabled then
                if originalDashForward and daoController and daoController.dashForward == hookedDashForward then
                    daoController.dashForward = originalDashForward
                end

                originalDashForward = nil
                hookedDashForward = nil
                daoController = nil
            else
                yuziExtender:Clean(task.spawn(installHook))
            end
        end,
        Tooltip = "Extends how far the yuzi dash launches you."
    })

    multiplier = yuziExtender:CreateSlider({
        Name = "Multiplier",
        Min = 1,
        Max = 5,
        Default = 2,
        Decimal = 10,
        Suffix = "x"
    })
end
if vape and vape.Loaded ~= nil then
    vape.Init = nil
    vape:Load()
end
