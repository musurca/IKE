--[[
----------------------------------------------
IKE
pbem_specactions.lua
----------------------------------------------

Contains definitions for the PBEM-specific
special actions

----------------------------------------------
]]--

local IKE_SPECACTIONS = {
    {
        script = "PBEM_ShowIKEVersion()",
        name   = Localize("SPEC_SHOWVERSION_NAME"),
        desc   = Localize("SPEC_SHOWVERSION_DESC")
    },
    {
        script = "PBEM_ShowRemainingTime()",
        name   = Localize("SPEC_SHOWTIME_NAME"),
        desc   = Localize("SPEC_SHOWTIME_DESC")
    },
    {
        script = "PBEM_SendChatMessage()",
        name   = Localize("SPEC_SENDMSG_NAME"),
        desc   = Localize("SPEC_SENDMSG_DESC")
    },
    {
        script = "PBEM_SendChatMessage(true)",
        name   = Localize("SPEC_SCHEDMSG_NAME"),
        desc   = Localize("SPEC_SCHEDMSG_DESC")
    },
    {
        script = "PBEM_EnterPassword()",
        name   = Localize("SPEC_PASSCHANGE_NAME"),
        desc   = Localize("SPEC_PASSCHANGE_DESC")
    },
    {
        script = "PBEM_ActionSetUserPreferences()",
        name   = Localize("SPEC_SETPREF_NAME"),
        desc   = Localize("SPEC_SETPREF_DESC")
    }
}

local IKE_TWOP_ACTIONS = {
    {
        script = "PBEM_ResignMatch()",
        name   = Localize("SPEC_RESIGN_NAME"),
        desc   = Localize("SPEC_RESIGN_DESC")
    },
    {
        script = "PBEM_OfferDraw()",
        name   = Localize("SPEC_DRAW_NAME"),
        desc   = Localize("SPEC_DRAW_DESC")
    }
}

local IKE_COOP_ACTIONS = {
    {
        script = "PBEM_ShareMarkpoints()",
        name   = Localize("SPEC_SHAREMP_NAME"),
        desc   = Localize("SPEC_SHAREMP_DESC")
    }
}

function PBEM_ShowIKEVersion()
    Input_OK(
        Format(
            Localize("MSG_IKE_VERSION"),
            {
                IKE_VERSION
            }
        )
    )
end

function PBEM_OfferDraw()
    if Turn_GetTurnNumber() == 0 and PBEM_SETUP_PHASE then
        Input_OK(Localize("DRAW_NOSETUP"))
        return
    end

    local offered = GetBoolean("__PBEM_DRAWOFFERED")
    if not offered then
        if Input_YesNo(Localize("DRAW_WILLOFFER")) then
            StoreBoolean("__PBEM_DRAWOFFERED", true)
            Input_OK(Localize("DRAW_OFFERED"))
        end
    else
        Input_OK(Localize("DRAW_ALREADY"))
    end
end

function PBEM_ResignMatch()
    if Input_YesNo(Localize("RESIGN_ARESURE")) then
        local otherside = ""
        for n, sidename in ipairs(PBEM_PLAYABLE_SIDES) do
            if sidename ~= PBEM_SIDENAME then
                otherside = sidename
                break
            end
        end
        local msg = Format(
            Localize("RESIGN_RESIGNED"),
            {PBEM_SIDENAME}
        )
        local newscore = ScenEdit_GetScore(otherside)
        if newscore == 0 then
            ScenEdit_SetScore(otherside, 1, msg)
            ScenEdit_SetScore(PBEM_ConstructDummySideName(otherside), 1, msg)
            newscore = 1
        end
        local myscore = ScenEdit_GetScore(PBEM_SIDENAME)
        if myscore > newscore then
            myscore = newscore - 1
            ScenEdit_SetScore(PBEM_SIDENAME, myscore, msg)
            ScenEdit_SetScore(PBEM_ConstructDummySideName(PBEM_SIDENAME), myscore, msg)
        end
        ScenEdit_EndScenario()
    end
