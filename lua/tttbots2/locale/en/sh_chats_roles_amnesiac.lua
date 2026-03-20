--[[
    Amnesiac role chat categories

    This file contains chat lines for the Amnesiac role events.
    Categories included:
        AmnesiacRoleReceived, AmnesiacSeekingCorpse, AmnesiacConversionSuccess,
        AmnesiacConversionWitnessed, AmnesiacDesperateLate,
        AmnesiacNoBodiesAvailable, AmnesiacPostConversionDisguise
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadAmnesiacChats()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end

    -- ===================================================================
    -- AMNESIAC ROLE CHATTER
    -- ===================================================================

    -- When a bot receives the Amnesiac role at round start
    RegisterCategory("AmnesiacRoleReceived", P.IMPORTANT, "When a bot receives the Amnesiac role.")
    Line("I don't remember anything... I need to find a body.", A.Default)
    Line("I'm an Amnesiac. I need to search a corpse to get my role back.", A.Default)
    Line("No memories, no role. Time to find a body.", A.Default)
    Line("ugh i'm the amnesiac, gotta go body hunting", A.Casual)
    Line("amnesiac gang, time to find a body lol", A.Casual)
    Line("Oh no, I can't remember who I am! I need to find someone to help me.", A.Nice)
    Line("I'm sure I'll figure out who I am soon. Let me check the bodies.", A.Nice)
    Line("I DON'T KNOW WHO I AM AND I HATE IT", A.Hothead)
    Line("Great, I'm the useless role. Where are the bodies?!", A.Hothead)
    Line("Amnesiac. Searching for identity.", A.Stoic)
    Line("I have no memory. I must find a corpse.", A.Stoic)
    Line("Amnesiac role. Need to find and search a body ASAP for role acquisition.", A.Tryhard)
    Line("Optimal play: locate nearest unconfirmed corpse immediately.", A.Tryhard)
    Line("I'm the amnesiac... or AM I?", A.Sus)
    Line("What if I just... don't remember anything? Suspicious.", A.Sus)
    Line("wait what role am i again?", A.Dumb)
    Line("how do i play amnesiac? do i just walk around?", A.Dumb)
    Line("Amnesia sucks. Let's stick together and find bodies as a team!", A.Teamer)
    Line("I'm an amnesiac, but I'm no good to anyone like this.", A.Bad)
    Line("Whatever, I'll find a body eventually.", A.Bad)

    -- When an Amnesiac bot spots a body and moves to investigate it
    RegisterCategory("AmnesiacSeekingCorpse", P.NORMAL, "When an Amnesiac bot spots a body to search. {{corpse}} is the victim's name.")
    Line("I see a body over there... let me check it.", A.Default)
    Line("There's a body! Maybe I'll remember something.", A.Default)
    Line("Time to search that corpse and find out who I am.", A.Default)
    Line("ooh a body, let me go check it out", A.Casual)
    Line("found a body, brb", A.Casual)
    Line("Oh, there's someone! Let me see if I can remember...", A.Nice)
    Line("A BODY! FINALLY! LET ME AT IT!", A.Hothead)
    Line("MOVE, I need that body!", A.Hothead)
    Line("Corpse located. Moving to investigate.", A.Stoic)
    Line("Body found. Approaching.", A.Stoic)
    Line("Body spotted. Moving to acquire role from {{corpse}}.", A.Tryhard)
    Line("Optimal target identified. Engaging search protocol.", A.Tryhard)
    Line("Oh look, a body... how convenient. Let me just... take a peek.", A.Sus)
    Line("what's that on the ground? oh it's a person", A.Dumb)
    Line("is that a dead body? let me go poke it", A.Dumb)
    Line("Found a body! Let's go check it together.", A.Teamer)
    Line("Another dead body. Big deal. Let me just search it.", A.Bad)

    -- When an Amnesiac bot successfully converts to a new role
    RegisterCategory("AmnesiacConversionSuccess", P.IMPORTANT, "When an Amnesiac bot converts to a new role. {{newrole}} is the role name.")
    Line("I remember now... I remember everything.", A.Default)
    Line("It's all coming back to me!", A.Default)
    Line("I know who I am now.", A.Default)
    Line("oh nice, i got a role now", A.Casual)
    Line("lets gooo i remember now", A.Casual)
    Line("Oh wonderful, I remember! I know what to do now.", A.Nice)
    Line("Thank goodness, I'm not lost anymore!", A.Nice)
    Line("FINALLY! I know who I am! Let's GO!", A.Hothead)
    Line("About time I got my memories back!", A.Hothead)
    Line("Memory restored. Proceeding.", A.Stoic)
    Line("I recall now. Time to act.", A.Stoic)
    Line("Role acquired. Switching to optimal strategy.", A.Tryhard)
    Line("Conversion complete. Adjusting play accordingly.", A.Tryhard)
    Line("I remember... or do I? Just kidding, I definitely remember.", A.Sus)
    Line("Huh, so THAT'S who I am. Interesting.", A.Sus)
    Line("oh cool i remember now! what was i doing again?", A.Dumb)
    Line("wait did something just happen to me?", A.Dumb)
    Line("I remember now! Let's work together, team!", A.Teamer)
    Line("Oh, I know my role now. Whatever.", A.Bad)

    -- When another bot sees the global popup about an Amnesiac converting
    RegisterCategory("AmnesiacConversionWitnessed", P.IMPORTANT, "When a bot sees the Amnesiac conversion popup. {{newrole}} is the new role.")
    Line("Did an Amnesiac just take a role?", A.Default)
    Line("Someone just remembered who they were...", A.Default)
    Line("An Amnesiac converted. Be on your guard.", A.Default)
    Line("amnesiac just got a role, watch out", A.Casual)
    Line("Oh, someone remembered! I hope they're on our side.", A.Nice)
    Line("WHO JUST CONVERTED?! SHOW YOURSELF!", A.Hothead)
    Line("Amnesiac conversion noted.", A.Stoic)
    Line("Amnesiac just acquired {{newrole}}. Adjusting threat assessment.", A.Tryhard)
    Line("So an Amnesiac just became something... very interesting.", A.Sus)
    Line("what's an amnesiac? did someone get a new role?", A.Dumb)
    Line("An Amnesiac just converted. Team, stay alert!", A.Teamer)
    Line("Great, now we have to figure out who the Amnesiac was.", A.Bad)

    -- When an Amnesiac bot is still unconverted late in the round
    RegisterCategory("AmnesiacDesperateLate", P.IMPORTANT, "When an Amnesiac bot is desperate to convert late in the round.")
    Line("I need to find a body, fast...", A.Default)
    Line("Running out of time! Where are the bodies?!", A.Default)
    Line("I'm running out of time to remember!", A.Default)
    Line("bro i need a body asap im running out of time", A.Casual)
    Line("Oh no, I really need to find someone soon!", A.Nice)
    Line("WHERE ARE THE BODIES?! I'M RUNNING OUT OF TIME!", A.Hothead)
    Line("I SWEAR IF I DON'T FIND A BODY SOON...", A.Hothead)
    Line("Time is short. Must locate a corpse.", A.Stoic)
    Line("Critical: no role acquired yet. Must find body immediately.", A.Tryhard)
    Line("Still can't remember... tick tock...", A.Sus)
    Line("am i supposed to have done something by now?", A.Dumb)
    Line("Team, I still need a body! Help me find one!", A.Teamer)
    Line("This is taking forever. Where did everyone die?", A.Bad)

    -- When no unconfirmed corpses exist for the Amnesiac
    RegisterCategory("AmnesiacNoBodiesAvailable", P.NORMAL, "When there are no unconfirmed corpses for the Amnesiac to search.")
    Line("Where are all the bodies?", A.Default)
    Line("No one's died yet? Come on...", A.Default)
    Line("I can't find any bodies to search.", A.Default)
    Line("no bodies anywhere, great", A.Casual)
    Line("I hope everyone's okay... but I also need someone to die.", A.Nice)
    Line("HOW IS NOBODY DEAD YET?!", A.Hothead)
    Line("No corpses available.", A.Stoic)
    Line("Zero valid targets. Need kills to generate searchable corpses.", A.Tryhard)
    Line("Strange, no bodies... very strange indeed.", A.Sus)
    Line("where did all the dead people go?", A.Dumb)
    Line("Nobody's died yet? We need to find bodies together!", A.Teamer)
    Line("Unbelievable. Not a single body.", A.Bad)

    -- When a bot is trying to act natural after converting (popup was broadcast)
    RegisterCategory("AmnesiacPostConversionDisguise", P.NORMAL, "When an Amnesiac bot is trying to be discreet after converting.")
    Line("Act natural, act natural...", A.Default)
    Line("Nothing to see here, just minding my own business.", A.Default)
    Line("I should probably lay low for a bit.", A.Default)
    Line("just playing it cool, nothing happened", A.Casual)
    Line("haha what amnesiac? i've always been this role", A.Casual)
    Line("I'm fine! Everything's fine! Don't mind me!", A.Nice)
    Line("NOBODY LOOK AT ME", A.Hothead)
    Line("...", A.Stoic)
    Line("Maintaining cover. Blending in.", A.Tryhard)
    Line("Adopting new play pattern to avoid identification.", A.Tryhard)
    Line("Who, me? I've been this role the whole time. Definitely.", A.Sus)
    Line("What's an amnesiac? Never heard of it.", A.Sus)
    Line("did something happen? i wasn't paying attention", A.Dumb)
    Line("Team, let's focus on the game. Nothing weird happened!", A.Teamer)
    Line("Whatever. Just keep playing.", A.Bad)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadAmnesiacChats()
end
timer.Simple(1, loadModule_Deferred)
