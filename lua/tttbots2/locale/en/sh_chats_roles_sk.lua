--[[
    Serial Killer (SK) role chat categories

    This file contains chat lines for Serial Killer role events.
    Categories included:
        SKHunting, SKKnifeKill, SKShakeNade, SKGloat,
        SKLastStand, SKSpotted, SKVictory, SKSpottedByOthers
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
    MODERATE = 2,  --- Moderate priority (alias for IMPORTANT)
}

local function LoadSKChats()
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
    -- SERIAL KILLER (SK) ROLE EVENTS
    -----------------------------------------------------------

    RegisterCategory("SKHunting", P.MODERATE, "Serial Killer is stalking and hunting for isolated targets.")
    Line("I see a target... time to close in.", A.Default)
    Line("Someone's alone. Perfect opportunity.", A.Default)
    Line("Moving in for the kill...", A.Default)
    Line("Found one by themselves. My lucky day.", A.Default)

    Line("got my eyes on someone hehe", A.Casual)
    Line("someone's all alone... this'll be easy", A.Casual)
    Line("ooh a loner, don't mind if i do", A.Casual)

    Line("Target acquired. Closing distance.", A.Tryhard)
    Line("Isolated contact. Moving for elimination.", A.Tryhard)
    Line("Solo target identified. Engaging stealth approach.", A.Tryhard)

    Line("GET OVER HERE! I'M COMING FOR YOU!", A.Hothead)
    Line("FOUND ONE ALONE! TIME TO CUT!", A.Hothead)
    Line("THIS ONE IS MINE!!", A.Hothead)

    Line("A lone target. Approaching.", A.Stoic)
    Line("One has separated from the group.", A.Stoic)

    Line("Sorry about this... but you're all alone.", A.Nice)
    Line("I really don't want to do this... but I have to.", A.Nice)

    Line("Another victim. They never learn.", A.Bad)
    Line("Walking around alone? Rookie mistake.", A.Bad)

    Line("ooh someone is over there by themselves hmmm", A.Dumb)
    Line("maybe if i sneak up really quiet...", A.Dumb)

    Line("Moving in on a solo target. Clean and quiet.", A.Teamer)

    Line("haha they have no idea I'm right behind them", A.Sus)

    RegisterCategory("SKKnifeKill", P.IMPORTANT, "Serial Killer just killed someone with the SK knife.")
    Line("Another one bites the dust.", A.Default)
    Line("That was clean. No witnesses.", A.Default)
    Line("One down. Who's next?", A.Default)
    Line("Silent kill. Moving on.", A.Default)

    Line("lol get rekt", A.Casual)
    Line("ez kill no cap", A.Casual)
    Line("got em lmao next?", A.Casual)

    Line("Kill confirmed. Resetting position.", A.Tryhard)
    Line("Target neutralized. Scanning for witnesses.", A.Tryhard)
    Line("Clean elimination. Adjusting for next target.", A.Tryhard)

    Line("HAHA GOTCHA!! WHO'S NEXT?!", A.Hothead)
    Line("THAT'S WHAT YOU GET! COME AT ME!", A.Hothead)
    Line("ONE DOWN! ANYONE ELSE WANT SOME?!", A.Hothead)

    Line("Done. Next.", A.Stoic)
    Line("One fewer. Moving on.", A.Stoic)

    Line("I'm sorry... I had to.", A.Nice)
    Line("Rest in peace. I didn't enjoy that.", A.Nice)

    Line("Pathetic. They didn't even fight back.", A.Bad)
    Line("Too easy. These people are clueless.", A.Bad)

    Line("wait did I just... oh no", A.Dumb)
    Line("oops haha that was kinda cool though", A.Dumb)

    Line("Target eliminated. Maintaining operational silence.", A.Teamer)

    Line("they never saw it coming... and they never will", A.Sus)

    RegisterCategory("SKShakeNade", P.MODERATE, "Serial Killer throwing a shake nade for area denial or escape.")
    Line("Shake nade out! That'll slow them down.", A.Default)
    Line("Threw a shake nade. Time to reposition.", A.Default)
    Line("Nade out — that should give me some space.", A.Default)

    Line("SHAKE NADE GO BRRR", A.Casual)
    Line("yeet lol have fun with that", A.Casual)
    Line("shake nade go wooooo", A.Casual)

    Line("Deploying shake grenade for area denial.", A.Tryhard)
    Line("Nade deployed. Controlling engagement zone.", A.Tryhard)

    Line("EAT THIS!! SHAKE NADE!!", A.Hothead)
    Line("TAKE THAT! GOOD LUCK AIMING NOW!", A.Hothead)

    Line("Deploying distraction.", A.Stoic)
    Line("Shake grenade out.", A.Stoic)

    Line("Sorry! Shake nade incoming!", A.Nice)

    Line("Have fun with that one.", A.Bad)
    Line("Bet you didn't see that coming.", A.Bad)

    Line("i threw the wiggly ball thing lol", A.Dumb)
    Line("shake shake shake!!", A.Dumb)

    Line("Area denial deployed. Team, push through!", A.Teamer)

    RegisterCategory("SKGloat", P.MODERATE, "Serial Killer gloating after getting multiple kills (>50% dead).")
    Line("I'm on a roll and nobody can stop me.", A.Default)
    Line("More than half of you are gone. Who's left?", A.Default)
    Line("They keep falling one by one.", A.Default)

    Line("lmaooo this is too easy", A.Casual)
    Line("bruh half of them are already dead", A.Casual)
    Line("im built different honestly", A.Casual)

    Line("Kill count exceeding projections. Excellent.", A.Tryhard)
    Line("Statistical advantage achieved. Maintaining momentum.", A.Tryhard)

    Line("IS THAT ALL YOU'VE GOT?! I WANT MORE!", A.Hothead)
    Line("BRING IT!! I'LL TAKE ALL OF YOU!", A.Hothead)
    Line("NOBODY CAN STOP ME!!", A.Hothead)

    Line("The numbers thin.", A.Stoic)
    Line("Progress continues.", A.Stoic)

    Line("I'm... I'm so sorry everyone. I can't help it.", A.Nice)
    Line("I wish I could stop... but I can't.", A.Nice)

    Line("Pathetic. All of you.", A.Bad)
    Line("This is what happens when you're weak.", A.Bad)

    Line("wow uh I've been doing really well huh", A.Dumb)
    Line("are people dying? who's doing that? oh wait", A.Dumb)

    Line("Operational success rate: high. Continuing mission.", A.Teamer)

    Line("I wonder who the killer could be... haha", A.Sus)
    Line("wow whoever is killing everyone is really good lol", A.Sus)

    RegisterCategory("SKLastStand", P.CRITICAL, "Serial Killer is one of the last 2-3 players alive.")
    Line("It's just us now. No more hiding.", A.Default)
    Line("Down to the last few. Let's finish this.", A.Default)
    Line("Almost done. Just a couple more.", A.Default)

    Line("oh we're down to the wire now huh", A.Casual)
    Line("last few standing lol this is intense", A.Casual)
    Line("endgame vibes", A.Casual)

    Line("Final phase. Executing cleanup.", A.Tryhard)
    Line("Two contacts remaining. Prioritizing elimination.", A.Tryhard)

    Line("IT'S THE ENDGAME!! COME FIGHT ME!", A.Hothead)
    Line("LAST ONES STANDING! LET'S GO!!", A.Hothead)

    Line("This ends now.", A.Stoic)
    Line("The finale.", A.Stoic)

    Line("I'm sorry it's come to this...", A.Nice)
    Line("Please... just let it be over.", A.Nice)

    Line("How does it feel knowing you're next?", A.Bad)
    Line("Almost done with all of you.", A.Bad)

    Line("wait there's only like 3 of us left??", A.Dumb)
    Line("uh oh this isn't good... or is it? hmmm", A.Dumb)

    Line("Final push. No survivors.", A.Teamer)

    Line("I wonder who the serial killer is... heh", A.Sus)

    RegisterCategory("SKSpotted", P.CRITICAL, "Serial Killer has been identified/KOS'd by others (from SK's perspective).")
    Line("They know it's me. Time to go loud.", A.Default)
    Line("Cover's blown. No more sneaking around.", A.Default)
    Line("They spotted me. Doesn't matter — I'll kill them all.", A.Default)

    Line("welp they found me out gg", A.Casual)
    Line("rip my stealth run lol time to go loud", A.Casual)
    Line("aight mask off i guess", A.Casual)

    Line("Compromised. Switching to aggressive protocol.", A.Tryhard)
    Line("Cover blown. Adapting to open engagement.", A.Tryhard)

    Line("FINE! YOU KNOW IT'S ME?! COME AND GET ME!", A.Hothead)
    Line("YOU WANT A FIGHT?! YOU GOT ONE!!", A.Hothead)

    Line("Discovered. Adjusting approach.", A.Stoic)
    Line("They know. It changes nothing.", A.Stoic)

    Line("Oh no... you figured it out. I'm sorry.", A.Nice)
    Line("I was hoping it wouldn't come to this.", A.Nice)

    Line("So what if you know? You're still going to die.", A.Bad)
    Line("Knowing who I am won't save you.", A.Bad)

    Line("they know it's me?? how did they figure it out??", A.Dumb)
    Line("uh oh everyone's looking at me funny", A.Dumb)

    Line("Position compromised. Going full assault.", A.Teamer)

    Line("okay okay so maybe I am the serial killer...", A.Sus)

    RegisterCategory("SKVictory", P.IMPORTANT, "Serial Killer won the round.")
    Line("I killed them all. Every last one.", A.Default)
    Line("Nobody could stop me. Victory.", A.Default)
    Line("That's what a real serial killer looks like.", A.Default)

    Line("gg ez serial killer wins lol", A.Casual)
    Line("told you i was built different", A.Casual)
    Line("absolute massacre ngl", A.Casual)

    Line("Mission accomplished. Flawless execution.", A.Tryhard)
    Line("100% kill rate achieved. GG.", A.Tryhard)

    Line("YESSS!! I KILLED EVERYONE!! UNSTOPPABLE!!", A.Hothead)
    Line("GET REKT!! THE SERIAL KILLER WINS!!", A.Hothead)

    Line("It is done.", A.Stoic)
    Line("All targets eliminated.", A.Stoic)

    Line("I'm sorry everyone... but I had to win.", A.Nice)
    Line("Good game everyone. I feel terrible though.", A.Nice)

    Line("Pathetic. Not a single one of you could stop me.", A.Bad)
    Line("You never had a chance.", A.Bad)

    Line("wait... did I win?? oh cool!!", A.Dumb)
    Line("i killed everyone?? that's kinda messed up lol", A.Dumb)

    Line("Serial Killer victory. Mission complete.", A.Teamer)

    Line("haha I told you guys I was innocent... lol jk", A.Sus)
    Line("plot twist: it was me the whole time!", A.Sus)

    RegisterCategory("SKSpottedByOthers", P.CRITICAL, "When a non-SK bot spots the Serial Killer or identifies them as the killer.")
    Line("That's the Serial Killer! Watch out!", A.Default)
    Line("I think {{player}} is the Serial Killer!", A.Default)
    Line("{{player}} has the SK knife! They're the killer!", A.Default)
    Line("Serial Killer spotted — it's {{player}}!", A.Default)

    Line("yo {{player}} is the serial killer!!", A.Casual)
    Line("bruh {{player}} has the knife run", A.Casual)
    Line("wait that's the sk!! {{player}}!!", A.Casual)

    Line("Confirmed: {{player}} is Serial Killer. Engaging.", A.Tryhard)
    Line("SK identified as {{player}}. All units respond.", A.Tryhard)

    Line("{{player}} IS THE SERIAL KILLER!! GET THEM!!", A.Hothead)
    Line("THAT'S THE KILLER!! SHOOT {{player}}!!", A.Hothead)

    Line("{{player}} is the Serial Killer.", A.Stoic)
    Line("The killer is {{player}}. Be cautious.", A.Stoic)

    Line("Oh no, {{player}} is the Serial Killer! Everyone be careful!", A.Nice)
    Line("Please watch out — {{player}} is the killer!", A.Nice)

    Line("Knew it. {{player}} is the Serial Killer.", A.Bad)
    Line("{{player}} is the SK. Shocking. Not.", A.Bad)

    Line("wait is {{player}} the serial killer??? oh no", A.Dumb)
    Line("{{player}} has a knife... is that bad??", A.Dumb)

    Line("Team! {{player}} is confirmed Serial Killer! Focus them!", A.Teamer)

    Line("{{player}} acting real sus... oh wait they're literally the serial killer", A.Sus)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadSKChats()
end
timer.Simple(1, loadModule_Deferred)
