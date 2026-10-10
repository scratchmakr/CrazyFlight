local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
return {
    CharacterReady = Signal.new() :: Signal.Signal<Model>,
    WheelSpun = Signal.new() :: Signal.Signal<>,
    DataLoaded = Signal.new() :: Signal.Signal<>,
    ToggleEnvironmentVFX = Signal.new() :: Signal.Signal<boolean>,
}