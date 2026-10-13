--!strict
-- FlightRunService
-- Tracks each active run: hearts, fuel, elapsed time, distance, finish/fail.
-- Owns server-side collision detection against the course (barriers, lethal
-- obstacles, finish line), fuel drain, and plausibility checks.
--
-- Depends on PlaneService (session lifecycle). Called by PlaneWeaponService
-- for weapon-based target damage.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.Shared.Network)
local GameConfig = require(ReplicatedStorage.Shared.Constants.GameConfig)
local TestCourse = require(ReplicatedStorage.Shared.Constants.Courses.TestCourse)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)

local PlaneService = require(script.Parent.PlaneService)
local CourseBuilder = require(ServerScriptService.Server.Flight.CourseBuilder)

export type RunState = {
	session: any,
	hearts: number,
	fuel: number,
	distance: number,
	elapsed: number,
	startTime: number,
	finished: boolean,
	ending: boolean,
	hitCooldownUntil: number, -- timestamp before which no new non-lethal damage
	targetCooldown: { [Instance]: number }, -- per-target cooldown
	fastSpeedSince: number?, -- plausibility
	lastAttrPush: number,
	lastSpeed: number,
	courseFolder: Folder?,
}

local FlightRunService = {}
FlightRunService._runs = {} :: { [any]: RunState }

local ATTR_PUSH_INTERVAL = 0.2 -- 5 Hz attribute replication throttle
local FUEL_DRAIN_INTERVAL = 0.1
local DAMAGE_INVULN_FALLBACK = 0.6

-- Internal utilities --------------------------------------------------------
local function endRun(run: RunState, success: boolean, reason: string)
	if run.ending then return end
	run.ending = true
	run.finished = true
	local session = run.session
	local pilot = session.pilot
	local gunner = session.gunner
	local payload = {
		success = success,
		reason = reason,
		time = run.elapsed,
		distance = run.distance,
	}
	if pilot and pilot.Parent then
		pcall(function() Network.Flight.RunEnded:Server():Fire(pilot, payload) end)
	end
	if gunner and gunner.Parent then
		pcall(function() Network.Flight.RunEnded:Server():Fire(gunner, payload) end)
	end
	-- End the plane session; also removes everyone from seats + teleports.
	task.defer(function()
		PlaneService.DestroyPlane(session.plane)
	end)
end

local function sendFeedback(run: RunState, kind: string, position: Vector3?, amount: number?)
	local session = run.session
	for _, player in { session.pilot, session.gunner } do
		if player and player.Parent then
			pcall(function()
				Network.Flight.Feedback:Server():Fire(player, {
					kind = kind,
					position = position,
					amount = amount,
				})
			end)
		end
	end
end

local function pushAttributes(run: RunState, force: boolean?)
	local now = os.clock()
	if not force and (now - run.lastAttrPush) < ATTR_PUSH_INTERVAL then
		return
	end
	run.lastAttrPush = now
	local plane = run.session.plane
	plane:SetAttribute(FlightUtil.Attributes.Hearts, run.hearts)
	plane:SetAttribute(FlightUtil.Attributes.Fuel, math.floor(run.fuel * 10) / 10)
	plane:SetAttribute(FlightUtil.Attributes.Distance, math.floor(run.distance))
	plane:SetAttribute(FlightUtil.Attributes.Speed, math.floor(run.lastSpeed))
end

