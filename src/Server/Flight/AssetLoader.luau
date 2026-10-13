--!strict
-- Resolves plane / gun / bullet asset templates. Falls back to generated
-- placeholders when the assets are missing in ReplicatedStorage.Assets.
-- Generated placeholders are cached inside ReplicatedStorage.Assets so later
-- replacement with real models "just works" without server restarts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceholderPlane = require(script.Parent.PlaceholderPlane)
local PlaceholderCannon = require(script.Parent.PlaceholderCannon)
local PlaceholderBullet = require(script.Parent.PlaceholderBullet)

local AssetLoader = {}

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function assetsFolder(): Folder
	return getOrCreateFolder(ReplicatedStorage, "Assets")
end

local function planesFolder(): Folder
	return getOrCreateFolder(assetsFolder(), "Planes")
end

local function gunsFolder(): Folder
	return getOrCreateFolder(assetsFolder(), "Guns")
end

local function projectilesFolder(): Folder
	return getOrCreateFolder(assetsFolder(), "Projectiles")
end

-- Validates that a plane template has the required structure.
local function isValidPlane(model: Instance): boolean
	if not model:IsA("Model") then return false end
	if not model.PrimaryPart then
		local root = model:FindFirstChild("Root")
		if root and root:IsA("BasePart") then
			model.PrimaryPart = root
		else
			return false
		end
	end
	if not model:FindFirstChild("PilotSeat") then return false end
	if not model:FindFirstChild("GunnerSeat") then return false end
	local mounts = model:FindFirstChild("GunMounts")
	if not mounts then return false end
	-- At least one BasePart child in GunMounts
	for _, child in mounts:GetChildren() do
		if child:IsA("BasePart") or child:IsA("Attachment") then
			return true
		end
	end
	return false
end

local function isValidGun(model: Instance): boolean
	if not model:IsA("Model") then return false end
	if not model.PrimaryPart then
		local base = model:FindFirstChild("Base")
		if base and base:IsA("BasePart") then
			model.PrimaryPart = base
		else
			return false
		end
	end
	local barrel = model:FindFirstChild("Barrel")
	if not barrel or not barrel:IsA("BasePart") then return false end
	if not barrel:FindFirstChild("Muzzle") then return false end
	return true
end

function AssetLoader.getPlaneTemplate(planeId: string): Model
	local folder = planesFolder()
	local existing = folder:FindFirstChild(planeId)
	if existing and isValidPlane(existing) then
		return existing :: Model
	end
	if existing then
		warn(`[AssetLoader] plane '{planeId}' exists but is invalid; replacing with placeholder`)
		existing:Destroy()
	end
	local placeholder = PlaceholderPlane.build()
	placeholder.Name = planeId
	placeholder.Parent = folder
	return placeholder
end

function AssetLoader.getGunTemplate(gunId: string): Model
	local folder = gunsFolder()
	local existing = folder:FindFirstChild(gunId)
	if existing and isValidGun(existing) then
		return existing :: Model
	end
	if existing then
		warn(`[AssetLoader] gun '{gunId}' exists but is invalid; replacing with placeholder`)
		existing:Destroy()
	end
	local placeholder = PlaceholderCannon.build()
	placeholder.Name = gunId
	placeholder.Parent = folder
	return placeholder
end

function AssetLoader.getBulletTemplate(bulletId: string): BasePart
	local folder = projectilesFolder()
	local existing = folder:FindFirstChild(bulletId)
	if existing and existing:IsA("BasePart") then
		return existing
	end
	if existing then
		warn(`[AssetLoader] bullet '{bulletId}' exists but is not a BasePart; replacing with placeholder`)
		existing:Destroy()
	end
	local placeholder = PlaceholderBullet.build()
	placeholder.Name = bulletId
	placeholder.Parent = folder
	return placeholder
end

return AssetLoader
