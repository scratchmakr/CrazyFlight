--!strict
-- PlaneCameraController
-- Scriptable camera for both roles. Uses the course basis (not plane roll)
-- so the camera never violently banks with the plane. Predictively smooths
-- the plane position to hide replication jitter for the gunner.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Network = require(ReplicatedStorage.Shared.Network)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)
local Guns = {
	BasicCannon = require(ReplicatedStorage.Shared.Constants.Guns.BasicCannon),
}

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local PlaneCameraController = {}
PlaneCameraController._mount = nil :: any
PlaneCameraController._trove = nil :: any
PlaneCameraController._smoothedPos = nil :: Vector3?
PlaneCameraController._aim = { yaw = 0, pitch = 0 } -- Gunner aim angles (radians)
PlaneCameraController._lookDirection = nil :: Vector3?
PlaneCameraController._lookRay = nil :: Ray?

PlaneCameraController.AimChanged = Signal.new()

local MOUSE_SENSITIVITY = 0.0025 -- radians per pixel
local TOUCH_SENSITIVITY = 0.004
local GAMEPAD_RATE = 2.2 -- radians per second at full stick

-- Original camera state so we can restore it
local savedCameraType = nil :: Enum.CameraType?
local savedCameraSubject = nil :: Instance?
local savedMouseBehavior = nil :: Enum.MouseBehavior?

local function captureCameraState()
	savedCameraType = Camera.CameraType
	savedCameraSubject = Camera.CameraSubject
	savedMouseBehavior = UserInputService.MouseBehavior
end

local function restoreCameraState()
	Camera.CameraType = Enum.CameraType.Custom
	local char = LocalPlayer.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Camera.CameraSubject = humanoid
		end
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	savedCameraType = nil
	savedCameraSubject = nil
	savedMouseBehavior = nil
end

local function clampAim(yaw: number, pitch: number): (number, number)
	local gunCfg = Guns.BasicCannon
	local maxYaw = math.rad(gunCfg.MaxAimYaw)
	local maxPitch = math.rad(gunCfg.MaxAimPitch)
	return math.clamp(yaw, -maxYaw, maxYaw), math.clamp(pitch, -maxPitch, maxPitch)
end

-- Gamepad aim rate state
local gamepadAim = Vector2.zero

local function onInputChanged(input: InputObject, processed: boolean)
	if processed then return end
	local mount = PlaneCameraController._mount
	if not mount or mount.role ~= "Gunner" then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local d = input.Delta
		PlaneCameraController._aim.yaw += -d.X * MOUSE_SENSITIVITY
		PlaneCameraController._aim.pitch += -d.Y * MOUSE_SENSITIVITY
		PlaneCameraController._aim.yaw, PlaneCameraController._aim.pitch = clampAim(
			PlaneCameraController._aim.yaw, PlaneCameraController._aim.pitch
		)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		-- Only track drag if it's not on the virtual joystick / buttons area.
		-- We can't fully detect that here cheaply; the gunner typically has no joystick.
		local d = input.Delta
		PlaneCameraController._aim.yaw += -d.X * TOUCH_SENSITIVITY
		PlaneCameraController._aim.pitch += -d.Y * TOUCH_SENSITIVITY
		PlaneCameraController._aim.yaw, PlaneCameraController._aim.pitch = clampAim(
			PlaneCameraController._aim.yaw, PlaneCameraController._aim.pitch
		)
	elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local p = input.Position
			local x = math.abs(p.X) > 0.1 and p.X or 0
			local y = math.abs(p.Y) > 0.1 and p.Y or 0
			gamepadAim = Vector2.new(x, y)
		end
	end
end

local function clearMount()
	if PlaneCameraController._trove then
		PlaneCameraController._trove:Destroy()
		PlaneCameraController._trove = nil
	end
	PlaneCameraController._mount = nil
	PlaneCameraController._smoothedPos = nil
	PlaneCameraController._aim.yaw = 0
	PlaneCameraController._aim.pitch = 0
	PlaneCameraController._lookDirection = nil
	PlaneCameraController._lookRay = nil
	gamepadAim = Vector2.zero
	if savedCameraType ~= nil then
		restoreCameraState()
	end
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function setupForMount(plane: Model, role: string, controlMode: string)
	clearMount()
	if not plane or not plane.Parent then return end

	captureCameraState()
	Camera.CameraType = Enum.CameraType.Scriptable

	PlaneCameraController._mount = { plane = plane, role = role, controlMode = controlMode }
	PlaneCameraController._smoothedPos = plane.PrimaryPart and plane.PrimaryPart.Position

	local trove = Trove.new()
	PlaneCameraController._trove = trove

	trove:Add(plane.Destroying:Connect(clearMount))
	trove:Add(plane.AncestryChanged:Connect(function(_, parent)
		if not parent then clearMount() end
	end))

	if role == "Gunner" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		trove:Add(UserInputService.InputChanged:Connect(onInputChanged))
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