end

function PBEM_SendChatMessage(scheduled)
    scheduled = scheduled or false

    local side_num = Turn_GetCurSide()

    if scheduled then
        local base_id = "__SCEN_SCHEDULEDMSG_"..side_num
        if GetBoolean(base_id) then
            Input_OK(Localize("CHAT_ALREADY_SCHEDULED"))
            return
        end
    end

    local targetside = ""
    local myside = Turn_GetCurSideName()
    -- if there's only two sides, pick the other one
    if #PBEM_PLAYABLE_SIDES == 2 then
        for i=1,#PBEM_PLAYABLE_SIDES do
            if PBEM_PLAYABLE_SIDES[i] ~= myside then
                targetside = PBEM_PLAYABLE_SIDES[i]
                break
            end
        end
        if targetside == "" then
            return
        end
    else
        -- otherwise, let the player choose
        local sidelist = ""
        for i=1, #PBEM_PLAYABLE_SIDES do
            if PBEM_PLAYABLE_SIDES[i] ~= myside then
                sidelist = sidelist..PBEM_PLAYABLE_SIDES[i]
                if i ~= #PBEM_PLAYABLE_SIDES then
                    sidelist = sidelist..", "
                end
            end
        end
        local side_input = Input_String(Format(Localize("SEND_CHAT"), {
            sidelist
        }))
        side_input = RStrip(side_input)
        if side_input == "" then
            Input_OK(Localize("CHAT_CANCELLED"))
            return
        end
        --match it regardless of case
        local side_to_change = ""
        for k,sidename in ipairs(PBEM_PLAYABLE_SIDES) do
            local check_a = string.upper(side_input)
            local check_b = string.upper(sidename)
            if check_a == check_b then
                side_to_change = sidename
                break
            end
        end
        if side_to_change == "" then
            Input_OK(Format(Localize("NO_SIDE_FOUND"), {
                side_input
            }))
            return
        end
        targetside = side_to_change
    end
    local message = RStrip(
        Input_String(
            Format(Localize("ENTER_CHAT"), {
                targetside
            })
        )
    )
    if message == "" then
        Input_OK(Localize("CHAT_CANCELLED"))
        return
    end
    -- eliminate any html tags with (gasp) a regular expression.
    -- yes, Stack Overflow, I know we're not supposed to do this.
    message = string.gsub(message, "(<[^>]*>)", "")
    -- trim to length limit
    if #message > 280 then
        message = string.sub(message, 1, 280)
    end

    if scheduled then
        --ask the player to choose a time
        local time_parsed = false
        while not time_parsed do
            local sched_time = RStrip(
                Input_String(Localize("SCHEDULE_CHAT"))
            )
            local time_table = {}
            string.gsub(sched_time, "(%d+)", function(n)
                table.insert(time_table, tonumber(n))
            end)
            if #time_table ~= 3 then
                if not Input_YesNo(Localize("FORMAT_INCORRECT")) then
                    Input_OK(Localize("CHAT_CANCELLED"))
                    return
                end 
            else
                local delivery_time = ScenEdit_CurrentTime()
                local hour, minute, second = time_table[1], time_table[2], time_table[3]
                local time_correct = true
                if minute > 59 then
                    if not Input_YesNo(Localize("MIN_INCORRECT")) then
                        Input_OK(Localize("CHAT_CANCELLED"))
                        return
                    end
                    time_correct = false
                end
                if second > 59 then
                    if not Input_YesNo(Localize("SEC_INCORRECT")) then
                        Input_OK(Localize("CHAT_CANCELLED"))
                        return
                    end
                    time_correct = false
                end
                if time_correct then
                    delivery_time = delivery_time + hour*60*60 + minute*60 + second
                    if Input_YesNo(Format(Localize("CHECK_CHAT_DATE"), {
                        PBEM_CustomTimeMilitary(delivery_time)
                    })) then
                        PBEM_MakeScheduledMessage(side_num, targetside, delivery_time, message)
                        time_parsed = true
                    else
                        if not Input_YesNo(Localize("CHAT_TRY_AGAIN")) then
                            Input_OK(Localize("CHAT_CANCELLED"))
                            return
                        end
                    end
                end
            end
        end
    else
        --deliver the message immediately
        ScenEdit_SpecialMessage(
            targetside,
            Format(Localize("CHAT_MSG_FORM"), {
                myside,
                message
            })
        )
    end
    Input_OK(Localize("CHAT_SENT"))
