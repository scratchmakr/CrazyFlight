local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemType = require(ReplicatedStorage.Shared.Types.ItemType)
local RarityType = require(ReplicatedStorage.Shared.Types.RarityType)
local Items = {}

export type Metadata = {
    name: string,
    rarity: string,
    image: string,
    hidden: true?,
}
export type Structure = {[string]: Metadata}

Items.METADATA = {
    [ItemType.MONEY] = {
        name = "Money",
        rarity = RarityType.GODLY,
        image = "rbxassetid://92308919283613",
    },

    [ItemType.XP] = {
        name = "XP",
        rarity = RarityType.GODLY,
        image = "rbxassetid://76296981164072",
    },
} :: Structure

return Items