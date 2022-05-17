--[[
----------------------------------------------
IKE
pbem_time.lua
----------------------------------------------

Contains all functions that deal with scenario time
and turn times.

----------------------------------------------
]]--

--[[
A partial reimplementation of os.date() to workaround
CMO bug with negative epoch times. Should work from
Jan 1, 1900 00:00:00 through Feb 28, 2100 23:59:59.
]]--
function EpochTimeToUTC(etime, date_sep, time_sep)
    date_sep = date_sep or "."
    time_sep = time_sep or "."

    local function isLeapYear(y)
        if y % 4 == 0 then
            if y % 100 == 0 then
                if y % 400 == 0 then
                    return true
                end
                return false
            end
            return true
        end
        return false
    end

    local days_in_month_common  = {31,28,31,30,31,30,31,31,30,31,30,31}
    local days_in_month_leap    = {31,29,31,30,31,30,31,31,30,31,30,31}

    --start from midnight Jan 1, 1900, or -2208988800 epoch seconds
    --note that 1900 was NOT a leap year due to Gregorian rules.
    --However 1904 was--so it's okay to start here.
    local EPOCH_20TH_CENTURY = -2208988800 
    local SECONDS_TO_HOURS = 60*60
    local SECONDS_TO_DAYS = SECONDS_TO_HOURS*24
    local SECONDS_TO_COMMON_YEAR = SECONDS_TO_DAYS*365
    local SECONDS_TO_LEAP_YEAR = SECONDS_TO_DAYS*366
    local SECONDS_IN_LEAP_SEQ = SECONDS_TO_COMMON_YEAR*3+SECONDS_TO_LEAP_YEAR

    etime = etime - EPOCH_20TH_CENTURY
    local leap_seqs = math.floor(etime / SECONDS_IN_LEAP_SEQ)
    local remainder_secs = etime % SECONDS_IN_LEAP_SEQ
    local remainder_years = math.floor(remainder_secs / SECONDS_TO_COMMON_YEAR)
    remainder_secs = remainder_secs % SECONDS_TO_COMMON_YEAR
    local remainder_days = math.floor(remainder_secs / SECONDS_TO_DAYS)
    remainder_secs = remainder_secs % SECONDS_TO_DAYS

    local year = 1900 + leap_seqs*4 + remainder_years

    local month_table
    if isLeapYear(year) then
        month_table = days_in_month_leap
    else
        month_table = days_in_month_common
    end

    local month = 1
    local day = 1

    while remainder_days > 0 do
        if remainder_days > month_table[month] then
            remainder_days = remainder_days - month_table[month]
            month = month + 1
        else
            day = day + remainder_days
            remainder_days = 0
        end
    end

    local hour = math.floor(remainder_secs / SECONDS_TO_HOURS)
    remainder_secs = remainder_secs % SECONDS_TO_HOURS
    local minute = math.floor(remainder_secs / 60)
    local second = remainder_secs % 60

    if hour < 10 then
        hour = "0"..tostring(hour)
    end
    if minute < 10 then
        minute = "0"..tostring(minute)
    end
    if second < 10 then
        second = "0"..tostring(second)
    end

    return {
        Date=month..date_sep..day..date_sep..year, 
        Time=hour..time_sep..minute..time_sep..second
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
        Time=time_str
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
