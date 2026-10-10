
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local ScreenGui = require(StarterPlayer.StarterPlayerScripts.Client.Utility.ScreenGui)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Camera: Camera = workspace.CurrentCamera
export type props = {
    element: GuiObject,
    container: GuiObject?,
    tracking: Fusion.Value<boolean>,
}

local screenGui = ScreenGui({
    Name = "UIHighlighterScreenGui",
    Parent = LocalPlayer:WaitForChild("PlayerGui"),
    DisplayOrder = 100,
    ScreenInsets = Enum.ScreenInsets.None,
    SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
})

local function isPhone()
    local touchEnabled = UserInputService.TouchEnabled
    local viewport = Camera.ViewportSize
    -- local smallestDimension = math.min(viewport.X, viewport.Y)
    local aspectRatio = math.max(viewport.X, viewport.Y) / math.min(viewport.X, viewport.Y)
    return aspectRatio > 1.8 and touchEnabled -- and smallestDimension < 500
end

return function(props: props)
    local masterTrove = Trove.new()
    
    local tracking = props.tracking
    local element = props.element
    -- local anchorPoint = element.AnchorPoint
    -- local container = props.container or element.Parent

    local absPosState = Fusion.Value(element.AbsolutePosition)
    local absSizeState = Fusion.Value(element.AbsoluteSize)

    local isPhone = isPhone()
    local adjustedAbsPos = Fusion.Computed(function()
        local absSize = absSizeState:get()
        local absPos = absPosState:get()
        local additionalOffset = absSize.X / 2
        if isPhone then
            additionalOffset *= 2
        end
        return Vector2.new(
            absPos.X + additionalOffset,
            absPos.Y + GuiService:GetGuiInset().Y + absSize.Y / 2
        )
    end)

    local hidingPos = Fusion.Computed(function()
        local absPos = adjustedAbsPos:get()
        return UDim2.fromOffset(absPos.X, absPos.Y) - UDim2.fromScale(absPos.X / 2, absPos.Y / 2)
    end)
    local hidingSize = Fusion.Computed(function()
        local absSize = absSizeState:get()
        return UDim2.fromOffset(absSize.X, absSize.Y) + UDim2.fromScale(absSize.X / 2, absSize.Y / 2)
    end)

    local goalPos = Fusion.Computed(function()
        local absPos = adjustedAbsPos:get()
        local isTracking = tracking:get()
        if isTracking then
            return UDim2.fromOffset(absPos.X, absPos.Y)
        else
            return hidingPos:get()
        end
    end)

    local goalSize = Fusion.Computed(function()
        local absSize = absSizeState:get()
        local isTracking = tracking:get()
        if isTracking then
            return UDim2.fromOffset(absSize.X, absSize.Y)
        else
            return hidingSize:get()
        end
    end)

    local springPos = Fusion.Spring(goalPos, 12, 1)
    local springSize = Fusion.Spring(goalSize, 12, 1)

    -- if tracking:get() then
    --     tracking:set(false)
    --     task.defer(function()
    --         tracking:set(true)
    --     end)
    -- end

    local newFrame = Fusion.New("Frame") {
        BackgroundTransparency = 1,
        Size = springSize,
        Position = springPos,
        Parent = screenGui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Visible = true,
        [Fusion.Children] = Fusion.New("UIStroke") {
            Thickness = 5000,
            Color = Color3.fromRGB(0, 0, 0),
            Transparency = Fusion.Spring(Fusion.Computed(function()
                return tracking:get() and 0.5 or 1
            end), 18, 1),
        },
        [Fusion.Cleanup] = function()
            masterTrove:Destroy()
        end,
    }

    Fusion.Hydrate(element) {
        [Fusion.Out "AbsolutePosition"] = absPosState,
        [Fusion.Out "AbsoluteSize"] = absSizeState,
    }

    return newFrame
end