end

function PBEM_ShowRemainingTime()
    if Turn_GetTurnNumber() == 0 and PBEM_SETUP_PHASE then
        Input_OK(Localize("SHOW_REMAINING_SETUP"))
    else
        local timeLeft = PBEM_GetNextTurnStartTime() - ScenEdit_CurrentTime()

        local hrs = math.floor(timeLeft / (60*60))
        local min = math.floor((timeLeft - hrs*60*60) / 60)
        local sec = math.floor(timeLeft - hrs*60*60 - min*60)
        
        local msg = Format(
            Localize("SHOW_REMAINING_TIME"), 
            {
                PadDigits(hrs), 
                PadDigits(min), 
                PadDigits(sec)
            }
        )
        Input_OK(msg)
    end
end

function PBEM_AddSpecialActionTable(side, tbl)
    local ds = PBEM_ConstructDummySideName(side)

    ForEachDo(tbl, function(action)
        ScenEdit_AddSpecialAction({
            ActionNameOrID=action.name,
            Description=action.desc,
            Side=side,
            IsActive=true,
            IsRepeatable=true,
            ScriptText=action.script
        })
        ScenEdit_AddSpecialAction({
            ActionNameOrID=action.name,
            Description=action.desc,
            Side=ds,
            IsActive=true,
            IsRepeatable=true,
            ScriptText=action.script
        })
    end)
end

function PBEM_RemoveSpecialActionTable(side, tbl)
    local ds = PBEM_ConstructDummySideName(side)

    ForEachDo(tbl, function(action)
        pcall(ScenEdit_SetSpecialAction, {
            ActionNameOrID=action.name,
            Side=side,
            mode="remove"
        })
        pcall(ScenEdit_SetSpecialAction, {
            ActionNameOrID=action.name,
            Side=ds,
            mode="remove"
        })
    end)
end

function PBEM_AddRTSide(side)
    PBEM_AddSpecialActionTable(side, IKE_SPECACTIONS)

    if #PBEM_PLAYABLE_SIDES == 2 then
        PBEM_AddSpecialActionTable(side, IKE_TWOP_ACTIONS)
    end

    if GetBoolean(
        "__SCEN_ISCOOPFOR_"..PBEM_SideNumberByName(side)
    ) == true then
        PBEM_AddSpecialActionTable(side, IKE_COOP_ACTIONS)
    end
end

function PBEM_RemoveRTSide(side)
    PBEM_RemoveSpecialActionTable(side, IKE_SPECACTIONS)

    if #PBEM_PLAYABLE_SIDES == 2 then
        PBEM_RemoveSpecialActionTable(side, IKE_TWOP_ACTIONS)
    end

    if GetBoolean(
        "__SCEN_ISCOOPFOR_"..PBEM_SideNumberByName(side)
    ) == true then
        PBEM_RemoveSpecialActionTable(side, IKE_COOP_ACTIONS)
    end
end

function PBEM_AddActionTacticalTimeSide(side)
    local tac_len_min = math.floor(
        GetNumber("__SCEN_TACTICAL_LENGTH") / 60
    )
    local action_name = Format(
        LocalizeForSide(side, "SPEC_TACTICAL_NAME"),
        {tac_len_min}
    )
    local action_desc = Format(
        LocalizeForSide(side, "SPEC_TACTICAL_DESC"),
        {tac_len_min}
    )

    ScenEdit_AddSpecialAction({
        ActionNameOrID=action_name,
        Description=action_desc,
        Side=side,
        IsActive=true,
        IsRepeatable=true,
        ScriptText="PBEM_EnterTacticalTime()"
    })

    local ds = PBEM_ConstructDummySideName(side)
    ScenEdit_AddSpecialAction({
        ActionNameOrID=action_name,
        Description=action_desc,
        Side=ds,
        IsActive=true,
        IsRepeatable=true,
        ScriptText="PBEM_EnterTacticalTime()"
    })
