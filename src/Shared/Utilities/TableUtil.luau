local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local Symbols = require(ReplicatedStorage.Shared.Types.Symbols)

local TableUtil = {}

function TableUtil.deepMerge(target: any, source: any): any
	for k, v in pairs(source) do
		if v == Symbols.NIL_SYMBOL then
			target[k] = nil
		elseif type(v) == "table" and target[k] then
			target[k] = TableUtil.deepMerge(table.clone(target[k]), v)
		else
			target[k] = v
		end
	end
	return target
end

function TableUtil.surfaceMerge(target: any, source: any): any
	for k, v in pairs(source) do
		if v == Symbols.NIL_SYMBOL then
			target[k] = nil
		else
			target[k] = v
		end
	end
	
	return target
end

function TableUtil.getDifferences(tbl1, tbl2): ({[string | number]: true?}, number)
	--tbl1 = tbl1 or {}
	--tbl2 = tbl2 or {}
	if not (typeof(tbl1) == "table" and typeof(tbl2) == "table") then
		--warn("Incorrect arguments for difference check")
		return {}, 1
	end
	local differences = {}

	for id, amt in tbl1 do
		local otherAmt = tbl2[id]
		if not otherAmt or (otherAmt and otherAmt ~= amt) then
			differences[id] = true
		end
	end
	
	for id, amt in tbl2 do
		if differences[id] then continue end
		local otherAmt = tbl1[id]
		if not otherAmt or (otherAmt and otherAmt ~= amt) then
			differences[id] = true
		end
	end
	
	return differences, #RblxUtils.Table.keys(differences)
end

function TableUtil.deepEqual(a, b)
	if a == b then
		return true
	end

	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	for key, value in a do
		if not TableUtil.deepEqual(value, b[key]) then
			return false
		end
	end

	for key in b do
		if a[key] == nil then
			return false
		end
	end

	return true
end

function TableUtil.shuffle(array, random: Random)
    for i = #array, 2, -1 do
        local j = random:NextInteger(1, i)
        array[i], array[j] = array[j], array[i]
    end
end

return TableUtil