--!strict
-- FlightUIController
-- Minimal functional HUD for Crazy Flight!, built with plain Instance UI so it
-- works in a fresh Studio place with no datastore configuration required.
--
-- Shows:
--   * queue status (while waiting on pads)
--   * hearts, fuel bar, timer, speed (pilot), heat bar + crosshair (gunner)
--   * boost/brake indicators (pilot), overheat flash (gunner)
--   * damage flash, low-fuel flash, hit toasts, run end panel w/ Retry

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Network = require(ReplicatedStorage.Shared.Network)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)
local GameConfig = require(ReplicatedStorage.Shared.Constants.GameConfig)

local LocalPlayer = Players.LocalPlayer

local FlightUIController = {}

local HUD = {
	screenGui = nil :: ScreenGui?,
	queuePanel = nil :: Frame?,
	queueText = nil :: TextLabel?,
	queueLeaveButton = nil :: TextButton?,
	hudPanel = nil :: Frame?,
	heartsFrame = nil :: Frame?,
	heartImages = {} :: { TextLabel },
	fuelBar = nil :: Frame?,
	fuelFill = nil :: Frame?,
	fuelText = nil :: TextLabel?,
	timerText = nil :: TextLabel?,
	speedText = nil :: TextLabel?,
	heatBar = nil :: Frame?,
	heatFill = nil :: Frame?,
	heatText = nil :: TextLabel?,
	overheatLabel = nil :: TextLabel?,
	boostBrakeLabel = nil :: TextLabel?,
	crosshair = nil :: Frame?,
	resultPanel = nil :: Frame?,
	resultTitle = nil :: TextLabel?,
	resultReason = nil :: TextLabel?,
	resultTime = nil :: TextLabel?,
	resultRetry = nil :: TextButton?,
	resultLeave = nil :: TextButton?,
	toastContainer = nil :: Frame?,
	flashFrame = nil :: Frame?,
}

local mount = nil :: { plane: Model, role: string, controlMode: string }?
local mountTrove = nil :: any
local currentConfig = nil

-- UI construction -----------------------------------------------------------
local function newUIStroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.Parent = parent
end

