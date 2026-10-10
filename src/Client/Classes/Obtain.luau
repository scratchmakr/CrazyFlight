local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ObtainSurface = require(StarterPlayer.StarterPlayerScripts.Client.Components.ObtainSurface)
local PageController = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.PageController)
local UseSelector = require(StarterPlayer.StarterPlayerScripts.Client.Hooks.UseSelector)
local PageTypes = require(StarterPlayer.StarterPlayerScripts.Client.Types.PageTypes)
local Rarities = require(ReplicatedStorage.Shared.Constants.Rarities)
local ItemUtil = require(ReplicatedStorage.Shared.Utilities.ItemUtil)
local RarityUtil = require(ReplicatedStorage.Shared.Utilities.RarityUtil)
local SoundUtil = require(ReplicatedStorage.Shared.Utilities.SoundUtil)
local CameraViewmodel = require(script.Parent.CameraViewmodel)

export type ItemInfo = {
    itemType: string,
    amount: number,
}
export type Context = {
    items: { ItemInfo },
    onCleanup: (() -> ())?,
}

local VALID_INPUTS = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.Gamepad1,
    Enum.UserInputType.Touch,
}
local DEBOUNCE_TIME = 1

local Obtain = {}
Obtain.__index = Obtain

function Obtain.new(context: Context)
    local self = setmetatable({
        masterTrove = Trove.new(),
        items = context.items,
        onCleanup = context.onCleanup,
        currentIndex = 0,
        cameraViewmodels = {} :: { [number]: CameraViewmodel.Self },
        activeViewmodels = {} :: { [number]: boolean },
        cleaned = false,
    }, Obtain)

    self:initialize()
    return self
end

export type Self = typeof(Obtain.new(...))

function Obtain.initialize(self: Self)
    local masterTrove = self.masterTrove
    local items = self.items
    local cameraViewmodels = self.cameraViewmodels
    
    local delayTimestamp = os.clock()
    local debounce = false
    masterTrove:Add(UserInputService.InputBegan:Connect(function(input, gp)
        if gp or debounce then
            return
        end

        if os.clock() - delayTimestamp < DEBOUNCE_TIME then
            return
        end
        delayTimestamp = os.clock()
        
        debounce = true
        task.delay(DEBOUNCE_TIME, function()
            debounce = false
        end)

        if table.find(VALID_INPUTS, input.UserInputType) then
            self:next()
        end
    end))
    for index, itemInfo in items do
        local itemType = itemInfo.itemType
        local amount = itemInfo.amount

        local itemTab = ItemUtil.getTabType(itemType)
        local metadata = ItemUtil.getMetadata(itemType)
        local rarityMetadata = RarityUtil.getMetadata(metadata.rarity)
        local rarityPrefabs = rarityMetadata and rarityMetadata.prefabs
        local rarityVFX = rarityPrefabs and rarityPrefabs.vfx
        if not (rarityVFX and itemTab) then
            warn("No rarityVFX or itemTab", itemType, itemTab, rarityVFX, metadata, rarityMetadata)
            continue
        end
        local obtainSurface = ObtainSurface({
            name = itemType,
            additionalAmount = amount,
            ownedAmount = UseSelector(function(state)
                local data = state.data
                local cosmetics = data.cosmetics
                local tabState = cosmetics[itemTab] or data[itemTab]
                local ownedAmount = tabState and tabState[itemType] or 0
                return ownedAmount
            end),
            onFinished = function()
                self:next()
            end,
        })
        obtainSurface.Parent = workspace
        
        local newRarityVFX = rarityVFX:Clone()
        newRarityVFX.Anchored = false
        newRarityVFX.Parent = obtainSurface
        newRarityVFX.CFrame = obtainSurface.CFrame
        local newWeld = Instance.new("WeldConstraint")
        newWeld.Part0 = newRarityVFX
        newWeld.Part1 = obtainSurface
        newWeld.Parent = obtainSurface
        local newCameraViewmodel = CameraViewmodel.new({
            viewmodel = obtainSurface,
            cframeOffset = CFrame.new(0, 0, 4),
            reactToMouse = {
                maxTiltX = 7,
                maxTiltY = 7,
            },
            float = {
                height = 0.1,
                frequency = 2,
            },
        })
        masterTrove:Add(function()
            newCameraViewmodel:cleanup()
        end)
        cameraViewmodels[index] = newCameraViewmodel
    end
end

function Obtain.next(self: Self)
    local items = self.items
    local totalItems = #items
    local currentIndex = self.currentIndex
    self.currentIndex = math.min(currentIndex + 1, totalItems)
    if currentIndex >= totalItems then
        self:cleanup()
    else
        PageController.setPage(PageTypes.OBTAIN)
        if self.currentIndex == 1 then
            SoundUtil.playSound({
                sound = ReplicatedStorage.Assets.SFX.UI.ObtainItem,
            })
        end
        self:display()
    end
end

function Obtain.display(self: Self)
    local activeViewmodels = self.activeViewmodels
    local currentIndex = self.currentIndex
    local cameraViewmodels = self.cameraViewmodels
    local viewmodelSetup = cameraViewmodels[currentIndex]
    if viewmodelSetup then
        viewmodelSetup:show()
    end

    self:hideAll()
    activeViewmodels[currentIndex] = true
end

function Obtain.hideAll(self: Self)
    local activeViewmodels = self.activeViewmodels
    for index in activeViewmodels do
        self:hide(index)
    end
end

function Obtain.hide(self: Self, index: number)
    local activeViewmodels = self.activeViewmodels
    local cameraViewmodels = self.cameraViewmodels
    local cameraViewmodel = cameraViewmodels[index]
    if cameraViewmodel then
        cameraViewmodel:hide()
    end
    activeViewmodels[index] = nil
end

function Obtain.cleanup(self: Self)
    self:hideAll()
 
    if self.cleaned then
        return
    end

    local onCleanup = self.onCleanup
    if onCleanup then
        onCleanup()
    end
 
    self.cleaned = true
    task.delay(1, function()
        local masterTrove = self.masterTrove
        masterTrove:Destroy()
        setmetatable(self, nil)
    end)
end

return Obtain