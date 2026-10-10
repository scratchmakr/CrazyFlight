local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local CameraController = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.CameraController)
local Trove = require(ReplicatedStorage.Packages.Trove)
local CombatCharacter = require(ReplicatedStorage.Shared.Classes.CombatCharacter)
local CharacterConfig = require(ReplicatedStorage.Shared.Constants.CharacterConfig)
local BoostType = require(ReplicatedStorage.Shared.Types.EquipmentTypes.BoostType)
local CharacterUtil = require(ReplicatedStorage.Shared.Utilities.CharacterUtil)
export type Context = {
    character: Model,
    combatCharacter: CombatCharacter.Self,
}

local MOVEMENT_STATES = CharacterConfig.movementStates
local SLIDING_DURATION = CharacterConfig.sliding.duration
local SLIDING_SPEED = CharacterConfig.sliding.speed
local WALL_SLIDE_SPEED = CharacterConfig.wallSlide.speed
local MAX_DESCEND_DISTANCE = CharacterConfig.wallSlide.maxDescendDistance
local AIR_CONTROL = CharacterConfig.airControl
local WALL_CHECK_DISTANCE = CharacterConfig.wallSlide.wallCheckDistance

local CharacterMovement = {}
CharacterMovement.__index = CharacterMovement

function CharacterMovement.new(context: Context)
    local self = setmetatable({
        masterTrove = Trove.new(),
        combatCharacter = context.combatCharacter,
        character = context.character,

        wallSlideRuntime = {
            trove = Trove.new(),
            attachedPart = nil,
            latchTargetCFrame = nil,
            predictedGroundRaycastResult = nil,
        },
        fovSpring = CameraController.createFieldOfViewSpring("sliding", {
            speed = 25,
            damping = 1,
        })
    }, CharacterMovement)
    self.characterTrove = self.masterTrove:Extend()
    return self
end

export type Self = typeof(CharacterMovement.new(...))

function CharacterMovement.start(self: Self)
    local masterTrove = self.masterTrove
    masterTrove:Add(RunService.Heartbeat:Connect(function(dt: number)
        self:update(dt)
    end))
    self:initializeCharacter(self.character)
end

function CharacterMovement.initializeCharacter(self: Self, character: Model)
    self.character = character
    local characterTrove = self.characterTrove
    local humanoid = self:getHumanoid()
    local combatCharacter = self.combatCharacter
    local attributes = combatCharacter.attributes
    local slideState = attributes.slideState
    local wallSlideRuntime = self.wallSlideRuntime
    characterTrove:Add(humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Dead then
            -- self:destroy()
        elseif newState == Enum.HumanoidStateType.Landed then
            if wallSlideRuntime.attachedPart then
                return
            end
            combatCharacter:resetWallSlide()
            if slideState.queued then
                combatCharacter:slide(self:getDirection())
            end
        elseif newState == Enum.HumanoidStateType.Jumping then -- for initial jump
            combatCharacter:logJump()
        end
    end))
end

function CharacterMovement.getHumanoid(self: Self)
    local character = self.character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid
end

function CharacterMovement.getRootPart(self: Self)
    local character = self.character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    return rootPart
end

function CharacterMovement.cancelSlide(self: Self)
    local fovSpring = self.fovSpring
    fovSpring:setTarget(0)

    local combatCharacter = self.combatCharacter
    combatCharacter:cancelSlide()
end

function CharacterMovement.updateSliding(self: Self, dt: number)
    local character = self.character
    local combatCharacter = self.combatCharacter
    local attributes = combatCharacter.attributes
    local slideState = attributes.slideState
    local direction = slideState.direction
    local humanoid = self:getHumanoid()
    local rootPart: BasePart = character and character:FindFirstChild("HumanoidRootPart")
    if not (rootPart and humanoid) then
        return
    end

    local fovSpring = self.fovSpring
    fovSpring:setTarget(CharacterConfig.sliding.addedFov)

    local timeSinceSlide = workspace:GetServerTimeNow() - slideState.timestamp
    local alpha = math.clamp(timeSinceSlide / SLIDING_DURATION, 0, 1)
    local easedAlpha = TweenService:GetValue(
        alpha,
        Enum.EasingStyle.Quad, 
        Enum.EasingDirection.Out
    )
    slideState.speed = SLIDING_SPEED * (1 - easedAlpha)
    if combatCharacter:isSlideExpired() then
        self:cancelSlide()
        return
    end

    local obstaclesDetected = combatCharacter:detectObstacles()
    if obstaclesDetected then
        self:cancelSlide()
        return
    end

    -- print(slideState.speed, direction)
    if rootPart then
        -- direction = if direction.Magnitude == 0 then humanoid.MoveDirection else direction
        rootPart.AssemblyLinearVelocity = direction
            * slideState.speed
            + Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
    end
end

