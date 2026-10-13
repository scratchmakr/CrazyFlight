--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Red = require(ReplicatedStorage.Packages.Red)

return {
	-- Server -> Client ---------------------------------------------------

	-- Fired when a player is seated in a plane role.
	Mounted = Red.Event("Flight_Mounted", function(plane, role, controlMode)
		return plane :: Model, role :: string, controlMode :: string
	end),

	-- Fired when the player is removed from a plane (end of run, left, etc).
	Unmounted = Red.Event("Flight_Unmounted", function()
		return
	end),

	-- Queue state updates (pilotName, gunnerName, countdown-or-nil).
	QueueStatus = Red.Event("Flight_QueueStatus", function(status)
		return status :: {
			pilot: string?,
			gunner: string?,
			countdown: number?,
			running: boolean?,
			minimumPlayers: number,
		}
	end),

	-- Run ended (per-player).
	RunEnded = Red.Event("Flight_RunEnded", function(result)
		return result :: {
			success: boolean,
			reason: string,
			time: number,
			distance: number,
		}
	end),

	-- Projectile fired (broadcast to all).
	ProjectileFired = Red.Event("Flight_ProjectileFired", function(projectile)
		return projectile :: {
			id: number,
			shooterId: number,
			origin: Vector3,
			velocity: Vector3,
			gravity: number,
			lifetime: number,
		}
	end),

	-- Projectile impact (broadcast to all).
	ProjectileImpact = Red.Event("Flight_ProjectileImpact", function(impact)
		return impact :: {
			id: number,
			position: Vector3,
			kind: string, -- "Barrier" | "Fuel" | "Lethal" | "World" | "Expired"
		}
	end),

	-- Gameplay feedback (broadcast to session members).
	Feedback = Red.Event("Flight_Feedback", function(feedback)
		return feedback :: {
			kind: string, -- "BarrierHit" | "BarrierDestroyed" | "FuelCollected" | "Damaged" | "Overheated" | "LowFuel"
			position: Vector3?,
			amount: number?,
		}
	end),

	-- Client -> Server ---------------------------------------------------

	-- Request to leave the pad queue.
	LeaveQueue = Red.Event("Flight_LeaveQueue", function()
		return
	end),

	-- Request a retry after a run ended.
	Retry = Red.Event("Flight_Retry", function()
		return
	end),

	-- Fire a shot. shotId must be a monotonically increasing number per client.
	Fire = Red.Event("Flight_Fire", function(shotId, targetPoint)
		assert(typeof(shotId) == "number", "shotId must be a number")
		assert(typeof(targetPoint) == "Vector3", "targetPoint must be a Vector3")
		return shotId :: number, targetPoint :: Vector3
	end),
}
