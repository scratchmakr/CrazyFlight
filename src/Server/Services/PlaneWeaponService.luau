--!strict
-- PlaneWeaponService
-- Validates fire requests from the gunner (or solo-debug pilot), tracks the
-- shared weapon heat pool, alternates fire between barrels, simulates
-- projectiles on the server with raycasting, and broadcasts projectile
-- lifecycle to clients.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.Shared.Network)
local GameConfig = require(ReplicatedStorage.Shared.Constants.GameConfig)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)

local PlaneService = require(script.Parent.PlaneService)
local FlightRunService = require(script.Parent.FlightRunService)

local PlaneWeaponService = {}

export type WeaponState = {
	session: any,
	heat: number,
	overheated: boolean,
	nextShotAt: number,
	barrelIndex: number,
	projectiles: { [number]: Projectile },
	nextProjectileId: number,
	lastShotTimes: { [Player]: { number } }, -- rolling window for rate check
}

type Projectile = {
	id: number,
	shooterId: number,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	lifetime: number,
	spawnedAt: number,
	lastPosition: Vector3,
	damage: number,
}

PlaneWeaponService._states = {} :: { [any]: WeaponState }

-- Keep a rolling window of recent client shot timestamps to catch spam.
-- Allows up to ceil(FireRate * 1.5) shots per second with a tolerance window.
local function recordAndCheckShotRate(state: WeaponState, player: Player, gunCfg: any): boolean
	local now = os.clock()
	local windowEnd = now
	local windowStart = now - 1.0
	local list = state.lastShotTimes[player]
	if not list then
		list = {}
		state.lastShotTimes[player] = list
	end
	-- Drop old entries
	local writeIndex = 1
	for i = 1, #list do
		if list[i] >= windowStart then
			list[writeIndex] = list[i]
			writeIndex += 1
		end
	end
	for i = writeIndex, #list do
		list[i] = nil
	end
	local maxAllowed = math.ceil(gunCfg.FireRate * 1.5)
	if #list >= maxAllowed then
		return false
	end
	table.insert(list, now)
	return true
end

local function ensureState(session: any): WeaponState
	local state = PlaneWeaponService._states[session]
	if state then return state end
	state = {
		session = session,
		heat = 0,
		overheated = false,
		nextShotAt = 0,
		barrelIndex = 0,
		projectiles = {},
		nextProjectileId = 1,
		lastShotTimes = {},
	}
	PlaneWeaponService._states[session] = state
	return state
end

local function broadcastSessionPlayers(session: any, event, payload)
	for _, player in { session.pilot, session.gunner } do
		if player and player.Parent then
			pcall(function()
				event:Server():Fire(player, payload)
			end)
		end
	end
end

local function broadcastProjectileToAll(event, payload)
	for _, player in Players:GetPlayers() do
		pcall(function()
			event:Server():Fire(player, payload)
		end)
	end
end

