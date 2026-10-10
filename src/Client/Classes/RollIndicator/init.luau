local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local SimpleSpring = require(script.Parent.SimpleSpring)
local Viewport = require(StarterPlayer.StarterPlayerScripts.Client.Components.Viewport)
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Spring = require(ReplicatedStorage.Packages.Spring)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Vide = require(ReplicatedStorage.Packages.Vide)
local LuckyBlockConfig = require(ReplicatedStorage.Shared.Constants.Configs.LuckyBlockConfig)
local Data = require(ReplicatedStorage.Shared.Constants.Data)
local Reroll = require(ReplicatedStorage.Shared.Constants.Reroll)
local LuckyBlockFormat = require(ReplicatedStorage.Shared.Formats.LuckyBlockFormat)
local EquipmentUtil = require(ReplicatedStorage.Shared.Utilities.Equipment.EquipmentUtil)
local LuckyBlockUtil = require(ReplicatedStorage.Shared.Utilities.LuckyBlockUtil)
local WeightUtil = require(ReplicatedStorage.Shared.Utilities.WeightUtil)

local RollIndicatorFrame = UIContainer.Components.RollIndicator

export type ClassContext = {
    playerState: Data.PlayerState,
}

local Apply = Vide.apply
local Source = Vide.source
local Derive = Vide.derive

local ENTRY_COUNT = 15

local RollIndicator = {}
RollIndicator.__index = RollIndicator

function RollIndicator.new(context: ClassContext)
    local self = setmetatable({
        masterTrove = Trove.new(),
        frame = nil :: typeof(RollIndicatorFrame)?,
        playerState = context.playerState,
        weightSprings = {
            mainAlpha = SimpleSpring.new({
                currentValue = 0,
                damping = 1,
                speed = 3,
                targetValue = 0,
            }),
            bounceAlpha = SimpleSpring.new({
                currentValue = 0,
                damping = 0.85,
                speed = 5,
                targetValue = 0,
            }),
        },
        inAnimation = false,
        elapsedTime = 0,
        indicatorToggle = Source(false),
        activeThreads = {} :: { thread },
        currentEntries = {} :: { Frame },
        slotFrames = {} :: { Frame },
        slotIndex = 1,
        signals = {
            onRollStarted = Signal.new(),
            onRollCompleted = Signal.new(),
        },
        rollContext = {
            blockType = nil :: string?,
            seed = nil :: number?,
        } :: LuckyBlockFormat.RollContext,
    }, RollIndicator)
    self.rollTrove = self.masterTrove:Extend()
    self:_initialize()
    return self
end

export type Self = typeof(RollIndicator.new(...))
function RollIndicator._getRNGPool(self: Self)
    -- introduce player state of unlocked equipment into rng pool
    local rollContext = self:_getRollContext()
    local blockType = rollContext.blockType
    local pool = LuckyBlockUtil.getEquipmentWeights(blockType)
    pool = LuckyBlockUtil.injectRerolls(pool)
    return pool
end

function RollIndicator._initialize(self: Self)
    local masterTrove = self.masterTrove
    local frame = RollIndicatorFrame:Clone()
    self.frame = frame
    masterTrove:Add(frame)
    local indicatorToggle = self.indicatorToggle
    local indicator1 = frame.Indicator1
    local indicator2 = frame.Indicator2

    for _, indicator in {indicator1, indicator2} do
        local indicatorImage = indicator:FindFirstChildOfClass("ImageLabel")
        if not indicatorImage then
            continue
        end
        Apply(indicatorImage) {
            ImageTransparency = Vide.spring(Derive(function()
                return indicatorToggle() and 0 or 1
            end), 0.25, 1)
        }
    end
    return frame
end

function RollIndicator._getRollContext(self: Self)
    return self.rollContext
end

