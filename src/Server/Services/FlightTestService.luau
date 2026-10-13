--!strict
-- FlightTestService
-- Creates / maintains the FlightTesting pads, queues players into Pilot / Gunner
-- roles, respects GameConfig.MinimumPlayers to decide when to launch, and asks
-- FlightRunService to start a run. Also handles LeaveQueue and Retry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.Shared.Network)
local GameConfig = require(ReplicatedStorage.Shared.Constants.GameConfig)
local TestCourse = require(ReplicatedStorage.Shared.Constants.Courses.TestCourse)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)

local PlaneService = require(script.Parent.PlaneService)
local FlightRunService = require(script.Parent.FlightRunService)

local FlightTestService = {}

local Pads = {
	Folder = nil :: Folder?,
	PilotPad = nil :: Part?,
	GunnerPad = nil :: Part?,
	PlaneSpawn = nil :: Part?,
}

local Queue = {
	Pilot = nil :: Player?,
	Gunner = nil :: Player?,
}

-- Players whose previous role we remember, used for Retry.
local LastRole: { [Player]: "Pilot" | "Gunner" } = {}

local startingLock = false
local countdownToken = 0

local function broadcastStatus(countdown: number?)
	for _, player in Players:GetPlayers() do
		Network.Flight.QueueStatus:Server():Fire(player, {
			pilot = Queue.Pilot and Queue.Pilot.Name or nil,
			gunner = Queue.Gunner and Queue.Gunner.Name or nil,
			countdown = countdown,
			running = PlaneService.hasActiveSession(),
			minimumPlayers = GameConfig.MinimumPlayers,
		})
	end
end

-- Pad creation --------------------------------------------------------------
local function makeLabel(parent: BasePart, text: string, color: Color3)
	local bg = Instance.new("BillboardGui")
	bg.Name = "Label"
	bg.AlwaysOnTop = true
	bg.Size = UDim2.fromScale(10, 2.5)
	bg.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	bg.Parent = parent
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeColor3 = color
	tl.TextStrokeTransparency = 0
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.Parent = bg
end

