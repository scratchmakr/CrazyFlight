local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectileFormat = require(ReplicatedStorage.Shared.Formats.ProjectileFormat)
local AttributeType = require(ReplicatedStorage.Shared.Types.AttributeType)

local SimulatedPlayersFolder = workspace:WaitForChild("SimulatedPlayers")

local SnapshotUtil = {}

function SnapshotUtil.lerpSnapshot(
	snapshot1: ProjectileFormat.Snapshot,
	snapshot2: ProjectileFormat.Snapshot,
	alpha: number
): ProjectileFormat.Snapshot

	alpha = math.clamp(alpha, 0, 1)

	local lerpedSnapshot = {
		timestamp = snapshot1.timestamp
			+ (snapshot2.timestamp - snapshot1.timestamp) * alpha,

		players = {},
	}

	for userId, player1 in snapshot1.players do
		local player2 = snapshot2.players[userId]

		if not player2 then
			continue
		end

		local lerpedPlayer = {}
		lerpedSnapshot.players[userId] = lerpedPlayer

		for bodyType, bodyInfo1 in player1 do
			local bodyInfo2 = player2[bodyType]

			if not bodyInfo2 then
				continue
			end

			lerpedPlayer[bodyType] = {
				CFrame = bodyInfo1.CFrame:Lerp(
					bodyInfo2.CFrame,
					alpha
				)
			}
		end
	end

	return lerpedSnapshot
end

function SnapshotUtil.getPlayerRigs()
    local playerRigs = SimulatedPlayersFolder:GetChildren()
    for _, player in Players:GetPlayers() do
        local character = player.Character
        if not character then
            continue
        end
        table.insert(playerRigs, character)
    end
    return playerRigs
end

function SnapshotUtil.getUserIdFromModel(model: Model): string?
    local playerFromCharacter = Players:GetPlayerFromCharacter(model)
    local userId = playerFromCharacter and playerFromCharacter.UserId
    userId = userId or (model and (model:GetAttribute(AttributeType.MatchingUserId) or model.Name))
    if not userId then
        return nil
    end

    return userId
end

function SnapshotUtil.getSimulatedRig(rig: Model): Model?
    local userId = SnapshotUtil.getUserIdFromModel(rig)
    if not userId then
        return nil
    end
    return SimulatedPlayersFolder:FindFirstChild(userId)
end

function SnapshotUtil.createSnapshot(playerRigs: { Instance })
    local snapshot: ProjectileFormat.Snapshot = {
        timestamp = workspace:GetServerTimeNow(),
        players = {},
    }

    local function createPlayerSnapshot(userId: string, rig: Model)
        local userSnapshot = {}
        for _, body in rig:GetChildren() do
            if not body:IsA("BasePart") or body.Name == "HumanoidRootPart" then
                continue
            end
            userSnapshot[body.Name] = {
                CFrame = body.CFrame,
            }
        end
        return userSnapshot
    end

    for _, character in playerRigs do
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not (character:IsA("Model") and humanoidRootPart) then
            continue
        end
        local player = Players:GetPlayerFromCharacter(character)
        local userId = player and player.UserId or character.Name
        snapshot.players[userId] = createPlayerSnapshot(userId, character)
    end

    return snapshot
end

return SnapshotUtil