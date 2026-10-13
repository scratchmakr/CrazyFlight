--!strict
-- PlaneWeaponController
-- Handles gunner (and solo-pilot debug) fire input, renders traveling bullet
-- visuals from server-authoritative ProjectileFired/ProjectileImpact events,
-- and renders a quick prediction tracer locally while waiting for the server
-- to echo the shot.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Network = require(ReplicatedStorage.Shared.Network)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)
local GameConfig = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Guns = {
	BasicCannon = require(ReplicatedStorage.Shared.Constants.Guns.BasicCannon),
}

local PlaneCameraController = require(script.Parent.PlaneCameraController)
local PlaneController = require(script.Parent.PlaneController)

local LocalPlayer = Players.LocalPlayer

local PlaneWeaponController = {}
PlaneWeaponController._trove = nil :: any
PlaneWeaponController._mount = nil :: any
PlaneWeaponController._shotId = 0
PlaneWeaponController._fireHeld = false

-- Projectile visuals (keyed by server id)
local Projectiles: { [number]: {
	id: number,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	lifetime: number,
	spawnedAt: number,
	part: BasePart,
} } = {}

local BULLET_COLOR = Color3.fromRGB(255, 220, 80)
local BULLET_SIZE = Vector3.new(0.35, 0.35, 1.6)

local function makeBulletPart(): BasePart
	local p = Instance.new("Part")
	p.Name = "FlightBullet"
	p.Size = BULLET_SIZE
	p.Material = Enum.Material.Neon
	p.Color = BULLET_COLOR
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	local l = Instance.new("PointLight")
	l.Range = 6
	l.Brightness = 2
	l.Color = BULLET_COLOR
	l.Parent = p
	return p
end

local function spawnMuzzleFlash(position: Vector3)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.6, 0.6, 0.6)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 240, 180)
	p.Position = position
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 0.1
	p.Parent = workspace
	Debris:AddItem(p, 0.08)
end

local function spawnImpactBurst(position: Vector3, color: Color3?)
	local p = Instance.new("Part")
	p.Size = Vector3.new(2, 2, 2)
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = color or Color3.fromRGB(255, 180, 90)
	p.Position = position
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 0.2
	p.Parent = workspace
	Debris:AddItem(p, 0.2)
end

local function registerProjectile(id: number, origin: Vector3, velocity: Vector3, gravity: number, lifetime: number)
	if Projectiles[id] then
		Projectiles[id].part:Destroy()
	end
	local part = makeBulletPart()
	-- Point along velocity
	if velocity.Magnitude > 0 then
		part.CFrame = CFrame.lookAt(origin, origin + velocity.Unit)
	else
		part.Position = origin
	end
	part.Parent = workspace
	Projectiles[id] = {
		id = id,
		origin = origin,
		velocity = velocity,
		gravity = gravity,
		lifetime = lifetime,
		spawnedAt = os.clock(),
		part = part,
	}
end

local function destroyProjectile(id: number)
	local p = Projectiles[id]
	if p then
		Projectiles[id] = nil
		if p.part and p.part.Parent then
			p.part:Destroy()
		end
	end
end

-- Fire input handling -------------------------------------------------------
local function canFire(): boolean
	local mount = PlaneWeaponController._mount
	if not mount then return false end
	local plane = mount.plane
	if not plane or not plane.Parent then return false end
	local overheated = plane:GetAttribute(FlightUtil.Attributes.Overheated)
	if overheated then return false end
	-- Role allowed?
	if mount.role == "Gunner" then return true end
	-- Solo pilot debug fire
	if mount.role == "Pilot" and GameConfig.DebugMode and GameConfig.SoloPilotDebugFire then
		local gunnerId = plane:GetAttribute(FlightUtil.Attributes.GunnerUserId)
		return gunnerId == 0 or gunnerId == nil
	end
	return false
end

local lastFireClient = 0

local function tryFire()
	if not canFire() then return end
	local mount = PlaneWeaponController._mount
	if not mount then return end
	local plane = mount.plane
	if not plane or not plane.Parent then return end
	local now = os.clock()
	local gunCfg = Guns.BasicCannon -- Prototype has one weapon type
	local period = 1 / math.max(0.001, gunCfg.FireRate)
	if (now - lastFireClient) < period then return end
	lastFireClient = now

	-- Compute target point
	local target: Vector3
	if mount.role == "Gunner" then
		target = PlaneCameraController.getAimTargetPoint()
			or (plane.PrimaryPart and plane.PrimaryPart.Position + FlightUtil.getCourseOrigin().LookVector * 400)
			or Vector3.zero
	else
		-- Solo-pilot debug fire: aim straight ahead along the course
		local root = plane.PrimaryPart
		if root then
			target = root.Position + FlightUtil.getCourseOrigin().LookVector * 400
		else
			target = Vector3.zero
		end
	end

	PlaneWeaponController._shotId += 1
	Network.Flight.Fire:Client():Fire(PlaneWeaponController._shotId, target)

	-- Local muzzle flash feedback (best-effort; the actual muzzle part may be
	-- hard to pick without state, so use the first mount position)
	local gunMounts = plane:FindFirstChild("GunMounts")
	if gunMounts then
		local list = gunMounts:GetChildren()
		if #list > 0 then
			local mountPart = list[1]
			if mountPart:IsA("BasePart") then
				spawnMuzzleFlash(mountPart.Position)
			end
		end
	end
