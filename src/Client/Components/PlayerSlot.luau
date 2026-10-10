local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UserUtil = require(ReplicatedStorage.Shared.Utilities.UserUtil)

export type Props = {
    userId: Fusion.Value<string> | string,
    level: Fusion.Value<number> | number,
    streak: Fusion.Value<number> | number,
    iconScale: number?,
}

local FRAME = UIContainer.Components.PlayerFrame

return function(props: Props)
    local userIdSource = props.userId
    local levelSource = props.level
    local streakSource = props.streak
    local iconScale = props.iconScale or 1

    local newSlot = FRAME:Clone()

    local statsContainer = newSlot.Stats
    local levelLabel = statsContainer.Level
    local levelTitle = levelLabel.Title
    local streakLabel = statsContainer.Winstreak
    local streakTitle = streakLabel.Title

    local playerIcon = newSlot.Icon

    Fusion.Hydrate(levelTitle) {
        Text = if typeof(levelSource) == "number" then levelSource else Fusion.Computed(function()
            return levelSource:get() or ""
        end)
    }

    Fusion.Hydrate(streakTitle) {
        Text = if typeof(streakSource) == "number" then streakSource else Fusion.Computed(function()
            return streakSource:get() or ""
        end)
    }

    for _, icon in statsContainer:GetChildren() do
        local uiScale = icon:FindFirstChildOfClass("UIScale")
        if uiScale then
            Fusion.Hydrate(uiScale) {
                Scale = iconScale,
            }
        end
    end

    task.spawn(function()
        Fusion.Hydrate(playerIcon) {
            Image = if typeof(userIdSource) == "string" then UserUtil.getUserThumbnail(userIdSource) else Fusion.Computed(function()
                return UserUtil.getUserThumbnail(userIdSource:get()) or ""
            end),
        }
    end)

    return newSlot
end