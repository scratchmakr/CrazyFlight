local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SoundUtil = require(ReplicatedStorage.Shared.Utilities.SoundUtil)
local Assets = ReplicatedStorage.Assets

return function(functions)
	local hovering = Fusion.Value(false)
	local click = Fusion.Value(false)
	local events = {
		MouseEnter = function()
			hovering:set(true)
			SoundUtil.playSound({
				sound = Assets.SFX.UI.Hover,
			})
			if functions and functions["MouseEnter"] then
				functions["Value"]:set(true)
			end
		end,
		MouseLeave = function()
			hovering:set(false)
			click:set(false)
			if functions and functions["MouseLeave"] then
				functions["Value"]:set(false)
			end
		end,
		MouseButton1Down = function()
			click:set(true)
		end,
		MouseButton1Up = function()
			local ClickSound = (typeof(functions) == "table" and typeof(functions.ClickSound) == "Instance" and functions.ClickSound:IsA("Sound") and functions.ClickSound:Clone()) or Assets.SFX.UI.Click:Clone()
			SoundUtil.playSound({
				sound = ClickSound,
			})
			click:set(false)
		end,
	}

	return hovering, click, events
end
