local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
-- local UIContainer = require(ReplicatedStorage.Lobby.Shared.UI.Constants.UIContainer)
-- local blackFrameTemplate = UIContainer:WaitForChild("BlackFrame")

local responsiveButton = require(script.Parent.ResponsiveButton)

export type Structure = {
	Buttons: {GuiButton},
	ResponsiveButton: responsiveButton.Properties,
	
	BlackFrame: {CornerRadius: UDim}?,
	DefaultButton: GuiButton?,
}

type PropStructure = {
	selectedButton: Fusion.Value<typeof(({} :: Structure).DefaultButton) | nil>,
}

local CORRESPONDING_COLOR_PROPERTY = {
	TextLabel = "TextColor3",
	Frame = "BackgroundColor3",
}
local DARKENED_COLOR3 = Color3.fromRGB(160, 160, 160)

return function(props: Structure) : (Trove.Trove, PropStructure)
	local buttonGroup = props.Buttons
	--assert(typeof(props.ResponsiveButton) == "table")
	assert(typeof(buttonGroup) == "table", "Button group must be a table")
	----print(buttonGroup)
	if #buttonGroup <= 0 then return end
	local responsiveButtonInfo = props.ResponsiveButton or {}
	local selectedButton: typeof(({} :: PropStructure).selectedButton) = Fusion.Value(props.DefaultButton or buttonGroup[1])
	local props: PropStructure = {
		selectedButton = selectedButton,
	}
	local mainTrove = Trove.new()
	for _, button in buttonGroup do
		if button:IsA("ImageButton") then
			local ogButtonImgColor = button.ImageColor3
			local responsiveButtonProperties = table.clone(responsiveButtonInfo)
			responsiveButtonProperties.Button = button
			-- print("iterated thru", button, buttonGroup, responsiveButtonProperties)
			
			for _, guiObject in button:GetDescendants() do
				local correspondingProperty = CORRESPONDING_COLOR_PROPERTY[guiObject.ClassName]
				if correspondingProperty then
					mainTrove:Add(Fusion.Hydrate(guiObject) {
						[correspondingProperty] = Fusion.Computed(function()
							return selectedButton:get() == button and ogButtonImgColor or DARKENED_COLOR3
						end),
					})
				end
			end
			
			mainTrove:Add(Fusion.Hydrate(responsiveButton(responsiveButtonProperties)) {
				[Fusion.OnEvent("Activated")] = function()
					selectedButton:set(button)
				end,
				ImageColor3 = Fusion.Computed(function()
					return selectedButton:get() == button and ogButtonImgColor or DARKENED_COLOR3
				end),
			})
		end
	end
	
	return mainTrove, props
end
