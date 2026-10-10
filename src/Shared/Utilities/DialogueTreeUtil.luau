local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DialogueTree = require(ReplicatedStorage.Shared.Constants.DialogueTree)

local DialogueTreeUtil = {}

function DialogueTreeUtil.getDialogueTree(dialogueId: string): DialogueTree.TreeInfo
    local dialogueTree = DialogueTree.DIALOGUE_TREES[dialogueId]
    return dialogueTree
end

function DialogueTreeUtil.getNodeInfo(dialogueId: string, nodeName: string): DialogueTree.NodeInfo
    local dialogueTree = DialogueTreeUtil.getDialogueTree(dialogueId)
    local nodeInfo = dialogueTree and dialogueTree.nodes[nodeName]
    return nodeInfo
end

function DialogueTreeUtil.getNextNodeId(dialogueId: string, currentNodeId: string, decisionIndex: number?)
    local dialogueTree = DialogueTreeUtil.getDialogueTree(dialogueId)
    local currentNodeInfo = dialogueTree and dialogueTree.nodes[currentNodeId]
    if not currentNodeInfo then
        return nil
    end

    local nextNodeId = currentNodeInfo.nextNode

    local options = currentNodeInfo.options
    local optionInfo = decisionIndex and options and options[decisionIndex]
    if optionInfo then
        nextNodeId = optionInfo.nextNode
    end

    return nextNodeId
end

return DialogueTreeUtil