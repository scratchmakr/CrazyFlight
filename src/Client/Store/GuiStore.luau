local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local PageTypes = require(StarterPlayer.StarterPlayerScripts.Client.Types.PageTypes)
local Charm = require(ReplicatedStorage.Packages.Charm)

local INITIAL_STATE = {
    page = PageTypes.LANDING,
    pageLock = false,
}

local getState, setState = Charm.signal(INITIAL_STATE)
local ClientStore = {
    getState = getState,
    setState = setState,
    actions = {
        setPage = function(page: string)
            local currentState = getState()
            if currentState.pageLock then
                return
            end
            local newState = table.clone(currentState)
            newState.page = page
            setState(newState)
        end,
        togglePageLock = function(toggle: boolean)
            local currentState = getState()
            local newState = table.clone(currentState)
            newState.pageLock = toggle
            setState(newState)
        end
    }
}

export type Actions = typeof(ClientStore.actions)

return ClientStore