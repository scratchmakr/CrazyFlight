--!strict
-- Small neon projectile visual template. Clients clone and position this.

local PlaceholderBullet = {}

function PlaceholderBullet.build(): BasePart
	local p = Instance.new("Part")
	p.Name = "BasicBullet"
	p.Size = Vector3.new(0.4, 0.4, 1.5)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 220, 80)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false

	local light = Instance.new("PointLight")
	light.Range = 6
	light.Brightness = 1.5
	light.Color = p.Color
	light.Parent = p

	return p
end

return PlaceholderBullet