-- Camera update per frame ---------------------------------------------------
local PILOT_OFFSET = Vector3.new(0, 10, -32) -- behind + above (relative to course basis)
local GUNNER_OFFSET = Vector3.new(0, 6, -22)
local LOOK_AHEAD = 40 -- Studs to lead with velocity

local function updateCamera(dt: number)
	local mount = PlaneCameraController._mount
	if not mount then return end
	local plane = mount.plane
	if not plane or not plane.Parent then
		clearMount()
		return
	end
	local root = plane.PrimaryPart
	if not root then return end

	-- Predictively smooth the plane position (helps the gunner against jitter)
	local vel = root.AssemblyLinearVelocity
	local actual = root.Position
	-- Lead by a bit of velocity for prediction
	local predicted = actual + vel * (1 / 60)
	local smoothed = PlaneCameraController._smoothedPos or actual
	local alpha = FlightUtil.smoothing(20, dt)
	smoothed = smoothed:Lerp(predicted, alpha)
	PlaneCameraController._smoothedPos = smoothed

	-- Course basis (no plane roll) so camera doesn't violently bank
	local courseCF = FlightUtil.getCourseOrigin()
	local baseCF = CFrame.lookAt(smoothed, smoothed + courseCF.LookVector, courseCF.UpVector)

	if mount.role == "Pilot" or (mount.role == "Gunner" and mount.controlMode == "Autopilot" and false) then
		-- Pilot camera
		local offsetCF = baseCF * CFrame.new(PILOT_OFFSET)
		-- Look ahead down the course
		local lookTarget = smoothed + courseCF.LookVector * LOOK_AHEAD + courseCF.UpVector * 2
		Camera.CFrame = CFrame.lookAt(offsetCF.Position, lookTarget, courseCF.UpVector)
		PlaneCameraController._lookDirection = (Camera.CFrame.LookVector)
	else
		-- Gunner camera (or Autopilot gunner)
		-- Apply gamepad rate-aim (if any) each frame
		if gamepadAim.Magnitude > 0 then
			PlaneCameraController._aim.yaw += -gamepadAim.X * GAMEPAD_RATE * dt
			PlaneCameraController._aim.pitch += gamepadAim.Y * GAMEPAD_RATE * dt
			PlaneCameraController._aim.yaw, PlaneCameraController._aim.pitch = clampAim(
				PlaneCameraController._aim.yaw, PlaneCameraController._aim.pitch
			)
		end

		local yaw = PlaneCameraController._aim.yaw
		local pitch = PlaneCameraController._aim.pitch
		local gunnerBase = baseCF * CFrame.new(GUNNER_OFFSET)
		-- Aim direction relative to course basis
		local aimCF = baseCF * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		local lookForward = aimCF.LookVector
		local focus = smoothed + lookForward * 200
		Camera.CFrame = CFrame.lookAt(gunnerBase.Position, focus, courseCF.UpVector)
		PlaneCameraController._lookDirection = lookForward
	end
end

-- Public helpers for weapon controller --------------------------------------
function PlaneCameraController.getAimTargetPoint(): Vector3?
	local mount = PlaneCameraController._mount
	if not mount then return nil end
	local plane = mount.plane
	if not plane or not plane.Parent then return nil end
	local lookDir = PlaneCameraController._lookDirection
	if not lookDir then return nil end

	-- Raycast from the camera forward against the course for a precise aim point.
	local origin = Camera.CFrame.Position
	local rparams = RaycastParams.new()
	rparams.FilterType = Enum.RaycastFilterType.Include
	local course = workspace:FindFirstChild("FlightCourse")
	if course then
		rparams.FilterDescendantsInstances = { course }
		local hit = workspace:Raycast(origin, lookDir * 1000, rparams)
		if hit then
			return hit.Position
		end
	end
	return origin + lookDir * 800
end

function PlaneCameraController.isMountedAsGunner(): boolean
	local m = PlaneCameraController._mount
	return m ~= nil and m.role == "Gunner"
end

function PlaneCameraController.isMountedAsSoloPilot(): boolean
	local m = PlaneCameraController._mount
	if not m then return false end
	if m.role ~= "Pilot" then return false end
	local plane = m.plane
	if not plane or not plane.Parent then return false end
	local gunnerUserId = plane:GetAttribute(FlightUtil.Attributes.GunnerUserId)
	return gunnerUserId == 0 or gunnerUserId == nil
end

function PlaneCameraController._Init()
	Network.Flight.Mounted:Client():On(function(plane, role, controlMode)
		task.defer(function()
			setupForMount(plane, role, controlMode)
		end)
	end)
	Network.Flight.Unmounted:Client():On(function()
		clearMount()
	end)
end

function PlaneCameraController._PreRenderUpdate(dt: number)
	updateCamera(dt)
end

function PlaneCameraController._CharacterAdded()
	-- If the character respawns while a camera is forced scriptable, restore it.
	if not PlaneCameraController._mount then
		if savedCameraType ~= nil then
			restoreCameraState()
		else
			Camera.CameraType = Enum.CameraType.Custom
		end
	end
end

return PlaneCameraController
