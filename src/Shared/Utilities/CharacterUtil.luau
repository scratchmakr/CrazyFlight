local Players = game:GetService("Players")
local CharacterUtil = {}

function CharacterUtil.applyUserDescription(character: Model, userId: number)
	local numericId = tonumber(userId)
	local newDescription = numericId and Players:GetHumanoidDescriptionFromUserIdAsync(numericId)
	if not newDescription then
		warn(`Could not get humanoid description for user {userId}!`)
		return false
	end
	local rigName = character.Name
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`Could not find humanoid in character {character.Name}!`)
		return false
	end
	local currentDescription = humanoid and humanoid:GetAppliedDescription()
	newDescription.HeightScale = currentDescription.HeightScale
    newDescription.WidthScale = currentDescription.WidthScale
    newDescription.DepthScale = currentDescription.DepthScale
    newDescription.HeadScale = currentDescription.HeadScale
    newDescription.BodyTypeScale = currentDescription.BodyTypeScale
    newDescription.ProportionScale = currentDescription.ProportionScale
	humanoid:ApplyDescriptionResetAsync(newDescription)
	character.Name = rigName
	return true
end

function CharacterUtil.getMassOfRig(rig: Model): number
    local mass = 0
    for _, part in rig:GetDescendants() do
        if part:IsA("BasePart") or part:IsA("MeshPart") then
            mass += part:GetMass()
        end
    end
    return mass
end

function CharacterUtil.calculateTravelTime(distance: number, topSpeed: number, acceleration: number): number
	local timeToMax = topSpeed / acceleration
	local distanceToMax = 0.5 * acceleration * timeToMax^2

	if distance <= distanceToMax then
		return math.sqrt((2 * distance) / acceleration)
	else
		local remainingDistance = distance - distanceToMax
		return timeToMax + (remainingDistance / topSpeed)
	end
end

function CharacterUtil.getMeetPosition(startA, startB, speedA, speedB, accelA, accelB)
	local distance = (startB - startA).Magnitude
	local directionA = (startB - startA).Unit

	local combinedSpeed = speedA + speedB
	local combinedAccel = accelA + accelB

	local t

	if combinedAccel == 0 then
		t = distance / combinedSpeed
	else
		-- solve: 0.5*a*t^2 + v*t - distance = 0
		local a = 0.5 * combinedAccel
		local b = combinedSpeed
		local c = -distance

		t = (-b + math.sqrt(b*b - 4*a*c)) / (2*a)
	end

	local distanceA = speedA * t + 0.5 * accelA * t * t
	local meetPosition = startA + directionA * distanceA

	return meetPosition, t
end

function CharacterUtil.getDistanceFromElapsedTime(elapsedTime, acceleration, topSpeed)
    local timeToTopSpeed = topSpeed / acceleration

    if elapsedTime <= timeToTopSpeed then
        return 0.5 * acceleration * elapsedTime ^ 2
    end

    local accelDistance = 0.5 * acceleration * timeToTopSpeed ^ 2
    local extraTime = elapsedTime - timeToTopSpeed

    return accelDistance + topSpeed * extraTime
end

return CharacterUtil
