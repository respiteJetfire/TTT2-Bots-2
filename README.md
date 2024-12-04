<img src="https://forthebadge.com/images/badges/cc-by-sa.svg" height=30px> <img src="https://forthebadge.com/images/badges/works-on-my-machine.svg" height=30px> <img src="https://forthebadge.com/images/badges/built-with-love.svg" height=30px>

Please leave any bug reports or feature requests in the Issues section. THANK YOU to all the bug reporters that have helped me improve this project!

![TTT Bots Header](tttbots-banner2.png)

## What is this?

This is a modification to thebigsleepjoe's amazing player bot addon for the Trouble in Terrorist Town game mode in Garry's Mod.

It is designed to be as modular as possible, allowing easy customization and expansion. It is designed for TTT2.

This has been tested and designed to work on this steam workshop collection [here](https://steamcommunity.com/sharedfiles/filedetails/?id=3317752676), I have forked the original addon and will try to make changes in parallel to the original repository.

This is my first time modifying any kind of game addons or working with lua, my coding background is more Python oriented so forgive the butchery I have done to some of this lovely code that was originally written.

📝 Note: Please stick to the main branch. Most other branches are eitherunstable or significantly behind.

## Maps

You can find the maps custom-made for this add-on [here](https://www.github.com/thebigsleepjoe/TTT-Bots-2-Maps).

**The bots will work on any map with a navmesh**, but if you want plug-and-play and/or you don't care, you can just use the above add-on.

## How to use

1. Download the latest test version from the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3306701540).
2. Start a Peer-to-Peer or SRCDS with sufficient player slots on a map with a navmesh or one of the included maps.
3. *As a super admin,* either type `!botadd X` in chat or write `ttt_bot_add X` in the console.
4. You're done!

## Role Support

This add-on supports a wide range of TTT2 roles. Here are some that have explicit compatibility:

* Amnesiac
* Anonymous
* Ballas
* Banker
* Bloods
* Bodyguard
* Brainwasher
* Clairvoyant
* Clown
* Crips
* Cursed
* Decipherer
* Defector (WIP)
* Deputy
* Detective
* Doctor
* Drunk
* Families
* Graverobber (WIP)
* Hitman (WIP)
* Hoovers
* Infected
* Jackal
* Jester
* Killerclown
* Marker
* Medic
* Mesmerist
* Mimic
* Occultist
* Oracle
* Pharaoh (WIP)
* Pirate Captain
* Pirate
* Priest (WIP)
* Restless
* Revenant (WIP)
* Serial Killer
* Sheriff
* Sidekick
* Slave
* Spy (WIP)
* Survivalist
* Swapper
* Undecided
* Unknown (WIP)
* Vigilante
* Wicked

The mod also auto-generates compatibility with custom roles, but it is imperfect. It does not comprehend most 'public killer' roles (e.g., 'Speedrunner').


## Major Change: Chatter evolution
## OpenAI ChatGPT Support + Azure / Elevenlabs / Microsoft Voice API TTS Support

This Modification to the TTT Bots mod supports bot replies to the player (and other bots), if you provide an OpenAI Key the bots will reply to text chat, either by name or proximity. This feature is in alpha and needs further testing and refining.

The Bots also now have extra text/voice lines for many situations, including trying to copy/steal someone's role, announcing if a player seems suspicious or trustworthy, using certain weapons etc.

They also can now respond to certain requests in chat such as the following (based on several conditions that must be currently active):

* Making a Player into a Cursed / Defector / Medic / Doctor using special role changing Deagles
* Healing a Player if they are on low health
* Cease firing or Stop Shooting
* Wait for the player
* Attack another player
* Following the player
* Using the Role Checker (Addon in workshop collection)
* Moving to the player's location

This Mod also introduces Text to Speech through the bots chatter system, the current implementation has the downside of holding the UI updates back from the client until the TTS Voice clip is downloaded. I also haven't hooked it up to the TTT2 UI system so I've made a placeholder voice chat graphic in that case.

For Azure TTS you will need the region (e.g en-US) and your Azure Subscription Key. As far as I'm aware this service is free to use at this point since we are only using their free Demo API

For ElevenLabs TTS you will need an API Key.

Alternatively you can opt to use the old Microsoft Sam Voice API but I've found that to be slow, if iconic at the very least.

This feature is also in early Alpha so bugs are expected and a complete redesign of this is probably inevitable.

## Custom Weapon Support

Bots will use some of the custom TTT weapons in the above linked steam workshop collection but this is currently hardcoded to be purchasable by certain roles, I will try to figure out a way to tie this system better with the TTT2 shop system.


## Usage and Commands

A basic usage guide can be found [on the wiki](https://github.com/thebigsleepjoe/TTT-Bots-2/wiki/Basic-Usage-Guide).

It will give you all the info you need for 90% of cases. A more in-depth set of guides are a WIP.

Commands can be found in the CVARS.md file.

## For developers

[Check out the developer guide](https://github.com/thebigsleepjoe/TTT-Bots-2/wiki/Developer-Guide).

Please help me document/improve the codebase! I would highly appreciate it. And you can have bots get named after you!

## License

First and foremost, this open-source software is provided as-is, with no warranty or guarantee of functionality.

I am committed to keeping this project open-source and easily accessible to everyone. I want developers and bot enthusiasts to be able to examine my code, offer feedback, and contribute. However, I have invested much time and effort into developing this project to its current state. Therefore, I have licensed it under CC-BY-SA 4.0, which allows you to clone, use, modify, and redistribute my content freely as long as you give me credit upon using significant portions of my code.

^ You can find the proper legalese for the CC-BY-SA-4.0 license in the LICENSE.txt file.
