run(function()
    local KillfeedSpoofer
    local KillerName
    local VictimName
    local WeaponName
    local MessageText
    local oldkillfeed

    local function formatKillfeedText(value)
        return value
            :gsub('{killer}', KillerName.Value)
            :gsub('{victim}', VictimName.Value)
            :gsub('{weapon}', WeaponName.Value)
    end

    -- Returns the edited replacement for a single string field (or the original if it
    -- shouldn't be touched). Never allocates tables, so entry structure is preserved.
    local function spoofString(value, key, depth)
        if type(value) ~= 'string' then return value end
        if value:find('{killer}') or value:find('{victim}') or value:find('{weapon}') then
            return formatKillfeedText(value)
        end
        local keyText = key and tostring(key):lower() or ''
        if keyText:find('killer') then return KillerName.Value end
        if keyText:find('victim') then return VictimName.Value end
        if keyText:find('weapon') then return WeaponName.Value end
        if depth == 0 or keyText == 'message' or keyText == 'text' or (keyText:find('kill') and keyText:find('text')) then
            return formatKillfeedText(MessageText.Value)
        end
        return value
    end

    -- Edits the killfeed entry data IN PLACE. The previous version deep-copied the
    -- whole argument tree, which dropped the killfeed object's references/metatables so
    -- the entry rendered as blank - i.e. it *removed* the killfeed instead of editing it.
    -- Mutating the existing tables keeps the entry intact and simply rewrites its text.
    local function spoofInPlace(value, depth, seen)
        if type(value) ~= 'table' or depth > 4 then return end
        seen = seen or {}
        if seen[value] then return end
        seen[value] = true
        for i, v in value do
            if type(v) == 'string' then
                value[i] = spoofString(v, i, depth)
            elseif type(v) == 'table' then
                spoofInPlace(v, depth + 1, seen)
            end
        end
    end

    KillfeedSpoofer = vape.Categories.Legit:CreateModule({
        Name = 'KillfeedSpoofer',
        Function = function(callback)
            if callback and not oldkillfeed then
                oldkillfeed = bedwars.KillFeedController.addToKillFeed
                bedwars.KillFeedController.addToKillFeed = function(self, ...)
                    local args = {...}
                    -- Guarded so a failure can never swallow the entry: the original
                    -- addToKillFeed always runs, editing it locally when possible.
                    pcall(function()
                        local seen = {}
                        for i, v in args do
                            if type(v) == 'string' then
                                args[i] = spoofString(v, i, 0)
                            elseif type(v) == 'table' then
                                spoofInPlace(v, 1, seen)
                            end
                        end
                    end)
                    return oldkillfeed(self, table.unpack(args))
                end
            elseif oldkillfeed then
                bedwars.KillFeedController.addToKillFeed = oldkillfeed
                oldkillfeed = nil
            end
        end,
        Tooltip = 'Locally edits killfeed messages (names/weapon/text) without removing them'
    })
    KillerName = KillfeedSpoofer:CreateTextBox({
        Name = 'Killer',
        Default = lplr.DisplayName
    })
    VictimName = KillfeedSpoofer:CreateTextBox({
        Name = 'Victim',
        Default = 'Enemy'
    })
    WeaponName = KillfeedSpoofer:CreateTextBox({
        Name = 'Weapon',
        Default = 'Sword'
    })
    MessageText = KillfeedSpoofer:CreateTextBox({
        Name = 'Message',
        Default = '{killer} eliminated {victim} with {weapon}'
    })
end)