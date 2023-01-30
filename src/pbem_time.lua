--[[
----------------------------------------------
IKE
pbem_time.lua
----------------------------------------------

Contains all functions that deal with scenario time
and turn times.

----------------------------------------------
]]--

IKE_DATEFORMAT = "MMDDYYYY"

--[[
A reimplementation of os.date() to workaround
inability of Lua embedded library to handle
negative epoch times, using CMO's native
EpochToUTC_* functions.

We could entirely supplant os.date with this, but 
it's riskier due to the need to parse strings
from CMO and the chance of an internal library
changing without notice. We'll just use this
method for negative epoch times only.
]]--
function EpochTimeToUTC(etime, date_sep, time_sep)
    local date = EpochToUTC_Date(etime)
    local time = EpochToUTC_Time(etime)

    -- separator characters sometimes change between
    -- locales, so let's replace with whitespace
    local date_tbl_str = string.gsub(date, "%D", " ")
    local time_tbl_str = string.gsub(time, "%D", " ")
    local date_tbl = String_Split(date_tbl_str)
    local time_tbl = String_Split(time_tbl_str)
    
    local day = tonumber(date_tbl[1])
    local month = tonumber(date_tbl[2])
    local year = tonumber(date_tbl[3])
    local hour = tonumber(time_tbl[1])
    local minute = tonumber(time_tbl[2])
    local second = tonumber(time_tbl[3])

    return {
        Date=month..date_sep..day..date_sep..year,
        Time=hour..time_sep..minute..time_sep..second,
        DateFormat=IKE_DATEFORMAT
    }
end

function PBEM_CustomTimeToUTC(time_secs)
    if time_secs < 0 then
        return EpochTimeToUTC(time_secs)
    end

    local date_str = os.date("!%m.%d.%Y", time_secs)
    local time_str = os.date("!%H.%M.%S", time_secs)
    return {
        Date=date_str,
        Time=time_str,
        DateFormat=IKE_DATEFORMAT
    }
end

function PBEM_StartTimeToUTC()
    return PBEM_CustomTimeToUTC(
        tonumber(VP_GetScenario().StartTimeNum)
    )
end

function PBEM_CustomTimeMilitary(currentTime)
    if currentTime < 0 then
        local date_time = EpochTimeToUTC(currentTime, "/", ":")
        return date_time.Date.." "..date_time.Time.."Z"
    end
    
    return os.date("!%m/%d/%Y %H:%M:%SZ", currentTime)
end

function PBEM_CurrentTimeMilitary()
    return PBEM_CustomTimeMilitary(
        tonumber(VP_GetScenario().CurrentTimeNum)
    )
end

--[[
returns the start time of the current turn in seconds
]]--
function PBEM_GetCurTurnStartTime()
    return GetNumber("__CUR_TURN_TIME")
end

--[[
return the start time of the next turn in seconds
]]--
function PBEM_GetNextTurnStartTime()
    return PBEM_GetCurTurnStartTime() + PBEM_TurnLength()
end
