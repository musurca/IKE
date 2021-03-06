--[[
----------------------------------------------
IKE
pbem_main.lua
----------------------------------------------

This file contains most of the important logic
for the IKE system.

----------------------------------------------
]]--

IKE_VERSION = "1.31"

PBEM_DUMMY_SIDE = '-----------'

function PBEM_DoInitialSetup()
    if ScenEdit_GetKeyValue("PBEM_INITIALSETUP") == "1" then
        if PBEM_OnInitialSetup then
            pcall(PBEM_OnInitialSetup)
        end
    end
end

function PBEM_NotRunning()
    --returns true if we're not running IKE anymore
    return Turn_GetCurSide() == 0
end

function PBEM_SideNumberByName(sidename)
    for i=1,#PBEM_PLAYABLE_SIDES do
        if PBEM_PLAYABLE_SIDES[i] == sidename then
            return i
        end
    end
    return 1
end

function PBEM_HasSetupPhase()
    return GetBoolean("__SCEN_SETUPPHASE")
end

function PBEM_PlayableSides()
    return GetStringArray('__SCEN_PLAYABLESIDES')
end

function PBEM_TurnLength()
    return GetNumber("__SCEN_TURN_LENGTH")
end

function PBEM_RoundLength()
    return PBEM_ROUND_LENGTH
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

function PBEM_InitScenGlobals()
    PBEM_TURNOVER = 0
    PBEM_SETUP_PHASE = PBEM_HasSetupPhase()
    PBEM_TURN_LENGTH = PBEM_TurnLength()
    PBEM_PLAYABLE_SIDES = PBEM_PlayableSides()
    PBEM_ROUND_LENGTH = PBEM_TURN_LENGTH * #PBEM_PLAYABLE_SIDES
    PBEM_UNLIMITED_ORDERS = PBEM_OrdersUnlimited()
    if not PBEM_UNLIMITED_ORDERS then
        PBEM_ORDER_PHASES = PBEM_OrderPhases()
        PBEM_ORDER_INTERVAL = PBEM_OrderInterval()
    end
    PBEM_SIDENAME = Turn_GetCurSideName()
    PBEM_TURN_START_TIME = PBEM_GetCurTurnStartTime()

    --Retrieve any scheduled messages
    PBEM_PrecacheScheduledMessages()
end

function PBEM_StartTurn()
    -- necessary to load these right away
    PBEM_InitScenGlobals()
    
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
    local turnnum = Turn_GetTurnNumber()
    local curtime = ScenEdit_CurrentTime()

    --see if scenario  is over
    if ScenEdit_GetSideOptions({side=PBEM_DUMMY_SIDE}).awareness == 'Omniscient' then
        local msg = Message_Header(Format(Localize("END_OF_SCENARIO_SUMMARY"), {turnnum}))..PBEM_ScoreSummary()
        ScenEdit_SpecialMessage('playerside', msg)
        return
    end

    -- set up CMO API replacements
    PBEM_InitAPIReplace()

    -- prohibit excessively old clients
    if tonumber(GetBuildNumber()) < 1147.17 then
        Input_OK(Format(Localize("VERSION_TOO_OLD"), {GetBuildNumber()}))
        PBEM_SelfDestruct()
        return
    end

    --check for editor mode prohibition
    if VP_GetScenario().GameMode == 2 and GetBoolean("__SCEN_PREVENTEDITOR") then
        --can't open a PBEM session in Editor mode until it's over
        Input_OK(Localize("NO_EDITOR_MODE"))
        PBEM_SelfDestruct()
        return
    end

    if (turnnum == 1 and not PBEM_SETUP_PHASE and curtime == PBEM_TURN_START_TIME) or (turnnum == 0 and PBEM_SETUP_PHASE) then
        -- do initial senario setup if this is the first run
        if Turn_GetCurSide() == 1 then
            PBEM_SetHostBuildNumber()
            PBEM_UserCheckSettings()
            PBEM_DoInitialSetup()
        elseif not PBEM_CheckHostBuildNumber() then
            -- version mismatch
            PBEM_SelfDestruct()
            return
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
                msg = Format(Localize("CHOOSE_PASSWORD"), {
                    PBEM_SIDENAME
                })
            end
            pass = Input_String(msg)
            local passcheck = Input_String(Localize("CONFIRM_PASSWORD"))
            if pass == passcheck then
                passwordsMatch = true
            end
        end
        PBEM_SetPassword(Turn_GetCurSide(), pass)
        ScenEdit_SetSideOptions({
            side=PBEM_SIDENAME, 
            switchto=true
        })

        if turnnum == 0 and PBEM_SETUP_PHASE then
            PBEM_StartSetupPhase()
        else
            PBEM_ShowTurnIntro()
        end
    else
        if not PBEM_CheckHostBuildNumber() then
            -- version mismatch
            PBEM_SelfDestruct()
            return
        end

        -- Check our password
        local passwordAccepted = false
        while not passwordAccepted do
            local pass = Input_String(Format(Localize("ENTER_PASSWORD"), {
                PBEM_SIDENAME, 
                turnnum
            }))
            if PBEM_CheckPassword(Turn_GetCurSide(), pass) then
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
        local time_check = curTime - turnStartTime
        
        if PBEM_UNLIMITED_ORDERS then
            ScenEdit_SetSideOptions({
                side=PBEM_SIDENAME, 
                switchto=true
            })
        else
            if time_check % PBEM_ORDER_INTERVAL == 0 then
                if curTime > turnStartTime then
                    --remind us what order phase we were in
                    PBEM_StartOrderPhase()
                else
                    ScenEdit_SetSideOptions({
                        side=PBEM_SIDENAME, 
                        switchto=true
                    })
                end
            else
                -- resume order phase in the middle
                PBEM_EndOrderPhase()
                PBEM_ShowOrderPhase(true)
            end
        end

        if curTime == turnStartTime then
            PBEM_ShowTurnIntro()
        end
    end

    PBEM_FlushSpecialMessages()
end

function PBEM_UpdateTick()
    local curPlayerSide = __PBEM_FN_PLAYERSIDE()
    local scenStartTime = VP_GetScenario().StartTimeNum
    local scenCurTime = ScenEdit_CurrentTime()
    local turnnum = Turn_GetTurnNumber()

    if Turn_GetTurnNumber() > 0 then
        if scenCurTime >= PBEM_GetNextTurnStartTime() then
            if PBEM_TURNOVER < 1 then
                PBEM_EndTurn()
            elseif PBEM_TURNOVER < 2 then
                -- safety net
                ScenEdit_SetTime(PBEM_CustomTimeToUTC(PBEM_GetCurTurnStartTime()))
                PBEM_TURNOVER = PBEM_TURNOVER + 1
                return
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

                --mirror side score and contact postures
                PBEM_MirrorSideScore()
                PBEM_MirrorContactPostures()
                
                --check for order phase
                local time_check = scenCurTime - PBEM_TURN_START_TIME
                if curPlayerSide ~= PBEM_DUMMY_SIDE then
                    -- register unit to trigger contact sharing
                    PBEM_AddDummyUnit()
                    --add special actions to dummy side
                    PBEM_AddRTSide(PBEM_DUMMY_SIDE)
                    --switch to dummy side
                    PBEM_EndOrderPhase()
                elseif time_check % PBEM_ORDER_INTERVAL == 0 then
                    -- start giving orders again
                    PBEM_StartOrderPhase()
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

    -- check for and deliver any scheduled messages
    PBEM_CheckScheduledMessages()

    -- display all special messages at once
    PBEM_FlushSpecialMessages()
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
    PBEM_TURNOVER = 1
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