end

function PBEM_RemoveActionTacticalTimeSide(side)
    local tac_len_min = math.floor(
        GetNumber("__SCEN_TACTICAL_LENGTH") / 60
    )
    local action_name = Format(
        LocalizeForSide(side, "SPEC_TACTICAL_NAME"),
        {tac_len_min}
    )

    pcall(ScenEdit_SetSpecialAction, {
        ActionNameOrID=action_name,
        Side=side,
        mode="remove"
    })

    local ds = PBEM_ConstructDummySideName(side)
    pcall(ScenEdit_SetSpecialAction, {
        ActionNameOrID=action_name,
        Side=ds,
        mode="remove"
    })
end

function PBEM_EnterTacticalTime()
    if Turn_GetTurnNumber() == 0 and PBEM_SETUP_PHASE then
        Input_OK(Localize("TACTICAL_SETUP"))
        return
    end

    if ScenEdit_CurrentTime() ~= PBEM_GetCurTurnStartTime() then
        Input_OK(Localize("TACTICAL_NOTSTART"))
        return
    end

    -- remove this action
    PBEM_RemoveActionTacticalTimeSide(PBEM_SIDENAME)

    -- add the intermediate time action
    PBEM_AddActionIntermediateTimeSide(PBEM_SIDENAME)

    -- Set the tactical turn length
    local tac_len = GetNumber("__SCEN_TACTICAL_LENGTH")
    PBEM_SetTurnLength(tac_len)
    local tac_len_min = math.floor(tac_len / 60)
    Input_OK(
        Format( Localize("TACTICAL_ENTERED"), { tac_len_min } )
    )
    StoreBoolean("__SCEN_TIME_INTERMEDIATE", false)

    -- disable notification since we initiated it
    local sidenum = PBEM_SideNumberByName(PBEM_SIDENAME)
    StoreBoolean("__SCEN_WASINTERMEDIATE_"..sidenum, false)
end

function PBEM_CheckTacticalTime()
    if GetBoolean("__SCEN_TIME_INTERMEDIATE") == false then
        local sidenum = PBEM_SideNumberByName(PBEM_SIDENAME)
        if GetBoolean("__SCEN_WASINTERMEDIATE_"..sidenum) == true then
            StoreBoolean("__SCEN_WASINTERMEDIATE_"..sidenum, false)

            -- remove the tactical action
            PBEM_RemoveActionTacticalTimeSide(PBEM_SIDENAME)

            -- add the intermediate time action
            PBEM_AddActionIntermediateTimeSide(PBEM_SIDENAME)

            --notify that tactical time has started
            local tac_len_min = math.floor(GetNumber("__SCEN_TACTICAL_LENGTH") / 60)
            Input_OK(
                Format(
                    Localize("TACTICAL_INITIATED"),
                    { tac_len_min }
                )
            )
        end
    end
end

function PBEM_AddActionIntermediateTimeSide(side)
    local intermed_len = GetNumber("__SCEN_INTERMED_LENGTH")
    local intermed_len_min = math.floor(intermed_len / 60)
    local action_name = Format(
        LocalizeForSide(side, "SPEC_INTERMEDIATE_NAME"),
        { intermed_len_min }
    )
    local action_desc = Format(
        LocalizeForSide(side, "SPEC_INTERMEDIATE_DESC"),
        { intermed_len_min }
    )

    ScenEdit_AddSpecialAction({
        ActionNameOrID=action_name,
        Description=action_desc,
        Side=side,
        IsActive=true,
        IsRepeatable=true,
        ScriptText="PBEM_EnterIntermediateTime()"
    })

    local ds = PBEM_ConstructDummySideName(side)
    ScenEdit_AddSpecialAction({
        ActionNameOrID=action_name,
        Description=action_desc,
        Side=ds,
        IsActive=true,
        IsRepeatable=true,
        ScriptText="PBEM_EnterIntermediateTime()"
    })
