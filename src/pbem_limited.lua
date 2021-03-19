--[[
----------------------------------------------
IKE
pbem_limited.lua
----------------------------------------------

Contains logic for IKE's Limited Orders mode.

----------------------------------------------
]]--

function PBEM_OrdersUnlimited()
    return GetBoolean('__SCEN_UNLIMITEDORDERS')
end

function PBEM_OrderPhases()
    return GetNumberArray("__SCEN_ORDERINTERVAL")
end

function PBEM_OrderInterval()
    return math.floor(PBEM_TURN_LENGTH / PBEM_ORDER_PHASES[Turn_GetCurSide()])
end

function PBEM_MirrorSideScore()
    --mirror side score
    local sidescore = ScenEdit_GetScore(PBEM_SIDENAME)
    if ScenEdit_GetScore(PBEM_DUMMY_SIDE) ~= sidescore then
        ScenEdit_SetScore(PBEM_DUMMY_SIDE, sidescore, PBEM_SIDENAME)
    end
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

function PBEM_DummyUnit()
    return GetString("__PBEM_DUMMYGUID")
end

function PBEM_AddDummyUnit()
    local dummy_guid = PBEM_DummyUnit()
    if dummy_guid ~= "" then
        PBEM_RemoveDummyUnit()
    end

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
end

function PBEM_RemoveDummyUnit()
    local dummy_guid = PBEM_DummyUnit()
    if dummy_guid ~= "" then
        pcall(ScenEdit_DeleteUnit, {
            side=PBEM_DUMMY_SIDE, 
            guid=dummy_guid
        })
        StoreString("__PBEM_DUMMYGUID", "")
    end
end

function PBEM_ShowOrderPhase(resume)
    resume = resume or false
    local cur_time = ScenEdit_CurrentTime()
    local turn_start_time = PBEM_GetCurTurnStartTime()
    local phase_num = ((cur_time - turn_start_time) / PBEM_ORDER_INTERVAL) + 1
    phase_num = math.floor(phase_num)
    local turn_len_min = math.floor((PBEM_GetNextTurnStartTime() - cur_time) / 60)
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
    )
    if resume then
        msg = msg..Localize("RESUME_ORDER_MESSAGE")
    else
        msg = msg..Localize("START_ORDER_MESSAGE")
    end
    PBEM_SpecialMessage('playerside', msg, nil, true)
end

function PBEM_EndOrderPhase()
    PBEM_MirrorSide(PBEM_SIDENAME)
    PBEM_MirrorSideScore()
    ScenEdit_SetSideOptions({side=PBEM_DUMMY_SIDE, switchto=true})
end

function PBEM_StartOrderPhase()
    ScenEdit_SetSideOptions({side=PBEM_SIDENAME, switchto=true})
    PBEM_ShowOrderPhase()
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

