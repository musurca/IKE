--[[
----------------------------------------------
IKE
pbem_msgs.lua
----------------------------------------------

Contains definitions for functions that deal with
storing turn/side info in special messages.

----------------------------------------------
]]--

function PBEM_SetContactRegister(sidenum, contacts)
    StoreString("__SIDE_"..tostring(sidenum)..'_CONTACTS', contacts)
end

function PBEM_GetContactRegister(sidenum)
    return string.sub(GetString("__SIDE_"..tostring(sidenum)..'_CONTACTS'), 0)
end

function PBEM_SetKillRegister(sidenum, kills)
    StoreString("__SIDE_"..tostring(sidenum)..'_KILLS', kills)
end

function PBEM_GetKillRegister(sidenum)
    return string.sub(GetString("__SIDE_"..tostring(sidenum)..'_KILLS'), 0)
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

function PBEM_RegisterNewContact()
    local contact = ScenEdit_UnitC()
    local detector = ScenEdit_UnitY()
    local contacttime = PBEM_CurrentTimeMilitary()
   
    if not contact then
        return
    end

    local contactname = contact.name
    local detecting_side = contact.fromside.name
    
    if IsIn(detecting_side, PBEM_PLAYABLE_SIDES) then
        if detecting_side ~= Turn_GetCurSideName() then
            local actual_unit = ScenEdit_GetUnit({
                guid=contact.actualunitid
            })
            if actual_unit.side == detecting_side then
                --it's annoying to be notified of out-of-comms contacts
                --on our own side, so we'll just ignore them
                return
            end

            local sidenum = PBEM_SideNumberByName(detecting_side)
            local contacts = PBEM_GetContactRegister(sidenum)
            local detection_data = ""
            if detector then
                detection_data = Format(Localize("DETECTED_MARKER"), {
                    contactname,
                    detector.unit.name
                })
            end
            contacts = contacts.."<i>"..contacttime.."</i> // "..detection_data.."<br/>"
            PBEM_SetContactRegister(sidenum, contacts)

            --mark contact on the map
            ScenEdit_AddReferencePoint({
                side=detecting_side, 
                name=Format(Localize("CONTACT_MARKER"), {
                    contactname,
                    contacttime
                }), 
                lat=contact.latitude, 
                lon=contact.longitude, 
                highlighted=true
            })
        end
    end
end

function PBEM_RegisterUnitKilled()
    local killed = ScenEdit_UnitX()
    local killer = ScenEdit_UnitY()
    local killtime = PBEM_CurrentTimeMilitary()
    local killer_unit = nil
    local killer_side = ""
    if killer then
        if killer.unit then
            killer_unit = killer.unit
            killer_side = killer_unit.side
        end
    end

    -- register loss
    if IsIn(killed.side, PBEM_PLAYABLE_SIDES) then
        if killed.side ~= Turn_GetCurSideName() then
            local sidenum = PBEM_SideNumberByName(killed.side)
            local losses = PBEM_GetLossRegister(sidenum)
            local unitname
            if killed.name == killed.classname then
                unitname = killed.name
            else
                unitname = killed.name..' ('..killed.classname..')'
            end
            if killer_unit then
                if killer_unit.classname then
                    unitname = unitname.." "..Format(Localize("LOSS_LISTING"), {
                        killer_unit.classname
                    })
                end
            end
            losses = losses.."<i>"..killtime.."</i> // "..unitname.."<br/>"
            PBEM_SetLossRegister(sidenum, losses)

            --mark loss on the map
            ScenEdit_AddReferencePoint({
                side=killed.side, 
                name=Format(Localize("LOSS_MARKER"), {killed.name}), 
                lat=killed.latitude, 
                lon=killed.longitude, 
                highlighted=true
            })
        end
    end

    -- register and mark kill
    if killer_unit then
        if IsIn(killer_side, PBEM_PLAYABLE_SIDES) then
            if killer_side ~= Turn_GetCurSideName() then
                -- record the kill for the player
                local sidenum = PBEM_SideNumberByName(killer_side)
                local kills = PBEM_GetKillRegister(sidenum)
                local killer_side_guid = SideGUIDByName(killer_side)
                local known_name = killed.classname
                for k, contact in pairs(killed.ascontact) do
                    if contact.side == killer_side_guid then
                        known_name = contact.name
                    end
                end
                local unitname = known_name
                if killer_unit.classname then
                    unitname = unitname.." "..Format(Localize("KILL_LISTING"), {
                        killer_unit.classname
                    })
                end
                kills = kills.."<i>"..killtime.."</i> // "..unitname.."<br/>"
                PBEM_SetKillRegister(sidenum, kills)

                --mark kill on the map
                ScenEdit_AddReferencePoint({
                    side=killer_side,
                    name=Format(Localize("KILL_MARKER"), {known_name}), 
                    lat=killed.latitude, 
                    lon=killed.longitude, 
                    highlighted=true
                })
            end
        end
    end
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

