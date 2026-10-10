local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Rarities = require(ReplicatedStorage.Shared.Constants.Rarities)
local RarityUtil = require(ReplicatedStorage.Shared.Utilities.RarityUtil)
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local ApplyGradient = require(StarterPlayer.StarterPlayerScripts.Client.Utility.ApplyGradient)
local ResponsiveButton = require(StarterPlayer.StarterPlayerScripts.Client.Utility.button.ResponsiveButton)

local FRAME = UIContainer.Components.Slot

export type props = {
    name: string,
    rarity: string,
    image: string?,
    amount: (Vide.Source<number> | number)?,
    show: Vide.Source<boolean>,
    darken: Vide.Source<boolean>?,
}

return function(props: props)
    local name = props.name
    local rarity = props.rarity
    local image = props.image
    local amount = props.amount or Vide.source(0)
    local show = props.show
    local darken = props.darken
    
    local newSlot = ResponsiveButton({
        Button = FRAME:Clone(),
    })

    local innerFrame = newSlot.Inner
    local mainTitle = innerFrame.Title
    local amountTitle = innerFrame.Amount
    local icon = innerFrame.Icon
    local blackFrame = newSlot.BlackFrame

    local mainGlow = newSlot.Glow
    local colorSequence = RarityUtil.getColorSequence(rarity)
    
    ApplyGradient({
        components = {
            [innerFrame.UIGradient] = true,
            [innerFrame.UIStroke.UIGradient] = true,
            [innerFrame.Textures.Halftone.UIGradient] = true,
            [mainGlow.UIGradient] = true,
        },
        gradientColor = colorSequence,
        showAnimation = show,
        period = 2,
    })

    Vide.apply(blackFrame) {
        Visible = if darken then Vide.derive(function()
            return darken()
        end) else nil
    }

    Vide.apply(amountTitle) {
        Text = Vide.derive(function()
            local isNumber = typeof(amount) == "number"
            local amountValue = isNumber and amount or amount()
            return amountValue and `{amountValue}x` or ""
        end),
        Visible = Vide.derive(function()
            local isNumber = typeof(amount) == "number"
            local amountValue = isNumber and amount or amount()
            return amountValue and amountValue > 0 or false
        end),
    }

    Vide.apply(mainTitle) {
        Text = name,
    }

    Vide.apply(icon) {
        Image = image,
    }

    return newSlot
end