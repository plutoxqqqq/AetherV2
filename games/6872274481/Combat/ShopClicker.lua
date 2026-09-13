run(function()
    local ShopQuickBuy
    local HoldDelay
    local CPS
    local purchaseSounds = {}

    local holding = false
    local clickThread

    
    
    
    
    local function playPurchaseSound()
        local sound = Instance.new('Sound')
        sound.Name = 'AetherShopPurchase'
        sound.SoundId = bedwars.SoundList.BEDWARS_PURCHASE_ITEM
        sound.Parent = gameCamera
        purchaseSounds[sound] = true
        sound.Ended:Once(function()
            purchaseSounds[sound] = nil
            sound:Destroy()
        end)
        sound:Play()
        task.delay(10, function()
            if purchaseSounds[sound] then
                purchaseSounds[sound] = nil
                sound:Destroy()
            end
        end)
    end

    local function getShopId()
        if not entitylib.isAlive then return nil end
        local localPosition = entitylib.character.RootPart.Position
        local id
        for _, v in store.shop do
            if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
                id = v.Id
            end
        end
        return id
    end

    local function getHoveredItem()
        local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
        for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
            local obj = v
            while obj and obj ~= lplr.PlayerGui do
                local itemType = obj.Name:match('^(.+)_ShopItemCard$')
                if itemType then
                    return itemType
                end
                obj = obj.Parent
            end
        end
    end

    local function canBuy(item)
        if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
        if item.lockedByForge or item.disabled then return false end
        if item.require and item.require.teamUpgrade then
            if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
                return false
            end
        end
        local currency = getItem(item.currency)
        return (currency and currency.amount or 0) >= item.price
    end

    local function purchase(itemType, shopId)
        if bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] ~= nil then return end

        local item = bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
        if not item or not canBuy(item) then return end

        bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
            shopItem = item,
            shopId = shopId
        }):andThen(function(suc)
            if not suc then return end
            playPurchaseSound()
            bedwars.Store:dispatch({
                type = 'BedwarsAddItemPurchased',
                itemType = itemType
            })
            if item.tiered then
                bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] = true
            end
        end)
    end

    local function startClicking(itemType)
        if clickThread then
            task.cancel(clickThread)
        end
        clickThread = task.spawn(function()
            repeat
                local shopId = bedwars.AppController:isAppOpen('BedwarsItemShopApp') and store.shopLoaded and getShopId()
                if shopId then
                    purchase(itemType, shopId)
                end
                task.wait(1 / CPS.Value)
            until not holding
            clickThread = nil
        end)
    end

    ShopQuickBuy = vape.Categories.Combat:CreateModule({
        Name = 'ShopClicker',
        Function = function(callback)
            if callback then
                ShopQuickBuy:Clean(inputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    if not bedwars.AppController:isAppOpen('BedwarsItemShopApp') then return end

                    local itemType = getHoveredItem()
                    if not itemType then return end

                    holding = true
                    task.delay(HoldDelay.Value, function()
                        if holding and getHoveredItem() == itemType then
                            startClicking(itemType)
                        end
                    end)
                end))

                ShopQuickBuy:Clean(inputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        holding = false
                    end
                end))
            else
                holding = false
                if clickThread then
                    task.cancel(clickThread)
                    clickThread = nil
                end
                for sound in purchaseSounds do
                    sound:Destroy()
                    purchaseSounds[sound] = nil
                end
            end
        end,
        Tooltip = 'Hold on a shop item to rapidly buy it'
    })
    HoldDelay = ShopQuickBuy:CreateSlider({
        Name = 'Hold Delay',
        Min = 0,
        Max = 1,
        Default = 0.15,
        Decimal = 20,
        Suffix = 'seconds'
    })
    CPS = ShopQuickBuy:CreateSlider({
        Name = 'CPS',
        Min = 1,
        Max = 20,
        Default = 20,
        Darker = true
    })
end)
