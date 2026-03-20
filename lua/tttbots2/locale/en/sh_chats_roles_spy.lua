--[[
    Spy role chat categories

    This file contains chat lines for Spy role events.
    Categories included:
        SpyBlendIn, SpyFakeBuy, SpyReportIntel, SpyReactJam,
        SpyCoverBlow, SpyDeflection, SpySurvival, TraitorSuspectsSpy,
        TraitorDiscoversSpy, SpyPostReveal, SpyEavesdrop
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadSpyChats()
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
    -- SPY ROLE EVENTS
    -----------------------------------------------------------

    RegisterCategory("SpyBlendIn", P.NORMAL, "When a spy bot is blending in near a traitor, acting casual to maintain cover.")
    Line("Just hanging around. Nothing suspicious here.", A.Default)
    Line("Let's stick together, safer that way.", A.Default)
    Line("Anything going on over here?", A.Default)
    Line("Keeping my eyes peeled for traitors.", A.Default)

    Line("yo whats up", A.Casual)
    Line("just vibing", A.Casual)
    Line("chilling near you if thats cool", A.Casual)
    Line("sup lol", A.Casual)

    Line("Maintaining formation. Good situational awareness.", A.Tryhard)
    Line("Covering this sector. Stay frosty.", A.Tryhard)
    Line("Holding position. Report any contacts.", A.Tryhard)

    Line("What are you looking at?!", A.Hothead)
    Line("Stay away from me! I mean— stay close. For safety.", A.Hothead)

    Line("Nothing out of the ordinary.", A.Stoic)
    Line("All seems quiet here.", A.Stoic)
    Line("Proceeding normally.", A.Stoic)

    Line("Hey! How's it going? Everything okay?", A.Nice)
    Line("Glad we're sticking together! Safety in numbers!", A.Nice)
    Line("You're looking a bit nervous. Everything alright?", A.Nice)

    Line("I'm definitely a traitor too. Yep. For sure.", A.Bad)
    Line("So when do we... do the thing? You know. The thing.", A.Bad)

    Line("wait are we supposed to go somewhere? i forgot", A.Dumb)
    Line("are you a traitor? wait am I a traitor? im confused", A.Dumb)
    Line("i think im lost lol", A.Dumb)

    Line("Let's group up, safer for the team!", A.Teamer)
    Line("Good to have a partner. We got this.", A.Teamer)

    Line("Interesting choice of weapon you got there...", A.Sus)
    Line("You seem... calm. Too calm.", A.Sus)
    Line("I've got my eye on you. In a friendly way of course.", A.Sus)

    RegisterCategory("SpyFakeBuy", P.NORMAL, "When a spy bot completes a fake equipment purchase to deceive traitors.")
    Line("Just bought some equipment.", A.Default)
    Line("Got myself a little something from the shop.", A.Default)
    Line("Stocking up on gear.", A.Default)

    Line("got some stuff lol", A.Casual)
    Line("shopping spree time", A.Casual)

    Line("Equipment acquired. Optimizing loadout.", A.Tryhard)
    Line("Purchased tactical advantage. Ready for engagement.", A.Tryhard)

    Line("YEAH! NEW TOYS!", A.Hothead)

    Line("Equipment purchased.", A.Stoic)

    Line("Ooh, got something nice from the shop!", A.Nice)

    Line("This should make things... interesting.", A.Bad)

    Line("i bought a thing but what does it do", A.Dumb)
    Line("shopping!! wait how do i use this", A.Dumb)

    Line("Gearing up for the team!", A.Teamer)

    Line("Just picked up a little something... don't ask what.", A.Sus)

    RegisterCategory("SpyReportIntel", P.IMPORTANT, "When a spy bot reports traitor intel to an innocent or detective. {{player}} is the traitor being reported, {{target}} is who they're reporting to.")
    Line("I saw {{player}} doing something suspicious! Be careful!", A.Default)
    Line("Watch out for {{player}}, they're not what they seem.", A.Default)
    Line("{{player}} is one of the bad guys, trust me on this.", A.Default)
    Line("I have intel on {{player}} — they're a traitor!", A.Default)

    Line("yo {{player}} is sus af trust me", A.Casual)
    Line("dude {{player}} is a traitor im telling you", A.Casual)
    Line("heads up {{player}} is bad news", A.Casual)

    Line("Intel report: {{player}} confirmed hostile. Engage with caution.", A.Tryhard)
    Line("Target identified: {{player}}. Traitor confirmed. Relay to all units.", A.Tryhard)

    Line("{{player}} IS A TRAITOR! I KNEW IT!", A.Hothead)
    Line("I CAUGHT {{player}} RED-HANDED!", A.Hothead)

    Line("{{player}} is a traitor.", A.Stoic)
    Line("Confirmed hostile: {{player}}.", A.Stoic)

    Line("I really hate to say it, but {{player}} is a traitor...", A.Nice)
    Line("Please be careful around {{player}}, they're not on our side.", A.Nice)

    Line("Heh, figured {{player}} was a traitor all along.", A.Bad)
    Line("{{player}} is a traitor. Saw it coming.", A.Bad)

    Line("umm i think {{player}} might be bad?? idk", A.Dumb)
    Line("is {{player}} a traitor? they looked kinda evil to me", A.Dumb)

    Line("Everyone listen! {{player}} is a confirmed traitor! Group up!", A.Teamer)
    Line("Team intel: {{player}} is hostile. Watch each other's backs!", A.Teamer)

    Line("I know things about {{player}}... dark things.", A.Sus)
    Line("{{player}}... isn't who they say they are.", A.Sus)

    RegisterCategory("SpyReactJam", P.NORMAL, "When a traitor bot's team chat is jammed by the spy's presence and they react to it.")
    Line("Why can't I use team chat?!", A.Default)
    Line("Something is blocking our comms!", A.Default)
    Line("Team chat isn't working... that's weird.", A.Default)

    Line("bruh team chat is broken", A.Casual)
    Line("yo why cant i talk to my team", A.Casual)
    Line("comms are down or something", A.Casual)

    Line("Communication jamming detected. Possible spy interference.", A.Tryhard)
    Line("Comms compromised. Adjusting to open-channel protocol.", A.Tryhard)

    Line("WHO'S JAMMING OUR COMMS?! THERE'S A SPY!", A.Hothead)
    Line("SOMEONE IS MESSING WITH OUR TEAM CHAT!", A.Hothead)

    Line("Comms jammed. Interesting.", A.Stoic)
    Line("Team channel is compromised.", A.Stoic)

    Line("Oh no, I can't reach my teammates...", A.Nice)

    Line("Great. Someone's ruining our comms.", A.Bad)
    Line("Useless. Can't even talk to my own team.", A.Bad)

    Line("wait why cant i talk to the other traitors? am i broken?", A.Dumb)
    Line("hello? hello? is this thing on?", A.Dumb)

    Line("Team comms are down! We might have a spy! Stay alert!", A.Teamer)

    Line("The silence is... deafening.", A.Sus)
    Line("Someone doesn't want us talking. Curious.", A.Sus)

    RegisterCategory("SpyCoverBlow", P.IMPORTANT, "When a spy bot's cover is blown and traitors discover they're not really a traitor.")
    Line("They found me out! Cover's blown!", A.Default)
    Line("Well, the jig is up. They know I'm not a traitor.", A.Default)
    Line("Cover blown. Time for plan B.", A.Default)

    Line("oh no they caught me lmao", A.Casual)
    Line("welp cover blown gg", A.Casual)
    Line("busted lol", A.Casual)

    Line("Cover compromised. Switching to direct engagement.", A.Tryhard)
    Line("Identity exposed. Falling back to contingency protocol.", A.Tryhard)

    Line("THEY FOUND ME OUT?! FINE! COME AT ME!", A.Hothead)
    Line("YOU THINK BLOWING MY COVER SCARES ME?!", A.Hothead)

    Line("Cover's blown. Moving on.", A.Stoic)
    Line("So they know. Makes no difference.", A.Stoic)

    Line("Oh dear, they figured me out...", A.Nice)
    Line("I'm sorry everyone, I tried my best to stay hidden!", A.Nice)

    Line("Took them long enough to figure it out.", A.Bad)
    Line("Whatever. I got what I needed anyway.", A.Bad)

    Line("wait they know im not a traitor?? how??", A.Dumb)
    Line("oh no am i in trouble now", A.Dumb)

    Line("My cover's blown! Innocents, I'm on your side!", A.Teamer)

    Line("The mask falls... but the show isn't over.", A.Sus)
    Line("Hmm. They saw through me. How perceptive.", A.Sus)

    RegisterCategory("SpyDeflection", P.NORMAL, "When a spy bot deflects suspicion by acting innocent or redirecting blame.")
    Line("Who, me? I'm just an innocent bystander.", A.Default)
    Line("I have no idea what you're talking about.", A.Default)
    Line("You've got the wrong person.", A.Default)

    Line("nah wasnt me lol", A.Casual)
    Line("idk what ur talking about", A.Casual)

    Line("Negative. Your intel is flawed.", A.Tryhard)
    Line("I suggest you re-evaluate your target priority.", A.Tryhard)

    Line("YOU ACCUSING ME?! BACK OFF!", A.Hothead)
    Line("TRY ME! I DARE YOU!", A.Hothead)

    Line("Incorrect.", A.Stoic)
    Line("You're mistaken.", A.Stoic)

    Line("Oh, I would never! You must be thinking of someone else!", A.Nice)
    Line("Me? No no no, I'm one of the good guys!", A.Nice)

    Line("Ha. Accuse me all you want. Makes you look dumb.", A.Bad)

    Line("huh?? what did i do??", A.Dumb)
    Line("i didnt do anything i swear! ...i think", A.Dumb)

    Line("I'm with the team! Don't turn on each other!", A.Teamer)

    Line("Or... maybe you're the one we should be watching.", A.Sus)
    Line("Interesting accusation. Very... revealing.", A.Sus)

    RegisterCategory("SpySurvival", P.IMPORTANT, "When a spy bot survived the round, post-round celebration.")
    Line("Made it through! The spy lives to fight another day.", A.Default)
    Line("And nobody suspected a thing!", A.Default)
    Line("Mission accomplished. Intel gathered, cover maintained.", A.Default)

    Line("lol i survived gg", A.Casual)
    Line("ez spy win", A.Casual)
    Line("they never figured me out haha", A.Casual)

    Line("Mission complete. Spy successfully embedded. Zero casualties.", A.Tryhard)
    Line("Full round survival achieved. Optimal spy performance.", A.Tryhard)

    Line("HAHA! I WAS RIGHT THERE THE WHOLE TIME!", A.Hothead)
    Line("YOU COULDN'T CATCH ME! THE SPY WINS!", A.Hothead)

    Line("Survived.", A.Stoic)
    Line("Another day, another successful mission.", A.Stoic)

    Line("I'm so glad I made it! Good game everyone!", A.Nice)
    Line("That was scary, but we did it!", A.Nice)

    Line("None of you had a clue. Pathetic.", A.Bad)
    Line("Too easy. I was literally standing right there.", A.Bad)

    Line("wait i won?? nice!!", A.Dumb)
    Line("did i do good? i have no idea what happened lol", A.Dumb)

    Line("The spy made it! Great teamwork from the innocents!", A.Teamer)

    Line("I was among you the whole time... and you never knew.", A.Sus)
    Line("The spy always wins in the end.", A.Sus)

    RegisterCategory("TraitorSuspectsSpy", P.NORMAL, "When a traitor bot becomes suspicious that {{player}} might not really be a traitor (might be a spy).")
    Line("Wait... is {{player}} really one of us?", A.Default)
    Line("Something feels off about {{player}}...", A.Default)
    Line("I'm not so sure about {{player}} anymore.", A.Default)

    Line("yo is {{player}} actually a traitor tho", A.Casual)
    Line("hmm {{player}} is acting kinda weird for a traitor", A.Casual)

    Line("Anomalous behavior detected from {{player}}. Possible spy.", A.Tryhard)
    Line("Running identity verification on {{player}}. Patterns inconsistent.", A.Tryhard)

    Line("{{player}} IS ACTING WEIRD! ARE THEY A SPY?!", A.Hothead)
    Line("I DON'T TRUST {{player}}!", A.Hothead)

    Line("{{player}} seems... different.", A.Stoic)
    Line("Observing inconsistencies in {{player}}'s behavior.", A.Stoic)

    Line("Hey {{player}}, are you feeling okay?", A.Nice)

    Line("I always had a bad feeling about {{player}}.", A.Bad)
    Line("{{player}} is sketchy. Just saying.", A.Bad)

    Line("is {{player}} supposed to be with us? i cant remember", A.Dumb)

    Line("Team, keep an eye on {{player}}. Something isn't right.", A.Teamer)

    Line("{{player}}... I've been watching you. Interesting behavior.", A.Sus)
    Line("There's something {{player}} isn't telling us.", A.Sus)

    RegisterCategory("TraitorDiscoversSpy", P.CRITICAL, "When a traitor bot fully discovers that {{player}} is a spy infiltrator.")
    Line("{{player}} is a SPY! They're not one of us!", A.Default)
    Line("We've been infiltrated! {{player}} is a spy!", A.Default)
    Line("{{player}} was faking it the whole time!", A.Default)

    Line("LMAO {{player}} IS A SPY", A.Casual)
    Line("yo {{player}} was a spy this whole time bruh", A.Casual)

    Line("SPY CONFIRMED: {{player}}. All units, eliminate immediately.", A.Tryhard)
    Line("Intelligence breach! {{player}} is a spy. Neutralize!", A.Tryhard)

    Line("{{player}} IS A SPY!! GET THEM!! NOW!!", A.Hothead)
    Line("A SPY?! {{player}} YOU'RE DEAD!", A.Hothead)

    Line("{{player}} is a spy. Eliminating.", A.Stoic)
    Line("Identity confirmed: {{player}} is a spy.", A.Stoic)

    Line("Oh no, {{player}} was a spy all along!", A.Nice)
    Line("I can't believe {{player}} tricked us...", A.Nice)

    Line("Knew it. {{player}} was too good to be true.", A.Bad)
    Line("{{player}} is a spy. Should've known.", A.Bad)

    Line("wait {{player}} isnt a traitor?? then what are they??", A.Dumb)
    Line("{{player}} is a... spy? what does that mean", A.Dumb)

    Line("TRAITORS! {{player}} IS A SPY! Focus fire!", A.Teamer)

    Line("A spy in our midst... how delightfully devious.", A.Sus)
    Line("{{player}}... the master of disguise. Until now.", A.Sus)

    RegisterCategory("SpyPostReveal", P.IMPORTANT, "Post-round: when a traitor bot reacts to learning that {{player}} was a spy the whole time.")
    Line("{{player}} was a spy?! No way!", A.Default)
    Line("I can't believe {{player}} was a spy this whole time!", A.Default)
    Line("A spy? That explains everything about {{player}}.", A.Default)

    Line("BRO {{player}} WAS A SPY?? WTF", A.Casual)
    Line("no way {{player}} was a spy lmao", A.Casual)
    Line("{{player}} had us all fooled haha", A.Casual)

    Line("Post-round analysis: {{player}} was a spy. Noted for future reference.", A.Tryhard)
    Line("Debrief: {{player}} was embedded as spy. Must improve detection protocols.", A.Tryhard)

    Line("{{player}} WAS A SPY?! HOW DID WE NOT NOTICE?!", A.Hothead)
    Line("ARE YOU KIDDING ME?! {{player}} WAS A SPY!!", A.Hothead)

    Line("{{player}} was a spy. Acknowledged.", A.Stoic)
    Line("Interesting. {{player}} was a spy.", A.Stoic)

    Line("Oh wow, {{player}} was a spy! Well played!", A.Nice)
    Line("Good job {{player}}! You really fooled us!", A.Nice)

    Line("{{player}} was a spy. Should've seen it coming.", A.Bad)
    Line("A spy. Of course. Useless teammates couldn't spot {{player}}.", A.Bad)

    Line("{{player}} was a SPY?! i thought they were our friend!", A.Dumb)
    Line("wait so {{player}} was pretending? thats so confusing", A.Dumb)

    Line("Team, {{player}} was a spy. Let's learn from this.", A.Teamer)

    Line("I had a feeling about {{player}} all along. Did anyone listen? No.", A.Sus)
    Line("{{player}}... the ultimate deception. I'm almost impressed.", A.Sus)

    RegisterCategory("SpyEavesdrop", P.NORMAL, "When a spy bot is eavesdropping on a traitor's activity from a distance.")
    Line("I see what they're up to...", A.Default)
    Line("Interesting... very interesting.", A.Default)
    Line("Taking notes on their activity.", A.Default)

    Line("hehe watching them from here", A.Casual)
    Line("sneaky sneaky", A.Casual)

    Line("Surveillance active. Gathering tactical intelligence.", A.Tryhard)
    Line("Observing target behavior patterns. Recording.", A.Tryhard)

    Line("I see EVERYTHING you're doing!", A.Hothead)

    Line("Observing.", A.Stoic)
    Line("Noted.", A.Stoic)

    Line("Oh my, what are they doing over there...", A.Nice)

    Line("Keep talking. I'm listening.", A.Bad)
    Line("Fools don't even know I'm watching.", A.Bad)

    Line("what are they doing? looks weird", A.Dumb)
    Line("i see something happening but idk what it is", A.Dumb)

    Line("Gathering intel for the team!", A.Teamer)

    Line("From the shadows, I see all...", A.Sus)
    Line("How curious... they think nobody's watching.", A.Sus)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadSpyChats()
end
timer.Simple(1, loadModule_Deferred)
