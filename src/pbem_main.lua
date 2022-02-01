--[[
----------------------------------------------
IKE
pbem_main.lua
----------------------------------------------

This file contains most of the important logic
for the IKE system.

----------------------------------------------
]]--

IKE_VERSION = "1.51"
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

function PBEM_HasVariableTurnLengths()
    return GetBoolean("__SCEN_VAR_TURN_LENGTHS")
end

function PBEM_SetTurnLength(len)
    StoreNumber("__SCEN_TURN_LENGTH", len)
    PBEM_TURN_LENGTH = len
    PBEM_ORDER_INTERVAL = PBEM_OrderInterval()
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
    PBEM_SETUP_PHASE = PBEM_HasSetupPhase()
    PBEM_TURN_LENGTH = PBEM_TurnLength()
    PBEM_PLAYABLE_SIDES = PBEM_PlayableSides()
    PBEM_ROUND_LENGTH = PBEM_TURN_LENGTH * #PBEM_PLAYABLE_SIDES
    PBEM_ORDER_PHASES = PBEM_OrderPhases()
    PBEM_ORDER_INTERVAL = PBEM_OrderInterval()
    PBEM_SIDENAME = Turn_GetCurSideName()
    PBEM_TURN_START_TIME = PBEM_GetCurTurnStartTime()

    --Retrieve any scheduled messages
    PBEM_PrecacheScheduledMessages()
end

function PBEM_StartTurn()
    local scen = VP_GetScenario()
    --check for editor mode prohibition
    if scen.GameMode == 2 and GetBoolean("__SCEN_PREVENTEDITOR") then
        --can't open a PBEM session in Editor mode
        Input_OK(Localize("NO_EDITOR_MODE"))
        PBEM_SelfDestruct()
        return
    end

    -- necessary to load these right away
    PBEM_InitScenGlobals()
    
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
    local turnnum = Turn_GetTurnNumber()

    -- set up CMO API replacements
    PBEM_InitAPIReplace()

    --see if scenario is over
    local time_elapsed = scen.CurrentTimeNum - scen.StartTimeNum
    if (GetBoolean("PBEM_MATCHOVER") == true) or (time_elapsed >= scen.DurationNum) then
        ScenEdit_EndScenario()
        return
    end

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

    local side_num = Turn_GetCurSide()
    local side_init = "PBEM_SIDE_INITIALIZED_"..side_num
    local is_first_init = GetBoolean(side_init)
    if is_first_init == false then
        --set the language for this player
        PBEM_SetLocale()

        if side_num == 1 then
            -- do initial scenario setup if this is the first run
            PBEM_SetHostBuildNumber()
            PBEM_UserCheckSettings()
            PBEM_DoInitialSetup()
        elseif not PBEM_CheckHostBuildNumber() then
            -- version mismatch
            PBEM_SelfDestruct()
            return
        end

        -- add special actions after locale is set
        PBEM_AddRTSide(PBEM_SIDENAME)
        if PBEM_HasVariableTurnLengths() then
            -- add action to enter tactical time
            PBEM_AddActionTacticalTimeSide(PBEM_SIDENAME)
        end

        -- Enter a password
        PBEM_EnterPassword()

        ScenEdit_SetSideOptions({
            side=PBEM_SIDENAME,
            switchto=true
        })

        if PBEM_HasVariableTurnLengths() then
            Input_OK(Localize("VARIABLE_TIME_WARNING"))
        end

        StoreBoolean(side_init, true)
    else
        -- side already initialized
        if not PBEM_CheckHostBuildNumber() then
            -- version mismatch
            PBEM_SelfDestruct()
            return
        end

        -- Verify our password
        if PBEM_VerifyPassword() == false then
            PBEM_SelfDestruct()
            return
        end
        
        -- First, see if other player has offered a draw
        if PBEM_CheckDraw() then
            ScenEdit_EndScenario()
            return
        end
    end

    if turnnum == 0 then
        if is_first_init == true then
            ScenEdit_SetSideOptions({
                side=PBEM_SIDENAME,
                switchto=true
            })
        end

        -- start setup phase
        PBEM_StartSetupPhase()
    else
        -- start/resume normal turn
        local turnStartTime = PBEM_TURN_START_TIME
        local nextTurnStartTime = PBEM_GetNextTurnStartTime()
        local curTime = ScenEdit_CurrentTime()
        local time_check = curTime - turnStartTime

        if (time_check % PBEM_ORDER_INTERVAL == 0) or (curTime == (nextTurnStartTime-1)) then
            if curTime > turnStartTime then
                --remind us what order phase we were in
                PBEM_SwitchOrderPhase()
            else
                -- turn start
                ScenEdit_SetSideOptions({
                    side=PBEM_SIDENAME,
                    switchto=true
                })

                -- reset flag to guard against running turn after end
                StoreNumber("PBEM_TURNOVER", 0)

                -- set event handler for next action phase
                PBEM_MarkNextActionPhase()

                -- show the turn intro
                PBEM_ShowTurnIntro()
            end
        else
            -- resume order phase in the middle
            PBEM_EndOrderPhase()
            PBEM_ShowOrderPhase(true)
        end
    end

    PBEM_FlushSpecialMessages()
