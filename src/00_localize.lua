--[[
----------------------------------------------
IKE
00_localize.lua
----------------------------------------------

Localization library. Detects the language for
the current locale and returns text strings in 
that language. Falls back to English if the
language isn't yet supported.

----------------------------------------------
]]--

IKE_LOCALIZATIONS = {
    ["English"] = {
        ["START_OF_TURN_HEADER"]    = "%1 Turn %2<br/>(%3 minutes)",
        ["END_OF_TURN_HEADER"]      = "End of %1 Turn %2",
        ["END_OF_TURN_MESSAGE"]     = "Go to <b>File -> Save As...</b>, save this game, and send the save file to the <b>%1</b> player via email or another transfer service.<br/><br/><u>IMPORTANT:</u> Do <b>NOT</b> close this window or resume the game before saving, or you will have to replay your turn.",
        ["SHOW_REMAINING_SETUP"]    = "This is the setup phase.",
        ["SHOW_REMAINING_TIME"]     = "Time remaining in your turn: %1:%2:%3.",
        ["END_OF_SCENARIO_SUMMARY"] = "End of Scenario (Turn %1)",
        ["END_OF_SCENARIO_HEADER"]  = "End of Scenario",
        ["END_OF_SCENARIO_MESSAGE"] = "Go to <b>File -> Save As...</b>, save this game, and send the save file to the other players via email or another transfer service.<br/><br/>",
        ["MESSAGES_RECEIVED"]       = "Messages received:",
        ["LOSSES_REPORTED"]         = "Losses reported:",
        ["SETUP_PHASE_INTRO"]       = "This is the %1 setup phase.\n\nLeave the game paused until you've finished setting up your loadouts and missions.\n\nWhen you're done, click Play to end your turn.",
        ["END_OF_SETUP_HEADER"]     = "End of %1 Setup Phase",        
        ["PASSWORDS_DIDNT_MATCH"]   = "Passwords didn\'t match! Please enter your password again:",
        ["CHOOSE_PASSWORD"]         = "%1, please choose a password:",
        ["CONFIRM_PASSWORD"]        = "Enter password again to confirm:",
        ["ENTER_PASSWORD"]          = "%1, enter your password to start turn %2:",
        ["WRONG_PASSWORD"]          = "The password was incorrect.",
        ["START_ORDER_HEADER"]      = "%1 Turn %2<br/>(%3 minutes)<br/><br/>Order Phase %4",
        ["NEXT_ORDER_HEADER"]       = "%1 Turn %2<br/>(%3 minutes left)<br/><br/>Order Phase %4",
        ["START_ORDER_MESSAGE"]     = "Give orders to your units as needed. When you're ready, <b>start the clock</b> to execute them.",
        ["ORDER_PHASE_DIVIDER"]     = "%1 of %2",
        ["LOSS_MARKER"]             = "Loss of %1",
        ["NO_EDITOR_MODE"]          = "You can't open a PBEM game in Editor mode until the scenario has ended.\n\nPlay this scenario using Start New Game or Load Saved Game from the main menu.",
        ["WIZARD_INTRO_MESSAGE"]    = "Welcome to IKE v%1! This tool adds PBEM/hotseat play to any Command: Modern Operations scenario.\n\nRunning this tool cannot be undone. Have you saved a backup of this scenario?",
        ["WIZARD_BACKUP"]           = "Please save a backup first, then RUN this tool again.",
        ["WIZARD_FIXED_TURNLENGTH"] = "Do you want to use a FIXED turn length?\n(Click No for VARIABLE turn lengths by side.)",
        ["WIZARD_TURN_LENGTH"]      = "Enter the TURN LENGTH in minutes:",
        ["WIZARD_TURN_LENGTH_SIDE"] = "Enter the TURN LENGTH in minutes for side %1:",
        ["WIZARD_ZERO_LENGTH"]      = "ERROR: The turn length must be greater than 0!",
        ["WIZARD_UNLIMITED_ORDERS"] = "Should players be able to give UNLIMITED orders during a turn?\n(Click No for a LIMITED number of orders per turn.)",
        ["WIZARD_ORDER_NUMBER"]     = "HOW MANY orders can a side give per turn?",
        ["WIZARD_ZERO_ORDER"]       = "ERROR: The number of orders must be greater than 0!",
        ["WIZARD_PLAYABLE_SIDE"]    = "Should the %1 side be PLAYABLE?",
        ["WIZARD_GO_FIRST"]         = "Should the %1 side go FIRST?",
        ["WIZARD_CLEAR_MISSIONS"]   = "Clear any existing missions for the %1 side?",
        ["WIZARD_SETUP_PHASE"]      = "Should the game start with a SETUP PHASE?",
        ["WIZARD_PREVENT_EDITOR"]   = "Do you want to PREVENT players from opening the game in EDITOR MODE until it's over?\n(Click no to ALLOW EDITOR MODE.)",
        ["WIZARD_SUCCESS"]          = "Success! Your PBEM/hotseat scenario has been initialized. Go to FILE -> SAVE AS... to save it under a new name. It will be ready to play when next loaded.\n\n(If you're planning to publish it to the Steam Workshop, you should do it now, before you close this scenario.)\n\nThanks for using IKE!"
    }
}

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
    return basis[msg_code]
end

--[[!! LEAVE TWO CARRIAGE RETURNS AFTER SOURCE FILE !!]]--

