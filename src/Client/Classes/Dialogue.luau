local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local DialogueTree = require(ReplicatedStorage.Shared.Constants.DialogueTree)
local DialogueTreeUtil = require(ReplicatedStorage.Shared.Utilities.DialogueTreeUtil)

export type Context = {
    id: string,
    showUI: Fusion.Value<boolean>,
    currentDialogue: Fusion.Value<string>,
    signals: {
        skippedDialogue: Signal.Signal<() -> ()>,
    },
    onComplete: () -> (),
}

local Dialogue = {}
Dialogue.__index = Dialogue
Dialogue.EVENT_TYPES = {
    FORCE_CLOSE = "force_close",
}
function Dialogue.new(context: Context)
    local self = setmetatable({
        masterTrove = Trove.new(),
        id = context.id,
        showUI = context.showUI,
        currentDialogue = context.currentDialogue,
        onComplete = context.onComplete,
        currentNode = Fusion.Value("") :: Fusion.Value<string>,
        signals = {
            eventTrigger = Signal.new(),
            decisionMade = Signal.new(),
            skippedDialogue = context.signals.skippedDialogue,
        },
    }, Dialogue)

    return self
end

export type Self = typeof(Dialogue.new(...))
function Dialogue.getDialogueTree(self: Self): DialogueTree.TreeInfo
    return DialogueTreeUtil.getDialogueTree(self.id)
end

function Dialogue.getNodeInfo(self: Self, nodeName: string): DialogueTree.NodeInfo
    return DialogueTreeUtil.getNodeInfo(self.id, nodeName)
end

function Dialogue.getNextNodeId(self: Self, decisionIndex: number?)
    local nodeName = self.currentNode:get()
    return DialogueTreeUtil.getNextNodeId(self.id, nodeName, decisionIndex)
end

function Dialogue.initialize(self: Self)
    -- local masterTrove = self.masterTrove
    -- local signals = self.signals
    local dialogueTree = self:getDialogueTree()
    local startNode = dialogueTree.startNode
    local nodeInfo = self:getNodeInfo(startNode)

    -- local debounce = false
    -- masterTrove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
    --     if gameProcessedEvent or debounce then
    --         return
    --     end
    --     debounce = true
    --     task.delay(0.25, function()
    --         debounce = false
    --     end)
    --     signals.skippedDialogue:Fire()
    -- end))
    self.showUI:set(true)
    self.currentNode:set(startNode)
    self.currentDialogue:set(nodeInfo.text)
end

function Dialogue.setNextNode(self: Self, decisionIndex: number?)
    local signals = self.signals
    local masterTrove = self.masterTrove
    local nodeTrove = masterTrove:Extend()

    local nextNodeId = self:getNextNodeId(decisionIndex)
    if not nextNodeId then
        self:destroy()
        signals.decisionMade:Fire(decisionIndex or nil)
        return
    else
        signals.decisionMade:Fire(decisionIndex or nil)
    end

    local nextNodeInfo = self:getNodeInfo(nextNodeId)
    local waitForToOpen = nextNodeInfo.waitForToOpen
    local waitForToClose = nextNodeInfo.waitForToClose
    if waitForToOpen or waitForToClose then
        local waitForOpenEvent = waitForToOpen and waitForToOpen.event
        -- local waitForOpenValue = waitForToOpen and waitForToOpen.value

        local waitForCloseEvent = waitForToClose and waitForToClose.event
        -- local waitForCloseValue = waitForToClose and waitForToClose.value
        nodeTrove:Add(signals.eventTrigger:Connect(function(event: string)--, value: number)
            if waitForOpenEvent and event == waitForOpenEvent then
                -- if waitForOpenValue and value and value ~= waitForOpenValue then
                --     return
                -- end
                self.showUI:set(true)

                if not waitForToClose then
                    nodeTrove:Destroy()
                end
            end

            local isForceClose = event == Dialogue.EVENT_TYPES.FORCE_CLOSE
            if (waitForCloseEvent and event == waitForCloseEvent) or isForceClose then
                -- if waitForCloseValue and value and value ~= waitForCloseValue then
                --     return
                -- end
                if isForceClose then
                    self.showUI:set(false)
                else
                    self:setNextNode(nil)    
                end
                nodeTrove:Destroy()
            end
        end))
    end

    self.showUI:set(not waitForToOpen)
    self.currentDialogue:set(nextNodeInfo.text)
    self.currentNode:set(nextNodeId)
end

function Dialogue.onDecisionMade(self: Self, callback: (decisionIndex: number?) -> (), disconnectOnDecision: boolean?)
    local masterTrove = self.masterTrove
    local signals = self.signals
    local connection
    connection = signals.decisionMade:Connect(function(decisionIndex: number?)
        callback(decisionIndex)
        if disconnectOnDecision then
            connection:Disconnect()
        end
    end)
    masterTrove:Add(connection)
    return connection
end

function Dialogue.destroy(self: Self)
    self.showUI:set(false)
    local onComplete = self.onComplete
    if typeof(onComplete) == "function" then
        onComplete()
    end
    local masterTrove = self.masterTrove
    task.delay(0.5, function()
        masterTrove:Destroy()
    end)
end

return Dialogue