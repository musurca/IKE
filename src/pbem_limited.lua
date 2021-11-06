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

function PBEM_ConstructDummySideName(side)
    return "("..side..")"
end

function PBEM_DummySideName()
    return PBEM_ConstructDummySideName(PBEM_SIDENAME)
end

function PBEM_ShowFinalPosition()
    local sidescore = ScenEdit_GetScore(PBEM_SIDENAME)
    if ScenEdit_GetScore(PBEM_DUMMY_SIDE) ~= sidescore then
        ScenEdit_SetScore(PBEM_DUMMY_SIDE, sidescore, PBEM_SIDENAME)
    end

    ScenEdit_SetSidePosture(PBEM_SIDENAME, PBEM_DUMMY_SIDE, "F")
    ScenEdit_SetSidePosture(PBEM_DUMMY_SIDE, PBEM_SIDENAME, "F")
    local sides = VP_GetSides()
    for i=1,#sides do
        local side = sides[i].name
        if PBEM_SIDENAME ~= side then
            local posture = ScenEdit_GetSidePosture(PBEM_SIDENAME, side)
            ScenEdit_SetSidePosture(PBEM_DUMMY_SIDE, side, posture)
        end
    end
end

function PBEM_MirrorSideScore()
    --mirror side score
    local dummy_side = PBEM_DummySideName()
    local sidescore = ScenEdit_GetScore(PBEM_SIDENAME)
    if ScenEdit_GetScore(dummy_side) ~= sidescore then
        ScenEdit_SetScore(dummy_side, sidescore, PBEM_SIDENAME)
    end
end

function PBEM_MirrorSide(sidename)
    local dummy_side = PBEM_ConstructDummySideName(sidename)
    ScenEdit_SetSidePosture(sidename, dummy_side, "F")
    ScenEdit_SetSidePosture(dummy_side, sidename, "F")
    local sides = VP_GetSides()
    for i=1,#sides do
        local side = sides[i].name
        if sidename ~= side then
            local posture = ScenEdit_GetSidePosture(sidename, side)
            ScenEdit_SetSidePosture(dummy_side, side, posture)
        end
    end
end

function PBEM_MirrorContactPostures()
    local dummy_side = PBEM_DummySideName()
    local contacts = ScenEdit_GetContacts(dummy_side)
    local mirrorside = PBEM_SIDENAME
    local mirrorside_guid = SideGUIDByName(mirrorside)
    for k, contact in ipairs(contacts) do
        local unit = ScenEdit_GetUnit({guid=contact.actualunitid})
        for j, ascon in ipairs(unit.ascontact) do
            if ascon.side == mirrorside_guid then
                local mcontact = ScenEdit_GetContact({side=mirrorside, guid=ascon.guid})
                if mcontact.posture ~= contact.posture then
                    contact.posture = mcontact.posture
                end
                break
            end
        end
    end
end

function PBEM_WipeRPs()
    -- Erase all RPs from dummy side
    local dummy_side = PBEM_DummySideName()
    local area = {}
    local rps
    local sides = VP_GetSides()
    for i=1,#sides do
        local side = sides[i]
        if side.name == dummy_side then
            for k, v in ipairs(side.rps) do
                area[k] = v.name
            end
            if #area > 0 then
                rps = ScenEdit_GetReferencePoints(
                    {
                        side=dummy_side,
                        area=area
                    }
                )
                for k, v in ipairs(rps) do
                    ScenEdit_DeleteReferencePoint(v)
                end
            end
            return
        end
    end
end

function PBEM_TransferRPs()
    -- Transfer RPs from dummy side to player side
    local dummy_side = PBEM_DummySideName()
    local area = {}
    local rps
    local sides = VP_GetSides()
    for i=1,#sides do
        local side = sides[i]
        if side.name == dummy_side then
            for k, v in ipairs(side.rps) do
                area[k] = v.name
            end
            if #area > 0 then
                rps = ScenEdit_GetReferencePoints(
                    {
                        side=dummy_side,
                        area=area
                    }
                )
                for k, v in ipairs(rps) do
                    ScenEdit_AddReferencePoint(
                        {
                            side=PBEM_SIDENAME,
                            name=v.name,
                            lat=v.latitude,
                            lon=v.longitude,
                            highlighted=true
                        }
                    )
                    ScenEdit_DeleteReferencePoint(v)
                end
            end
            return
        end
    end
end

function PBEM_AddDummyUnit(side)
    --adds a dummy unit so allies transmit contacts
    local dummy = ScenEdit_AddUnit({
        side=side,
        name="",
        type="FACILITY",
        dbid=174, 
        latitude=-89,
        longitude=0,
    })
end

function PBEM_ShowOrderPhase(resume)
    resume = resume or false
    local cur_time = ScenEdit_CurrentTime()
    local next_turn_start_time = PBEM_GetNextTurnStartTime()
    local turn_start_time = PBEM_GetCurTurnStartTime()
    local phase_num = ((cur_time - turn_start_time) / PBEM_ORDER_INTERVAL) + 1
    local turn_len_min = math.floor((next_turn_start_time - cur_time) / 60)
    local phase_str = Format(Localize("ORDER_PHASE_DIVIDER"), {
        math.floor(phase_num + 0.5),
        math.floor(PBEM_TURN_LENGTH / PBEM_ORDER_INTERVAL) + 1
    })

    -- determine whether this is a regular order phase or the last order phase
    local order_header, order_message
    if (cur_time == (next_turn_start_time - 1)) then
        order_header = Localize("FINAL_ORDER_HEADER")
        order_message = Localize("FINAL_ORDER_MESSAGE")
    else
        order_header = Localize("NEXT_ORDER_HEADER")
        order_message = Localize("START_ORDER_MESSAGE")
    end

    local msg = Message_Header(
        Format(
            order_header, {
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
        msg = msg..order_message
    end
    PBEM_SpecialMessage('playerside', msg, nil, true)
end

function PBEM_EndOrderPhase()
    PBEM_MirrorSide(PBEM_SIDENAME)
    PBEM_MirrorSideScore()
    ScenEdit_SetSideOptions({side=PBEM_DummySideName(), switchto=true})
end

function PBEM_StartOrderPhase()
    ScenEdit_SetSideOptions({side=PBEM_SIDENAME, switchto=true})
    PBEM_ShowOrderPhase()
end
