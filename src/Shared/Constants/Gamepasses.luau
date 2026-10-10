local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GamepassType = require(ReplicatedStorage.Shared.Types.GamepassType)
local ItemType = require(ReplicatedStorage.Shared.Types.ItemType)
local PerformType = require(ReplicatedStorage.Shared.Types.PerformType)

export type Metadata = {
    name: string,
    gamepassId: number,
    giftProductId: number?,
    altGamepassType: string?,
    perform: PerformType.Perform?,
    isProduct: boolean?,
    maxPurchases: number?,
    isPaidRandomItem: boolean?,
}

export type PurchaseKind = "Product" | "GamePass" | "GiftProduct"

export type PurchaseInfo = {
    gamepassType: string,
    purchaseKind: PurchaseKind,
}

export type Structure = { [string]: Metadata }

local Gamepasses = {}

Gamepasses.METADATA = {
    [GamepassType.VIP] = {
        name = "VIP",
        gamepassId = 1963680317,
        perform = {},
        isProduct = false,
        isPaidRandomItem = false,
    },
} :: Structure

function Gamepasses.getMetadata(gamepassType: string): Metadata?
    return typeof(gamepassType) == "string" and Gamepasses.METADATA[gamepassType]
end

function Gamepasses.getPaymentProductId(gamepassType: string, isGift: boolean?): number?
    local metadata = Gamepasses.getMetadata(gamepassType)
    if not metadata then
        return nil
    end

    if isGift then
        return metadata.giftProductId
    end

    if metadata.isProduct then
        return metadata.gamepassId
    end

    return metadata.gamepassId
end

function Gamepasses.getPurchaseInfoByRobloxId(robloxId: number): PurchaseInfo?
    for gamepassType, meta in Gamepasses.METADATA do
        if meta.giftProductId == robloxId then
            return {
                gamepassType = gamepassType,
                purchaseKind = "GiftProduct",
            }
        end
    end

    for gamepassType, meta in Gamepasses.METADATA do
        if meta.gamepassId == robloxId then
            return {
                gamepassType = gamepassType,
                purchaseKind = if meta.isProduct then "Product" else "GamePass",
            }
        end
    end

    return nil
end

function Gamepasses.getTypeByRobloxId(robloxId: number): string?
    local purchaseInfo = Gamepasses.getPurchaseInfoByRobloxId(robloxId)
    return purchaseInfo and purchaseInfo.gamepassType
end

function Gamepasses.getTypeByGiftProductId(productId: number): string?
    for gamepassType, meta in Gamepasses.METADATA do
        if meta.giftProductId == productId then
            return gamepassType
        end
    end
    return nil
end

function Gamepasses.getPrice(gamepassType: string): number?
    -- get gamepassinfo async api
    local metadata = Gamepasses.getMetadata(gamepassType)
    if not metadata then
        return nil
    end
    local gamepassId = metadata.gamepassId
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfoAsync(gamepassId, Enum.AssetType.GamePass)
    end)
    if not success then
        return nil
    end

    local price = info.PriceInRobux
    return price
end

return Gamepasses