--[[
----------------------------------------------
IKE
pbem_time.lua
----------------------------------------------

Contains all functions that deal with scenario time
and turn times.

----------------------------------------------
]]--

function PBEM_StartTimeToUTC()
    local date_str = os.date("!%m.%d.%Y", VP_GetScenario().StartTimeNum)
    local time_str = os.date("!%H.%M.%S", VP_GetScenario().StartTimeNum)
    return {Date=date_str, Time=time_str}
end

function PBEM_CustomTimeToUTC(time_secs)
    local date_str = os.date("!%m.%d.%Y", time_secs)
    local time_str = os.date("!%H.%M.%S", time_secs)
    return {Date=date_str, Time=time_str}
end

function PBEM_CurrentTimeMilitary()
    return os.date("!%m/%d/%Y %H:%M:%SZ", VP_GetScenario().CurrentTimeNum)
end

function PBEM_ScenarioStartTime()
    return GetNumber("__PBEM_STARTTIME")
end

--[[
determines what the current side SHOULD be from the current time
]]--
function PBEM_GetCurSideFromTime()
    local scenStartTime = VP_GetScenario().StartTimeNum
    local scenCurTime = ScenEdit_CurrentTime()
    local round_length = PBEM_RoundLength()

    local offset = scenCurTime - scenStartTime
    local turn_num = math.floor(offset / round_length)

    local turn_start_time = scenStartTime + turn_num*round_length
    for k,v in ipairs(PBEM_TURN_LENGTHS) do
        turn_start_time = turn_start_time + v
        if turn_start_time > scenCurTime then
            return k    
        end
    end
    -- should never happen unless we're messing with the time
    return 999
end

--[[
returns the start time of the current turn in seconds
]]--
function PBEM_GetCurTurnStartTime()
    local scenStartTime = VP_GetScenario().StartTimeNum
    local turnNumber = Turn_GetTurnNumber()
    if turnNumber == 0 then
        -- setup phase
        return scenStartTime
    end
    local round_length = PBEM_RoundLength()
    local offset = (turnNumber-1)*round_length
    for i=1,(Turn_GetCurSide()-1) do
        offset = offset + PBEM_TURN_LENGTHS[i]
    end
    
    return scenStartTime + offset
end

--[[
return the start time of the next turn in seconds
]]--
function PBEM_GetNextTurnStartTime()
    return PBEM_TURN_START_TIME + PBEM_TURN_LENGTH
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

