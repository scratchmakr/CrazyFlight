local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Vide = require(ReplicatedStorage.Packages.Vide)
local InfiniteGradient = require(ReplicatedStorage.Shared.Utilities.InfiniteGradient)


export type Context = {
    components: {
        [GuiObject]: boolean,
    },
    gradientColor: ColorSequence,
    showAnimation: Vide.source<boolean>?,
    period: number?,
    trove: Trove.Trove?,
}

return function(context: Context)
    local components = context.components
    local gradientColor = context.gradientColor
    local showAnimation = context.showAnimation
    local period = context.period
    local trove = context.trove

    for component, isEnabled in components do
        local gradient = component:FindFirstChildOfClass("UIGradient")
        if component:IsA("UIGradient") then
            gradient = component
        end
        if not gradient then
            continue
        end

        gradient.Color = gradientColor

        if not isEnabled then
            continue
        end
        
        local infiniteGradient = InfiniteGradient:CreateEffect({
            Gradient = gradient,
            Show = showAnimation,
            Period = period,
        })

        Vide.cleanup(function()
            infiniteGradient:Dispose()
        end)

        if trove then
            trove:Add(function()
                infiniteGradient:Dispose()
            end)
        end
    end
end