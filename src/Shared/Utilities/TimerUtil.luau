local ONE_DAY = 60 * 60 * 24
local SEVEN_DAYS = 7 * 60 * 60 * 24
local timerFunctions = {}
local timerUtil = {}
timerUtil.ONE_DAY = ONE_DAY
timerUtil.SEVEN_DAY = SEVEN_DAYS
timerUtil.timeFunctions = timerFunctions

function timerUtil.formatTime(t: number)
	local days = math.floor(t / ONE_DAY)
	local hours = math.floor(t / 3600) % 24
	local minutes = math.floor(t / 60) % 60
	local seconds = t % 60
	local hourString = ""
	local timeString = ""
	if hours > 0 then
		hourString = string.format("%02d:", hours)
	end
	if days > 0 then
		timeString ..= `{days}d`
	end
	timeString ..= `{hourString}{string.format("%02d:%02d", minutes, seconds)}`
	----print(days, timeString)
	return timeString
end

function timerUtil.dayChanged()
	local now = os.time()
	local nextDay = math.ceil(now / ONE_DAY) * ONE_DAY
	return nextDay - now, nextDay
end

function timerUtil.nextWeekTime()
	local adjustedTime = os.time() - (ONE_DAY  * 4)
	local weeklyRefreshAt = math.ceil(adjustedTime / (SEVEN_DAYS)) * SEVEN_DAYS
	
	return weeklyRefreshAt - adjustedTime, weeklyRefreshAt
end

function timerUtil.getTimeUntil(length: number)
	local now = os.time()
	local refreshTime = math.ceil(now / length) * length
	return refreshTime - now, refreshTime
end

function timerUtil.getRemainingTime(length: number, lastTime: number)
	return math.max(0, length - (os.time() - lastTime))
end

return timerUtil