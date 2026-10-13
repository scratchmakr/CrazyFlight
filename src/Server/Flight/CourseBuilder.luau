--!strict
-- Builds / tears down the generated obstacle course in Workspace.FlightCourse.
-- Course is rebuilt per run so barriers / fuel pickups are reset cleanly.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestCourse = require(ReplicatedStorage.Shared.Constants.Courses.TestCourse)
local FlightUtil = require(ReplicatedStorage.Shared.Utilities.FlightUtil)

local CourseBuilder = {}

local COURSE_FOLDER_NAME = "FlightCourse"

local COLORS = {
	Barrier = Color3.fromRGB(220, 60, 60),
	Fuel = Color3.fromRGB(240, 220, 60),
	Lethal = Color3.fromRGB(60, 60, 60),
	Wall = Color3.fromRGB(50, 50, 55),
	Finish = Color3.fromRGB(70, 220, 90),
}

local function makeObstaclePart(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false -- Server collision is detected via GetPartsInPart on the plane root
	p.CanQuery = true
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildBarrier(parent: Instance, cf: CFrame, size: Vector3, health: number): Part
	local p = makeObstaclePart(parent, "Barrier", cf, size, COLORS.Barrier)
	p.Material = Enum.Material.Neon
	p:SetAttribute(FlightUtil.Attributes.TargetKind, "Barrier")
	p:SetAttribute(FlightUtil.Attributes.TargetHealth, health)
	CollectionService:AddTag(p, FlightUtil.Tags.FlightTarget)
	return p
end

local function buildFuel(parent: Instance, cf: CFrame, size: Vector3, fuel: number): Part
	local p = makeObstaclePart(parent, "Fuel", cf, size, COLORS.Fuel)
	p.Material = Enum.Material.Neon
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size.X, size.X, size.X)
	p:SetAttribute(FlightUtil.Attributes.TargetKind, "Fuel")
	p:SetAttribute(FlightUtil.Attributes.TargetFuel, fuel)
	p:SetAttribute(FlightUtil.Attributes.TargetHealth, 1)
	CollectionService:AddTag(p, FlightUtil.Tags.FlightTarget)
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 2
	light.Color = p.Color
	light.Parent = p
	return p
end

local function buildLethal(parent: Instance, cf: CFrame, size: Vector3, kindName: string): Part
	local color = kindName == "Wall" and COLORS.Wall or COLORS.Lethal
	local p = makeObstaclePart(parent, kindName, cf, size, color)
	CollectionService:AddTag(p, FlightUtil.Tags.FlightLethal)
	return p
end

local function buildFinish(parent: Instance, cf: CFrame, size: Vector3): Part
	local p = makeObstaclePart(parent, "Finish", cf, size, COLORS.Finish)
	p.Material = Enum.Material.Neon
	p.Transparency = 0.4
	CollectionService:AddTag(p, FlightUtil.Tags.FlightFinish)
	return p
end

function CourseBuilder.destroy()
	local existing = workspace:FindFirstChild(COURSE_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

function CourseBuilder.build(): Folder
	CourseBuilder.destroy()

	local folder = Instance.new("Folder")
	folder.Name = COURSE_FOLDER_NAME
	CollectionService:AddTag(folder, FlightUtil.Tags.FlightCourse)

	-- Course origin visual marker (small start pad)
	local startPad = makeObstaclePart(folder, "StartMarker",
		TestCourse.Origin * CFrame.new(0, -10, 0),
		Vector3.new(80, 0.5, 10),
		Color3.fromRGB(90, 160, 220))
	startPad.Material = Enum.Material.Neon
	startPad.Transparency = 0.3

	for _, obstacle in TestCourse.Obstacles do
		local cf = FlightUtil.courseCFrame(obstacle.distance, obstacle.offset.X, obstacle.offset.Y)
		local size = obstacle.size
		if obstacle.kind == "Barrier" then
			buildBarrier(folder, cf, size, obstacle.health or 1)
		elseif obstacle.kind == "Fuel" then
			buildFuel(folder, cf, size, obstacle.fuel or 20)
		elseif obstacle.kind == "Lethal" or obstacle.kind == "Wall" then
			buildLethal(folder, cf, size, obstacle.kind)
		elseif obstacle.kind == "Finish" then
			buildFinish(folder, cf, size)
		else
			warn(`[CourseBuilder] unknown obstacle kind: {tostring(obstacle.kind)}`)
		end
	end

	folder.Parent = workspace
	return folder
end

function CourseBuilder.get(): Folder?
	return workspace:FindFirstChild(COURSE_FOLDER_NAME) :: Folder?
end

return CourseBuilder
