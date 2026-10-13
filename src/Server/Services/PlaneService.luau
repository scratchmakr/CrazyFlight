--!strict
-- PlaneService
-- Manages plane spawn/destruction, pilot/gunner mounting, network ownership,
-- autopilot for solo gunner mode, and session tracking.
--
-- Structural notes:
--  * Supports multiple sessions in principle (keyed by plane); FlightTestService
--    only creates one at a time for the prototype.
--  * The PILOT (if any) owns the physics assembly, so flight is simulated on
--    the pilot's client. The server retains ownership in Autopilot mode.
--  * `_Update` here only drives autopilot movement; damage/fuel/weapons live
--    in dedicated services that read this service's session state.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Network = require(ReplicatedStorage.Shared.Network)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)
local Planes = {
	BasicPlane = require(ReplicatedStorage.Shared.Constants.Planes.BasicPlane),
}
local Guns = {
	BasicCannon = require(ReplicatedStorage.Shared.Constants.Guns.BasicCannon),
}
local TestCourse = require(ReplicatedStorage.Shared.Constants.Courses.TestCourse)

local AssetLoader = require(ServerScriptService.Server.Flight.AssetLoader)

export type Role = "Pilot" | "Gunner"
export type ControlMode = "Pilot" | "Autopilot"

export type Session = {
	id: number,
	plane: Model,
	planeId: string,
	config: typeof(Planes.BasicPlane),
	gunConfig: typeof(Guns.BasicCannon),
	pilot: Player?,
	gunner: Player?,
	controlMode: ControlMode,
	trove: any,
	linearVelocity: LinearVelocity,
	alignOrientation: AlignOrientation,
	pilotSeat: Seat,
	gunnerSeat: Seat,
	gunMounts: { BasePart },
	ended: boolean,
	startTime: number,
}

local PlaneService = {}
PlaneService._sessions = {} :: { [Model]: Session }
PlaneService._playerSessions = {} :: { [Player]: Session }
PlaneService._nextSessionId = 1

-- Signals (other services subscribe to these to avoid circular requires)
PlaneService.SessionStarted = Signal.new() :: Signal.Signal<Session>
PlaneService.SessionEnding = Signal.new() :: Signal.Signal<Session>
PlaneService.PlayerUnmounted = Signal.new() :: Signal.Signal<Player, Session>
PlaneService.PlayerMounted = Signal.new() :: Signal.Signal<Player, Session, Role>

local function getConfig(planeId: string)
	local cfg = Planes[planeId]
	if not cfg then
		warn(`[PlaneService] unknown planeId '{planeId}', falling back to BasicPlane`)
		cfg = Planes.BasicPlane
	end
	return cfg
end

local function getGunConfig(gunId: string)
	local cfg = Guns[gunId]
	if not cfg then
		warn(`[PlaneService] unknown gunId '{gunId}', falling back to BasicCannon`)
		cfg = Guns.BasicCannon
	end
	return cfg
end

local function discoverMounts(plane: Model): { BasePart }
	local gunMountsFolder = plane:FindFirstChild("GunMounts")
	local mounts: { BasePart } = {}
	if not gunMountsFolder then
		return mounts
	end
	-- Sort by name to make barrel ordering deterministic (Mount1, Mount2, ...)
	local children = gunMountsFolder:GetChildren()
	table.sort(children, function(a, b) return a.Name < b.Name end)
	for _, child in children do
		if child:IsA("BasePart") then
			table.insert(mounts, child)
		elseif child:IsA("Attachment") then
			local parent = child.Parent
			if parent and parent:IsA("BasePart") then
				table.insert(mounts, parent)
			end
		end
	end
	return mounts
end

-- Attach a cannon model to a given mount; returns the muzzle attachment.
local function mountCannon(mountPart: BasePart, cannonTemplate: Model): Attachment?
	local cannon = cannonTemplate:Clone()
	cannon.Name = `Cannon_{mountPart.Name}`
	local base = cannon.PrimaryPart or cannon:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") then
		warn(`[PlaneService] cannon template missing PrimaryPart/Base`)
		cannon:Destroy()
		return nil
	end
	cannon:PivotTo(mountPart.CFrame)
	-- Weld base to the mount part
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = mountPart
	weld.Part1 = base
	weld.Parent = base
	-- Make sure all cannon parts are massless and non-colliding
	for _, d in cannon:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= base then
				local w = Instance.new("WeldConstraint")
				w.Part0 = base
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	cannon.Parent = mountPart
	local barrel = cannon:FindFirstChild("Barrel")
	if barrel and barrel:IsA("BasePart") then
		local muzzle = barrel:FindFirstChild("Muzzle")
		if muzzle and muzzle:IsA("Attachment") then
			return muzzle
		end
	end
	-- Fall back: synthesize a muzzle attachment at base
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Parent = base
	return muzzle