-- Starting a run ------------------------------------------------------------
function FlightRunService.StartRun(pilot: Player?, gunner: Player?)
	if PlaneService.hasActiveSession() then
		warn(`[FlightRunService] cannot start: a session is already active`)
		return
	end
	if not pilot and not gunner then
		warn(`[FlightRunService] cannot start: no players provided`)
		return
	end

	-- Rebuild the course so barriers / fuel reset
	local courseFolder = nil
	if GameConfig.GenerateTestCourse then
		courseFolder = CourseBuilder.build()
	end

	-- Spawn the plane
	local spawnCFrame = TestCourse.Origin * TestCourse.PlaneSpawnOffset
	-- Prefer the FlightTesting PlaneSpawn part if present (so later moving the part works)
	local flightTesting = workspace:FindFirstChild("FlightTesting")
	if flightTesting then
		local spawnPart = flightTesting:FindFirstChild("PlaneSpawn")
		if spawnPart and spawnPart:IsA("BasePart") then
			spawnCFrame = spawnPart.CFrame
		end
	end
	-- Align the plane with course forward
	spawnCFrame = CFrame.lookAt(spawnCFrame.Position, spawnCFrame.Position + TestCourse.Origin.LookVector)
	local session = PlaneService.SpawnPlane(pilot, gunner, "BasicPlane", spawnCFrame)
	if not session then
		warn(`[FlightRunService] PlaneService failed to spawn plane`)
		return
	end

	local run: RunState = {
		session = session,
		hearts = session.config.MaxHearts,
		fuel = session.config.FuelCapacity,
		distance = 0,
		elapsed = 0,
		startTime = os.clock(),
		finished = false,
		ending = false,
		hitCooldownUntil = 0,
		targetCooldown = {},
		fastSpeedSince = nil,
		lastAttrPush = 0,
		lastSpeed = 0,
		courseFolder = courseFolder,
	}
	FlightRunService._runs[session] = run

	-- Clean up when the session ends from any cause
	local conn
	conn = PlaneService.SessionEnding:Connect(function(endingSession)
		if endingSession ~= session then return end
		FlightRunService._runs[session] = nil
		if conn then conn:Disconnect() end
	end)

	pushAttributes(run, true)
end

-- Damage a target part. Used by PlaneWeaponService (projectile hits).
-- Returns true if the target was actually damaged this call.
function FlightRunService.DamageTarget(session: any, part: BasePart, damage: number): boolean
	if not part or not part.Parent then return false end
	if not CollectionService:HasTag(part, FlightUtil.Tags.FlightTarget) then
		return false
	end
	local run = FlightRunService._runs[session]
	if not run or run.ending then return false end

	local kind = part:GetAttribute(FlightUtil.Attributes.TargetKind)
	if kind == "Fuel" then
		-- Any hit collects it (one-shot).
		local amount = part:GetAttribute(FlightUtil.Attributes.TargetFuel) or 20
		run.fuel = math.min(session.config.FuelCapacity, run.fuel + amount)
		pushAttributes(run, true)
		sendFeedback(run, "FuelCollected", part.Position, amount)
		part:SetAttribute(FlightUtil.Attributes.TargetHealth, 0)
		CollectionService:RemoveTag(part, FlightUtil.Tags.FlightTarget)
		part:Destroy()
		return true
	elseif kind == "Barrier" then
		local hp = (part:GetAttribute(FlightUtil.Attributes.TargetHealth) or 1) - damage
		if hp <= 0 then
			sendFeedback(run, "BarrierDestroyed", part.Position)
			part:SetAttribute(FlightUtil.Attributes.TargetHealth, 0)
			CollectionService:RemoveTag(part, FlightUtil.Tags.FlightTarget)
			part:Destroy()
		else
			part:SetAttribute(FlightUtil.Attributes.TargetHealth, hp)
			sendFeedback(run, "BarrierHit", part.Position)
		end
		return true
	end
	return false
end

-- Collision scan ------------------------------------------------------------
local collisionOverlapParams = OverlapParams.new()
collisionOverlapParams.FilterType = Enum.RaycastFilterType.Include
collisionOverlapParams.MaxParts = 32

