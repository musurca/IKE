--[[
----------------------------------------------
IKE
04_wizard.lua
----------------------------------------------

This source file contains the IKE Wizard that 
sets up a scenario for PBEM play without 
requiring the author to write any additional
code.

----------------------------------------------
]]--

IKE_VERSION = "1.2"

PBEM_UNITYPES = {
    1, --aircraft
    2, --ship
    3, --submarine
    4, --facility
    7 --satellite
}

function PBEM_Init()
    --wizard intro
    if not Input_YesNo(Format(Localize("WIZARD_INTRO_MESSAGE"), {IKE_VERSION})) then
        Input_OK(Localize("WIZARD_BACKUP"))
        return
    end
    --designate playable sides
    local sides = VP_GetSides()
    local playableSides = {}
    for i=1,#sides do
        if Input_YesNo(Format(Localize("WIZARD_PLAYABLE_SIDE"), {sides[i].name})) then
            table.insert(playableSides, sides[i].name)
        end
    end
    local turn_lengths = {}
    if Input_YesNo(Localize("WIZARD_FIXED_TURNLENGTH")) then
        -- length of turn
        local turnLength = 0
        while turnLength == 0 do
            turnLength = Input_Number(Localize("WIZARD_TURN_LENGTH"))
            if not turnLength then
                return
            else
                turnLength = math.max(0, math.floor(turnLength))
                if turnLength == 0 then
                    Input_OK(Localize("WIZARD_ZERO_LENGTH"))
                end
            end
        end
        -- same length for each side
        for k,v in ipairs(playableSides) do
            table.insert(turn_lengths, turnLength*60)
        end
    else
        -- length of turns
        ForEachDo(playableSides, function(sidename)
            local turnLength = 0
            while turnLength == 0 do
                turnLength = Input_Number(Format(Localize("WIZARD_TURN_LENGTH_SIDE"), {sidename}))
                if not turnLength then
                    return
                else
                    turnLength = math.max(0, math.floor(turnLength))
                    if turnLength == 0 then
                        Input_OK(Localize("WIZARD_ZERO_LENGTH"))
                    end
                end
            end
            -- insert turn length for that side
            table.insert(turn_lengths, turnLength*60)
        end)
    end
    --unlimited orders?
    unlimitedOrders = Input_YesNo(Localize("WIZARD_UNLIMITED_ORDERS"))
    if not unlimitedOrders then
        --number of orders per turn
        orderNumber = Input_Number(Localize("WIZARD_ORDER_NUMBER"))
        orderNumber = math.max(0, math.floor(orderNumber))
        if orderNumber == 0 then
            Input_OK(Localize("WIZARD_ZERO_ORDER"))
            return
        end
    end
    --turn order
    local order_set = false
    while not order_set do
        for i=1,#playableSides do
            if Input_YesNo(Format(Localize("WIZARD_GO_FIRST"), {playableSides[i]})) then
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
                    if Input_YesNo(Format(Localize("WIZARD_CLEAR_MISSIONS"), {sname})) then
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
    local setupPhase = Input_YesNo(Localize("WIZARD_SETUP_PHASE"))

    --Store choices in the scenario
    PBEM_SETUP_PHASE = setupPhase
    PBEM_PLAYABLE_SIDES = playableSides
    StoreStringArray("__SCEN_PLAYABLESIDES", PBEM_PLAYABLE_SIDES)
    StoreNumberArray("__SCEN_TURN_LENGTHS", turn_lengths)
    StoreBoolean('__SCEN_SETUPPHASE', PBEM_SETUP_PHASE)
    StoreBoolean('__SCEN_UNLIMITEDORDERS', unlimitedOrders)
    if not unlimitedOrders then
        StoreNumber('__SCEN_ORDERINTERVAL', orderNumber)
    end
    
    if not PBEM_EventExists('PBEM: Scenario Loaded') then
        ScenEdit_AddSide({name=PBEM_DUMMY_SIDE})
        --ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, awareness='BLIND'})

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

        for i=1,#PBEM_PLAYABLE_SIDES do
            -- add special actions
            PBEM_AddRTSide(PBEM_PLAYABLE_SIDES[i])

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

    Input_OK(Localize("WIZARD_SUCCESS"))
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