function PBEM_ShowTurnIntro()
    local cursidenum = Turn_GetCurSide()
    local turnnum = Turn_GetTurnNumber()
    local lossreport = ""
    -- show new contacts from previous turn
    local contacts = PBEM_GetContactRegister(cursidenum)
    if contacts ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("CONTACTS_REPORTED").."</u><br/><br/>"..contacts
        PBEM_SetContactRegister(cursidenum, "")
    end
    -- show kills from previous turn
    local kills = PBEM_GetKillRegister(cursidenum)
    if kills ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("KILLS_REPORTED").."</u><br/><br/>"..kills
        PBEM_SetKillRegister(cursidenum, "")
    end
    -- show losses from previous turn
    local losses = PBEM_GetLossRegister(cursidenum)
    if losses ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("LOSSES_REPORTED").."</u><br/><br/>"..losses
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
                math.floor(PBEM_TURN_LENGTH / PBEM_ORDER_INTERVAL) + 1
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

function PBEM_MakeScheduledMessage(side_num, targetside, time, msg)
    local base_id = "__SCEN_SCHEDULEDMSG_"..side_num
    StoreBoolean(base_id, true)
    StoreString(base_id.."_TARGET", targetside)
    StoreNumber(base_id.."_TIME", time)
    StoreString(base_id.."_MSG", msg)

    table.insert(PBEM_SCHEDULED_MESSAGES, {
        from = side_num,
        target = targetside,
        time = time,
        msg = msg
    })
end

function PBEM_ClearScheduledMessage(side_num)
    local base_id = "__SCEN_SCHEDULEDMSG_"..side_num
    StoreBoolean(base_id, false)
    StoreString(base_id.."_TARGET", "")
    StoreNumber(base_id.."_TIME", 0)
    StoreString(base_id.."_MSG", "")
end

function PBEM_PrecacheScheduledMessages()
    PBEM_SCHEDULED_MESSAGES = {}
    for i=1, #PBEM_PLAYABLE_SIDES do
        local base_id = "__SCEN_SCHEDULEDMSG_"..i
        if GetBoolean(base_id) then
            table.insert(PBEM_SCHEDULED_MESSAGES, {
                from = i,
                target = GetString(base_id.."_TARGET"),
                time = GetNumber(base_id.."_TIME"),
                msg = GetString(base_id.."_MSG")
            })
        end
    end
end

function PBEM_CheckScheduledMessages()
    local cur_time = ScenEdit_CurrentTime()
    for i = #PBEM_SCHEDULED_MESSAGES, 1, -1 do
        local message = PBEM_SCHEDULED_MESSAGES[i]
        if cur_time >= message.time then
            ScenEdit_SpecialMessage(message.target, Format(Localize("CHAT_MSG_FORM"), {
                PBEM_PLAYABLE_SIDES[message.from],
                message.msg
            }))
            PBEM_ClearScheduledMessage(message.from)
            table.remove(PBEM_SCHEDULED_MESSAGES, i)
        end
    end
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