end

function PBEM_UpdateTick()
    -- if in setup phase, end it
    local turnnum = Turn_GetTurnNumber()
    if turnnum == 0 then
        PBEM_EndSetupPhase()
        return
    end

    -- emergency check against turn overrun in highest time compression
    local turnover_num = GetNumber("PBEM_TURNOVER")
    if turnover_num > 0 then
        if turnover_num < 2 then
            -- if within overrun threshold, reset to turn end time
            turnover_num = turnover_num + 1
            ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
            ScenEdit_SpecialMessage("playerside", GetString("PBEM_ENDTURN_MSG"))
            StoreNumber("PBEM_TURNOVER", turnover_num)

            ScenEdit_SetTime(
                PBEM_CustomTimeToUTC(
                    GetNumber("__CUR_TURN_TIME")
                )
            )
            return
        else
            Input_OK(Localize("FATALERROR_CORRUPT"))
            PBEM_SelfDestruct()
            return
        end
    end

    -- check if time has elapsed and scenario is over
    local scen = VP_GetScenario()
    local time_elapsed = scen.CurrentTimeNum - scen.StartTimeNum
    if (GetBoolean("PBEM_MATCHOVER") == true) or (time_elapsed >= scen.DurationNum) then
        ScenEdit_EndScenario()
        return
    end

    -- Make sure the player isn't trying to play another side
    local curPlayerSide = __PBEM_FN_PLAYERSIDE()
    local dummy_side = PBEM_DummySideName()
    local cur_side_name = PBEM_SIDENAME
    if cur_side_name ~= curPlayerSide and curPlayerSide ~= dummy_side and curPlayerSide ~= PBEM_DUMMY_SIDE then
        --probably attempting to cheat
        Input_OK(Localize("FATALERROR_CORRUPT"))
        PBEM_SelfDestruct()
        return
    end

    --mirror side score and contact postures
    PBEM_MirrorSideScore()
    PBEM_MirrorContactPostures()

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
    StoreString("PBEM_ENDTURN_MSG", msg)
    StoreNumber("__CUR_TURN_TIME", next_turn_time)
    PBEM_FlushSpecialMessages()

    ScenEdit_SetTime(
        PBEM_CustomTimeToUTC(next_turn_time)
    )

    -- increase turn overrun threshold
    StoreNumber("PBEM_TURNOVER", 1)

    PBEM_EndAPIReplace()
end

function PBEM_StartSetupPhase()
    -- show setup phase intro
    local msg = Format(Localize("SETUP_PHASE_INTRO"), {
        Turn_GetCurSideName()
    })
    Input_OK(msg)
end

function PBEM_EndSetupPhase()
    --save current side before advancing
    local sidename = Turn_GetCurSideName()

    -- if handler registered, run it
    if ScenEdit_GetKeyValue("PBEM_SETUP_END_EVENT") == "1" then
        if PBEM_OnSetupPhaseEnd then
            pcall(PBEM_OnSetupPhaseEnd, sidename)
        end
    end

    Turn_NextSide()
    ScenEdit_PlaySound("radioChirp5.mp3")
    local msg = Message_Header(Format(Localize("END_OF_SETUP_HEADER"), {
        sidename
    }))..Format(Localize("END_OF_TURN_MESSAGE"), {
        Turn_GetCurSideName() -- next side
    })
    PBEM_SpecialMessage('playerside', msg, nil, true)
    PBEM_FlushSpecialMessages()
    ScenEdit_SetTime(PBEM_StartTimeToUTC())

    PBEM_EndAPIReplace()
end
