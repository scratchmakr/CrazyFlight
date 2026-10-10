local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local SpringTween = require(ReplicatedStorage.Packages.Spring)
local useButtonState = require(script.Parent.useButtonState)
local whiteButtonClick = require(script.WhiteButtonClick)
--local buttonGroupEffects = require(script.ButtonGroupEffects)

type WhiteOnClick = whiteButtonClick.WhiteOnClick
export type Properties = {
	Button: Instance,
	ScaleObject: GuiObject?,
	HoverScale: number | nil?,
	ClickScale: number | nil?,
	WhiteOnClick: WhiteOnClick?,
	Dampening: number?,
	Callback: () -> ()?,
	Functions: {
		MouseEnter: boolean?,
		MouseLeave: boolean?,
		Value: Fusion.Value<boolean>?,
	}?
	--ButtonGroup: buttonGroupEffects.Structure?,
}

return function (props: Properties)
	if not props.HoverScale then props.HoverScale = 1.07 end
	if not props.ClickScale then props.ClickScale = 0.95 end
	if not props.Dampening then props.Dampening = 0.7 end
	local trove = Trove.new()
	local hover,click,event = useButtonState(props.Functions)

	local ogScale = props.Button:FindFirstChildWhichIsA("UIScale")
	if ogScale then ogScale:Destroy() end
	
	if typeof(props.WhiteOnClick) == "table" then
		trove:Add(whiteButtonClick(props, click))
	end
	--if typeof(props.AssignButtonGroup) == "table" then
	--	trove:Add(buttonGroupEffects(props))
	--end
	
	local scaleObject = props.ScaleObject or props.Button
	local newUIScale = scaleObject:FindFirstChildOfClass("UIScale") or Fusion.New("UIScale") {}
	Fusion.Hydrate(scaleObject) {
		[Fusion.Children] = newUIScale
	}
	
	local currentScale = Fusion.Computed(function()
		return if click:get() then props.ClickScale 
			else if hover:get() then props.HoverScale 
			else 1
	end)

	trove:Add(Fusion.Observer(currentScale):onChange(function()
		local currentScale = currentScale:get()
		-- --print("currentScale", currentScale)
		SpringTween.stop(newUIScale)
		SpringTween.target(newUIScale, props.Dampening, 4, {
			Scale = currentScale
		})
	end))
	return Fusion.Hydrate(props.Button) {
		[Fusion.OnEvent("MouseEnter")] = event.MouseEnter,
		[Fusion.OnEvent("MouseLeave")] = event.MouseLeave,
		[Fusion.OnEvent("MouseButton1Down")] = event.MouseButton1Down,
		[Fusion.OnEvent("MouseButton1Up")] = event.MouseButton1Up,
		[Fusion.OnEvent("Activated")] = props.Callback,
	}
end
