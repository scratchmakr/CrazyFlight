local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local SimpleSpring = require(StarterPlayer.StarterPlayerScripts.Client.Classes.SimpleSpring)
local Trove = require(ReplicatedStorage.Packages.Trove)
local CombatCharacter = require(ReplicatedStorage.Shared.Classes.CombatCharacter)
local CharacterConfig = require(ReplicatedStorage.Shared.Constants.CharacterConfig)
local ArmsFormat = require(ReplicatedStorage.Shared.Formats.ArmsFormat)
local EquipmentClassFormat = require(ReplicatedStorage.Shared.Formats.EquipmentClassFormat)
local EquipmentDataFormat = require(ReplicatedStorage.Shared.Formats.EquipmentDataFormat)
local AnimationType = require(ReplicatedStorage.Shared.Types.AnimationType)
local EquipmentTypes = require(ReplicatedStorage.Shared.Types.EquipmentTypes)
local AnimationUtil = require(ReplicatedStorage.Shared.Utilities.AnimationUtil)
local EquipmentUtil = require(ReplicatedStorage.Shared.Utilities.Equipment.EquipmentUtil)
local PartUtil = require(ReplicatedStorage.Shared.Utilities.PartUtil)

local Camera = workspace.CurrentCamera

local OFFSET_TYPES = {
	CAMERA_LAG = "CameraLag",
	RUN_BOBBING = "RunBobbing",
	RUN_POSE = "RunPosE",
	SLIDE = "Slide",
	IDLE = "Idle",
	LANDED_IMPULSE = "LandedImpulse",
	JUMPING_IMPULSE = "JumpingImpulse",
	FREE_FALL = "FreeFall",
	RECOIL_POSITION = "RecoilPosition",
	RECOIL_ROTATION = "RecoilRotation",
	ADS_POSITION = "ADSPosition",
	ADS_ROTATION = "ADSRotation",
}

local ANIMATION_TO_STATE = {
	start = AnimationType.RELOAD_CYCLE_START,
	loop = AnimationType.RELOAD_CYCLE_LOOP,
	["end"] = AnimationType.RELOAD_CYCLE_LOOP,
	one_cycle = AnimationType.RELOAD_CYCLE_START,
}

-- How much normal camera movement affects the arms.
local CAMERA_LAG_PITCH = 0.008
local CAMERA_LAG_YAW = 0.012
local CAMERA_LAG_ROLL = 0.004

-- Maximum rotational lag in degrees.
local MAX_CAMERA_LAG_PITCH = 3
local MAX_CAMERA_LAG_YAW = 5
local MAX_CAMERA_LAG_ROLL = 2

-- Degrees / second before a turn counts as a flick.
local FLICK_THRESHOLD = 50
local MAX_FLICK_SPEED = 1000

-- Velocity added to the spring on a flick.
local MIN_FLICK_IMPULSE = 6
local MAX_FLICK_IMPULSE = 14

local CAMERA_LANDED_IMPULSE = -10
local CAMERA_JUMPING_IMPULSE = 6
local RUN_BOBBING_SPEED = 10
local SLIDE_BOBBING_SPEED = 10

local FREE_FALL_VELOCITY_THRESHOLD = 70
local FREE_FALL_MAX_OFFSET = 0.6

local MAX_ADS_ROTATION = 10

local RECOIL_POSITION_PER_POINT = Vector3.new(0, -1, 2.5)
local RECOIL_ROTATION_PER_POINT = Vector3.new(
	math.rad(2),
	math.rad(3),
	math.rad(-13)
	-- math.rad(2),
	-- math.rad(-12)
)
export type Context = {
	armType: string,
	character: Model,
	combatCharacter: CombatCharacter.Self,
}

type OffsetInfo = {
	spring: SimpleSpring.Self?,
	offset: CFrame?,
	elapsedTime: number?,

	springToCFrame: ((Vector3) -> CFrame)?,
	weightSpring: SimpleSpring.Self?,
	order: number?,
}

local ArmsClass = {}
ArmsClass.__index = ArmsClass

function ArmsClass.new(context: Context)
	local self = setmetatable({
		masterTrove = Trove.new(),
		armType = context.armType,
		combatCharacter = context.combatCharacter,
		character = context.character,
		cframeOffsets = {} :: { [string]: OffsetInfo },
		offsetMap = {} :: { [number]: string },
		animationCache = {} :: { [string]: AnimationTrack? },
		show = false,
		aimingDownSights = false,
		toggleShowTimestamp = 0,
		viewportArms = nil :: Model?,
		elapsedTime = 0,
		lastCameraCFrame = Camera.CFrame,
		wasFastCameraTurn = false,
	}, ArmsClass)
	self.characterTrove = self.masterTrove:Extend()

	self:initialize()
	return self
end

export type Self = typeof(ArmsClass.new(...))

