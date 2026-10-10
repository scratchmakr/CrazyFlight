local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Data = require(ReplicatedStorage.Shared.Constants.Data)
local Titles = require(ReplicatedStorage.Shared.Constants.Titles)
local PlayerUtil = require(ReplicatedStorage.Shared.Utilities.PlayerUtil)
local ItemType = require(ReplicatedStorage.Shared.Types.ItemType)
local TrackedStatType = require(ReplicatedStorage.Shared.Types.TrackedStatType)

local FRAME = UIContainer.Components.NametagUI

export type Props = {
    username: string,
    displayName: string,
    safeData: Fusion.Value<Data.PlayerState>,
}

return function(props: Props)
    local masterTrove = Trove.new()
    local safeDataSource = props.safeData
    local frame = Fusion.Hydrate(FRAME:Clone()) {
        [Fusion.Cleanup] = function()
            masterTrove:Destroy()
        end,
    }

    local infoFrame = frame.InfoFrame
    local levelLabel = infoFrame.Level
    local levelTitle = levelLabel.Title
    local winstreakLabel = infoFrame.Winstreak
    local winstreakTitle = winstreakLabel.Title
    local displayTitle = infoFrame.DisplayName

    local titleFrame = frame.TitleFrame
    local iconTitle = titleFrame.Icon
    local titleFrameTitle = titleFrame.Title

    local usernameFrame = frame.UsernameFrame
    local usernameTitle = usernameFrame.Title

    local function updateTitle()
        local safeData = safeDataSource:get()
        local titles = safeData and safeData.titles

        local titleType = nil
        for type, titleData in titles do
            if titleData.equipped then
                titleType = type
                break
            end
        end

        local visible = titleType ~= nil
        titleFrame.Visible = visible
        local titleMetadata = Titles.METADATA[titleType]
        if not titleMetadata then
            return
        end
        titleFrameTitle.Text = titleMetadata.name
        titleFrameTitle.UIGradient.Color = titleMetadata.color
        iconTitle.Image = titleMetadata.icon or ""
        iconTitle.Visible = titleMetadata.icon ~= nil
    end

    masterTrove:Add(Fusion.Observer(safeDataSource):onChange(updateTitle))

    Fusion.Hydrate(usernameTitle) {
        Text = `@{props.username}`,
    }

    Fusion.Hydrate(displayTitle) {
        Text = props.displayName,
    }

    Fusion.Hydrate(levelTitle) {
        Text = Fusion.Computed(function()
            local safeData = safeDataSource:get()
            local inventory = safeData and safeData.inventory
            local xp = inventory and inventory[ItemType.XP] or 0
            local level = PlayerUtil.calculateLevel(xp)
            return level
        end)
    }

    Fusion.Hydrate(winstreakTitle) {
        Text = Fusion.Computed(function()
            local safeData = safeDataSource:get()
            local trackedStats = safeData and safeData.trackedStats
            local winstreak = trackedStats and trackedStats[TrackedStatType.WIN_STREAK] or 0
            return winstreak
        end)
    }
    
    return frame    
end