function RollIndicator._populateEntries(self: Self, slotFrame: Frame)
    local rollContext = self:_getRollContext()
    local blockType = rollContext.blockType
    local seed = rollContext.seed

    local reelStrip = slotFrame:FindFirstChild("ReelStrip")
    if not reelStrip then
        warn("No reel strip found", slotFrame)
        return
    end
    local slotIndex = self.slotIndex
    local currentEntries = self.currentEntries
    local frame = self.frame
    local templatesFolder = frame.Templates
    local entryTemplate = templatesFolder.EntryTemplate
    local rngPool = self:_getRNGPool(blockType)
    local totalWeight = WeightUtil.getTotalWeight(rngPool)
    local rollSequence = LuckyBlockUtil.rollLuckyBlock(rollContext)
    for i = 1, ENTRY_COUNT do
        local filteredSeed = seed + i
        local random = Random.new(filteredSeed)
        local entryType = WeightUtil.getRandomKeyFromDictionary(rngPool, random)
        if i == 2 then
            entryType = rollSequence[slotIndex]
        end

        local entryMetadata = EquipmentUtil.getMetadata(entryType)
        local viewportInfo = entryMetadata and entryMetadata.viewportInfo
        local cframeOffset = viewportInfo and viewportInfo.cframeOffset or CFrame.identity
        local prefabs = entryMetadata and entryMetadata.prefabs
        local equipmentPrefab = prefabs and prefabs.viewmodel

        local rerollInfo = Reroll.METADATA[entryType]
        local rerollImage = rerollInfo and rerollInfo.image
        if not (equipmentPrefab or rerollImage) then
            warn("No equipment prefab found", entryType)
            continue
        end

        local newEntry = Apply(entryTemplate:Clone()) {
            Name = entryType,
            Parent = reelStrip,
            Visible = true,
        }
        local innerFrame = newEntry.Inner
        local viewportFrame = innerFrame.ViewportFrame
        local oddsTitle = innerFrame.OddsTitle
        local icon = innerFrame.Icon

        if rerollImage then
            oddsTitle.Text = ""
            icon.Image = rerollImage
        elseif equipmentPrefab then
            oddsTitle.Text = `1/{math.floor(1 / (1 / totalWeight))}`
            -- oddsTitle.Text = `1/{i}`
            Viewport({
                viewmodel = equipmentPrefab:Clone(),
                viewportFrame = viewportFrame,
                cframeOffset = cframeOffset,
            })
        end
        table.insert(currentEntries, newEntry)
    end
end

function RollIndicator._setRollContext(self: Self, blockType: string, seed: number)
    local rollContext = self:_getRollContext()
    rollContext.blockType = blockType
    rollContext.seed = seed
end

function RollIndicator._getAlpha(self: Self)
    local weightSprings = self.weightSprings
    local mainAlpha = 0
    for _, weightSpring in weightSprings do
        mainAlpha += weightSpring:update()
    end
    return mainAlpha / #weightSprings
end