function ArmsClass.getEquipmentMetadata(self: Self): EquipmentDataFormat.EquipmentInfo?
	local armType = self.armType
	local equipmentInfo = EquipmentUtil.getMetadata(armType)
	if not equipmentInfo then
		warn(`Could not find metadata for type: {armType}`)
		return nil
	end
	return equipmentInfo
end

function ArmsClass.getArmsMetadata(self: Self): ArmsFormat.ArmsFormat?
	local armType = self.armType
	local equipmentInfo = self:getEquipmentMetadata()
	local viewportArms = equipmentInfo and equipmentInfo.viewportArms
	if not viewportArms then
		warn(`Could not find metadata for type: {armType}`)
		return nil
	end
	return viewportArms
end

function ArmsClass.getCharacter(self: Self)
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	return character
end

function ArmsClass.createOffsetInfo(self: Self, offsetType: string, context: OffsetInfo)
	local cframeOffsets = self.cframeOffsets
	local offsetMap = self.offsetMap
	local order = #RblxUtils.Table.keys(cframeOffsets) + 1
	context.order = order
	cframeOffsets[offsetType] = context
	offsetMap[order] = offsetType
	return context
end

function ArmsClass.initialize(self: Self)
	local masterTrove = self.masterTrove
	local armType = self.armType

	local equipmentMetadata = self:getEquipmentMetadata()
	local prefabs = equipmentMetadata and equipmentMetadata.prefabs
	local correspondingViewportArms = prefabs and prefabs.arms
	if not correspondingViewportArms then
		warn(`Could not find viewport arms for type: {armType}`)
		return
	end
	
	local ballisticInfo = equipmentMetadata and equipmentMetadata.ballisticInfo
	local recoil = ballisticInfo and ballisticInfo.recoil or 1
	local armsMetadata = self:getArmsMetadata()
	local weight = armsMetadata.weight or 1
	local newViewportArms = correspondingViewportArms:Clone()
	newViewportArms.Parent = Camera
	self.viewportArms = newViewportArms
	masterTrove:Add(newViewportArms)

	self:createOffsetInfo(OFFSET_TYPES.RUN_BOBBING, {
		offset = CFrame.identity,

		weightSpring = SimpleSpring.new({
			currentValue = 0,
			targetValue = 0,
			speed = 20,
			damping = 0.85,
		}),
		elapsedTime = 0,
	})

	self:createOffsetInfo(OFFSET_TYPES.RUN_POSE, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = 0,
			targetValue = 0,

			speed = 20,
			damping = 0.85,
		}),
	})
	self:createOffsetInfo(OFFSET_TYPES.LANDED_IMPULSE, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = 0,
			targetValue = 0,
			speed = 20,
			damping = 0.55,
		}),
	})

	self:createOffsetInfo(OFFSET_TYPES.RECOIL_POSITION, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = 0,

			targetValue = 0,
			speed = 35 - math.max(weight, 10),
			damping = 0.65,
		}),
		elapsedTime = 0,
	})

	self:createOffsetInfo(OFFSET_TYPES.RECOIL_ROTATION, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = Vector3.zero,
			targetValue = Vector3.zero,
			speed = 15,
			damping = 0.65,
		}),
		elapsedTime = 0,
	})

	self:createOffsetInfo(OFFSET_TYPES.JUMPING_IMPULSE, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = 0,

			targetValue = 0,
			speed = 20,
			damping = 0.7,
		}),
	})

	self:createOffsetInfo(OFFSET_TYPES.FREE_FALL, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = 0,
			targetValue = 0,
			speed = 25,
			damping = 1,
		}),
	})

	self:createOffsetInfo(OFFSET_TYPES.SLIDE, {
		offset = CFrame.identity,

		weightSpring = SimpleSpring.new({
			currentValue = 0,
			targetValue = 0,
			speed = 20,
			damping = 0.7,
		}),
		elapsedTime = 0,
	})

	self:createOffsetInfo(OFFSET_TYPES.ADS_POSITION, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = 0,
			targetValue = 0,
			speed = 30,
			damping = 0.8,
		}),
	})

	self:createOffsetInfo(OFFSET_TYPES.CAMERA_LAG, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = Vector3.zero,
			targetValue = Vector3.zero,
			speed = 14,
			damping = 0.5,
		}),
	})

	self:createOffsetInfo(OFFSET_TYPES.ADS_ROTATION, {
		offset = CFrame.identity,
		weightSpring = SimpleSpring.new({
			currentValue = 0,
			targetValue = 0,
			speed = 30,
			damping = 0.7,
		}),
	})

	local animationCache = self.animationCache
	for animationName, animationInfo in armsMetadata.animations do
		local animation = animationInfo.animation
		if not animation then
			warn(`Could not find animation for name: {animationName}`)
			continue
		end
		local looped = animationInfo.looped or false
		local animationTrack = AnimationUtil.loadAnimation(newViewportArms, animation, looped)
		animationCache[animationName] = animationTrack
		animationTrack.Looped = looped
	end
	
	self:initializeCharacter(self:getCharacter())
end

function ArmsClass.setADS(self: Self, isADS: boolean)
	self.aimingDownSights = isADS
