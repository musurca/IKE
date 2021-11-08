--[[
----------------------------------------------
IKE
pbem_main.lua
----------------------------------------------

This file contains most of the important logic
for the IKE system.

----------------------------------------------
]]--

IKE_VERSION = "1.41"
IKE_MIN_ALLOWED_BUILD_MAJOR = 1147
IKE_MIN_ALLOWED_BUILD_MINOR = 34

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
    --check for editor mode prohibition
    if VP_GetScenario().GameMode == 2 and GetBoolean("__SCEN_PREVENTEDITOR") then
        --can't open a PBEM session in Editor mode
        Input_OK(Localize("NO_EDITOR_MODE"))
        PBEM_SelfDestruct()
        return
    end

    -- necessary to load these right away
    PBEM_InitScenGlobals()
    
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
    local turnnum = Turn_GetTurnNumber()
    local curtime = ScenEdit_CurrentTime()

    --see if scenario is over
    if GetBoolean("PBEM_MATCHOVER") == true then
        StoreBoolean("PBEM_MATCHOVER", false)
        PBEM_ScenarioOver()
        PBEM_FlushSpecialMessages()
        return
    end

    -- set up CMO API replacements
    PBEM_InitAPIReplace()

    -- prohibit excessively old clients
    local buildnum_string = GetBuildNumber()
    local version_div_index = string.find(buildnum_string, "%.")
    local cmo_version_major = tonumber(
        string.sub(buildnum_string, 1, version_div_index - 1)
    )
    local cmo_version_minor = tonumber(
        string.sub(buildnum_string, version_div_index + 1, string.len(buildnum_string) )
    )
    local too_old = false
    if cmo_version_major < IKE_MIN_ALLOWED_BUILD_MAJOR then
        too_old = true
    elseif cmo_version_major == IKE_MIN_ALLOWED_BUILD_MAJOR then
        if cmo_version_minor < IKE_MIN_ALLOWED_BUILD_MINOR then
            too_old = true
        end
    end
    if too_old then
        Input_OK(Format(Localize("VERSION_TOO_OLD"), {
            GetBuildNumber(),
            tostring(IKE_MIN_ALLOWED_BUILD_MAJOR).."."..tostring(IKE_MIN_ALLOWED_BUILD_MINOR)
        }))
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
        local nextTurnStartTime = PBEM_GetNextTurnStartTime()
        local curTime = ScenEdit_CurrentTime()
        local time_check = curTime - turnStartTime
        
        if PBEM_UNLIMITED_ORDERS then
            ScenEdit_SetSideOptions({
                side=PBEM_SIDENAME,
                switchto=true
            })
        else
            if (time_check % PBEM_ORDER_INTERVAL == 0) or (curTime == (nextTurnStartTime-1)) then
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
    local scenCurTime = ScenEdit_CurrentTime()
    local turnnum = Turn_GetTurnNumber()
    local nextTurnStartTime = PBEM_GetNextTurnStartTime()

    if GetBoolean("PBEM_MATCHOVER") == true then
        PBEM_SpecialMessage('playerside', Message_Header(Localize("END_OF_SCENARIO_HEADER")))
        PBEM_FlushSpecialMessages()
        return
    end

    if turnnum > 0 then
        if scenCurTime >= nextTurnStartTime then
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
            local dummy_side = PBEM_DummySideName()
            local cur_side_check = PBEM_GetCurSideFromTime()
            local cur_side_name = PBEM_PLAYABLE_SIDES[cur_side_check] or "!!CHEATER!!"
            if cur_side_name ~= curPlayerSide and curPlayerSide ~= dummy_side and curPlayerSide ~= PBEM_DUMMY_SIDE then
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
                if curPlayerSide ~= dummy_side then
                    --make sure the dummy side has no RPs
                    PBEM_WipeRPs()
                    --switch to dummy side
                    PBEM_EndOrderPhase()
                elseif (time_check % PBEM_ORDER_INTERVAL == 0) or (scenCurTime == (nextTurnStartTime-1)) then
                    --transfer any temporary RPs to the correct side
                    PBEM_TransferRPs()
                    -- start giving orders again
                    PBEM_StartOrderPhase()
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
