--!strict
-- Fixed, repeatable test course.
--
-- All obstacles are placed relative to the course origin:
--   +X = right, +Y = up, +Z = forward (direction of travel)
--
-- Autopilot path waypoints give (distance, offsetX, offsetY) describing the
-- lateral/vertical offset of the plane at that forward distance.

local TestCourse = {}

TestCourse.Origin = CFrame.new(0, 220, 0) -- Course start, high in the sky
TestCourse.Length = 3500 -- Must stay in sync with GameConfig.CourseLength

-- Half-size of the "safe" play volume (studs). Beyond this = instant death.
TestCourse.Bounds = Vector3.new(120, 90, 100)

-- Where PlaneSpawn goes, offset back from the course origin.
TestCourse.PlaneSpawnOffset = CFrame.new(0, 0, -40)

-- Where the FlightTesting pads go (world CFrame).
TestCourse.TestingArea = CFrame.new(0, 10, -120)

-- Autopilot waypoints (used when the gunner is solo).
-- Linearly interpolated by forward distance.
TestCourse.AutopilotPath = {
	{ distance = 0,    offsetX = 0,   offsetY = 0 },
	{ distance = 400,  offsetX = 18,  offsetY = 6 },
	{ distance = 800,  offsetX = -18, offsetY = -4 },
	{ distance = 1200, offsetX = 24,  offsetY = 10 },
	{ distance = 1600, offsetX = -22, offsetY = 2 },
	{ distance = 2000, offsetX = 0,   offsetY = 14 },
	{ distance = 2400, offsetX = 20,  offsetY = -2 },
	{ distance = 2800, offsetX = -16, offsetY = 8 },
	{ distance = 3200, offsetX = 0,   offsetY = 0 },
	{ distance = 3500, offsetX = 0,   offsetY = 0 },
}

-- Obstacle kinds:
--   "Barrier"       red destructible wall
--   "Fuel"          yellow shootable pickup
--   "Lethal"        dark-gray instant-death obstacle
--   "Wall"          dark-gray lethal corridor wall
--   "Finish"        green finish line
TestCourse.Obstacles = {
	-- Starting area reference
	{ kind = "Lethal", distance = 50,   offset = Vector3.new(-110, 0, 0), size = Vector3.new(5, 160, 80) },
	{ kind = "Lethal", distance = 50,   offset = Vector3.new(110, 0, 0),  size = Vector3.new(5, 160, 80) },

	-- Open flight section with scattered barriers
	{ kind = "Barrier", distance = 220,  offset = Vector3.new(-20, 0, 0),  size = Vector3.new(18, 18, 4), health = 1 },
	{ kind = "Barrier", distance = 320,  offset = Vector3.new(25, 5, 0),   size = Vector3.new(18, 18, 4), health = 1 },
	{ kind = "Fuel",    distance = 400,  offset = Vector3.new(0, 10, 0),   size = Vector3.new(6, 6, 6),   fuel = 25 },

	-- Barrier wall with gap on the right
	{ kind = "Barrier", distance = 550,  offset = Vector3.new(-30, 0, 0),  size = Vector3.new(40, 40, 4), health = 1 },
	{ kind = "Barrier", distance = 550,  offset = Vector3.new(30, 25, 0),  size = Vector3.new(40, 10, 4), health = 1 },

	-- Steering obstacle (static lethal pillar left+right alternating)
	{ kind = "Lethal",  distance = 750,  offset = Vector3.new(-40, 0, 0),  size = Vector3.new(20, 60, 10) },
	{ kind = "Lethal",  distance = 900,  offset = Vector3.new(40, 0, 0),   size = Vector3.new(20, 60, 10) },

	-- Fuel reward after harder stretch
	{ kind = "Fuel",    distance = 1050, offset = Vector3.new(0, 15, 0),   size = Vector3.new(6, 6, 6),   fuel = 30 },
	{ kind = "Fuel",    distance = 1050, offset = Vector3.new(-15, 0, 0),  size = Vector3.new(6, 6, 6),   fuel = 15 },

	-- Barrier cluster
	{ kind = "Barrier", distance = 1200, offset = Vector3.new(0, 0, 0),    size = Vector3.new(20, 20, 4), health = 2 },
	{ kind = "Barrier", distance = 1250, offset = Vector3.new(-25, 10, 0), size = Vector3.new(16, 16, 4), health = 1 },
	{ kind = "Barrier", distance = 1250, offset = Vector3.new(25, -5, 0),  size = Vector3.new(16, 16, 4), health = 1 },

	-- Narrow passage: lethal walls with a vertical gap
	{ kind = "Wall",    distance = 1500, offset = Vector3.new(-25, 0, 0),  size = Vector3.new(5, 80, 60) },
	{ kind = "Wall",    distance = 1500, offset = Vector3.new(25, 0, 0),   size = Vector3.new(5, 80, 60) },
	{ kind = "Wall",    distance = 1550, offset = Vector3.new(0, 40, 0),   size = Vector3.new(45, 5, 60) },
	{ kind = "Wall",    distance = 1550, offset = Vector3.new(0, -40, 0),  size = Vector3.new(45, 5, 60) },

	-- Fuel reward
	{ kind = "Fuel",    distance = 1700, offset = Vector3.new(0, 0, 0),    size = Vector3.new(6, 6, 6),   fuel = 30 },

	-- Dense barrier wave
	{ kind = "Barrier", distance = 1900, offset = Vector3.new(-30, -10, 0), size = Vector3.new(14, 14, 4), health = 1 },
	{ kind = "Barrier", distance = 1900, offset = Vector3.new(0, 15, 0),    size = Vector3.new(14, 14, 4), health = 1 },
	{ kind = "Barrier", distance = 1900, offset = Vector3.new(30, -10, 0),  size = Vector3.new(14, 14, 4), health = 1 },

	-- High fuel pickup requiring aim
	{ kind = "Fuel",    distance = 2100, offset = Vector3.new(0, 25, 0),   size = Vector3.new(6, 6, 6),   fuel = 25 },

	-- Lethal spire
	{ kind = "Lethal",  distance = 2250, offset = Vector3.new(0, -20, 0),  size = Vector3.new(60, 20, 15) },

	-- Barrier gauntlet
	{ kind = "Barrier", distance = 2400, offset = Vector3.new(-18, 0, 0),  size = Vector3.new(18, 18, 4), health = 2 },
	{ kind = "Barrier", distance = 2400, offset = Vector3.new(18, 0, 0),   size = Vector3.new(18, 18, 4), health = 2 },
	{ kind = "Fuel",    distance = 2550, offset = Vector3.new(20, 10, 0),  size = Vector3.new(6, 6, 6),   fuel = 20 },
	{ kind = "Fuel",    distance = 2550, offset = Vector3.new(-20, 10, 0), size = Vector3.new(6, 6, 6),   fuel = 20 },

	-- Final narrow passage
	{ kind = "Wall",    distance = 2850, offset = Vector3.new(-20, 0, 0),  size = Vector3.new(5, 100, 60) },
	{ kind = "Wall",    distance = 2850, offset = Vector3.new(20, 0, 0),   size = Vector3.new(5, 100, 60) },

	-- Last fuel top-up
	{ kind = "Fuel",    distance = 3100, offset = Vector3.new(0, 0, 0),    size = Vector3.new(6, 6, 6),   fuel = 40 },

	-- Finish line (green, spans the lane)
	{ kind = "Finish",  distance = 3450, offset = Vector3.new(0, 0, 0),    size = Vector3.new(120, 120, 4) },
}

return TestCourse
