local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
return {
    ClientReady = Signal.new() :: Signal.Signal<Player>, 
    PlayerLeftSignals = {},
}
