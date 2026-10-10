local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Equipment = require(ReplicatedStorage.Shared.Constants.Equipment)
local EquipmentDataFormat = require(ReplicatedStorage.Shared.Formats.EquipmentDataFormat)
local EquipmentUtil = {}

function EquipmentUtil.getMetadata(equipmentType: string): EquipmentDataFormat.EquipmentInfo?
    for tabType, equipmentList in Equipment.METADATA do
        local metadata = equipmentList[equipmentType]
        if metadata then
            return metadata
        end
    end
    return nil
end

function EquipmentUtil.getTabType(equipmentType: string): string?
    for tabType, equipmentList in Equipment.METADATA do
        local metadata = equipmentList[equipmentType]
        if metadata then
            return tabType
        end
    end
    return nil
end

function EquipmentUtil.isPassive(equipmentType: string): boolean
    local metadata = EquipmentUtil.getMetadata(equipmentType)
    if metadata then
        return metadata.isPassive
    end
    return false
end

return EquipmentUtil