end

function ArmsClass.initializeCharacter(self: Self, character: Model)
	local characterTrove = self.characterTrove
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("humanoid not found")
		return
	end

	self.character = character
	characterTrove:Add(humanoid.StateChanged:Connect(function(oldState, newState)
		if newState == Enum.HumanoidStateType.Landed then
			self.cframeOffsets[OFFSET_TYPES.LANDED_IMPULSE].weightSpring:impulse(1)
		elseif newState == Enum.HumanoidStateType.Jumping then
			self.cframeOffsets[OFFSET_TYPES.JUMPING_IMPULSE].weightSpring:impulse(1)
		end
	end))
end

function ArmsClass.playAnimation(self: Self, animationContext: AnimationUtil.AnimationContext)
	local animation = animationContext.animationTrack
	if not animation then
		warn("Animation track is nil!", debug.traceback())
		return
	end
	
	if animation.IsPlaying and not animationContext.override then
		return
	end

	AnimationUtil.playAnimation(animationContext)
	return true
end

function ArmsClass.cancelAllAnimations(self: Self, exceptions: { string })
	local animationCache = self.animationCache
	for animationName, animationTrack in animationCache do
		if exceptions and table.find(exceptions, animationName) then
			continue
		end
		AnimationUtil.stopAnimation(animationTrack)
	end
end

function ArmsClass.cancelAnimations(self: Self, animations: { string })
	local animationCache = self.animationCache
	for _, animationName in animations do
		local animationTrack = animationCache[animationName]
		if not animationTrack then
			continue
		end
		AnimationUtil.stopAnimation(animationTrack)
	end
end

function ArmsClass.toggleShow(self: Self, show: boolean)
	self.show = show

	local animationCache = self.animationCache
	local equipAnimation = animationCache[AnimationType.EQUIP]
	local idleAnimation = animationCache[AnimationType.IDLE]
	local viewportArms = self.viewportArms
	local targetParent = show and Camera or script
	viewportArms.Parent = targetParent
	self.toggleShowTimestamp = workspace:GetServerTimeNow()
	if show then
		self.lastCameraCFrame = Camera.CFrame
		if not equipAnimation then
			return
		end
		self:playAnimation({
			animationTrack = equipAnimation,
			override = true,
			onComplete = function()
				if not idleAnimation then
					return
				end
				self:playAnimation({
					animationTrack = idleAnimation,
					override = true,
				})
			end,
		})
	else
		self:cancelAllAnimations()
	end
end

function ArmsClass.playReloadAnimation(self: Self, reloadContext: EquipmentClassFormat.ReloadStartRequest)
	local animationCache = self.animationCache
	local isTactical = reloadContext.isTactical
	local equipmentMetadata = self:getEquipmentMetadata()
	local reloadInfo = equipmentMetadata.reloadInfo
	local reloadType = reloadInfo and reloadInfo.type
	if not reloadType then
		return
	end

	self:cancelAnimations({ AnimationType.CHAMBER })
	if reloadType == EquipmentTypes.ReloadType.Cycle then
		local reloadState = reloadContext.state
		local animationToPlay = ANIMATION_TO_STATE[reloadState]
		local animationTrack = animationToPlay and animationCache[animationToPlay]
		if not animationTrack then
			return
		end

		local onComplete = function()
			if reloadState == "start" then
				self:playAnimation({
					animationTrack = animationCache[AnimationType.RELOAD_CYCLE_LOOP],
					override = true,
				})
			elseif reloadState == "end" then
				self:playAnimation({
					animationTrack = animationCache[AnimationType.RELOAD_CYCLE_END],
					override = true,
				})
			elseif reloadState == "one_cycle" then
				self:playAnimation({
					animationTrack = animationCache[AnimationType.RELOAD_CYCLE_LOOP],
					onComplete = function()
						self:playAnimation({
							animationTrack = animationCache[AnimationType.RELOAD_CYCLE_END],
							override = true,
						})
					end,
				})
			end
		end
		self:playAnimation({
			animationTrack = animationTrack,
			onComplete = onComplete,
			override = true,
		})
	elseif reloadType == EquipmentTypes.ReloadType.Oneshot then
		local animationTrack = isTactical and animationCache[AnimationType.RELOAD_TACTICAL] or animationCache[AnimationType.RELOAD_FULL]
		if not animationTrack then
			return
		end
		self:playAnimation({
			animationTrack = animationTrack,
		})
	end
end

function ArmsClass.updateIdle(self: Self, dt: number)
	local isADS = self:isADS()
	local cframeOffsets = self.cframeOffsets
	local armsMetadata = self:getArmsMetadata()
	local offsets = armsMetadata.offsets
	local rootOffset = offsets.root or CFrame.identity

	local targetOffset = rootOffset
	local cframeOffset = cframeOffsets[OFFSET_TYPES.IDLE] or {}

	cframeOffset.elapsedTime = (cframeOffset.elapsedTime or 0) + dt
	local et = cframeOffset.elapsedTime * 0.5
	local x = 0.025 * math.sin(et)
	local y = 0.05 * math.sin(et) * math.cos(et)

	targetOffset *= CFrame.new(x, y, 0)
	if isADS then
		targetOffset = CFrame.identity
	end
	cframeOffset.offset = targetOffset
	cframeOffsets[OFFSET_TYPES.IDLE] = cframeOffset
