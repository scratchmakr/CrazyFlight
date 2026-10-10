local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gt = require(ReplicatedStorage.Packages.gt)
local TrackedStatType = require(ReplicatedStorage.Shared.Types.TrackedStatType)

export type Structure = { [string]: number }
local TrackedStats = {}
TrackedStats.TEMPLATE = {} :: Structure

for _, statType in TrackedStatType do
	TrackedStats.TEMPLATE[statType] = 0
end

TrackedStats.DataCheck = gt.build(gt.dictionary(gt.string(), gt.number()))

return TrackedStats
