--[[
----------------------------------------------
IKE
pbem_specactions.lua
----------------------------------------------

Contains definitions for the PBEM-specific
special actions

----------------------------------------------
]]--

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
    ScenEdit_AddSpecialAction({
        ActionNameOrID='PBEM: Change posture towards a side',
        Description="Changes your posture toward a side. Useful if you've accidentally attacked some civilians and don't want them to be hostile anymore.",
        Side=side,
        IsActive=true, 
        IsRepeatable=true,
        ScriptText='PBEM_UserChangePosture()'
    })

    ScenEdit_AddSpecialAction({
        ActionNameOrID='PBEM: Show remaining time in turn',
        Description="Display the remaining time before your PBEM turn ends.",
        Side=side,
        IsActive=true, 
        IsRepeatable=true,
        ScriptText='PBEM_ShowRemainingTime()'
    })
end

function PBEM_RemoveRTSide(side)
    pcall(ScenEdit_SetSpecialAction, {
        ActionNameOrID='PBEM: Show remaining time in turn',
        Side=side,
        mode="remove"
    })
    pcall(ScenEdit_SetSpecialAction, {
        ActionNameOrID='PBEM: Change posture towards a side',
        Side=side,
        mode="remove"
    })
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

