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

function PBEM_GetDamageRegister(sidenum)
    return string.sub(GetString("__SIDE_"..tostring(sidenum)..'_DAMAGES'), 0)
end

function PBEM_SetDamageRegister(sidenum, damages)
    StoreString("__SIDE_"..tostring(sidenum)..'_DAMAGES', damages)
end

function PBEM_GetHitRegister(sidenum)
    return string.sub(GetString("__SIDE_"..tostring(sidenum)..'_HITS'), 0)
end

function PBEM_SetHitRegister(sidenum, hits)
    StoreString("__SIDE_"..tostring(sidenum)..'_HITS', hits)
end

function PBEM_GetFratricideRegister(sidenum)
    return string.sub(GetString("__SIDE_"..tostring(sidenum)..'_FRAT'), 0)
end

function PBEM_SetFratricideRegister(sidenum, hits)
    StoreString("__SIDE_"..tostring(sidenum)..'_FRAT', hits)
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
            if not actual_unit then
                return
            end
            if actual_unit.side == detecting_side then
                --it's annoying to be notified of out-of-comms contacts
                --on our own side, so we'll just ignore them
                return
            end

            local sidenum = PBEM_SideNumberByName(detecting_side)
            local contacts = PBEM_GetContactRegister(sidenum)
            local detection_data = ""
            if detector then
                local detector_unit = detector.unit
                if detector_unit then
                    detection_data = Format(
                        LocalizeForSide(
                            detecting_side,
                            "DETECTED_MARKER"
                        ),
                        {
                            contactname,
                            detector_unit.name
                        }
                    )
                end
            end
            contacts = contacts.."<i>"..contacttime.."</i> // "..detection_data.."<br/>"
            PBEM_SetContactRegister(sidenum, contacts)

            --mark contact on the map
            ScenEdit_AddReferencePoint({
                side=detecting_side,
                name=Format(
                    LocalizeForSide(
                        detecting_side,
                        "CONTACT_MARKER"
                    ),
                    {
                        contactname,
                        contacttime
                    }
                ),
                lat=contact.latitude,
                lon=contact.longitude,
                highlighted=true
            })
        end
    end
end

PBEM_WEAPON_CODES = {
    [2001] = "ID_GUIDEDWEAP",
    [2002] = "ID_ROCKET",
    [2003] = "ID_BOMB",
    [2004] = "ID_GUNS",
    [2010] = "ID_SUICIDEBOMB",
    [2011] = "ID_SABOTAGEBOMB",
    [2012] = "ID_GUIDEDPROJ",
    [4001] = "ID_TORPEDO",
    [4002] = "ID_DEPTHCHARGE",
    [4004] = "ID_MINE",
    [4005] = "ID_MINE",
    [4006] = "ID_MINE",
    [4007] = "ID_MINE",
    [4008] = "ID_MINE",
    [4009] = "ID_MINE",
    [4011] = "ID_MINE",
    [6001] = "ID_LASER"
}

function PBEM_KnownWeaponName(weapon_unit, detecting_side)
    -- determine the name of the weapon by how much is known about it
    local detecting_side_guid = SideGUIDByName(detecting_side)
    local weap_name = LocalizeForSide(detecting_side, "UNKNOWN_WEAPON")

    if weapon_unit then
        -- find generic name of weapon
        local subtype = tonumber(weapon_unit.subtype)
        if subtype then
            local weap_locale_id = PBEM_WEAPON_CODES[subtype]
            if weap_locale_id then
                weap_name = LocalizeForSide(detecting_side, weap_locale_id)
            end
        end
        
        -- see if we have enough info to get more specific
        for k, contact in ipairs(weapon_unit.ascontact) do
            if contact.side == detecting_side_guid then
                local success, con = pcall(
                    ScenEdit_GetContact,
                    {
                        side=detecting_side,
                        guid=contact.guid
                    }
                )
                if con then
                    if con.classificationlevel >= 3 then
                        weap_name = weapon_unit.classname
                    end
                end
                break
            end
        end
    end

    return weap_name
end

