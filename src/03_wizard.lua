--[[
----------------------------------------------
IKE
03_wizard.lua
----------------------------------------------

This source file contains the IKE Wizard that 
sets up a scenario for PBEM play without 
requiring the author to write any additional
code.

----------------------------------------------
]]--

PBEM_INTRO_MSG = [[Welcome to IKE v1.1! This tool adds PBEM/hotseat play to any Command: Modern Operations scenario.

Running this tool cannot be undone. Have you saved a backup of this scenario?]]

PBEM_LAST_MSG = [[Success! Your PBEM/hotseat scenario has been initialized. Go to FILE -> SAVE AS... to save it under a new name. It will be ready to play when next loaded.

(If you're planning to publish it to the Steam Workshop, you should do it now, before you close this scenario.)

Thanks for using IKE!]]

function PBEM_Init()
    --wizard intro
    if not Input_YesNo(PBEM_INTRO_MSG) then
        Input_OK("Please save a backup first, then RUN this tool again.")
        return
    end
    -- length of turn
    local turnLength = Input_Number("Enter the desired TURN LENGTH in minutes:")
    if not turnLength then
        return
    end
    turnLength = math.floor(turnLength)
    --designate playable sides
    local sides = VP_GetSides()
    local playableSides = {}
    for i=1,#sides do
        if Input_YesNo("Should the "..sides[i].name.." side be PLAYABLE?") then
            table.insert(playableSides, sides[i].name)
        end
    end
    --turn order
    local order_set = false
    while not order_set do
        for i=1,#playableSides do
            if Input_YesNo("Should the "..playableSides[i].." side go FIRST?") then
                local temp_side = playableSides[1]
                playableSides[1] = playableSides[i]
                playableSides[i] = temp_side
                order_set = true
                break
            end
        end
    end
    -- clear missions if desired
    for i=1,#playableSides do
        local sname = playableSides[i]
        for j=1, #sides do
            local side = sides[j]
            if side.name == sname then
                if #side.missions > 0 then
                    if Input_YesNo("Clear any existing missions for the "..sname.." side?") then
                        while #side.missions > 0 do
                            local m = side.missions[1]
                            ScenEdit_DeleteMission(m.side, m.name)
                        end
                    end
                end
                break
            end
        end
    end
    --setup phase
    local setupPhase = Input_YesNo("Should the game start with a SETUP PHASE?")

    PBEM_SETUP_PHASE = setupPhase
    PBEM_TURN_LENGTH = turnLength*60
    PBEM_PLAYABLE_SIDES = playableSides
    StoreStringArray("__SCEN_PLAYABLESIDES", PBEM_PLAYABLE_SIDES)
    StoreNumber('__TURN_LENGTH', PBEM_TURN_LENGTH)
    StoreBoolean('__SCEN_SETUPPHASE', PBEM_SETUP_PHASE)
    
    if not PBEM_EventExists('PBEM: Scenario Loaded') then
        ScenEdit_AddSide({name=PBEM_DUMMY_SIDE})
        ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, awareness='BLIND'})

        -- initialize IKE on load by injecting its own code into the VM
        ScenEdit_SetEvent('PBEM: Scenario Loaded', {mode='add', IsRepeatable=true, IsShown=false})
        ScenEdit_SetTrigger({name='PBEM_Scenario_Loaded', mode='add', type='ScenLoaded'})
        ScenEdit_SetAction({name='PBEM: Turn Starts', mode='add', type='LuaScript', ScriptText=IKE_LOADER})
        ScenEdit_SetEventTrigger('PBEM: Scenario Loaded', {mode='add', name='PBEM_Scenario_Loaded'})
        ScenEdit_SetEventAction('PBEM: Scenario Loaded', {mode='add', name='PBEM: Turn Starts'})

        -- security check every second
        ScenEdit_SetEvent('PBEM: Turn Security', {mode='add', IsRepeatable=true, IsShown=false})
        ScenEdit_SetTrigger({name='PBEM_Turn_Security', mode='add', type='RegularTime', interval=0})
        ScenEdit_SetAction({name='PBEM: Check Turn Security', mode='add', type='LuaScript', ScriptText='PBEM_CheckSideSecurity()'})
        ScenEdit_SetEventTrigger('PBEM: Turn Security', {mode='add', name='PBEM_Turn_Security'})
        ScenEdit_SetEventAction('PBEM: Turn Security', {mode='add', name='PBEM: Check Turn Security'})

        -- track all destroyed units
        ScenEdit_SetEvent('PBEM: Turn Event Tracker', {mode='add', IsRepeatable=true, IsShown=false})
        for i=1,#PBEM_UNITYPES do
            local triggername = 'PBEM_Unit_Killed_'..i
            ScenEdit_SetTrigger({name=triggername, mode='add', type='UnitDestroyed', TargetFilter={TargetType=PBEM_UNITYPES[i], TargetSubType=0}})
            ScenEdit_SetEventTrigger('PBEM: Turn Event Tracker', {mode='add', name=triggername})
        end
        ScenEdit_SetAction({name='PBEM: Register Unit Killed', mode='add', type='LuaScript', ScriptText='PBEM_RegisterUnitKilled()'})
        ScenEdit_SetEventAction('PBEM: Turn Event Tracker', {mode='add', name='PBEM: Register Unit Killed'})

        -- track scenario end
        ScenEdit_SetEvent('PBEM: Scenario Over', {mode='add', IsRepeatable=false, IsShown=false})
        ScenEdit_SetTrigger({name='PBEM_On_Scenario_End', mode='add', type='ScenEnded'})
        ScenEdit_SetEventTrigger('PBEM: Scenario Over', {mode='add', name='PBEM_On_Scenario_End'})
        ScenEdit_SetAction({name='PBEM: End the Scenario', mode='add', type='LuaScript', ScriptText='PBEM_ScenarioOver()'})
        ScenEdit_SetEventAction('PBEM: Scenario Over', {mode='add', name='PBEM: End the Scenario'})

        for i=1,#PBEM_PLAYABLE_SIDES do
            ScenEdit_AddSpecialAction({
                ActionNameOrID='PBEM: Show remaining time in turn',
                Description="Display the remaining time before your PBEM turn ends.",
                Side=PBEM_PLAYABLE_SIDES[i],
                IsActive=true, 
                IsRepeatable=true,
                ScriptText='PBEM_ShowRemainingTime()'
            })

            -- initialize kill register
            PBEM_SetKillRegister(i, "")
        end
    end

    Turn_SetCurSide(1)
    local start_turn = 1
    if PBEM_HasSetupPhase() then
        start_turn = 0
    end
    ScenEdit_SetTime(PBEM_StartTimeToUTC())
    StoreNumber('__TURN_CURNUM', start_turn)
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})

    Input_OK(PBEM_LAST_MSG)
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

