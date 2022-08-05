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
        
        local msg = Format(Localize("SHOW_REMAINING_TIME"), {PadDigits(hrs), PadDigits(min), PadDigits(sec)})
        Input_OK(msg)
    end
end

function PBEM_AddRTSide(side)
    local ds = PBEM_ConstructDummySideName(side)

    ForEachDo(IKE_SPECACTIONS, function(action)
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

    if #PBEM_PLAYABLE_SIDES == 2 then
        ForEachDo(IKE_TWOP_ACTIONS, function(action)
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
end

function PBEM_RemoveRTSide(side)
    local ds = PBEM_ConstructDummySideName(side)

    ForEachDo(IKE_SPECACTIONS, function(action)
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

    if #PBEM_PLAYABLE_SIDES == 2 then
        ForEachDo(IKE_TWOP_ACTIONS, function(action)
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