end

function ArmsClass.isADS(self: Self)
	local isADS = self.aimingDownSights
	if not isADS then
		return false
	end
	local isEquipping = self:isEquipping()
	if isEquipping then
		return false
	end
	local combatState = self:getCombatState()
	local movementState = self:getMovementState()
	local isSliding = movementState == CharacterConfig.movementStates.SLIDING
	local isShooting = table.find(CharacterConfig.validShootTypes, combatState)
	local isReloading = combatState == CharacterConfig.combatStates.RELOADING
	return not (isShooting or isReloading or isSliding)
end

function ArmsClass.updateADSPosition(self: Self, dt: number)
	local isADS = self:isADS()
	local cframeOffsets = self.cframeOffsets
	local aimingDownSightsInfo = cframeOffsets[OFFSET_TYPES.ADS_POSITION]
	local weightSpring = aimingDownSightsInfo.weightSpring

	local viewportArms = self.viewportArms
	local weaponModel = viewportArms and viewportArms:FindFirstChild("WeaponModel")
	local adsAttachment = weaponModel and weaponModel:FindFirstChild("ADSAttachment", true)
	if not adsAttachment then
		return
	end
	local adsAttachmentPivot = adsAttachment.WorldCFrame
	local rootPivot = viewportArms:GetPivot()
	local targetOffset = adsAttachmentPivot:ToObjectSpace(rootPivot)
	
	local weight = weightSpring:update()
	local targetWeight = isADS and 1 or 0
	weightSpring:setTarget(targetWeight)
	local offset = CFrame.identity:Lerp(targetOffset, weight)
	aimingDownSightsInfo.offset = offset
	cframeOffsets[OFFSET_TYPES.ADS_POSITION] = aimingDownSightsInfo
end

function ArmsClass.updateADSRotation(self: Self, dt: number)
	local isADS = self:isADS()
	local cframeOffsets = self.cframeOffsets
	local aimingDownSightsInfo = cframeOffsets[OFFSET_TYPES.ADS_ROTATION]
	local weightSpring = aimingDownSightsInfo.weightSpring

	local combatCharacter = self.combatCharacter
	local combatAttributes = combatCharacter and combatCharacter.attributes
	local character = combatAttributes and combatAttributes.character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and rootPart) then
		return
	end	
	local moveDirection = humanoid.MoveDirection
	local localDirection = rootPart.CFrame:VectorToObjectSpace(moveDirection)
	local isStrafing = math.round(localDirection.X) ~= 0
	local isStrafingRight = localDirection.X > 0.1

	local viewportArms = self.viewportArms
	local weaponModel = viewportArms and viewportArms:FindFirstChild("WeaponModel")
	local adsAttachment = weaponModel and weaponModel:FindFirstChild("ADSAttachment", true)
	if not adsAttachment then
		return
	end
	local adsAttachmentPivot = adsAttachment.WorldCFrame
	local rootPivot = viewportArms:GetPivot()

	local adsRotation = isStrafingRight and -MAX_ADS_ROTATION or MAX_ADS_ROTATION
	if not isStrafing then
		adsRotation = 0
	end
	local targetRotation = weightSpring:update()
	local targetWeight = isADS and adsRotation or 0
	weightSpring:setTarget(targetWeight)
	local pivotOffset = PartUtil.mutateCFrameFromPivot(
		rootPivot,
		adsAttachmentPivot,
		CFrame.Angles(0, 0, math.rad(targetRotation))
	)
	aimingDownSightsInfo.offset = pivotOffset
	cframeOffsets[OFFSET_TYPES.ADS_ROTATION] = aimingDownSightsInfo
end