local function newUICorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeLabel(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeColor3 = Color3.new(0, 0, 0)
	t.TextStrokeTransparency = 0.3
	t.TextScaled = true
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function makeButton(parent: Instance, text: string, props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Text = text
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	b.Parent = parent
	newUICorner(b, 8)
	return b
end

local function buildHUD()
	if HUD.screenGui then return end
	local sg = Instance.new("ScreenGui")
	sg.Name = "CrazyFlightHUD"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 10
	sg.Enabled = true
	sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
	HUD.screenGui = sg

	-- Full-screen damage flash
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 1
	flash.Parent = sg
	HUD.flashFrame = flash

	-- Queue panel ----------------------------------------------------------
	local qp = Instance.new("Frame")
	qp.Name = "QueuePanel"
	qp.AnchorPoint = Vector2.new(0.5, 0)
	qp.Position = UDim2.new(0.5, 0, 0, 24)
	qp.Size = UDim2.new(0, 360, 0, 80)
	qp.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	qp.BackgroundTransparency = 0.2
	qp.BorderSizePixel = 0
	qp.Visible = false
	qp.Parent = sg
	newUICorner(qp, 8)
	newUIStroke(qp, Color3.fromRGB(80, 150, 230))
	HUD.queuePanel = qp

	local qt = makeLabel(qp, {
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.new(0, 10, 0, 4),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	HUD.queueText = qt

	local leaveButton = makeButton(qp, "Leave Queue", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(0, 140, 0, 24),
		BackgroundColor3 = Color3.fromRGB(200, 70, 70),
	})
	leaveButton.Activated:Connect(function()
		Network.Flight.LeaveQueue:Client():Fire()
	end)
	HUD.queueLeaveButton = leaveButton

	-- Main HUD panel -------------------------------------------------------
	local hud = Instance.new("Frame")
	hud.Name = "HUD"
	hud.Size = UDim2.fromScale(1, 1)
	hud.BackgroundTransparency = 1
	hud.Visible = false
	hud.Parent = sg
	HUD.hudPanel = hud

	-- Top-left: Hearts
	local hearts = Instance.new("Frame")
	hearts.Name = "Hearts"
	hearts.AnchorPoint = Vector2.new(0, 0)
	hearts.Position = UDim2.new(0, 24, 0, 24)
	hearts.Size = UDim2.new(0, 180, 0, 40)
	hearts.BackgroundTransparency = 1
	hearts.Parent = hud
	HUD.heartsFrame = hearts
	local hlayout = Instance.new("UIListLayout")
	hlayout.FillDirection = Enum.FillDirection.Horizontal
	hlayout.Padding = UDim.new(0, 8)
	hlayout.Parent = hearts
	for i = 1, 5 do -- Build up to 5 heart slots; show only as many as MaxHearts
		local h = makeLabel(hearts, {
			Size = UDim2.new(0, 40, 0, 40),
			Text = "<3",
			TextColor3 = Color3.fromRGB(255, 80, 90),
			Visible = false,
			LayoutOrder = i,
		})
		HUD.heartImages[i] = h
	end

	-- Top-center: Timer
	HUD.timerText = makeLabel(hud, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.new(0, 180, 0, 40),
		Text = "0.0s",
		Font = Enum.Font.Code,
	})

	-- Top-right: Queue status mini (shows minimum players required when idle)
	-- Not needed; queue panel handles it.

	-- Bottom-left: Fuel bar + fuel text
	local fuelBar = Instance.new("Frame")
	fuelBar.Name = "FuelBar"
	fuelBar.AnchorPoint = Vector2.new(0, 1)
	fuelBar.Position = UDim2.new(0, 24, 1, -24)
	fuelBar.Size = UDim2.new(0, 280, 0, 24)
	fuelBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	fuelBar.BorderSizePixel = 0
	fuelBar.Parent = hud
	newUICorner(fuelBar, 4)
	newUIStroke(fuelBar, Color3.fromRGB(255, 220, 80))
	HUD.fuelBar = fuelBar
	local fuelFill = Instance.new("Frame")
	fuelFill.Name = "Fill"
	fuelFill.Size = UDim2.fromScale(1, 1)
	fuelFill.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
	fuelFill.BorderSizePixel = 0
	fuelFill.Parent = fuelBar
	newUICorner(fuelFill, 4)
	HUD.fuelFill = fuelFill
	HUD.fuelText = makeLabel(fuelBar, {
		Size = UDim2.fromScale(1, 1),
		Text = "FUEL 100",
		TextColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		ZIndex = 2,
	})

	-- Pilot: Speed + boost/brake (above fuel bar)
	HUD.speedText = makeLabel(hud, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -56),
		Size = UDim2.new(0, 160, 0, 24),
		Text = "SPD 0",
		Font = Enum.Font.Code,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	HUD.boostBrakeLabel = makeLabel(hud, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 190, 1, -56),
		Size = UDim2.new(0, 140, 0, 24),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Gunner: Heat bar + overheat label (bottom-right)
	local heatBar = Instance.new("Frame")
	heatBar.Name = "HeatBar"
	heatBar.AnchorPoint = Vector2.new(1, 1)
	heatBar.Position = UDim2.new(1, -24, 1, -24)
	heatBar.Size = UDim2.new(0, 280, 0, 24)
	heatBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	heatBar.BorderSizePixel = 0
	heatBar.Parent = hud
	newUICorner(heatBar, 4)
	newUIStroke(heatBar, Color3.fromRGB(255, 120, 60))
	HUD.heatBar = heatBar
	local heatFill = Instance.new("Frame")
	heatFill.Name = "Fill"
	heatFill.Size = UDim2.fromScale(0, 1)
	heatFill.AnchorPoint = Vector2.new(0, 0)
	heatFill.BackgroundColor3 = Color3.fromRGB(255, 120, 60)
	heatFill.BorderSizePixel = 0
	heatFill.Parent = heatBar
	newUICorner(heatFill, 4)
	HUD.heatFill = heatFill
	HUD.heatText = makeLabel(heatBar, {
		Size = UDim2.fromScale(1, 1),
		Text = "HEAT 0",
		TextColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		ZIndex = 2,
	})
	HUD.overheatLabel = makeLabel(hud, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -56),
		Size = UDim2.new(0, 160, 0, 24),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 90, 70),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- Crosshair (center-screen, gunner)
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.new(0, 36, 0, 36)
	crosshair.BackgroundTransparency = 1
	crosshair.Visible = false
	crosshair.Parent = hud
	HUD.crosshair = crosshair
	local function addCrossBar(w, h)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, w, 0, h)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
		f.BorderSizePixel = 0
		f.Parent = crosshair
	end
	addCrossBar(2, 24)
	addCrossBar(24, 2)
	-- Center dot
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 3, 0, 3)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BorderSizePixel = 0
	dot.Parent = crosshair

	-- Toast container (hit/fuel feedback) at top-right
	local toast = Instance.new("Frame")
	toast.Name = "Toasts"
	toast.AnchorPoint = Vector2.new(1, 0)
	toast.Position = UDim2.new(1, -24, 0, 80)
	toast.Size = UDim2.new(0, 240, 0, 400)
	toast.BackgroundTransparency = 1
	toast.Parent = hud
	HUD.toastContainer = toast
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Vertical
	tl.Padding = UDim.new(0, 4)
	tl.VerticalAlignment = Enum.VerticalAlignment.Top
	tl.Parent = toast

	-- Result panel (end of run) -------------------------------------------
	local rp = Instance.new("Frame")
	rp.Name = "ResultPanel"
	rp.AnchorPoint = Vector2.new(0.5, 0.5)
	rp.Position = UDim2.fromScale(0.5, 0.5)
	rp.Size = UDim2.new(0, 420, 0, 220)
	rp.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	rp.BackgroundTransparency = 0.1
	rp.BorderSizePixel = 0
	rp.Visible = false
	rp.Parent = sg
	newUICorner(rp, 10)
	newUIStroke(rp, Color3.fromRGB(80, 200, 120))
	HUD.resultPanel = rp
	HUD.resultTitle = makeLabel(rp, {
		Size = UDim2.new(1, -20, 0, 48),
		Position = UDim2.new(0, 10, 0, 10),
		Text = "RUN COMPLETE",
		TextColor3 = Color3.fromRGB(80, 220, 120),
	})
	HUD.resultReason = makeLabel(rp, {
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, 60),
		Text = "",
	})
	HUD.resultTime = makeLabel(rp, {
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.new(0, 10, 0, 92),
		Text = "Time: 0.0s",
		Font = Enum.Font.Code,
	})
	HUD.resultRetry = makeButton(rp, "Retry", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.3, 0, 1, -14),
		Size = UDim2.new(0, 160, 0, 40),
		BackgroundColor3 = Color3.fromRGB(60, 160, 90),
	})
	HUD.resultRetry.Activated:Connect(function()
		if HUD.resultPanel then HUD.resultPanel.Visible = false end
		Network.Flight.Retry:Client():Fire()
	end)
	HUD.resultLeave = makeButton(rp, "Close", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.7, 0, 1, -14),
		Size = UDim2.new(0, 160, 0, 40),
		BackgroundColor3 = Color3.fromRGB(160, 90, 90),
	})
	HUD.resultLeave.Activated:Connect(function()
		if HUD.resultPanel then HUD.resultPanel.Visible = false end
	end)
