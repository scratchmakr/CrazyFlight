local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DamageFormat = require(ReplicatedStorage.Shared.Formats.DamageFormat)
local EquipmentUtil = require(ReplicatedStorage.Shared.Utilities.Equipment.EquipmentUtil)

local DamageUtil = {}

function DamageUtil.calculateBallisticDamage(damageContext: DamageFormat.ballisticDamageContext)
    local damage = 0
    local raycastResult = damageContext.raycastResult
    local raycastInstance = raycastResult and raycastResult.Instance
    local equipmentType = damageContext.equipmentType
    local equipmentMetadata = EquipmentUtil.getMetadata(equipmentType)
    local ballisticInfo = equipmentMetadata and equipmentMetadata.ballisticInfo
    local headshotMultiplier = ballisticInfo and ballisticInfo.headshotMultiplier or 1
    if not (headshotMultiplier and raycastInstance) then
        return damage, false
    end

    local equipmentDamage = equipmentMetadata.damage
    local isHead = raycastInstance.Name == "Head"
    damage = equipmentDamage * (isHead and headshotMultiplier or 1)
    
    return damage, isHead
end

return DamageUtil