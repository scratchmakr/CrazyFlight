local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Data = require(ReplicatedStorage.Shared.Constants.Data)
local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)

local INITIAL_STATE = {
    playerStates = {} :: { [string]: Data.PlayerState },
}

local getState, setState = Charm.signal(INITIAL_STATE)
local ClientStore = {
    getState = getState,
    setState = setState,
}

function ClientStore.patchState(patch: {[string]: any}, replace: boolean?)
    local currentState = getState()
    local newState = table.clone(currentState)
    if replace then
        TableUtil.surfaceMerge(newState, patch)
    else
        TableUtil.deepMerge(newState, patch)
    end
    -- print("patching state", patch, newState, replace)
    setState(newState)
end

return ClientStore