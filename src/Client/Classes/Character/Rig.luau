local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local LocalUserId = LocalPlayer.UserId
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Assets = require(ReplicatedStorage.Shared.Constants.Assets)
local LuckyBlockFormat = require(ReplicatedStorage.Shared.Formats.LuckyBlockFormat)
local RigFormat = require(ReplicatedStorage.Shared.Formats.RigFormat)
local AnimationType = require(ReplicatedStorage.Shared.Types.AnimationType)
local AnimationUtil = require(ReplicatedStorage.Shared.Utilities.AnimationUtil)
local EquipmentUtil = require(ReplicatedStorage.Shared.Utilities.Equipment.EquipmentUtil)
local PartUtil = require(ReplicatedStorage.Shared.Utilities.PartUtil)

local EquipmentModels = Assets.EquipmentModels

export type RigContext = {
    userId: number,
}

local RigClass = {}
RigClass.__index = RigClass

function RigClass.new(context: RigContext)
    local self = setmetatable({
        masterTrove = Trove.new(),
        userId = context.userId,
        attributes = {
            equippedType = nil :: string?,
            equippedModel = nil :: Model?,
        },
        signals = {
            onRoll = Signal.new() :: Signal.Signal<LuckyBlockFormat.RollContext>,
        },
        animationCache = {},
    }, RigClass)
    self.equipmentTrove = self.masterTrove:Extend()
    self.characterTrove = self.masterTrove:Extend()

    self:initializeCharacter(self:getCharacter())
    return self
end

export type Self = typeof(RigClass.new(...))

function RigClass.getCharacter(self: Self)
    local userId = self.userId
    local player = Players:GetPlayerByUserId(userId)
    local character = player and player.Character
    return character
end

function RigClass.isLocalPlayer(self: Self)
    local userId = self.userId
    return userId == LocalUserId
end

function RigClass.displayRoll(self: Self, context: LuckyBlockFormat.RollContext)
    local signals = self.signals
    local onRoll = signals.onRoll
    onRoll:Fire(context)
end

function RigClass.initializeCharacter(self: Self, character: Model)
    local characterTrove = self.characterTrove
    local animationCache = self.animationCache
    local humanoid = character and character:WaitForChild("Humanoid")
    local animator: Animator = humanoid and humanoid:WaitForChild("Animator")

    characterTrove:Clean()
    table.clear(animationCache)
    local attributes = self.attributes
    local equippedType = attributes.equippedType
    if not equippedType then
        return
    end
    self:initializeAnimations()
end

function RigClass.initializeAnimations(self: Self)
    local character = self:getCharacter()
    local attributes = self.attributes
    local animationCache = self.animationCache
    local characterTrove = self.characterTrove
    local equippedType = attributes.equippedType
    local equipmentMetadata = equippedType and EquipmentUtil.getMetadata(equippedType)
    local rigInfo = equipmentMetadata and equipmentMetadata.rigInfo
    local rigAnimations = rigInfo and rigInfo.animations
    if not rigAnimations then
        return
    end

    for animType, animationInfo in rigAnimations do
        if animationCache[animType] then
            continue
        end
        
        local animation = animationInfo.animation
        local looped = animationInfo.looped
        if animation:IsA("Animation") then
            local animationTrack = AnimationUtil.loadAnimation(character, animation, looped)
            animationCache[animType] = animationTrack
            characterTrove:Add(animationTrack)
        end
    end
end

function RigClass.playAnimation(self: Self, animationName: string)
    local animationCache = self.animationCache
    local animationTrack = animationCache[animationName]
    if not animationTrack then
        warn(`Animation track not found: {animationName}`)
        return
    end
    AnimationUtil.playAnimation({
        animationTrack = animationTrack,
    })
end

function RigClass.update(self: Self, dt: number)
end

function RigClass.toggleEquipment(self: Self, context: RigFormat.RigToggleContext)
    local isLocalPlayer = self:isLocalPlayer()
    local equipmentTrove = self.equipmentTrove
    local equipmentType = context.equipmentType
    local isEquipped = context.isEquipped
    local attributes = self.attributes
    local equippedType = attributes.equippedType
    if equippedType == equipmentType then
        return
    end

    equipmentTrove:Clean()
    if not isEquipped then
        attributes.equippedType = nil
        return
    end
    attributes.equippedType = equipmentType

    local character = self:getCharacter()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rightHand = character:FindFirstChild("RightHand")
    local rightGripAttachment = rightHand and rightHand:FindFirstChild("RightGripAttachment")
    local equipmentModel = EquipmentModels:FindFirstChild(equipmentType)
    if not (equipmentModel and character and rightGripAttachment and humanoid) then
        return
    end
    
    self:initializeAnimations()
    local newEquipmentModel = equipmentModel:Clone()
    local equipmentPrimaryPart = newEquipmentModel.PrimaryPart
    local upperTorso = character and character:FindFirstChild("UpperTorso")
    local rightHandGrip = newEquipmentModel:FindFirstChild("RightHandGrip", true)
    local leftHandGrip = newEquipmentModel:FindFirstChild("LeftHandGrip", true)
    local leftUpperArm = character and character:FindFirstChild("LeftUpperArm")
    local leftLowerArm = leftUpperArm and character:FindFirstChild("LeftLowerArm")
    if not (leftLowerArm and leftHandGrip and upperTorso) then
        return
    end
    local rightGripPivot = rightHandGrip and rightHandGrip.WorldCFrame
    local equipmentPivot = newEquipmentModel:GetPivot()
    local pivotOffset = rightGripPivot:ToObjectSpace(equipmentPivot)
    newEquipmentModel.Parent = character
    newEquipmentModel:PivotTo(rightGripAttachment.WorldCFrame * CFrame.Angles(0, math.rad(5), 0) * CFrame.new(-0.35, 0, 0) * pivotOffset)
    equipmentTrove:Add(newEquipmentModel)
    PartUtil.attachTo(equipmentPrimaryPart, rightHand)
    
    local ikControl = humanoid:FindFirstChild("EquipmentLeftHandIK") or Instance.new("IKControl")
    ikControl.Name = "EquipmentLeftHandIK"
    ikControl.Type = Enum.IKControlType.Transform
    ikControl.ChainRoot = leftUpperArm
    ikControl.EndEffector = leftLowerArm
    ikControl.Target = leftHandGrip
    ikControl.Weight = 0.75
    ikControl.SmoothTime = 0
    ikControl.Parent = humanoid

    local pole = upperTorso:FindFirstChild("LeftElbowPole") or Instance.new("Attachment")
    pole.Name = "LeftElbowPole"
    pole.Position = Vector3.new(0, 0, 0)
    pole.Parent = upperTorso
    
    ikControl.Pole = pole
    -- print("ikControl", ikControl, pole, newEquipmentModel)
    if isLocalPlayer then
        self:playAnimation(AnimationType.IDLE)
    end
end

return RigClass