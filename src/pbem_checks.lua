--[[
----------------------------------------------
IKE
pbem_checks.lua
----------------------------------------------

Contains various checks to determine whether game
can begin (passwords, build versions, etc).

----------------------------------------------
]]--

IKE_MIN_ALLOWED_BUILD_MAJOR = 1268
IKE_MIN_ALLOWED_BUILD_MINOR = 1

function PBEM_EnterPassword()
    local passwordsMatch = false
    local attemptNum = 0
    local pass = ""
    while not passwordsMatch do
        attemptNum = attemptNum + 1
        local msg = ""
        if attemptNum > 1 then
            msg = Localize("PASSWORDS_DIDNT_MATCH")
        else
            msg = Format(Localize("CHOOSE_PASSWORD"), {
                PBEM_SIDENAME
            })
        end
        pass = Input_String(msg)
        local passcheck = Input_String(Localize("CONFIRM_PASSWORD"))
        if pass == passcheck then
            passwordsMatch = true
        end
    end
    PBEM_SetPassword(Turn_GetCurSide(), pass)
end

function PBEM_SetPassword(sidenum, password)
    StoreString("__SIDE_"..tostring(sidenum).."_PASSWD", md5.Calc(password))
end

function PBEM_VerifyPassword()
    local passwordAccepted = false
    while not passwordAccepted do
        local pass = Input_String(Format(Localize("ENTER_PASSWORD"), {
            PBEM_SIDENAME,
            Turn_GetTurnNumber()
        }))
        if PBEM_CheckPassword(Turn_GetCurSide(), pass) then
            passwordAccepted = true
        else
            local choice = ScenEdit_MsgBox(Localize("WRONG_PASSWORD"), 5)
            if choice ~= 'Retry' then
                return false
            end
        end
    end
    return true
end

function PBEM_CheckPassword(sidenum, password)
    local hash = GetString("__SIDE_"..tostring(sidenum).."_PASSWD")
    return hash == md5.Calc(password)
end

function PBEM_SetHostBuildNumber()
    StoreString("__PBEM_HOST_BUILDNUM", GetBuildNumber())
end

function PBEM_CheckHostBuildNumber()
    local mybuild = GetBuildNumber()
    local hostbuild = GetString("__PBEM_HOST_BUILDNUM")
    if Turn_GetCurSide() == 1 then
        if hostbuild ~= mybuild then
            PBEM_SetHostBuildNumber()
            Input_OK(Format(Localize("VERSION_UPGRADE"), {mybuild}))
        end
    else
        if mybuild ~= hostbuild then
            Input_OK(Format(Localize("VERSION_MISMATCH"), {
                mybuild,
                hostbuild
            }))
            return false
        end
    end
    return true
end

