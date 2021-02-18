--[[
----------------------------------------------
IKE
03_pbem.lua
----------------------------------------------

This file contains most of the important logic
for the IKE system.

----------------------------------------------
]]--

PBEM_DUMMY_SIDE = 'PBEM'

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

function PBEM_EndTurn()
    local next_turn_time = PBEM_GetNextTurnStartTime()
    local turn_num = Turn_GetTurnNumber()
    local player_side = PBEM_SIDENAME

    if not PBEM_UNLIMITED_ORDERS then
        ScenEdit_SetScore(PBEM_DUMMY_SIDE, 0, "----------------")
        --remove the dummy sensor unit if it exists
        PBEM_RemoveDummyUnit()
        PBEM_RemoveRTSide(PBEM_DUMMY_SIDE)
    end
    Turn_NextSide()
    ScenEdit_PlaySound("radioChirp5.mp3")
    local msg = Message_Header(Format(Localize("END_OF_TURN_HEADER"), {
        player_side, 
        turn_num
    }))
    msg = msg..Format(Localize("END_OF_TURN_MESSAGE"), {
        Turn_GetCurSideName()
    })
    PBEM_SpecialMessage('playerside', msg, nil, true)
    ScenEdit_SetTime(PBEM_CustomTimeToUTC(next_turn_time)) 

    PBEM_EndAPIReplace()
    PBEM_TURNOVER = true
end

function PBEM_CheckSideSecurity()
    local curPlayerSide = __PBEM_FN_PLAYERSIDE()
    local scenStartTime = VP_GetScenario().StartTimeNum
    local scenCurTime = ScenEdit_CurrentTime()
    local turnnum = Turn_GetTurnNumber()

    if Turn_GetTurnNumber() > 0 then
        if scenCurTime >= PBEM_GetNextTurnStartTime() then
            if not PBEM_TURNOVER then
                PBEM_EndTurn()
            else
                PBEM_SelfDestruct()
                return
            end
        else
            -- Make sure the player isn't trying to modify another side's orders
            local cur_side_check = PBEM_GetCurSideFromTime()
            local cur_side_name = PBEM_PLAYABLE_SIDES[cur_side_check] or "!!CHEATER!!"
            if cur_side_name ~= curPlayerSide and curPlayerSide ~= PBEM_DUMMY_SIDE then
                --probably attempting to cheat
                PBEM_SelfDestruct()
                return
            elseif not PBEM_UNLIMITED_ORDERS then
                -- handle limited orders

                --mirror side score
                local sidescore = ScenEdit_GetScore(PBEM_SIDENAME)
                if ScenEdit_GetScore(PBEM_DUMMY_SIDE) ~= sidescore then
                    ScenEdit_SetScore(PBEM_DUMMY_SIDE, sidescore, PBEM_SIDENAME)
                end
                
                --check for order phase
                local time_check = scenCurTime - PBEM_TURN_START_TIME
                if curPlayerSide ~= PBEM_DUMMY_SIDE then
                    PBEM_EndOrderPhase()
                    -- register unit to trigger contact sharing
                    PBEM_AddDummyUnit()
                    --add special actions to dummy side
                    PBEM_AddRTSide(PBEM_DUMMY_SIDE)
                elseif time_check % PBEM_ORDER_INTERVAL == 0 then
                    -- start giving orders again
                    PBEM_StartOrderPhase((time_check / PBEM_ORDER_INTERVAL) + 1)
                    --remove the dummy sensor unit if it exists
                    PBEM_RemoveDummyUnit()
                    --remove special actions from dummy side
                    PBEM_RemoveRTSide(PBEM_DUMMY_SIDE)
                end
            end
        end
    else
        -- ending a setup phase
        PBEM_EndSetupPhase()
    end

    -- display all special messages at once
    PBEM_FlushSpecialMessages()
end

function PBEM_ShowRemainingTime()
    if Turn_GetTurnNumber() == 0 and PBEM_SETUP_PHASE then
        Input_OK(Localize("SHOW_REMAINING_SETUP"))
    else
        local timeLeft = PBEM_GetNextTurnStartTime() - ScenEdit_CurrentTime()
        local timeStrings = {}

        local hrs = math.floor(timeLeft / (60*60))
        local min = math.floor((timeLeft - hrs*60*60) / 60)
        local sec = math.floor(timeLeft - hrs*60*60 - min*60)
        
        local msg = Format(Localize("SHOW_REMAINING_TIME"), {PadDigits(hrs), PadDigits(min), PadDigits(sec)})
        Input_OK(msg)
    end
