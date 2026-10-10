local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientStore = require(script.ClientStore)
local GuiStore = require(script.GuiStore)
local Charm = require(ReplicatedStorage.Packages.Charm)
local Data = require(ReplicatedStorage.Shared.Constants.Data)

local getData, setData = Charm.signal(Data.TEMPLATE)

local Store = {
    getData = getData,
    setData = setData,
}

for _, store in script:GetChildren() do
    local success, module = pcall(require, store)
    if not success then
        continue
    end

    local actions = module.actions
    if actions then
        for actionName, action in actions do
            Store[actionName] = action
        end
    end
end

local clientStateComputed = Charm.computed(function()
    return ClientStore.getState()
end)

local computedState = Charm.computed(function()
    return {
        data = getData(),
        client = clientStateComputed(),
        gui = GuiStore.getState(),
    }
end)

export type State = typeof(computedState())

-- Accept both Store.getState(...) and Store:getState(...)
function Store.getState<T>(pathOrSelf: any, maybePath: ((state: State) -> T)?): typeof(computedState())
    local path = pathOrSelf
    if path == Store then
        path = maybePath
    end

    if typeof(path) == "function" then
        local state = computedState()
        return path(state)
    else
        return computedState()
    end
end


-- Accept both Store.subscribe(...) and Store:subscribe(...)
function Store.subscribe<T>(
	selfOrSelector: any,
	maybeSelector: any,
	maybeCallback: any
): () -> ()

	local selector = selfOrSelector
	local callback = maybeSelector

	if selfOrSelector == Store then
		selector = maybeSelector
		callback = maybeCallback
	end

	assert(typeof(selector) == "function", "Store.subscribe expects a selector function")
	assert(typeof(callback) == "function", "Store.subscribe expects a callback function")

	local initialized = false
	local previousValue: T

	return Charm.effect(function()
		local newValue: T = selector(computedState())

		if initialized and newValue ~= previousValue then
			local oldValue = previousValue
			previousValue = newValue

			callback(newValue, oldValue)
		else
			previousValue = newValue
			initialized = true
		end
	end)
end

type Store = typeof(Store)
type Actions = GuiStore.Actions & Store

return Store :: Actions