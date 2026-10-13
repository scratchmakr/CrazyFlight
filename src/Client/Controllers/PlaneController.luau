--!strict
-- PlaneController
-- Local pilot flight: reads movement input, drives the plane's LinearVelocity
-- and AlignOrientation on each PreRender while mounted as Pilot. Disables jump
-- while in a seat.
--
-- Other controllers (Camera, UI, Weapon) listen to Mounted/Unmounted
-- separately; this one only cares about pilot control.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Network = require(ReplicatedStorage.Shared.Network)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)
local GameConfig = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Planes = {
	BasicPlane = require(ReplicatedStorage.Shared.Constants.Planes.BasicPlane),
}

local LocalPlayer = Players.LocalPlayer

type MountInfo = {
	plane: Model,
	role: string,
	controlMode: string,
	config: any,
}

local PlaneController = {}
PlaneController._mount = nil :: MountInfo?
PlaneController._trove = nil :: any
PlaneController.MountChanged = Signal.new() :: Signal.Signal<MountInfo?>

-- Shared pilot input state (also read by weapon controller for debug fire)
local pilotInput = {
	moveX = 0,
	moveY = 0,
	boost = false,
	brake = false,
	debugFire = false,
}
PlaneController._pilotInput = pilotInput

local function getConfigForPlane(plane: Model)
	local id = plane.Name:match("^Flight_(.-)_") or "BasicPlane"
	return Planes[id] or Planes.BasicPlane
end

function PlaneController.getMount(): MountInfo?
	return PlaneController._mount
end

local function readMovement(): (number, number)
	-- Prefer the engine's control module (handles mobile + gamepad + WASD)
	local ok, moveVec = pcall(function()
		local pscripts = LocalPlayer:FindFirstChildOfClass("PlayerScripts")
		if not pscripts then return Vector3.zero end
		local playerModule = pscripts:FindFirstChild("PlayerModule")
		if not playerModule then return Vector3.zero end
		local module = require(playerModule :: any)
		if typeof(module.GetControls) ~= "function" then return Vector3.zero end
		local controls = module:GetControls()
		if controls and typeof(controls.GetMoveVector) == "function" then
			return controls:GetMoveVector()
		end
		return Vector3.zero
	end)
	if ok and typeof(moveVec) == "Vector3" then
		-- Z<0 is "forward" in the engine convention. In our arcade mapping,
		-- "W" (forward) means pitch UP, so flip Z and use it as vertical.
		local x = moveVec.X
		local y = -moveVec.Z
		return FlightUtil.clampInput(x, y)
	end
	-- Keyboard fallback
	local x = 0
	local y = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then x += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then x -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then y += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then y -= 1 end
	return FlightUtil.clampInput(x, y)
end

