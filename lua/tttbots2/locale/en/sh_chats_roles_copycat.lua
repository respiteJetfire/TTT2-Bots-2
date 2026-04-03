--[[
    Copycat role chat categories

    This file contains chat lines for the Copycat role events.
    Categories included:
        CopycatRoleReceived, CopycatSeekingCorpse, CopycatTranscribed,
        CopycatSwitching, CopycatSwitchSuccess, CopycatPostSwitch
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadCopycatChats()
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
    -- COPYCAT ROLE CHATTER
    -- ===================================================================

    -- When a bot receives the Copycat role at round start
    RegisterCategory("CopycatRoleReceived", P.IMPORTANT, "When a bot receives the Copycat role.")
    Line("Time to do some research on everyone...", A.Default)
    Line("I need to gather intel from the dead. Files won't fill themselves.", A.Default)
    Line("Let me check who's been killed and steal their identity.", A.Default)
    Line("copycat time, gotta go collect some roles", A.Casual)
    Line("nice, i get to be whoever i want lol", A.Casual)
    Line("Oh, this is interesting! I can be anyone I want!", A.Nice)
    Line("I hope I can find some good roles to copy!", A.Nice)
    Line("LET'S GO! TIME TO STEAL SOME ROLES!", A.Hothead)
    Line("Get out of my way, I've got files to collect!", A.Hothead)
    Line("Copycat. Initiating role collection protocol.", A.Stoic)
    Line("The files are empty. Time to fill them.", A.Stoic)
    Line("Copycat role acquired. Priority: collect high-value roles from corpses.", A.Tryhard)
    Line("Optimal strategy: search bodies first, switch to combat role second.", A.Tryhard)
    Line("Copycat, huh? How do I know I'm not already someone else?", A.Sus)
    Line("Everyone should be very worried right now...", A.Sus)
    Line("wait so i search bodies and then i become them? cool", A.Dumb)
    Line("how do the files work again?", A.Dumb)
    Line("Copycat here! Let's work together to find bodies!", A.Teamer)
    Line("Great, another gimmick role. Let's get it over with.", A.Bad)
    Line("Whatever. I'll just grab some roles and figure it out.", A.Bad)

    -- When a Copycat bot spots a body and moves to investigate it
    RegisterCategory("CopycatSeekingCorpse", P.NORMAL, "When a Copycat bot spots a body to search. {{corpse}} is the victim's name.")
    Line("There's a body. Let me check their role for my files.", A.Default)
    Line("I see {{corpse}}'s body. Time to add to my collection.", A.Default)
    Line("Another body to document in the files.", A.Default)
    Line("ooh a body, lemme grab that role", A.Casual)
    Line("found one, brb collecting", A.Casual)
    Line("Oh no, someone died! But at least I can learn from them.", A.Nice)
    Line("Poor {{corpse}}... but their role could be useful.", A.Nice)
    Line("BODY! GIVE ME THAT ROLE!", A.Hothead)
    Line("MOVE! I need to check that corpse!", A.Hothead)
    Line("Corpse detected. Approaching for transcription.", A.Stoic)
    Line("Body found. Cataloguing.", A.Stoic)
    Line("Target corpse identified: {{corpse}}. Moving to transcribe role.", A.Tryhard)
    Line("High-value intel opportunity. Engaging.", A.Tryhard)
    Line("A body... how convenient. Let me just take a little look.", A.Sus)
    Line("What role did this one have? Very curious...", A.Sus)
    Line("is that a dead person? let me go write something down", A.Dumb)
    Line("i think i need to touch that body or something", A.Dumb)
    Line("Found a body! Let's check it for intel!", A.Teamer)
    Line("Another body. Whatever, let me just grab the role.", A.Bad)

    -- When a Copycat bot successfully transcribes a role from a corpse
    RegisterCategory("CopycatTranscribed", P.IMPORTANT, "When a Copycat bot transcribes a role into the files. {{role}} is the role name.")
    Line("Got it! Added {{role}} to my files.", A.Default)
    Line("New role collected: {{role}}. Good.", A.Default)
    Line("{{role}} has been transcribed.", A.Default)
    Line("nice, got {{role}} in the files now", A.Casual)
    Line("{{role}} collected, ez", A.Casual)
    Line("Oh wonderful, I've learned about the {{role}} role!", A.Nice)
    Line("ANOTHER ONE FOR THE COLLECTION!", A.Hothead)
    Line("{{role}} transcribed. Collection growing.", A.Stoic)
    Line("{{role}} acquired. Evaluating combat potential.", A.Tryhard)
    Line("Interesting... I now have {{role}} in my files. Very interesting.", A.Sus)
    Line("oh cool i got a new one! what's {{role}} do again?", A.Dumb)
    Line("Team, I've transcribed {{role}}!", A.Teamer)
    Line("Fine. Added {{role}}. Big deal.", A.Bad)

    -- When a Copycat bot decides to switch roles
    RegisterCategory("CopycatSwitching", P.IMPORTANT, "When a Copycat bot is about to switch to a new role. {{role}} is the target role.")
    Line("Time to become someone else. Let me check my files...", A.Default)
    Line("I think it's time to switch. Looking through the files.", A.Default)
    Line("I've gathered enough intel. Time to transform.", A.Default)
    Line("aight switching roles now, wish me luck", A.Casual)
    Line("time to become {{role}} lol", A.Casual)
    Line("I think I'll try being a {{role}} for a while!", A.Nice)
    Line("LET'S DO THIS! SWITCHING NOW!", A.Hothead)
    Line("Switching to {{role}}. Proceeding.", A.Stoic)
    Line("Role switch initiated. Target: {{role}}. Optimal play incoming.", A.Tryhard)
    Line("What if I became... someone else? Yes, I think I will.", A.Sus)
    Line("which button do i press? oh wait, {{role}} looks cool", A.Dumb)
    Line("Team, I'm switching to {{role}}!", A.Teamer)
    Line("Whatever, I'll just go with {{role}}.", A.Bad)

    -- When a Copycat bot successfully switches roles
    RegisterCategory("CopycatSwitchSuccess", P.IMPORTANT, "When a Copycat bot successfully switches to a new role. {{role}} is the new role.")
    Line("Transformation complete. I'm someone new now.", A.Default)
    Line("Done. I've switched to a new identity.", A.Default)
    Line("The files worked perfectly. New role active.", A.Default)
    Line("switched! let's go", A.Casual)
    Line("nice im {{role}} now", A.Casual)
    Line("Oh how exciting, I'm a brand new person!", A.Nice)
    Line("BOOM! NEW ROLE! LET'S WRECK!", A.Hothead)
    Line("NOW we're talking! Time to cause chaos!", A.Hothead)
    Line("Role change confirmed. Adapting.", A.Stoic)
    Line("Switching complete.", A.Stoic)
    Line("Role switch successful. Now playing optimally as {{role}}.", A.Tryhard)
    Line("Hmm, who am I now? Even I don't know...", A.Sus)
    Line("oh wait did it work? am i different now?", A.Dumb)
    Line("Switch complete! Let's coordinate with the new role!", A.Teamer)
    Line("Done. Whatever.", A.Bad)

    -- When a Copycat bot is trying to blend in after switching
    RegisterCategory("CopycatPostSwitch", P.NORMAL, "When a Copycat bot is trying to act natural after switching roles.")
    Line("Nothing happened. I've always been this role.", A.Default)
    Line("Just doing my job here, nothing to see.", A.Default)
    Line("act natural, no one noticed", A.Casual)
    Line("I'm just a regular player, don't mind me!", A.Nice)
    Line("WHAT ARE YOU LOOKING AT?!", A.Hothead)
    Line("Maintaining cover.", A.Stoic)
    Line("Post-switch: blending into role expectations.", A.Tryhard)
    Line("Who am I? I've always been this. Always.", A.Sus)
    Line("wait what was i doing again?", A.Dumb)
    Line("Everything's normal here, team!", A.Teamer)
    Line("Mind your own business.", A.Bad)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadCopycatChats()
end
timer.Simple(1, loadModule_Deferred)