function PBEM_RegisterUnitDamaged()
    local damaged = ScenEdit_UnitX()
    local damager = ScenEdit_UnitY()
    local damage_time = PBEM_CurrentTimeMilitary()
    local damager_unit = nil
    local damager_side = ""
    local damager_side_guid = ""
    local dguid = string.upper(damaged.guid)
    if damager then
        if damager.unit then
            damager_unit = damager.unit
            damager_side = damager_unit.side
            damager_side_guid = SideGUIDByName(damager_side)

            if damaged then
                StoreString("__LD_"..dguid, damager_side)
            end
        end
    end

    if damaged.type == "Aircraft" then
        -- don't push aircraft damage to our turn log
        return
    end

    -- register damage
    if IsIn(damaged.side, PBEM_PLAYABLE_SIDES) then
        if damaged.side ~= Turn_GetCurSideName() then
            local damaged_side = damaged.side
            local sidenum = PBEM_SideNumberByName(damaged_side)
            local damage_register = PBEM_GetDamageRegister(sidenum)
            local unitname
            if damaged.name == damaged.classname then
                unitname = damaged.name
            else
                unitname = damaged.name..' ('..damaged.classname..')'
            end
            -- find the name of the weapon by how much is known about it
            local weap_name = PBEM_KnownWeaponName(damager_unit, damaged_side)
            StoreString("__LDCLASS_"..dguid, weap_name)
            unitname = unitname.." "..Format(
                LocalizeForSide(damaged_side, "DAMAGE_LISTING"),
                {
                    weap_name
                }
            )
            damage_register = damage_register.."<i>"..damage_time.."</i> // "..unitname.."<br/>"
            PBEM_SetDamageRegister(sidenum, damage_register)
        end
    end

    --register hit
    if damager_unit then
        if IsIn(damager_side, PBEM_PLAYABLE_SIDES) and (damager_side ~= damaged.side) then
            if damager_side ~= Turn_GetCurSideName() then
                -- record the hit for the player
                local sidenum = PBEM_SideNumberByName(damager_side)
                local hits = PBEM_GetHitRegister(sidenum)
                local known_name = damaged.type
                for k, contact in ipairs(damaged.ascontact) do
                    if contact.side == damager_side_guid then
                        known_name = contact.name
                        break
                    end
                end
                local unitname = known_name
                if damager_unit.classname then
                    unitname = known_name.." "..Format(
                        LocalizeForSide(damager_side, "HIT_LISTING"),
                        {
                            damager_unit.classname
                        }
                    )
                end
                hits = hits.."<i>"..damage_time.."</i> // "..unitname.."<br/>"
                PBEM_SetHitRegister(sidenum, hits)
            end
        end
    end
end

function PBEM_RegisterUnitKilled()
    local killed = ScenEdit_UnitX()
    local killer = ScenEdit_UnitY()
    local killtime = PBEM_CurrentTimeMilitary()
    local killer_unit = nil
    local kguid = string.upper(killed.guid)
    local damstore_id = "__LD_"..kguid
    local damclass_id = "__LDCLASS_"..kguid
    local killer_side = GetString(damstore_id)
    local damclass_default = GetString(damclass_id)
    local killer_side_guid = ""
    StoreString(damstore_id, "")
    StoreString(damclass_id, "")
    if killer then
        if killer.unit then
            killer_unit = killer.unit
            killer_side = killer_unit.side
        end
    end
    if killer_side ~= "" then
        killer_side_guid = SideGUIDByName(killer_side)
    end

    local is_fratricide = (killer_side == killed.side)

    -- register loss
    if IsIn(killed.side, PBEM_PLAYABLE_SIDES) then
        if killed.side ~= Turn_GetCurSideName() then       
            local killed_side = killed.side
            local sidenum = PBEM_SideNumberByName(killed_side)
            local losses
            if is_fratricide == true then
                losses = PBEM_GetFratricideRegister(sidenum)
            else
                losses = PBEM_GetLossRegister(sidenum)
            end
            local unitname
            if killed.name == killed.classname then
                unitname = killed.name
            else
                unitname = killed.name..' ('..killed.classname..')'
            end
            -- find the name of the weapon by how much is known about it
            local weap_name = damclass_default
            if killer_unit or (weap_name == "") then
                weap_name = PBEM_KnownWeaponName(killer_unit, killed_side)
            end
            unitname = unitname.." "..Format(
                LocalizeForSide(killed_side, "LOSS_LISTING"),
                {
                    weap_name
                }
            )
            losses = losses.."<i>"..killtime.."</i> // "..unitname.."<br/>"
            if is_fratricide == true then
                PBEM_SetFratricideRegister(sidenum, losses)
            else
                PBEM_SetLossRegister(sidenum, losses)
            end

            --mark loss on the map
            ScenEdit_AddReferencePoint({
                side=killed_side,
                name=Format(
                    LocalizeForSide(killed_side, "LOSS_MARKER"),
                    {
                        killed.name
                    }
                ),
                lat=killed.latitude,
                lon=killed.longitude,
                highlighted=true
            })
        end
    end

    if is_fratricide == true then
        -- no need to mark the kill
        return
    end

    -- register and mark kill
    if killer_unit or (killer_side ~= "") then
        if IsIn(killer_side, PBEM_PLAYABLE_SIDES) then
            if killer_side ~= Turn_GetCurSideName() then
                -- record the kill for the player
                local sidenum = PBEM_SideNumberByName(killer_side)
                local kills = PBEM_GetKillRegister(sidenum)
                local known_name = killed.type
                for k, contact in ipairs(killed.ascontact) do
                    if contact.side == killer_side_guid then
                        known_name = contact.name
                        break
                    end
                end
                local unitname = known_name
                if killer_unit then
                    if killer_unit.classname then
                        unitname = unitname.." "..Format(
                            LocalizeForSide(killer_side, "KILL_LISTING"),
                            {
                                killer_unit.classname
                            }
                        )
                    end
                end
                kills = kills.."<i>"..killtime.."</i> // "..unitname.."<br/>"
                PBEM_SetKillRegister(sidenum, kills)

                --mark kill on the map
                ScenEdit_AddReferencePoint({
                    side=killer_side,
                    name=Format(
                        LocalizeForSide(killer_side, "KILL_MARKER"),
                        {
                            known_name
                        }
                    ),
                    lat=killed.latitude,
                    lon=killed.longitude,
                    highlighted=true
                })
            end
        end
    end
