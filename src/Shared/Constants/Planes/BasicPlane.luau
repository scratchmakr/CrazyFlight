--!strict
-- BasicPlane flight stats. Not final balance; tweak freely.

return {
	Id = "BasicPlane",
	DisplayName = "Basic Plane",

	-- Speed (studs/second)
	CruiseSpeed = 85,
	BoostSpeed = 135,
	BrakeSpeed = 45,

	-- Steering (studs/second along each axis)
	HorizontalSpeed = 45,
	VerticalSpeed = 40,

	-- Smoothing exponents (higher = snappier)
	SteeringResponsiveness = 8,
	BankingResponsiveness = 6,

	-- Visual tilt limits (degrees)
	MaxBankAngle = 25,
	MaxPitchAngle = 15,

	-- Health & fuel
	MaxHearts = 3,
	FuelCapacity = 100,

	-- Fuel drain (per second)
	FuelDrain = 0.75,
	BoostFuelDrain = 2.0,
	BrakeFuelDrain = 0.3,

	-- Weapon
	GunId = "BasicCannon",

	-- Collision hitbox (studs)
	HitboxSize = Vector3.new(16, 4, 20),

	-- How much of the plane's velocity is inherited by bullets (0..1)
	InheritVelocityFactor = 0.5,

	-- Invulnerability window after a non-lethal hit (seconds)
	DamageInvulnerability = 0.6,
}
