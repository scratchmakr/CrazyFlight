--!strict
-- Generates a simple parts-based placeholder cannon model.
-- Structure:
--   BasicCannon
--     Base (PrimaryPart; welds to the mount)
--     Barrel
--     Muzzle (Attachment inside Barrel)

local PlaceholderCannon = {}

local function makePart(name: string, parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Material = Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

function PlaceholderCannon.build(): Model
	local model = Instance.new("Model")
	model.Name = "BasicCannon"

	local base = makePart("Base", model, {
		Size = Vector3.new(1.25, 1.25, 1.5),
		Color = Color3.fromRGB(60, 60, 60),
	})
	model.PrimaryPart = base

	local barrel = makePart("Barrel", model, {
		Size = Vector3.new(0.6, 0.6, 3),
		Color = Color3.fromRGB(40, 40, 40),
		CFrame = base.CFrame * CFrame.new(0, 0, 1.5),
	})
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = barrel
	w.Parent = base

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	-- Barrel forward is +Z; the muzzle attachment should sit at the tip.
	muzzle.CFrame = CFrame.new(0, 0, barrel.Size.Z * 0.5)
	muzzle.Parent = barrel

	return model
end

return PlaceholderCannon