end

function PBEM_ScoreSummary(score_tbl)
    local scoretxt = ""
    for i=1,#PBEM_PLAYABLE_SIDES do
        local sidename = PBEM_PLAYABLE_SIDES[i]
        local finalscore = score_tbl[i]
        scoretxt = scoretxt..'<center><b>'..sidename..':  '..finalscore..'</b></center><br/>'
    end
    return scoretxt
end

function PBEM_ShowTurnIntro()
    -- first deal with variable turn length issues
    if PBEM_HasVariableTurnLengths() then
        PBEM_CheckTacticalTime()
        PBEM_CheckIntermediateTime()
    end

    local cursidenum = Turn_GetCurSide()
    local turnnum = Turn_GetTurnNumber()
    local lossreport = ""
    -- show new contacts from previous turn
    local contacts = PBEM_GetContactRegister(cursidenum)
    if contacts ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("CONTACTS_REPORTED").."</u><br/><br/>"..contacts
        PBEM_SetContactRegister(cursidenum, "")
    end
    -- show hits from previous turn
    local hits = PBEM_GetHitRegister(cursidenum)
    if hits ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("HITS_REPORTED").."</u><br/><br/>"..hits
        PBEM_SetHitRegister(cursidenum, "")
    end
    -- show kills from previous turn
    local kills = PBEM_GetKillRegister(cursidenum)
    if kills ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("KILLS_REPORTED").."</u><br/><br/>"..kills
        PBEM_SetKillRegister(cursidenum, "")
    end
    -- show damages from previous turn
    local damages = PBEM_GetDamageRegister(cursidenum)
    if damages ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("DAMAGES_REPORTED").."</u><br/><br/>"..damages
        PBEM_SetDamageRegister(cursidenum, "")
    end
    -- show losses from previous turn
    local losses = PBEM_GetLossRegister(cursidenum)
    if losses ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("LOSSES_REPORTED").."</u><br/><br/>"..losses
        PBEM_SetLossRegister(cursidenum, "")
    end
    -- show fratricides from previous turn
    local frats = PBEM_GetFratricideRegister(cursidenum)
    if frats ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("FRATRICIDES_REPORTED").."</u><br/><br/>"..frats
        PBEM_SetFratricideRegister(cursidenum, "")
    end
    -- get any special messages we missed
    local prev_msgs = GetString("__SCEN_PREVMSGS_"..cursidenum)
    if prev_msgs ~= "" then
        lossreport = lossreport.."<br/><u>"..Localize("MESSAGES_RECEIVED").."</u><br/>"..prev_msgs
        StoreString("__SCEN_PREVMSGS_"..cursidenum, "")
    end
    local msg_header
    local turn_len_min = math.floor(PBEM_TURN_LENGTH / 60)
    local orderNumStr = Format(Localize("ORDER_PHASE_DIVIDER"), {
        "1",
        math.floor(PBEM_TURN_LENGTH / PBEM_ORDER_INTERVAL) + 1
    })
    msg_header = Format(Localize("START_ORDER_HEADER"), {
        PBEM_SIDENAME,
        tostring(turnnum),
        turn_len_min,
        orderNumStr
    })

    local msg = Message_Header(msg_header)
    msg = msg..Localize("START_ORDER_MESSAGE").."<br/><br/>"
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
            ScenEdit_SpecialMessage(
                message.target,
                Format(Localize("CHAT_MSG_FORM"), {
                    PBEM_PLAYABLE_SIDES[message.from],
                    message.msg
                })
            )
            PBEM_ClearScheduledMessage(message.from)
            table.remove(PBEM_SCHEDULED_MESSAGES, i)
        end
    end
end
