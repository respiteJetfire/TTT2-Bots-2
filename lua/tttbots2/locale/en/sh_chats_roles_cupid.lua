--[[
    Cupid / Lover role chat categories

    This file contains chat lines for Cupid and Lover team events.
    Categories included:
        CupidCreatingLovers, CupidLoversFormed, CupidLoverDied,
        CupidLoverPanic, CupidTeamCoordinate, CupidVictory,
        CupidTimePressure, CupidBetrayedTraitor, CupidSpotted,
        CupidLoverSpotted
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadCupidChats()
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
    -- Cupid / Lover Chatter Lines
    -- ===================================================================

    RegisterCategory("CupidCreatingLovers", P.NORMAL, "When Cupid is about to shoot someone with the crossbow to create lovers.")
    Line("Time to spread the love!", A.Default)
    Line("Let's make a match!", A.Default)
    Line("Cupid's arrow is ready.", A.Default)

    Line("lol time for shipping", A.Casual)
    Line("gonna make someone fall in love hehe", A.Casual)
    Line("matchmaker time!", A.Casual)

    Line("Executing pairing protocol. First target acquired.", A.Tryhard)
    Line("Initiating lover link. Optimal pairing calculated.", A.Tryhard)

    Line("LOVE IS COMING FOR YOU!", A.Hothead)
    Line("NOBODY ESCAPES MY ARROWS!", A.Hothead)

    Line("...", A.Stoic)
    Line("Pairing.", A.Stoic)

    Line("This is going to be so sweet! Two lovebirds~", A.Nice)
    Line("Aw, I hope they'll be happy together!", A.Nice)

    Line("Suffer the bonds of love, mortals.", A.Bad)
    Line("Nothing personal. Just business.", A.Bad)

    Line("uhhh which end of the bow do i point?", A.Dumb)
    Line("is this how love works?", A.Dumb)

    Line("Creating a pair for the team!", A.Teamer)
    Line("Strategic pairing incoming!", A.Teamer)

    Line("Who said love can't be... manipulated?", A.Sus)
    Line("They'll never suspect this matchmaking has a purpose.", A.Sus)

    RegisterCategory("CupidLoversFormed", P.NORMAL, "When Cupid successfully links two players as lovers.")
    Line("It's a match! They're connected now.", A.Default)
    Line("The bond is formed!", A.Default)
    Line("Love is in the air!", A.Default)

    Line("omg they're so cute together!!", A.Casual)
    Line("ship confirmed!", A.Casual)

    Line("Lover bond established. Phase 2 initiated.", A.Tryhard)
    Line("Pairing complete. Moving to survival protocol.", A.Tryhard)

    Line("AND THEY ARE BOUND FOREVER!", A.Hothead)

    Line("Done.", A.Stoic)
    Line("Linked.", A.Stoic)

    Line("Aww, they look so good together! Be happy!", A.Nice)
    Line("What a lovely couple! I wish them the best~", A.Nice)

    Line("Now they're stuck together. Poetic.", A.Bad)
    Line("Enjoy your chain, lovebirds.", A.Bad)

    Line("wait did that work? are they in love??", A.Dumb)
    Line("i think i did a thing!!", A.Dumb)

    Line("Pair formed! Now we work as a unit!", A.Teamer)

    Line("And just like that, two fates are intertwined...", A.Sus)

    RegisterCategory("CupidLoverDied", P.NORMAL, "When a Cupid's lover partner dies — the surviving lover reacts in panic.")
    Line("NO! My partner!", A.Default)
    Line("They killed my other half!", A.Default)
    Line("I can feel the bond breaking... no!", A.Default)

    Line("NOOOO my babe!!", A.Casual)
    Line("omg they're dead im so sad", A.Casual)

    Line("Partner down! Bond severed! I'm compromised!", A.Tryhard)
    Line("Lover eliminated. Solo survival mode engaged.", A.Tryhard)

    Line("THEY KILLED THEM! THEY'RE GONNA PAY FOR THIS!", A.Hothead)
    Line("WHO DID THIS?! ANSWER ME!", A.Hothead)

    Line("...gone.", A.Stoic)
    Line("The bond is broken.", A.Stoic)

    Line("Oh no... please no... not them...", A.Nice)
    Line("This can't be happening! They were everything!", A.Nice)

    Line("Interesting. One down, and now I'm free.", A.Bad)
    Line("Shame. They were useful alive.", A.Bad)

    Line("wait what happened? where did they go??", A.Dumb)
    Line("i feel weird... is my partner ok?", A.Dumb)

    Line("We lost a teammate! Regroup!", A.Teamer)

    Line("How convenient that they died... how very convenient.", A.Sus)

    RegisterCategory("CupidLoverPanic", P.NORMAL, "When a bot's lover partner is being attacked nearby.")
    Line("Leave them alone!", A.Default)
    Line("Stop hurting my partner!", A.Default)

    Line("HEY GET AWAY FROM THEM!", A.Casual)
    Line("nooo stop itttt!", A.Casual)

    Line("Threat to lover detected! Engaging hostile!", A.Tryhard)
    Line("Protecting paired asset! Weapons free!", A.Tryhard)

    Line("TOUCH THEM AGAIN AND I'LL END YOU!", A.Hothead)
    Line("BACK OFF RIGHT NOW!", A.Hothead)

    Line("Defending.", A.Stoic)

    Line("Please stop! Don't hurt them!", A.Nice)
    Line("Why would you do that?!", A.Nice)

    Line("Big mistake targeting my partner.", A.Bad)
    Line("You shouldn't have done that.", A.Bad)

    Line("hey!! stop being mean to my friend!", A.Dumb)

    Line("Teammate under fire! Moving to assist!", A.Teamer)
    Line("Covering my partner!", A.Teamer)

    Line("Interesting choice of target you have there...", A.Sus)

    RegisterCategory("CupidTeamCoordinate", P.NORMAL, "When a lover bot is coordinating with their partner during gameplay.")
    Line("Stay close to me, partner.", A.Default)
    Line("We need to stick together.", A.Default)
    Line("I've got your back.", A.Default)

    Line("bff time! lets gooo", A.Casual)
    Line("u and me buddy!", A.Casual)

    Line("Maintaining optimal formation distance.", A.Tryhard)
    Line("Formation check. Partner within visual range.", A.Tryhard)

    Line("NOBODY SPLITS US UP!", A.Hothead)

    Line("Together.", A.Stoic)
    Line("Close.", A.Stoic)

    Line("Let's stay safe together, okay?", A.Nice)
    Line("I feel safer when we're near each other!", A.Nice)

    Line("Don't slow me down.", A.Bad)
    Line("Keep up or get left behind.", A.Bad)

    Line("where r u going? wait for me!", A.Dumb)
    Line("are we supposed to stay together? ok!", A.Dumb)

    Line("Team sync! Let's move as one!", A.Teamer)
    Line("Buddy system activated!", A.Teamer)

    Line("Interesting that we're bound together, isn't it?", A.Sus)

    RegisterCategory("CupidVictory", P.NORMAL, "When the lover team wins the round.")
    Line("Love wins! We did it!", A.Default)
    Line("The power of love prevails!", A.Default)

    Line("YESSS LOVE WINS!!", A.Casual)
    Line("get rekt losers, love is OP", A.Casual)

    Line("Lover victory condition achieved. GG.", A.Tryhard)
    Line("Objective complete. Lovers survive. Perfect execution.", A.Tryhard)

    Line("LOVE IS UNSTOPPABLE! HAHA!", A.Hothead)

    Line("Victory.", A.Stoic)

    Line("Isn't it wonderful? Love conquers all!", A.Nice)
    Line("We survived because we cared about each other!", A.Nice)

    Line("Another victory. How... romantic.", A.Bad)

    Line("wait we won? yay!!", A.Dumb)
    Line("love is cool i guess!", A.Dumb)

    Line("Teamwork from the heart! That's how we win!", A.Teamer)

    Line("Love wins... but at what cost?", A.Sus)

    RegisterCategory("CupidTimePressure", P.NORMAL, "When Cupid is running out of time to use the crossbow before it gets removed.")
    Line("I need to find someone fast!", A.Default)
    Line("Running out of time!", A.Default)
    Line("Gotta use this before it's gone!", A.Default)

    Line("omg hurry hurry hurry!", A.Casual)
    Line("no time no time no time!", A.Casual)

    Line("Critical time remaining! Must execute pairing NOW!", A.Tryhard)
    Line("Timer critical! Acquiring target immediately!", A.Tryhard)

    Line("NO WAY AM I WASTING THIS!", A.Hothead)
    Line("COME HERE, SOMEONE, ANYONE!", A.Hothead)

    Line("Hurrying.", A.Stoic)

    Line("Oh gosh, I need to hurry!", A.Nice)

    Line("Tch. Running out of time.", A.Bad)

    Line("wait the bow is disappearing??", A.Dumb)
    Line("uhh how much time do i have?", A.Dumb)

    Line("Need a teammate to pair with! Anyone!", A.Teamer)

    Line("The clock ticks... I must choose wisely.", A.Sus)

    RegisterCategory("CupidBetrayedTraitor", P.NORMAL, "When a traitor-aligned bot reacts to one of their teammates being pulled to the Lover team by Cupid.")
    Line("Wait, they switched sides?!", A.Default)
    Line("We lost one of ours to love!", A.Default)

    Line("lol they got cupid'd", A.Casual)
    Line("rip our teammate, they're in love now", A.Casual)

    Line("Ally compromised by Cupid. Adjusting strategy.", A.Tryhard)
    Line("Team composition changed. Recalculating.", A.Tryhard)

    Line("TRAITOR! YOU ABANDONED US!", A.Hothead)
    Line("LOVE MADE THEM WEAK!", A.Hothead)

    Line("Noted.", A.Stoic)

    Line("Oh... I hope they're happy at least.", A.Nice)

    Line("Pathetic. Fell for Cupid's trick.", A.Bad)
    Line("One less to share the spoils with.", A.Bad)

    Line("wait are they still on our team?", A.Dumb)
    Line("i'm confused, are we friends still?", A.Dumb)

    Line("We lost a teammate! Regroup and adapt!", A.Teamer)

    Line("How convenient that Cupid chose THEM specifically...", A.Sus)

    RegisterCategory("CupidSpotted", P.NORMAL, "When a bot identifies that a player is playing Cupid.")
    Line("That's the Cupid! Watch out!", A.Default)
    Line("I see Cupid over there.", A.Default)

    Line("omg it's cupid lol", A.Casual)
    Line("there's the matchmaker!", A.Casual)

    Line("Cupid identified! Marking threat priority.", A.Tryhard)
    Line("Visual on Cupid. Engaging awareness protocol.", A.Tryhard)

    Line("THERE'S CUPID! GET THEM!", A.Hothead)

    Line("Cupid. Spotted.", A.Stoic)

    Line("Oh, it's Cupid! I wonder who they'll pair.", A.Nice)

    Line("Found you, little matchmaker.", A.Bad)
    Line("Cupid thinks they can play god? Pathetic.", A.Bad)

    Line("what does cupid do again?", A.Dumb)

    Line("Heads up team, Cupid's in play!", A.Teamer)

    Line("Cupid... now why would they be lurking there?", A.Sus)

    RegisterCategory("CupidLoverSpotted", P.NORMAL, "When a non-lover bot spots a player on the Lover team nearby.")
    Line("Those two are lovers! Watch out.", A.Default)
    Line("That's one of the lovers.", A.Default)

    Line("aww they're in love! also they might kill us", A.Casual)
    Line("lovebirds spotted!", A.Casual)

    Line("Lover-team member identified. Threat assessment updated.", A.Tryhard)
    Line("Confirmed lover. Adjusting target priority.", A.Tryhard)

    Line("THERE'S ONE OF THE LOVERS! THEY'RE DANGEROUS!", A.Hothead)

    Line("Lover. Noted.", A.Stoic)

    Line("Oh, that's one of the lovers! Be careful everyone.", A.Nice)

    Line("Look at the little lovebird. How sweet.", A.Bad)
    Line("Lovers are a threat. Don't be fooled.", A.Bad)

    Line("are they in love? that's weird", A.Dumb)
    Line("why do they have hearts around them?", A.Dumb)

    Line("Lover spotted! Team, stay alert!", A.Teamer)

    Line("A lover, you say? How very... interesting.", A.Sus)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadCupidChats()
end
timer.Simple(1, loadModule_Deferred)
