local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local RarityUtil = require(script.Parent.RarityUtil)
local Items = require(ReplicatedStorage.Shared.Constants.Items)
local InventoryTabType = require(ReplicatedStorage.Shared.Types.InventoryTabType)
local ItemType = require(ReplicatedStorage.Shared.Types.ItemType)

export type ItemMetadata = Consumables.ConsumableInfo | CosmeticsFormat.CosmeticInfo?
local ItemUtil = {
    _itemMetadatas = {
        [InventoryTabType.INVENTORY] = Items.METADATA,
    } :: {
        [Tab]: ItemMetadata,
    }
}

function ItemUtil.getMetadata(item: string): ItemMetadata?
    for tabType, metadata in ItemUtil._itemMetadatas do
        local itemMetadata = metadata[item]
        if itemMetadata then
            return itemMetadata
        end
    end
    return nil
end

function ItemUtil.getTabType(item: string): Tab?
    for tabType, metadata in ItemUtil._itemMetadatas do
        local itemMetadata = metadata[item]
        if itemMetadata then
            return tabType
        end
    end
    return nil
end

function ItemUtil.itemIsEquippable(item: string): boolean
    local tabType = ItemUtil.getTabType(item)
    if tabType == InventoryTabType.FOOTBALLS or tabType == InventoryTabType.FINISHERS or tabType == InventoryTabType.IMPACTFX then
        return true
    end
    return false
end

function ItemUtil.isCosmetic(item: string): boolean
    local tabType = ItemUtil.getTabType(item)
    if tabType == InventoryTabType.FOOTBALLS or tabType == InventoryTabType.FINISHERS or tabType == InventoryTabType.IMPACTFX then
        return true
    end
    return false
end

function ItemUtil.orderByRarity(items: { string }): { string }
    local orderedItems = table.clone(items)
    table.sort(orderedItems, function(a, b)
        local aMetadata = ItemUtil.getMetadata(a)
        local bMetadata = ItemUtil.getMetadata(b)
        local aRarity = aMetadata and aMetadata.rarity
        local bRarity = bMetadata and bMetadata.rarity
        local aRarityMetadata = aRarity and RarityUtil.getMetadata(aRarity)
        local bRarityMetadata = bRarity and RarityUtil.getMetadata(bRarity)
        if aRarityMetadata.order == bRarityMetadata.order then
            return a < b
        end
        
        return aRarityMetadata.order > bRarityMetadata.order
    end)
    return orderedItems
end

function ItemUtil.formatRewards(rewards: { [string]: number }): { {
    itemType: string,
    amount: number,
} }
    local formattedRewards = {}
    local orderedRewards = ItemUtil.orderByRarity(RblxUtils.Table.keys(rewards))
    for _, itemType in orderedRewards do
        local amount = rewards[itemType]
        table.insert(formattedRewards, {
            itemType = itemType,
            amount = amount,
        })
    end

    return formattedRewards
end

return ItemUtil