function ArmsClass.updateCameraLag(self: Self, dt: number)
	local cframeOffsets = self.cframeOffsets
	if dt <= 0 then
		return
	end

	local cameraCFrame = Camera.CFrame
	local lastCameraCFrame = self.lastCameraCFrame

	self.lastCameraCFrame = cameraCFrame

	local equipmentMetadata = self:getEquipmentMetadata()
	local adsInfo = equipmentMetadata and equipmentMetadata.adsInfo
	local subtractedFOV = adsInfo and adsInfo.subtractedFOV
	local isADS = self:isADS() and subtractedFOV ~= nil

	local rotationDelta = lastCameraCFrame.Rotation:ToObjectSpace(cameraCFrame.Rotation)
	local pitchDelta, yawDelta, rollDelta = rotationDelta:ToOrientation()
	local pitchSpeed = math.deg(pitchDelta) / dt
	local yawSpeed = math.deg(yawDelta) / dt
	local rollSpeed = math.deg(rollDelta) / dt

	local viewportArms = self.viewportArms
	local weaponModel = viewportArms and viewportArms:FindFirstChild("WeaponModel")
	local adsAttachment = weaponModel and weaponModel:FindFirstChild("ADSAttachment", true)
	local adsAttachmentPivot = adsAttachment and adsAttachment.WorldCFrame
	local rootPivot = viewportArms:GetPivot()

	local targetLag = Vector3.new(
		math.clamp(
			-pitchSpeed * CAMERA_LAG_PITCH,
			-MAX_CAMERA_LAG_PITCH,
			MAX_CAMERA_LAG_PITCH
		),

		math.clamp(
			-yawSpeed * CAMERA_LAG_YAW,
			-MAX_CAMERA_LAG_YAW,
			MAX_CAMERA_LAG_YAW
		),

		math.clamp(
			yawSpeed * CAMERA_LAG_ROLL,
			-MAX_CAMERA_LAG_ROLL,
			MAX_CAMERA_LAG_ROLL
		)
	)

	if isADS then
		targetLag *= 0.25
	end
	local cameraLagInfo = cframeOffsets[OFFSET_TYPES.CAMERA_LAG]
	local weightSpring = cameraLagInfo.weightSpring

	weightSpring:setTarget(targetLag)
	local angularVelocity = Vector3.new(
		pitchSpeed,
		yawSpeed,
		rollSpeed
	)

	local turnSpeed = angularVelocity.Magnitude

	local isFastTurn = turnSpeed >= FLICK_THRESHOLD

	if isFastTurn and not self.wasFastCameraTurn and not isADS then
		local alpha = math.clamp( (turnSpeed - FLICK_THRESHOLD) / (MAX_FLICK_SPEED - FLICK_THRESHOLD), 0, 1)
		local impulseStrength = MIN_FLICK_IMPULSE + (MAX_FLICK_IMPULSE - MIN_FLICK_IMPULSE) * alpha
		local impulseDirection = Vector3.new(-pitchSpeed, -yawSpeed, yawSpeed * 0.3)

		if impulseDirection.Magnitude > 0 then
			weightSpring:impulse(impulseDirection.Unit * impulseStrength)
		end
	end

	local springOffset: Vector3 = weightSpring:update()
	local positionalOffset = CFrame.new(
		springOffset.Y * 0.003,
		-springOffset.X * 0.002,
		0
	)

	local rotationalOffset = CFrame.Angles(
		math.rad(springOffset.X),
		math.rad(springOffset.Y),
		math.rad(springOffset.Z)
	)

	if isADS then
		cameraLagInfo.offset = PartUtil.mutateCFrameFromPivot(
			rootPivot,
			adsAttachmentPivot,
			CFrame.Angles(
				math.rad(springOffset.X),
				math.rad(0),
				math.rad(springOffset.Z * 25)
			)
		)
	else
		cameraLagInfo.offset = positionalOffset * rotationalOffset
	end

	cframeOffsets[OFFSET_TYPES.CAMERA_LAG] = cameraLagInfo
	self.wasFastCameraTurn = isFastTurn
end

function ArmsClass.updateRunBobbing(self: Self, dt: number)
	local isADS = self:isADS()
	local cframeOffsets = self.cframeOffsets
	local character = self:getCharacter()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart: BasePart = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and rootPart) then
		return
	end

	local viewportArms = self.viewportArms
	local weaponModel = viewportArms and viewportArms:FindFirstChild("WeaponModel") or viewportArms
	local combatState = self:getCombatState()
	local isShooting = table.find(CharacterConfig.validShootTypes, combatState)
	local movementState = self:getMovementState()
	local armsMetadata = self:getArmsMetadata()
	local offsets = armsMetadata.offsets
	local rootOffset = offsets.root or CFrame.identity
	local runOffset = offsets.runOffset or CFrame.identity
	local bobbingWeight = armsMetadata.weight or 1

	local moveDirection = humanoid.MoveDirection
	local magnitude = moveDirection.Magnitude

	local runInfo = cframeOffsets[OFFSET_TYPES.RUN_BOBBING]
	local weightSpring = runInfo.weightSpring
	local targetWeight = if magnitude ~= 0
		and movementState ~= CharacterConfig.movementStates.SLIDING
		then 1 else 0
	if isShooting then
		weightSpring:setValue(0)
	else
		weightSpring:setTarget(targetWeight)
	end	
	local alpha = weightSpring:update()
	if isADS then
		alpha *= 0.25
	end
	local weaponCFrame = weaponModel:GetPivot()
	local rootPivot = viewportArms:GetPivot()
	local et = runInfo.elapsedTime
	local charSpeed = rootPart.AssemblyLinearVelocity.Magnitude
	local speedNormalized = math.clamp(charSpeed / CharacterConfig.defaultWalkSpeed, 0, 1)
	runInfo.elapsedTime += dt * speedNormalized
	local bobbingOffset = 
		CFrame.new(0, math.sin(et * RUN_BOBBING_SPEED * 2) * 0.05 * alpha * bobbingWeight, 0)
			* CFrame.Angles(
				0.1 * math.sin(et * RUN_BOBBING_SPEED) * math.cos(et * RUN_BOBBING_SPEED) * alpha * bobbingWeight,
				0.1 * math.sin(et * RUN_BOBBING_SPEED) * alpha * bobbingWeight,
				0
			)
	
	local pivotOffset = PartUtil.mutateCFrameFromPivot(
		rootPivot,
		weaponCFrame,
		bobbingOffset
	)
	local offsetCFrame = CFrame.identity:Lerp(
		CFrame.new(rootOffset.Position)
			* CFrame.new(runOffset.Position)
			* pivotOffset
			, alpha)

	runInfo.offset = offsetCFrame
