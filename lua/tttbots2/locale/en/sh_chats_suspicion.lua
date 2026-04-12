--[[
    Suspicion System & Behavior-Driven Chatter Categories

    This file contains chat lines for suspicion-related observations,
    behavior-driven callouts, and awareness chatter. Categories included:
        SuspicionRising, SuspicionCleared, SuspicionConflict,
        TraitorWeaponSpotted, NearUnidentifiedBody,
        WitnessC4Defuse, WitnessC4Plant,
        SuspicionFollowing, SuspicionFollowingEscalate,
        SuspicionGrenadeThrow, SuspicionPersonalSpace,
        ParanoiaComment,
        GroupUpArrived, GroupUpSeeking,
        StalkingTarget, StalkingAbort,
        SeekingCover, CoverPeekAttack,
        WanderComment, LootingWeapon, GettingWeapon,
        BodyguardProtecting, DecrowdMoving, ClearingBreakables,
        InfectedRushing, GluttonBiting, DoomguyHunting,
        VultureFeeding, JanitorSweeping
]]

local P = {
    CRITICAL = 1,
    IMPORTANT = 2,
    NORMAL = 3,
}

local function LoadSuspicionChats()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end

    -- =======================================================================
    -- SUSPICION SYSTEM CHATTER
    -- =======================================================================

    -----------------------------------------------------------
    -- SUSPICION RISING
    -----------------------------------------------------------
    RegisterCategory("SuspicionRising", P.IMPORTANT, "When a bot notices growing suspicion on {{player}} before declaring them fully suspicious.")
    Line("Hmm, {{player}} is starting to look a bit off...", A.Default)
    Line("Something about {{player}} doesn't sit right with me.", A.Default)
    Line("I'm getting a weird vibe from {{player}}.", A.Default)
    Line("Keep an eye on {{player}}, something feels wrong.", A.Default)
    Line("Not sure yet, but {{player}} is raising some flags.", A.Default)
    Line("idk {{player}} is giving me weird vibes", A.Casual)
    Line("{{player}} is being kinda weird ngl", A.Casual)
    Line("something off about {{player}} but idk", A.Casual)
    Line("Somethings off about {{player}}...", A.Bad)
    Line("{{player}} better not be up to something", A.Bad)
    Line("is {{player}} doing something?", A.Dumb)
    Line("{{player}} looks funny", A.Dumb)
    Line("wait whats {{player}} doing", A.Dumb)
    Line("{{player}}, I'm watching you.", A.Hothead)
    Line("Don't try anything, {{player}}.", A.Hothead)
    Line("I swear {{player}} is up to something.", A.Hothead)
    Line("{{player}} is being a little suspicious, don't you think?", A.Nice)
    Line("Hey {{player}}, you okay? You seem nervous.", A.Nice)
    Line("Noted. {{player}} exhibiting irregular behavior.", A.Tryhard)
    Line("Flagging {{player}} for observation.", A.Tryhard)
    Line("{{player}} has some tells. Watching closely.", A.Tryhard)
    Line("...", A.Stoic)
    Line("Watching {{player}}.", A.Stoic)
    Line("yo keep an eye on {{player}} for me", A.Teamer)
    Line("{{player}} is acting weird, right? I'm not the only one?", A.Teamer)
    Line("{{player}} is looking real sus rn", A.Sus)
    Line("trust me bro {{player}} is doing something", A.Sus)

    -----------------------------------------------------------
    -- SUSPICION CLEARED
    -----------------------------------------------------------
    RegisterCategory("SuspicionCleared", P.NORMAL, "When a bot's suspicion on {{player}} has fully decayed to zero.")
    Line("Actually, {{player}} seems fine now.", A.Default)
    Line("I think I was wrong about {{player}}.", A.Default)
    Line("False alarm on {{player}}, they're clean.", A.Default)
    Line("nvm {{player}} is chill", A.Casual)
    Line("{{player}} is good actually mb", A.Casual)
    Line("whatever {{player}} is fine i guess", A.Bad)
    Line("ok {{player}} isnt doing anything", A.Dumb)
    Line("...fine, {{player}}'s alright.", A.Hothead)
    Line("Sorry {{player}}, I was being paranoid.", A.Nice)
    Line("Revoking suspicion flag on {{player}}.", A.Tryhard)
    Line("{{player}}. Clear.", A.Stoic)
    Line("{{player}} is good guys, false alarm", A.Teamer)
    Line("ok ok {{player}} is fine... for now", A.Sus)

    -----------------------------------------------------------
    -- SUSPICION CONFLICT
    -----------------------------------------------------------
    RegisterCategory("SuspicionConflict", P.IMPORTANT, "When a bot disagrees with another bot's KOS call on {{player}} because they trust the target.")
    Line("Wait, I don't think {{player}} is bad. I've been watching them.", A.Default)
    Line("Hold on, {{player}} has been clean as far as I can tell.", A.Default)
    Line("I disagree, {{player}} seems innocent to me.", A.Default)
    Line("nah {{player}} is fine, i was with them", A.Casual)
    Line("bro {{player}} didnt do anything", A.Casual)
    Line("You're wrong about {{player}}.", A.Bad)
    Line("Leave {{player}} alone!", A.Bad)
    Line("but {{player}} is nice tho", A.Dumb)
    Line("huh? {{player}} didnt do anything?", A.Dumb)
    Line("BACK OFF {{player}}, they didn't do anything!", A.Hothead)
    Line("You're wrong and I'll defend {{player}}!", A.Hothead)
    Line("Please don't attack {{player}}, I think they're innocent.", A.Nice)
    Line("Let's not be hasty about {{player}}, okay?", A.Nice)
    Line("Negative. {{player}} has clean evidence. Overruling.", A.Tryhard)
    Line("Data conflicts. {{player}} is low-threat per my assessment.", A.Tryhard)
    Line("No.", A.Stoic)
    Line("{{player}} is innocent.", A.Stoic)
    Line("guys {{player}} is with us, dont shoot", A.Teamer)
    Line("i mean... {{player}} COULD be good...", A.Sus)

    -----------------------------------------------------------
    -- TRAITOR WEAPON SPOTTED
    -----------------------------------------------------------
    RegisterCategory("TraitorWeaponSpotted", P.CRITICAL, "When a bot sees {{player}} holding a traitor weapon.")
    Line("{{player}} has a traitor weapon!", A.Default)
    Line("Why does {{player}} have that?! That's a T weapon!", A.Default)
    Line("{{player}} is holding a traitor weapon, watch out!", A.Default)
    Line("yo {{player}} has a T weapon", A.Casual)
    Line("uhhh {{player}} why do you have that", A.Casual)
    Line("WHAT {{player}} has a traitor weapon??", A.Bad)
    Line("{{player}} has a weird gun", A.Dumb)
    Line("is that a traitor thing {{player}} has?", A.Dumb)
    Line("{{player}} IS PACKING! TRAITOR WEAPON!", A.Hothead)
    Line("DROP THAT T WEAPON {{player}}!", A.Hothead)
    Line("Um, {{player}}, why do you have that weapon?", A.Nice)
    Line("T weapon confirmed on {{player}}. Engaging.", A.Tryhard)
    Line("{{player}}. Traitor weapon. Noted.", A.Stoic)
    Line("guys {{player}} has a traitor weapon watch out", A.Teamer)
    Line("CALLED IT {{player}} has a T weapon", A.Sus)

    -----------------------------------------------------------
    -- NEAR UNIDENTIFIED BODY
    -----------------------------------------------------------
    RegisterCategory("NearUnidentifiedBody", P.IMPORTANT, "When a bot sees {{player}} standing near an unidentified body without investigating.")
    Line("{{player}}, why are you just standing by that body?", A.Default)
    Line("{{player}} is loitering near an unidentified body...", A.Default)
    Line("Hey {{player}}, aren't you going to ID that body?", A.Default)
    Line("{{player}} standing next to a body and doing nothing lol", A.Casual)
    Line("uh {{player}} gonna id that or what", A.Casual)
    Line("{{player}} is just ignoring that body??", A.Bad)
    Line("{{player}} is by a body! that's sus!", A.Bad)
    Line("{{player}} is next to a dead guy", A.Dumb)
    Line("ID THE BODY {{player}}!", A.Hothead)
    Line("{{player}}, could you please check that body?", A.Nice)
    Line("{{player}} near unID'd corpse. Flagging for suspicion.", A.Tryhard)
    Line("{{player}}. Body. Unidentified.", A.Stoic)
    Line("yo {{player}} is by a body and not id'ing it", A.Teamer)
    Line("see? {{player}} is ignoring bodies. sus.", A.Sus)

    -----------------------------------------------------------
    -- WITNESS C4 DEFUSE
    -----------------------------------------------------------
    RegisterCategory("WitnessC4Defuse", P.IMPORTANT, "When a bot witnesses {{player}} defusing C4.")
    Line("{{player}} just defused the C4! Good job!", A.Default)
    Line("Nice, {{player}} got the bomb!", A.Default)
    Line("{{player}} defused it! We're safe!", A.Default)
    Line("{{player}} defused the c4 pog", A.Casual)
    Line("nice one {{player}}", A.Casual)
    Line("about time someone defused it", A.Bad)
    Line("yay {{player}} stopped the boom!", A.Dumb)
    Line("Finally! Good work, {{player}}!", A.Hothead)
    Line("Thank you {{player}}, that was close!", A.Nice)
    Line("C4 neutralized by {{player}}. Threat eliminated.", A.Tryhard)
    Line("Defused.", A.Stoic)
    Line("{{player}} got the c4! nice!", A.Teamer)
    Line("ok {{player}} defused it... but who planted it?", A.Sus)

    -----------------------------------------------------------
    -- WITNESS C4 PLANT
    -----------------------------------------------------------
    RegisterCategory("WitnessC4Plant", P.CRITICAL, "When a bot witnesses {{player}} planting C4.")
    Line("{{player}} JUST PLANTED C4!", A.Default)
    Line("BOMB! {{player}} is planting C4!", A.Default)
    Line("{{player}} planted a bomb! They're a traitor!", A.Default)
    Line("{{player}} just planted c4 wtf", A.Casual)
    Line("BRO {{player}} PLANTED A BOMB", A.Casual)
    Line("ARE YOU KIDDING ME {{player}} PLANTED C4??", A.Bad)
    Line("{{player}} put a bomb thing down!", A.Dumb)
    Line("{{player}} IS PLANTING! GET THEM!", A.Hothead)
    Line("Oh no, {{player}} planted C4!", A.Nice)
    Line("C4 deployed by {{player}}. Confirmed hostile.", A.Tryhard)
    Line("{{player}}. C4. Traitor.", A.Stoic)
    Line("{{player}} planted c4!! everyone get them!", A.Teamer)
    Line("I KNEW IT! {{player}} planted c4!", A.Sus)

    -----------------------------------------------------------
    -- SUSPICION FOLLOWING
    -----------------------------------------------------------
    RegisterCategory("SuspicionFollowing", P.NORMAL, "When a bot notices {{player}} has been following them.")
    Line("{{player}}, are you following me?", A.Default)
    Line("Why is {{player}} behind me...", A.Default)
    Line("Is {{player}} tailing me?", A.Default)
    Line("{{player}} why are you following me lol", A.Casual)
    Line("uhh {{player}} is following me", A.Casual)
    Line("Stop following me {{player}}", A.Bad)
    Line("{{player}} is right behind me help", A.Dumb)
    Line("{{player}}, BACK OFF!", A.Hothead)
    Line("Hey {{player}}, need something? You've been following me.", A.Nice)
    Line("{{player}} maintaining proximity. Monitoring.", A.Tryhard)
    Line("{{player}}. Following.", A.Stoic)
    Line("guys {{player}} keeps following me", A.Teamer)
    Line("{{player}} is following me and i dont like it", A.Sus)

    -----------------------------------------------------------
    -- SUSPICION FOLLOWING ESCALATE
    -----------------------------------------------------------
    RegisterCategory("SuspicionFollowingEscalate", P.IMPORTANT, "When {{player}} has been following the bot for too long and suspicion is growing.")
    Line("{{player}} won't stop following me. This isn't right.", A.Default)
    Line("Seriously {{player}}, stop following me! This is getting scary.", A.Default)
    Line("{{player}} has been on my tail for way too long.", A.Default)
    Line("{{player}} is STILL following me wtf", A.Casual)
    Line("ok {{player}} this is getting weird stop", A.Casual)
    Line("GET AWAY FROM ME {{player}}", A.Bad)
    Line("{{player}} wont leave me alone!!", A.Dumb)
    Line("{{player}} I WILL SHOOT YOU IF YOU DON'T STOP!", A.Hothead)
    Line("ONE MORE STEP {{player}}!", A.Hothead)
    Line("{{player}}, please, you're making me nervous...", A.Nice)
    Line("Persistent tail by {{player}}. Threat escalation.", A.Tryhard)
    Line("{{player}}. Still following. Prepare.", A.Stoic)
    Line("{{player}} is on me guys help", A.Teamer)
    Line("{{player}} is definitely about to do something", A.Sus)

    -----------------------------------------------------------
    -- SUSPICION GRENADE THROW
    -----------------------------------------------------------
    RegisterCategory("SuspicionGrenadeThrow", P.IMPORTANT, "When a bot sees {{player}} throw a suspicious grenade.")
    Line("{{player}} just threw a grenade!", A.Default)
    Line("Watch out! {{player}} is throwing grenades!", A.Default)
    Line("Why is {{player}} throwing grenades?!", A.Default)
    Line("{{player}} threw a nade wtf", A.Casual)
    Line("{{player}} is tossing nades lol", A.Casual)
    Line("{{player}} THREW A GRENADE AT US", A.Bad)
    Line("{{player}} threw a boom thing!", A.Dumb)
    Line("{{player}} IS THROWING GRENADES! KILL THEM!", A.Hothead)
    Line("{{player}}, why are you throwing that?!", A.Nice)
    Line("Grenade deployed by {{player}}. Hostile intent.", A.Tryhard)
    Line("{{player}}. Grenade.", A.Stoic)
    Line("{{player}} is throwing grenades watch out!", A.Teamer)
    Line("told you {{player}} was sus, now they're throwing nades", A.Sus)

    -----------------------------------------------------------
    -- SUSPICION PERSONAL SPACE
    -----------------------------------------------------------
    RegisterCategory("SuspicionPersonalSpace", P.NORMAL, "When someone is uncomfortably close to the bot.")
    Line("You're a bit close, don't you think?", A.Default)
    Line("Personal space, please.", A.Default)
    Line("Could you back up a little?", A.Default)
    Line("bro youre so close to me", A.Casual)
    Line("dude personal space", A.Casual)
    Line("MOVE!", A.Bad)
    Line("Get out of my face!", A.Bad)
    Line("why are you so close", A.Dumb)
    Line("youre touching me", A.Dumb)
    Line("BACK UP NOW!", A.Hothead)
    Line("GET OFF ME!", A.Hothead)
    Line("Hey, you mind giving me a little room?", A.Nice)
    Line("Proximity alert. Step back.", A.Tryhard)
    Line("Too close.", A.Stoic)
    Line("guys someone is all up in my space", A.Teamer)
    Line("this person is way too close, def about to stab me", A.Sus)

    -----------------------------------------------------------
    -- PARANOIA COMMENT
    -----------------------------------------------------------
    RegisterCategory("ParanoiaComment", P.NORMAL, "When a paranoid bot mutters something suspicious about the situation.")
    Line("I feel like someone's watching me...", A.Default)
    Line("Something doesn't feel right about all this...", A.Default)
    Line("I swear I keep hearing footsteps behind me.", A.Default)
    Line("Does anyone else feel like we're being watched?", A.Default)
    Line("Is it just me or is it too quiet?", A.Default)
    Line("im getting paranoid someone is watching me", A.Casual)
    Line("is it just me or is everyone sus", A.Casual)
    Line("Nobody move. I don't trust anyone.", A.Bad)
    Line("I don't trust a single one of you.", A.Bad)
    Line("whats that noise??", A.Dumb)
    Line("i think someones following me", A.Dumb)
    Line("who made that noise? SHOW YOURSELF!", A.Hothead)
    Line("I swear if someone is lurking...", A.Hothead)
    Line("Stay alert everyone, I have a bad feeling.", A.Nice)
    Line("Scanning perimeter. Threat level: uncertain.", A.Tryhard)
    Line("Statistical anomaly detected. Elevated caution.", A.Tryhard)
    Line("...", A.Stoic)
    Line("Watchful.", A.Stoic)
    Line("guys stay close i dont like this", A.Teamer)
    Line("everyone here is sus and i trust no one", A.Sus)
    Line("i just KNOW someone is about to do something", A.Sus)

    -- =======================================================================
    -- BEHAVIOR-DRIVEN CHATTER
    -- =======================================================================

    -----------------------------------------------------------
    -- GROUP UP
    -----------------------------------------------------------
    RegisterCategory("GroupUpSeeking", P.NORMAL, "When a bot is heading toward an ally to group up.")
    Line("Heading over to {{player}}.", A.Default)
    Line("Let me join up with {{player}}.", A.Default)
    Line("Coming to {{player}}, wait up.", A.Default)
    Line("omw to {{player}}", A.Casual)
    Line("going to {{player}}", A.Casual)
    Line("Hey {{player}} wait for me", A.Dumb)
    Line("Moving to {{player}}'s position.", A.Tryhard)
    Line("Grouping with {{player}}.", A.Stoic)
    Line("lets stick together {{player}}", A.Teamer)

    RegisterCategory("GroupUpArrived", P.NORMAL, "When a bot has successfully grouped up with an ally.")
    Line("Alright, I'm here with {{player}}.", A.Default)
    Line("Good, let's stick together.", A.Default)
    Line("Safety in numbers.", A.Default)
    Line("aight im here", A.Casual)
    Line("lets roll", A.Casual)
    Line("ok im with {{player}} now", A.Dumb)
    Line("better to be in a group", A.Nice)
    Line("Formation established with {{player}}.", A.Tryhard)
    Line("Grouped.", A.Stoic)
    Line("ok {{player}} im with you now", A.Teamer)
    Line("good, now nobody can sneak up on us", A.Sus)

    -----------------------------------------------------------
    -- STALKING (traitor team-only)
    -----------------------------------------------------------
    RegisterCategory("StalkingTarget", P.NORMAL, "When a traitor bot is stalking {{player}} (team-only chatter).")
    Line("I've got {{player}} in my sights...", A.Default)
    Line("Following {{player}}. Waiting for the right moment.", A.Default)
    Line("{{player}} is alone. Almost time.", A.Default)
    Line("got eyes on {{player}}", A.Casual)
    Line("stalking {{player}} rn", A.Casual)
    Line("{{player}} is mine.", A.Bad)
    Line("im following {{player}}", A.Dumb)
    Line("{{player}} is DEAD. Just doesn't know it yet.", A.Hothead)
    Line("Tracking {{player}}. Optimal kill window approaching.", A.Tryhard)
    Line("{{player}}. Soon.", A.Stoic)
    Line("i got {{player}}, cover me", A.Teamer)
    Line("{{player}} has no idea...", A.Sus)

    RegisterCategory("StalkingAbort", P.NORMAL, "When a traitor bot aborts a stalk due to witnesses (team-only).")
    Line("Too many eyes. Backing off.", A.Default)
    Line("Can't do it, someone's watching.", A.Default)
    Line("Aborting, witnesses nearby.", A.Default)
    Line("nah too many people watching", A.Casual)
    Line("cant do it rn, too many witnesses", A.Casual)
    Line("Dammit, can't get them alone.", A.Bad)
    Line("theres people looking", A.Dumb)
    Line("UGH! Someone's always watching!", A.Hothead)
    Line("Abort. Witness density too high.", A.Tryhard)
    Line("Not now.", A.Stoic)
    Line("abort, too risky right now", A.Teamer)
    Line("they looked at me... do they know?", A.Sus)

    -----------------------------------------------------------
    -- SEEK COVER
    -----------------------------------------------------------
    RegisterCategory("SeekingCover", P.IMPORTANT, "When a bot is taking cover under fire.")
    Line("Taking cover!", A.Default)
    Line("I need to get behind something!", A.Default)
    Line("Finding cover, getting shot at!", A.Default)
    Line("getting behind cover!!", A.Casual)
    Line("hiding lol", A.Casual)
    Line("IM GETTING SHOT AT", A.Bad)
    Line("help im getting shot!!", A.Dumb)
    Line("COVER! NOW!", A.Hothead)
    Line("I need to find somewhere safe!", A.Nice)
    Line("Seeking cover. Returning fire shortly.", A.Tryhard)
    Line("Cover.", A.Stoic)
    Line("im pinned down help!", A.Teamer)
    Line("i knew this would happen", A.Sus)

    RegisterCategory("CoverPeekAttack", P.IMPORTANT, "When a bot peeks from cover to fire at the attacker.")
    Line("Peeking! Firing!", A.Default)
    Line("Got a shot, taking it!", A.Default)
    Line("shooting from cover!", A.Casual)
    Line("pew pew from behind here", A.Casual)
    Line("EAT THIS!", A.Bad)
    Line("I SHOOT YOU!", A.Dumb)
    Line("NOW YOU DIE!", A.Hothead)
    Line("Sorry, but I have to!", A.Nice)
    Line("Engaging from cover. Firing.", A.Tryhard)
    Line("Firing.", A.Stoic)
    Line("covering fire!", A.Teamer)
    Line("knew they'd come for me", A.Sus)

    -----------------------------------------------------------
    -- WANDER COMMENT
    -----------------------------------------------------------
    RegisterCategory("WanderComment", P.NORMAL, "When a bot makes an idle comment while wandering the map.")
    Line("Just patrolling around...", A.Default)
    Line("Nothing here, moving on.", A.Default)
    Line("Checking this area out.", A.Default)
    Line("just walkin around", A.Casual)
    Line("exploring lol", A.Casual)
    Line("This map is boring.", A.Bad)
    Line("where am i going", A.Dumb)
    Line("im lost", A.Dumb)
    Line("Where IS everyone?", A.Hothead)
    Line("Nice area, seems safe.", A.Nice)
    Line("Clearing sector. No contacts.", A.Tryhard)
    Line("Patrolling.", A.Stoic)
    Line("anyone wanna come with me?", A.Teamer)
    Line("nobody around... too quiet...", A.Sus)

    -----------------------------------------------------------
    -- LOOTING / GETTING WEAPONS
    -----------------------------------------------------------
    RegisterCategory("LootingWeapon", P.NORMAL, "When a bot comments on looting a dropped weapon.")
    Line("Ooh, someone dropped a weapon. Mine now.", A.Default)
    Line("Picking up this weapon, don't mind me.", A.Default)
    Line("Found a weapon on the ground.", A.Default)
    Line("ooh free gun", A.Casual)
    Line("yoink", A.Casual)
    Line("dibs on this weapon", A.Bad)
    Line("ooh shiny!", A.Dumb)
    Line("MINE!", A.Hothead)
    Line("Oh, someone left this. I'll take it.", A.Nice)
    Line("Acquiring dropped ordnance. Upgrade detected.", A.Tryhard)
    Line("Picking up.", A.Stoic)
    Line("im grabbing this gun guys", A.Teamer)
    Line("why was this just lying here... trap?", A.Sus)

    RegisterCategory("GettingWeapon", P.NORMAL, "When a bot comments while heading to pick up a weapon.")
    Line("I need a weapon.", A.Default)
    Line("Gotta grab a weapon real quick.", A.Default)
    Line("need a gun brb", A.Casual)
    Line("i need a weapon", A.Dumb)
    Line("GIVE ME A WEAPON!", A.Hothead)
    Line("Anyone have a spare weapon?", A.Nice)
    Line("Acquiring armament.", A.Tryhard)
    Line("Arming up.", A.Stoic)
    Line("i gotta go get a gun hold on", A.Teamer)

    -----------------------------------------------------------
    -- BODYGUARD
    -----------------------------------------------------------
    RegisterCategory("BodyguardProtecting", P.IMPORTANT, "When a bodyguard bot announces they are protecting someone (team-only).")
    Line("I'm protecting {{player}}. Stay close.", A.Default)
    Line("Guarding {{player}}, nobody touches them.", A.Default)
    Line("{{player}} is under my protection.", A.Default)
    Line("watching over {{player}}", A.Casual)
    Line("got {{player}}'s back", A.Casual)
    Line("Anyone touches {{player}} and they're DEAD!", A.Hothead)
    Line("Don't worry {{player}}, I've got you.", A.Nice)
    Line("Bodyguard protocol active. VIP: {{player}}.", A.Tryhard)
    Line("Protecting {{player}}.", A.Stoic)
    Line("im guarding {{player}}, nobody touch them", A.Teamer)

    -----------------------------------------------------------
    -- DECROWD
    -----------------------------------------------------------
    RegisterCategory("DecrowdMoving", P.NORMAL, "When a bot notices crowding and moves away.")
    Line("Too many people here, I'm moving.", A.Default)
    Line("Getting a bit crowded, backing up.", A.Default)
    Line("too many people here", A.Casual)
    Line("its crowded", A.Dumb)
    Line("MOVE! Out of my way!", A.Hothead)
    Line("Sorry, just need a bit of space.", A.Nice)
    Line("Excessive player density. Relocating.", A.Tryhard)
    Line("Crowded. Moving.", A.Stoic)
    Line("guys spread out a bit", A.Teamer)
    Line("everyone bunched up like this is dangerous", A.Sus)

    -----------------------------------------------------------
    -- CLEAR BREAKABLES
    -----------------------------------------------------------
    RegisterCategory("ClearingBreakables", P.NORMAL, "When a bot comments on breaking objects in their path.")
    Line("Clearing this out of the way.", A.Default)
    Line("Breaking through this.", A.Default)
    Line("smashing stuff lol", A.Casual)
    Line("bonk!", A.Dumb)
    Line("OUT OF MY WAY!", A.Hothead)
    Line("Just clearing the path.", A.Nice)
    Line("Clearing obstacle.", A.Tryhard)
    Line("Breaking.", A.Stoic)

    -----------------------------------------------------------
    -- INFECTED RUSHING
    -----------------------------------------------------------
    RegisterCategory("InfectedRushing", P.IMPORTANT, "When an infected zombie bot rushes toward enemies (team-only).")
    Line("CHARGE! Get them!", A.Default)
    Line("Rushing in! Attack!", A.Default)
    Line("lets gooo rush them!", A.Casual)
    Line("RAAAAAGH!", A.Hothead)
    Line("brains!!", A.Dumb)
    Line("Moving to engage. Full assault.", A.Tryhard)
    Line("Charging.", A.Stoic)
    Line("rush them now!", A.Teamer)

    -----------------------------------------------------------
    -- GLUTTON BITING
    -----------------------------------------------------------
    RegisterCategory("GluttonBiting", P.NORMAL, "When a glutton bot is seeking food (team-only).")
    Line("So hungry... need to eat...", A.Default)
    Line("I need food, finding someone to bite.", A.Default)
    Line("im starving omg", A.Casual)
    Line("FOOD! I NEED FOOD!", A.Hothead)
    Line("me hungry", A.Dumb)
    Line("Hunger critical. Engaging feeding protocol.", A.Tryhard)
    Line("Hungry.", A.Stoic)
    Line("i need to eat, cover me", A.Teamer)

    -----------------------------------------------------------
    -- DOOMGUY HUNTING
    -----------------------------------------------------------
    RegisterCategory("DoomguyHunting", P.NORMAL, "When Doomguy is actively hunting targets.")
    Line("Rip and tear!", A.Default)
    Line("Time to hunt.", A.Default)
    Line("Nobody escapes the Doom Slayer.", A.Default)
    Line("hunting time lets gooo", A.Casual)
    Line("THEY WILL ALL FALL!", A.Hothead)
    Line("im gonna get them!", A.Dumb)
    Line("Engaging hunt mode. Target acquisition.", A.Tryhard)
    Line("Hunting.", A.Stoic)
    Line("im going hunting, wish me luck", A.Teamer)

    -----------------------------------------------------------
    -- VULTURE FEEDING
    -----------------------------------------------------------
    RegisterCategory("VultureFeeding", P.NORMAL, "When a vulture bot is seeking corpses to eat.")
    Line("I can smell a body nearby...", A.Default)
    Line("Time to feed.", A.Default)
    Line("found a body yum", A.Casual)
    Line("MINE! Don't touch that body!", A.Hothead)
    Line("ooh whats that", A.Dumb)
    Line("Corpse located. Initiating consumption.", A.Tryhard)
    Line("Feeding.", A.Stoic)

    -----------------------------------------------------------
    -- JANITOR SWEEPING
    -----------------------------------------------------------
    RegisterCategory("JanitorSweeping", P.NORMAL, "When a janitor bot is cleaning up corpses (team-only).")
    Line("Time to clean up this mess.", A.Default)
    Line("Sweeping the evidence.", A.Default)
    Line("cleaning up the bodies", A.Casual)
    Line("NOBODY WILL KNOW!", A.Hothead)
    Line("im cleaning the body", A.Dumb)
    Line("Initiating evidence disposal.", A.Tryhard)
    Line("Cleaning.", A.Stoic)
    Line("cleaning this up, cover me", A.Teamer)

    -----------------------------------------------------------
    -- TRAPPING PLAYER (traitor team-only)
    -----------------------------------------------------------
    RegisterCategory("TrappingPlayer", P.NORMAL, "When a traitor bot locks a door after killing someone (team-only).")
    Line("Locking this door behind me.", A.Default)
    Line("Nobody's finding this body.", A.Default)
    Line("Door locked. Evidence secured.", A.Default)
    Line("locking the door lol", A.Casual)
    Line("haha locked", A.Casual)
    Line("Good luck finding THIS body.", A.Bad)
    Line("im locking the door", A.Dumb)
    Line("STAY OUT!", A.Hothead)
    Line("Evidence containment. Locking entry point.", A.Tryhard)
    Line("Locked.", A.Stoic)
    Line("locking this up, we're good", A.Teamer)

    -----------------------------------------------------------
    -- REVIVING PLAYER
    -----------------------------------------------------------
    RegisterCategory("RevivingPlayer", P.IMPORTANT, "When a bot announces they are attempting to revive {{player}} with a defibrillator.")
    Line("Hold on {{player}}, I'm reviving you!", A.Default)
    Line("I've got the defib! Reviving {{player}}!", A.Default)
    Line("Don't worry {{player}}, I'll bring you back.", A.Default)
    Line("reviving {{player}} hold on", A.Casual)
    Line("defibbing {{player}} brb", A.Casual)
    Line("{{player}} better be grateful for this.", A.Bad)
    Line("im zapping {{player}} back!", A.Dumb)
    Line("CLEAR! Reviving {{player}}!", A.Hothead)
    Line("I'll save you {{player}}!", A.Nice)
    Line("Initiating revival procedure on {{player}}.", A.Tryhard)
    Line("Reviving {{player}}.", A.Stoic)
    Line("im getting {{player}} back guys cover me", A.Teamer)
    Line("reviving {{player}}... hope they're not the traitor", A.Sus)

    -----------------------------------------------------------
    -- GUARDIAN SEEKING
    -----------------------------------------------------------
    RegisterCategory("GuardianSeeking", P.NORMAL, "When a guardian bot announces they are looking for someone to protect.")
    Line("Looking for someone to guard.", A.Default)
    Line("I need to find someone to protect.", A.Default)
    Line("Guardian here, who needs protection?", A.Default)
    Line("looking for someone to protect", A.Casual)
    Line("anyone need a bodyguard?", A.Casual)
    Line("Stay close to me if you want to live.", A.Bad)
    Line("who needs protecting??", A.Dumb)
    Line("I'LL PROTECT SOMEONE!", A.Hothead)
    Line("I'd like to help someone, let me guard you!", A.Nice)
    Line("Guardian online. Seeking VIP.", A.Tryhard)
    Line("Guarding.", A.Stoic)
    Line("who needs protection? im guardian", A.Teamer)

    -----------------------------------------------------------
    -- MINGE CROWBAR
    -----------------------------------------------------------
    RegisterCategory("MingeCrowbar", P.NORMAL, "When a bot decides to troll someone with crowbar pushes.")
    Line("Bonk!", A.Default)
    Line("Hehe, crowbar time!", A.Default)
    Line("lmao bonk", A.Casual)
    Line("yeet", A.Casual)
    Line("WHACK!", A.Bad)
    Line("hehe crowbar go brrr", A.Dumb)
    Line("bonk bonk!", A.Dumb)
    Line("GET OVER HERE!", A.Hothead)
    Line("Sorry, I just had to!", A.Nice)
    Line("Applying kinetic force test.", A.Tryhard)
    Line("Bonk.", A.Stoic)
end

hook.Add("TTTBots_LocaleLoaded", "TTTBots_SuspicionChats", LoadSuspicionChats)
if TTTBots.Locale and TTTBots.Locale.AddLine then LoadSuspicionChats() end
