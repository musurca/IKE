<p align="center"><img src="https://github.com/musurca/IKE/raw/main/logo.jpg" /></p>

## PBEM/hotseat multiplayer for *Command: Modern Operations* scenarios
FOR PLAYERS: [**DOWNLOAD LATEST SCENARIO PACK HERE (v1.42)**](https://github.com/musurca/IKE/releases/download/v1.42-scenarios/IKE_Scenario_Pack_v1.42.zip)

FOR SCENARIO AUTHORS: [**DOWNLOAD LATEST RELEASE HERE (v1.42)**](https://github.com/musurca/IKE/releases/download/v1.42/IKE_v1.42.zip)

If you're a scenario author or player looking to convert a new or existing scenario for multiplayer use, you only need to download either the latest release or scenario pack using the links above. 

This code repository is intended only for those who are curious about how **IKE** works internally, want to add more features, or want to localize the text for a language other than English. In other words, **if you just want to create a PBEM scenario, you can just download the latest release and skip everything below.**

If you're interested in localizing text: you don't have to build the system. You can just clone the [English localization source CSV](https://github.com/musurca/IKE/blob/main/locale/English_locale.csv), translate the text into your language, and submit the changes by forking the repo and making a pull request, or else by [creating a new Issue](https://github.com/musurca/IKE/issues/new) and attaching the file if you don't want to muck around with GitHub.

For all others interested: welcome! Pull requests and bug reports are greatly appreciated.

(Please note that **IKE** is licensed under [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0-standalone.html), so if you intend to make and distribute changes, please make the source freely available or submit a pull request to this repository promptly.)

### Build prerequisites
* A Bash shell (on Windows 10, install the [WSL](https://www.howtogeek.com/249966/how-to-install-and-use-the-linux-bash-shell-on-windows-10/))
* [luamin](https://github.com/mathiasbynens/luamin)
* [Python 3](https://www.python.org/downloads/)

#### Quick prerequisite install instructions on Windows 10

Assuming you've installed the [WSL](https://www.howtogeek.com/249966/how-to-install-and-use-the-linux-bash-shell-on-windows-10/) and Ubuntu, run the following commands from the shell:
```
sudo apt-get install npm
sudo npm install -g luamin
```

### How to compile

#### Release
```
./build.sh
```

The compiled, minified Lua code will be placed in `release/ike_min.lua`. This is suitable for converting scenarios for PBEM play by pasting it into the Lua Code Editor and clicking RUN as the final step in the scenario creation process.
 
#### Debug
```
./build.sh debug
```

This will produce compiled but unminified Lua code in `debug/ike_debug.lua`. _Do not use this in a released scenario._ This is mostly useful to observe how the final released Lua is composed from the source files.

#### Why is the build process so complicated?
**IKE** works by injecting its own code into a *CMO* LuaScript event action which is executed upon every scenario load. The build process converts the **IKE** source into a minified, escaped string which is then re-embedded into its own code. (IKE-ception!)

### What is IKE?
**IKE** adds PBEM (Play by E-Mail) or Hotseat play to any *Command: Modern Operations* scenario, allowing you to engage in a turn-based multiplayer game with one or more opponents by exchanging .save files.

### What does it do?
**IKE**...
* turns *Command: Modern Operations* into a WEGO-style multiplayer game in which players give orders in phases, then watch their units execute them.
* keeps track of turn order and length, and stops the scenario automatically when a player’s turn is over.
* provides a summary of any losses sustained or messages received during the last turn.
* supports either fixed turn lengths, or *Harpoon*-style variable turn lengths (Intermediate vs. Tactical)
* adds an (optional) Setup Phase, allowing players to configure loadouts, missions, and orders before the game begins.
* provides password protection for each player’s turn.
* allows players to either use the scenario’s recommended PBEM settings, or customize them at game start.
* maintains a consistent random seed, to discourage replaying turns for more advantageous results.
* prevents players from cheating by (optionally) disabling the Editor until the scenario has ended.

### Who is it for?
**IKE** is designed primarily for scenario authors who want to create a multiplayer version of their existing scenario, but it may also be used productively by players who want to convert their favorite scenario for use with a friend.

### How do I use it?
For detailed instructions, please refer to the manual included with the [latest official release](https://github.com/musurca/IKE/releases/download/v1.42/IKE_v1.42.zip).

### VERSION HISTORY
v1.5 (????):
* added: optional variable turn lengths
* added: new action - Offer a Draw
* added: new action - Resign
* added: new action - Change Password
* added: weapon strike report
* added: damage report for ships, subs, and facilities
* added: customizable event handler for end of Setup Phase
* added: Red-Blue Hawaii, 1985
* added: The Bear and the Eagle, 1987 (@Eskild)
* changed: Operation Soberania - added full airbases
* changed: Operation Soberania - Chilean loadouts changed
* fixed: some kills not reported
* fixed: first order phase message displayed correctly 
* fixed: limited control in scenarios without a Setup Phase
* fixed: kill & contact records in wrong language (for real this time)
* fixed: Chinese language typos (@cristianwj)
* fixed: First Contact - end condition
* fixed: Operation Soberania - excessive fuel usage on CL Latorre
* removed: Unlimited Orders mode

v1.42 (11/20/2021):
* added: Chinese (Simplified) localization (thanks to @cristianwj!)
* added: Chinese (Simplified) translation of Scenario Author's Manual (thanks to @GolasYH 叶含!)
* added: Twin Head Dragon Exercise 2021 (by @cristianwj)
* changed: explicit message if game build is updated
* changed: various scenarios - Realistic Sub Comms disabled
* changed: various scenarios - civilian collective resp. disabled
* fixed: contact mirroring/register nils during heavy combat
* fixed: kill & contact records in wrong language
* fixed: score fixed after scenario's end
* fixed: order phases disappearing on 30x compression
* fixed: Event_Delete failure on self-destruct

v1.41 (11/7/2021):
* changed: no-editor check earlier in chain
* fixed: enemy contact detection info appearing in log
* fixed: ScenEdit_SpecialMessage behavior reverted
* fixed: exploits related to scenario end
* fixed: typo in French locale

v1.4 (10/30/2021):
* added: final order phase before the end of a turn in Limited Order mode
* added: French localization (thanks to @nukkxx!)
* added: Spanish localization (thanks to Jorge Arraya!)
* change: bumped minimum CMO build to Steam update for Red Tide DLC (1147.34)
* change: all scenarios - DB updated to v491
* change: Canary's Cage - Spanish airbases can be attacked
* fixed: RPs created between limited order phases now preserved & private
* fixed: ScenEdit_SpecialMessage no longer delayed until next frame
* fixed: replaced platform PRNG with pure Lua xorshift32
* fixed: error message reporting build number mismatch
* fixed: North Pacific Shootout - downed pilot names don't repeat
* fixed: various scenarios - weather reports restored
* fixed: various scenarios - critical RPs protected
* fixed: various scenarios - descriptions/briefings reworded
* fixed: various scenarios - late random teleportations

v1.31 (5/5/2021):
* change: host can now upgrade/downgrade CMO build
* change: older CMO clients (before 1147.17) are prohibited
* fixed: between order phases contacts will show correct posture

v1.3 (3/28/2021):
* added: new contacts from off-turn reported
* added: kills made on off-turn reported
* added: immediate and scheduled chat messages
* added: can set turn order for more than 2 playable sides
* added: Second Battle of Guadalcanal
* change: all players must use the same CMO build
* change: optional setup function must be registered
* change: losses show weapon class by which unit was killed
* change: dummy side name
* change: North Pacific Shootout - can pick up enemy pilots
* change: North Pacific Shootout - Soviet side can use sub for SAR
* fixed: contacts sometimes disappear in limited orders
* fixed: IKE wizard removes previous IKE installation
* fixed: scenarios in years 1900-1970 now work properly
* fixed: Shamal - kills give points to correct side

v1.21 (2/18/2021):
* fixed: API replacements

v1.2 (2/18/2021):
* added: limited order mode
* added: players can customize scenario settings
* added: option to prevent editor mode
* added: losses marked with RPs
* added: missed messages delivered next turn
* added: special action to change side posture
* added: localization support
* fixed: end of setup phase message
* fixed: API replacements clean themselves up
* fixed: workaround for broken ScenEnded trigger
* fixed: set clock precisely to turn boundaries
* fixed: special message order hiding IKE messages
* fixed: coop kills not reported as losses
* fixed: observed losses not reported next turn
* fixed: ScenEdit_PlayerSide() in limited order mode
* fixed: better random seed

v1.1 (2/1/2021):
* fixed: edge case for ScenEdit_SetTime() 
* fixed: use os.date("!") to format scenario times

v1.0 (1/25/2021):
* Initial release.
