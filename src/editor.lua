--[[
----------------------------------------------
IKE
editor.lua
----------------------------------------------

Wrapper for CMO API functions pertaining to Events,
Triggers, Conditions, and Actions.

----------------------------------------------
]]--

function Side_Exists(side_name)
    for k, side in ipairs(VP_GetSides()) do
        if side.name == side_name then
            return true
        end
    end
    return false
end

function Event_Exists(evt_name)
    local events = ScenEdit_GetEvents()
    for i=1,#events do
        local event = events[i]
        if event.details.description == evt_name then
            return true
        end
    end

    return false
end

function Event_Delete(evt_name, recurse)
    recurse = recurse or false
    if recurse then
        -- delete nested actions, conditions, and triggers
        ForEachDo_Break(ScenEdit_GetEvents(), function(event)
            if event.details.description == evt_name then
                ForEachDo(event.details.triggers, function(e)
                    for key, val in pairs(e) do
                        if val.Description ~= nil then
                            Event_RemoveTrigger(evt_name, val.Description)
                            Trigger_Delete(val.Description)
                        end
                    end
                end)
                ForEachDo(event.details.conditions, function(e)
                    for key, val in pairs(e) do
                        if val.Description ~= nil then
                            Event_RemoveCondition(evt_name, val.Description)
                            Condition_Delete(val.Description)
                        end
                    end
                end)
                ForEachDo(event.details.actions, function(e)
                    for key, val in pairs(e) do
                        if val.Description ~= nil then
                            Event_RemoveAction(evt_name, val.Description)
                            Action_Delete(val.Description)
                        end
                    end
                end)

                return false
            end
            return true
        end)
    end

    -- remove the event
    pcall(ScenEdit_SetEvent, evt_name, {mode="remove"})
end

function Event_Create(evt_name, args)
    -- clear any existing events with that name
    ForEachDo(ScenEdit_GetEvents(), function(event)
        if event.details.description == evt_name then
            pcall(ScenEdit_SetEvent, evt_name, {
                mode="remove"
            })
        end
    end)

    -- add our event
    args.mode="add"
    ScenEdit_SetEvent(evt_name, args)
    return evt_name
end

function Event_AddTrigger(evt, trig)
    ScenEdit_SetEventTrigger(evt, {mode='add', name=trig})
end

function Event_RemoveTrigger(evt, trig)
    ScenEdit_SetEventTrigger(evt, {mode='remove', name=trig})
end

function Event_AddCondition(evt, cond)
    ScenEdit_SetEventCondition(evt, {mode='add', name=cond})
end

function Event_RemoveCondition(evt, cond)
    ScenEdit_SetEventCondition(evt, {mode='remove', name=cond})
end

function Event_AddAction(evt, action)
    ScenEdit_SetEventAction(evt, {mode='add', name=action})
end

function Event_RemoveAction(evt, action)
    ScenEdit_SetEventAction(evt, {mode='remove', name=action})
end

function Trigger_Create(trig_name, args)
    args.name=trig_name
    args.mode="add"
    ScenEdit_SetTrigger(args)
    return trig_name
end

function Trigger_Delete(trig_name)
    ScenEdit_SetTrigger({name=trig_name, mode="remove"})
end

function Condition_Create(cond_name, args)
    args.name=cond_name
    args.mode="add"
    ScenEdit_SetCondition(args)
    return cond_name
end

function Condition_Delete(cond_name)
    ScenEdit_SetCondition({
        name=cond_name, 
        mode="remove"
    })
end

function Action_Create(action_name, args)
    args.name=action_name
    args.mode="add"
    ScenEdit_SetAction(args)
    return action_name
end

function Action_Delete(action_name)
    ScenEdit_SetAction({
        name=action_name, 
        mode="remove"
    })
end

function ExecuteAt(timetoexecute, code)
    local function uuid()
        local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
        local function swap(c)
            local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
            return string.format('%x', v)
        end
        return string.gsub(template, '[xy]', swap)
    end
    local run_epoch = (62135596800 + timetoexecute) * 10000000
    local evt_uuid = uuid()
    while Event_Exists(evt_uuid) do
        evt_uuid = uuid()
    end
    local evt_name = ""
    while not Event_Exists(evt_uuid) do
        -- create the event
        evt_name = Event_Create(
            evt_uuid,
            {
                IsRepeatable = false,
                IsShown = false
            }
        )

        -- trigger on time
        local trigger_name = Trigger_Create(
            uuid(),
            {
                type = 'Time',
                Time = run_epoch
            }
        )
        Event_AddTrigger(evt_name, trigger_name)

        -- action to perform
        local script = "__waitevt__=function()\r\n" .. code .. "\r\nend\r\npcall(__waitevt__)\r\npcall(Event_Delete, \"" .. evt_name .. "\")"
        local action_name = Action_Create(
            uuid(),
            {
                type = 'LuaScript',
                ScriptText = script
            }
        )
        Event_AddAction(evt_name, action_name)
    end

    return evt_name
end