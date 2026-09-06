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

    LARPKits = vape.Categories.Render:CreateModule({
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
