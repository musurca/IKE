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
        script="PBEM_ShowRemainingTime()",
        name="(PBEM) Show remaining time in turn",
        desc="Display the remaining time before your PBEM turn ends."
    },
    {
        script="PBEM_SendChatMessage()",
        name="(PBEM) Send message to other player",
        desc="Sends a message to another player, to be delivered at the start of their next turn. Note that the maximum message length is 280 characters, and that HTML tags will be removed."
    },
    {
        script="PBEM_UserChangePosture()",
        name="(PBEM) Change posture towards a side",
        desc="Changes your posture toward a side. Useful if you've accidentally attacked some civilians and don't want them to be hostile anymore."
    }
}

function PBEM_SendChatMessage()
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
    local message = RStrip(Input_String(Format(Localize("ENTER_CHAT"), {
        targetside
    })))
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
    ScenEdit_SpecialMessage(targetside, Format(Localize("CHAT_MSG_FORM"), {
        myside,
        message
    }))
    Input_OK(Localize("CHAT_SENT"))
end

function PBEM_ShowRemainingTime()
    if Turn_GetTurnNumber() == 0 and PBEM_SETUP_PHASE then
        Input_OK(Localize("SHOW_REMAINING_SETUP"))
    else
        local timeLeft = PBEM_GetNextTurnStartTime() - ScenEdit_CurrentTime()
        local timeStrings = {}

        local hrs = math.floor(timeLeft / (60*60))
        local min = math.floor((timeLeft - hrs*60*60) / 60)
        local sec = math.floor(timeLeft - hrs*60*60 - min*60)
        
        local msg = Format(Localize("SHOW_REMAINING_TIME"), {PadDigits(hrs), PadDigits(min), PadDigits(sec)})
        Input_OK(msg)
    end
end

function PBEM_UserChangePosture()
    local sidelist = ""
    local myside = Turn_GetCurSideName()
    local non_player_sides = {}
    for k,side in ipairs(VP_GetSides()) do
        if side.name ~= myside and side.name ~= PBEM_DUMMY_SIDE then
            table.insert(non_player_sides, side.name)
        end
    end
    for k,sidename in ipairs(non_player_sides) do
        sidelist = sidelist..sidename
        if k ~= #non_player_sides then
            sidelist = sidelist..", "
        end
    end
    local side_input = Input_String(Format(Localize("CHANGE_POSTURE"), {
        sidelist
    }))
    side_input = RStrip(side_input)
    if side_input == "" then
        return
    end
    --match it regardless of case
    local side_to_change = ""
    for k,sidename in ipairs(non_player_sides) do
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
    local posture_map = {
        ["F"] = "FRIENDLY",
        ["N"] = "NEUTRAL",
        ["U"] = "UNFRIENDLY",
        ["H"] = "HOSTILE"
    }
    local curposture = posture_map[ScenEdit_GetSidePosture(myside, side_to_change)]
    local newposture = Input_String(Format(Localize("SET_POSTURE"), {
        side_to_change,
        curposture
    }))
    newposture = RStrip(string.upper(newposture))
    if newposture == "" then
        return
    end
    local postures = {"FRIENDLY", "NEUTRAL", "UNFRIENDLY", "HOSTILE"}
    if not IsIn(newposture, postures) then
        Input_OK(Format(Localize("NO_POSTURE_FOUND"), {
            newposture
        }))
        return
    end
    ScenEdit_SetSidePosture(myside, side_to_change, string.sub(newposture, 1, 1))
    Input_OK(Format(Localize("POSTURE_IS_SET"), {
        side_to_change,
        newposture
    }))
end

function PBEM_AddRTSide(side)
    ForEachDo(IKE_SPECACTIONS, function(action)
            ScenEdit_AddSpecialAction({
                ActionNameOrID=action.name,
                Description=action.desc,
                Side=side,
                IsActive=true, 
                IsRepeatable=true,
                ScriptText=action.script
            })
    end)
end

function PBEM_RemoveRTSide(side)
    ForEachDo(IKE_SPECACTIONS, function(action)
        pcall(ScenEdit_SetSpecialAction, {
            ActionNameOrID=action.name,
            Side=side,
            mode="remove"
        })
    end)
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

