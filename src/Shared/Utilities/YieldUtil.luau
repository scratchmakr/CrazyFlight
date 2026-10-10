local YieldUtil = {}

function YieldUtil.yieldForCondition(condition: <t>() -> t, timeout: number?)
    timeout = timeout or 10
    local timeNow = workspace:GetServerTimeNow()
    repeat
        local success = condition()
        if success then
            return success
        end

        task.wait()
    until workspace:GetServerTimeNow() - timeNow > timeout

    return false
end

return YieldUtil