end

local function freezeNonRootParts(plane: Model, root: BasePart)
	for _, d in plane:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.CanCollide = false
			-- Only the root does collision queries for the server collision scan.
			-- Mount cannons already set CanQuery=false; keep seats queryable=false too.
			if not d:IsA("Seat") then
				d.CanQuery = false
			end
			d.CanTouch = d:IsA("Seat") -- Seats need touch to detect humanoids
			d.Massless = true
			d.Anchored = false
		end
	end
	root.Anchored = false
end

function PlaneService.getSession(plane: Model): Session?
	return PlaneService._sessions[plane]
end

function PlaneService.getPlayerSession(player: Player): Session?
	return PlaneService._playerSessions[player]
end

function PlaneService.getPlayerPlane(player: Player): Model?
	local s = PlaneService._playerSessions[player]
	return if s then s.plane else nil
end

function PlaneService.getPlaneSession(plane: Model): Session?
	return PlaneService._sessions[plane]
end

-- Returns true if any session is currently active.
function PlaneService.hasActiveSession(): boolean
	return next(PlaneService._sessions) ~= nil
end

-- Spawn a plane. pilot and/or gunner may be nil (solo testing).
function PlaneService.SpawnPlane(pilot: Player?, gunner: Player?, planeId: string, spawnCFrame: CFrame): Session?
	planeId = planeId or "BasicPlane"
	local config = getConfig(planeId)
	local gunConfig = getGunConfig(config.GunId)

	local template = AssetLoader.getPlaneTemplate(planeId)
	local plane = template:Clone()
	plane.Name = `Flight_{planeId}_{PlaneService._nextSessionId}`
	plane:PivotTo(spawnCFrame)

	local root = plane.PrimaryPart
	if not root then
		warn(`[PlaneService] plane template has no PrimaryPart; aborting spawn`)
		plane:Destroy()
		return nil
	end

	freezeNonRootParts(plane, root)

	local pilotSeat = plane:FindFirstChild("PilotSeat")
	local gunnerSeat = plane:FindFirstChild("GunnerSeat")
	if not (pilotSeat and pilotSeat:IsA("Seat") and gunnerSeat and gunnerSeat:IsA("Seat")) then
		warn(`[PlaneService] missing PilotSeat/GunnerSeat`)
		plane:Destroy()
		return nil
	end

	-- Movement attachment + constraints on the root
	local moveAttachment = Instance.new("Attachment")
	moveAttachment.Name = "FlightMove"
	moveAttachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "FlightLinearVelocity"
	linearVelocity.Attachment0 = moveAttachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.ForceLimitsEnabled = false
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.Parent = root

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "FlightAlignOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = moveAttachment
	alignOrientation.RigidityEnabled = false
	alignOrientation.MaxTorque = math.huge
	alignOrientation.MaxAngularVelocity = math.huge
	alignOrientation.Responsiveness = 60
	alignOrientation.CFrame = spawnCFrame
	alignOrientation.Parent = root

	-- Attach guns to mounts
	local gunTemplate = AssetLoader.getGunTemplate(config.GunId)
	local mounts = discoverMounts(plane)
	if #mounts == 0 then
		warn(`[PlaneService] plane has no gun mounts`)
	end
	local muzzles: { Attachment } = {}
	for _, mount in mounts do
		local muzzle = mountCannon(mount, gunTemplate)
		if muzzle then
			table.insert(muzzles, muzzle)
		end
	end

	-- Session struct
	local sessionId = PlaneService._nextSessionId
	PlaneService._nextSessionId += 1
	local trove = Trove.new()
	local session: Session = {
		id = sessionId,
		plane = plane,
		planeId = planeId,
		config = config,
		gunConfig = gunConfig,
		pilot = pilot,
		gunner = gunner,
		controlMode = pilot and "Pilot" or "Autopilot",
		trove = trove,
		linearVelocity = linearVelocity,
		alignOrientation = alignOrientation,
		pilotSeat = pilotSeat,
		gunnerSeat = gunnerSeat,
		gunMounts = mounts,
		ended = false,
		startTime = os.clock(),
	}
	-- Store the muzzle attachments on the session as a side table
	;(session :: any).muzzles = muzzles

	-- Replicated attributes
	plane:SetAttribute(FlightUtil.Attributes.SessionId, sessionId)
	plane:SetAttribute(FlightUtil.Attributes.Hearts, config.MaxHearts)
	plane:SetAttribute(FlightUtil.Attributes.Fuel, config.FuelCapacity)
	plane:SetAttribute(FlightUtil.Attributes.FuelMax, config.FuelCapacity)
	plane:SetAttribute(FlightUtil.Attributes.Heat, 0)
	plane:SetAttribute(FlightUtil.Attributes.HeatMax, gunConfig.MaxHeat)
	plane:SetAttribute(FlightUtil.Attributes.Overheated, false)
	plane:SetAttribute(FlightUtil.Attributes.StartTime, workspace:GetServerTimeNow())
	plane:SetAttribute(FlightUtil.Attributes.Distance, 0)
	plane:SetAttribute(FlightUtil.Attributes.Speed, 0)
	plane:SetAttribute(FlightUtil.Attributes.ControlMode, session.controlMode)
	plane:SetAttribute(FlightUtil.Attributes.PilotUserId, pilot and pilot.UserId or 0)
	plane:SetAttribute(FlightUtil.Attributes.GunnerUserId, gunner and gunner.UserId or 0)

	CollectionService:AddTag(plane, FlightUtil.Tags.FlightPlane)

	plane.Parent = workspace
	PlaneService._sessions[plane] = session

	-- Clean up when the plane is destroyed for any reason
	trove:Add(plane.Destroying:Connect(function()
		PlaneService._cleanupSession(session, "destroyed")
	end))

	-- Mount players
	if pilot then
		PlaneService.MountPlayer(pilot, plane, "Pilot")
	end
	if gunner then
		PlaneService.MountPlayer(gunner, plane, "Gunner")
	end

	-- Give the pilot network ownership (defer so the physics assembly is settled)
	task.defer(function()
		if session.ended then return end
		if pilot and pilot.Parent then
			local success = pcall(function()
				if root:CanSetNetworkOwnership() then
					root:SetNetworkOwner(pilot)
				end
			end)
			if not success then
				root:SetNetworkOwner(nil)
			end
		else
			root:SetNetworkOwner(nil)
		end
	end)

	PlaneService.SessionStarted:Fire(session)
	return session