end

function ArmsClass.updateRunPose(self: Self, dt: number)
	local cframeOffsets = self.cframeOffsets
	local character = self:getCharacter()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart: BasePart = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and rootPart) then
		return
	end

	local viewportArms = self.viewportArms
	local weaponModel = viewportArms and viewportArms:FindFirstChild("WeaponModel") or viewportArms
	local combatState = self:getCombatState()
	local isShooting = table.find(CharacterConfig.validShootTypes, combatState)
	local isReloading = combatState == CharacterConfig.combatStates.RELOADING
	local isADS = self:isADS()
	local movementState = self:getMovementState()
	local armsMetadata = self:getArmsMetadata()
	local offsets = armsMetadata.offsets
	local rootOffset = offsets.root or CFrame.identity
	local runOffset = offsets.runOffset or CFrame.identity

	local moveDirection = humanoid.MoveDirection
	local magnitude = moveDirection.Magnitude

	local runPoseInfo = cframeOffsets[OFFSET_TYPES.RUN_POSE]
	local weightSpring = runPoseInfo.weightSpring
	local targetWeight = if magnitude ~= 0
		and movementState ~= CharacterConfig.movementStates.SLIDING
		then 1 else 0
	if isShooting or isReloading or isADS then
		weightSpring:setValue(0)
	else
		weightSpring:setTarget(targetWeight)
	end
	
	local alpha = weightSpring:update()
	local weaponCFrame = weaponModel:GetPivot()
	local rootPivot = viewportArms:GetPivot()
	
	local pivotOffset = PartUtil.mutateCFrameFromPivot(
		rootPivot,
		weaponCFrame,
		CFrame.Angles(runOffset:ToEulerAngles())
	)
	local offsetCFrame = CFrame.identity:Lerp(
		CFrame.new(rootOffset.Position)
			* CFrame.new(0.25, 0, 0.5)
			* CFrame.new(runOffset.Position)
			* pivotOffset
			, alpha)

	runPoseInfo.offset = offsetCFrame
end

function ArmsClass.updateFreeFall(self: Self, dt: number)
	local cframeOffsets = self.cframeOffsets
	local freeFallInfo = cframeOffsets[OFFSET_TYPES.FREE_FALL]
	local character = self:getCharacter()
	local rootPart: BasePart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	-- local combatState = self:getCombatState()
	local isADS = self:isADS()
	local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
	local verticalVelocityNormalized = -math.clamp(verticalVelocity / FREE_FALL_VELOCITY_THRESHOLD, -1, 1)
	freeFallInfo.weightSpring:setTarget(verticalVelocityNormalized)
	local weight = freeFallInfo.weightSpring:update()
	local offset = weight * FREE_FALL_MAX_OFFSET
	if isADS then
		offset *= 0
	end

	freeFallInfo.offset = CFrame.new(0, offset, 0)
end

function ArmsClass.updateLanded(self: Self, dt: number)
	local isADS = self:isADS()
	local cframeOffsets = self.cframeOffsets
	local landedImpulse = cframeOffsets[OFFSET_TYPES.LANDED_IMPULSE]
	local weightSpring = landedImpulse.weightSpring

	local viewportArms = self.viewportArms
	local weaponModel = viewportArms and viewportArms:FindFirstChild("WeaponModel") or viewportArms
	local armsMetadata = self:getArmsMetadata()
	local armsWeight = armsMetadata.weight or 1
	local weight = weightSpring:update()
	if isADS then
		weight *= 0.5
	end
	local weaponPivot = weaponModel:GetPivot()
	local rootPivot = viewportArms:GetPivot()
	local impulse = weight * CAMERA_LANDED_IMPULSE * armsWeight
	local pivotOffset = PartUtil.mutateCFrameFromPivot(
		rootPivot,
		weaponPivot,
		CFrame.new(0, impulse, 0)
		* CFrame.Angles(0, 0, -impulse)
	)

	landedImpulse.offset = pivotOffset
	cframeOffsets[OFFSET_TYPES.LANDED_IMPULSE] = landedImpulse
end

