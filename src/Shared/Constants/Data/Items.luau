local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local gt = require(ReplicatedStorage.Packages.gt)
local ItemType = require(ReplicatedStorage.Shared.Types.ItemType)

export type Structure = { [string]: number? }

local Items = {}
Items.TEMPLATE = {}

if RunService:IsStudio() then
	for _, name in ItemType do
		-- Items.TEMPLATE[name] = 1000000000
	end
end

Items.DataCheck = gt.build(gt.dictionary(gt.string(), gt.optional(gt.number())))

return Items
