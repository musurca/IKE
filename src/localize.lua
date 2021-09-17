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

function Localize(msg_code)
    local language = os.setlocale("")
    local index = string.find(language, "_")
    if index > 2 then
        language = string.sub(language, 1, index-1)
    else
        language = "English"
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