-- Fire a shot (server-authoritative) ---------------------------------------
local function handleFire(player: Player, _shotId: number, targetPoint: Vector3)
	local session = PlaneService.getPlayerSession(player)
	if not session or session.ended then return end

	-- Role check: gunner always allowed. Pilot allowed only in solo debug.
	local isGunner = session.gunner == player
	local isSoloPilot = session.pilot == player and session.gunner == nil
	if not isGunner and not (isSoloPilot and GameConfig.SoloPilotDebugFire) then
		return
	end

	local gunCfg = session.gunConfig
	local state = ensureState(session)

	-- Rate limit
	if not recordAndCheckShotRate(state, player, gunCfg) then
		return
	end
	local now = os.clock()
	if now < state.nextShotAt then
		return
	end
	if GameConfig.EnableWeaponOverheat and state.overheated then
		return
	end

	local mounts = session.gunMounts :: { BasePart }
	if #mounts == 0 then return end

	-- Alternate barrels round-robin
	state.barrelIndex = (state.barrelIndex % #mounts) + 1
	local mount = mounts[state.barrelIndex]
	-- Find the muzzle attachment: a cannon was welded under each mount.
	local muzzle: Attachment?
	local cannon = mount:FindFirstChild(`Cannon_{mount.Name}`)
	if cannon then
		local barrel = cannon:FindFirstChild("Barrel")
		if barrel and barrel:IsA("BasePart") then
			local m = barrel:FindFirstChild("Muzzle")
			if m and m:IsA("Attachment") then
				muzzle = m
			end
		end
	end
	local origin: Vector3
	if muzzle then
		origin = muzzle.WorldPosition
	else
		origin = mount.Position
	end

	local plane = session.plane
	local root = plane.PrimaryPart
	if not root then return end

	-- Direction: toward target point, clamped to arc from plane forward
	local planeForward = root.CFrame.LookVector
	-- Course forward (stable reference regardless of banking)
	local courseForward = FlightUtil.getCourseOrigin().LookVector
	local courseUp = FlightUtil.getCourseOrigin().UpVector
	local courseRight = FlightUtil.getCourseOrigin().RightVector
	local toTarget = (targetPoint - origin)
	if toTarget.Magnitude < 1e-3 then
		toTarget = courseForward * 100
	end
	local dir = FlightUtil.clampAimDirection(courseForward, courseUp, courseRight, toTarget.Unit, gunCfg.MaxAimYaw, gunCfg.MaxAimPitch)

	-- Apply server-side spread
	if gunCfg.Spread and gunCfg.Spread > 0 then
		local spreadRad = math.rad(gunCfg.Spread)
		local randYaw = (math.random() * 2 - 1) * spreadRad
		local randPitch = (math.random() * 2 - 1) * spreadRad
		dir = (dir * math.cos(randYaw) + courseRight * math.sin(randYaw))
		dir = (dir * math.cos(randPitch) + courseUp * math.sin(randPitch)).Unit
	end

	local baseVelocity = dir * gunCfg.ProjectileSpeed
	local planeVel = root.AssemblyLinearVelocity * (session.config.InheritVelocityFactor or 0)
	local velocity = baseVelocity + planeVel

	-- Rate / heat
	local period = 1 / math.max(0.0001, gunCfg.FireRate)
	state.nextShotAt = now + period
	if GameConfig.EnableWeaponOverheat then
		state.heat = math.min(gunCfg.MaxHeat, state.heat + gunCfg.HeatPerShot)
		if state.heat >= gunCfg.MaxHeat then
			state.overheated = true
			plane:SetAttribute(FlightUtil.Attributes.Overheated, true)
			broadcastSessionPlayers(session, Network.Flight.Feedback, { kind = "Overheated" })
		end
		plane:SetAttribute(FlightUtil.Attributes.Heat, math.floor(state.heat))
	end

	local projectile: Projectile = {
		id = state.nextProjectileId,
		shooterId = player.UserId,
		origin = origin,
		velocity = velocity,
		gravity = gunCfg.ProjectileGravity or 0,
		lifetime = gunCfg.ProjectileLifetime or 3,
		spawnedAt = now,
		lastPosition = origin,
		damage = gunCfg.Damage or 1,
	}
	state.projectiles[projectile.id] = projectile
	state.nextProjectileId += 1

	broadcastProjectileToAll(Network.Flight.ProjectileFired, {
		id = projectile.id,
		shooterId = projectile.shooterId,
		origin = projectile.origin,
		velocity = projectile.velocity,
		gravity = projectile.gravity,
		lifetime = projectile.lifetime,
	})
end

-- Projectile stepping -------------------------------------------------------
local projectileRaycastParams = RaycastParams.new()
projectileRaycastParams.FilterType = Enum.RaycastFilterType.Include

local function retireProjectile(state: WeaponState, projectile: Projectile, position: Vector3, kind: string)
	if state.projectiles[projectile.id] == nil then return end
	state.projectiles[projectile.id] = nil
	broadcastProjectileToAll(Network.Flight.ProjectileImpact, {
		id = projectile.id,
		position = position,
		kind = kind,
	})
end

local function stepProjectiles(state: WeaponState, dt: number)
	local session = state.session
	if session.ended then return end
	local course = workspace:FindFirstChild("FlightCourse")
	for _id, projectile in state.projectiles do
		local age = os.clock() - projectile.spawnedAt
		if age >= projectile.lifetime then
			retireProjectile(state, projectile, projectile.lastPosition, "Expired")
			continue
		end
		local newPos = FlightUtil.projectilePosition(projectile.origin, projectile.velocity, projectile.gravity, age)
		local segment = newPos - projectile.lastPosition
		if segment.Magnitude > 0 and course then
			projectileRaycastParams.FilterDescendantsInstances = { course }
			local hit = workspace:Raycast(projectile.lastPosition, segment, projectileRaycastParams)
			if hit and hit.Instance then
				local part = hit.Instance
				local kind: string
				if CollectionService:HasTag(part, FlightUtil.Tags.FlightTarget) then
					local tKind = part:GetAttribute(FlightUtil.Attributes.TargetKind)
					local damaged = FlightRunService.DamageTarget(session, part, projectile.damage)
					kind = tKind == "Fuel" and "Fuel" or (damaged and "Barrier" or "World")
				elseif CollectionService:HasTag(part, FlightUtil.Tags.FlightLethal) then
					kind = "Lethal"
				elseif CollectionService:HasTag(part, FlightUtil.Tags.FlightFinish) then
					kind = "Finish"
				else
					kind = "World"
				end
				retireProjectile(state, projectile, hit.Position, kind)
				continue
			end
		end
		projectile.lastPosition = newPos
	end
end

-- Heartbeat update ----------------------------------------------------------
function PlaneWeaponService._Update(dt: number)
	for session, state in PlaneWeaponService._states do
		if session.ended then
			-- Clear projectiles for ended sessions
			for id in state.projectiles do
				state.projectiles[id] = nil
			end
			PlaneWeaponService._states[session] = nil
			continue
		end
		local gunCfg = session.gunConfig
		-- Cool down
		if GameConfig.EnableWeaponOverheat and state.heat > 0 then
			state.heat = math.max(0, state.heat - gunCfg.CoolingRate * dt)
			local plane = session.plane
			plane:SetAttribute(FlightUtil.Attributes.Heat, math.floor(state.heat))
			if state.overheated and state.heat < gunCfg.OverheatRecoveryThreshold then
				state.overheated = false
				plane:SetAttribute(FlightUtil.Attributes.Overheated, false)
			end
		end
		stepProjectiles(state, dt)
	end
end

function PlaneWeaponService._Init()
	Network.Flight.Fire:Server():On(function(player: Player, shotId, targetPoint)
		handleFire(player, shotId, targetPoint)
	end)
	PlaneService.SessionStarted:Connect(function(session)
		ensureState(session)
	end)
	PlaneService.SessionEnding:Connect(function(session)
		local state = PlaneWeaponService._states[session]
		if state then
			-- Expire any live projectiles so clients clean up visuals
			for _id, projectile in state.projectiles do
				retireProjectile(state, projectile, projectile.lastPosition, "Expired")
			end
			PlaneWeaponService._states[session] = nil
		end
	end)
end

return PlaneWeaponService
