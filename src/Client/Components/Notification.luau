local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Spring = require(ReplicatedStorage.Packages.Spring)

local NotificationCenter = UIContainer.Screens.TopCenterContainer.NotificationCenter
local NotificationTemplate = NotificationCenter.NotificationTemplate
local ThemesFolder = NotificationCenter.Themes

export type notificationProps = {
    message: string,
    type: "success" | "error" | "warning",
    duration: number?,
    parent: Instance?,
}

return function(props: notificationProps)

    local message = props.message
    local type = props.type
    local parent = props.parent
    local duration = props.duration or 3

    if typeof(type) == "boolean" then
        type = type and "success" or "error"
    end
    
    local themeGradient = ThemesFolder:FindFirstChild(type)
    if not themeGradient then
        warn(`Could not find theme gradient for {type}!`)
        return
    end

    local showing = Fusion.Value(false)
    local newNotification = Fusion.Hydrate(NotificationTemplate:Clone()) {
        Size = Fusion.Spring(Fusion.Computed(function()
            return showing:get() and UDim2.fromScale(1, 0.1) or UDim2.fromScale(1, 0)
        end), 18, 0.4),
        Visible = true,
        Parent = parent,
    }
    
    local title = newNotification.Title
    local titleGradient = title:FindFirstChildOfClass("UIGradient")
    titleGradient.Color = themeGradient.Color
    Fusion.Hydrate(title) {
        Text = message,
        Rotation = -7,
    }
    showing:set(true)
    Spring.target(title, 0.7, 2, {
        Rotation = 0,
    })
    task.delay(duration, function()
        showing:set(false)
        task.wait(0.2)
        newNotification:Destroy()
    end)
    
    return newNotification
end