function RollIndicator._getSlotFrame(self: Self)
    local slotFrames = self.slotFrames
    return slotFrames[#slotFrames]
end

function RollIndicator._showSelectAnimation(self: Self)
    local currentSlotFrame = self:_getSlotFrame()
    local slotFrameUIScale = currentSlotFrame and currentSlotFrame:FindFirstChildOfClass("UIScale")
    local reelStrip = currentSlotFrame and currentSlotFrame.ReelStrip
    if not (reelStrip and slotFrameUIScale) then
        return
    end

    local winnerCanvas: CanvasGroup = nil
    local currentEntries = self.currentEntries
    for i = 1, 3 do
        local entryCanvas = currentEntries[i]
        local innerFrame = entryCanvas and entryCanvas.Inner
        local uiScale = innerFrame and innerFrame.UIScale
        if not uiScale then
            continue
        end
        local isWinner = i == 2
        if isWinner then
            Spring.target(uiScale, 0.7, 2.5, {
                Scale = 1.2,
            })
            winnerCanvas = entryCanvas
        else
            Spring.target(entryCanvas, 1, 2.5, {
                GroupTransparency = 1,
            })
            Spring.target(uiScale, 0.7, 2.5, {
                Scale = 0,
            })
        end
    end
    self.elapsedTime = 0
    self.slotIndex += 1
    self.inAnimation = false
    
    local rollSequence = LuckyBlockUtil.rollLuckyBlock(self:_getRollContext())
    local nextItem = rollSequence[self.slotIndex]
    local selectThread = task.delay(LuckyBlockConfig.SELECT_TIME, function()
        if not nextItem then
            task.wait(LuckyBlockConfig.END_TIME)
            Spring.stop(slotFrameUIScale)
            Spring.target(slotFrameUIScale, 1, 2.5, {
                Scale = 0,
            })
            Spring.target(winnerCanvas, 1, 2.5, {
                GroupTransparency = 1,
            })
            self:_toggleIndicators(false)
            task.wait(1)
            self:_cleanup()
            return
        end
        local rollContext = self:_getRollContext()
        local blockType = rollContext.blockType
        local seed = rollContext.seed
        self:roll(blockType, seed)
    end)

    table.insert(self.activeThreads, selectThread)
end

function RollIndicator._shouldReroll(self: Self)

end

function RollIndicator.update(self: Self, dt: number)
    local currentSlotFrame = self:_getSlotFrame()
    local slotFrameUIScale = currentSlotFrame and currentSlotFrame:FindFirstChildOfClass("UIScale")
    local reelStrip = currentSlotFrame and currentSlotFrame.ReelStrip
    if not (reelStrip and slotFrameUIScale) then
        return
    end

    if not self.inAnimation then
        return
    end

    if self.elapsedTime > LuckyBlockConfig.ROLL_TIME then
        self:_showSelectAnimation()
        return
    end
    
    local currentEntries = self.currentEntries
    local sampleEntry = currentEntries[1]
    local sampleInnerFrame = sampleEntry and sampleEntry.Inner
    local innerFrameSizeY = sampleInnerFrame and sampleInnerFrame.Size.Y.Scale
    local innerFrameAbsSizeY = sampleEntry and sampleEntry.AbsoluteSize.Y * innerFrameSizeY / slotFrameUIScale.Scale
    if not innerFrameAbsSizeY then
        warn("No inner frame size found", sampleEntry)
        return
    end

    self.elapsedTime += dt
    local weightSprings = self.weightSprings
    local mainAlpha = weightSprings.mainAlpha:update()
    local bounceAlpha = weightSprings.bounceAlpha:update()
    local mainPosition = (1 - mainAlpha) * innerFrameAbsSizeY * (ENTRY_COUNT - 1)
    local bouncePosition = bounceAlpha * innerFrameAbsSizeY
    local totalPosition = innerFrameAbsSizeY + bouncePosition + mainPosition
    reelStrip.Position = UDim2.new(0.5, 0, -0.5, -totalPosition)
    for index, entryCanvas in currentEntries do
        local innerFrame = entryCanvas.Inner
        local uiScale = innerFrame:FindFirstChildOfClass("UIScale")
        if not uiScale then
            continue
        end

        local currentIndex = totalPosition / entryCanvas.AbsoluteSize.Y / innerFrameSizeY
        local distance = math.abs(currentIndex - index + 1) * 0.65
        local alpha = math.clamp(distance, 0, 1)
        local targetTransparency = math.lerp(0, 1, alpha)
        entryCanvas.GroupTransparency = targetTransparency
        uiScale.Scale = math.lerp(1, 0.5, alpha)
    end
end

function RollIndicator.roll(self: Self, blockType: string, seed: number)
    local rollTrove = self.rollTrove
    local isFirstRoll = #self.slotFrames == 0
    if isFirstRoll then
        self:_toggleIndicators(true)
        self:_setRollContext(blockType, seed)
    end
    self.inAnimation = true
    local weightSprings = self.weightSprings
    weightSprings.mainAlpha:setValue(0)
    weightSprings.bounceAlpha:setValue(0)
    local frame = self.frame
    local templatesFolder = frame.Templates
    local slotTemplate = templatesFolder.SlotTemplate

    local newSlot = Apply(slotTemplate:Clone()) {
        Parent = frame,
        Visible = true,
    }
    rollTrove:Add(function()
        newSlot:Destroy()
    end)
    local slotScale = newSlot:FindFirstChildOfClass("UIScale")
    if slotScale then
        slotScale.Scale = 0
        Spring.target(slotScale, 0.65, 2.5, {
            Scale = 1,
        })
    end
    weightSprings.mainAlpha:setTarget(1)
    task.spawn(function()
        task.wait(0.7)
        weightSprings.bounceAlpha:setTarget(-1.4)
        task.wait(0.8)
        weightSprings.bounceAlpha:setTarget(0.4)
        task.wait(0.7)
        weightSprings.bounceAlpha:setTarget(0)
    end)
    table.clear(self.currentEntries)
    table.insert(self.slotFrames, newSlot)
    self.slotIndex = #self.slotFrames
    self:_populateEntries(newSlot)
end

function RollIndicator._toggleIndicators(self: Self, show: boolean)
    self.indicatorToggle(show)
end

function RollIndicator._cleanup(self: Self)
    local activeThreads = self.activeThreads
    for _, thread in activeThreads do
        if thread == coroutine.running() then
            continue
        end
        task.cancel(thread)
    end
    table.clear(activeThreads)
    table.clear(self.slotFrames)
    self.elapsedTime = 0
    local rollTrove = self.rollTrove
    rollTrove:Clean()
end

function RollIndicator.destroy(self: Self)
    self.masterTrove:Destroy()
    for _, signal in self.signals do
        signal:Destroy()
    end
end

return RollIndicator