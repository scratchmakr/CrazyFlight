local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LuckyBlockFormat = require(script.Parent.LuckyBlockFormat)
local Equipment = require(ReplicatedStorage.Shared.Classes.Equipment)
local BehaviorFormat = require(ReplicatedStorage.Shared.Formats.BehaviorFormat)
export type EquipmentInfo = {
    priority: number,
    equipped: boolean,
    equipmentClass: Equipment.Self?,
}
export type AddEquipmentContext = {
    rollContext: {string}?,
    equipmentType: string?,
    override: boolean?,
    priority: number?,
    behaviorClass: BehaviorFormat.Behavior?,
}
export type ToggleEquipmentContext = {
    tabType: string,
    timestamp: number?,
    isEquip: boolean?,
}

export type InventoryItemToggledContext = {
    equipmentType: string,
    isEquipped: boolean,
}

export type RemoveEquipmentContext = {
    equipmentType: string,
}

return {}