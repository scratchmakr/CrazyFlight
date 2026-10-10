local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local DeviceType = require(ReplicatedStorage.Shared.Types.DeviceType)

export type Context = {
    keybindInfos: { [DeviceType.DeviceType]: {
        frame: GuiObject,
        keybind: Enum.KeyCode?,
    } },
    deviceComputed: Fusion.Computed<DeviceType.DeviceType>,
}

return function(context: Context)
    local keybindInfos = context.keybindInfos
    local deviceComputed = context.deviceComputed

    for deviceType, keybindInfo in keybindInfos do
        local frame = keybindInfo.frame
        local keybind = keybindInfo.keybind

        if frame:IsA("ImageLabel") then
            local image = keybind and UserInputService:GetImageForKeyCode(keybind)
            if deviceType == DeviceType.TOUCH then
                image = "rbxassetid://135201838618320"
            end

            if image then
                frame.Image = image
            end
        elseif frame:IsA("TextLabel") then
            frame.Text = keybind.Name
        end

        Fusion.Hydrate(frame) {
            Visible = Fusion.Computed(function()
                return deviceComputed:get() == deviceType
            end)
        }
    end
end