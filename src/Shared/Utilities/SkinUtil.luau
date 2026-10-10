local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Skins = require(ReplicatedStorage.Shared.Constants.Skins)

local SkinUtil = {}

function SkinUtil.getSkinMetadata(skinType: string)
    return Skins.METADATA[skinType]
end

return SkinUtil