end

-- Update helpers ------------------------------------------------------------
local function setHearts(current: number, maximum: number)
	for i, label in HUD.heartImages do
		label.Visible = i <= maximum
		if label.Visible then
			if i <= current then
				label.TextColor3 = Color3.fromRGB(255, 80, 90)
				label.Text = "<3"
			else
				label.TextColor3 = Color3.fromRGB(80, 80, 90)
				label.Text = "<3"
			end
		end
	end
end

local function setFuel(current: number, maximum: number)
	local ratio = maximum > 0 and math.clamp(current / maximum, 0, 1) or 0
	if HUD.fuelFill then
		HUD.fuelFill.Size = UDim2.new(ratio, 0, 1, 0)
		if ratio < 0.25 then
			HUD.fuelFill.BackgroundColor3 = Color3.fromRGB(255, 90, 70)
		else
			HUD.fuelFill.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
		end
	end
	if HUD.fuelText then
		HUD.fuelText.Text = string.format("FUEL %d / %d", math.floor(current), maximum)
	end
end

local function setHeat(current: number, maximum: number, overheated: boolean)
	local ratio = maximum > 0 and math.clamp(current / maximum, 0, 1) or 0
	if HUD.heatFill then
		HUD.heatFill.Size = UDim2.new(ratio, 0, 1, 0)
		if overheated then
			HUD.heatFill.BackgroundColor3 = Color3.fromRGB(255, 60, 40)
		else
			HUD.heatFill.BackgroundColor3 = Color3.fromRGB(255, 120, 60)
		end
	end
	if HUD.heatText then
		HUD.heatText.Text = string.format("HEAT %d / %d", math.floor(current), maximum)
	end
	if HUD.overheatLabel then
		HUD.overheatLabel.Text = overheated and "OVERHEATED!" or ""
	end
