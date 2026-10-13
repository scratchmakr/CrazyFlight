--!strict
-- Central prototype configuration for Crazy Flight!
-- Change MinimumPlayers to switch between solo (1) and two-player (2) testing.

local GameConfig = {
	-- Testing / Multiplayer
	MinimumPlayers = 1,
	MaximumPlayers = 2,

	-- Flight
	AutoForward = true,

	-- Course
	GenerateTestCourse = true,
	CourseLength = 3500,

	-- Gameplay toggles
	EnableFuel = true,
	EnableHealth = true,
	EnableWeaponOverheat = true,

	-- Testing / UX
	DebugMode = true,
	SoloPilotDebugFire = true, -- Press F while flying solo-pilot to fire
	StartCountdown = 3, -- Seconds after the join requirement is met before launch
}

return GameConfig
