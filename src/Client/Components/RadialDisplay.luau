local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local FRAME = UIContainer.Components.RadialCrop

export type Props = {
    frame: typeof(FRAME)?,
    chargeRatioComputed: Fusion.Computed<number>,
}

return function(props: Props)
    local frame = props.frame or FRAME:Clone()
    local chargeRatioComputed = props.chargeRatioComputed
    
    local radialLeftCrop = frame.LeftCrop
    local radialLeftBar = radialLeftCrop.Bar
    local leftGradient = radialLeftBar.UIGradient
    local radialRightCrop = frame.RightCrop
    local radialRightBar = radialRightCrop.Bar
    local rightGradient = radialRightBar.UIGradient

    Fusion.Hydrate(radialLeftBar) {
        Visible = Fusion.Computed(function()
            local chargeRatio = math.round(chargeRatioComputed:get() * 100)
            return chargeRatio > 50
        end),
    }

    Fusion.Hydrate(radialRightBar) {
        Visible = Fusion.Computed(function()
            local chargeRatio = math.round(chargeRatioComputed:get() * 100)
            return chargeRatio > 0
        end),
    }

    Fusion.Hydrate(leftGradient) {
        Rotation = Fusion.Computed(function()
            local chargeRatio = chargeRatioComputed:get()
            if chargeRatio < 0.5 then
                return -180
            end
            return (1 - chargeRatio) * -180 * 2
        end),
    }
    
    Fusion.Hydrate(rightGradient) {
        Rotation = Fusion.Computed(function()
            local chargeRatio = math.min(chargeRatioComputed:get(), 0.5)
            return chargeRatio * 180 * 2
        end),
    }

end