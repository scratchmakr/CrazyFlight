local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityType = require(ReplicatedStorage.Shared.Types.RarityType)

local AssetsFolder = ReplicatedStorage.Assets
local UIAssets = AssetsFolder.UI
local RarityGradients = UIAssets.RarityGradients
local VFXFolder = AssetsFolder.VFX
local RarityVFXFolder = VFXFolder.Rarities

export type RarityInfo = {
    name: string,
    color: ColorSequence,
    prefabs: {
        vfx: BasePart?,
    }?,
    rotation: number,
    order: number?,
}

local order = 0
local function build(metadata: RarityInfo)
    order += 1
    metadata.order = order
    return metadata
end

local Rarities = {}
Rarities.METADATA = {
    [RarityType.COMMON] = build({
        name = "Common",
        color = RarityGradients.Common.Color,
        rotation = RarityGradients.Common.Rotation,
        prefabs = {
            vfx = RarityVFXFolder.Common,
        },
    }),
    [RarityType.RARE] = build({
        name = "Rare",
        color = RarityGradients.Rare.Color,
        rotation = RarityGradients.Rare.Rotation,
        prefabs = {
            vfx = RarityVFXFolder.Rare,
        },
    }),
    [RarityType.EPIC] = build({
        name = "Epic",
        color = RarityGradients.Epic.Color,
        rotation = RarityGradients.Epic.Rotation,
        prefabs = {
            vfx = RarityVFXFolder.Epic,
        },
    }),
    [RarityType.LEGENDARY] = build({
        name = "Legendary",
        color = RarityGradients.Legendary.Color,
        rotation = RarityGradients.Legendary.Rotation,
        prefabs = {
            vfx = RarityVFXFolder.Legendary,
        },
    }),
    [RarityType.GODLY] = build({
        name = "Godly",
        color = RarityGradients.Godly.Color,
        rotation = RarityGradients.Godly.Rotation,
        prefabs = {
            vfx = RarityVFXFolder.Godly,
        },
    }),
    [RarityType.SECRET] = build({
        name = "Secret",
        color = RarityGradients.Secret.Color,
        rotation = RarityGradients.Secret.Rotation,
    }),
    [RarityType.ULTRA] = build({
        name = "Ultra",
        color = RarityGradients.Ultra.Color,
        rotation = RarityGradients.Ultra.Rotation,
        prefabs = {
            vfx = RarityVFXFolder.Ultra,
        },
    }),
} :: { [string]: RarityInfo }

return Rarities