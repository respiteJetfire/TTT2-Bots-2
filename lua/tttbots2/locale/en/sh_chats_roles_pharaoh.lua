--[[
    Pharaoh / Graverobber / Ankh chat categories

    This file contains chat lines for pharaoh role events, graverobber mechanics,
    and all ankh-related interactions. Categories included:
        PlacedAnkh, AnkhStolen, AnkhRecovered, AnkhDestroyed, AnkhRevival,
        GraverobberStoleAnkh, AnkhSpotted, DefendAnkh, HuntingAnkh
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadPharaohChats()
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
    -- PHARAOH / GRAVEROBBER / ANKH EVENTS
    -----------------------------------------------------------

    -- When a Pharaoh bot places their ankh
    RegisterCategory("PlacedAnkh", P.NORMAL, "When a Pharaoh bot has placed their ankh.")
    Line("I've secured a strategic position.", A.Default)
    Line("My artifact is in place.", A.Default)
    Line("The ankh is set.", A.Default)
    Line("Placed something important. Don't worry about it.", A.Default)
    Line("My preparations are complete.", A.Default)
    Line("put my thing down, we're good", A.Casual)
    Line("ankh is down, let's go", A.Casual)
    Line("set up my little insurance policy", A.Casual)
    Line("My artifact is safely hidden. Nobody touch it.", A.Hothead)
    Line("I PLACED IT. NOBODY GO NEAR IT.", A.Hothead)
    Line("I've placed my ankh! Stay safe, everyone!", A.Nice)
    Line("The ankh is ready. Let's protect each other!", A.Nice)
    Line("Ankh deployed.", A.Stoic)
    Line("Artifact positioned.", A.Stoic)
    Line("Strategic asset deployed at optimal location.", A.Tryhard)
    Line("Ankh placed. Defense perimeter established.", A.Tryhard)
    Line("I put something down. Don't ask what it is.", A.Sus)
    Line("Nothing to see here, just placed a totally normal artifact.", A.Sus)
    Line("i put the glowy thing on the ground!", A.Dumb)
    Line("what does this ankh do again? anyway it's placed", A.Dumb)
    Line("Ankh is placed, team. Let's keep it safe!", A.Teamer)
    Line("I guess I placed it. Whatever.", A.Bad)

    -- When a Pharaoh's ankh has been stolen/converted by a Graverobber
    RegisterCategory("AnkhStolen", P.CRITICAL, "When a Pharaoh's ankh was stolen by a Graverobber.")
    Line("Someone stole my ankh! I need to get it back!", A.Default)
    Line("The ankh was taken from me!", A.Default)
    Line("My ankh has been compromised!", A.Default)
    Line("bro someone took my ankh", A.Casual)
    Line("yo my ankh got stolen wtf", A.Casual)
    Line("WHO STOLE MY ANKH?! I'LL KILL THEM!", A.Hothead)
    Line("THAT'S MY ANKH! GIVE IT BACK!", A.Hothead)
    Line("Oh no, my ankh was taken! Please help!", A.Nice)
    Line("Someone took my ankh... we need to get it back!", A.Nice)
    Line("Ankh ownership transferred. Initiating recovery.", A.Stoic)
    Line("My ankh was stolen.", A.Stoic)
    Line("Critical: ankh compromised. Switching to recovery protocol.", A.Tryhard)
    Line("Ankh stolen. Must reclaim immediately.", A.Tryhard)
    Line("Someone took my ankh... how did they find it?", A.Sus)
    Line("The ankh is gone. Someone knew where it was.", A.Sus)
    Line("where did my glowy thing go?", A.Dumb)
    Line("i think someone took my ankh? is that bad?", A.Dumb)
    Line("Team, my ankh was stolen! Help me get it back!", A.Teamer)
    Line("Great, someone stole my ankh. Wonderful.", A.Bad)

    -- When a Pharaoh re-converts their stolen ankh
    RegisterCategory("AnkhRecovered", P.IMPORTANT, "When a Pharaoh reclaims their stolen ankh.")
    Line("Got my ankh back!", A.Default)
    Line("Artifact reclaimed.", A.Default)
    Line("The ankh is mine again!", A.Default)
    Line("got it back, we're good", A.Casual)
    Line("ankh recovered les go", A.Casual)
    Line("THAT'S RIGHT, IT'S MINE AGAIN!", A.Hothead)
    Line("GOT IT BACK. DON'T TOUCH IT AGAIN.", A.Hothead)
    Line("I got my ankh back! Thank goodness!", A.Nice)
    Line("Ankh reclaimed. Crisis averted.", A.Stoic)
    Line("Ankh recovered. Re-establishing defensive perimeter.", A.Tryhard)
    Line("Interesting... it's back in my possession.", A.Sus)
    Line("yay i got the glowy thing back!", A.Dumb)
    Line("Ankh is back with us, team!", A.Teamer)
    Line("Finally got it back. Ugh.", A.Bad)

    -- When an ankh is destroyed
    RegisterCategory("AnkhDestroyed", P.IMPORTANT, "When an ankh is destroyed.")
    Line("The ankh was destroyed!", A.Default)
    Line("Someone broke the ankh!", A.Default)
    Line("The artifact has been shattered.", A.Default)
    Line("rip the ankh", A.Casual)
    Line("ankh is gone lol", A.Casual)
    Line("WHO DESTROYED THE ANKH?!", A.Hothead)
    Line("THE ANKH IS BROKEN! UNACCEPTABLE!", A.Hothead)
    Line("Oh no, the ankh was destroyed...", A.Nice)
    Line("Ankh destroyed.", A.Stoic)
    Line("Strategic asset lost. Adjusting strategy.", A.Tryhard)
    Line("The ankh is gone... suspicious timing.", A.Sus)
    Line("the glowy thing exploded!", A.Dumb)
    Line("Ankh is down, team. Stay sharp!", A.Teamer)
    Line("Well, there goes the ankh.", A.Bad)

    -- When a player revives via ankh
    RegisterCategory("AnkhRevival", P.IMPORTANT, "When a player revives through their ankh.")
    Line("I'm back! The ankh saved me.", A.Default)
    Line("Revived from the dead!", A.Default)
    Line("The ankh brought me back!", A.Default)
    Line("lmao i'm alive again", A.Casual)
    Line("ankh clutch, let's go", A.Casual)
    Line("I'M BACK AND I'M ANGRY!", A.Hothead)
    Line("YOU THOUGHT I WAS DEAD? THINK AGAIN!", A.Hothead)
    Line("I'm back! Thank you, ankh!", A.Nice)
    Line("Revived. Resuming operations.", A.Stoic)
    Line("Ankh revival successful. Low HP, playing defensive.", A.Tryhard)
    Line("Back from the dead... interesting.", A.Sus)
    Line("wait how am i alive again?", A.Dumb)
    Line("I'm back, team! Let's finish this!", A.Teamer)
    Line("Great, I'm alive again. With 50 HP. Wonderful.", A.Bad)

    -- Graverobber team chat after stealing an ankh
    RegisterCategory("GraverobberStoleAnkh", P.IMPORTANT, "When a Graverobber steals an ankh (team chat).")
    Line("I've captured the ankh. It's mine now.", A.Default)
    Line("Got the pharaoh's artifact.", A.Default)
    Line("The ankh is ours now.", A.Default)
    Line("yoink, got the ankh", A.Casual)
    Line("stole the ankh lol", A.Casual)
    Line("THE ANKH IS MINE NOW!", A.Hothead)
    Line("Ankh acquired.", A.Stoic)
    Line("Ankh secured. Extra life obtained.", A.Tryhard)
    Line("I took their little artifact... hehe.", A.Sus)
    Line("i touched the glowy thing and now it's mine!", A.Dumb)
    Line("Ankh captured for the team!", A.Teamer)
    Line("Got the ankh. You're welcome.", A.Bad)

    -- When any bot spots an ankh on the ground
    RegisterCategory("AnkhSpotted", P.NORMAL, "When a bot spots an ankh entity on the ground.")
    Line("I see something glowing over here...", A.Default)
    Line("There's a strange artifact here.", A.Default)
    Line("I found an ankh!", A.Default)
    Line("yo what's this glowing thing", A.Casual)
    Line("found something weird over here", A.Casual)
    Line("THERE'S AN ANKH HERE!", A.Hothead)
    Line("Oh look, there's an ankh here!", A.Nice)
    Line("Ankh located.", A.Stoic)
    Line("Ankh spotted. Marking location.", A.Tryhard)
    Line("Interesting... an ankh. Who put this here?", A.Sus)
    Line("ooh shiny thing!", A.Dumb)
    Line("Found an ankh, team!", A.Teamer)
    Line("There's an ankh here. Great.", A.Bad)

    -- When a Pharaoh is rushing to defend their ankh
    RegisterCategory("DefendAnkh", P.CRITICAL, "When a Pharaoh is rushing to defend their ankh from attack or conversion.")
    Line("Someone's messing with my ankh!", A.Default)
    Line("Get away from there!", A.Default)
    Line("My ankh is under attack!", A.Default)
    Line("yo someone's at my ankh", A.Casual)
    Line("hey get away from my ankh!", A.Casual)
    Line("TOUCH MY ANKH AND YOU DIE!", A.Hothead)
    Line("GET AWAY FROM MY ANKH RIGHT NOW!", A.Hothead)
    Line("Someone please help, my ankh is being attacked!", A.Nice)
    Line("Ankh threat detected. Responding.", A.Stoic)
    Line("Ankh under siege. Moving to intercept.", A.Tryhard)
    Line("Why is someone near my ankh...?", A.Sus)
    Line("hey that's MY glowy thing, stop!", A.Dumb)
    Line("Team, my ankh is being attacked! Help!", A.Teamer)
    Line("Of course someone's going after my ankh.", A.Bad)

    -- When a Graverobber is actively searching for an ankh (team chat)
    RegisterCategory("HuntingAnkh", P.NORMAL, "When a Graverobber is searching for the ankh (team chat).")
    Line("I need to find that ankh...", A.Default)
    Line("Where did the Pharaoh hide it?", A.Default)
    Line("Searching for the ankh.", A.Default)
    Line("looking for the ankh", A.Casual)
    Line("where's that ankh at", A.Casual)
    Line("WHERE'S THE DAMN ANKH?!", A.Hothead)
    Line("FIND ME THAT ANKH!", A.Hothead)
    Line("Searching for the ankh. Wish me luck!", A.Nice)
    Line("Ankh search in progress.", A.Stoic)
    Line("Systematically sweeping for ankh. Checking secluded areas.", A.Tryhard)
    Line("The ankh has to be somewhere hidden...", A.Sus)
    Line("what does an ankh look like again?", A.Dumb)
    Line("Team, help me find the ankh!", A.Teamer)
    Line("I guess I have to find this ankh thing.", A.Bad)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadPharaohChats()
end
timer.Simple(1, loadModule_Deferred)
