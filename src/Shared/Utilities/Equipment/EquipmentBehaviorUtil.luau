local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipmentBehaviors = require(ReplicatedStorage.Shared.Classes.EquipmentBehaviors)
local BehaviorFormat = require(ReplicatedStorage.Shared.Formats.BehaviorFormat)
local EquipmentBehaviorUtil = {}

function EquipmentBehaviorUtil.getBehavior(equipmentType: string): BehaviorFormat.BehaviorClass?
    return EquipmentBehaviors.CLASSES[equipmentType]
end

return EquipmentBehaviorUtil