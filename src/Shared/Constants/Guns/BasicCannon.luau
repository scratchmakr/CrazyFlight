--!strict
-- BasicCannon weapon stats.

return {
	Id = "BasicCannon",
	DisplayName = "Basic Cannon",

	Damage = 10,

	-- Fire rate is the TOTAL shots/sec across all mounted barrels.
	-- Barrels alternate round-robin while preserving this cadence.
	FireRate = 8,

	-- Projectile
	ProjectileSpeed = 450,
	ProjectileLifetime = 3,
	ProjectileGravity = 0,

	-- Server-applied random spread in degrees
	Spread = 1,

	-- Overheat
	HeatPerShot = 8,
	MaxHeat = 100,
	CoolingRate = 25,
	OverheatRecoveryThreshold = 35,

	Automatic = true,

	-- Firing arc (degrees) relative to plane forward
	MaxAimYaw = 55,
	MaxAimPitch = 40,
}
