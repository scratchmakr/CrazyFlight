local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")
local UserUtil = {}

export type UserInfo = {
    username: string,
    displayName: string,
    iconId: string,
    friendIds: { string },
}

UserUtil.playerInfoCache = {} :: { [string]: UserInfo }

function UserUtil.getUserInfo(userId: string): UserInfo?
    userId = tostring(userId)
    local numericId = tonumber(userId)
    local playerInfo = UserUtil.playerInfoCache[userId] or {}
    if playerInfo.username and playerInfo.displayName then
        return playerInfo
    end

    local function updatePlayerInfo(context: {
        username: string,
        displayName: string,
    })
        playerInfo.username = context.username
        playerInfo.displayName = context.displayName
        UserUtil.playerInfoCache[userId] = playerInfo
    end

    local playerInstance = Players:GetPlayerByUserId(numericId)
    if playerInstance then
        updatePlayerInfo({
            username = playerInstance.Name,
            displayName = playerInstance.DisplayName,
        })
        return playerInfo
    end

    local success, content = pcall(function(...)
        return UserService:GetUserInfosByUserIdsAsync({numericId})
    end)
    local userInfo = success and content[1]
    if success then
        updatePlayerInfo({
            username = userInfo.Username,
            displayName = userInfo.DisplayName,
        })
        return playerInfo
    end

    return nil
end

function UserUtil.getUserThumbnail(userId: string, thumbnailType: Enum.ThumbnailType?, thumbnailSize: Enum.ThumbnailSize?)
    thumbnailType = thumbnailType or Enum.ThumbnailType.HeadShot
    thumbnailSize = thumbnailSize or Enum.ThumbnailSize.Size420x420
    userId = tostring(userId)
    local numericId = tonumber(userId)
    local playerInfo = UserUtil.playerInfoCache[userId] or {}
    local key = `icon{thumbnailType.Name}{thumbnailSize.Name}`
    local iconId = playerInfo[key]
    if iconId then
        return iconId
    end

    local success, content = pcall(function()
        return Players:GetUserThumbnailAsync(numericId, thumbnailType, thumbnailSize)
    end)

    local playerInfo = UserUtil.playerInfoCache[userId] or {}
    if success then
        playerInfo[key] = content
        UserUtil.playerInfoCache[userId] = playerInfo
    end

    return content
end

function UserUtil.getFriendInfos(userId: string | number)
    local numericId = tonumber(userId)
    local playerInfo = UserUtil.playerInfoCache[numericId] or {}
    local friendIds = playerInfo.friendIds
    if friendIds then
        return friendIds
    end

    local friends = {}
	local success, pages = pcall(function()
		return Players:GetFriendsAsync(numericId)
	end)

	if not success then
		warn("Failed to get friends:", pages)
		return friends
	end

    local maxFriends = 100
	while true do
        if #friends >= maxFriends then
            break
        end

		for _, friendInfo in pages:GetCurrentPage() do
			table.insert(friends, friendInfo)
		end

		if pages.IsFinished then
			break
		end

		local pageSuccess, pageError = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)

		if not pageSuccess then
			warn("Failed to load next friends page:", pageError)
			break
		end
	end

    playerInfo.friendIds = friends
    UserUtil.playerInfoCache[numericId] = playerInfo
	return friends
end

if RunService:IsClient() then
    UserUtil.getFriendInfos(Players.LocalPlayer.UserId)
end

return UserUtil