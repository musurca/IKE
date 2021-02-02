--[[
----------------------------------------------
IKE
02_pbem.lua
----------------------------------------------

This file contains most of the important logic
for the IKE system.

----------------------------------------------
]]--

PBEM_DUMMY_SIDE = 'PBEM'

PBEM_UNITYPES = {
    1, --aircraft
    2, --ship
    3, --submarine
    4, --facility
    7 --satellite
}

function PBEM_StartTimeToUTC()
    local date_str = os.date("!%m.%d.%Y", VP_GetScenario().StartTimeNum)
    local time_str = os.date("!%H.%M.%S", VP_GetScenario().StartTimeNum)
    return {Date=date_str, Time=time_str}
end

function PBEM_CurrentTimeMilitary()
    return os.date("!%m/%d/%Y %H:%M:%S", VP_GetScenario().CurrentTimeNum)
end

function PBEM_ScenarioStartTime()
    return GetNumber("__PBEM_STARTTIME")
end

function PBEM_GetNextTurnStartTime()
    local scenStartTime = VP_GetScenario().StartTimeNum
    local numSides = #PBEM_PLAYABLE_SIDES
    local sideNum = Turn_GetCurSide()
    local turnNumber = Turn_GetTurnNumber()

    return scenStartTime + PBEM_TURN_LENGTH*(turnNumber-1)*numSides + PBEM_TURN_LENGTH*sideNum
end

function PBEM_GetCurTurnStartTime()
    return PBEM_GetNextTurnStartTime() - PBEM_TURN_LENGTH
end

function PBEM_CheckSideSecurity()
    local curPlayerSide = ScenEdit_PlayerSide()
    local scenStartTime = VP_GetScenario().StartTimeNum
    local scenCurTime = ScenEdit_CurrentTime()
    local turnnum = Turn_GetTurnNumber()
    if Turn_GetTurnNumber() > 0 then
        if PBEM_GetNextTurnStartTime() == scenCurTime then
            -- End turn
            Turn_NextSide()
            ScenEdit_PlaySound("radioChirp5.mp3")
            local msg = Message_Header('End of '..curPlayerSide..' Turn '..turnnum)..'Go to <b>File -> Save As...</b>, save this game, and send the save file to the <b>'..Turn_GetCurSideName()..'</b> player via email or another transfer service.<br/><br/><u>IMPORTANT:</u> Do <b>NOT</b> close this window or resume the game before saving, or you will have to replay your turn.'
            ScenEdit_SpecialMessage('playerside', msg)
            PBEM_EndRandom()
        else
            -- Check for funny business
            local timeOffset = scenCurTime - scenStartTime

            if timeOffset % PBEM_TURN_LENGTH ~= 0 then
                local curTurnNumber = (math.floor(timeOffset / PBEM_TURN_LENGTH) % #PBEM_PLAYABLE_SIDES) + 1
                if curPlayerSide ~= PBEM_PLAYABLE_SIDES[curTurnNumber] then
                    PBEM_SelfDestruct()
                end
            end
        end
    else
        -- ending a setup phase
        PBEM_EndSetupPhase()
    end
end

function PBEM_ShowRemainingTime()
    if Turn_GetTurnNumber() == 0 and PBEM_SETUP_PHASE then
        Input_OK("This is the setup phase.")
    else
        local timeLeft = PBEM_GetNextTurnStartTime() - ScenEdit_CurrentTime()
        local timeStrings = {}

        local hrs = math.floor(timeLeft / (60*60))
        local min = math.floor((timeLeft - hrs*60*60) / 60)
        local sec = math.floor(timeLeft - hrs*60*60 - min*60)
        
        Input_OK("Time remaining in your turn: "..PadDigits(hrs)..":"..PadDigits(min)..":"..PadDigits(sec)..".")
    end
end

function PBEM_SideNumberByName(sidename)
    for i=1,#PBEM_PLAYABLE_SIDES do
        if PBEM_PLAYABLE_SIDES[i] == sidename then
            return i
        end
    end
    return 1
end

function PBEM_SetKillRegister(sidenum, kills)
    StoreString("__SIDE_"..tostring(sidenum)..'_LOSSES', kills)
end

function PBEM_GetKillRegister(sidenum)
    return string.sub(GetString("__SIDE_"..tostring(sidenum)..'_LOSSES'), 0)
end

function Message_Header(text)
    return '<br/><hr><br/><center><b>'..text..'</b></center><br/><hr><br/>'
end

function PBEM_RegisterUnitKilled()
    local killed = ScenEdit_UnitX()
    local killtime = PBEM_CurrentTimeMilitary()
    local sidenum = PBEM_SideNumberByName(killed.side)
    local losses = PBEM_GetKillRegister(sidenum)
    local unitname
    if killed.name == killed.classname then
        unitname = killed.name
    else
        unitname = killed.name..' ('..killed.classname..')'
    end
    losses = losses..killtime..' // '..unitname..'<br/>'
    PBEM_SetKillRegister(sidenum, losses)
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

function PBEM_TurnLength()
    return GetNumber('__TURN_LENGTH')
end

function PBEM_ScenarioOver()
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, awareness='OMNI'})
    local scores = PBEM_ScoreSummary()
    local msg = Message_Header('End of Scenario')..scores..'Go to <b>File -> Save As...</b>, save this game, and send the save file to the other players via email or another transfer service.<br/><br/>'
    ScenEdit_SpecialMessage('playerside', msg)
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
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
end

