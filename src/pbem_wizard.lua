--[[
----------------------------------------------
IKE
pbem_wizard.lua
----------------------------------------------

This source file contains the IKE Wizard that 
sets up a scenario for PBEM play without 
requiring the author to write any additional
code.

----------------------------------------------
]]--

function PBEM_Wizard()
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
    --determine turn length
    local turn_length = 0
    local turnLengthSec = 0
    while turnLengthSec == 0 do
        turnLengthSec = Input_Number(Localize("WIZARD_TURN_LENGTH"))
        if not turnLengthSec then
            return
        else
            turnLengthSec = math.max(0, math.floor(turnLengthSec))
            if turnLengthSec == 0 then
                Input_OK(Localize("WIZARD_ZERO_LENGTH"))
            end
        end
    end
    turn_length = turnLengthSec * 60
    
    --unlimited orders?
    local unlimitedOrders = Input_YesNo(Localize("WIZARD_UNLIMITED_ORDERS"))
    local order_phases = {}
    if not unlimitedOrders then
        --number of orders per turn
        ForEachDo(playableSides, function(side)
            local orderNumber = Input_Number(
                Format(Localize("WIZARD_ORDER_NUMBER"), {
                    side
                })
            )
            orderNumber = math.max(2, math.floor(orderNumber)) - 1
            table.insert(order_phases, orderNumber)
        end)
    end
    --turn order - set up to nine ranks
    local order_set = false
    local order_messages = {
        Localize("FIRST"),
        Localize("SECOND"),
        Localize("THIRD"),
        Localize("FOURTH"),
        Localize("FIFTH"),
        Localize("SIXTH"),
        Localize("SEVENTH"),
        Localize("EIGHTH"),
        Localize("NINTH")
    }
    local ranks_to_set = math.min(#playableSides-1, 9)
    local rank = 1
    while not order_set do
        for i=rank, #playableSides do
            local msg_go_order = Format(Localize("WIZARD_GO_ORDER"), {
                playableSides[i],
                order_messages[rank]
            })
            if Input_YesNo(msg_go_order) then
                --swap order
                local temp_side = playableSides[rank]
                playableSides[rank] = playableSides[i]
                playableSides[i] = temp_side
                --swap order_phases
                if not unlimitedOrders then
                    temp_side = order_phases[rank]
                    order_phases[rank] = order_phases[i]
                    order_phases[i] = temp_side
                end
                rank = rank + 1
                break
            end
        end
        if rank > ranks_to_set then
            order_set = true
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
    --editor mode
    local prevent_editor = Input_YesNo(Localize("WIZARD_PREVENT_EDITOR"))

    --Store choices in the scenario
    PBEM_SETUP_PHASE = setupPhase
    PBEM_PLAYABLE_SIDES = playableSides
    StoreStringArray("__SCEN_PLAYABLESIDES", PBEM_PLAYABLE_SIDES)
    StoreNumber("__SCEN_TURN_LENGTH", turn_length)
    StoreBoolean('__SCEN_SETUPPHASE', PBEM_SETUP_PHASE)
    StoreBoolean('__SCEN_UNLIMITEDORDERS', unlimitedOrders)
    StoreBoolean("__SCEN_PREVENTEDITOR", prevent_editor)
    if not unlimitedOrders then
        StoreNumberArray('__SCEN_ORDERINTERVAL', order_phases)
    end

    -- Install IKE into the scenario

    -- first, remove any preexisting version of IKE
    if Event_Exists("PBEM: Scenario Loaded") then
        Event_Delete("PBEM: Scenario Loaded", true)
        
        ForEachDo(PBEM_PLAYABLE_SIDES, function(side)
            PBEM_RemoveRTSide(side)
        end)
    end
    if Event_Exists("PBEM: Update Tick") then
        Event_Delete("PBEM: Update Tick", true)
    end
    if Event_Exists("PBEM: Destroyed Unit Tracker") then
        Event_Delete("PBEM: Destroyed Unit Tracker", true)
    end
    if Event_Exists("PBEM: Damaged Unit Tracker") then
        Event_Delete("PBEM: Damaged Unit Tracker", true)
    end
    if Event_Exists("PBEM: New Contact Tracker") then
        Event_Delete("PBEM: New Contact Tracker", true)
    end
    if Side_Exists(PBEM_DUMMY_SIDE) then
        ScenEdit_RemoveSide({name=PBEM_DUMMY_SIDE})
    end
    
    --next, create the PBEM dummy side and initialize PBEM events
    ScenEdit_AddSide({name=PBEM_DUMMY_SIDE})
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, awareness='BLIND'})
    for i, v in ipairs(PBEM_PLAYABLE_SIDES) do
        local ds = PBEM_ConstructDummySideName(v)
        if Side_Exists(ds) then
            ScenEdit_RemoveSide({name=ds})
        end
        ScenEdit_AddSide({name=ds})
    end

    -- initialize IKE on load by injecting its own code into the VM
    local loadEvent = Event_Create("PBEM: Scenario Loaded", {
        IsRepeatable=true,
        IsShown=false
    })
    Event_AddTrigger(loadEvent, Trigger_Create("PBEM_Scenario_Loaded", {
        type="ScenLoaded"
    }))
    Event_AddAction(loadEvent, Action_Create("PBEM: Turn Starts", {
        type="LuaScript",
        ScriptText=IKE_LOADER
    }))

    -- update tick every second
    local updateEvent = Event_Create("PBEM: Update Tick", {
        IsRepeatable=true, 
        IsShown=false
    })
    Event_AddTrigger(updateEvent, Trigger_Create("PBEM_Update_Tick", {
        type="RegularTime", 
        interval=0
    }))
    Event_AddAction(updateEvent, Action_Create("PBEM: Next Update", {
        type="LuaScript", 
        ScriptText="PBEM_UpdateTick()"
    }))

    -- track all destroyed units
    local PBEM_UNITYPES = {
        1, --aircraft
        2, --ship
        3, --submarine
        4, --facility
        7 --satellite
    }
    local destEvent = Event_Create("PBEM: Destroyed Unit Tracker", {
        IsRepeatable=true,
        IsShown=false
    })
    for i=1,#PBEM_UNITYPES do
        local triggername = 'PBEM_Unit_Killed_'..i
        Event_AddTrigger(destEvent, Trigger_Create(triggername, {
            type = "UnitDestroyed",
            TargetFilter = {
                TargetType = PBEM_UNITYPES[i],
                TargetSubType = 0
            }
        }))
    end
    Event_AddAction(destEvent, Action_Create("PBEM: Register Unit Killed", {
        type="LuaScript", 
        ScriptText="PBEM_RegisterUnitKilled()"
    }))

    -- track some damaged units
    local PBEM_DAMTYPES = {
        2, --ship
        3, --submarine
        4 --facility
    }
    local destEvent = Event_Create("PBEM: Damaged Unit Tracker", {
        IsRepeatable=true,
        IsShown=false
    })
    for i=1,#PBEM_DAMTYPES do
        local triggername = 'PBEM_Unit_Damaged_'..i
        Event_AddTrigger(destEvent, Trigger_Create(triggername, {
            type = "UnitDamaged",
            DamagePercent = 1,
            TargetFilter = {
                TargetType = PBEM_DAMTYPES[i],
                TargetSubType = 0
            }
        }))
    end
    Event_AddAction(destEvent, Action_Create("PBEM: Register Unit Damaged", {
        type="LuaScript",
        ScriptText="PBEM_RegisterUnitDamaged()"
    }))

    -- track all new contacts
    local PBEM_DETECTORS = {
        1, --aircraft
        2, --ship
        3, --submarine
        4 --facility
    }
    local contactEvent = Event_Create("PBEM: New Contact Tracker", {
        IsRepeatable=true, 
        IsShown=false
    })
    for i=1,#PBEM_PLAYABLE_SIDES do
        local guid = SideGUIDByName(PBEM_PLAYABLE_SIDES[i])
        if guid then
            for j=1,#PBEM_DETECTORS do
                local triggername = 'PBEM_NewContact_'..i..'_'..j
                Event_AddTrigger(contactEvent, Trigger_Create(triggername, {
                    type="UnitDetected", 
                    DetectorSideID=guid, 
                    TargetFilter = {
                        TargetType = PBEM_DETECTORS[j],
                        TargetSubType=0
                    }
                }))
            end
        end
    end
    Event_AddAction(contactEvent, Action_Create("PBEM: Register New Contact", {
        type="LuaScript",
        ScriptText="PBEM_RegisterNewContact()"
    }))

    -- next, set up the playable sides
    for i, v in ipairs(PBEM_PLAYABLE_SIDES) do
        local ds = PBEM_ConstructDummySideName(v)
        PBEM_AddDummyUnit(ds)
        PBEM_AddRTSide(ds)

        -- add special actions
        PBEM_AddRTSide(v)

        -- initialize message registers
        PBEM_SetLossRegister(i, "")
        PBEM_SetKillRegister(i, "")
        PBEM_SetContactRegister(i, "")

        -- clear scheduled messages
        PBEM_ClearScheduledMessage(i)
    end

    --initialize the first turn
    Turn_SetCurSide(1)
    local start_turn = 1
    if PBEM_HasSetupPhase() then
        start_turn = 0
    end
    StoreNumber('__TURN_CURNUM', start_turn)

    -- reset the scenario to its starting time
    ScenEdit_SetTime(PBEM_StartTimeToUTC())

    -- finally, switch to the dummy side for scenario start
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})

    Input_OK(Localize("WIZARD_SUCCESS"))
end
