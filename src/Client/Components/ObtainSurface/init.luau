
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Rarities = require(ReplicatedStorage.Shared.Constants.Rarities)
local InfiniteGradient = require(ReplicatedStorage.Shared.Utilities.InfiniteGradient)
local ItemUtil = require(ReplicatedStorage.Shared.Utilities.ItemUtil)
local RarityUtil = require(ReplicatedStorage.Shared.Utilities.RarityUtil)
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local ApplyGradient = require(StarterPlayer.StarterPlayerScripts.Client.Utility.ApplyGradient)
local Trove = require(ReplicatedStorage.Packages.Trove)

local FRAME = UIContainer.UIParts.Obtain
local DEFAULT_OFFSET = CFrame.new(0, 0, 3.5)
export type Props = {
    name: string,
    additionalAmount: number,
    ownedAmount: Fusion.Value<number>,
    onFinished: () -> ()?,
    show: Fusion.Value<boolean>?,
}

return function(props: Props)
    local masterTrove = Trove.new()
    local nameType = props.name
    local ownedAmountComputed = props.ownedAmount
    local showComputed = props.show or Fusion.Value(true)
    local metadata = ItemUtil.getMetadata(nameType)
    local description = metadata and metadata.description
    local rarity = metadata and metadata.rarity
    local iconImage = metadata.icon or metadata.image

    local rarityMetadata = RarityUtil.getMetadata(rarity)
    if not rarityMetadata then
        warn("No rarityMetadata", nameType, metadata)
        return
    end
    
    local obtainPart = Fusion.Hydrate(FRAME:Clone()) {
        [Fusion.Cleanup] = function()
            masterTrove:Destroy()
        end,
    }
    local surfaceUI = obtainPart:FindFirstChildOfClass("SurfaceGui")
    local obtainFrame = surfaceUI.ObtainScreen
    local mainFrame = obtainFrame.Main
    local mainGlow = mainFrame.Glow
    local innerFrame = mainFrame.Inner
    local innerStroke = innerFrame.UIStroke
    local infoContainer = innerFrame.Info
    local descriptionTitle = infoContainer.DescriptionTitle
    local ownTitle = infoContainer.OwnTitle
    local rarityTitle = infoContainer.RarityTitle
    local mainTitle = infoContainer.Title
    local icon = obtainFrame.Icon
    local amountTitle = icon.Amount

    Fusion.Hydrate(amountTitle) {
        Text = Fusion.Computed(function()
            local additionalAmount = props.additionalAmount or 0
            if additionalAmount > 0 then
                return `+{additionalAmount}`
            end
            
            return ""
        end),
    }
    Fusion.Hydrate(surfaceUI) {
        Parent = LocalPlayer:FindFirstChild("PlayerGui") or obtainPart,
        Adornee = obtainPart,
    }

    Fusion.Hydrate(descriptionTitle) {
        Text = description or ""
    }

    Fusion.Hydrate(ownTitle) {
        Text = Fusion.Computed(function()
            local amount = ownedAmountComputed:get()
            if typeof(amount) ~= "number" then
                return ""
            end
            return `You own {amount}x`
        end),
    }

    Fusion.Hydrate(rarityTitle) {
        Text = rarityMetadata.name
    }

    Fusion.Hydrate(mainTitle) {
        Text = metadata.name
    }

    Fusion.Hydrate(icon) {
        Image = iconImage or ""
    }

    local prefab = metadata.prefab
    if prefab and not iconImage then
        local viewportProps = metadata.viewportProps
        local cframeOffset: CFrame = viewportProps and viewportProps.cframeOffset or CFrame.new()
        local newPrefab = prefab:Clone()

        local primaryPart
        local targetCFrame =  obtainPart.CFrame * DEFAULT_OFFSET--* CFrame.Angles(cframeOffset:ToEulerAnglesXYZ())
        if newPrefab:IsA("BasePart") then
            primaryPart = newPrefab
            newPrefab.CFrame = targetCFrame
        elseif newPrefab:IsA("Model") then
            primaryPart = newPrefab.PrimaryPart
            newPrefab:PivotTo(targetCFrame)
        end
        local weldConstraint = Instance.new("WeldConstraint")
        weldConstraint.Part0 = primaryPart
        weldConstraint.Part1 = obtainPart
        weldConstraint.Parent = primaryPart
        newPrefab.Parent = obtainPart
    end

    ApplyGradient({
        components = {
            [rarityTitle] = true,
            [innerStroke] = true,
            [mainGlow] = true,
        },
        gradientColor = rarityMetadata.color,
        showAnimation = showComputed,
    })

    return obtainPart
end