end

function PlaneService._cleanupSession(session: Session, reason: string?)
	if session.ended then return end
	session.ended = true
	PlaneService.SessionEnding:Fire(session)
	PlaneService._sessions[session.plane] = nil

	-- Unmount any remaining players, teleport them to the testing area.
	for _, role in { "Pilot", "Gunner" } :: { Role } do
		local player = role == "Pilot" and session.pilot or session.gunner
		if player and player.Parent then
			PlaneService._unmountPlayer(player, session, role, true)
		end
	end
	if session.trove then
		session.trove:Destroy()
	end
	if session.plane and session.plane.Parent then
		session.plane:Destroy()
	end
end

function PlaneService.DestroyPlane(plane: Model)
	local session = PlaneService._sessions[plane]
	if session then
		PlaneService._cleanupSession(session, "manual")
	elseif plane and plane.Parent then
		plane:Destroy()
	end
end

-- Teleport a player to the test area (above TestCourse.TestingArea).
local function teleportToTestingArea(player: Player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then return end
	hrp.CFrame = TestCourse.TestingArea * CFrame.new(0, 5, 0)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
	end
end

function PlaneService.MountPlayer(player: Player, plane: Model, role: Role): boolean
	local session = PlaneService._sessions[plane]
	if not session then
		return false
	end
	local char = player.Character
	if not char then
		return false
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		return false
	end
	local seat = (role == "Pilot") and session.pilotSeat or session.gunnerSeat
	-- Teleport first so the Seat can grab it reliably
	hrp.CFrame = seat.CFrame + Vector3.new(0, 3, 0)
	seat:Sit(humanoid)
	player:SetAttribute(FlightUtil.Attributes.PlayerRole, role)
	PlaneService._playerSessions[player] = session
	Network.Flight.Mounted:Server():Fire(player, plane, role, session.controlMode)

	-- Watch for unexpected dismount (seat.Occupant changes to nil or humanoid dies)
	local function onOccupantChanged()
		if session.ended then return end
		if seat.Occupant ~= humanoid then
			-- Only treat as leaving the role; don't end the entire session unless both are gone
			PlaneService._handleRoleLeft(session, role, player)
		end
	end
	session.trove:Add(seat:GetPropertyChangedSignal("Occupant"):Connect(onOccupantChanged))
	session.trove:Add(humanoid.Died:Connect(function()
		if session.ended then return end
		PlaneService._handleRoleLeft(session, role, player)
	end))

	PlaneService.PlayerMounted:Fire(player, session, role)
	return true
end

function PlaneService._unmountPlayer(player: Player, session: Session, role: Role, teleport: boolean)
	if player then
		if role == "Pilot" then
			session.pilot = nil
		else
			session.gunner = nil
		end
		PlaneService._playerSessions[player] = nil
		player:SetAttribute(FlightUtil.Attributes.PlayerRole, nil)
		if teleport then
			teleportToTestingArea(player)
		end
		if player.Parent then
			pcall(function()
				Network.Flight.Unmounted:Server():Fire(player)
			end)
		end
		PlaneService.PlayerUnmounted:Fire(player, session)
	end
end

function PlaneService.UnmountPlayer(player: Player)
	local session = PlaneService._playerSessions[player]
	if not session then return end
	local role: Role = session.pilot == player and "Pilot" or "Gunner"
	PlaneService._unmountPlayer(player, session, role, true)
end

-- Called when a role seat loses its occupant unexpectedly.
function PlaneService._handleRoleLeft(session: Session, role: Role, player: Player)
	if session.ended then return end
	-- Mark the role empty
	PlaneService._unmountPlayer(player, session, role, true)

	-- If both roles are now empty, end the session.
	if not session.pilot and not session.gunner then
		PlaneService._cleanupSession(session, "abandoned")
		return
	end
	-- If pilot left but gunner remains, flip to Autopilot mode and take server ownership.
	if role == "Pilot" and session.gunner then
		session.controlMode = "Autopilot"
		session.plane:SetAttribute(FlightUtil.Attributes.ControlMode, "Autopilot")
		if session.plane.PrimaryPart then
			pcall(function()
				session.plane.PrimaryPart:SetNetworkOwner(nil)
			end)
		end
		-- Notify the remaining gunner so their HUD/camera can update if needed
		Network.Flight.Mounted:Server():Fire(session.gunner, session.plane, "Gunner", "Autopilot")
	end
end

-- Player disconnect / character reset handling ------------------------------
function PlaneService._PlayerRemoving(player: Player)
	local session = PlaneService._playerSessions[player]
	if not session then return end
	local role: Role = session.pilot == player and "Pilot" or "Gunner"
	PlaneService._handleRoleLeft(session, role, player)
end

function PlaneService._CharacterAdded(player: Player)
	-- If a player respawns mid-session, they are no longer in the plane.
	local session = PlaneService._playerSessions[player]
	if session and not session.ended then
		local role: Role = session.pilot == player and "Pilot" or "Gunner"
		PlaneService._handleRoleLeft(session, role, player)
	end
end

-- Autopilot update ----------------------------------------------------------
function PlaneService._Update(dt: number)
	for _, session in PlaneService._sessions do
		if session.ended then continue end
		if session.controlMode ~= "Autopilot" then continue end
		local plane = session.plane
		local root = plane.PrimaryPart
		if not root then continue end

		local cfg = session.config
		local pos = root.Position
		local distance = FlightUtil.forwardDistance(pos)
		local offX, offY = FlightUtil.autopilotOffset(distance + 60) -- Look ahead
		local targetCF = FlightUtil.courseCFrame(distance + 60, offX, offY)
		local toTarget = (targetCF.Position - pos)
		local forward = FlightUtil.getCourseOrigin().LookVector
		local right = FlightUtil.getCourseOrigin().RightVector
		local up = FlightUtil.getCourseOrigin().UpVector

		-- Horizontal / vertical steering components
		local horiz = math.clamp(toTarget:Dot(right) * 0.1, -1, 1)
		local vert = math.clamp(toTarget:Dot(up) * 0.1, -1, 1)
		local target = forward * cfg.CruiseSpeed
			+ right * horiz * cfg.HorizontalSpeed
			+ up * vert * cfg.VerticalSpeed

		-- Smooth
		local current = session.linearVelocity.VectorVelocity
		local alpha = FlightUtil.smoothing(cfg.SteeringResponsiveness, dt)
		session.linearVelocity.VectorVelocity = current:Lerp(target, alpha)

		-- Visual bank/pitch
		local bank = math.rad(-horiz * cfg.MaxBankAngle)
		local pitch = math.rad(vert * cfg.MaxPitchAngle)
		local goal = FlightUtil.getCourseOrigin() * CFrame.Angles(pitch, 0, bank)
		local currentCF = session.alignOrientation.CFrame
		local orientAlpha = FlightUtil.smoothing(cfg.BankingResponsiveness, dt)
		session.alignOrientation.CFrame = currentCF:Lerp(goal, orientAlpha)
	end
end

function PlaneService._Init()
	-- Nothing to pre-initialise; everything runs on demand from other services.
end

return PlaneService