end

local function onFire(_actionName, state, _input)
	if state == Enum.UserInputState.Begin then
		PlaneWeaponController._fireHeld = true
		tryFire()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		PlaneWeaponController._fireHeld = false
	end
	return Enum.ContextActionResult.Pass
end

-- Mount lifecycle ----------------------------------------------------------
local function clearMount()
	if PlaneWeaponController._trove then
		PlaneWeaponController._trove:Destroy()
		PlaneWeaponController._trove = nil
	end
	PlaneWeaponController._mount = nil
	PlaneWeaponController._fireHeld = false
	-- Clear any live projectile visuals that referenced our session
	for id, p in Projectiles do
		if p.part and p.part.Parent then
			p.part:Destroy()
		end
		Projectiles[id] = nil
	end
	ContextActionService:UnbindAction("CrazyFlight_Fire")
end

local function setupMount(plane: Model, role: string, controlMode: string)
	clearMount()
	PlaneWeaponController._mount = { plane = plane, role = role, controlMode = controlMode }
	local trove = Trove.new()
	PlaneWeaponController._trove = trove

	trove:Add(plane.Destroying:Connect(clearMount))

	-- Bind fire for gunner. For solo-pilot debug fire, PlaneController binds F
	-- via its own action; we poll its pilotInput table.
	if role == "Gunner" then
		ContextActionService:BindAction("CrazyFlight_Fire", onFire, true,
			Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle("CrazyFlight_Fire", "Fire")
		ContextActionService:SetPosition("CrazyFlight_Fire", UDim2.new(1, -170, 0.5, -50))
	end
end

-- Projectile stepping -------------------------------------------------------
local function stepProjectiles(_dt: number)
	local now = os.clock()
	for id, p in Projectiles do
		local age = now - p.spawnedAt
		if age > p.lifetime + 0.5 then
			destroyProjectile(id)
			continue
		end
		local pos = FlightUtil.projectilePosition(p.origin, p.velocity, p.gravity, age)
		if p.velocity.Magnitude > 0 then
			p.part.CFrame = CFrame.lookAt(pos, pos + p.velocity.Unit)
		else
			p.part.Position = pos
		end
	end
end

local function onFeedback(feedback)
	if feedback.kind == "BarrierDestroyed" and feedback.position then
		spawnImpactBurst(feedback.position, Color3.fromRGB(240, 90, 60))
	elseif feedback.kind == "BarrierHit" and feedback.position then
		spawnImpactBurst(feedback.position, Color3.fromRGB(240, 170, 60))
	elseif feedback.kind == "FuelCollected" and feedback.position then
		spawnImpactBurst(feedback.position, Color3.fromRGB(255, 240, 90))
	end
end

function PlaneWeaponController._Init()
	Network.Flight.Mounted:Client():On(function(plane, role, controlMode)
		task.defer(function()
			setupMount(plane, role, controlMode)
		end)
	end)
	Network.Flight.Unmounted:Client():On(function()
		clearMount()
	end)
	Network.Flight.ProjectileFired:Client():On(function(projectile)
		registerProjectile(projectile.id, projectile.origin, projectile.velocity, projectile.gravity, projectile.lifetime)
	end)
	Network.Flight.ProjectileImpact:Client():On(function(impact)
		destroyProjectile(impact.id)
		if impact.kind ~= "Expired" then
			spawnImpactBurst(impact.position)
		end
	end)
	Network.Flight.Feedback:Client():On(onFeedback)
end

function PlaneWeaponController._PreRenderUpdate(dt: number)
	stepProjectiles(dt)

	-- Automatic fire while held (gunner)
	local mount = PlaneWeaponController._mount
	if not mount then return end
	if mount.role == "Gunner" and PlaneWeaponController._fireHeld then
		tryFire()
	end

	-- Solo-pilot debug fire while F is held
	if mount.role == "Pilot" and GameConfig.DebugMode and GameConfig.SoloPilotDebugFire then
		if PlaneController._pilotInput and PlaneController._pilotInput.debugFire then
			tryFire()
		end
	end
end

return PlaneWeaponController