end

function PBEM_RemoveActionIntermediateTimeSide(side)
    local intermed_len = GetNumber("__SCEN_INTERMED_LENGTH")
    local intermed_len_min = math.floor(intermed_len / 60)
    local action_name = Format(
        LocalizeForSide(side, "SPEC_INTERMEDIATE_NAME"),
        { intermed_len_min }
    )

    pcall(ScenEdit_SetSpecialAction, {
        ActionNameOrID=action_name,
        Side=side,
        mode="remove"
    })

    local ds = PBEM_ConstructDummySideName(side)
    pcall(ScenEdit_SetSpecialAction, {
        ActionNameOrID=action_name,
        Side=ds,
        mode="remove"
    })
end

function PBEM_EnterIntermediateTime()
    local offered = GetBoolean("__PBEM_INTERMEDIATEOFFERED")
    if not offered then
        if Input_YesNo(Localize("INTERMEDIATE_WILLOFFER")) then
            StoreBoolean("__PBEM_INTERMEDIATEOFFERED", true)
            StoreNumber("__PBEM_INTERMEDIATE_VOTES", 1)
            Input_OK(Localize("INTERMEDIATE_OFFERED"))
        end
    else
        Input_OK(Localize("INTERMEDIATE_ALREADY"))
    end
end

function PBEM_CheckIntermediateTime()
    if GetBoolean("__SCEN_TIME_INTERMEDIATE") == false then
        local offered = GetBoolean("__PBEM_INTERMEDIATEOFFERED")
        if offered then
            local intermed_len = GetNumber("__SCEN_INTERMED_LENGTH")
            local intermed_len_min = math.floor(intermed_len / 60)
        
            local msg = Format(Localize("INTERMEDIATE_HASOFFER"), {intermed_len_min})
            if Input_YesNo(msg) then
                local votes = GetNumber("__PBEM_INTERMEDIATE_VOTES")
                votes = votes + 1
                if votes == #PBEM_PLAYABLE_SIDES then
                    -- enter intermediate turn time
                    StoreBoolean("__SCEN_TIME_INTERMEDIATE", true)
                    local sidenum = PBEM_SideNumberByName(PBEM_SIDENAME)
                    StoreBoolean("__SCEN_WASINTERMEDIATE_"..sidenum, true)

                    -- add the tactical action
                    PBEM_AddActionTacticalTimeSide(PBEM_SIDENAME)

                    -- remove the intermediate action
                    PBEM_RemoveActionIntermediateTimeSide(PBEM_SIDENAME)

                    PBEM_SetTurnLength(intermed_len)
                    Input_OK(
                        Format(
                            Localize("INTERMEDIATE_ENTERED"),
                            { intermed_len_min }
                        )
                    )

                    StoreBoolean("__PBEM_INTERMEDIATEOFFERED", false)
                    StoreNumber("__PBEM_INTERMEDIATE_VOTES", 0)
                else
                    --register the vote and move on
                    StoreNumber("__PBEM_INTERMEDIATE_VOTES", votes)
                    Input_OK(Localize("INTERMEDIATE_VOTED"))
                end
            else
                --decline intermediate time and end the vote
                Input_OK(Localize("INTERMEDIATE_DECLINED"))

                StoreBoolean("__PBEM_INTERMEDIATEOFFERED", false)
                StoreNumber("__PBEM_INTERMEDIATE_VOTES", 0)
            end
        end
    else
        local sidenum = PBEM_SideNumberByName(PBEM_SIDENAME)
        if GetBoolean("__SCEN_WASINTERMEDIATE_"..sidenum) == false then
            StoreBoolean("__SCEN_WASINTERMEDIATE_"..sidenum, true)

            -- add the tactical action
            PBEM_AddActionTacticalTimeSide(PBEM_SIDENAME)

            -- remove the intermediate action
            PBEM_RemoveActionIntermediateTimeSide(PBEM_SIDENAME)

            local intermed_len_min = math.floor(GetNumber("__SCEN_INTERMED_LENGTH") / 60)
            Input_OK(
                Format(
                    Localize("INTERMEDIATE_ENTERED"),
                    { intermed_len_min }
                )
            )
        end
    end
