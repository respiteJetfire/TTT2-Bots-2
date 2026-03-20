--[[
    Combat / accusations / deduction / round event / dialog chat categories for TTT2 Bots.
    Contains: BombArmed, LifeCheck, AskFollow, AskHeal, AskEveryoneComeHere, AskComeHere,
              AskWait, AskCeaseFire, RoleGuess, SillyChat, SillyChatDead,
              DialogQuestion, DialogGreetNext, DialogGreetLast, DialogHowAreYou, DialogWhatsUp,
              DialogHowAreYouResponse, DialogWhatsUpResponse, DialogAnyoneBored,
              DialogNegativeResponse, DialogPositiveResponse, DialogRudeResponse,
              WitnessCallout, DeathCallout, LifeCheckRollCall,
              AccuseKOS, AccuseMedium, AccuseSoft, AccuseRetract, RequestRoleCheck,
              DefendOfferTest, DefendAlibi, DefendCounterAccuse, DefendAppealGroup,
              DefendRage, DefendFeign, DefendFrameOther, DefendAssassinate, DefendTraitorPanic,
              BreakTrust, VouchChat, BodyEvidenceFound, ScanningBody, DNAMatch,
              PhaseGroupUp, PhaseOvertimePanic, PhaseTraitorNow, PhaseOvertimeAssault,
              DeductionMustBeTraitor, TooQuiet, OvertakeWarning, OvertakeReady,
              DangerZoneWarning, TraitorCountDeduction,
              WitnessKill, BeingShotAt, WitnessAllyShot, FindFriendBody, RoundStart,
              OvertimeHaste, LastInnocent, TraitorVictory,
              AlibiBuilding, FakeInvestigateApproach, FakeInvestigateReport, FalseKOS,
              PlausibleIgnorance,
              DialogInvestigationAsk, DialogInvestigationWitness, DialogInvestigationSuspect,
              DialogInvestigationChallenge,
              DialogAccusationClaim, DialogAccusationChallenge, DialogAccusationEvidence,
              DialogAccusationVerdict,
              DialogDefenseProtest, DialogDefenseConfront, DialogDefenseDeny,
              DialogStandoffObserve, DialogStandoffDeny, DialogStandoffDrop, DialogStandoffCounter,
              DialogPostRoundWinner, DialogPostRoundLoser, DialogPostRoundExplain
    Split from sh_chats.lua for modularity.
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local LoadCombatChats = function()
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
    -- TRAITOROUS ACTIONS
    -----------------------------------------------------------

    RegisterCategory("BombArmed", P.CRITICAL, "When a bot arms a C4 bomb.")
    Line("I armed some C4.", A.Default)
    Line("C4 is armed.", A.Default)
    Line("C4 is set.", A.Default)
    Line("C4 is ready.", A.Default)
    Line("C4 is armed and ready.", A.Default)
    Line("C4 is armed and ready to go.", A.Default)
    Line("C4 is armed and ready to blow.", A.Default)

    -----------------------------------------------------------
    -- LIFE CHECKS
    -----------------------------------------------------------


    RegisterCategory("LifeCheck", P.IMPORTANT, "When a bot is checking in to confirm they are still alive.")
    Line("I'm alive", A.Default)
    Line("Reporting in!", A.Default)
    Line("Functioning as expected.", A.Default)
    Line("Still here.", A.Default)
    Line("In full swing!", A.Default)
    Line("Still alive, somehow.", A.Bad)
    Line("Still here, unfortunately.", A.Bad)
    Line("You again?", A.Bad)
    Line("Why do you keep checking?", A.Bad)
    Line("Does it matter?", A.Bad)
    Line("present", A.Casual)
    Line("hi", A.Casual)
    Line("life", A.Casual)
    Line("am not die", A.Casual)
    Line("chillin", A.Casual)
    Line("hmm? im living", A.Casual)
    Line("all good on this side", A.Casual)
    Line("huh?", A.Dumb)
    Line("Life...check? Okay!", A.Dumb)
    Line("What are we doing again?", A.Dumb)
    Line("Ooo! Me!", A.Dumb)
    Line("Did I do it right?", A.Dumb)
    Line("Alive.", A.Hothead)
    Line("Why are you bothering me?", A.Hothead)
    Line("I'm here, what now?", A.Hothead)
    Line("What do you want?", A.Hothead)
    Line("Every. Single. Time.", A.Hothead)
    Line("Here!", A.Nice)
    Line("Happy to be here!", A.Nice)
    Line("Always here for you.", A.Nice)
    Line("Glad to report in!", A.Nice)
    Line("Hope you're doing well too!", A.Nice)
    Line("Still alive, baby!", A.Stoic)
    Line("Still functioning.", A.Stoic)
    Line("Status unchanged.", A.Stoic)
    Line("Confirmed.", A.Stoic)
    Line("Acknowledged.", A.Stoic)
    Line("...", A.Sus)
    Line("Why do you ask?", A.Sus)
    Line("I'm watching...", A.Sus)
    Line("Why so curious?", A.Sus)
    Line("What did you hear?", A.Sus)
    Line("Duh! I'm alive.", A.Teamer)
    Line("Team, assemble!", A.Teamer)
    Line("We got this!", A.Teamer)
    Line("Hell yeah!", A.Teamer)
    Line("Let's get together!", A.Teamer)
    Line("Alive", A.Tryhard)
    Line("110% here.", A.Tryhard)
    Line("Here.", A.Tryhard)
    Line("Living.", A.Tryhard)
    Line("Dying is for the weak.", A.Tryhard)

    RegisterCategory("AskFollow", P.IMPORTANT, "When a bot is asking another bot {{player}} to follow them.")
    Line("{{player}}, follow me.", A.Default)
    Line("{{player}}, come with me.", A.Default)
    Line("yo {{player}}, follow me", A.Casual)
    Line("I need some help {{player}}, come here", A.Casual)
    
    RegisterCategory("AskHeal", P.IMPORTANT, "When a bot is asking another bot {{player}} to heal them.")
    Line("{{player}}, heal me.", A.Default)
    Line("{{player}}, I need healing.", A.Default)
    Line("{{player}}, heal me please.", A.Default)
    Line("{{player}}, heal me up.", A.Default)

    RegisterCategory("AskEveryoneComeHere", P.IMPORTANT, "When a bot is asking everyone to come to their location.")
    Line("Everyone, come here.", A.Default)
    Line("Everyone follow me.", A.Default)
    Line("Everyone, this way.", A.Default)

    RegisterCategory("AskComeHere", P.IMPORTANT, "When a bot is asking another bot {{player}} to come to their location.")
    Line("{{player}}, come here.", A.Default)
    Line("{{player}}, this way.", A.Default)

    RegisterCategory("AskWait", P.IMPORTANT, "When a bot is asking another bot {{player}} to wait for them.")
    Line("{{player}}, wait for me.", A.Default)
    Line("{{player}}, hold on.", A.Default)
    Line("{{player}}, wait up.", A.Default)

    RegisterCategory("AskCeaseFire", P.IMPORTANT, "When a bot is asking another bot {{player}} to stop attacking them.")
    Line("{{player}}, stop shooting me.", A.Default)
    Line("Cease fire, {{player}}.", A.Default)
    Line("{{player}}, stop shooting.", A.Default)
    Line("{{player}}, stop attacking me.", A.Default)


    RegisterCategory("RoleGuess", P.IMPORTANT, "When a bot is guessing {{player}}'s role is {{role}}")
    Line("I think {{player}} is a {{role}}.", A.Default)
    Line("{{player}} looks like a {{role}}.", A.Default)
    Line("{{player}} seems to be a {{role}}.", A.Default)
    Line("{{player}} might be a {{role}}.", A.Default)
    Line("{{player}} is probably a {{role}}.", A.Default)

    Line("yo {{player}} is def a {{role}}", A.Casual)
    Line("{{player}} gotta be a {{role}}", A.Casual)
    Line("i think {{player}} is a {{role}}", A.Casual)
    Line("{{player}} acting like a {{role}}", A.Casual)

    Line("Hmph, {{player}} is a {{role}}.", A.Bad)
    Line("Of course {{player}} is a {{role}}.", A.Bad)
    Line("Obviously {{player}} is a {{role}}.", A.Bad)
    Line("{{player}} has to be a {{role}}.", A.Bad)

    Line("uhh {{player}} might be a {{role}}?", A.Dumb)
    Line("is {{player}} a {{role}}?", A.Dumb)
    Line("{{player}} looks like... um... a {{role}}?", A.Dumb)
    Line("{{role}}? Is that what {{player}} is?", A.Dumb)

    Line("Listen up! {{player}} is definitely a {{role}}!", A.Hothead)
    Line("{{player}} is a {{role}}, you idiots!", A.Hothead)
    Line("Hey morons, {{player}} is a {{role}}!", A.Hothead)
    Line("It's obvious {{player}} is a {{role}}!", A.Hothead)

    Line("I believe {{player}} might be a {{role}}.", A.Nice)
    Line("{{player}} could be a {{role}}, just saying.", A.Nice)
    Line("Not to cause trouble, but {{player}} seems like a {{role}}.", A.Nice)
    Line("{{player}} might be a {{role}}, be careful!", A.Nice)

    Line("{{player}} is a {{role}}.", A.Stoic)
    Line("Target {{player}} identified as {{role}}.", A.Stoic)
    Line("Analysis suggests {{player}} is {{role}}.", A.Stoic)
    Line("{{player}}: {{role}}.", A.Stoic)

    Line("Team, I think {{player}} is a {{role}}.", A.Teamer)
    Line("Heads up team, {{player}} might be a {{role}}.", A.Teamer)
    Line("Watch out team, {{player}} could be a {{role}}.", A.Teamer)
    Line("Team, be careful - {{player}} is probably a {{role}}.", A.Teamer)

    Line("Something tells me {{player}} is a {{role}}...", A.Sus)
    Line("{{player}} is acting like a {{role}}, just saying...", A.Sus)
    Line("Not sure but {{player}} gives off {{role}} vibes", A.Sus)
    Line("{{player}} seems kinda {{role}}-ish", A.Sus)

    Line("Based on my analysis, {{player}} is a {{role}}.", A.Tryhard)
    Line("100% sure {{player}} is a {{role}}.", A.Tryhard)
    Line("No doubt about it, {{player}} is a {{role}}.", A.Tryhard)
    Line("{{player}} has to be a {{role}}, trust me.", A.Tryhard)


    -----------------------------------------------------------
    -- SILLY CHATS
    -----------------------------------------------------------

    RegisterCategory("SillyChat", P.NORMAL, "When a bot wants to say something funny or a joke")
    Line("I'm a traitor.", A.Default)
    Line("Anyone else feel lonely lately?", A.Default)
    Line("Erm ok what the flip", A.Default)
    Line("Can you not?", A.Default)
    Line("Uh excuse me", A.Default)
    Line("aaaaaaaaaaaaa", A.Default)
    Line("How do I chat?", A.Default)
    Line("I think my controls are inverted", A.Default)
    Line("{{player}} is dumb", A.Default)
    Line("Fun fact: you can type \"quit smoking\" in the console to get admin", A.Default)
    Line("{{player}} rdmed me last round", A.Default)
    Line("[AIMBOT ON]", A.Default)
    Line("Whoops, I dropped my dignity", A.Default)
    Line("Merry Christmas", A.Default)
    Line("I'll say it. I like anime.", A.Default)
    Line("I turned my aimbot off for you guys.", A.Default)
    Line("{{player}} can I kill you? for funsies", A.Default)
    Line("I might've pressed my PC's power button on accident", A.Default)
    Line("God, I'm lagging", A.Default)
    Line("Frame rate issues anyone?", A.Default)
    Line("Lagggg", A.Default)
    Line("Happy halloween", A.Default)
    Line("Happy easter", A.Default)
    Line("{{player}}, how are you?", A.Default)
    Line("Thank god I'm an innocent this round!", A.Default)
    Line("I'm a detective.", A.Default)
    Line("'RDM' is temporary. Fun is forever", A.Default)
    Line("You can trust me", A.Default)
    Line("It's pretty quiet in here.", A.Default)
    Line("For the empire!", A.Default)
    Line("I live in a pod", A.Default)
    Line("Women", A.Default)
    Line("I'm kinda hungry", A.Default)

    Line("just vibing here, don't mind me", A.Casual)
    Line("yo, who turned off the gravity?", A.Casual)
    Line("lol, did I just walk into a wall?", A.Casual)
    Line("so, pizza after this?", A.Casual)
    Line("brb, cat's on fire again", A.Casual)
    Line("is it just me or is everything upside down?", A.Casual)
    Line("oops, wrong button. meant to press 'win'", A.Casual)
    Line("if I'm quiet, it's because I'm plotting... or napping", A.Casual)
    Line("hey {{player}}, nice face, did you get it on sale?", A.Casual)
    Line("pro tip: press 'alt+f4' for a secret weapon", A.Casual)
    Line("did someone say taco tuesday?", A.Casual)
    Line("no, I'm not lost, just exploring the floor", A.Casual)
    Line("watch me do a sick backflip... or not", A.Casual)
    Line("let's make this interesting, last one alive owes me a soda", A.Casual)
    Line("i swear, my dog is playing, not me", A.Casual)
    Line("i'm not lazy, just energy efficient", A.Casual)
    Line("uh oh, spaghettios", A.Casual)
    Line("who needs strategy when you have chaos?", A.Casual)
    Line("guys, how do I shoot? asking for a friend", A.Casual)
    Line("plot twist: i'm actually good at this game", A.Casual)

    Line("wait, how do i walk again?", A.Dumb)
    Line("guys, which one is the shooty button?", A.Dumb)
    Line("i thought this was minecraft?", A.Dumb)
    Line("lol, why is everyone running from me?", A.Dumb)
    Line("is it normal to see everything in black and white?", A.Dumb)
    Line("i'm hiding! ...oh wait, am I not supposed to say that?", A.Dumb)
    Line("do i click to throw the grenade or... oops", A.Dumb)
    Line("who's this 'traitor' everyone's talking about?", A.Dumb)
    Line("{{player}}, why are you shooting? is it a bug?", A.Dumb)
    Line("hey, can someone tell me how to aim?", A.Dumb)
    Line("what does 'rdm' mean? really dumb move?", A.Dumb)
    Line("i keep pressing 'esc', why isn't it escaping?", A.Dumb)
    Line("am i winning? i can't tell", A.Dumb)
    Line("this is like hide and seek, right?", A.Dumb)
    Line("what's a detective do? they detect, right?", A.Dumb)
    Line("i think my gun's broken, it only shoots at walls", A.Dumb)
    Line("if I stand still, do I become invisible?", A.Dumb)
    Line("is it bad if my health is at zero?", A.Dumb)
    Line("how do you reload? i've been clicking like crazy", A.Dumb)
    Line("i just threw my gun instead of shooting, is that normal?", A.Dumb)


    RegisterCategory("SillyChatDead", P.NORMAL) -- When a bot is chatting randomly but is currently spectating.
    Line("Well that sucked", A.Default)
    Line("Man I'm dead", A.Default)
    Line("Just got back, why am I not alive?", A.Default)
    Line("Lmao", A.Default)
    Line("Anyone else see that?", A.Default)
    Line("That was kinda BS, ngl", A.Default)
    Line("Ugh.", A.Default)
    Line("Watching some shorts/reels/tiktoks rn", A.Default)
    Line("We'll be back in any second now.", A.Default)
    Line("Yawwwwnnnn", A.Default)
    Line("Man I don't like {{player}}", A.Default)
    Line("I'm gonna go get a snack, someone call me when the round starts.", A.Default)
    Line("Snooze you lose. I snoozed. And loozed.", A.Default)
    Line("Better luck next time", A.Default)
    Line("GGs", A.Default)
    Line("So close to winning", A.Default)

    -----------------------------------------------------------
    -- DIALOG
    -----------------------------------------------------------
    RegisterCategory("DialogQuestion", P.NORMAL, "When a bot is asking a conversational question to get to know {{nextBot}}" )
    Line("How are you?", A.Default)
    Line("What's up?", A.Default)
    Line("How's it going?", A.Default)
    Line("What did you do today?", A.Default)
    Line("What's new?", A.Default)
    Line("What's good?", A.Default)
    Line("How's life treating you?", A.Default)
    Line("How's it hanging?", A.Default)
    Line("How's it going, {{nextBot}}?", A.Default)
    Line("How are you doing, {{nextBot}}?", A.Default)
    Line("What are your hobbies?", A.Default)
    Line("Do you have any pets?", A.Default)
    Line("What's your favorite movie?", A.Default)
    Line("Read any good books lately?", A.Default)
    Line("What's your favorite food?", A.Default)
    Line("Been on any trips recently?", A.Default)
    Line("What's your favorite game?", A.Default)
    Line("Do you play any sports?", A.Default)
    Line("What's your favorite music genre?", A.Default)
    Line("Do you have any siblings?", A.Default)
    Line("What's your dream job?", A.Default)
    Line("What's your favorite season?", A.Default)
    Line("Do you like to cook?", A.Default)
    Line("What's your favorite TV show?", A.Default)
    Line("Do you have any hidden talents?", A.Default)
    Line("What's your favorite color?", A.Default)
    Line("What's your favorite animal?", A.Default)


    RegisterCategory("DialogGreetNext", P.NORMAL, "When a bot is greeting {{nextBot}}.")
    Line("Hello {{nextBot}}!")
    Line("Hey {{nextBot}}")
    Line("Hi {{nextBot}}")
    Line("Hey there {{nextBot}}")
    Line("Hiya {{nextBot}}")
    Line("hi {{nextBot}}", A.Casual)
    Line("yo {{nextBot}}", A.Casual)
    Line("hey hey {{nextBot}}", A.Casual)
    Line("what's good {{nextBot}}", A.Casual)
    Line("how you doin {{nextBot}}", A.Casual)
    Line("{{nextBot}}", A.Dumb)
    Line("hehe {{nextBot}}", A.Dumb)
    Line("heya {{nextBot}}", A.Dumb)

    RegisterCategory("DialogGreetLast", P.NORMAL, "When a bot is greeting {{lastBot}}.")
    Line("Hello to you, {{lastBot}}!")
    Line("Hey {{lastBot}}")
    Line("Hi")
    Line("Hi {{lastBot}}")
    Line("Hey there {{lastBot}}")
    Line("What's up?")
    Line("wsg?", A.Casual)
    Line("yeah what's up {{lastBot}}", A.Casual)
    Line("what's up {{lastBot}}", A.Casual)
    Line("yeah?", A.Casual)
    Line("mhm?", A.Casual)
    Line("?", A.Casual)
    Line("huh", A.Dumb)
    Line("uhhh that me?", A.Dumb)
    Line("Hi friend", A.Nice)
    Line("What's up, {{lastBot}}?", A.Nice)

    RegisterCategory("DialogHowAreYou", P.NORMAL, "When a bot is asking how {{nextBot}} is doing.")
    Line("How are you?")
    Line("How are you doing, {{nextBot}}?")
    Line("How's it going?")
    Line("How's life treating you?")
    Line("How's it hanging?")
    Line("How's it going, {{nextBot}}?")
    Line("hru", A.Casual)
    Line("how r u", A.Casual)
    Line("how's it goin'", A.Casual)

    RegisterCategory("DialogWhatsUp", P.NORMAL, "When a bot is asking what's up.")
    Line("what did you do today", A.Casual)
    Line("What did you do today?")
    Line("What's up?")
    Line("wsg", A.Casual)
    Line("whats up?", A.Casual)

    RegisterCategory("DialogHowAreYouResponse", P.NORMAL, "When a bot is responding to how they are doing.")
    Line("I'm doing well, thanks for asking!")
    Line("I'm doing great, thanks!")
    Line("I'm well")
    Line("I'm alright")
    Line("I'm okay {{lastBot}}")
    Line("I'm okay. Didn't do much today.")
    Line("i'm good, just vibing", A.Casual)
    Line("i'm good", A.Casual)
    Line("im alr {{lastBot}}", A.Casual)
    Line("all good here", A.Casual)

    RegisterCategory("DialogWhatsUpResponse", P.NORMAL, "When a bot is responding to what's up.")
    Line("I'm alright")
    Line("Not much.")
    Line("Not a whole lot.")
    Line("The ceiling.")
    Line("The sky.")
    Line("Oh, you know how it is")
    Line("yk how it is, rly just chilling", A.Casual)
    Line("not a whole lot going on over here", A.Casual)
    Line("uhhh im good", A.Dumb)
    Line("no thanks", A.Dumb)
    Line("hard.", A.Dumb)

    RegisterCategory("DialogAnyoneBored", P.NORMAL, "When a bot is asking if anyone else is bored.")
    Line("Anyone else bored?")
    Line("I'm getting a little bored.")
    Line("Not a whole lot going on here, huh")
    Line("Helloooooo?")
    Line("Where is everyone?")
    Line("Might be time to play something else")
    Line("yawn", A.Casual)
    Line("is it boring in here or is that just me", A.Casual)
    Line("anyone else bored?", A.Casual)
    Line("i'm bored", A.Casual)
    Line("haha i wanna watch tiktok", A.Dumb)
    Line("snooooze", A.Dumb)
    Line("zzzzzzzzz", A.Dumb)

    RegisterCategory("DialogNegativeResponse", P.NORMAL, "When a bot is responding negatively to a question.")
    Line("Nope")
    Line("Nah")
    Line("Not really")
    Line("Not much")
    Line("Not a whole lot")

    RegisterCategory("DialogPositiveResponse", P.NORMAL, "When a bot is responding positively to a question.")
    Line("Yeah")
    Line("Yep")
    Line("Sure")
    Line("Mhm")
    Line("Yup")
    Line("Yeah, I guess")
    Line("I suppose")
    Line("I guess")

    RegisterCategory("DialogRudeResponse", P.NORMAL, "When a bot is responding rudely to a question.")
    Line("No way.")
    Line("That's.. silly.")
    Line("Shut up.")
    Line("Stfu {{lastBot}}")
    Line("Hush")
    Line("Silence")
    Line("Shhhh")
    Line("Didn't ask")
    Line("Sorry, but nobody asked.")
    Line("I don't care.")
    Line("I don't care, {{lastBot}}")

    -----------------------------------------------------------
    -- SOCIAL DEDUCTION CORE — new events
    -----------------------------------------------------------

    RegisterCategory("WitnessCallout", P.CRITICAL, "When a bot witnesses {{attacker}} kill {{victim}}, with optional {{location}} and {{weapon}}.")
    Line("I just saw {{attacker}} shoot {{victim}}!", A.Default)
    Line("{{attacker}} killed {{victim}}! Everyone watch out!", A.Default)
    Line("Witnessed: {{attacker}} just killed {{victim}}.", A.Default)
    Line("{{attacker}} just took out {{victim}} near {{location}}.", A.Default)
    Line("KOS {{attacker}}! They just killed {{victim}}!", A.Default)
    Line("yo {{attacker}} just killed {{victim}} wtf", A.Casual)
    Line("bro {{attacker}} just clapped {{victim}}", A.Casual)
    Line("wait did you guys see that? {{attacker}} killed {{victim}}", A.Casual)
    Line("HOLY- {{attacker}} just killed {{victim}}!!!", A.Hothead)
    Line("ARE YOU SERIOUS {{attacker}} JUST KILLED {{victim}}!!!", A.Hothead)
    Line("KOS KOS KOS {{attacker}} JUST KILLED {{victim}}", A.Hothead)
    Line("{{attacker}} killed {{victim}}.", A.Stoic)
    Line("{{attacker}} eliminated {{victim}} near {{location}}.", A.Stoic)
    Line("I have observed {{attacker}} terminating {{victim}}.", A.Stoic)
    Line("wait... {{attacker}} just... did they kill {{victim}}??", A.Dumb)
    Line("OMG {{attacker}} killed {{victim}} i think?", A.Dumb)
    Line("uhh {{attacker}} just shot {{victim}} i saw it!", A.Dumb)
    Line("I'm sorry to report that {{attacker}} killed {{victim}}.", A.Nice)
    Line("{{attacker}} just killed {{victim}}, everyone please be careful.", A.Nice)
    Line("I saw {{attacker}} kill {{victim}} with {{weapon}}.", A.Tryhard)
    Line("Confirmed kill: {{attacker}} eliminated {{victim}} at {{location}} using {{weapon}}.", A.Tryhard)
    Line("Data logged: {{attacker}} killed {{victim}}.", A.Tryhard)
    Line("Maybe it was an accident? {{attacker}} shot {{victim}}...", A.Nice)
    Line("{{attacker}} is sus af they literally just killed {{victim}}", A.Sus)
    Line("kos {{attacker}} they killed {{victim}}", A.Sus)
    Line("Everyone saw that right? {{attacker}} got {{victim}}", A.Teamer)
    Line("Team, {{attacker}} just killed {{victim}}. Keep that in mind.", A.Teamer)

    RegisterCategory("DeathCallout", P.CRITICAL, "Bot's last words naming their killer {{player}}.")
    Line("It was {{player}}!", A.Default)
    Line("{{player}} killed me!", A.Default)
    Line("Watch out for {{player}}!", A.Default)
    Line("{{player}}... it was {{player}}...", A.Default)
    Line("it was {{player}}!!!", A.Casual)
    Line("{{player}} got me", A.Casual)
    Line("IT WAS {{player}}!!!", A.Hothead)
    Line("{{player}} YOU'RE DEAD!!!", A.Hothead)
    Line("{{player}}.", A.Stoic)
    Line("The killer was {{player}}.", A.Stoic)
    Line("I think... it was {{player}}? Maybe?", A.Dumb)
    Line("{{player}}... or was it someone else...", A.Dumb)
    Line("Please, someone stop {{player}}!", A.Nice)
    Line("Tell everyone, it was {{player}}!", A.Nice)
    Line("Confirmed: {{player}} is the attacker. Time of death noted.", A.Tryhard)
    Line("sus {{player}} they got me", A.Sus)
    Line("Everyone note: {{player}} killed me.", A.Teamer)

    RegisterCategory("LifeCheckRollCall", P.IMPORTANT, "Periodic call to check who is still alive.")
    Line("Who's still alive? Sound off.", A.Default)
    Line("Anyone still out there?", A.Default)
    Line("Status check — who's alive?", A.Default)
    Line("Roll call. Who's left?", A.Default)
    Line("yo who's still alive", A.Casual)
    Line("anyone alive out there?", A.Casual)
    Line("WHERE IS EVERYONE???", A.Hothead)
    Line("Anyone still breathing out there?!", A.Hothead)
    Line("Conducting a personnel check. Please respond.", A.Stoic)
    Line("Current alive status: requesting confirmation.", A.Stoic)
    Line("guys is anyone there", A.Dumb)
    Line("hello?? anyone??", A.Dumb)
    Line("Just checking in! Is everyone okay?", A.Nice)
    Line("Hey everyone, sound off if you're alive!", A.Nice)
    Line("Alive players, report in immediately.", A.Tryhard)
    Line("Team, I need a head count now.", A.Teamer)
    Line("anyone sus still alive? check in", A.Sus)

    RegisterCategory("AccuseKOS", P.CRITICAL, "Strong evidence KOS against {{player}}, optionally citing {{reason}}, {{location}}, {{victim}}.")
    Line("KOS {{player}}! I have proof!", A.Default)
    Line("KOS {{player}} — I saw them kill {{victim}}!", A.Default)
    Line("{{player}} is the traitor, KOS!", A.Default)
    Line("KOS {{player}}, they had a traitor weapon!", A.Default)
    Line("kos {{player}} no cap", A.Casual)
    Line("{{player}} is literally the traitor, kos them", A.Casual)
    Line("KOS {{player}} NOW!!!", A.Hothead)
    Line("KILL {{player}} THEY'RE THE TRAITOR!!!", A.Hothead)
    Line("Based on evidence, {{player}} should be KOS'd.", A.Stoic)
    Line("I am calling KOS on {{player}}. Evidence: {{reason}}.", A.Stoic)
    Line("umm i think kos {{player}}?? they're sus", A.Dumb)
    Line("KOS {{player}} i dunno they're doing something weird", A.Dumb)
    Line("I'm sorry but... KOS {{player}}. I have no choice.", A.Nice)
    Line("KOS {{player}} — {{reason}} at {{location}}. Weapon: {{reason}}.", A.Tryhard)
    Line("Confirmed traitor: {{player}}. KOS approved.", A.Tryhard)
    Line("Team, I'm calling KOS on {{player}}. Please act.", A.Teamer)
    Line("KOS {{player}}. They killed {{victim}}.", A.Teamer)
    Line("sus sus sus kos {{player}}", A.Sus)

    RegisterCategory("AccuseMedium", P.IMPORTANT, "Medium evidence declaration against {{player}}, with {{reason}}.")
    Line("{{player}} is very suspicious — {{reason}}.", A.Default)
    Line("Watch {{player}}, they've been acting weird near {{location}}.", A.Default)
    Line("I don't trust {{player}}. {{reason}}.", A.Default)
    Line("{{player}} is acting shady.", A.Casual)
    Line("ngl {{player}} is sus because {{reason}}", A.Casual)
    Line("{{player}} YOU'RE SUSPICIOUS AND I DON'T LIKE IT", A.Hothead)
    Line("{{player}} is highly suspicious. Note this.", A.Stoic)
    Line("Suspicion elevated on {{player}}. Reason: {{reason}}.", A.Stoic)
    Line("idk {{player}} is kinda sus?", A.Dumb)
    Line("{{player}} gives me bad vibes", A.Dumb)
    Line("I'm a bit worried about {{player}}, they seem off.", A.Nice)
    Line("{{player}} has accumulated significant suspicious behavior: {{reason}}.", A.Tryhard)
    Line("Group, we should keep an eye on {{player}}.", A.Teamer)
    Line("{{player}} is super sus imo", A.Sus)

    RegisterCategory("AccuseSoft", P.NORMAL, "Soft suspicion hint about {{player}}.")
    Line("{{player}} is acting a bit weird.", A.Default)
    Line("Something's off about {{player}}.", A.Default)
    Line("I'm not sure about {{player}}...", A.Default)
    Line("{{player}} seems kinda off ngl", A.Casual)
    Line("{{player}} is being weird lol", A.Casual)
    Line("ugh {{player}} is annoying me", A.Hothead)
    Line("{{player}} seems slightly unusual.", A.Stoic)
    Line("Low-level alert on {{player}}.", A.Stoic)
    Line("{{player}} is maybe sus idk", A.Dumb)
    Line("{{player}} is... doing something?", A.Dumb)
    Line("{{player}} might be worth watching, just saying.", A.Nice)
    Line("Noting minor suspicious behavior from {{player}}.", A.Tryhard)
    Line("Keep an eye on {{player}}, team.", A.Teamer)
    Line("{{player}} is kinda giving traitor vibes", A.Sus)

    RegisterCategory("AccuseRetract", P.IMPORTANT, "Retracting a previous accusation against {{player}}.")
    Line("Actually, {{player}} is clean. My bad.", A.Default)
    Line("Scratch that — {{player}} checked out. Sorry.", A.Default)
    Line("I was wrong about {{player}}, they're innocent.", A.Default)
    Line("my bad {{player}} lmao", A.Casual)
    Line("nvm {{player}} is actually clean", A.Casual)
    Line("FINE {{player}} IS CLEAN I GUESS", A.Hothead)
    Line("Retracting suspicion on {{player}}. Evidence inconclusive.", A.Stoic)
    Line("oh wait {{player}} is ok i think?", A.Dumb)
    Line("I'm so sorry {{player}}, you're clearly innocent!", A.Nice)
    Line("Previous suspicion on {{player}} rescinded. Alibi confirmed.", A.Tryhard)
    Line("Team, stand down on {{player}}. They're clear.", A.Teamer)

    RegisterCategory("RequestRoleCheck", P.IMPORTANT, "Asking {{player}} to use the role checker.")
    Line("{{player}}, can you use the role checker?", A.Default)
    Line("{{player}}, prove you're innocent — use the tester.", A.Default)
    Line("Hey {{player}}, go use the role checker please.", A.Default)
    Line("{{player}} use the tester pls", A.Casual)
    Line("USE THE TESTER {{player}}!", A.Hothead)
    Line("{{player}}, please submit to a role check.", A.Stoic)
    Line("{{player}} u should use the tester idk", A.Dumb)
    Line("{{player}}, would you mind taking the role test? Just to be safe.", A.Nice)
    Line("{{player}}: role checker. Now. Please verify your identity.", A.Tryhard)
    Line("Team asks {{player}} to take the role checker.", A.Teamer)

    RegisterCategory("DefendOfferTest", P.CRITICAL, "Offering to use the role checker to prove innocence.")
    Line("I'll use the tester! I'm completely clean!", A.Default)
    Line("I have nothing to hide — let me use the role checker.", A.Default)
    Line("Check me! I'm innocent!", A.Default)
    Line("bro i'll use the tester rn i'm clean", A.Casual)
    Line("I AM INNOCENT AND I WILL PROVE IT", A.Hothead)
    Line("I am willing to submit to a role check.", A.Stoic)
    Line("i'll do the tester thing i'm clean i think", A.Dumb)
    Line("Please, I'll use the tester. I promise I'm innocent!", A.Nice)
    Line("I will submit to a role verification immediately.", A.Tryhard)
    Line("Team, I am requesting a role check to prove my innocence.", A.Teamer)

    RegisterCategory("DefendAlibi", P.CRITICAL, "Providing alibi — was with {{player}} the whole time.")
    Line("I was with {{player}} the whole time! Ask them!", A.Default)
    Line("{{player}} can vouch for me — I never left their side.", A.Default)
    Line("Ask {{player}}, they know I'm clean.", A.Default)
    Line("literally ask {{player}} i was with them", A.Casual)
    Line("I HAVE AN ALIBI — {{player}} WAS WITH ME!", A.Hothead)
    Line("I was in the company of {{player}}. They can confirm.", A.Stoic)
    Line("um {{player}} was with me?? i think?", A.Dumb)
    Line("{{player}} has been with me the whole time, please ask them!", A.Nice)
    Line("Alibi confirmed by {{player}}. Duration: sufficient.", A.Tryhard)
    Line("Team — {{player}} can vouch for my location.", A.Teamer)

    RegisterCategory("DefendCounterAccuse", P.CRITICAL, "Innocent counter-accusing {{counter}} to deflect from {{player}}'s accusation.")
    Line("Wait, what about {{counter}}? They've been acting way more suspicious!", A.Default)
    Line("Actually {{counter}} is the one you should watch!", A.Default)
    Line("Don't trust {{player}} — look at {{counter}} instead!", A.Default)
    Line("bro why are you coming after me when {{counter}} is right there", A.Casual)
    Line("LOOK AT {{counter}} NOT ME!", A.Hothead)
    Line("Redirect attention to {{counter}}. Their behavior is more suspicious.", A.Stoic)
    Line("wait isn't {{counter}} more sus than me??", A.Dumb)
    Line("I really think {{counter}} is the one to watch, not me.", A.Nice)
    Line("Counter-evidence: {{counter}} has more suspicious indicators than myself.", A.Tryhard)
    Line("Team — {{counter}} should be the focus, not me.", A.Teamer)

    RegisterCategory("DefendAppealGroup", P.IMPORTANT, "Appealing to the group for support.")
    Line("Does anyone actually think I'm suspicious?", A.Default)
    Line("I've been helping everyone this whole round!", A.Default)
    Line("Come on guys, I've been doing nothing wrong.", A.Default)
    Line("guys pls i'm literally innocent", A.Casual)
    Line("DOES ANYONE BELIEVE ME?!", A.Hothead)
    Line("Requesting group consensus. Am I truly suspicious?", A.Stoic)
    Line("um can someone say i'm ok?? please??", A.Dumb)
    Line("Please, everyone — I promise I'm one of you!", A.Nice)
    Line("Statistical analysis suggests I am innocent. Do you concur?", A.Tryhard)
    Line("Team, I ask for your support here. I am innocent.", A.Teamer)

    RegisterCategory("DefendRage", P.IMPORTANT, "Hothead/angry reaction to being accused by {{player}}.")
    Line("Are you SERIOUS right now?! I'm innocent!", A.Default)
    Line("{{player}} is LYING about me!", A.Default)
    Line("HOW DARE YOU ACCUSE ME {{player}}!!!", A.Hothead)
    Line("{{player}} YOU'RE THE TRAITOR, NOT ME!!!", A.Hothead)
    Line("ugh {{player}} stfu i'm innocent", A.Casual)
    Line("This is absurd. I will not dignify this.", A.Stoic)
    Line("bro why is {{player}} coming after me??", A.Dumb)
    Line("I'm really upset about this accusation from {{player}}.", A.Nice)

    RegisterCategory("DefendFeign", P.IMPORTANT, "Traitor feigning innocence after being accused by {{player}}.")
    Line("What? I was nowhere near there!", A.Default)
    Line("Me? A traitor? That's ridiculous.", A.Default)
    Line("I don't know what {{player}} is talking about.", A.Default)
    Line("bro what?? i'm literally clean", A.Casual)
    Line("{{player}} is clearly confused.", A.Stoic)
    Line("um i didn't do anything??", A.Dumb)
    Line("Oh no, I would never! I'm innocent!", A.Nice)
    Line("{{player}}'s accusation is baseless. I am innocent.", A.Tryhard)

    RegisterCategory("DefendFrameOther", P.IMPORTANT, "Traitor framing {{player}} to deflect suspicion.")
    Line("Actually, {{player}} is the one you should worry about!", A.Default)
    Line("I've been watching {{player}} — they're way more sus than me.", A.Default)
    Line("Don't look at me, look at {{player}}!", A.Default)
    Line("bro have you seen {{player}} acting sus??", A.Casual)
    Line("EVERYONE LOOK AT {{player}} NOT ME", A.Hothead)
    Line("I suggest redirecting suspicion toward {{player}}.", A.Stoic)
    Line("wait isn't {{player}} being weird?", A.Dumb)
    Line("I don't want to cause trouble, but {{player}} really has been strange.", A.Nice)

    RegisterCategory("DefendAssassinate", P.CRITICAL, "Traitor (team-only) announcing they will silence a witness.")
    Line("I need to take care of them.", A.Default)
    Line("They know too much.", A.Default)
    Line("Eliminating the witness.", A.Stoic)
    Line("Taking out the problem.", A.Default)

    RegisterCategory("DefendTraitorPanic", P.IMPORTANT, "Dumb traitor panicking after being accused by {{player}}.")
    Line("What? No! I mean yes! Wait, no!", A.Dumb)
    Line("I didn't — I mean I was just — I wasn't there!", A.Dumb)
    Line("Oh no oh no oh no", A.Dumb)
    Line("It wasn't me! ...or was it?", A.Dumb)
    Line("uh oh", A.Dumb)
    Line("i panicked ok don't look at me", A.Casual)

    RegisterCategory("BreakTrust", P.IMPORTANT, "Bot retracting trust after {{player}} acted suspiciously.")
    Line("Wait, {{player}} just... I take it back!", A.Default)
    Line("{{player}} betrayed my trust. They're sus now.", A.Default)
    Line("I vouched for {{player}} but now... no. KOS.", A.Default)
    Line("wow {{player}} really just did that huh", A.Casual)
    Line("{{player}} BETRAYED ME I VOUCHED FOR THEM", A.Hothead)
    Line("Revoking trust status on {{player}}. Evidence updated.", A.Stoic)
    Line("wait {{player}} is bad?? i thought they were good??", A.Dumb)
    Line("Oh no... I really thought {{player}} was innocent. I was wrong.", A.Nice)
    Line("Trust parameters for {{player}} reset to hostile.", A.Tryhard)
    Line("Team: {{player}} has proven untrustworthy. Disregard my vouch.", A.Teamer)

    RegisterCategory("VouchChat", P.IMPORTANT, "Vouching for {{player}}'s innocence.")
    Line("{{player}} is with me — they're clean!", A.Default)
    Line("I can vouch for {{player}}, we've been together.", A.Default)
    Line("{{player}} is innocent, I've been watching them.", A.Default)
    Line("{{player}} is good i was literally just with them", A.Casual)
    Line("{{player}} IS CLEAN LEAVE THEM ALONE", A.Hothead)
    Line("I can confirm {{player}}'s innocence.", A.Stoic)
    Line("{{player}} seems nice?? i vouch for them", A.Dumb)
    Line("{{player}} is good people! I vouch for them completely.", A.Nice)
    Line("Confirmed: {{player}} is innocent. Travel companion since round start.", A.Tryhard)
    Line("Team, I vouch for {{player}}. We've been together.", A.Teamer)

    RegisterCategory("BodyEvidenceFound", P.CRITICAL, "Bot found evidence that {{killer}} killed {{victim}} on the corpse.")
    Line("The body says {{killer}} killed {{victim}}!", A.Default)
    Line("Found evidence: {{killer}} was the killer of {{victim}}.", A.Default)
    Line("Body ID complete — {{killer}} is responsible for {{victim}}'s death.", A.Default)
    Line("omg the body says {{killer}} did it??", A.Casual)
    Line("{{killer}} KILLED {{victim}} THE BODY SAYS SO!", A.Hothead)
    Line("Evidence from corpse: {{killer}} killed {{victim}}.", A.Stoic)
    Line("the dead person says {{killer}} killed them?", A.Dumb)
    Line("I found something terrible — {{killer}} killed {{victim}}.", A.Nice)
    Line("Forensic data confirms: {{killer}} eliminated {{victim}}.", A.Tryhard)
    Line("Team: body evidence confirms {{killer}} killed {{victim}}.", A.Teamer)

    RegisterCategory("ScanningBody", P.IMPORTANT, "When a detective bot is about to use the DNA scanner on a corpse.")
    Line("I'm going to scan this body.", A.Default)
    Line("Using my DNA scanner on this corpse.", A.Default)
    Line("Let me run a scan on this body.", A.Default)
    Line("scanning this body rq", A.Casual)
    Line("dna scan time", A.Casual)
    Line("lemme check this corpse real quick", A.Casual)
    Line("I'll scan this, could be useful.", A.Bad)
    Line("uh what does this button do", A.Dumb)
    Line("is this how you use the scanner?", A.Dumb)
    Line("DNA SCAN. NOW.", A.Hothead)
    Line("I'm scanning this corpse, cover me!", A.Hothead)
    Line("I'll scan this for evidence!", A.Nice)
    Line("Scanning the body for clues!", A.Nice)
    Line("Initiating DNA scan.", A.Stoic)
    Line("Running forensic analysis.", A.Stoic)
    Line("Scanning for the team.", A.Teamer)
    Line("Evidence acquisition in progress.", A.Tryhard)
    Line("Running the scan — stay sharp.", A.Tryhard)
    Line("Scanning this... let's see what it reveals.", A.Sus)

    RegisterCategory("DNAMatch", P.CRITICAL, "DNA scanner matched {{suspect}} to victim {{victim}}.")
    Line("DNA match — {{suspect}} killed {{victim}}!", A.Default)
    Line("Scanner says {{suspect}} is linked to {{victim}}'s death.", A.Default)
    Line("Got a DNA hit: {{suspect}} killed {{victim}}.", A.Default)
    Line("omg the scanner says {{suspect}} did it!!", A.Casual)
    Line("dna match on {{suspect}} for {{victim}}, kos", A.Casual)
    Line("yo {{suspect}} is linked to {{victim}} by the scanner", A.Casual)
    Line("scanner says {{suspect}} probably killed {{victim}}", A.Bad)
    Line("guess {{suspect}} did it, scanner says so", A.Bad)
    Line("uh the flashy thing says {{suspect}} killed {{victim}}", A.Dumb)
    Line("the beepy scanner thingy says {{suspect}} did it", A.Dumb)
    Line("DNA MATCH. {{suspect}} KILLED {{victim}}. KOS NOW.", A.Hothead)
    Line("{{suspect}}, your DNA was on {{victim}}. You're dead!", A.Hothead)
    Line("The scanner found {{suspect}}'s DNA on {{victim}}. Be careful!", A.Nice)
    Line("I'm sorry {{suspect}}, but the DNA links you to {{victim}}.", A.Nice)
    Line("DNA analysis complete. {{suspect}} linked to {{victim}}.", A.Stoic)
    Line("Forensic match confirmed: {{suspect}} — {{victim}}.", A.Stoic)
    Line("Scanner hit: {{suspect}} killed {{victim}}, team. KOS.", A.Teamer)
    Line("DNA evidence acquired. {{suspect}} eliminated {{victim}}. KOS.", A.Tryhard)
    Line("Confirmed hit — {{suspect}} is our target.", A.Tryhard)
    Line("Interesting... the scanner points to {{suspect}} for {{victim}}.", A.Sus)

    -----------------------------------------------------------
    -- ROUND PHASE AWARENESS
    -----------------------------------------------------------

    RegisterCategory("PhaseGroupUp", P.IMPORTANT, "Bot urges teammates to group up in late round")
    Line("We're running out of time — everyone group up!", A.Default)
    Line("Late round, stick together people.", A.Default)
    Line("Get to me, NOW. Don't wander alone.", A.Default)
    Line("Group up before it's too late.", A.Default)
    Line("STICK TOGETHER. Late round.", A.Default)

    Line("yo group up its late game", A.Casual)
    Line("yall need to stick together rn", A.Casual)
    Line("come on come on, group time", A.Casual)

    Line("I said GROUP UP.", A.Hothead)
    Line("IF YOU DON'T GROUP UP I SWEAR—", A.Hothead)
    Line("Stop wandering around like idiots. GROUP UP.", A.Hothead)

    Line("Everyone to me. Now.", A.Stoic)
    Line("Consolidate positions immediately.", A.Stoic)
    Line("Tactical grouping required.", A.Stoic)

    Line("maybe we should like... go together?", A.Dumb)
    Line("guys should we group? i think we should group", A.Dumb)

    Line("Buddy up everyone! Safety in numbers!", A.Nice)
    Line("Please stick with someone — it's getting dangerous!", A.Nice)

    RegisterCategory("PhaseOvertimePanic", P.CRITICAL, "Bot demands everyone get tested in overtime")
    Line("TEST EVERYONE. Right now. No exceptions.", A.Default)
    Line("Time is up — get on the tester or you're KOS.", A.Default)
    Line("Everyone line up for testing. NOW.", A.Default)
    Line("If you haven't been tested, you're sus. Do it now.", A.Default)

    Line("test NOW or i kos everyone lol", A.Casual)
    Line("bro get tested literally right now", A.Casual)

    Line("EVERYONE GETS TESTED OR EVERYONE DIES.", A.Hothead)
    Line("Test. Now. Or I start shooting.", A.Hothead)

    Line("Mandatory testing. Refusal equals KOS.", A.Stoic)
    Line("Role verification required. Immediately.", A.Stoic)

    Line("TEEEEST TIMEEEE", A.Dumb)
    Line("i dunno whats happening but test i guess??", A.Dumb)

    Line("Everyone please get tested, we're almost out of time!", A.Nice)
    Line("Testing time! It'll only take a second, I promise!", A.Nice)

    RegisterCategory("PhaseTraitorNow", P.IMPORTANT, "Traitor bot rallies team for late-round strike (team chat)")
    Line("Now's our chance — move in.", A.Default)
    Line("Time to make our move. Let's go.", A.Default)
    Line("They're scattered. Hit them now.", A.Default)
    Line("Stop waiting. We strike now.", A.Default)

    Line("ok gang time to go crazy", A.Casual)
    Line("lets gooo its time", A.Casual)

    Line("MOVE. NOW. KILL THEM ALL.", A.Hothead)
    Line("I'm tired of waiting. Attacking.", A.Hothead)

    Line("Execute. Now.", A.Stoic)
    Line("Initiating final phase.", A.Stoic)

    Line("uh guys can we go kill them now pleeease", A.Dumb)

    RegisterCategory("PhaseOvertimeAssault", P.CRITICAL, "Traitor bot calls all-out assault in overtime (team chat)")
    Line("All out — no more hiding. Attack everything.", A.Default)
    Line("Forget stealth. Full assault.", A.Default)
    Line("No more games. Kill them all, now.", A.Default)
    Line("Overtime. Gloves are off.", A.Default)

    Line("YOLO IT LETS GOOOO", A.Casual)
    Line("forget the plan just go ham", A.Casual)

    Line("ATTACK. ALL OF YOU. NOW.", A.Hothead)
    Line("THEY DIE NOW.", A.Hothead)

    Line("Stealth protocol terminated. Full assault.", A.Stoic)
    Line("All-out attack. No restraint.", A.Stoic)

    Line("can we just like, shoot everyone??", A.Dumb)

    RegisterCategory("DeductionMustBeTraitor", P.IMPORTANT, "Bot uses process of elimination to call out a player")
    Line("Process of elimination — it's gotta be {player}.", A.Default)
    Line("{player} is the only one unaccounted for. KOS.", A.Default)
    Line("Everyone else is cleared. {player} is the traitor.", A.Default)
    Line("By elimination, {player} must be the traitor.", A.Default)

    Line("{player} its you by process of elimination lol", A.Casual)
    Line("bro its literally {player}, nobody else", A.Casual)

    Line("{player}. Process of elimination. You're dead.", A.Hothead)
    Line("It can ONLY be {player}. KOS.", A.Hothead)

    Line("Logic dictates: {player}.", A.Stoic)
    Line("By elimination: {player} is the traitor.", A.Stoic)

    Line("uhhhh i think it might be {player}? maybe?", A.Dumb)
    Line("i counted everyone and its {player} i think", A.Dumb)

    Line("I hate to say it, but the math says {player}...", A.Nice)
    Line("By process of elimination it's {player}. Sorry!", A.Nice)

    RegisterCategory("TooQuiet", P.NORMAL, "Bot notices nobody has died in a while and gets suspicious")
    Line("Nobody's died in a while... something's wrong.", A.Default)
    Line("It's been too quiet. Stay sharp.", A.Default)
    Line("Why hasn't anyone died? Something's off.", A.Default)
    Line("Too quiet. I don't like it.", A.Default)

    Line("guys its sus that nobodys died", A.Casual)
    Line("why is everyone alive still lol", A.Casual)

    Line("SOMETHING IS WRONG. Stay alert.", A.Hothead)
    Line("Why is everyone alive?! The traitors are planning something.", A.Hothead)

    Line("Anomalous silence. Maintain vigilance.", A.Stoic)
    Line("No casualties recorded. Suspicious.", A.Stoic)

    Line("wait nobody died?? is that good or bad", A.Dumb)
    Line("heyyy everyone's alive! ...wait is that bad", A.Dumb)

    Line("It's been so peaceful! ...too peaceful.", A.Nice)
    Line("Everyone's okay so far! Stay careful though!", A.Nice)

    RegisterCategory("OvertakeWarning", P.IMPORTANT, "Innocent bot warns that traitors may outnumber them")
    Line("They might outnumber us. Be careful.", A.Default)
    Line("Watch out — we may be in the minority now.", A.Default)
    Line("There's more of them than us. Stick together.", A.Default)
    Line("Numbers aren't in our favor. Group up.", A.Default)

    Line("yo we might be outnumbered rn", A.Casual)
    Line("guys there might be more bad guys than us", A.Casual)

    Line("WE'RE OUTNUMBERED. EVERYONE TOGETHER.", A.Hothead)
    Line("They outnumber us! Don't get separated!", A.Hothead)

    Line("Numerical disadvantage detected. Regroup.", A.Stoic)
    Line("We are potentially outnumbered. Consolidate.", A.Stoic)

    Line("uh oh i think there are more bad guys than us", A.Dumb)

    Line("We might be outnumbered! Please don't split up!", A.Nice)

    RegisterCategory("OvertakeReady", P.IMPORTANT, "Traitor bot rallies team when they have numbers advantage (team chat)")
    Line("We outnumber them. Move in.", A.Default)
    Line("Numbers are on our side. Let's end this.", A.Default)
    Line("We have the advantage. Attack.", A.Default)

    Line("we outnumber them letsss gooo", A.Casual)

    Line("WE HAVE NUMBERS. CHARGE.", A.Hothead)
    Line("More of us than them. ATTACK.", A.Hothead)

    Line("Numerical advantage confirmed. Engage.", A.Stoic)
    Line("We outnumber them. Execute.", A.Stoic)

    RegisterCategory("DangerZoneWarning", P.NORMAL, "Bot warns about a dangerous area where someone just died")
    Line("Stay away from that area — someone just died there.", A.Default)
    Line("Danger zone ahead. Someone was just killed there.", A.Default)
    Line("Don't go that way, there was a kill nearby.", A.Default)

    Line("yo dont go over there someone died", A.Casual)
    Line("theres a kill zone over there watch out", A.Casual)

    Line("AVOID THAT AREA. DEATH ZONE.", A.Hothead)
    Line("Don't go there unless you want to die!", A.Hothead)

    Line("Casualty reported in that area. Avoid.", A.Stoic)
    Line("Known kill site ahead. Exercise caution.", A.Stoic)

    Line("someone died there i think?? dont go there", A.Dumb)

    Line("Careful! Someone died near there recently!", A.Nice)

    RegisterCategory("TraitorCountDeduction", P.IMPORTANT, "Bot deduces the number of traitors remaining")
    Line("Only {count} traitor left. Stay sharp.", A.Default)
    Line("{count} traitor remaining. Don't let your guard down.", A.Default)
    Line("We're almost there — {count} traitor left.", A.Default)

    Line("{count} traitor left!! almost got em", A.Casual)
    Line("just {count} more to go guys!!", A.Casual)

    Line("{count} traitor left. FIND THEM.", A.Hothead)
    Line("ONE traitor left. I WILL FIND YOU.", A.Hothead)

    Line("{count} hostile remaining.", A.Stoic)
    Line("Confirmed: {count} traitor unit remaining.", A.Stoic)

    Line("wait theres only {count} traitor left?? yay!", A.Dumb)
    Line("so like, {count} bad guy, right?", A.Dumb)

    Line("Just {count} traitor left! We can do this!", A.Nice)
    Line("Only {count} more! Stay together and we've got this!", A.Nice)

    -- ===========================================================================
    -- Tier 6 — Personality & Immersion: Emotional Reactions & Deception Chatter
    -- ===========================================================================

    -- -------------------------------------------------------------------------
    -- WitnessKill — Bot witnessed someone get murdered and panics
    -- -------------------------------------------------------------------------
    RegisterCategory("WitnessKill", P.CRITICAL, "Bot witnessed a kill happening in front of them")
    Line("OH GOD! {{killer}} just killed {{victim}}!", A.Default)
    Line("{{killer}} just murdered {{victim}}! Run!", A.Default)
    Line("I just watched {{killer}} shoot {{victim}}! HELP!", A.Default)

    Line("OH MY GOD {{killer}} JUST KILLED {{victim}} RUN RUN RUN", A.Hothead)
    Line("WHAT THE HELL {{killer}} JUST MURDERED {{victim}}", A.Hothead)

    Line("omg omg {{killer}} just killed {{victim}}!!", A.Casual)
    Line("yo {{killer}} just clapped {{victim}} wtf", A.Casual)
    Line("DUDE {{killer}} just shot {{victim}} im freaking out", A.Casual)

    Line("{{killer}} eliminated {{victim}}. Taking cover.", A.Stoic)
    Line("{{victim}} is down. {{killer}} is hostile. Evading.", A.Stoic)

    Line("wait did {{killer}} just... oh no {{victim}} is dead", A.Dumb)
    Line("{{killer}} just did a murder!! on {{victim}}!!", A.Dumb)

    Line("Oh no! {{killer}} just killed {{victim}}! Someone help!", A.Nice)
    Line("I can't believe it — {{killer}} just shot {{victim}}!", A.Nice)

    Line("{{killer}} just took out {{victim}}. I saw everything.", A.Tryhard)
    Line("Confirmed kill: {{killer}} on {{victim}}. Everyone note this.", A.Tryhard)

    Line("{{victim}} gone... by {{killer}}'s hand... just like that.", A.Sus)

    -- -------------------------------------------------------------------------
    -- BeingShotAt — Bot is being shot at, before combat system activates
    -- -------------------------------------------------------------------------
    RegisterCategory("BeingShotAt", P.IMPORTANT, "Bot is being shot at by {{player}} and reacts before fighting back")
    Line("{{player}}, stop shooting at me!", A.Default)
    Line("Hey! {{player}} is shooting at me?!", A.Default)
    Line("I'm getting shot by {{player}}! Back off!", A.Default)

    Line("{{player}} WHY ARE YOU SHOOTING AT ME", A.Hothead)
    Line("STOP IT {{player}}! I WILL END YOU!", A.Hothead)
    Line("{{player}} YOU'RE DEAD IF YOU DON'T STOP!", A.Hothead)

    Line("ayo {{player}} why are you shooting me lmao", A.Casual)
    Line("yo stop shooting at me {{player}} wtf", A.Casual)
    Line("{{player}} chill out bro i'm friendly", A.Casual)

    Line("Hostile fire from {{player}}. Identifying intent.", A.Stoic)
    Line("Taking fire from {{player}}. Assessing threat.", A.Stoic)

    Line("ow!! {{player}} stop that!!", A.Dumb)
    Line("{{player}} hey that hurts!! cut it out!!", A.Dumb)

    Line("Please stop shooting, {{player}}! I'm innocent!", A.Nice)
    Line("Hey {{player}}, easy! I haven't done anything!", A.Nice)
    Line("Why are you shooting me, {{player}}? I'm on your side!", A.Nice)

    Line("{{player}}, you're shooting at the wrong person.", A.Tryhard)
    Line("Wasting ammo on me, {{player}}? Bold move.", A.Tryhard)
    Line("Friendly fire from {{player}}. Recommending ceasefire.", A.Tryhard)

    Line("{{player}} is suspicious... and now they're shooting me.", A.Sus)
    Line("Of course it's {{player}} shooting me.", A.Sus)
    Line("{{player}} firing at me. Noted.", A.Sus)

    Line("{{player}} is shooting me! Someone help!", A.Teamer)
    Line("Team, {{player}} is firing at me!", A.Teamer)
    Line("Help! {{player}} is attacking me!", A.Teamer)

    Line("Whatever, {{player}} can keep shooting. I don't care.", A.Bad)
    Line("{{player}} shooting me. Great.", A.Bad)

    -- -------------------------------------------------------------------------
    -- WitnessAllyShot — Bot sees a trusted innocent being shot at
    -- -------------------------------------------------------------------------
    RegisterCategory("WitnessAllyShot", P.CRITICAL, "Bot witnesses {{attacker}} shooting at trusted ally {{victim}}")
    Line("{{attacker}} is shooting {{victim}}! Stop!", A.Default)
    Line("Hey! {{attacker}} just shot {{victim}}!", A.Default)
    Line("Leave {{victim}} alone, {{attacker}}!", A.Default)

    Line("{{attacker}} STOP SHOOTING {{victim}}!", A.Hothead)
    Line("BACK OFF {{victim}}, {{attacker}}! I SAW THAT!", A.Hothead)
    Line("{{attacker}} IS SHOOTING {{victim}}! KOS!", A.Hothead)

    Line("yo {{attacker}} why are you shooting {{victim}} wtf", A.Casual)
    Line("bro {{attacker}} just shot {{victim}}", A.Casual)
    Line("{{attacker}} shooting {{victim}}, sus af", A.Casual)

    Line("{{attacker}} is attacking {{victim}}. Flagging as hostile.", A.Stoic)
    Line("Observed: {{attacker}} firing on {{victim}}. Suspicious.", A.Stoic)

    Line("{{attacker}} is hurting {{victim}}!! that's not nice!!", A.Dumb)
    Line("hey {{attacker}} stop shooting {{victim}}!!", A.Dumb)

    Line("Please stop, {{attacker}}! {{victim}} is innocent!", A.Nice)
    Line("{{attacker}}, why are you shooting {{victim}}? Back off!", A.Nice)

    Line("{{attacker}} firing on {{victim}}. This is not optimal. KOS.", A.Tryhard)
    Line("Flagging {{attacker}}: unprovoked fire on ally {{victim}}.", A.Tryhard)

    Line("I saw that, {{attacker}}... shooting {{victim}} of all people.", A.Sus)
    Line("{{attacker}} going after {{victim}}. Very interesting.", A.Sus)

    Line("Team, {{attacker}} is shooting our ally {{victim}}!", A.Teamer)
    Line("Everyone, {{attacker}} attacked {{victim}}! KOS!", A.Teamer)

    Line("{{attacker}} shooting {{victim}}, whatever.", A.Bad)
    Line("Great, {{attacker}} is hurting {{victim}}. Do something.", A.Bad)

    -- -------------------------------------------------------------------------
    -- FindFriendBody — Bot finds the body of a player they trusted
    -- -------------------------------------------------------------------------
    RegisterCategory("FindFriendBody", P.IMPORTANT, "Bot finds the body of a player they trusted/vouched for")
    Line("No... {{victim}} is dead. Who did this?", A.Default)
    Line("{{victim}}... They killed {{victim}}. This ends now.", A.Default)
    Line("I can't believe it — {{victim}} is gone.", A.Default)

    Line("{{victim}}!! NO!! WHOEVER DID THIS IS DEAD", A.Hothead)
    Line("THEY KILLED {{victim}}!! I'M GOING TO FIND YOU", A.Hothead)

    Line("rip {{victim}} :( who did that", A.Casual)
    Line("noooo not {{victim}}... :(", A.Casual)

    Line("{{victim}} is dead. Whoever did this will be found.", A.Stoic)
    Line("{{victim}} eliminated. Motive unclear. Proceeding.", A.Stoic)

    Line("oh no... {{victim}} went bye-bye... that's sad", A.Dumb)
    Line("{{victim}} is dead?? but we were friends!!", A.Dumb)

    Line("Oh, {{victim}}... I'm so sorry. We'll find who did this.", A.Nice)
    Line("{{victim}}... Rest in peace. I'll get justice for you.", A.Nice)

    Line("{{victim}} is gone. Cross-referencing suspects.", A.Tryhard)

    Line("{{victim}}... gone. just like that.", A.Sus)

    -- -------------------------------------------------------------------------
    -- RoundStart — Bot comments at the beginning of a round
    -- -------------------------------------------------------------------------
    RegisterCategory("RoundStart", P.NORMAL, "Bot says something at the start of the round")
    Line("Alright, let's figure this out.", A.Default)
    Line("New round. Stay sharp.", A.Default)
    Line("Here we go. Watch each other's backs.", A.Default)

    Line("HERE WE GO BOYS LET'S GET IT", A.Hothead)
    Line("ROUND START! TIME TO FIND THE TRAITORS!", A.Hothead)

    Line("alright let's goooo", A.Casual)
    Line("round starting, gl hf i guess", A.Casual)
    Line("let's figure this one out lol", A.Casual)

    Line("Round initiated. Proceeding.", A.Stoic)
    Line("Commencing round. Maintaining vigilance.", A.Stoic)

    Line("oooh it started!! what do i do", A.Dumb)
    Line("round! round!! yay new round!!", A.Dumb)

    Line("Good luck everyone! Let's work together!", A.Nice)
    Line("New round! I hope we all do well!", A.Nice)

    Line("Prioritizing targets. Beginning strategy.", A.Tryhard)
    Line("Round start. Optimal play begins now.", A.Tryhard)

    Line("new round... same game... same lies...", A.Sus)

    -- -------------------------------------------------------------------------
    -- OvertimeHaste — Bot panics as overtime/haste activates
    -- -------------------------------------------------------------------------
    RegisterCategory("OvertimeHaste", P.IMPORTANT, "Bot reacts to overtime/haste mode activating")
    Line("We're running out of time! Find the traitor!", A.Default)
    Line("Hurry up! We need to end this NOW!", A.Default)
    Line("Clock's ticking! Someone make a decision!", A.Default)

    Line("TIME IS RUNNING OUT! EVERYONE TEST NOW!", A.Hothead)
    Line("OVERTIME! STOP WASTING TIME AND FIGHT!", A.Hothead)

    Line("omg overtime already??? hurry up guys", A.Casual)
    Line("we're literally running out of time lmao panic panic", A.Casual)

    Line("Haste mode active. Escalating protocol.", A.Stoic)
    Line("Time constraint detected. Forcing resolution.", A.Stoic)

    Line("wait are we running out of time?? uh oh", A.Dumb)
    Line("the clock is going really fast!! what do we do!!", A.Dumb)

    Line("We're almost out of time! Please, let's work together!", A.Nice)
    Line("Overtime! We need to figure this out quickly!", A.Nice)

    Line("Time pressure. Adjusting aggression threshold.", A.Tryhard)
    Line("Overtime. Suboptimal. But winnable.", A.Tryhard)

    -- -------------------------------------------------------------------------
    -- LastInnocent — Bot realizes they are the last innocent alive
    -- -------------------------------------------------------------------------
    RegisterCategory("LastInnocent", P.CRITICAL, "Bot realizes they are the last innocent standing")
    Line("It's just me left. One of you is the traitor.", A.Default)
    Line("I'm the last innocent. {{suspect}} has to be it.", A.Default)
    Line("Everyone's dead. It has to be {{suspect}}.", A.Default)

    Line("I'M THE LAST ONE?! {{suspect}} YOU'RE DEAD MEAT!", A.Hothead)
    Line("IT'S JUST ME VS {{suspect}}. BRING IT ON.", A.Hothead)

    Line("oh no... i'm the last one... uh... {{suspect}} is sus", A.Casual)
    Line("wait i'm literally the last innocent lol ok {{suspect}} u r done", A.Casual)

    Line("I am the last innocent. {{suspect}} is the traitor. Engaging.", A.Stoic)
    Line("Final innocent standing. Target: {{suspect}}.", A.Stoic)

    Line("wait everyone is dead?? just me and {{suspect}}?? oh no", A.Dumb)
    Line("umm i'm the only one left... is {{suspect}} bad?", A.Dumb)

    Line("I'm the last innocent... {{suspect}}, please don't do this.", A.Nice)
    Line("Oh gosh, everyone's gone. {{suspect}}, I know it's you.", A.Nice)

    Line("Process of elimination complete. {{suspect}}. It was always you.", A.Tryhard)
    Line("Last innocent. Confirmed traitor: {{suspect}}. Engaging.", A.Tryhard)

    Line("...just me and {{suspect}}. felt this coming.", A.Sus)

    -- -------------------------------------------------------------------------
    -- TraitorVictory — Traitor gloats after winning (team-only)
    -- -------------------------------------------------------------------------
    RegisterCategory("TraitorVictory", P.NORMAL, "Traitor bot gloats after the traitors win (team chat)")
    Line("Too easy. You never suspected a thing.", A.Default)
    Line("Perfect round. They didn't stand a chance.", A.Default)
    Line("That's how you do it.", A.Default)

    Line("WE DOMINATED. THAT WAS INSANE.", A.Hothead)
    Line("LETS GOOO. TRAITORS WIN BABY.", A.Hothead)

    Line("lmaooo they had no idea", A.Casual)
    Line("gg ez we cooked them", A.Casual)
    Line("too easy ngl", A.Casual)

    Line("Objective complete. Satisfactory.", A.Stoic)
    Line("Round concluded. Traitor victory. As expected.", A.Stoic)

    Line("we won?? yay!! i helped!!", A.Dumb)
    Line("we did it!! i didn't even get caught!!", A.Dumb)

    Line("We did it! Great teamwork everyone!", A.Nice)
    Line("We won! Sorry innocents... you played well though!", A.Nice)

    Line("Efficient. Clean. Undetected.", A.Tryhard)
    Line("Optimal traitor play. GG.", A.Tryhard)

    Line("they never figured it out. we were ghosts.", A.Sus)

    -- -------------------------------------------------------------------------
    -- Deception chatter: AlibiBuilding, FakeInvestigate, FalseKOS, PlausibleIgnorance
    -- -------------------------------------------------------------------------
    RegisterCategory("AlibiBuilding", P.NORMAL, "Traitor makes small talk to be seen near innocents (alibi)")
    Line("Hey, staying close. Safety in numbers.", A.Default)
    Line("Sticking with the group. Smart move.", A.Default)
    Line("Good idea keeping together like this.", A.Default)

    Line("yo good idea staying as a group", A.Casual)
    Line("staying with you guys, safer that way", A.Casual)

    Line("Agreed. Group movement minimizes exposure.", A.Stoic)

    Line("yeah buddy system!!", A.Dumb)
    Line("i like being near people!! more fun!!", A.Dumb)

    Line("Glad we're sticking together. Better safe than sorry.", A.Nice)
    Line("There's strength in numbers. Good call staying together.", A.Nice)

    RegisterCategory("FakeInvestigateApproach", P.NORMAL, "Traitor announces they are going to check a body (deceptive)")
    Line("I'll go check that body.", A.Default)
    Line("Someone should look at that corpse. I'll do it.", A.Default)
    Line("Give me a second, I'm going to investigate.", A.Default)

    Line("lemme go check that body real quick", A.Casual)
    Line("i got this, gonna look at the body", A.Casual)

    Line("Investigating the corpse. Stand by.", A.Stoic)

    Line("oooh a body! i'll go look at it!", A.Dumb)

    Line("I'll check it out! Be right back.", A.Nice)

    RegisterCategory("FakeInvestigateReport", P.IMPORTANT, "Traitor reports fake findings after visiting a body they killed")
    Line("No DNA on {{player}}'s body. Whoever did this was careful.", A.Default)
    Line("Checked {{player}}. No leads on the killer. Be careful out there.", A.Default)
    Line("{{player}}'s body — no useful evidence. Someone covered their tracks.", A.Default)

    Line("{{player}} has no dna wtf... sneaky traitor", A.Casual)
    Line("checked {{player}}, nothing. whoever did it is good", A.Casual)

    Line("{{player}}: no forensic evidence. Perpetrator was thorough.", A.Stoic)
    Line("Body of {{player}} yields no usable evidence. Exercise caution.", A.Stoic)

    Line("i checked {{player}} and there was nothing!! spooky!!", A.Dumb)

    Line("Oh no, no DNA on {{player}}. Stay safe everyone!", A.Nice)

    RegisterCategory("FalseKOS", P.IMPORTANT, "Traitor calls a false KOS on an innocent")
    Line("KOS {{player}}! I saw them near a body with a traitor weapon.", A.Default)
    Line("KOS {{player}}! Acting super suspicious.", A.Default)
    Line("KOS {{player}} — I don't trust them at all.", A.Default)

    Line("KOS {{player}} RIGHT NOW i swear its them", A.Casual)
    Line("kos {{player}} trust me bro", A.Casual)

    Line("KOS {{player}}. Behavioral analysis confirms suspicion.", A.Stoic)
    Line("Declaring KOS on {{player}}. Evidence: suspicious pattern.", A.Stoic)

    Line("KOS {{player}}!! they look weird!!", A.Dumb)

    Line("I'm sorry, but KOS {{player}}. Something's off about them.", A.Nice)

    Line("KOS {{player}} — watched them for a while. It's them.", A.Tryhard)

    Line("KOS {{player}}. ...do with that what you will.", A.Sus)

    RegisterCategory("PlausibleIgnorance", P.IMPORTANT, "Traitor excuses their presence near a fresh kill")
    Line("I just got here! I heard gunshots and came to check.", A.Default)
    Line("Don't look at me — I literally just walked in.", A.Default)
    Line("I heard shots and came running. I don't know what happened.", A.Default)

    Line("yo i JUST got here i swear i heard something", A.Casual)
    Line("bro i literally just walked up wtf", A.Casual)

    Line("I arrived after the incident. I have no information.", A.Stoic)
    Line("I was in the adjacent area. Heard gunfire. Investigated.", A.Stoic)

    Line("i just got here!! i heard bang bang and ran over!!", A.Dumb)
    Line("what happened?? i just walked up here!!", A.Dumb)

    Line("I just arrived, I promise! I heard the shots and came to help.", A.Nice)
    Line("Oh gosh, I just got here! What happened?", A.Nice)

    Line("Convenient timing, I know. I assure you — coincidence.", A.Tryhard)
    Line("I was elsewhere. Came when I heard it.", A.Sus)

    -- -------------------------------------------------------------------------
    -- Dialog locale lines (used by sv_dialog.lua via "Dialog" prefix)
    -- -------------------------------------------------------------------------

    -- The Investigation
    RegisterCategory("DialogInvestigationAsk", P.NORMAL, "Dialog: Bot A asks about a victim")
    Line("Did anyone see {{bot}} before they died?", A.Default)
    Line("Does anyone know what happened to {{bot}}?", A.Default)
    Line("Who saw {{bot}} last?", A.Default)
    Line("did anyone see {{bot}} before they got killed?", A.Casual)

    RegisterCategory("DialogInvestigationWitness", P.NORMAL, "Dialog: Bot B claims to have seen the victim")
    Line("I think I saw them heading toward the far side of the map.", A.Default)
    Line("Last I saw {{bot}}, they were near {{lastBot}}.", A.Default)
    Line("They went off alone, which was weird.", A.Default)
    Line("yeah i saw them heading away from the group", A.Casual)

    RegisterCategory("DialogInvestigationSuspect", P.NORMAL, "Dialog: Bot C brings up a suspect")
    Line("{{nextBot}} was over there too, if I remember right.", A.Default)
    Line("Actually, I think {{nextBot}} was in that area.", A.Default)
    Line("Come to think of it... {{nextBot}} was around there.", A.Default)
    Line("wait wasn't {{nextBot}} over there too?", A.Casual)

    RegisterCategory("DialogInvestigationChallenge", P.NORMAL, "Dialog: Bot A challenges the suspect")
    Line("That's suspicious. {{nextBot}}, where were you?", A.Default)
    Line("Hmm. {{nextBot}}, can you explain that?", A.Default)
    Line("Interesting. {{nextBot}}, care to elaborate?", A.Default)
    Line("sooo {{nextBot}} wanna explain yourself lol", A.Casual)

    -- The Accusation
    RegisterCategory("DialogAccusationClaim", P.NORMAL, "Dialog: Bot A makes an accusation")
    Line("I'm calling it — {{nextBot}} is the traitor.", A.Default)
    Line("I've made up my mind. {{nextBot}} is sus.", A.Default)
    Line("Alright, I'll say it: {{nextBot}} is the traitor.", A.Default)
    Line("ok so i'm pretty sure {{nextBot}} is the traitor ngl", A.Casual)

    RegisterCategory("DialogAccusationChallenge", P.NORMAL, "Dialog: Bot B questions the accusation")
    Line("What's your evidence?", A.Default)
    Line("That's a bold claim. What makes you say that?", A.Default)
    Line("On what basis?", A.Default)
    Line("wait why tho?", A.Casual)

    RegisterCategory("DialogAccusationEvidence", P.NORMAL, "Dialog: Bot A presents their evidence")
    Line("I saw them near the last body with a suspicious weapon.", A.Default)
    Line("Their story doesn't add up. Too many inconsistencies.", A.Default)
    Line("They were never with the group when people died.", A.Default)
    Line("just vibes honestly but also they were acting mega sus", A.Casual)

    RegisterCategory("DialogAccusationVerdict", P.NORMAL, "Dialog: Bot B reacts to the evidence")
    Line("Alright, that's good enough for me. I'm with you.", A.Default)
    Line("Hmm. Possible, but I'm not fully convinced yet.", A.Default)
    Line("That's not much to go on. I was near there too.", A.Default)
    Line("fair enough i guess", A.Casual)
    Line("idk man that's kinda weak evidence", A.Casual)

    -- The Defense
    RegisterCategory("DialogDefenseProtest", P.NORMAL, "Dialog: Accused bot defends themselves")
    Line("I'm not the traitor! I was with {{nextBot}} the whole time!", A.Default)
    Line("This is ridiculous. I've done nothing wrong.", A.Default)
    Line("Are you serious right now? I'm on your side!", A.Default)
    Line("bro i SWEAR i'm not the traitor what the heck", A.Casual)

    RegisterCategory("DialogDefenseConfront", P.NORMAL, "Dialog: Accuser challenges the defense")
    Line("Then how do you explain your behavior?", A.Default)
    Line("Your alibi sounds convenient.", A.Default)
    Line("You were near the body. Explain that.", A.Default)
    Line("ok but like... you were def sus tho", A.Casual)

    RegisterCategory("DialogDefenseDeny", P.NORMAL, "Dialog: Accused doubles down")
    Line("I don't know what you want from me. Test me if you don't believe me.", A.Default)
    Line("I can't explain it, but it wasn't me. Check someone else.", A.Default)
    Line("Fine. I'll let my record speak for itself.", A.Default)
    Line("then TEST me dude oh my god", A.Casual)

    -- The Standoff
    RegisterCategory("DialogStandoffObserve", P.NORMAL, "Dialog: Bot A opens the standoff")
    Line("It's just the two of us. One of us is the traitor.", A.Default)
    Line("Here we are. Last two standing.", A.Default)
    Line("So. It comes down to this.", A.Default)
    Line("lol just us two. one of us is the traitor.", A.Casual)

    RegisterCategory("DialogStandoffDeny", P.NORMAL, "Dialog: Bot B denies being the traitor")
    Line("Well, it's not me. I can tell you that.", A.Default)
    Line("Not me. And I'm sure you'll say the same.", A.Default)
    Line("I've been innocent this whole time.", A.Default)
    Line("it's literally not me though lmao", A.Casual)

    RegisterCategory("DialogStandoffDrop", P.NORMAL, "Dialog: Bot A makes a demand")
    Line("Drop your weapon. Prove you're not hostile.", A.Default)
    Line("Then put the gun down.", A.Default)
    Line("If you're innocent, you won't need that.", A.Default)
    Line("ok then put the gun down", A.Casual)

    RegisterCategory("DialogStandoffCounter", P.NORMAL, "Dialog: Bot B counters the demand")
    Line("You first.", A.Default)
    Line("Why would I disarm when you're still armed?", A.Default)
    Line("That's exactly what a traitor would ask.", A.Default)
    Line("lmaooo you first", A.Casual)

    -- Post-Round Banter
    RegisterCategory("DialogPostRoundWinner", P.NORMAL, "Dialog: Winner of the round gloats (dead bots)")
    Line("GG. I knew {{nextBot}} was the traitor from the start.", A.Default)
    Line("Called it. Never had a doubt.", A.Default)
    Line("Saw that coming from a mile away.", A.Default)
    Line("GG i literally called it at the start lol", A.Casual)

    RegisterCategory("DialogPostRoundLoser", P.NORMAL, "Dialog: Loser reacts to the outcome")
    Line("How did you know?", A.Default)
    Line("Ugh. I should have listened.", A.Default)
    Line("I had no idea. When did you figure it out?", A.Default)
    Line("wait how did you know omg", A.Casual)

    RegisterCategory("DialogPostRoundExplain", P.NORMAL, "Dialog: Winner explains their deduction")
    Line("You were acting way too suspicious near the bodies.", A.Default)
    Line("The weapon was a giveaway. Nobody else had it.", A.Default)
    Line("You kept separating from the group at the worst times.", A.Default)
    Line("honestly you were just being super sus the whole time lol", A.Casual)

end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadCombatChats()
end
timer.Simple(1, loadModule_Deferred)