local function makePad(name: string, cf: CFrame, color: Color3, promptText: string, roleFor: "Pilot" | "Gunner"): Part
	local pad = Instance.new("Part")
	pad.Name = name
	pad.Size = Vector3.new(10, 1, 10)
	pad.CFrame = cf
	pad.Anchored = true
	pad.CanCollide = true
	pad.Material = Enum.Material.Neon
	pad.Color = color
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = Pads.Folder
	makeLabel(pad, promptText, color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = `{roleFor}Prompt`
	prompt.ActionText = promptText
	prompt.ObjectText = "Crazy Flight"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	prompt.Triggered:Connect(function(player)
		FlightTestService._onPromptTriggered(player, roleFor)
	end)
	return pad
end

local function ensurePads()
	if Pads.Folder and Pads.Folder.Parent then
		return
	end
	local existing = workspace:FindFirstChild("FlightTesting")
	if existing and existing:IsA("Folder") then
		Pads.Folder = existing
	else
		if existing then existing:Destroy() end
		local folder = Instance.new("Folder")
		folder.Name = "FlightTesting"
		folder.Parent = workspace
		Pads.Folder = folder
	end

	local base = TestCourse.TestingArea
	Pads.PilotPad = makePad("PilotPad", base * CFrame.new(-8, 0, 0), Color3.fromRGB(80, 150, 230), "Join as Pilot", "Pilot")
	Pads.GunnerPad = makePad("GunnerPad", base * CFrame.new(8, 0, 0), Color3.fromRGB(230, 150, 80), "Join as Gunner", "Gunner")

	local spawnPart = Instance.new("Part")
	spawnPart.Name = "PlaneSpawn"
	spawnPart.Size = Vector3.new(16, 0.25, 20)
	spawnPart.CFrame = TestCourse.Origin * TestCourse.PlaneSpawnOffset
	spawnPart.Anchored = true
	spawnPart.CanCollide = false
	spawnPart.Transparency = 0.8
	spawnPart.Material = Enum.Material.ForceField
	spawnPart.Color = Color3.fromRGB(255, 255, 255)
	spawnPart.Parent = Pads.Folder
	Pads.PlaneSpawn = spawnPart
end

-- Queue / start logic -------------------------------------------------------
local function totalQueued(): number
	local n = 0
	if Queue.Pilot then n += 1 end
	if Queue.Gunner then n += 1 end
	return n
end

local function tryStart()
	if startingLock then return end
	if PlaneService.hasActiveSession() then return end

	local minPlayers = math.clamp(GameConfig.MinimumPlayers, 1, 2)
	local n = totalQueued()
	if minPlayers >= 2 then
		if not (Queue.Pilot and Queue.Gunner) then return end
	else
		if n < 1 then return end
	end

	startingLock = true
	local myToken = countdownToken + 1
	countdownToken = myToken

	task.spawn(function()
		local total = math.max(0, math.floor(GameConfig.StartCountdown or 0))
		for remaining = total, 1, -1 do
			if countdownToken ~= myToken then
				startingLock = false
				return
			end
			-- Re-validate during countdown
			if minPlayers >= 2 and not (Queue.Pilot and Queue.Gunner) then
				startingLock = false
				countdownToken += 1
				broadcastStatus(nil)
				return
			end
			if minPlayers < 2 and totalQueued() < 1 then
				startingLock = false
				countdownToken += 1
				broadcastStatus(nil)
				return
			end
			broadcastStatus(remaining)
			task.wait(1)
		end
		if countdownToken ~= myToken then
			startingLock = false
			return
		end
		-- Snapshot
		local pilot = Queue.Pilot
		local gunner = Queue.Gunner
		if pilot then LastRole[pilot] = "Pilot" end
		if gunner then LastRole[gunner] = "Gunner" end
		Queue.Pilot = nil
		Queue.Gunner = nil
		broadcastStatus(nil)

		local ok, err = pcall(function()
			FlightRunService.StartRun(pilot, gunner)
		end)
		if not ok then
			warn(`[FlightTestService] StartRun errored: {err}`)
		end
		startingLock = false
	end)
end

function FlightTestService._leaveQueue(player: Player)
	local changed = false
	if Queue.Pilot == player then
		Queue.Pilot = nil
		changed = true
	end
	if Queue.Gunner == player then
		Queue.Gunner = nil
		changed = true
	end
	if changed then
		countdownToken += 1 -- cancel any pending countdown
		broadcastStatus(nil)
	end
end

function FlightTestService._onPromptTriggered(player: Player, role: "Pilot" | "Gunner")
	if PlaneService.hasActiveSession() then
		-- Busy; just resend status so the UI shows "in progress".
		broadcastStatus(nil)
		return
	end
	-- If the player is already queued for THIS role, treat it as leave.
	if Queue[role] == player then
		FlightTestService._leaveQueue(player)
		return
	end
	-- Clear any prior role for this player
	if Queue.Pilot == player then Queue.Pilot = nil end
	if Queue.Gunner == player then Queue.Gunner = nil end
	-- Deny if role is taken by someone else
	if Queue[role] and Queue[role] ~= player then
		-- taken; ignore
		broadcastStatus(nil)
		return
	end
	Queue[role] = player
	LastRole[player] = role
	broadcastStatus(nil)
	tryStart()
end

-- Entry points -------------------------------------------------------------
function FlightTestService._Init()
	ensurePads()
	Network.Flight.LeaveQueue:Server():On(function(player: Player)
		FlightTestService._leaveQueue(player)
	end)
	Network.Flight.Retry:Server():On(function(player: Player)
		if PlaneService.hasActiveSession() then return end
		local role = LastRole[player] or "Pilot"
		FlightTestService._onPromptTriggered(player, role)
	end)

	PlaneService.SessionEnding:Connect(function()
		-- After a session ends, re-broadcast status so UIs know it's open again.
		task.defer(function()
			broadcastStatus(nil)
			-- Also try to restart immediately if players are still queued (unusual).
			tryStart()
		end)
	end)
end

function FlightTestService._PlayerAdded(player: Player)
	-- Send current queue status so the HUD knows what's going on when they join
	task.delay(1, function()
		if player.Parent then
			broadcastStatus(nil)
		end
	end)
end

function FlightTestService._PlayerRemoving(player: Player)
	FlightTestService._leaveQueue(player)
	LastRole[player] = nil
end

-- Public helper for other services
function FlightTestService.getPlaneSpawnCFrame(): CFrame
	ensurePads()
	local part = Pads.PlaneSpawn
	if part then
		return part.CFrame
	end
	return TestCourse.Origin * TestCourse.PlaneSpawnOffset
end

function FlightTestService.getTestingArea(): CFrame
	return TestCourse.TestingArea
end

return FlightTestService
