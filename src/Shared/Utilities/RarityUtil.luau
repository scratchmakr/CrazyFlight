local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = require(ReplicatedStorage.Shared.Constants.Assets)
local Rarities = require(ReplicatedStorage.Shared.Constants.Rarities)
local RarityGradients = Assets.UI.RarityGradients

local RarityUtil = {}

function RarityUtil.getMetadata(rarity: string): Rarities.RarityInfo?
    local metadata = Rarities.METADATA[rarity]
    return metadata
end

function RarityUtil.getColorSequence(rarity: string): ColorSequence?
    local metadata = RarityUtil.getMetadata(rarity)
    return metadata and metadata.color or RarityGradients.Nothing.Color
end

return RarityUtil