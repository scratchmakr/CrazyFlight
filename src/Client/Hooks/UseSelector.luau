local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Store)

local Source = Vide.source
return function<T>(selector: (state: Store.State) -> T)
	local value = Source(selector(Store.getState())) :: Vide.Source<T>
	local disconnect = Store.subscribe(selector, function(new, old)
		value(new)
	end)
	return value, disconnect
end