end

function PBEM_UserChangePosture()
    local sidelist = ""
    local myside = Turn_GetCurSideName()
    local non_player_sides = {}
    for k,side in ipairs(VP_GetSides()) do
        if side.name ~= myside and side.name ~= PBEM_DUMMY_SIDE then
            table.insert(non_player_sides, side.name)
        end
    end
    for k,sidename in ipairs(non_player_sides) do
        sidelist = sidelist..sidename
        if k ~= #non_player_sides then
            sidelist = sidelist..", "
        end
    end
    local side_input = Input_String(Format(Localize("CHANGE_POSTURE"), {
        sidelist
    }))
    side_input = RStrip(side_input)
    if side_input == "" then
        return
    end
    --match it regardless of case
    local side_to_change = ""
    for k,sidename in ipairs(non_player_sides) do
        local check_a = string.upper(side_input)
        local check_b = string.upper(sidename)
        if check_a == check_b then
            side_to_change = sidename
            break
        end
    end
    if side_to_change == "" then
        Input_OK(Format(Localize("NO_SIDE_FOUND"), {
            side_input
        }))
        return
    end
    local posture_map = {
        ["F"] = "FRIENDLY",
        ["N"] = "NEUTRAL",
        ["U"] = "UNFRIENDLY",
        ["H"] = "HOSTILE"
    }
    local curposture = posture_map[ScenEdit_GetSidePosture(myside, side_to_change)]
    local newposture = Input_String(Format(Localize("SET_POSTURE"), {
        side_to_change,
        curposture
    }))
    newposture = RStrip(string.upper(newposture))
    if newposture == "" then
        return
    end
    local postures = {"FRIENDLY", "NEUTRAL", "UNFRIENDLY", "HOSTILE"}
    if not IsIn(newposture, postures) then
        Input_OK(Format(Localize("NO_POSTURE_FOUND"), {
            newposture
        }))
        return
    end
    ScenEdit_SetSidePosture(myside, side_to_change, string.sub(newposture, 1, 1))
    Input_OK(Format(Localize("POSTURE_IS_SET"), {
        side_to_change,
        newposture
    }))
end

function PBEM_AddRTSide(side)
    ScenEdit_AddSpecialAction({
        ActionNameOrID='PBEM: Change posture towards a side',
        Description="Changes your posture toward a side. Useful if you've accidentally attacked some civilians and don't want them to be hostile anymore.",
        Side=side,
        IsActive=true, 
        IsRepeatable=true,
        ScriptText='PBEM_UserChangePosture()'
    })

    ScenEdit_AddSpecialAction({
        ActionNameOrID='PBEM: Show remaining time in turn',
        Description="Display the remaining time before your PBEM turn ends.",
        Side=side,
        IsActive=true, 
        IsRepeatable=true,
        ScriptText='PBEM_ShowRemainingTime()'
    })
end

function PBEM_RemoveRTSide(side)
    pcall(ScenEdit_SetSpecialAction, {
        ActionNameOrID='PBEM: Show remaining time in turn',
        Side=side,
        mode="remove"
    })
    pcall(ScenEdit_SetSpecialAction, {
        ActionNameOrID='PBEM: Change posture towards a side',
        Side=side,
        mode="remove"
    })
end

function PBEM_SideNumberByName(sidename)
    for i=1,#PBEM_PLAYABLE_SIDES do
        if PBEM_PLAYABLE_SIDES[i] == sidename then
            return i
        end
    end
    return 1
end

function PBEM_SetLossRegister(sidenum, kills)
    StoreString("__SIDE_"..tostring(sidenum)..'_LOSSES', kills)
end

function PBEM_GetLossRegister(sidenum)
    return string.sub(GetString("__SIDE_"..tostring(sidenum)..'_LOSSES'), 0)
end

function Message_Header(text)
    return '<br/><hr><br/><center><b>'..text..'</b></center><br/><hr><br/>'
end

