run(function()
    local util = vape.Libraries.bedwarsutil

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
        return util.Shop.Id('item')
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
        return util.Shop.CanBuy(item)
    end

    local function purchase(itemType, shopId)
        if util.Shop.Owned(itemType) then return end

        local item = util.Shop.Item(itemType, shopId)
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
                local shopId = util.Shop.ItemScreenOpen() and store.shopLoaded and getShopId()
                if shopId then
                    purchase(itemType, shopId)
                end
                task.wait(1 / CPS.Value)
            until not holding
            clickThread = nil
        end)
    end

    ShopQuickBuy = vape.Categories.Utility:CreateModule({
        Name = 'ShopClicker',
        Function = function(callback)
            if callback then
                ShopQuickBuy:Clean(inputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    if not util.Shop.ItemScreenOpen() then return end

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