function PBEM_SelfDestruct()
    local sides = VP_GetSides()
    for i=1,#sides do
        StoreString("__SIDE_"..tostring(i).."_PASSWD","")
        ScenEdit_RemoveSide({side=sides[i].name})
    end
    PBEM_EndRandom()
end

function PBEM_ShowTurnIntro()
    local cursidenum = Turn_GetCurSide()
    local turnnum = Turn_GetTurnNumber()
    local lossreport = ""
    if turnnum > 1 or cursidenum > 1 then
        -- show losses from previous turn
        local losses = PBEM_GetKillRegister(cursidenum)
        if losses == '' then
            losses = "None."
        end
        lossreport = '<br/><u>Losses reported:</u><br/><br/>'..losses
    end
    PBEM_SetKillRegister(cursidenum, "")
    ScenEdit_SpecialMessage('playerside', Message_Header(Turn_GetCurSideName()..' Turn '..tostring(turnnum))..lossreport)
end

function PBEM_RandomSeed(a)
    StoreNumber('__PBEM_RANDOMSEEDVAL', a)
end

function PBEM_NextRandomSeed()
    PBEM_RandomSeed(__PBEM_FN_RANDOM(-2147483648, 2147483647))
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

    PBEM_NextRandomSeed()
    return rval
end

function PBEM_InitRandom()
    if not __PBEM_FN_RANDOMSEED then
        __PBEM_FN_RANDOMSEED = math.randomseed
        __PBEM_FN_RANDOM = math.random
    end
    math.randomseed = function(a) end
    math.random = PBEM_Random
    
    __PBEM_FN_RANDOMSEED(GetNumber('__PBEM_RANDOMSEEDVAL'))
    __PBEM_FN_RANDOM()
    __PBEM_FN_RANDOM()
    __PBEM_FN_RANDOM()
    PBEM_NextRandomSeed()
end

function PBEM_EndRandom()
    math.randomseed = __PBEM_FN_RANDOMSEED
    math.random = __PBEM_FN_RANDOM
end

function PBEM_StartTurn()
    -- necessary to load these right away
    PBEM_SETUP_PHASE = PBEM_HasSetupPhase()
    PBEM_TURN_LENGTH = PBEM_TurnLength()
    PBEM_PLAYABLE_SIDES = PBEM_PlayableSides()

    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
    local sidename = Turn_GetCurSideName()
    local turnnum = Turn_GetTurnNumber()
    local curtime = ScenEdit_CurrentTime()

    --see if scenario  is over
    if ScenEdit_GetSideOptions({side=PBEM_DUMMY_SIDE}).awareness == 'Omniscient' then
        local msg = Message_Header("End of Scenario (Turn "..turnnum..')')..PBEM_ScoreSummary()
        ScenEdit_SpecialMessage('playerside', msg)
        return
    end

    if (turnnum == 1 and not PBEM_SETUP_PHASE and curtime == PBEM_GetCurTurnStartTime()) or (turnnum == 0 and PBEM_SETUP_PHASE) then
        -- do initial senario setup if this is the first run
        if Turn_GetCurSide() == 1 then
            PBEM_RandomSeed(os.time())

            if PBEM_OnInitialSetup then
                PBEM_OnInitialSetup()
            end
        end
        PBEM_InitRandom()
        
        -- Enter a password
        local passwordsMatch = false
        local attemptNum = 0
        local pass = ""
        while not passwordsMatch do
            attemptNum = attemptNum + 1
            local msg = ""
            if attemptNum > 1 then
                msg = "Passwords didn\'t match! Please enter your password again:"
            else
                msg = sidename..", please choose a password:"
            end
            pass = Input_String(msg)
            local passcheck = Input_String("Enter password again to confirm:")
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
        PBEM_InitRandom()

        -- Check our password
        local passwordAccepted = false
        while not passwordAccepted do
            local pass = Input_String(sidename..", enter your password to start turn "..turnnum..":")
            if PBEM_CheckPassword(Turn_GetCurSide(), pass) then
                ScenEdit_SetSideOptions({side=sidename, switchto=true})
                passwordAccepted = true
            else
                local choice = ScenEdit_MsgBox("The password was incorrect.", 5)
                if choice ~= 'Retry' then
                    PBEM_SelfDestruct()
                    return
                end
            end
        end
        
        local turnStartTime = PBEM_GetCurTurnStartTime()
        local curTime = ScenEdit_CurrentTime()

        if (PBEM_SETUP_PHASE and turnnum == 1 and curTime == (turnStartTime+#PBEM_PLAYABLE_SIDES)) or (curTime == turnStartTime) then
            PBEM_ShowTurnIntro()
        end
    end
end

function PBEM_StartSetupPhase()
    local sidename = ScenEdit_PlayerSide()
    Input_OK("This is the "..sidename.." setup phase.\n\nLeave the game paused until you've finished setting up your loadouts and missions.\n\nWhen you're done, click Play to end your turn.")
end

function PBEM_EndSetupPhase()
    local sidename = ScenEdit_PlayerSide()
    Turn_NextSide()
    ScenEdit_PlaySound("radioChirp5.mp3")
    local msg = Message_Header('End of '..sidename..' Setup Phase')..'Go to <b>File -> Save As...</b>, save this game, and send the save file to the <b>'..Turn_GetCurSideName()..'</b> player via email or another transfer service.<br/><br/><u>IMPORTANT:</u> Do <b>NOT</b> close this window or resume the game before saving, or you will have to replay your turn.'
    ScenEdit_SpecialMessage('playerside', msg)
    --ScenEdit_SetTime(PBEM_StartTimeToUTC())

    PBEM_EndRandom()
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

