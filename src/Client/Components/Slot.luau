local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralSlot = require(script.Parent.GeneralSlot)
local Viewport = require(script.Parent.Viewport)
local Vide = require(ReplicatedStorage.Packages.Vide)
local EquipmentUtil = require(ReplicatedStorage.Shared.Utilities.Equipment.EquipmentUtil)

export type Context = {
    slotType: string,
    show: Vide.Source<boolean>,
    selected: Vide.Source<boolean>,
}

return function(context: Context)
    local show = context.show
    local selected = context.selected
    local slotType = context.slotType
    
    local equipmentMetadata = EquipmentUtil.getMetadata(slotType)

    local slotProps: GeneralSlot.props & {
        viewportInfo: {
            cframeOffset: CFrame?,
            viewmodel: Model?,
        },
    } = {
        name = nil :: string?,
        rarity = nil :: string?,
        viewportInfo = {
            cframeOffset = CFrame.new(),
            viewmodel = nil :: Model?,
        },
        show = show,
    }

    if equipmentMetadata then
        slotProps.name = equipmentMetadata.name
        slotProps.rarity = equipmentMetadata.rarity
        local viewportInfo = slotProps.viewportInfo
        viewportInfo.viewmodel = equipmentMetadata.prefabs.viewmodel
        viewportInfo.cframeOffset = viewportInfo and viewportInfo.cframeOffset or CFrame.new()
    end

    local slot = GeneralSlot(slotProps)
    local innerFrame = slot.Inner
    local viewportInfo = slotProps.viewportInfo
    if viewportInfo then
        local viewmodel = viewportInfo.viewmodel
        local cframeOffset = viewportInfo.cframeOffset
        Viewport({
            viewmodel = viewmodel,
            viewportFrame = innerFrame.ViewportFrame,
            cframeOffset = cframeOffset,
        })
        innerFrame.Icon.Visible = false
    end

    return slot
end