function ArmsClass.updateJumping(self: Self, dt: number)
	local isADS = self:isADS()
	local cframeOffsets = self.cframeOffsets
	local jumpingImpulse = cframeOffsets[OFFSET_TYPES.JUMPING_IMPULSE]
	local weightSpring = jumpingImpulse.weightSpring

	local viewportArms = self.viewportArms
	local weaponModel = viewportArms and viewportArms:FindFirstChild("WeaponModel") or viewportArms
	local armsMetadata = self:getArmsMetadata()
	local armsWeight = armsMetadata.weight or 1
	local weight = weightSpring:update()
	if isADS then
		weight *= 0
	end
	local weaponPivot = weaponModel:GetPivot()
	local rootPivot = viewportArms:GetPivot()
	local impulse = weight * CAMERA_JUMPING_IMPULSE * armsWeight
	local pivotOffset = PartUtil.mutateCFrameFromPivot(
		rootPivot,
		weaponPivot,
		CFrame.new(0, -impulse, 0)
		* CFrame.Angles(0, 0, impulse)
	)

	jumpingImpulse.offset = pivotOffset
	cframeOffsets[OFFSET_TYPES.JUMPING_IMPULSE] = jumpingImpulse
end

function ArmsClass.updateSlide(self: Self, dt: number)
	local combatState = self:getCombatState()
	local isADS = self:isADS()
	local movementState = self:getMovementState()	
	local cframeOffsets = self.cframeOffsets
	local slideInfo = cframeOffsets[OFFSET_TYPES.SLIDE]
	local weightSpring = slideInfo.weightSpring
	local weight = weightSpring:update()
	local targetWeight = movementState == CharacterConfig.movementStates.SLIDING and 1 or 0
	local viewportArms = self.viewportArms
	local weaponModel = viewportArms and viewportArms:FindFirstChild("WeaponModel") or viewportArms

	local isShooting = table.find(CharacterConfig.validShootTypes, combatState)

	local armsMetadata = self:getArmsMetadata()
	local offsets = armsMetadata.offsets
	local rootOffset = offsets.root or CFrame.identity

	local weaponPivot = weaponModel:GetPivot()
	local rootPivot = viewportArms:GetPivot()
	local et = slideInfo.elapsedTime
	slideInfo.elapsedTime += dt
	local bobbing = CFrame.Angles(
		0.05 * math.sin(et * SLIDE_BOBBING_SPEED * 2) * math.cos(et * SLIDE_BOBBING_SPEED * 2),
		0.025 * math.sin(et * SLIDE_BOBBING_SPEED * 2),
		0
	)
	local pivotOffset = PartUtil.mutateCFrameFromPivot(
		rootPivot,
		weaponPivot,
		rootOffset
			* CFrame.new(0, 0, -0.5)
			* CFrame.Angles(math.rad(-15), 0, 0)
			* bobbing
	)

	-- local alpha = isShooting and 0 or weight
	weightSpring:setTarget(targetWeight)
	slideInfo.offset = CFrame.identity:Lerp(pivotOffset, weight)
	cframeOffsets[OFFSET_TYPES.SLIDE] = slideInfo
end

function ArmsClass.updateWallSlide(self: Self, dt: number)
	
	-- local movementState = self:getMovementState()
	-- if movementState == CharacterConfig.movementStates.WALL_SLIDE then
	-- 	self:cancelAllAnimations()
	-- else
		
	-- end
end

function ArmsClass.updateWallJump(self: Self, dt: number)

end

function ArmsClass.updateRecoilPosition(self: Self, dt: number)
	local cframeOffsets = self.cframeOffsets
	local recoilInfo = cframeOffsets[OFFSET_TYPES.RECOIL_POSITION]
	local weightSpring = recoilInfo.weightSpring
	local weight = weightSpring:update()
	local position = RECOIL_POSITION_PER_POINT

	recoilInfo.elapsedTime += dt
	recoilInfo.offset = CFrame.identity:Lerp(CFrame.new(position), weight)
	cframeOffsets[OFFSET_TYPES.RECOIL_POSITION] = recoilInfo
end

function ArmsClass.updateRecoilRotation(self: Self, dt: number)
	local cframeOffsets = self.cframeOffsets
	local recoilInfo = cframeOffsets[OFFSET_TYPES.RECOIL_ROTATION]
	local weightSpring = recoilInfo.weightSpring
	local weight = weightSpring:update()

	local viewportArms = self.viewportArms
	local weaponModel = viewportArms:FindFirstChild("WeaponModel") or viewportArms
	local weaponPivot = weaponModel:GetPivot()
	local rootPivot = viewportArms:GetPivot()

	local pivotOffset = PartUtil.mutateCFrameFromPivot(
		rootPivot,
		weaponPivot,
		CFrame.Angles(weight.X, weight.Y, weight.Z)
	)
	recoilInfo.elapsedTime += dt
	recoilInfo.offset = pivotOffset
	cframeOffsets[OFFSET_TYPES.RECOIL_ROTATION] = recoilInfo
end

