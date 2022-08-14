--[[
----------------------------------------------
IKE
pbem_preferences.lua
----------------------------------------------

Defines functions related to user preferences
(reference point markers for events, etc.)

----------------------------------------------
]]--

-- default user preferences 
IKE_PREFERENCES_DEFAULT = {
   { "EVENT_MARK_RP", true },
   { "EVENT_RP_DELETE_ENDTURN", true },
   { "AUTOSAVE_END_TURN", true }
}
IKE_PREF_KEY    = 1
IKE_PREF_VALUE  = 2

function PBEM_PreferencePrefix()
    return "PREF_"..Turn_GetCurSide().."_"
end

function PBEM_InitPreferences()
    local prefix = PBEM_PreferencePrefix()
    for i, pref in ipairs(IKE_PREFERENCES_DEFAULT) do
        StoreBoolean(
            prefix..pref[IKE_PREF_KEY], 
            pref[IKE_PREF_VALUE]
        )
    end
end

function PBEM_GetPreference(pref_id)
    local prefix = PBEM_PreferencePrefix()
    return GetBoolean(prefix..pref_id)
end

function PBEM_SetPreference(pref_id, val)
    local prefix = PBEM_PreferencePrefix()
    StoreBoolean(prefix..pref_id, val)
end

function PBEM_GetPreferenceForSide(sidename, pref_id)
    local prefix = "PREF_"..PBEM_SideNumberByName(sidename).."_"
    return GetBoolean(prefix..pref_id)
end