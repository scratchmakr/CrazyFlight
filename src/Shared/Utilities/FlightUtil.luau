--!strict
-- Shared helpers for Crazy Flight.

local TestCourse = require(script.Parent.Parent.Constants.Courses.TestCourse)

local FlightUtil = {}

-- Tags
FlightUtil.Tags = {
	FlightPlane = "FlightPlane",
	FlightCourse = "FlightCourse",
	FlightTarget = "FlightTarget", -- Shootable (barrier or fuel)
	FlightLethal = "FlightLethal", -- Instant death on collision
	FlightFinish = "FlightFinish", -- Finish line
}

-- Attributes used across network boundaries
FlightUtil.Attributes = {
	Role = "FlightRole", -- on plane: "Pilot" | "Gunner" | nil
	PlayerRole = "FlightRole", -- on player
	SessionId = "FlightSessionId", -- on plane

	-- Replicated run state (on plane model)
	Hearts = "FlightHearts",
	Fuel = "FlightFuel",
	FuelMax = "FlightFuelMax",
	Heat = "FlightHeat",
	HeatMax = "FlightHeatMax",
	Overheated = "FlightOverheated",
	StartTime = "FlightStartTime",
	Distance = "FlightDistance",
	Speed = "FlightSpeed",
	ControlMode = "FlightControlMode",
	PilotUserId = "FlightPilotUserId",
	GunnerUserId = "FlightGunnerUserId",

	-- Target attributes (on obstacle parts)
	TargetKind = "TargetKind", -- "Barrier" | "Fuel"
	TargetHealth = "TargetHealth",
	TargetFuel = "TargetFuel",
}

-- Course basis helpers ------------------------------------------------------

function FlightUtil.getCourseOrigin(): CFrame
	return TestCourse.Origin
end

-- Returns a CFrame at the given forward distance along the course, with the
-- given lateral/vertical offset. The orientation always faces +Z (course forward).
function FlightUtil.courseCFrame(distance: number, offsetX: number?, offsetY: number?): CFrame
	local x = offsetX or 0
	local y = offsetY or 0
	return TestCourse.Origin * CFrame.new(x, y, distance)
end

-- Projects a world position onto the course forward axis, returning the
-- forward distance from the course origin.
function FlightUtil.forwardDistance(worldPosition: Vector3): number
	local local_ = TestCourse.Origin:PointToObjectSpace(worldPosition)
	return local_.Z
end

-- Returns true if the position is outside the course bounds laterally/vertically.
function FlightUtil.isOutOfBounds(worldPosition: Vector3): boolean
	local local_ = TestCourse.Origin:PointToObjectSpace(worldPosition)
	local b = TestCourse.Bounds
	if math.abs(local_.X) > b.X then return true end
	if math.abs(local_.Y) > b.Y then return true end
	if local_.Z < -b.Z then return true end
	return false
end

-- Linear interpolation along the autopilot path (returns offsetX, offsetY).
function FlightUtil.autopilotOffset(distance: number): (number, number)
	local path = TestCourse.AutopilotPath
	if #path == 0 then return 0, 0 end
	if distance <= path[1].distance then
		return path[1].offsetX, path[1].offsetY
	end
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		if distance <= b.distance then
			local t = (distance - a.distance) / math.max(1e-3, b.distance - a.distance)
			return a.offsetX + (b.offsetX - a.offsetX) * t,
				a.offsetY + (b.offsetY - a.offsetY) * t
		end
	end
	local last = path[#path]
	return last.offsetX, last.offsetY
end

-- Analytic projectile position at time t with constant gravity.
function FlightUtil.projectilePosition(p0: Vector3, v0: Vector3, gravity: number, t: number): Vector3
	return p0 + v0 * t + Vector3.new(0, -0.5 * gravity * t * t, 0)
end

-- Analytic projectile velocity at time t.
function FlightUtil.projectileVelocity(v0: Vector3, gravity: number, t: number): Vector3
	return v0 + Vector3.new(0, -gravity * t, 0)
end

-- Frame-rate independent exponential smoothing factor: use as
--   value = value + (target - value) * smoothing(k, dt)
-- so that `k` roughly corresponds to "how quickly" (larger = snappier).
function FlightUtil.smoothing(k: number, dt: number): number
	return 1 - math.exp(-math.max(0, k) * math.max(0, dt))
end

-- Clamp a 2D input vector to magnitude <= 1 (so diagonals are not faster).
function FlightUtil.clampInput(x: number, y: number): (number, number)
	local m2 = x * x + y * y
	if m2 <= 1 then
		return x, y
	end
	local m = math.sqrt(m2)
	return x / m, y / m
end

-- Clamp an aim direction to a yaw/pitch cone around a forward vector.
function FlightUtil.clampAimDirection(forward: Vector3, up: Vector3, right: Vector3, dir: Vector3, maxYawDeg: number, maxPitchDeg: number): Vector3
	if dir.Magnitude < 1e-4 then
		return forward
	end
	local d = dir.Unit
	local yaw = math.atan2(d:Dot(right), d:Dot(forward))
	local flat = (d - up * d:Dot(up))
	local flatMag = flat.Magnitude
	local pitch = math.atan2(d:Dot(up), flatMag > 1e-4 and flatMag or 1e-4)
	local maxYaw = math.rad(maxYawDeg)
	local maxPitch = math.rad(maxPitchDeg)
	yaw = math.clamp(yaw, -maxYaw, maxYaw)
	pitch = math.clamp(pitch, -maxPitch, maxPitch)
	-- Rebuild direction: yaw around up, then pitch around right
	local horiz = (forward * math.cos(yaw) + right * math.sin(yaw))
	local result = horiz * math.cos(pitch) + up * math.sin(pitch)
	return result.Unit
end

return FlightUtil
