local StringUtil = {}

local SHORT_SUFFIXES = {
	"", -- 10^0
	"K", -- 10^3
	"M", -- 10^6
	"B", -- 10^9
	"T", -- 10^12
	"Qa", -- 10^15 quadrillion
	"Qi", -- 10^18 quintillion
	"Sx", -- 10^21 sextillion
	"Sp", -- 10^24 septillion
	"Oc", -- 10^27 octillion
	"No", -- 10^30 nonillion
	"Dc", -- 10^33 decillion
	"Ud", -- 10^36 undecillion
	"Dd", -- 10^39 duodecillion
	"Td", -- 10^42 tredecillion
	"Qdc", -- 10^45 quattuordecillion
	"Qid", -- 10^48 quindecillion
}

local LONG_SUFFIXES = {
	"", -- 10^0
	"thousand",
	"million",
	"billion",
	"trillion",
	"quadrillion",
	"quintillion",
	"sextillion",
	"septillion",
	"octillion",
	"nonillion",
	"decillion",
	"undecillion",
	"duodecillion",
	"tredecillion",
	"quattuordecillion",
	"quindecillion",
}

local function trimNumberString(s: string): string
	-- Turns "1.2300" -> "1.23", and "2.000" -> "2"
	if not s:find(".", 1, true) then
		return s
	end
	s = s:gsub("0+$", "")
	s = s:gsub("%.$", "")
	return s
end

local function formatWithMaxDecimals(num: number, maxDecimals: number): string
	if maxDecimals <= 0 then
		return tostring(math.floor(num + 0.5))
	end

	local factor = 10 ^ maxDecimals
	local rounded = math.floor(num * factor + 0.5) / factor

	-- Luau doesn't always like computed format specifiers, so build the format string explicitly.
	local fmt = "%." .. tostring(maxDecimals) .. "f"
	return trimNumberString(string.format(fmt, rounded))
end

-- Abbreviates large numbers:
--  - 1500 -> "1.5K"
--  - 1_250_000 -> "1.25M"
--  - 1_000_000_000_000_000_000 -> "1Qi" (quintillion)
--
-- style: "short" | "long"
function StringUtil.abbreviateNumber(value: number, maxDecimals: number?, style: string?): string
	local resolvedMaxDecimals: number = (maxDecimals ~= nil) and maxDecimals or 2
	local resolvedStyle: string = style or "short"

	if value ~= value then
		return "NaN"
	end

	if value == math.huge then
		return "Infinity"
	elseif value == -math.huge then
		return "-Infinity"
	end

	if value == 0 then
		return "0"
	end

	local sign = value < 0 and -1 or 1
	local absValue = math.abs(value)

	local tier = 0
	local tierCap = #SHORT_SUFFIXES - 1
	while absValue >= 1000 and tier < tierCap do
		absValue /= 1000
		tier += 1
	end

	local suffixIndex = tier + 1

	-- Tier 0: return the (possibly rounded) raw number.
	if tier == 0 then
		local absFloor = math.floor(absValue)
		if math.abs(absValue - absFloor) < 1e-9 then
			return (sign < 0 and "-" or "") .. tostring(absFloor)
		end
		return (sign < 0 and "-" or "") .. formatWithMaxDecimals(absValue, resolvedMaxDecimals)
	end

	local formatted = formatWithMaxDecimals(absValue, resolvedMaxDecimals)

	if resolvedStyle == "long" then
		local word = LONG_SUFFIXES[suffixIndex] or ""
		if word == "" then
			return (sign < 0 and "-" or "") .. formatted
		end
		return (sign < 0 and "-" or "") .. formatted .. " " .. word
	end

	-- Default: "short"
	local short = SHORT_SUFFIXES[suffixIndex] or ""
	return (sign < 0 and "-" or "") .. formatted .. short
end

function StringUtil.formatTime(seconds: number): string
	if seconds ~= seconds or seconds < 0 then
		seconds = 0
	end

	local total = math.floor(seconds)
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60

	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, secs)
	elseif minutes >= 10 then
		return string.format("%02d:%02d", minutes, secs)
	end

	return string.format("%d:%02d", minutes, secs)
end

return StringUtil