--[[
    Defector / Cursed / Role-Switching Chat Categories

    This file contains chat lines for defector role events, role-switching mechanics,
    and all cursed role interactions. Categories included:
        DefectorConverted, DefectorApproaching, DefectorDropping,
        UseTraitorButton, DroppingContract, NewContract,
        SwappingRole, CopyingRole,
        CursedRoleReceived, CursedSwapSuccess, CursedChasing, CursedDeagleFired,
        CursedRespawned, CursedNoBacksies, CursedCantTagDet, CursedDesperateLate,
        CursedSelfImmolate, CursedSpotted, CursedApproachingMe, CursedCantDamage,
        CursedSwappedWithSomeone
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadDefectorChats()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end

    -----------------------------------------------------------
    -- DEFECTOR ROLE CHATTER
    -----------------------------------------------------------

    RegisterCategory("DefectorConverted", P.IMPORTANT, "When a bot has been converted to the defector role mid-round.")
    Line("I've been given a special mission...", A.Default)
    Line("Something has changed... I feel different.", A.Default)
    Line("I know what I have to do now.", A.Default)
    Line("oh cool, i got a new toy", A.Casual)
    Line("well this is interesting lol", A.Casual)
    Line("Oh my... I have a terrible purpose now.", A.Nice)
    Line("I have accepted my fate.", A.Stoic)
    Line("PERFECT. Time to blow some people up!", A.Hothead)
    Line("Great, I'm a walking bomb now.", A.Bad)
    Line("I'll make this count for the team!", A.Teamer)
    Line("Suicide bomber role acquired. Calculating optimal targets.", A.Tryhard)
    Line("I'm totally still innocent guys, don't worry about me!", A.Sus)
    Line("Ooh what's this bomb thing? Looks fun!", A.Dumb)

    RegisterCategory("DefectorApproaching", P.IMPORTANT, "When a defector bot is navigating toward an enemy cluster (Team Only).")
    Line("Moving into position...", A.Default)
    Line("Getting closer to the targets.", A.Default)
    Line("heading toward the group now", A.Casual)
    Line("Almost there...", A.Nice)
    Line("Closing distance to detonation point.", A.Stoic)
    Line("HERE I COME!", A.Hothead)
    Line("Walking toward them, they have no idea.", A.Bad)
    Line("Moving in for the team!", A.Teamer)
    Line("Optimal cluster identified. Approaching.", A.Tryhard)
    Line("Just going for a casual stroll toward everyone...", A.Sus)
    Line("Where am I going? Oh right, toward the people!", A.Dumb)

    RegisterCategory("DefectorDropping", P.IMPORTANT, "When a traitor bot is dropping the defector conversion item near {{player}} (Team Only).")
    Line("Dropping the item for {{player}} now!", A.Default)
    Line("Pick this up, {{player}}!", A.Default)
    Line("yo {{player}} grab this", A.Casual)
    Line("Here you go {{player}}, a little gift!", A.Nice)
    Line("Item deployed near {{player}}.", A.Stoic)
    Line("TAKE IT {{player}}! PICK IT UP!", A.Hothead)
    Line("Dropped something near {{player}}.", A.Bad)
    Line("Leaving this for {{player}} — for the team!", A.Teamer)
    Line("Strategic item placement near {{player}}.", A.Tryhard)
    Line("Oh no, I accidentally dropped something near {{player}}...", A.Sus)
    Line("Here {{player}}, have a present! I think?", A.Dumb)

    RegisterCategory("UseTraitorButton", P.IMPORTANT, "When a bot activates a traitor button")
    Line("Heh, that should ruin their day.", A.Default)
    Line("Button pressed. Enjoy the chaos.", A.Default)
    Line("Time to press the big red button.", A.Hothead)
    Line("yo i just hit the button lmao", A.Casual)
    Line("That should take care of a few of them.", A.Nice)

    RegisterCategory("DroppingContract", P.CRITICAL, "When a bot is dropping a contract to {{player}} so they can join {{player}}'s team")
    Line("Pick up the contract I've just dropped for you {{player}}!", A.Default)
    Line("Freeze {{player}}, I've dropped a contract to you!", A.Default)
    Line("Oi Dickhead fucking stop so I can give you a contract", A.Hothead)
    Line("yo yo hold up one sec lemme give you a contract", A.Casual)
    Line("Hey beautiful, let me give you a present!", A.Nice)
    Line("Yo lets make my team and your team allies {{player}}", A.Teamer)

    RegisterCategory("NewContract", P.IMPORTANT, "When a bot is offering a new contract to a {{player}}.")
    Line("{{player}}, we're on your side now", A.Default)
    Line("Hey fuckhead, try not to shoot us now we're on your team!", A.Hothead)

    RegisterCategory("SwappingRole", P.IMPORTANT, "When a Cursed bot wants to swap roles with {{player}}")
    Line("{{player}} stand still, don't be alarmed!", A.Default)
    Line("come here {{player}}", A.Default)
    Line("{{player}}, I need your role!", A.Default)
    Line("yo {{player}}, wait up, I'm swapping with you.", A.Casual)
    Line("{{player}}, hold up a sec!", A.Casual)
    Line("{{player}}, gotta swap roles real quick.", A.Nice)
    Line("{{player}}, don't move. Swapping roles.", A.Stoic)
    Line("GET OVER HERE {{player}}! I need your role!", A.Hothead)
    Line("{{player}}, just hold still and it'll be over.", A.Bad)
    Line("{{player}}, for the good of the team, give me your role!", A.Teamer)
    Line("{{player}}, swapping with you. Optimal play.", A.Tryhard)
    Line("{{player}}, don't worry... I just want to talk.", A.Sus)
    Line("{{player}}, wait up! I wanna be friends!", A.Dumb)

    RegisterCategory("CopyingRole", P.IMPORTANT, "When a bot is copying another {{player}}'s role.")
    Line("{{player}}, wait up!", A.Default)
    Line("hold up {{player}}", A.Default)
    Line("{{player}}, copying your role.", A.Default)
    Line("{{player}}, hold still, copying your role.", A.Default)
    Line("{{player}}, don't move, mimicking you.", A.Default)
    Line("{{player}}, taking your role.", A.Default)
    Line("{{player}}, stay put, copying your role.", A.Default)
    Line("{{player}}, gonna mimic your role.", A.Default)
    Line("{{player}}, wait up, copying your role.", A.Default)
    Line("{{player}}, I'm becoming you.", A.Default)

    -----------------------------------------------------------
    -- CURSED ROLE CHATTER
    -----------------------------------------------------------

    -- When a bot receives the Cursed role (round start or mid-round swap)
    RegisterCategory("CursedRoleReceived", P.IMPORTANT, "When a bot receives the Cursed role.")
    Line("Oh no, I'm cursed!", A.Default)
    Line("Great, I'm cursed... someone come here.", A.Default)
    Line("I've been cursed! I need to find someone to swap with.", A.Default)
    Line("ugh, i'm cursed. this sucks", A.Casual)
    Line("bruh i got cursed lol", A.Casual)
    Line("I'm so sorry everyone, I'm cursed now.", A.Nice)
    Line("I've been afflicted with the curse.", A.Stoic)
    Line("WHO CURSED ME?! I'M GONNA GET YOU BACK!", A.Hothead)
    Line("Great, I'm cursed. Just my luck.", A.Bad)
    Line("I'm cursed! Someone help me out here!", A.Teamer)
    Line("Cursed role. Need to swap ASAP.", A.Tryhard)
    Line("I'm totally not cursed... don't run.", A.Sus)
    Line("Ooh I'm cursed! What does that mean?", A.Dumb)

    -- When a Cursed bot successfully swaps roles with someone
    RegisterCategory("CursedSwapSuccess", P.IMPORTANT, "When a Cursed bot successfully swaps with {{player}}.")
    Line("Ha! Have fun being cursed, {{player}}!", A.Default)
    Line("Sorry {{player}}, better you than me!", A.Default)
    Line("I'm free! Thanks {{player}}!", A.Default)
    Line("lol bye {{player}}, enjoy the curse", A.Casual)
    Line("seeya {{player}} haha", A.Casual)
    Line("Sorry {{player}}, I had to do it!", A.Nice)
    Line("The curse has been passed.", A.Stoic)
    Line("HAHA! {{player}} IS CURSED NOW!", A.Hothead)
    Line("Later, {{player}}! Sucker!", A.Bad)
    Line("Swapped with {{player}}! Let's go team!", A.Teamer)
    Line("Swap complete. I'm back in the game.", A.Tryhard)
    Line("Oh {{player}}, I didn't mean to do that...", A.Sus)
    Line("Wait, did I just give {{player}} the curse? Oops!", A.Dumb)

    -- When a Cursed bot is chasing/approaching a swap target
    RegisterCategory("CursedChasing", P.NORMAL, "When a Cursed bot is approaching {{player}} to swap.")
    Line("Hold still {{player}}!", A.Default)
    Line("Come here {{player}}, I just want to talk!", A.Default)
    Line("{{player}}, don't run!", A.Default)
    Line("yo {{player}} come back here", A.Casual)
    Line("{{player}} wait up dude", A.Casual)
    Line("{{player}}, please don't run, I need your help!", A.Nice)
    Line("Approaching target.", A.Stoic)
    Line("GET BACK HERE {{player}}!", A.Hothead)
    Line("{{player}}, stop running you coward!", A.Bad)
    Line("{{player}}, take one for the team!", A.Teamer)
    Line("Closing distance on {{player}}.", A.Tryhard)
    Line("{{player}}, I'm not gonna hurt you... I promise.", A.Sus)
    Line("{{player}}! I wanna give you a hug!", A.Dumb)

    -- When a Cursed bot fires the RoleSwap Deagle
    RegisterCategory("CursedDeagleFired", P.NORMAL, "When a Cursed bot fires the RoleSwap Deagle.")
    Line("Don't dodge!", A.Default)
    Line("Tag, you're it!", A.Default)
    Line("Swap deagle, baby!", A.Default)
    Line("yeet", A.Casual)
    Line("pew pew swap time", A.Casual)
    Line("Sorry, I have to shoot!", A.Nice)
    Line("Firing RoleSwap Deagle.", A.Stoic)
    Line("EAT DEAGLE!", A.Hothead)
    Line("Enjoy the curse!", A.Bad)
    Line("Deagle shot for the team!", A.Teamer)
    Line("Optimal target acquired. Firing.", A.Tryhard)
    Line("Oops, my finger slipped!", A.Sus)
    Line("Is this how you use this thing?", A.Dumb)

    -- When a Cursed bot respawns after dying
    RegisterCategory("CursedRespawned", P.NORMAL, "When a Cursed bot respawns after dying.")
    Line("I'm back!", A.Default)
    Line("You can't get rid of me that easily!", A.Default)
    Line("The curse brings me back!", A.Default)
    Line("im back lol", A.Casual)
    Line("respawned, time to find someone", A.Casual)
    Line("I'm alive again! Let's try this again.", A.Nice)
    Line("Respawned. Resuming objective.", A.Stoic)
    Line("I'M BACK AND I'M ANGRY!", A.Hothead)
    Line("Miss me? Didn't think so.", A.Bad)
    Line("Back in action, team!", A.Teamer)
    Line("Respawn timer expired. Re-engaging.", A.Tryhard)
    Line("Did you guys miss me? No? Okay.", A.Sus)
    Line("Woah, I'm alive again! Cool!", A.Dumb)

    -- When a Cursed bot can't tag someone due to no-backsies
    RegisterCategory("CursedNoBacksies", P.NORMAL, "When a Cursed bot hits the no-backsies restriction.")
    Line("Ugh, no backsies...", A.Default)
    Line("I can't tag them back yet!", A.Default)
    Line("No backsies! I need to find someone else.", A.Default)
    Line("dang, no backsies", A.Casual)
    Line("cant swap back, need another target", A.Casual)
    Line("Oh no, I can't swap with them yet.", A.Nice)
    Line("Backsies protection active. Seeking new target.", A.Stoic)
    Line("WHAT?! NO BACKSIES?! UGH!", A.Hothead)
    Line("Stupid no-backsies rule...", A.Bad)
    Line("Can't swap back. Finding another target.", A.Teamer)
    Line("No-backsies timer active. Retargeting.", A.Tryhard)
    Line("That's... convenient for them.", A.Sus)
    Line("Why can't I tag them? That's unfair!", A.Dumb)

    -- When a Cursed bot can't tag a Detective
    RegisterCategory("CursedCantTagDet", P.NORMAL, "When a Cursed bot can't tag a Detective.")
    Line("I can't curse a Detective!", A.Default)
    Line("Detectives are protected...", A.Default)
    Line("damn, can't tag detectives", A.Casual)
    Line("That's a Detective, I can't swap with them.", A.Nice)
    Line("Target is Detective-class. Protected.", A.Stoic)
    Line("WHY CAN'T I TAG THE DETECTIVE?!", A.Hothead)
    Line("Of course the detective is protected...", A.Bad)
    Line("Can't tag detectives. Need a different target.", A.Teamer)
    Line("Detective protection active. Adjusting.", A.Tryhard)
    Line("The detective seems... immune to me.", A.Sus)
    Line("I tried to tag the detective but nothing happened!", A.Dumb)

    -- When the round is late and the Cursed is desperate
    RegisterCategory("CursedDesperateLate", P.IMPORTANT, "When the round is late and the Cursed is desperate to swap.")
    Line("I need to curse someone NOW!", A.Default)
    Line("Running out of time!", A.Default)
    Line("I'm running out of options!", A.Default)
    Line("oh god oh god i need to swap quick", A.Casual)
    Line("SOMEONE PLEASE LET ME TAG YOU", A.Casual)
    Line("Please, someone, I need to swap before it's too late!", A.Nice)
    Line("Time is running out. Must swap immediately.", A.Stoic)
    Line("SOMEONE GET OVER HERE RIGHT NOW!", A.Hothead)
    Line("I'm screwed if I don't swap NOW!", A.Bad)
    Line("Team, I need someone to swap with urgently!", A.Teamer)
    Line("Critical: must execute swap before round end.", A.Tryhard)
    Line("Haha, I'm fine, everything's fine...", A.Sus)
    Line("Wait, do I lose if I don't swap? HELP!", A.Dumb)

    -- When a Cursed bot self-immolates
    RegisterCategory("CursedSelfImmolate", P.NORMAL, "When a Cursed bot self-immolates.")
    Line("AAAGH! *sets self on fire*", A.Default)
    Line("Burning myself for a fresh start!", A.Default)
    Line("lmao im on fire", A.Casual)
    Line("Sorry, I had to burn myself.", A.Nice)
    Line("Self-immolation initiated.", A.Stoic)
    Line("BURN BABY BURN!", A.Hothead)
    Line("Time to make some ashes.", A.Bad)
    Line("Burning for the team!", A.Teamer)
    Line("Strategic immolation executed.", A.Tryhard)
    Line("Don't mind me, just... on fire.", A.Sus)
    Line("Ooh, pretty flames!", A.Dumb)

    -- When another bot spots a Cursed player
    RegisterCategory("CursedSpotted", P.IMPORTANT, "When a bot spots a known Cursed player {{player}}.")
    Line("Watch out, {{player}} is Cursed!", A.Default)
    Line("Cursed player spotted!", A.Default)
    Line("{{player}} is the Cursed, stay away!", A.Default)
    Line("yo {{player}} is cursed, run", A.Casual)
    Line("heads up, {{player}} is cursed", A.Casual)
    Line("Everyone be careful, {{player}} is Cursed!", A.Nice)
    Line("Cursed identified: {{player}}.", A.Stoic)
    Line("{{player}} IS CURSED! DON'T LET THEM NEAR YOU!", A.Hothead)
    Line("{{player}} is cursed. Not my problem.", A.Bad)
    Line("Team, watch out for {{player}}, they're Cursed!", A.Teamer)
    Line("Cursed player {{player}} identified. Avoid contact.", A.Tryhard)
    Line("Is {{player}} cursed? I think they are...", A.Sus)
    Line("{{player}} looks... different. Are they cursed?", A.Dumb)

    -- When the Cursed is approaching another bot
    RegisterCategory("CursedApproachingMe", P.CRITICAL, "When the Cursed player is approaching this bot.")
    Line("Stay away from me!", A.Default)
    Line("The Cursed is coming for me!", A.Default)
    Line("Don't come any closer!", A.Default)
    Line("oh no the cursed is coming for me", A.Casual)
    Line("nope nope nope stay back", A.Casual)
    Line("Please don't curse me!", A.Nice)
    Line("Cursed player approaching. Evading.", A.Stoic)
    Line("GET AWAY FROM ME CURSED!", A.Hothead)
    Line("Touch me and I'll end you. Oh wait...", A.Bad)
    Line("Help! The Cursed is after me!", A.Teamer)
    Line("Cursed player in proximity. Maintaining distance.", A.Tryhard)
    Line("Why are you walking toward me like that...", A.Sus)
    Line("Are you trying to tag me? That's not nice!", A.Dumb)

    -- When a bot can't damage the Cursed
    RegisterCategory("CursedCantDamage", P.NORMAL, "When a bot tries to damage the Cursed and fails.")
    Line("I can't hurt them!", A.Default)
    Line("The Cursed is immune!", A.Default)
    Line("My shots aren't doing anything!", A.Default)
    Line("bro is unkillable wtf", A.Casual)
    Line("my shots aint doing jack", A.Casual)
    Line("I can't damage them, they're immune!", A.Nice)
    Line("Damage output: zero. Target is immune.", A.Stoic)
    Line("WHY WON'T YOU DIE?!", A.Hothead)
    Line("Waste of ammo on that freak.", A.Bad)
    Line("Team, don't bother shooting the Cursed!", A.Teamer)
    Line("Confirmed: Cursed has damage immunity.", A.Tryhard)
    Line("Interesting... they can't be hurt.", A.Sus)
    Line("Why aren't my bullets working?!", A.Dumb)

    -- When a bot witnesses a role swap
    RegisterCategory("CursedSwappedWithSomeone", P.IMPORTANT, "When a bot witnesses {{player1}} cursing {{player2}}.")
    Line("They just swapped roles!", A.Default)
    Line("{{player1}} cursed {{player2}}!", A.Default)
    Line("Did you see that? They swapped!", A.Default)
    Line("yo they just swapped roles", A.Casual)
    Line("{{player1}} tagged {{player2}} lol", A.Casual)
    Line("Oh no, {{player2}} just got cursed!", A.Nice)
    Line("Role swap observed: {{player1}} → {{player2}}.", A.Stoic)
    Line("{{player1}} JUST CURSED {{player2}}!", A.Hothead)
    Line("Ha, {{player2}} got cursed. Sucks to be them.", A.Bad)
    Line("Watch out, {{player2}} is the new Cursed!", A.Teamer)
    Line("Swap confirmed. {{player2}} is now Cursed.", A.Tryhard)
    Line("Something weird just happened between {{player1}} and {{player2}}...", A.Sus)
    Line("Wait, did {{player1}} just curse {{player2}}? Whoa!", A.Dumb)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadDefectorChats()
end
timer.Simple(1, loadModule_Deferred)