end

local function pushToast(text: string, color: Color3)
	if not HUD.toastContainer then return end
	local t = makeLabel(HUD.toastContainer, {
		Size = UDim2.new(1, 0, 0, 24),
		Text = text,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	t.LayoutOrder = os.clock() * 1000
	task.delay(1.5, function()
		if t.Parent then t:Destroy() end
	end)
end

local function flashDamage()
	if not HUD.flashFrame then return end
	HUD.flashFrame.BackgroundTransparency = 0.4
	TweenService:Create(HUD.flashFrame, TweenInfo.new(0.4), {
		BackgroundTransparency = 1,
	}):Play()
end

local function setRoleVisibility(role: string)
	if HUD.crosshair then HUD.crosshair.Visible = role == "Gunner" end
	if HUD.heatBar then HUD.heatBar.Visible = role == "Gunner" end
	if HUD.speedText then HUD.speedText.Visible = role == "Pilot" end
	if HUD.boostBrakeLabel then HUD.boostBrakeLabel.Visible = role == "Pilot" end
	if HUD.overheatLabel then HUD.overheatLabel.Visible = role == "Gunner" end
end

-- Mount handling ------------------------------------------------------------
local function clearMount()
	mount = nil
	currentConfig = nil
	if mountTrove then
		mountTrove:Destroy()
		mountTrove = nil
	end
	if HUD.hudPanel then HUD.hudPanel.Visible = false end
end

local function setMount(plane: Model, role: string, controlMode: string)
	clearMount()
	buildHUD()
	mount = { plane = plane, role = role, controlMode = controlMode }
	if HUD.hudPanel then HUD.hudPanel.Visible = true end
	if HUD.queuePanel then HUD.queuePanel.Visible = false end
	setRoleVisibility(role)
	local trove = Trove.new()
	mountTrove = trove
	trove:Add(plane.Destroying:Connect(clearMount))

	-- Initial values
	local maxHearts = plane:GetAttribute(FlightUtil.Attributes.Hearts) or 3
	local hearts = maxHearts
	local fuelMax = plane:GetAttribute(FlightUtil.Attributes.FuelMax) or 100
	setHearts(hearts, maxHearts)
	setFuel(fuelMax, fuelMax)
	setHeat(0, plane:GetAttribute(FlightUtil.Attributes.HeatMax) or 100, false)
end

-- Attribute polling (replicated attributes on the plane) --------------------
local function pollAttributes()
	local m = mount
	if not m then return end
	local plane = m.plane
	if not plane or not plane.Parent then return end
	local maxHearts = plane:GetAttribute(FlightUtil.Attributes.Hearts) and plane:GetAttribute(FlightUtil.Attributes.Hearts) or 3
	-- Clamp max heart indicator by what we know (plane default 3)
	-- Hearts attribute holds current, FuelMax holds fuel capacity, we infer MaxHearts.
	-- We'll show HUD.heartImages up to 5 slots and set visibility based on 3.
	setHearts(plane:GetAttribute(FlightUtil.Attributes.Hearts) or 0, 3)
	setFuel(plane:GetAttribute(FlightUtil.Attributes.Fuel) or 0, plane:GetAttribute(FlightUtil.Attributes.FuelMax) or 100)
	local heat = plane:GetAttribute(FlightUtil.Attributes.Heat) or 0
	local heatMax = plane:GetAttribute(FlightUtil.Attributes.HeatMax) or 100
	local overheated = plane:GetAttribute(FlightUtil.Attributes.Overheated) or false
	setHeat(heat, heatMax, overheated)

	-- Timer
	local startTime = plane:GetAttribute(FlightUtil.Attributes.StartTime) or 0
	if HUD.timerText then
		local elapsed = math.max(0, workspace:GetServerTimeNow() - startTime)
		HUD.timerText.Text = string.format("%0.1fs", elapsed)
	end
	-- Speed + Boost/Brake (pilot)
	if HUD.speedText then
		HUD.speedText.Text = string.format("SPD %d", plane:GetAttribute(FlightUtil.Attributes.Speed) or 0)
	end
	if HUD.boostBrakeLabel and m.role == "Pilot" then
		local PlaneController = require(script.Parent.PlaneController)
		local pi = PlaneController._pilotInput
		if pi.boost then
			HUD.boostBrakeLabel.Text = "BOOST"
			HUD.boostBrakeLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
		elseif pi.brake then
			HUD.boostBrakeLabel.Text = "BRAKE"
			HUD.boostBrakeLabel.TextColor3 = Color3.fromRGB(90, 180, 255)
		else
			HUD.boostBrakeLabel.Text = ""
		end
	end
end

-- Queue status display ------------------------------------------------------
local function showQueue(status)
	buildHUD()
	if HUD.queuePanel then
		HUD.queuePanel.Visible = true
	end
	local text
	if status.running then
		text = "Flight in progress..."
	elseif status.countdown then
		text = string.format("Launching in %d...", status.countdown)
	else
		local parts = {}
		if status.pilot then table.insert(parts, string.format("Pilot: %s", status.pilot)) end
		if status.gunner then table.insert(parts, string.format("Gunner: %s", status.gunner)) end
		if #parts == 0 then
			text = string.format("Queue empty (min %d player%s)", status.minimumPlayers,
				status.minimumPlayers == 1 and "" or "s")
		else
			text = table.concat(parts, "    ")
			if status.minimumPlayers >= 2 then
				if not status.pilot then text = text .. "   Waiting for Pilot" end
				if not status.gunner then text = text .. "   Waiting for Gunner" end
			end
		end
	end
	if HUD.queueText then HUD.queueText.Text = text end
	-- Hide queue when we are mounted
	if mount then HUD.queuePanel.Visible = false end
	-- Show "Leave" only if the local player is in the queue
	if HUD.queueLeaveButton then
		local localIsQueued = status.pilot == LocalPlayer.Name or status.gunner == LocalPlayer.Name
		HUD.queueLeaveButton.Visible = localIsQueued and not status.running
	end
end

local function hideQueuePanelIfEmpty()
	if not HUD.queuePanel then return end
end

-- Feedback events -----------------------------------------------------------
local function onFeedback(feedback)
	local kind = feedback.kind
	if kind == "Damaged" then
		flashDamage()
		pushToast("- HEART", Color3.fromRGB(255, 100, 100))
	elseif kind == "LowFuel" then
		pushToast("LOW FUEL!", Color3.fromRGB(255, 160, 70))
	elseif kind == "Overheated" then
		pushToast("OVERHEATED!", Color3.fromRGB(255, 90, 70))
	elseif kind == "FuelCollected" then
		pushToast(string.format("+%d FUEL", feedback.amount or 0), Color3.fromRGB(255, 220, 90))
	elseif kind == "BarrierDestroyed" then
		pushToast("TARGET DOWN", Color3.fromRGB(255, 180, 80))
	elseif kind == "BarrierHit" then
		pushToast("HIT", Color3.fromRGB(255, 200, 120))
	end
end

local function onRunEnded(result)
	buildHUD()
	if HUD.resultPanel then HUD.resultPanel.Visible = true end
	if HUD.resultTitle then
		HUD.resultTitle.Text = result.success and "RUN COMPLETE!" or "RUN FAILED"
		HUD.resultTitle.TextColor3 = result.success and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(240, 90, 90)
	end
	if HUD.resultReason then
		HUD.resultReason.Text = result.reason or ""
	end
	if HUD.resultTime then
		HUD.resultTime.Text = string.format("Time: %0.1fs    Distance: %d", result.time or 0, result.distance or 0)
	end
	if HUD.resultPanel then
		local stroke = HUD.resultPanel:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = result.success and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(240, 90, 90)
		end
	end
	if HUD.hudPanel then HUD.hudPanel.Visible = false end
end

function FlightUIController._Init()
	-- Build HUD upfront so queue status can show.
	task.defer(buildHUD)

	Network.Flight.Mounted:Client():On(function(plane, role, controlMode)
		task.defer(function()
			setMount(plane, role, controlMode)
		end)
	end)
	Network.Flight.Unmounted:Client():On(function()
		clearMount()
	end)
	Network.Flight.QueueStatus:Client():On(showQueue)
	Network.Flight.Feedback:Client():On(onFeedback)
	Network.Flight.RunEnded:Client():On(onRunEnded)
end

function FlightUIController._PreRenderUpdate(_dt)
	pollAttributes()
end

return FlightUIController