end

function PBEM_ActionSetUserPreferences()
    for _, pref in ipairs(IKE_PREFERENCES_DEFAULT) do
        local pref_key = pref[IKE_PREF_KEY]
        local old_pref_val = BooleanToString(
            PBEM_GetPreference(pref_key)
        )
        local new_pref_val = Input_YesNo(
            Format(
                Localize("ASK_"..pref_key),
                {
                    Format(
                        Localize("CURRENT_SETTING"), 
                        {old_pref_val}
                    )
                }
            )
        )
        PBEM_SetPreference(pref_key, new_pref_val)
    end

    Input_OK(
        Localize("PREFERENCES_NOW_SET")
    )
end

function PBEM_ShareMarkpoints()
    local cursidename = Turn_GetCurSideName()
    -- can only share reference points during the order phase
    if __PBEM_FN_PLAYERSIDE() ~= cursidename then
        Input_OK(Localize("SHARE_RP_NOT_ORDERPHASE"))
        return
    end

    local sidetable = VP_GetSide({side=cursidename})
    local selected_rps = {}
    for k, rp in ipairs(sidetable.rps) do
        if rp.highlighted == true then
            table.insert(selected_rps, rp)
        end
    end
    if #selected_rps == 0 then
        Input_OK(Localize("NO_RPS_SELECTED"))
        return
    end

    local allied_sides = {}
    for k, side in ipairs(PBEM_PLAYABLE_SIDES) do
        if side ~= cursidename then
            if ScenEdit_GetSidePosture(
                cursidename,
                side
            ) == "F" then
                table.insert(allied_sides, side)
            end
        end
    end
    
    -- make sure that an allied side exists
    if #allied_sides == 0 then
        Input_OK("SHARE_RP_NO_SIDE_AVAIL")
        return
    end

    local share_side = allied_sides[1]
    if #allied_sides > 1 then
        -- ask user to choose an allied side
        local sidelist = ""
        for k, other_side in ipairs(allied_sides) do
            sidelist = sidelist..other_side
            if k ~= #allied_sides then
                sidelist = sidelist..", "
            end
        end
        local side_input = Input_String(
            Format(
                Localize("SHARE_RP_WHICH_SIDE"),
                { sidelist }
            )
        )
        side_input = RStrip(
            string.upper(side_input)
        )
        if side_input == "" then
            Input_OK(Localize("SHARE_RP_CANCELLED"))
            return
        end
        --match it regardless of case
        for k, other_side in ipairs(allied_sides) do
            if side_input == string.upper(other_side) then
                share_side = other_side
                break
            end
        end
        if share_side == "" then
            Input_OK(
                Format(
                    Localize("NO_SIDE_FOUND"),
                    {side_input}
                )
            )
            return
        end
    end

    local rp_list = ""
    for k, rp in ipairs(selected_rps) do
        pcall(
            ScenEdit_AddReferencePoint,
            {
                side=share_side,
                name=Format(
                    LocalizeForSide(share_side, "MARKPOINT_NAME"),
                    {share_side, rp.name}
                ),
                lat=rp.latitude,
                lon=rp.longitude,
                highlighted=true
            }
        )
        rp_list = rp_list..rp.name
        if k ~= #selected_rps then
            rp_list = rp_list..", "
        end
    end

    -- deselect reference points after sharing
    for k, rp in ipairs(selected_rps) do
        rp.highlighted = false
    end

    Input_OK(
        Format(
            Localize("SHARE_RP_SUCCESSFUL"),
            {rp_list, share_side}
        )
    )
end