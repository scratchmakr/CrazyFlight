local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local EasySprite, SpriteSequence = require(ReplicatedStorage.Shared.Imported.EasySprite), require(ReplicatedStorage.Shared.Imported.EasySprite.SpriteSequencer)
local presetsLibrary = require(script.Presets)

export type preferences = {
	presetType: string?,
	fps: number?,
	spritesheet: string?,
	dimensions: Vector2?,
	gridsize: Vector2?,
	looped: true?,
	pause: Fusion.Value<boolean>,
}

return function(spriteLabel: ImageLabel | ImageButton, preferences: preferences): (ImageLabel, SpriteSequence.Sequence)
	local masterTrove = Trove.new()
	preferences = preferences or {}
	local preset = presetsLibrary[spriteLabel.Name]
	local dimensions = preferences.dimensions or preset.dimensions
	local gridsize = preferences.gridsize or preset.gridsize
	local cells = gridsize.X * gridsize.Y
	local cellsize = Vector2.new(dimensions.X / gridsize.X, dimensions.Y / gridsize.Y)
	local spriteSheet = spriteLabel
	local mySpriteSheet = EasySprite.new(
		spriteSheet,
		preset and spriteSheet.Image or preferences.spritesheet,
		dimensions,
		cellsize
	)
	local sequence = SpriteSequence.fromRange(mySpriteSheet, 1, cells)
	Fusion.Hydrate(spriteSheet) {
		[Fusion.Cleanup] = function()
			masterTrove:Destroy()
		end,
	}
	sequence.play(preferences.fps or 30, preferences.looped)
	local pauseAnimation = preferences.pause
	if pauseAnimation then
		masterTrove:Add(Fusion.Observer(pauseAnimation):onChange(function()
			if pauseAnimation:get() then
				sequence.stop()
			else
				sequence.play(preferences.fps or 30, preferences.looped)
			end
		end))
	end
	return spriteSheet, sequence
end
