local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Conch = require(ReplicatedStorage.Packages.Conch)
local ItemType = require(ReplicatedStorage.Shared.Types.ItemType)

return Conch.args.enum_from_map("ItemEnum", ItemType)