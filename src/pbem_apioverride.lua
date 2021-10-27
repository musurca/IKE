--[[
----------------------------------------------
IKE
pbem_apioverride.lua
----------------------------------------------

Contains definitions for the IKE functions that 
replace parts of the default CMO ScenEdit_* API.

----------------------------------------------
]]--

function PBEM_InitAPIReplace()
    PBEM_InitScenarioOver()
    PBEM_InitRandom()
    PBEM_InitSpecialMessage()
    PBEM_InitPlayerSide()
end

function PBEM_EndAPIReplace()
    PBEM_FlushSpecialMessages()

    PBEM_EndScenarioOver()
    PBEM_EndRandom()
    PBEM_EndSpecialMessage()
    PBEM_EndPlayerSide()

    PBEM_OnInitialSetup = nil
end

function PBEM_InitPlayerSide()
    if not __PBEM_FN_PLAYERSIDE then
        __PBEM_FN_PLAYERSIDE = ScenEdit_PlayerSide
    end
    ScenEdit_PlayerSide = PBEM_PlayerSide
end

function PBEM_EndPlayerSide()
    if __PBEM_FN_PLAYERSIDE then
        ScenEdit_PlayerSide = __PBEM_FN_PLAYERSIDE
    end
end

function PBEM_PlayerSide()
    --clean up if haven't been already
    if PBEM_NotRunning() then
        PBEM_EndPlayerSide()
        return ScenEdit_PlayerSide()
    end

    local side = __PBEM_FN_PLAYERSIDE()
    if side == PBEM_DUMMY_SIDE then
        return Turn_GetCurSideName()
    end
    return side
end

function PBEM_SpecialMessage(side, message, location, priority)
    --clean up if haven't been already
    if PBEM_NotRunning() then
        PBEM_EndSpecialMessage()
        if location then
            ScenEdit_SpecialMessage(side, message, location)
        else
            ScenEdit_SpecialMessage(side, message)
        end
        return
    end

    priority = priority or false
    if not PBEM_MESSAGEQUEUE then
        PBEM_MESSAGEQUEUE = {}
    end
    local side_name = side
    --make sure messages are properly delivered
    if side_name == Turn_GetCurSideName() then
        local cur_side = __PBEM_FN_PLAYERSIDE()
        if ScenEdit_CurrentTime() ~= VP_GetScenario().StartTimeNum or cur_side ~= PBEM_DUMMY_SIDE then
            -- immediately deliver the message
            if location then
                __PBEM_FN_SPECIALMESSAGE("playerside", message, location)
            else
                __PBEM_FN_SPECIALMESSAGE("playerside", message)
            end
            return
        end
        --otherwise, if on scenario load and player is first side, save all messages
        --and flush them all at once
    elseif IsIn(side_name, PBEM_PLAYABLE_SIDES) then
        -- if not 'playerside' or current side, then save it
        -- for later display
        for k,v in ipairs(PBEM_PLAYABLE_SIDES) do
            if side_name == v then
                local prev_msgs = GetString("__SCEN_PREVMSGS_"..k)
                prev_msgs = prev_msgs.."<br/><center><i>------------------------------<br/>"..PBEM_CurrentTimeMilitary().."<br/>------------------------------</i></center><br/>"..message.."<br/>"
                StoreString("__SCEN_PREVMSGS_"..k, prev_msgs)
                break
            end
        end
        return
    end
    local new_msg = {
        side=side_name,
        message=message,
        location=location
    }
    if priority then
        table.insert(PBEM_MESSAGEQUEUE, 1, new_msg)
    else
        table.insert(PBEM_MESSAGEQUEUE, new_msg)
    end
end

function PBEM_FlushSpecialMessages()
    if PBEM_MESSAGEQUEUE then
        for k,v in ipairs(PBEM_MESSAGEQUEUE) do
            if v.location then
                __PBEM_FN_SPECIALMESSAGE(v.side, v.message, v.location)
            else
                __PBEM_FN_SPECIALMESSAGE(v.side, v.message)
            end
        end
        PBEM_MESSAGEQUEUE = nil
    end
end

function PBEM_InitSpecialMessage()
    if not __PBEM_FN_SPECIALMESSAGE then
        __PBEM_FN_SPECIALMESSAGE = ScenEdit_SpecialMessage
    end
    ScenEdit_SpecialMessage = PBEM_SpecialMessage
end

function PBEM_EndSpecialMessage()
    if __PBEM_FN_SPECIALMESSAGE then
        ScenEdit_SpecialMessage = __PBEM_FN_SPECIALMESSAGE
    end
end

function PBEM_InitScenarioOver()
    if not __PBEM_FN_ENDSCENARIO then
        __PBEM_FN_ENDSCENARIO = ScenEdit_EndScenario
    end
    ScenEdit_EndScenario = PBEM_ScenarioOver
end

function PBEM_EndScenarioOver()
    if __PBEM_FN_ENDSCENARIO then
        ScenEdit_EndScenario = __PBEM_FN_ENDSCENARIO
    end
end

function PBEM_ScenarioOver()
    --clean ourselves up if we haven't already
    if PBEM_NotRunning() then
        PBEM_EndScenarioOver()
        ScenEdit_EndScenario()
        return
    end

    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, awareness='OMNI'})
    PBEM_MirrorSide(PBEM_SIDENAME)
    PBEM_MirrorSideScore()
    local scores = PBEM_ScoreSummary()
    local msg = Message_Header(Localize("END_OF_SCENARIO_HEADER"))..scores..Localize("END_OF_SCENARIO_MESSAGE")
    PBEM_SpecialMessage('playerside', msg, nil, true)
    __PBEM_FN_ENDSCENARIO()

    PBEM_EndAPIReplace()
end

function PBEM_RandomSeed(a)
    StoreNumber('__PBEM_RANDOMSEEDVAL', a)
    PBEM_RANDOM_SEEDVAL = a
end

function PBEM_Random(lower, upper)
    local raw_state = XORSHIFT_32(PBEM_RANDOM_SEEDVAL)
    PBEM_RandomSeed(raw_state)
    local raw_rnd = raw_state / 4294967296

    local rval = 0
    if lower then
        if upper then
            rval = math.floor(1+lower+raw_rnd*(upper-lower))
        else
            rval = math.floor(1+raw_rnd*lower)
        end
    else
        rval = raw_rnd
    end

    if PBEM_NotRunning() then
        --Clean ourselves up if we're still loaded
        --in a non-IKE context
        PBEM_EndRandom()
    end
    return rval
end

function PBEM_InitRandom()
    if not __PBEM_FN_RANDOMSEED then
        __PBEM_FN_RANDOMSEED = math.randomseed
        __PBEM_FN_RANDOM = math.random
    end
    math.randomseed = function(a) end
    math.random = PBEM_Random

    local seed = GetNumber('__PBEM_RANDOMSEEDVAL')
    if seed == 0 then
        seed = os.time() % 4294967296
    end
    PBEM_RandomSeed(seed)
end

function PBEM_EndRandom()
    if __PBEM_FN_RANDOMSEED then
        math.randomseed = __PBEM_FN_RANDOMSEED
    end
    if __PBEM_FN_RANDOM then
        math.random = __PBEM_FN_RANDOM
    end
end
