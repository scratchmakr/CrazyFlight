--!strict
-- Generates a simple parts-based placeholder plane model.
-- Returns a Model that follows the required structure:
--   BasicPlane
--     Root (PrimaryPart, invisible hitbox)
--     Body (fuselage, nose, wings, tail)
--     PilotSeat (Seat)
--     GunnerSeat (Seat)
--     GunMounts (Mount1, Mount2)
--     Visuals (cockpit, props, etc.)

local PlaceholderPlane = {}

local function makePart(name: string, parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Material = Enum.Material.SmoothPlastic
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

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

function PlaceholderPlane.build(): Model
	local model = Instance.new("Model")
	model.Name = "BasicPlane"

	-- Root (hitbox, PrimaryPart). Keep it CanQuery=true so the server collision
	-- scan can use GetPartsInPart on it.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(16, 4, 20)
	root.Transparency = 1
	root.Material = Enum.Material.SmoothPlastic
	root.CanCollide = false
	root.CanQuery = true
	root.CanTouch = false
	root.Massless = false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.3, 0.5)
	root.Parent = model
	model.PrimaryPart = root

	local body = Instance.new("Folder")
	body.Name = "Body"
	body.Parent = model

	-- Fuselage
	local fuselage = makePart("Fuselage", body, {
		Size = Vector3.new(4, 3, 16),
		Color = Color3.fromRGB(170, 180, 190),
		CFrame = root.CFrame,
	})
	weld(root, fuselage)

	-- Nose
	local nose = makePart("Nose", body, {
		Size = Vector3.new(2.5, 2.5, 4),
		Color = Color3.fromRGB(80, 90, 100),
		CFrame = root.CFrame * CFrame.new(0, 0, 10),
	})
	weld(root, nose)

	-- Wings (left + right)
	local leftWing = makePart("LeftWing", body, {
		Size = Vector3.new(10, 0.75, 5),
		Color = Color3.fromRGB(190, 60, 60),
		CFrame = root.CFrame * CFrame.new(-7, 0, -1),
	})
	weld(root, leftWing)
	local rightWing = makePart("RightWing", body, {
		Size = Vector3.new(10, 0.75, 5),
		Color = Color3.fromRGB(190, 60, 60),
		CFrame = root.CFrame * CFrame.new(7, 0, -1),
	})
	weld(root, rightWing)

	-- Tail fin
	local tailFin = makePart("TailFin", body, {
		Size = Vector3.new(0.5, 4, 3),
		Color = Color3.fromRGB(190, 60, 60),
		CFrame = root.CFrame * CFrame.new(0, 2, -8),
	})
	weld(root, tailFin)
	-- Tail wings
	local tailWing = makePart("TailWing", body, {
		Size = Vector3.new(8, 0.5, 2.5),
		Color = Color3.fromRGB(190, 60, 60),
		CFrame = root.CFrame * CFrame.new(0, 1, -8),
	})
	weld(root, tailWing)

	-- Seats --------------------------------------------------------------
	local function makeSeat(name: string, offset: CFrame): Seat
		local seat = Instance.new("Seat")
		seat.Name = name
		seat.Size = Vector3.new(2, 0.5, 2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CanQuery = false
		seat.CanTouch = true -- Seat needs CanTouch to detect humanoids
		seat.Massless = true
		seat.Anchored = false
		seat.CFrame = root.CFrame * offset
		seat.Parent = model
		weld(root, seat)
		return seat
	end
	makeSeat("PilotSeat", CFrame.new(0, 2, 2))
	makeSeat("GunnerSeat", CFrame.new(0, 2, -3))

	-- Gun mounts ---------------------------------------------------------
	local gunMounts = Instance.new("Folder")
	gunMounts.Name = "GunMounts"
	gunMounts.Parent = model

	local function makeMount(name: string, offset: CFrame): BasePart
		local mount = makePart(name, gunMounts, {
			Size = Vector3.new(0.5, 0.5, 0.5),
			Transparency = 1,
			CFrame = root.CFrame * offset,
		})
		weld(root, mount)
		-- Mount forward is along +Z of the mount itself
		local attachment = Instance.new("Attachment")
		attachment.Name = "MountAttachment"
		attachment.CFrame = CFrame.new()
		attachment.Parent = mount
		return mount
	end
	makeMount("Mount1", CFrame.new(-5, -0.5, 4))
	makeMount("Mount2", CFrame.new(5, -0.5, 4))

	-- Visuals ------------------------------------------------------------
	local visuals = Instance.new("Folder")
	visuals.Name = "Visuals"
	visuals.Parent = model
	-- Simple cockpit glass
	local cockpit = makePart("Cockpit", visuals, {
		Size = Vector3.new(3, 2, 4),
		Material = Enum.Material.Glass,
		Transparency = 0.5,
		Color = Color3.fromRGB(130, 180, 220),
		CFrame = root.CFrame * CFrame.new(0, 2, 2),
	})
	weld(root, cockpit)

	return model
end

return PlaceholderPlane