local function scanCollisions(run: RunState)
	local session = run.session
	local plane = session.plane
	local root = plane.PrimaryPart
	if not root then return end

	-- Out-of-bounds check (lateral or below course start)
	if FlightUtil.isOutOfBounds(root.Position) then
		sendFeedback(run, "Damaged", root.Position)
		endRun(run, false, "Out of bounds")
		return
	end

	local course = run.courseFolder
	if not course or not course.Parent then
		course = workspace:FindFirstChild("FlightCourse") :: Folder?
		run.courseFolder = course
		if not course then return end
	end

	collisionOverlapParams.FilterDescendantsInstances = { course }
	local parts = workspace:GetPartsInPart(root, collisionOverlapParams)
	if #parts == 0 then return end

	local now = os.clock()
	for _, p in parts do
		if CollectionService:HasTag(p, FlightUtil.Tags.FlightFinish) then
			endRun(run, true, "Finished")
			return
		end
		if CollectionService:HasTag(p, FlightUtil.Tags.FlightLethal) then
			sendFeedback(run, "Damaged", p.Position)
			endRun(run, false, "Fatal impact")
			return
		end
		if CollectionService:HasTag(p, FlightUtil.Tags.FlightTarget) then
			local kind = p:GetAttribute(FlightUtil.Attributes.TargetKind)
			if kind == "Fuel" then
				-- Flying through fuel = collect it (feels good)
				FlightRunService.DamageTarget(session, p, 1)
			elseif kind == "Barrier" then
				-- Non-lethal: subject to invuln window + per-target dedupe
				local perTarget = run.targetCooldown[p]
				if perTarget and perTarget > now then
					continue
				end
				if now < run.hitCooldownUntil then
					continue
				end
				run.hitCooldownUntil = now + (session.config.DamageInvulnerability or DAMAGE_INVULN_FALLBACK)
				run.targetCooldown[p] = now + 1.0
				if GameConfig.EnableHealth then
					run.hearts = math.max(0, run.hearts - 1)
				end
				sendFeedback(run, "Damaged", p.Position)
				-- Break the barrier so you can continue through
				p:SetAttribute(FlightUtil.Attributes.TargetHealth, 0)
				CollectionService:RemoveTag(p, FlightUtil.Tags.FlightTarget)
				p:Destroy()
				if run.hearts <= 0 then
					endRun(run, false, "Out of hearts")
					return
				end
				pushAttributes(run, true)
			end
		end
	end
end

-- Fuel + distance + speed update -------------------------------------------
local function fuelDrainRate(cfg: any, speed: number): number
	local cruise = cfg.CruiseSpeed
	local boost = cfg.BoostSpeed
	local brake = cfg.BrakeSpeed
	if speed >= (cruise + boost) * 0.5 then
		return cfg.BoostFuelDrain
	elseif speed <= (cruise + brake) * 0.5 then
		return cfg.BrakeFuelDrain
	end
	return cfg.FuelDrain
end

function FlightRunService._Update(dt: number)
	for session, run in FlightRunService._runs do
		if run.ending then continue end
		run.elapsed = os.clock() - run.startTime
		local plane = session.plane
		local root = plane.PrimaryPart
		if not root then
			endRun(run, false, "Plane destroyed")
			continue
		end
		local forward = FlightUtil.getCourseOrigin().LookVector
		local vel = root.AssemblyLinearVelocity
		local forwardSpeed = vel:Dot(forward)
		run.lastSpeed = forwardSpeed
		run.distance = FlightUtil.forwardDistance(root.Position)

		-- Plausibility: sustained excessive speed
		local cfg = session.config
		if forwardSpeed > cfg.BoostSpeed * 1.25 then
			run.fastSpeedSince = run.fastSpeedSince or os.clock()
			if os.clock() - (run.fastSpeedSince or 0) > 1.0 then
				endRun(run, false, "Invalid flight")
				continue
			end
		else
			run.fastSpeedSince = nil
		end

		-- Fuel drain (based on measured forward speed)
		if GameConfig.EnableFuel then
			local rate = fuelDrainRate(cfg, forwardSpeed)
			run.fuel = math.max(0, run.fuel - rate * dt)
			if run.fuel <= 0 then
				sendFeedback(run, "Damaged", root.Position)
				endRun(run, false, "Out of fuel")
				continue
			end
			-- Low fuel feedback
			if run.fuel < cfg.FuelCapacity * 0.25 then
				-- Throttle: push a feedback once per 2 seconds
				local lastLow = (run :: any).lastLowFuel or 0
				if os.clock() - lastLow > 2 then
					(run :: any).lastLowFuel = os.clock()
					sendFeedback(run, "LowFuel")
				end
			end
		end

		-- Collision scan
		scanCollisions(run)
		if run.ending then continue end

		pushAttributes(run, false)
	end
end

function FlightRunService.getRun(session: any): RunState?
	return FlightRunService._runs[session]
end

function FlightRunService._Init()
	PlaneService.SessionEnding:Connect(function(session)
		local run = FlightRunService._runs[session]
		if run then
			FlightRunService._runs[session] = nil
			if run.courseFolder then
				-- Keep the course around briefly so bullets etc can resolve.
				task.delay(0.2, function()
					-- Only destroy if a new run hasn't started that references it.
					if run.courseFolder and run.courseFolder.Parent then
						CourseBuilder.destroy()
					end
				end)
			end
		end
	end)
end

return FlightRunService