function PBEM_UserCheckSettings()
    local scentitle = VP_GetScenario().Title
    if Input_YesNo(Format(Localize("GAME_START"), {scentitle})) then
        -- use recommended settings
        return
    end

    --determine whether you use constant turn lengths
    local variable_turn_lengths = GetBoolean("__SCEN_VAR_TURN_LENGTHS")
    local prev_var_tl = variable_turn_lengths
    local turn_length = 0
    local intermed_length = 0
    local tactical_length = 0
    local tl_msg = Format(
        "%1\n\n%2",
        {
            Localize("WIZARD_CONST_TURN_LENGTHS"),
            Format(Localize("RECOMMENDED"), {
                BooleanToString(not variable_turn_lengths)
            })
        }
    )
    if Input_YesNo(tl_msg) then
        variable_turn_lengths = false
        --determine turn length
        local default_length = math.floor(PBEM_TURN_LENGTH/60)
        local turnLengthSec = Input_Number_Default(
            Format("%1\n\n%2", {
                Localize("WIZARD_TURN_LENGTH"),
                Format(Localize("RECOMMENDED"), {
                    default_length
                })
            }),
            default_length
        )
        turnLengthSec = math.max(0, math.floor(turnLengthSec))
        if turnLengthSec == 0 then
            turnLengthSec = default_length
        end
        turn_length = turnLengthSec * 60
    else
        variable_turn_lengths = true

        --determine length of Intermediate turn
        local def_intermed_length = math.floor(
            GetNumber("__SCEN_INTERMED_LENGTH") / 60
        )
        if def_intermed_length == 0 then
            def_intermed_length = 30
        end
        local intermed_turn_length_min = 0
        while intermed_turn_length_min == 0 do
            intermed_turn_length_min = Input_Number_Default(
                Format("%1\n\n%2", {
                    Localize("WIZARD_INTERMEDIATE_LENGTH"),
                    Format(Localize("RECOMMENDED"), {
                        def_intermed_length
                    })
                }),
                def_intermed_length
            )
            intermed_turn_length_min = math.max(0, math.floor(intermed_turn_length_min))
            if intermed_turn_length_min == 0 then
                Input_OK(Localize("WIZARD_ZERO_LENGTH"))
            end
        end
        intermed_length = intermed_turn_length_min * 60
        turn_length = intermed_length
        
        -- determine length of Tactical turn
        local def_tactical_length = math.floor(
            GetNumber("__SCEN_TACTICAL_LENGTH") / 60
        )
        if def_tactical_length == 0 then
            def_tactical_length = 5
        end
        local tactical_turn_length_min = 0
        while tactical_turn_length_min == 0 do
            tactical_turn_length_min = Input_Number_Default(
                Format("%1\n\n%2", {
                    Localize("WIZARD_TACTICAL_LENGTH"),
                    Format(Localize("RECOMMENDED"), {
                        def_tactical_length
                    })
                }),
                def_tactical_length
            )
            tactical_turn_length_min = math.max(0, math.floor(tactical_turn_length_min))
            if tactical_turn_length_min == 0 then
                Input_OK(Localize("WIZARD_ZERO_LENGTH"))
            end
        end
        tactical_length = tactical_turn_length_min * 60
    end

    local order_phases = {}
    --number of orders per turn
    local sidenum = 1
    ForEachDo(PBEM_PLAYABLE_SIDES, function(side)
        local orderNumber = 0
        while orderNumber == 0 do
            local rec_msg = ""
            local rec_orders = 0
            -- we add one to the order number for the final order phase
            rec_orders = PBEM_ORDER_PHASES[sidenum] + 1
            rec_msg = "\n\n"..Format(Localize("RECOMMENDED"), {rec_orders})

            orderNumber = Input_Number_Default(
                Format(Localize("WIZARD_ORDER_NUMBER"), {
                    side
                })..rec_msg,
                rec_orders
            )
            orderNumber = math.max(2, math.floor(orderNumber)) - 1
        end
        table.insert(order_phases, orderNumber)
        sidenum = sidenum + 1
    end)
    
    --turn order
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
    local playableSides = {}
    for k, side in ipairs(PBEM_PLAYABLE_SIDES) do
        table.insert(playableSides, side)
    end
    local ranks_to_set = math.min(#playableSides-1, 9)
    local rank = 1
    while not order_set do
        for i=rank, #playableSides do
            local input_order_msg = Format("%1\n\n%2", {
                Format(Localize("WIZARD_GO_ORDER"), {
                    playableSides[i],
                    order_messages[rank]
                }),
                Format(Localize("RECOMMENDED"), {
                    BooleanToString(i==rank)
                })
            })
            if Input_YesNo(input_order_msg) then
                local temp_side = playableSides[rank]
                playableSides[rank] = playableSides[i]
                playableSides[i] = temp_side

                temp_side = order_phases[rank]
                order_phases[rank] = order_phases[i]
                order_phases[i] = temp_side

                rank = rank + 1
                break
            end
        end
        if rank > ranks_to_set then
            order_set = true
        end
    end
    --editor mode
    local prevent_editor = Input_YesNo(Localize("WIZARD_PREVENT_EDITOR").."\n\n"..Format(Localize("RECOMMENDED"), {
        BooleanToString(GetBoolean("__SCEN_PREVENTEDITOR"))
    }))
    -- confirm settings
    Input_OK(Format(Localize("CONFIRM_SETTINGS"), {
        scentitle,
        playableSides[1]
    }))

    -- commit to settings
    StoreNumberArray('__SCEN_ORDERINTERVAL', order_phases)
    PBEM_PLAYABLE_SIDES = playableSides
    StoreStringArray("__SCEN_PLAYABLESIDES", PBEM_PLAYABLE_SIDES)
    StoreBoolean("__SCEN_PREVENTEDITOR", prevent_editor)
    StoreNumber("__SCEN_TURN_LENGTH", turn_length)
    if variable_turn_lengths then
        StoreBoolean("__SCEN_VAR_TURN_LENGTHS", true)
        StoreBoolean("__SCEN_TIME_INTERMEDIATE", true)
        StoreNumber("__SCEN_INTERMED_LENGTH", intermed_length)
        StoreNumber("__SCEN_TACTICAL_LENGTH", tactical_length)

        if prev_var_tl == false then
            for i, v in ipairs(PBEM_PLAYABLE_SIDES) do
                StoreBoolean("__SCEN_WASINTERMEDIATE_"..i, true)
            end
        end
    else
        StoreBoolean("__SCEN_VAR_TURN_LENGTHS", false)
    end

    -- reinit the scenario globals
    PBEM_InitScenGlobals()
end

function PBEM_SelfDestruct()
    local sides = VP_GetSides()
    for i=1,#sides do
        StoreString("__SIDE_"..tostring(i).."_PASSWD","")
        ScenEdit_RemoveSide({side=sides[i].name})
    end
    if Event_Exists("PBEM: Scenario Loaded") then
        Event_Delete("PBEM: Scenario Loaded", true)
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
    PBEM_EndAPIReplace()
end

function PBEM_CheckDraw()
    local draw_offered = GetBoolean("__PBEM_DRAWOFFERED")
    if draw_offered then
        if Input_YesNo(Localize("DRAW_ACCEPT")) then
            if Input_YesNo(Localize("DRAW_ARESURE")) then
                local otherside = ""
                for n, sidename in ipairs(PBEM_PLAYABLE_SIDES) do
                    if sidename ~= PBEM_SIDENAME then
                        otherside = sidename
                        break
                    end
                end
                local myscore = ScenEdit_GetScore(PBEM_SIDENAME)
                local otherscore = ScenEdit_GetScore(otherside)
                local finalscore
                if myscore > otherscore then
                    finalscore = myscore
                    local msg = LocalizeForSide(otherside, "DRAW_MATCHOVER")
                    ScenEdit_SetScore(otherside, finalscore, msg)
                    ScenEdit_SetScore(
                        PBEM_ConstructDummySideName(otherside),
                        finalscore,
                        msg
                    )
                elseif otherscore > myscore then
                    finalscore = otherscore
                    local msg = LocalizeForSide(PBEM_SIDENAME, "DRAW_MATCHOVER")
                    ScenEdit_SetScore(PBEM_SIDENAME, finalscore, msg)
                    ScenEdit_SetScore(
                        PBEM_ConstructDummySideName(PBEM_SIDENAME),
                        finalscore,
                        msg
                    )
                end

                return true
            end
        end
    end

    StoreBoolean("__PBEM_DRAWOFFERED", false)
    return false
end

--[[
    returns false if CMO build is too old for this version of IKE,
    true otherwise
]]--
function PBEM_VerifyBuildNumber()
    local buildnum_string = GetBuildNumber()
    local version_div_index = string.find(buildnum_string, "%.")
    local cmo_version_major = tonumber(
        string.sub(buildnum_string, 1, version_div_index - 1)
    )
    local cmo_version_minor = tonumber(
        string.sub(buildnum_string, version_div_index + 1, string.len(buildnum_string) )
    )
    if cmo_version_major < IKE_MIN_ALLOWED_BUILD_MAJOR then
        return false
    elseif cmo_version_major == IKE_MIN_ALLOWED_BUILD_MAJOR then
        if cmo_version_minor < IKE_MIN_ALLOWED_BUILD_MINOR then
            return false
        end
    end
    return true
end

function PBEM_MinimumCompatibleBuild()
    return tostring(IKE_MIN_ALLOWED_BUILD_MAJOR).."."..tostring(IKE_MIN_ALLOWED_BUILD_MINOR)
end