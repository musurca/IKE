--[[
----------------------------------------------
IKE
pbem_checks.lua
----------------------------------------------

Contains various checks to determine whether game
can begin (passwords, build versions, etc).

----------------------------------------------
]]--

function PBEM_SetPassword(sidenum, password)
    StoreString("__SIDE_"..tostring(sidenum).."_PASSWD", md5.Calc(password))
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
    if mybuild ~= hostbuild then
        Input_OK(Localize("VERSION_MISMATCH", {
            mybuild,
            hostbuild
        }))
        return false
    end
    return true
end

function PBEM_UserCheckSettings()
    local scentitle = VP_GetScenario().Title
    if Input_YesNo(Format(Localize("GAME_START"), {scentitle})) then
        -- use recommended settings
        return
    end

    local turn_lengths = {}
    local unlimitedOrders
    local order_phases = {}
    local first_side

    local default_length = math.floor(PBEM_TURN_LENGTH/60)
    local turnLength = Input_Number_Default(Localize("WIZARD_TURN_LENGTH").."\n\n"..Format(Localize("RECOMMENDED"), {
        default_length
    }), default_length)
    turnLength = math.max(0, math.floor(turnLength))
    if turnLength == 0 then
        turnLength = default_length
    end
    -- same length for each side (for now)
    for k,v in ipairs(PBEM_PLAYABLE_SIDES) do
        table.insert(turn_lengths, turnLength*60)
    end
    --unlimited orders?
    unlimitedOrders = Input_YesNo(Localize("WIZARD_UNLIMITED_ORDERS").."\n\n"..Format(Localize("RECOMMENDED"), {
        BooleanToString(PBEM_UNLIMITED_ORDERS)
    }))
    if not unlimitedOrders then
        --number of orders per turn
        local sidenum = 1
        ForEachDo(PBEM_PLAYABLE_SIDES, function(side)
            local orderNumber = 0
            while orderNumber == 0 do
                local rec_msg = ""
                local rec_orders = 0
                if not PBEM_UNLIMITED_ORDERS then
                    rec_orders = PBEM_ORDER_PHASES[sidenum]
                    rec_msg = "\n\n"..Format(Localize("RECOMMENDED"), {rec_orders})
                else
                    rec_orders = 1
                end
                orderNumber = Input_Number_Default(Format(Localize("WIZARD_ORDER_NUMBER"), {
                    side
                })..rec_msg, rec_orders)
                orderNumber = math.max(0, math.floor(orderNumber))
                if orderNumber == 0 then
                    if rec_orders > 0 then
                        orderNumber = rec_orders
                    else
                        Input_OK(Localize("WIZARD_ZERO_ORDER"))
                    end
                end
            end
            table.insert(order_phases, orderNumber)
            sidenum = sidenum + 1
        end)
    end
    --turn order
    first_side = 0
    while first_side == 0 do
        for i=1,#PBEM_PLAYABLE_SIDES do
            if Input_YesNo(Format(Localize("WIZARD_GO_FIRST"), {
                PBEM_PLAYABLE_SIDES[i]
            }).."\n\n"..Format(Localize("RECOMMENDED"), {
                BooleanToString(i==1)
            })) then
                first_side = i
                break
            end
        end
    end
    --editor mode
    local prevent_editor = Input_YesNo(Localize("WIZARD_PREVENT_EDITOR").."\n\n"..Format(Localize("RECOMMENDED"), {
        BooleanToString(GetBoolean("__SCEN_PREVENTEDITOR"))
    }))
    -- confirm settings
    Input_OK(Format(Localize("CONFIRM_SETTINGS"), {
        scentitle,
        PBEM_PLAYABLE_SIDES[first_side]
    }))

    -- commit to settings
    StoreNumberArray("__SCEN_TURN_LENGTHS", turn_lengths)
    StoreBoolean('__SCEN_UNLIMITEDORDERS', unlimitedOrders)
    if not unlimitedOrders then
        StoreNumberArray('__SCEN_ORDERINTERVAL', order_phases)
    end
    local a, b = PBEM_PLAYABLE_SIDES[1], PBEM_PLAYABLE_SIDES[first_side]
    PBEM_PLAYABLE_SIDES[1], PBEM_PLAYABLE_SIDES[first_side] = b, a
    StoreStringArray("__SCEN_PLAYABLESIDES", PBEM_PLAYABLE_SIDES)
    StoreBoolean("__SCEN_PREVENTEDITOR", prevent_editor)
    -- reinit the scenario globals
    PBEM_InitScenGlobals()
end

function PBEM_SelfDestruct()
    local sides = VP_GetSides()
    for i=1,#sides do
        StoreString("__SIDE_"..tostring(i).."_PASSWD","")
        ScenEdit_RemoveSide({side=sides[i].name})
    end
    PBEM_EndAPIReplace()
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

