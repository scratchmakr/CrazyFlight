local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UIConfigs = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIConfigs)
local PageController = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.PageController)
local PageTypes = require(StarterPlayer.StarterPlayerScripts.Client.Types.PageTypes)
local ResponsiveButton = require(StarterPlayer.StarterPlayerScripts.Client.Utility.button.ResponsiveButton)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfiniteGradient = require(ReplicatedStorage.Shared.Utilities.InfiniteGradient)
export type props = {
    frame: Frame,
    show: Fusion.Computed<boolean>,
    positions: {
        hide: UDim2,
        show: UDim2,
    },
    
    noInfiniteGradient: boolean?,
    onExit: () -> ()?, -- when the page is closed by button
    onShow: () -> ()?,
    onHide: () -> ()?,
}

return function(props: props)
    local frame = props.frame
    local position = props.positions
    local hidePosition = position.hide
    local showPosition = position.show

    local onExit = props.onExit
    local onShow = props.onShow
    local onHide = props.onHide

    local noInfiniteGradient = props.noInfiniteGradient

    if not noInfiniteGradient then
        for i = 1, 4 do
            local colorControlName = `ColorControl{i}`
            local colorGradient = frame:FindFirstChild(colorControlName, true)
            if colorGradient and colorGradient:IsA("UIGradient") then
                InfiniteGradient:CreateEffect({
                    Gradient = colorGradient,
                    Show = props.show,
                })
            end
        end
    end

    local closeButton = frame:FindFirstChild("CloseButton", true)
    if closeButton and closeButton:IsA("ImageButton") then
        Fusion.Hydrate(ResponsiveButton({
            Button = closeButton,
            HoverScale = 1.1,
            ClickScale = 0.9,
        })) {
            [Fusion.OnEvent("Activated")] = function()
                if typeof(onExit) == "function" then
                    onExit()
                end
                PageController.setPage(PageTypes.LANDING)
            end,
        }
    end

    return Fusion.Hydrate(frame) {
        Position = Fusion.Spring(Fusion.Computed(function()
            local show = props.show:get()
            if show and onShow then
                onShow()
            elseif not show and onHide then
                onHide()
            end
            return show and showPosition or hidePosition
        end), UIConfigs.Speed, UIConfigs.Damping)
    }
end