function PBEM_RegisterUnitKilled()
    local killed = ScenEdit_UnitX()
    local killtime = PBEM_CurrentTimeMilitary()

    if not IsIn(killed.side, PBEM_PLAYABLE_SIDES) then
        -- don't report losses
        return
    end

    if killed.side ~= Turn_GetCurSideName() then
        local sidenum = PBEM_SideNumberByName(killed.side)
        local losses = PBEM_GetLossRegister(sidenum)
        local unitname
        if killed.name == killed.classname then
            unitname = killed.name
        else
            unitname = killed.name..' ('..killed.classname..')'
        end
        losses = losses.."<i>"..killtime.."</i> // "..unitname.."<br/>"
        PBEM_SetLossRegister(sidenum, losses)
    end

    --mark loss on the map
    ScenEdit_AddReferencePoint({
        side=killed.side, 
        name=Format(Localize("LOSS_MARKER"), {killed.name}), 
        lat=killed.latitude, 
        lon=killed.longitude, 
        highlighted=true
    })
end

function PBEM_ScoreSummary()
    local scoretxt = ""
    for i=1,#PBEM_PLAYABLE_SIDES do
        local sidename = PBEM_PLAYABLE_SIDES[i]
        local finalscore = ScenEdit_GetScore(sidename)
        scoretxt = scoretxt..'<center><b>'..sidename..':  '..finalscore..'</b></center><br/><br/>'
    end
    return scoretxt
end

function PBEM_HasSetupPhase()
    return GetBoolean("__SCEN_SETUPPHASE")
end

function PBEM_PlayableSides()
    return GetStringArray('__SCEN_PLAYABLESIDES')
end

function PBEM_GetTurnLengths()
    return GetNumberArray("__SCEN_TURN_LENGTHS")
end

function PBEM_TurnLength()
    return PBEM_TURN_LENGTHS[Turn_GetCurSide()]
end

function PBEM_RoundLength()
    local length = 0
    for k,v in ipairs(PBEM_TURN_LENGTHS) do
        length = length + v
    end
    return length
end

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
    if PBEM_TurnLength() == 0 then
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
    if PBEM_TurnLength() == 0 then
        PBEM_EndSpecialMessage()
        ScenEdit_SpecialMessage(side, message, location)
        return
    end

    priority = priority or false
    if not PBEM_MESSAGEQUEUE then
        PBEM_MESSAGEQUEUE = {}
    end
    local side_name = side
    local special_archive = (ScenEdit_CurrentTime() == VP_GetScenario().StartTimeNum)
    --make sure messages are properly delivered
    if side_name == Turn_GetCurSideName() and not special_archive then
        side_name = "playerside"
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
    if PBEM_TurnLength() == 0 then
        PBEM_EndScenarioOver()
        ScenEdit_EndScenario()
        return
    end

    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, awareness='OMNI'})
    PBEM_MirrorSide(PBEM_SIDENAME)
    local scores = PBEM_ScoreSummary()
    local msg = Message_Header(Localize("END_OF_SCENARIO_HEADER"))..scores..Localize("END_OF_SCENARIO_MESSAGE")
    PBEM_SpecialMessage('playerside', msg, nil, true)
    __PBEM_FN_ENDSCENARIO()

    PBEM_EndAPIReplace()
end

function PBEM_SetPassword(sidenum, password)
    StoreString("__SIDE_"..tostring(sidenum).."_PASSWD", md5.Calc(password))
end

function PBEM_CheckPassword(sidenum, password)
    local hash = GetString("__SIDE_"..tostring(sidenum).."_PASSWD")
    return hash == md5.Calc(password)
end

function PBEM_EventExists(eventName)
    local events = ScenEdit_GetEvents()
    for i=1,#events do
        local event = events[i]
        if event.name == eventName then
            return true
        end
    end
    return false
end

function Turn_GetTurnNumber()
    return GetNumber('__TURN_CURNUM')
end

function Turn_NextTurnNumber()
    StoreNumber('__TURN_CURNUM', Turn_GetTurnNumber()+1)
end

function Turn_GetCurSide()
    return GetNumber('__TURN_CURSIDE')
end

function Turn_GetCurSideName()
    return PBEM_PLAYABLE_SIDES[Turn_GetCurSide()]
end

