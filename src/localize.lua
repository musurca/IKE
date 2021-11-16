--[[
----------------------------------------------
IKE
localize.lua
----------------------------------------------

Localization library. Detects the language for
the current locale and returns text strings in 
that language. Falls back to English if the
language isn't yet supported.

----------------------------------------------
]]--

function GetLanguageName()
    local localestring = os.setlocale("")
    local index = string.find(localestring, "_")
    if index > 2 then
        return string.sub(localestring, 1, index-1)
    end

    --English is our fallback
    return "English"
end

function Localize(msg_code)
    local language = GetLanguageName()
    local basis = IKE_LOCALIZATIONS[language]
    if basis == nil then
        basis = IKE_LOCALIZATIONS["English"]
    end
    local message = basis[msg_code]
    if not message then
        return "[String "..msg_code.." not found]"
    end
    return message
end

function LocalizeForSide(side, msg_code)
    local sidenum = PBEM_SideNumberByName(side)
    local language = GetString("PBEM_SIDE_LOCALE_"..sidenum)
    if language == "" then
        language = GetLanguageName()
    end
    local basis = IKE_LOCALIZATIONS[language]
    if basis == nil then
        basis = IKE_LOCALIZATIONS["English"]
    end
    local message = basis[msg_code]
    if not message then
        return "[String "..msg_code.." not found]"
    end
    return message
end

function PBEM_SetLocale()
    local sidenum = Turn_GetTurnNumber()
    StoreString(
        "PBEM_SIDE_LOCALE_"..sidenum,
        GetLanguageName()
    )
end