local function bindActions()
	local function onBoost(_actionName, state)
		pilotInput.boost = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		return Enum.ContextActionResult.Pass
	end
	local function onBrake(_actionName, state)
		pilotInput.brake = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		return Enum.ContextActionResult.Pass
	end
	local function onDebugFire(_actionName, state)
		pilotInput.debugFire = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindAction("CrazyFlight_Boost", onBoost, true,
		Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("CrazyFlight_Boost", "Boost")
	ContextActionService:SetPosition("CrazyFlight_Boost", UDim2.new(1, -170, 1, -170))

	ContextActionService:BindAction("CrazyFlight_Brake", onBrake, true,
		Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("CrazyFlight_Brake", "Brake")
	ContextActionService:SetPosition("CrazyFlight_Brake", UDim2.new(1, -170, 1, -300))

	if GameConfig.DebugMode and GameConfig.SoloPilotDebugFire then
		ContextActionService:BindAction("CrazyFlight_DebugFire", onDebugFire, false, Enum.KeyCode.F)
	end
end

local function unbindActions()
	ContextActionService:UnbindAction("CrazyFlight_Boost")
	ContextActionService:UnbindAction("CrazyFlight_Brake")
	ContextActionService:UnbindAction("CrazyFlight_DebugFire")
	pilotInput.moveX = 0
	pilotInput.moveY = 0
	pilotInput.boost = false
	pilotInput.brake = false
	pilotInput.debugFire = false
end

local function clearMount()
	if PlaneController._trove then
		PlaneController._trove:Destroy()
		PlaneController._trove = nil
	end
	PlaneController._mount = nil
	unbindActions()
	PlaneController.MountChanged:Fire(nil)
end

local function setMount(plane: Model, role: string, controlMode: string)
	clearMount()
	local info: MountInfo = {
		plane = plane,
		role = role,
		controlMode = controlMode,
		config = getConfigForPlane(plane),
	}
	PlaneController._mount = info
	local trove = Trove.new()
	PlaneController._trove = trove

	-- When the plane is destroyed, treat it as unmount locally.
	trove:Add(plane.Destroying:Connect(function()
		clearMount()
	end))
	trove:Add(plane.AncestryChanged:Connect(function(_, parent)
		if not parent then
			clearMount()
		end
	end))

	-- Disable jumping while mounted
	local character = LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.JumpPower = 0
			humanoid.UseJumpPower = true
			trove:Add(function()
				if humanoid.Parent then
					humanoid.JumpPower = 50
				end
			end)
		end
	end

	-- Only the Pilot in Pilot-control mode binds flight input + drives physics.
	if role == "Pilot" and controlMode == "Pilot" then
		bindActions()
	end

	PlaneController.MountChanged:Fire(info)
end

-- Pilot flight update -------------------------------------------------------
local function updatePilotFlight(dt: number)
	local mount = PlaneController._mount
	if not mount then return end
	if mount.role ~= "Pilot" then return end
	if mount.controlMode ~= "Pilot" then return end
	local plane = mount.plane
	if not plane or not plane.Parent then return end
	local root = plane.PrimaryPart
	if not root then return end
	local lv = root:FindFirstChild("FlightLinearVelocity")
	local ao = root:FindFirstChild("FlightAlignOrientation")
	if not (lv and lv:IsA("LinearVelocity") and ao and ao:IsA("AlignOrientation")) then
		return
	end

	-- Read input each frame
	local mx, my = readMovement()
	pilotInput.moveX = mx
	pilotInput.moveY = my

	local cfg = mount.config
	local forward = FlightUtil.getCourseOrigin().LookVector
	local up = FlightUtil.getCourseOrigin().UpVector
	local right = FlightUtil.getCourseOrigin().RightVector

	local speed = cfg.CruiseSpeed
	if pilotInput.boost then
		speed = cfg.BoostSpeed
	elseif pilotInput.brake then
		speed = cfg.BrakeSpeed
	end
	if not GameConfig.AutoForward then
		speed = speed * (my > 0 and 1 or (my < 0 and 0.3 or 0.6))
	end

	local target = forward * speed
		+ right * (mx * cfg.HorizontalSpeed)
		+ up * (my * cfg.VerticalSpeed)

	-- Soft keep-in-bounds nudge: push away if close to the edge
	local pos = root.Position
	local b = require(ReplicatedStorage.Shared.Constants.Courses.TestCourse).Bounds
	local local_ = FlightUtil.getCourseOrigin():PointToObjectSpace(pos)
	if math.abs(local_.X) > b.X * 0.85 then
		target = target - right * math.sign(local_.X) * cfg.HorizontalSpeed * 0.5
	end
	if math.abs(local_.Y) > b.Y * 0.85 then
		target = target - up * math.sign(local_.Y) * cfg.VerticalSpeed * 0.5
	end

	local current = lv.VectorVelocity
	local alpha = FlightUtil.smoothing(cfg.SteeringResponsiveness, dt)
	lv.VectorVelocity = current:Lerp(target, alpha)

	-- Visual bank + pitch (not actual aerodynamics)
	local bank = math.rad(-mx * cfg.MaxBankAngle)
	local pitch = math.rad(my * cfg.MaxPitchAngle)
	local goal = FlightUtil.getCourseOrigin() * CFrame.Angles(pitch, 0, bank)
	local currentCF = ao.CFrame
	local orientAlpha = FlightUtil.smoothing(cfg.BankingResponsiveness, dt)
	ao.CFrame = currentCF:Lerp(goal, orientAlpha)
end

function PlaneController._Init()
	Network.Flight.Mounted:Client():On(function(plane, role, controlMode)
		-- Defer so the plane model is likely fully replicated with constraints
		task.defer(function()
			if plane and plane.Parent then
				setMount(plane, role, controlMode)
			end
		end)
	end)
	Network.Flight.Unmounted:Client():On(function()
		clearMount()
	end)
end

function PlaneController._PreRenderUpdate(dt: number)
	updatePilotFlight(dt)
end

return PlaneController