function ArmsClass.playShotAnimation(self: Self, context: EquipmentClassFormat.ActionRequest)
	local animationCache = self.animationCache
	local equipmentMetadata = self:getEquipmentMetadata()
	local chamberInfo = equipmentMetadata and equipmentMetadata.chamberInfo
	local chamberDelay = chamberInfo and chamberInfo.delay or 0
	local chamberTime = chamberInfo and chamberInfo.chamberTime
	local ballisticInfo = equipmentMetadata and equipmentMetadata.ballisticInfo
	local recoil = ballisticInfo and ballisticInfo.recoil or 1
	local cframeOffsets = self.cframeOffsets
	local recoilPositionInfo = cframeOffsets[OFFSET_TYPES.RECOIL_POSITION]
	local weightSpring = recoilPositionInfo.weightSpring
	local isADS = self.aimingDownSights -- not self:isADS() because shooting cancels this and just results in regular recoil
	if isADS then
		recoil *= 0.5
	end
	weightSpring:impulse(5 * recoil)
	local random = Random.new()
	local randRotationMultiplier = random:NextNumber(-1, 1)
	local recoilRotationInfo = cframeOffsets[OFFSET_TYPES.RECOIL_ROTATION]
	weightSpring = recoilRotationInfo.weightSpring
	weightSpring:impulse(Vector3.new(
		RECOIL_ROTATION_PER_POINT.X * randRotationMultiplier,
		RECOIL_ROTATION_PER_POINT.Y * randRotationMultiplier,
		RECOIL_ROTATION_PER_POINT.Z
	) * 7 * recoil)
	if chamberTime and context.chamber then
		task.delay(chamberDelay, function()
			local combatState = self:getCombatState()
			local isReloading = combatState == CharacterConfig.combatStates.RELOADING
			if isReloading then
				return
			end

			self:playAnimation({
				animationTrack = animationCache[AnimationType.CHAMBER],
				looped = false,
			})
		end)
	else
		local shootAnimation = animationCache[AnimationType.SHOOT]
		if shootAnimation then
			self:playAnimation({
				animationTrack = shootAnimation,
				looped = false,
			})
		end
	end
end

function ArmsClass.getCFrameOffsets(self: Self, functions)
	local cframeOffsets = self.cframeOffsets

	local targetOffset = CFrame.identity

	local totalFunctions = #RblxUtils.Table.keys(cframeOffsets)
	for i = 1, totalFunctions do
		local offsetType = self.offsetMap[i]
		local cframeOffset = cframeOffsets[offsetType]
		if not cframeOffset then
			continue
		end

		local offset = cframeOffset.offset or CFrame.identity

		local spring = cframeOffset.spring

		if spring then
			local value = spring:update()
			if typeof(value) ~= "Vector3" then
				continue
			end

			local springToCFrame = cframeOffset.springToCFrame
			if springToCFrame then
				offset *= springToCFrame(value)
			else
				offset *= CFrame.new(value)
			end
		end

		targetOffset *= offset
	end

	return targetOffset
end

function ArmsClass.isEquipping(self: Self)
	local equipmentMetadata = self:getEquipmentMetadata()
	local equipTime = equipmentMetadata and equipmentMetadata.equipTime or 0.37
	local toggleShowTimestamp = self.toggleShowTimestamp
	local timeDifference = workspace:GetServerTimeNow() - toggleShowTimestamp
	local isEquipping = timeDifference < equipTime
	return isEquipping
end

function ArmsClass.update(self: Self, dt: number)
	local viewportArms = self.viewportArms
	local cframeOffsets = self:getCFrameOffsets()
	local toggleShowTimestamp = self.toggleShowTimestamp
	local timeDifference = workspace:GetServerTimeNow() - toggleShowTimestamp
	if not self.show or timeDifference < 0.01 then
		viewportArms:PivotTo(Camera.CFrame * CFrame.new(0, 0, 15))
		self.lastCameraCFrame = Camera.CFrame
		return
	end

	local updateFunctions = {
		self.updateIdle,
		self.updateRunBobbing,
		self.updateRunPose,
		self.updateFreeFall,
		self.updateLanded,
		self.updateJumping,
		self.updateSlide,
		self.updateWallSlide,
		self.updateWallJump,

		self.updateRecoilPosition,
		self.updateRecoilRotation,

		self.updateADSPosition,
		self.updateADSRotation,
		self.updateCameraLag,
	}

	for _, updateFunction in updateFunctions do
		updateFunction(self, dt)
	end

	self.elapsedTime += dt

	viewportArms:PivotTo(Camera.CFrame * cframeOffsets)
end

function ArmsClass.getMovementState(self: Self)
	local combatCharacter = self.combatCharacter
	local state = combatCharacter:getMovementState()
	return state
end

function ArmsClass.getCombatState(self: Self)
	local combatCharacter = self.combatCharacter
	local state = combatCharacter:getCombatState()
	return state
end

function ArmsClass.destroy(self: Self)
	self.masterTrove:Clean()
end

return ArmsClass