function CharacterMovement.getDirection(self: Self)
    local humanoid = self:getHumanoid()
    return humanoid.MoveDirection.Unit
end

function CharacterMovement.attachToWall(self: Self, raycastResult: RaycastResult?)
    if not raycastResult then
        return
    end

    local character = self.character
    local humanoid = self:getHumanoid()
    local wallSlideRuntime = self.wallSlideRuntime
    local wallSlideTrove = wallSlideRuntime.trove

    local combatCharacter = self.combatCharacter
    local raycastParams = combatCharacter.attributes.raycastParams
    local excludeCharactersParams = raycastParams.excludeCharacters

    local rayPosition = raycastResult.Position - CharacterConfig.wallSlide.wallRayOffset
    local normal = raycastResult.Normal
    local rootPart = self:getRootPart()

    local predictedGroundRaycastResult = workspace:Raycast(
        rootPart.Position,
        rootPart.CFrame.UpVector * -CharacterConfig.wallSlide.maxDescendDistance,
        excludeCharactersParams
    )
    wallSlideRuntime.predictedGroundRaycastResult = predictedGroundRaycastResult
    local attachedPart = Instance.new("Part", workspace)
    attachedPart.Anchored = true
    attachedPart.CanCollide = false
    attachedPart.CanQuery = false
    attachedPart.CanTouch = false
    attachedPart.Size = Vector3.one
    attachedPart.Transparency = 1

    local attachment0 = Instance.new("Attachment", rootPart)
    local attachment1 = Instance.new("Attachment", attachedPart)
    wallSlideTrove:Add(attachment0)
    wallSlideTrove:Add(attachment1)
    wallSlideTrove:Add(attachedPart)

    local latchTargetCFrame = CFrame.new(rayPosition)
        * CFrame.Angles(0, math.atan2(normal.X, normal.Z), 0)
        * CFrame.new(0, 0, 1.25)
    attachedPart.CFrame = latchTargetCFrame

    local alignPosition = Instance.new("AlignPosition")
    alignPosition.MaxForce = math.huge
    alignPosition.MaxVelocity = math.huge
    alignPosition.Responsiveness = 100
    alignPosition.Attachment0 = attachment0
    alignPosition.Attachment1 = attachment1
    alignPosition.Parent = attachedPart

    local alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.MaxTorque = math.huge
    alignOrientation.Responsiveness = 200
    alignOrientation.Attachment0 = attachment0
    alignOrientation.Attachment1 = attachment1
    alignOrientation.Parent = attachedPart

    wallSlideRuntime.latchTargetCFrame = latchTargetCFrame
    wallSlideRuntime.attachedPart = attachedPart

    local previousAutoRotate = humanoid.AutoRotate
    humanoid.AutoRotate = false
    wallSlideTrove:Add(function()
        humanoid.AutoRotate = previousAutoRotate
    end)

    local normalHipHeight = humanoid.HipHeight
    humanoid.HipHeight = 0.5
    wallSlideTrove:Add(function()
        humanoid.HipHeight = normalHipHeight
    end)
    for _, basePart in character:GetDescendants() do
        if basePart:IsA("BasePart") and basePart.CanCollide then
            basePart.CanCollide = false
            wallSlideTrove:Add(function()
                basePart.CanCollide = true
            end)
        end
    end
end

function CharacterMovement.updateDirectionalVelocity(self: Self, dt: number)
    local humanoid = self:getHumanoid()
    local rootPart = self:getRootPart()
	
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return
	end

	local moveDirection = humanoid.MoveDirection
	if moveDirection.Magnitude <= 0 then
		return
	end

	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(
		velocity.X,
		0,
		velocity.Z
	)

	local speed = horizontalVelocity.Magnitude

	if speed <= 0 then
		return
	end

	local desiredVelocity = moveDirection.Unit * speed

	local alpha = 1 - math.exp(-AIR_CONTROL * dt)

	local redirectedVelocity = horizontalVelocity:Lerp(
		desiredVelocity,
		alpha
	)

	rootPart.AssemblyLinearVelocity = Vector3.new(
		redirectedVelocity.X,
		velocity.Y,
		redirectedVelocity.Z
	)
end

