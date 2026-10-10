local StarterPlayer = game:GetService("StarterPlayer")
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local SpriteSheets = UIContainer.SpriteSheets

export type format = {
	dimensions: Vector2,
	gridsize: Vector2,
}
local presets: {[string]: format} = {
	[SpriteSheets.LightningBall.Name] = {
		dimensions = Vector2.one * 1024,
		gridsize = Vector2.new(8, 8)
	},
}

return presets