function Turn_SetCurSide(sidenum)
    StoreNumber('__TURN_CURSIDE', sidenum)
end

function Turn_NextSide()
    local curSide = Turn_GetCurSide() - 1
    curSide = ((1 + curSide) % #PBEM_PLAYABLE_SIDES) + 1
    if curSide == 1 then
        Turn_NextTurnNumber()
    end
    Turn_SetCurSide(curSide)
    PBEM_ClearPostures()
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
end

function PBEM_SelfDestruct()
    local sides = VP_GetSides()
    for i=1,#sides do
        StoreString("__SIDE_"..tostring(i).."_PASSWD","")
        ScenEdit_RemoveSide({side=sides[i].name})
    end
    PBEM_EndAPIReplace()
end

function PBEM_ShowTurnIntro()
    local cursidenum = Turn_GetCurSide()
    local turnnum = Turn_GetTurnNumber()
    local lossreport = ""
    -- show losses from previous turn
    local losses = PBEM_GetLossRegister(cursidenum)
    if losses ~= "" then
        lossreport = "<br/><u>"..Localize("LOSSES_REPORTED").."</u><br/><br/>"..losses
        PBEM_SetLossRegister(cursidenum, "")
    end
    -- get any special messages we missed
    local prev_msgs = GetString("__SCEN_PREVMSGS_"..cursidenum)
    if prev_msgs ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("MESSAGES_RECEIVED").."</u><br/>"..prev_msgs
        StoreString("__SCEN_PREVMSGS_"..cursidenum, "")
    end
    local msg_header
    local turn_len_min = math.floor(PBEM_TURN_LENGTH / 60)
    if PBEM_UNLIMITED_ORDERS then
        msg_header = Format(Localize("START_OF_TURN_HEADER"), {
            PBEM_SIDENAME, 
            turnnum,
            turn_len_min
        })
    else
        local orderNumStr
        if PBEM_ORDER_INTERVAL == PBEM_TURN_LENGTH then
            orderNumStr = ""
        else
            orderNumStr = Format(Localize("ORDER_PHASE_DIVIDER"), {
                "1",
                math.floor(PBEM_TURN_LENGTH / PBEM_ORDER_INTERVAL)
            })
        end
        msg_header = Format(Localize("START_ORDER_HEADER"), {
            PBEM_SIDENAME,
            tostring(turnnum),
            turn_len_min,
            orderNumStr
        })
    end
    local msg = Message_Header(msg_header)
    if not PBEM_UNLIMITED_ORDERS then
        msg = msg..Localize("START_ORDER_MESSAGE").."<br/><br/>"
    end
    msg = msg..lossreport
    PBEM_SpecialMessage('playerside', msg, nil, true)
end

function PBEM_RandomSeed(a)
    StoreNumber('__PBEM_RANDOMSEEDVAL', a)
end

function PBEM_NextRandomSeed()
    local newseed = -2147483646+2*(__PBEM_FN_RANDOM()*2147483646)
    PBEM_RandomSeed(newseed)
end

function PBEM_Random(lower, upper)
    local rval = 0
    if lower then
        if upper then
            rval = __PBEM_FN_RANDOM(lower, upper)
        else
            rval = __PBEM_FN_RANDOM(lower)
        end
    else
        rval = __PBEM_FN_RANDOM()
    end

    if PBEM_TurnLength() == 0 then
        --Clean ourselves up if we're still loaded
        --in a non-IKE context
        PBEM_EndRandom()
    else
        PBEM_NextRandomSeed()
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
        PBEM_RandomSeed(os.time())
        seed = GetNumber('__PBEM_RANDOMSEEDVAL')
    end
    __PBEM_FN_RANDOMSEED(seed)
    __PBEM_FN_RANDOM()
    __PBEM_FN_RANDOM()
    __PBEM_FN_RANDOM()
    PBEM_NextRandomSeed()
end

function PBEM_EndRandom()
    if __PBEM_FN_RANDOMSEED then
        math.randomseed = __PBEM_FN_RANDOMSEED
    end
    if __PBEM_FN_RANDOM then
        math.random = __PBEM_FN_RANDOM
    end
end

function PBEM_OrdersUnlimited()
    return GetBoolean('__SCEN_UNLIMITEDORDERS')
end

function PBEM_OrderPhases()
    return GetNumberArray("__SCEN_ORDERINTERVAL")
end

function PBEM_OrderInterval()
    return math.floor(PBEM_TURN_LENGTH / PBEM_ORDER_PHASES[Turn_GetCurSide()])
end

function PBEM_MirrorSide(sidename)
    ScenEdit_SetSidePosture(sidename, PBEM_DUMMY_SIDE, "F")
    ScenEdit_SetSidePosture(PBEM_DUMMY_SIDE, sidename, "F")
    local sides = VP_GetSides()
    for i=1,#sides do
        local side = sides[i].name
        if sidename ~= side then
            local posture = ScenEdit_GetSidePosture(sidename, side)
            ScenEdit_SetSidePosture(PBEM_DUMMY_SIDE, side, posture)
        end
    end
end

function PBEM_ClearPostures()
    ScenEdit_SetSidePosture(PBEM_SIDENAME, PBEM_DUMMY_SIDE, "N")
    ScenEdit_SetSidePosture(PBEM_DUMMY_SIDE, PBEM_SIDENAME, "N")
    local sides = VP_GetSides()
    for i=1,#sides do
        local side = sides[i].name
        if side ~= PBEM_DUMMY_SIDE then
            ScenEdit_SetSidePosture(PBEM_DUMMY_SIDE, side, "N")
            ScenEdit_SetSidePosture(side, PBEM_DUMMY_SIDE, "N")
        end
    end
end

function PBEM_DummyUnitExists()
    local guid
    if not PBEM_DUMMY_GUID then
        guid = GetString("__PBEM_DUMMYGUID")
        PBEM_DUMMY_GUID = guid
        if guid ~= "" then
            return true
        end
    elseif PBEM_DUMMY_GUID ~= "" then
        return true
    end
    return false
end

function PBEM_AddDummyUnit()
    if not PBEM_DummyUnitExists() then
        --adds a dummy unit so allies transmit contacts
        local dummy = ScenEdit_AddUnit({
            side=PBEM_DUMMY_SIDE, 
            name="",
            type="FACILITY",
            dbid=174, 
            latitude=-89,
            longitude=0,
        })
        StoreString("__PBEM_DUMMYGUID", dummy.guid)
        PBEM_DUMMY_GUID = dummy.guid
    end
end

function PBEM_RemoveDummyUnit()
    if PBEM_DummyUnitExists() then
        pcall(ScenEdit_DeleteUnit, {
            side=PBEM_DUMMY_SIDE, 
            guid=PBEM_DUMMY_GUID
        })
        PBEM_DUMMY_GUID = ""
        StoreString("__PBEM_DUMMYGUID", "")
    end
end

function PBEM_EndOrderPhase()
    PBEM_MirrorSide(PBEM_SIDENAME)
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
end

function PBEM_StartOrderPhase(phase_num)
    ScenEdit_SetSideOptions({side=PBEM_SIDENAME, switchto=true})
    local turn_len_min = math.floor((PBEM_GetNextTurnStartTime() - ScenEdit_CurrentTime()) / 60)
    local phase_str = Format(Localize("ORDER_PHASE_DIVIDER"), {
        math.floor(phase_num),
        math.floor(PBEM_TURN_LENGTH / PBEM_ORDER_INTERVAL)
    })
    local msg = Message_Header(
        Format(
            Localize("NEXT_ORDER_HEADER"), {
                PBEM_SIDENAME,
                Turn_GetTurnNumber(),
                turn_len_min,
                phase_str
            }
        )
    )..Localize("START_ORDER_MESSAGE")
    PBEM_SpecialMessage('playerside', msg, nil, true)
end

function PBEM_InitScenGlobals()
    PBEM_TURNOVER = false
    PBEM_SETUP_PHASE = PBEM_HasSetupPhase()
    PBEM_TURN_LENGTHS = PBEM_GetTurnLengths()
    PBEM_TURN_LENGTH = PBEM_TurnLength()
    PBEM_ROUND_LENGTH = PBEM_RoundLength()
    PBEM_PLAYABLE_SIDES = PBEM_PlayableSides()
    PBEM_UNLIMITED_ORDERS = PBEM_OrdersUnlimited()
    if not PBEM_UNLIMITED_ORDERS then
        PBEM_ORDER_PHASES = PBEM_OrderPhases()
        PBEM_ORDER_INTERVAL = PBEM_OrderInterval()
    end
    PBEM_SIDENAME = Turn_GetCurSideName()
    PBEM_TURN_START_TIME = PBEM_GetCurTurnStartTime()
end

function PBEM_StartTurn()
    -- necessary to load these right away
    PBEM_InitScenGlobals()
    
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
    local sidename = PBEM_SIDENAME
    local turnnum = Turn_GetTurnNumber()
    local curtime = ScenEdit_CurrentTime()

    --see if scenario  is over
    if ScenEdit_GetSideOptions({side=PBEM_DUMMY_SIDE}).awareness == 'Omniscient' then
        local msg = Message_Header(Format(Localize("END_OF_SCENARIO_SUMMARY"), {turnnum}))..PBEM_ScoreSummary()
        ScenEdit_SpecialMessage('playerside', msg)
        return
    end

    PBEM_InitAPIReplace()

    if tonumber(GetBuildNumber()) >= 1147.17 then
        if VP_GetScenario().GameMode == 2 and GetBoolean("__SCEN_PREVENTEDITOR") then
            --can't open a PBEM session in Editor mode until it's over
            Input_OK(Localize("NO_EDITOR_MODE"))
            PBEM_SelfDestruct()
            return
        end
    end

    if (turnnum == 1 and not PBEM_SETUP_PHASE and curtime == PBEM_TURN_START_TIME) or (turnnum == 0 and PBEM_SETUP_PHASE) then
        -- do initial senario setup if this is the first run
        if Turn_GetCurSide() == 1 then
            if PBEM_OnInitialSetup then
                PBEM_OnInitialSetup()
            end
        end

        -- Enter a password
        local passwordsMatch = false
        local attemptNum = 0
        local pass = ""
        while not passwordsMatch do
            attemptNum = attemptNum + 1
            local msg = ""
            if attemptNum > 1 then
                msg = Localize("PASSWORDS_DIDNT_MATCH")
            else
                msg = Format(Localize("CHOOSE_PASSWORD"), {sidename})
            end
            pass = Input_String(msg)
            local passcheck = Input_String(Localize("CONFIRM_PASSWORD"))
            if pass == passcheck then
                passwordsMatch = true
            end
        end
        PBEM_SetPassword(Turn_GetCurSide(), pass)
        ScenEdit_SetSideOptions({side=sidename, switchto=true})

        if turnnum == 0 and PBEM_SETUP_PHASE then
            PBEM_StartSetupPhase()
        else
            PBEM_ShowTurnIntro()
        end
    else
        -- Check our password
        local passwordAccepted = false
        while not passwordAccepted do
            local pass = Input_String(Format(Localize("ENTER_PASSWORD"), {sidename, turnnum}))
            if PBEM_CheckPassword(Turn_GetCurSide(), pass) then
                ScenEdit_SetSideOptions({side=sidename, switchto=true})
                passwordAccepted = true
            else
                local choice = ScenEdit_MsgBox(Localize("WRONG_PASSWORD"), 5)
                if choice ~= 'Retry' then
                    PBEM_SelfDestruct()
                    return
                end
            end
        end
        
        local turnStartTime = PBEM_TURN_START_TIME
        local curTime = ScenEdit_CurrentTime()

        if curTime == turnStartTime then
            PBEM_ShowTurnIntro()
        end
    end

    PBEM_FlushSpecialMessages()
end

function PBEM_StartSetupPhase()
    local msg = Format(Localize("SETUP_PHASE_INTRO"), {
        Turn_GetCurSideName()
    })
    Input_OK(msg)
end

function PBEM_EndSetupPhase()
    --save current side before advancing
    local sidename = Turn_GetCurSideName()
    Turn_NextSide()
    ScenEdit_PlaySound("radioChirp5.mp3")
    local msg = Message_Header(Format(Localize("END_OF_SETUP_HEADER"), {
        sidename
    }))..Format(Localize("END_OF_TURN_MESSAGE"), {
        Turn_GetCurSideName() -- next side
    })
    PBEM_SpecialMessage('playerside', msg, nil, true)
    ScenEdit_SetTime(PBEM_StartTimeToUTC())

    PBEM_EndAPIReplace()
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