function CharacterMovement.updateWallSlide(self: Self, dt: number)
    local combatCharacter = self.combatCharacter
    local wallSlideRunTime = self.wallSlideRuntime
    local attachedPart = wallSlideRunTime.attachedPart
    local wallSlideState = combatCharacter.attributes.wallSlideState
    if not attachedPart then
        return
    end
    
    local rootPart = self:getRootPart()
    if not rootPart then
        return
    end

    local humanoid = self:getHumanoid()
    if humanoid and humanoid.Jump then
        combatCharacter:attemptWallJump()
        return
    end

    local latchTargetCFrame = wallSlideRunTime.latchTargetCFrame
    if not latchTargetCFrame then
        return
    end

    local raycastResult = wallSlideState.raycastResult
    local normal = raycastResult and raycastResult.Normal
    if not normal then
        return
    end

    local timeSinceAttach = workspace:GetServerTimeNow() - wallSlideState.attachTimestamp
    if timeSinceAttach >= CharacterConfig.wallSlide.wallLostGraceDuration then
        local raycastParams = combatCharacter:updateParams()
        local wallCheckOrigin = rootPart.Position
        local result = workspace:Raycast(
            wallCheckOrigin,
            -normal * WALL_CHECK_DISTANCE,
            raycastParams
        )

        if not result then
            combatCharacter:attemptDetachFromWall()
            return
        end
    end

    local distanceToGround = MAX_DESCEND_DISTANCE
    local predictedGroundRaycastResult = wallSlideRunTime.predictedGroundRaycastResult
    if predictedGroundRaycastResult then
        distanceToGround = latchTargetCFrame.Position.Y - predictedGroundRaycastResult.Position.Y - 3.5
    end
    local duration = distanceToGround / MAX_DESCEND_DISTANCE * WALL_SLIDE_SPEED

    local timeSinceWallSlide = workspace:GetServerTimeNow() - wallSlideState.timestamp
    local alpha = math.clamp(
        timeSinceWallSlide / duration,
        0,
        1
    )
    local easedAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    if easedAlpha >= 1 then
        combatCharacter:attemptDetachFromWall()
        return
    end
    local descendDistance = distanceToGround * easedAlpha
    attachedPart.CFrame =
        CFrame.new(latchTargetCFrame.Position - Vector3.new(0, descendDistance, 0))
        * CFrame.Angles(latchTargetCFrame:ToEulerAngles())
end

function CharacterMovement.detachFromWall(self: Self)
    local runtime = self.wallSlideRuntime

    runtime.trove:Clean()

    runtime.attachedPart = nil
    runtime.latchTargetCFrame = nil
    runtime.predictedGroundRaycastResult = nil
end

function CharacterMovement.applyWallJump(self: Self)
    local combatCharacter = self.combatCharacter
    local wallSlideState = combatCharacter.attributes.wallSlideState
    local jumpsRemaining = wallSlideState.jumpsRemaining
    local raycastResult = wallSlideState.raycastResult
    local normal = raycastResult and raycastResult.Normal
	if jumpsRemaining < 0 then
		combatCharacter:attemptDetachFromWall()
		return
	end

    local character = self.character
    local humanoid = self:getHumanoid()
    local rootPart = self:getRootPart()
    local charMass = CharacterUtil.getMassOfRig(character)
	combatCharacter:attemptDetachFromWall()
	-- playAnimation("walljump", true)
    
	humanoid.WalkSpeed = 0
    local jumpPowerBoost = combatCharacter:getBoost(BoostType.JUMP_POWER)
	humanoid.JumpPower = CharacterConfig.wallSlide.jumpPower + jumpPowerBoost
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

    if normal then
        local horizontalNormal = Vector3.new(normal.X, 0, normal.Z).Unit
    
        rootPart:ApplyImpulse(
            horizontalNormal
            * CharacterConfig.wallSlide.jumpKnockbackForce
            * charMass
        ) 
    end
	task.delay(0.04, function()
        local walkSpeedBoost = combatCharacter:getBoost(BoostType.WALK_SPEED)
        local jumpPowerBoost = combatCharacter:getBoost(BoostType.JUMP_POWER)
        local walkSpeed = CharacterConfig.defaultWalkSpeed + walkSpeedBoost
        local jumpPower = CharacterConfig.defaultJumpPower + jumpPowerBoost
        -- print("walkspeedboost", walkSpeedBoost, jumpPower)
		humanoid.WalkSpeed = walkSpeed
		humanoid.JumpPower = jumpPower
	end)
end

function CharacterMovement.update(self: Self, dt: number)
    local combatCharacter = self.combatCharacter
    local state = combatCharacter:getMovementState()
    if state == MOVEMENT_STATES.SLIDING then
        combatCharacter:updateParams()
        self:updateSliding(dt)
    elseif state == MOVEMENT_STATES.WALL_SLIDE then
        self:updateWallSlide(dt)
    end
    -- combatCharacter:updateParams()
    -- self:updateSliding(dt)
    if state == MOVEMENT_STATES.IDLE then
        self:updateDirectionalVelocity(dt)
        combatCharacter:attemptWallAttach()
    end

    if state == MOVEMENT_STATES.DISABLED then
        combatCharacter:setBoost(MOVEMENT_STATES.DISABLED, {
            boosts = {
                walkSpeed = -1,
                jumpPower = -1,    
            },
        })
    else
        combatCharacter:removeGroup(MOVEMENT_STATES.DISABLED)
    end
end

function CharacterMovement.destroy(self: Self)
    local masterTrove = self.masterTrove
    masterTrove:Destroy()
end

return CharacterMovement