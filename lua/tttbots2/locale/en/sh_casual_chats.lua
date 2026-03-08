--[[
    sh_casual_chats.lua
    Casual / idle conversation templates for bots.
    These are split into a separate file to keep sh_chats.lua manageable.

    Categories:
        CasualObservation    - Random map / game observations
        CasualJoke           - Light-hearted jokes or puns
        CasualStory          - Mini anecdote snippets
        CasualCompliment     - Complimenting another player
        CasualComplaint      - Low-stakes gripes
        CasualQuestion       - Asks a rhetorical or real question
        CasualNervous        - Nervous small-talk while nothing is happening
        CasualBoredom        - Boredom-driven idle chatter (high boredom stat trigger)
        CasualWeather        - Absurd "weather/map flavour" observations
        PostCombatRelief     - After surviving a fight / close call
        NearMissReaction     - Bullet flew past, narrowly avoided death
        SurvivorRelief       - Being the last survivor of a dangerous situation
        QuietRoundComment    - When nobody has died in a while
        DialogCasual*        - Multi-bot casual dialog lines
]]

local P = {
    CRITICAL = 1,
    IMPORTANT = 2,
    NORMAL = 3,
}

local LoadCasualLang = function()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end

    ---------------------------------------------------------------------------
    -- CasualObservation — random map/game world observations
    ---------------------------------------------------------------------------
    RegisterCategory("CasualObservation", P.NORMAL, "Bot makes an idle observation about their surroundings.")
    Line("This map is actually kind of nice.", A.Default)
    Line("Ever notice how quiet it gets sometimes?", A.Default)
    Line("I keep forgetting how big this place is.", A.Default)
    Line("Something feels off today.", A.Default)
    Line("The lighting in here is terrible.", A.Default)
    Line("I should check that area out.", A.Default)

    Line("this map goes kinda hard ngl", A.Casual)
    Line("bro there's so many hiding spots here", A.Casual)
    Line("does anyone else feel like we're being watched lol", A.Casual)
    Line("this place kinda gives me the creeps tbh", A.Casual)
    Line("ok who designed this map", A.Casual)
    Line("vibes in here are immaculate rn", A.Casual)

    Line("Adequate terrain. Good sightlines.", A.Tryhard)
    Line("This layout favors aggressive play.", A.Tryhard)
    Line("Chokepoints noted. Adapting strategy.", A.Tryhard)
    Line("Map control is key here.", A.Tryhard)
    Line("Two flanks, one main corridor. Classic.", A.Tryhard)

    Line("I don't like this place.", A.Hothead)
    Line("Everything in here is annoying.", A.Hothead)
    Line("Who put all this stuff here?", A.Hothead)
    Line("Ugh, this map again.", A.Hothead)
    Line("I hate how long it takes to cross this room.", A.Hothead)

    Line("Everything is where it should be.", A.Stoic)
    Line("The architecture here is functional.", A.Stoic)
    Line("I have noted the exits.", A.Stoic)
    Line("This area is manageable.", A.Stoic)

    Line("Where is everything?", A.Dumb)
    Line("I walked in a circle again.", A.Dumb)
    Line("This map is too big for my brain.", A.Dumb)
    Line("Is that a door or a wall?", A.Dumb)
    Line("I keep ending up in the same room.", A.Dumb)

    Line("Lovely place. I adore the decor.", A.Nice)
    Line("Someone put real effort into this map!", A.Nice)
    Line("This is actually a really fun layout.", A.Nice)
    Line("I don't mind playing here.", A.Nice)

    Line("Great spot for an ambush.", A.Bad)
    Line("Nobody's watching this corner.", A.Bad)
    Line("So many places to hide.", A.Bad)

    Line("I'm watching everyone from up here.", A.Sus)
    Line("This room has suspicious energy.", A.Sus)
    Line("Why does everyone keep walking past me?", A.Sus)
    Line("I feel like something is about to happen.", A.Sus)

    Line("We should stick together in here.", A.Teamer)
    Line("I'll cover the left, you cover the right.", A.Teamer)
    Line("Let's keep an eye on each other.", A.Teamer)

    ---------------------------------------------------------------------------
    -- CasualJoke — light-hearted jokes or puns
    ---------------------------------------------------------------------------
    RegisterCategory("CasualJoke", P.NORMAL, "Bot tells a light joke or makes a humorous remark.")
    Line("Why did the traitor cross the road? To avoid detection.", A.Default)
    Line("If you kill me, at least I die doing what I love — being confused.", A.Default)
    Line("I'm not suspicious. Suspicion is a state of mind.", A.Default)
    Line("Detective work is just vibes, right?", A.Default)

    Line("imagine being a traitor and still losing lmaooo", A.Casual)
    Line("me: definitely not the traitor. also me: *sweating*", A.Casual)
    Line("fun fact: shooting your friends is generally frowned upon", A.Casual)
    Line("they say the best traitor is the one you trust most. so basically me", A.Casual)
    Line("ok so what if the real traitor was the friends we made along the way", A.Casual)

    Line("My win rate is zero but my heart rate is 200.", A.Tryhard)
    Line("The meta is evolving. I am evolving with it.", A.Tryhard)
    Line("Fun is for people without rankings.", A.Tryhard)
    Line("I speedran losing. World record.", A.Tryhard)

    Line("If I die, blame the other guy.", A.Hothead)
    Line("I'm not mad. I'm INTENSELY focused.", A.Hothead)
    Line("Joke? No jokes. Only victory.", A.Hothead)

    Line("I accidentally said hello to a corpse.", A.Dumb)
    Line("What is a traitor? Is it like a trader?", A.Dumb)
    Line("I put my gun down and I can't find it.", A.Dumb)
    Line("I laughed at a dead body and now I feel weird.", A.Dumb)
    Line("Do bullets hurt? Asking for a friend.", A.Dumb)

    Line("Why can't we all just be innocent?", A.Nice)
    Line("I think we're all winners in our own way.", A.Nice)
    Line("We should hug it out after this round.", A.Nice)

    Line("Ha. Funny. I still know where you all are.", A.Bad)
    Line("You're all so trusting. It's adorable.", A.Bad)

    Line("I have a theory. Everyone is the traitor except me. And I might be wrong.", A.Sus)
    Line("Statistically speaking, one of us is going to die soon. Exciting.", A.Sus)

    Line("Team fun is still team. Good joke.", A.Teamer)

    ---------------------------------------------------------------------------
    -- CasualStory — mini-anecdote style quips
    ---------------------------------------------------------------------------
    RegisterCategory("CasualStory", P.NORMAL, "Bot shares a brief fake anecdote or personal story snippet.")
    Line("One time I walked into a room and just turned around. Best decision of my life.", A.Default)
    Line("I once followed someone for five minutes because I thought they looked sus.", A.Default)
    Line("Last round I was watching the door the whole time. Nothing happened.", A.Default)
    Line("I had a plan once. It didn't survive first contact.", A.Default)

    Line("bro last round i was the last one alive and i just panicked the whole time", A.Casual)
    Line("i once called KOS on myself by accident", A.Casual)
    Line("one time i found a gun and had no idea what it did", A.Casual)
    Line("i walked past a traitor TWICE and didn't notice lol", A.Casual)

    Line("In my personal experience, the best strategy is doing everything right.", A.Tryhard)
    Line("I once hit a 180 flick shot on a moving target. Peak performance.", A.Tryhard)
    Line("My worst round was still better than most people's best.", A.Tryhard)

    Line("I got mad at the map once. The map won.", A.Hothead)
    Line("I was so mad last round I missed every shot.", A.Hothead)

    Line("Once I hid in a corner the entire round. Peaceful.", A.Stoic)
    Line("I watched two others fight each other for two minutes. Neither noticed me.", A.Stoic)

    Line("I accidentally healed a traitor once. We don't talk about it.", A.Nice)
    Line("One time I gave someone my last health kit. Then we both died. Worth it.", A.Nice)
    Line("I defended someone who turned out to be the traitor. Still proud of the effort.", A.Nice)

    Line("I once followed someone into a room and nothing bad happened. So I did it again.", A.Bad)

    Line("I once accidentally walked into my own team's line of fire. Good round.", A.Dumb)
    Line("I thought the traitor button was the elevator. I pressed it.", A.Dumb)

    Line("Last round our whole team moved together and won. We do it again.", A.Teamer)

    Line("I followed someone all round trying to figure them out. Still unsure.", A.Sus)

    ---------------------------------------------------------------------------
    -- CasualCompliment — complimenting another bot or situation
    ---------------------------------------------------------------------------
    RegisterCategory("CasualCompliment", P.NORMAL, "Bot compliments someone or something.")
    Line("Nice move earlier.", A.Default)
    Line("You're doing alright.", A.Default)
    Line("Solid play so far.", A.Default)
    Line("Good to have someone reliable around.", A.Default)

    Line("okay you're lowkey decent at this game", A.Casual)
    Line("ngl good play earlier", A.Casual)
    Line("you're not as bad as i thought lol", A.Casual)
    Line("that was actually kinda smart", A.Casual)

    Line("Your positioning is textbook.", A.Tryhard)
    Line("You actually know what you're doing. Rare.", A.Tryhard)
    Line("I respect the decision-making.", A.Tryhard)

    Line("You're not terrible. High praise.", A.Hothead)
    Line("Okay, fine, that was good.", A.Hothead)

    Line("Well done.", A.Stoic)
    Line("Effective.", A.Stoic)
    Line("That was the correct choice.", A.Stoic)

    Line("You're amazing! Seriously!", A.Nice)
    Line("I love having you on the team!", A.Nice)
    Line("You always know what to do!", A.Nice)
    Line("That was genuinely impressive.", A.Nice)
    Line("I'm glad you're here.", A.Nice)

    Line("Ha, even you can get it right sometimes.", A.Bad)

    Line("You played that perfectly. Studying you.", A.Sus)

    Line("That's what teamwork looks like right there.", A.Teamer)
    Line("See, this is why we work well together.", A.Teamer)

    ---------------------------------------------------------------------------
    -- CasualComplaint — low-stakes gripes about nothing serious
    ---------------------------------------------------------------------------
    RegisterCategory("CasualComplaint", P.NORMAL, "Bot gripes about something minor.")
    Line("My feet hurt. Metaphorically.", A.Default)
    Line("I've been walking for what feels like forever.", A.Default)
    Line("I keep running out of ammo at the worst time.", A.Default)
    Line("Why is this map so confusing?", A.Default)

    Line("i hate how long this round is going", A.Casual)
    Line("bro my aim is off today", A.Casual)
    Line("i keep getting the bad gun", A.Casual)
    Line("why does this always happen to me", A.Casual)
    Line("i am NOT having a good time rn", A.Casual)

    Line("These spawns are unbalanced.", A.Tryhard)
    Line("Suboptimal weapon distribution.", A.Tryhard)
    Line("This round has poor RNG.", A.Tryhard)

    Line("Everything in this round is annoying.", A.Hothead)
    Line("Why is nothing going right?!", A.Hothead)
    Line("I swear this game hates me.", A.Hothead)
    Line("Nothing is working and I'm frustrated.", A.Hothead)

    Line("This is inefficient.", A.Stoic)
    Line("There are better ways to do this.", A.Stoic)
    Line("I dislike poor coordination.", A.Stoic)

    Line("This is hard. Too hard.", A.Dumb)
    Line("Why does everything happen at once?", A.Dumb)
    Line("I don't know where to go.", A.Dumb)

    Line("This is fine. It's totally fine.", A.Nice)
    Line("I'm sure it'll get better soon!", A.Nice)

    Line("Everything is terrible and I love it.", A.Bad)
    Line("I deserve better weapons.", A.Bad)

    Line("This situation is suboptimal for my plans.", A.Sus)

    Line("We need better coordination.", A.Teamer)
    Line("We keep splitting up too much.", A.Teamer)

    ---------------------------------------------------------------------------
    -- CasualQuestion — rhetorical or genuine idle questions
    ---------------------------------------------------------------------------
    RegisterCategory("CasualQuestion", P.NORMAL, "Bot asks an idle rhetorical or casual question.")
    Line("Does anyone else feel like this round is taking forever?", A.Default)
    Line("Is it just me or is it really quiet right now?", A.Default)
    Line("Anyone else running low on ammo?", A.Default)
    Line("What's everyone up to?", A.Default)
    Line("Am I the only one paying attention?", A.Default)

    Line("does anyone else feel like the traitor is just watching us rn", A.Casual)
    Line("why is nobody talking lol", A.Casual)
    Line("wait are we all just wandering around?", A.Casual)
    Line("can we agree to all be chill for like 5 seconds", A.Casual)
    Line("is it me or is this round super boring so far", A.Casual)

    Line("Has anyone mapped out traitor movement patterns this round?", A.Tryhard)
    Line("What's the intel situation looking like?", A.Tryhard)
    Line("Anyone tracking the traitor's last known position?", A.Tryhard)

    Line("Why is nobody doing anything?!", A.Hothead)
    Line("Is everyone asleep?!", A.Hothead)
    Line("Can we speed this up?", A.Hothead)

    Line("What is the current situation?", A.Stoic)
    Line("What are the relevant facts?", A.Stoic)
    Line("Has anything noteworthy occurred?", A.Stoic)

    Line("What do we do now?", A.Dumb)
    Line("Where is everyone going?", A.Dumb)
    Line("Did something happen? I missed it.", A.Dumb)
    Line("Are we winning?", A.Dumb)

    Line("Is everyone doing okay?", A.Nice)
    Line("Can I help anyone with anything?", A.Nice)
    Line("Are we all sticking together?", A.Nice)

    Line("Anyone noticing what I'm noticing?", A.Sus)
    Line("Is anyone else watching that one person?", A.Sus)

    Line("Are we coordinating or just hoping for the best?", A.Teamer)
    Line("What's the plan, team?", A.Teamer)

    ---------------------------------------------------------------------------
    -- CasualNervous — nervous small-talk when nothing's happening
    ---------------------------------------------------------------------------
    RegisterCategory("CasualNervous", P.NORMAL, "Bot is visibly anxious during a quiet stretch.")
    Line("It's too quiet. I don't like it.", A.Default)
    Line("Something's going to happen. I can feel it.", A.Default)
    Line("Every time it gets this calm, something bad happens.", A.Default)
    Line("I hate waiting more than fighting.", A.Default)

    Line("bro the silence is literally killing me", A.Casual)
    Line("i'm so tense rn for no reason", A.Casual)
    Line("ok i need something to happen", A.Casual)
    Line("this calm is sus", A.Casual)
    Line("waiting is the worst part of ttt honestly", A.Casual)

    Line("Elevated heart rate. Tactical readiness.", A.Tryhard)
    Line("Silence before a storm. Preparing.", A.Tryhard)
    Line("Stay focused. Something is coming.", A.Tryhard)

    Line("I HATE THIS WAITING!", A.Hothead)
    Line("Just let something happen already!", A.Hothead)
    Line("My nerves are shot.", A.Hothead)

    Line("Silence is not inherently suspicious. But it is suspicious here.", A.Stoic)
    Line("Remaining alert.", A.Stoic)

    Line("I'm scared.", A.Dumb)
    Line("What's that sound?! Oh. Nothing.", A.Dumb)
    Line("I keep thinking someone's behind me.", A.Dumb)

    Line("Deep breaths, everyone. We're fine.", A.Nice)
    Line("I'm sure we're all perfectly safe!", A.Nice)

    Line("Good. Let them get comfortable.", A.Bad)
    Line("Nobody suspects anything. Perfect.", A.Bad)

    Line("The calm before the storm. I wonder who breaks first.", A.Sus)
    Line("Everyone is just a little too relaxed right now.", A.Sus)

    Line("Stay together. This is when it gets dangerous.", A.Teamer)
    Line("Group up. I don't like being spread out right now.", A.Teamer)

    ---------------------------------------------------------------------------
    -- CasualBoredom — fired when bot has high boredom stat
    ---------------------------------------------------------------------------
    RegisterCategory("CasualBoredom", P.NORMAL, "Bot is visibly bored — triggered by high boredom stat.")
    Line("Is something happening? Anything?", A.Default)
    Line("I've been walking the same path for 10 minutes.", A.Default)
    Line("This round is suspiciously peaceful.", A.Default)
    Line("Someone. Anyone. Do something.", A.Default)
    Line("I feel like I've checked every room twice.", A.Default)

    Line("bro i'm literally falling asleep", A.Casual)
    Line("i need something to happen rn", A.Casual)
    Line("hello?? is this game on?", A.Casual)
    Line("the vibes are dead. the map is dead. i might be dead.", A.Casual)
    Line("ok i'll be honest i was afk for a second", A.Casual)
    Line("i've stared at this wall for too long", A.Casual)

    Line("Downtime. Inefficient.", A.Tryhard)
    Line("Standing by for something worth my attention.", A.Tryhard)
    Line("Performance declines during inaction.", A.Tryhard)

    Line("BORING! Do something!", A.Hothead)
    Line("This round is TRASH! Where's the action?!", A.Hothead)
    Line("I'm going to start fights myself if nothing happens.", A.Hothead)

    Line("I am waiting.", A.Stoic)
    Line("Patience is a virtue. Testing mine.", A.Stoic)

    Line("Zzzzz. Oh sorry. I'm awake.", A.Dumb)
    Line("I tried to entertain myself but I don't know how.", A.Dumb)
    Line("I drew a smiley face on my hand.", A.Dumb)

    Line("I'm so bored but at least we're all bored together!", A.Nice)
    Line("Want to play a guessing game while we wait?", A.Nice)

    Line("Boredom? No. I'm just... plotting.", A.Bad)
    Line("The waiting is part of the plan.", A.Bad)

    Line("Boring rounds are actually an opportunity if you think about it.", A.Sus)
    Line("I've just been watching everyone. Learning.", A.Sus)

    Line("Team morale is flagging. Need something to do.", A.Teamer)
    Line("Come on guys, let's find something.", A.Teamer)

    ---------------------------------------------------------------------------
    -- CasualWeather — absurd "weather / environment" flavour commentary
    ---------------------------------------------------------------------------
    RegisterCategory("CasualWeather", P.NORMAL, "Absurd casual observation about the 'atmosphere' of the map.")
    Line("If this were a real place, I'd be cold.", A.Default)
    Line("Great weather for... whatever this is.", A.Default)
    Line("Smells like concrete and bad decisions.", A.Default)
    Line("I think it's overcast today. Hard to say.", A.Default)

    Line("bro it feels like a monday in here", A.Casual)
    Line("this lighting is giving me existential dread", A.Casual)
    Line("the air quality in here is terrible", A.Casual)
    Line("why does every map smell like old metal", A.Casual)

    Line("Environmental conditions: suboptimal for performance.", A.Tryhard)
    Line("Poor lighting. Visibility disadvantage.", A.Tryhard)
    Line("I've played in worse conditions. Barely.", A.Tryhard)

    Line("It's dark and I hate it.", A.Hothead)
    Line("Who designed this lighting? Fire them.", A.Hothead)

    Line("The ambient conditions are unremarkable.", A.Stoic)
    Line("Temperature: irrelevant. Focusing on task.", A.Stoic)

    Line("I wonder if it rains here.", A.Dumb)
    Line("Is there wind? I think I felt wind.", A.Dumb)
    Line("The floor is very floor-like today.", A.Dumb)

    Line("I like the atmosphere! Very cozy for a murder map.", A.Nice)
    Line("If I ignore the guns, this place is kind of pretty.", A.Nice)

    Line("Good lighting for shadowy business.", A.Bad)

    Line("The shadows here are suspicious. Everything is suspicious.", A.Sus)

    ---------------------------------------------------------------------------
    -- PostCombatRelief — after surviving a fight
    ---------------------------------------------------------------------------
    RegisterCategory("PostCombatRelief", P.NORMAL, "Bot expresses relief after surviving a fight or dangerous situation.")
    Line("That was close.", A.Default)
    Line("Still alive. Barely.", A.Default)
    Line("Glad that's over.", A.Default)
    Line("I need a second.", A.Default)
    Line("Okay. Okay. I'm fine.", A.Default)

    Line("bro my heart is pounding", A.Casual)
    Line("okay that was WAY too close", A.Casual)
    Line("i literally almost died just now lol", A.Casual)
    Line("that was kinda nuts ngl", A.Casual)
    Line("ok i'm shaking. good shaking. alive shaking.", A.Casual)

    Line("Survived. Back to optimum performance.", A.Tryhard)
    Line("That margin was unacceptably thin. Recalibrating.", A.Tryhard)
    Line("Damage taken. Acceptable. Continuing.", A.Tryhard)
    Line("Won that exchange. Note the weaknesses.", A.Tryhard)

    Line("That's what I'm TALKING about!", A.Hothead)
    Line("COME ON! WHO'S NEXT?!", A.Hothead)
    Line("I'm pumped up. Let's GO.", A.Hothead)
    Line("Don't test me like that again.", A.Hothead)

    Line("Threat neutralised.", A.Stoic)
    Line("That is over. Moving on.", A.Stoic)
    Line("I sustained damage. Continuing regardless.", A.Stoic)

    Line("Wait... I'm alive? I thought I was dead!", A.Dumb)
    Line("I closed my eyes. Did I win?", A.Dumb)
    Line("That was scary.", A.Dumb)

    Line("Everyone alright? Is everyone okay?", A.Nice)
    Line("That was scary but we made it!", A.Nice)
    Line("I'm just glad nobody got seriously hurt.", A.Nice)

    Line("Ha. That was fun.", A.Bad)
    Line("Too easy.", A.Bad)
    Line("I could have ended that faster.", A.Bad)

    Line("I almost didn't make it. Interesting.", A.Sus)
    Line("Someone was watching. I wonder who.", A.Sus)

    Line("We covered each other well there.", A.Teamer)
    Line("Good teamwork on that one.", A.Teamer)
    Line("That's what coordinating looks like.", A.Teamer)

    ---------------------------------------------------------------------------
    -- NearMissReaction — bullet narrowly missed
    ---------------------------------------------------------------------------
    RegisterCategory("NearMissReaction", P.NORMAL, "Bot reacts to nearly getting shot.")
    Line("That was uncomfortably close.", A.Default)
    Line("A little to the left and I'd be dead.", A.Default)
    Line("Someone just shot near me.", A.Default)
    Line("Was that aimed at me?", A.Default)

    Line("HELLO?? someone is shooting near me!!", A.Casual)
    Line("bro that almost hit me what the heck", A.Casual)
    Line("ok that was a little too close for comfort", A.Casual)
    Line("uh. who just shot near me", A.Casual)

    Line("Incoming fire. Adjusting position.", A.Tryhard)
    Line("That trajectory had my name on it.", A.Tryhard)
    Line("Flanking. They missed. Now they pay.", A.Tryhard)

    Line("HEY! WATCH IT!", A.Hothead)
    Line("Did someone just shoot at me?! WHO WAS THAT?!", A.Hothead)
    Line("I WILL find out who just did that.", A.Hothead)

    Line("I noted that.", A.Stoic)
    Line("Someone fired in my direction. Noted.", A.Stoic)

    Line("Ow! Wait, I wasn't hit. Still OW.", A.Dumb)
    Line("I instinctively ducked. Smart me.", A.Dumb)

    Line("Oh! Careful please!", A.Nice)
    Line("That was a close one! Everyone alright?", A.Nice)

    Line("Missed. I'll remember that.", A.Bad)
    Line("Good try.", A.Bad)

    Line("Someone shot near me on purpose. Noted.", A.Sus)
    Line("That was a warning shot. Interesting.", A.Sus)

    Line("Watch where you're firing, we're together!", A.Teamer)

    ---------------------------------------------------------------------------
    -- SurvivorRelief — after all others in a situation died except this bot
    ---------------------------------------------------------------------------
    RegisterCategory("SurvivorRelief", P.NORMAL, "Bot reacts after surviving when others around them died.")
    Line("...I'm the last one standing here.", A.Default)
    Line("Everyone else is gone. Just me.", A.Default)
    Line("I made it through.", A.Default)
    Line("I don't know how I'm still here.", A.Default)

    Line("wait. am i the only one left?", A.Casual)
    Line("bro i'm somehow still alive", A.Casual)
    Line("i don't know how i survived that", A.Casual)
    Line("everyone else is gone and i'm just... here", A.Casual)

    Line("Survival achieved. Sub-optimal team outcome.", A.Tryhard)
    Line("I am the only variable that succeeded.", A.Tryhard)
    Line("I survived because I was better prepared.", A.Tryhard)

    Line("They all fell but I DIDN'T!", A.Hothead)
    Line("Still standing! What?!", A.Hothead)
    Line("I outlasted everyone? Obviously.", A.Hothead)

    Line("I am the last one.", A.Stoic)
    Line("They are gone. I remain.", A.Stoic)

    Line("I survived? Wait, I survived!", A.Dumb)
    Line("Everyone is dead. Did I do that? I didn't do that.", A.Dumb)

    Line("Oh no. I hope everyone is okay.", A.Nice)
    Line("I wish I could have helped more.", A.Nice)
    Line("I made it, but at what cost?", A.Nice)

    Line("Fascinating. They all died and I didn't.", A.Bad)
    Line("And then there was one.", A.Bad)

    Line("I saw everything. I saw what happened.", A.Sus)
    Line("And now it's my word against the dead.", A.Sus)

    Line("We all went in together. I'm the only one left.", A.Teamer)
    Line("I should have stayed with the group.", A.Teamer)

    ---------------------------------------------------------------------------
    -- QuietRoundComment — when nobody has died in a long while
    ---------------------------------------------------------------------------
    RegisterCategory("QuietRoundComment", P.NORMAL, "Bot comments on an unusually quiet stretch with no deaths.")
    Line("Nobody's died in a while. That's either good or very bad.", A.Default)
    Line("Strangely peaceful round so far.", A.Default)
    Line("When nothing happens, I get suspicious.", A.Default)
    Line("We're either all innocent or the traitor is biding their time.", A.Default)

    Line("ok genuine question, is there even a traitor this round", A.Casual)
    Line("nothing is happening and i'm more scared than when things do happen", A.Casual)
    Line("the longer this goes without a death the more sus everything feels", A.Casual)
    Line("is everyone just waiting? because i'm waiting", A.Casual)

    Line("No kills in X minutes. Someone is gathering information.", A.Tryhard)
    Line("This unusual peace is a calculated stall tactic.", A.Tryhard)
    Line("Delay tactic. I've seen this before.", A.Tryhard)

    Line("This quiet is SUSPICIOUS. I hate it.", A.Hothead)
    Line("Something is WRONG. Nobody dying is WRONG!", A.Hothead)

    Line("Extended peace is tactically significant.", A.Stoic)
    Line("No deaths. Either luck or patience.", A.Stoic)

    Line("Maybe everyone is nice?", A.Dumb)
    Line("Is it over? Did we win already?", A.Dumb)
    Line("Maybe there's no traitor. Happy round!", A.Dumb)

    Line("This is so lovely! Maybe we can have a whole peaceful round!", A.Nice)
    Line("I love when nothing bad is happening!", A.Nice)

    Line("They're waiting. So am I.", A.Bad)
    Line("The longer they wait, the better my position.", A.Bad)

    Line("The traitor isn't acting. They're watching.", A.Sus)
    Line("Someone knows something. Nobody acts this calm naturally.", A.Sus)

    Line("Radio check — is everyone still alive out there?", A.Teamer)
    Line("Something's wrong. This silence is coordinated.", A.Teamer)

    ---------------------------------------------------------------------------
    -- Multi-bot casual dialog locale lines
    ---------------------------------------------------------------------------

    -- CoffeeBreak dialog
    RegisterCategory("DialogCasualCoffeeBreakOpen", P.NORMAL, "Dialog: Bot A opens a casual 'coffee break' chat.")
    Line("Man, I could really use a break right now.", A.Default)
    Line("Anyone else just... need a moment?", A.Default)
    Line("This round is dragging. Let's talk about something else.", A.Default)
    Line("if this round doesn't pick up i'm getting fictional coffee", A.Casual)
    Line("can we all agree to just chill for a second?", A.Casual)
    Line("My brain needs a rest.", A.Tryhard)
    Line("Recalibrating. Stand by.", A.Stoic)
    Line("I'm bored. Entertain me.", A.Hothead)
    Line("Can I sit? I want to sit.", A.Dumb)
    Line("Let's take a little breather, shall we?", A.Nice)
    Line("I have a plan and it involves doing nothing.", A.Bad)
    Line("I could use the downtime to observe things.", A.Sus)

    RegisterCategory("DialogCasualCoffeeBreakReply", P.NORMAL, "Dialog: Bot B responds to the break idea.")
    Line("Fair enough. Nothing's happening anyway.", A.Default)
    Line("Sure, what did you want to talk about?", A.Default)
    Line("I'm down. This round is a snooze.", A.Default)
    Line("haha yeah this round is dead", A.Casual)
    Line("same honestly", A.Casual)
    Line("Agreed. This situation is yielding no useful data.", A.Tryhard)
    Line("Downtime accepted.", A.Stoic)
    Line("FINE. But only for a minute.", A.Hothead)
    Line("Yes! Can we talk about something nice?", A.Nice)
    Line("I've been waiting for someone to say that.", A.Bad)
    Line("Interesting proposal. I accept.", A.Sus)

    RegisterCategory("DialogCasualCoffeeBreakTopic", P.NORMAL, "Dialog: Bot A brings up a random topic.")
    Line("What's everyone's strategy for this map?", A.Default)
    Line("Hypothetically, if you were the traitor, what would you do?", A.Default)
    Line("Do you think anyone here is actually good at this?", A.Default)
    Line("ok real question: who do you trust least right now", A.Casual)
    Line("what's your favorite thing about ttt", A.Casual)
    Line("Optimal traitor strategy requires information asymmetry.", A.Tryhard)
    Line("Curious: what defines a good round to you?", A.Stoic)
    Line("If I were traitor I'd have won already, just saying.", A.Hothead)
    Line("ooooh uhh... what's everyone's favorite color", A.Dumb)
    Line("Do you think we'll all make it through?", A.Nice)
    Line("I'm just curious what you all think of me.", A.Bad)
    Line("Theoretically, who would you suspect if you had to pick right now?", A.Sus)

    -- NervousWaiting dialog
    RegisterCategory("DialogCasualNervousOpen", P.NORMAL, "Dialog: Bot A opens a nervous waiting exchange.")
    Line("The longer this goes, the more on edge I get.", A.Default)
    Line("Something is going to happen soon. I can feel it.", A.Default)
    Line("I hate the quiet parts.", A.Default)
    Line("bro the tension rn is actually unbearable", A.Casual)
    Line("ok everyone just... be careful", A.Casual)
    Line("Anticipation is the worst part.", A.Tryhard)
    Line("High alert. Watching.", A.Stoic)
    Line("WHY ISN'T ANYTHING HAPPENING?!", A.Hothead)
    Line("I don't like this part.", A.Dumb)
    Line("I'm a little nervous, just between us.", A.Nice)
    Line("Perfect. Let them relax.", A.Bad)
    Line("They're all watching each other. Good.", A.Sus)

    RegisterCategory("DialogCasualNervousReply", P.NORMAL, "Dialog: Bot B relates to the nervousness.")
    Line("Yeah. Too quiet.", A.Default)
    Line("I know what you mean. I've been watching everyone.", A.Default)
    Line("something is DEFINITELY about to happen", A.Casual)
    Line("i keep jumping at nothing lol", A.Casual)
    Line("Agreed. Someone is planning.", A.Tryhard)
    Line("Confirmed. Situational awareness elevated.", A.Stoic)
    Line("YES, FINALLY someone else feels it!", A.Hothead)
    Line("oh no are we gonna die", A.Dumb)
    Line("I keep checking over my shoulder too.", A.Nice)
    Line("There's no reason to be nervous. Trust me.", A.Bad)
    Line("I've been counting everyone's movements.", A.Sus)

    -- StrangeNoise dialog
    RegisterCategory("DialogCasualNoiseOpen", P.NORMAL, "Dialog: Bot A reacts to an imagined or real strange noise.")
    Line("Did you hear that?", A.Default)
    Line("What was that sound?", A.Default)
    Line("Something moved nearby.", A.Default)
    Line("wait did you hear that just now", A.Casual)
    Line("bro what was that", A.Casual)
    Line("Audio anomaly detected.", A.Tryhard)
    Line("There was a sound.", A.Stoic)
    Line("WHAT WAS THAT?!", A.Hothead)
    Line("I hear ghosts.", A.Dumb)
    Line("Oh! Did you hear something weird too?", A.Nice)
    Line("...I hear everything.", A.Bad)
    Line("I've been tracking that sound for a while.", A.Sus)

    RegisterCategory("DialogCasualNoiseReply", P.NORMAL, "Dialog: Bot B responds to the sound report.")
    Line("Could be nothing.", A.Default)
    Line("Yeah, I heard it. Stay sharp.", A.Default)
    Line("yeah... yeah that was weird", A.Casual)
    Line("could be the traitor. could be lag.", A.Casual)
    Line("Analyzing: likely footstep from NW sector.", A.Tryhard)
    Line("Heard it. Filed.", A.Stoic)
    Line("Then let's go find them!", A.Hothead)
    Line("it's probably nothing. or everything.", A.Dumb)
    Line("I hear it too! Be careful!", A.Nice)
    Line("Sounds like opportunity to me.", A.Bad)
    Line("I know what made that sound.", A.Sus)

    -- MapCommentary dialog
    RegisterCategory("DialogCasualMapOpen", P.NORMAL, "Dialog: Bot A comments on the map layout.")
    Line("This map is bigger than I remember.", A.Default)
    Line("Why are there so many rooms here?", A.Default)
    Line("I keep getting turned around in here.", A.Default)
    Line("ok this map is genuinely confusing", A.Casual)
    Line("who built this place and why", A.Casual)
    Line("The layout presents multiple strategic vulnerabilities.", A.Tryhard)
    Line("The map has inefficient flow patterns.", A.Stoic)
    Line("This map is ANNOYING.", A.Hothead)
    Line("I think I've been here before. Or somewhere like it.", A.Dumb)
    Line("I actually kind of love this map's design!", A.Nice)
    Line("Lots of good hiding spots here.", A.Bad)
    Line("The geometry of this place is suspicious.", A.Sus)

    RegisterCategory("DialogCasualMapReply", P.NORMAL, "Dialog: Bot B agrees or disagrees about the map.")
    Line("I actually like it here.", A.Default)
    Line("It's definitely maze-like in some areas.", A.Default)
    Line("yeah the pathing here is wild", A.Casual)
    Line("i've gotten lost like three times", A.Casual)
    Line("Agreed. Poor design for competitive play.", A.Tryhard)
    Line("Acknowledgement: map layout noted.", A.Stoic)
    Line("It's the worst map. No debate.", A.Hothead)
    Line("I think all maps look the same to me", A.Dumb)
    Line("Every map has its own charm!", A.Nice)
    Line("Good for someone who knows it well.", A.Bad)
    Line("There are patterns in these rooms.", A.Sus)

    -- WeaponChat dialog
    RegisterCategory("DialogCasualWeaponOpen", P.NORMAL, "Dialog: Bot A starts talking about weapons.")
    Line("What are you carrying?", A.Default)
    Line("I got a decent weapon drop this round.", A.Default)
    Line("Found something interesting on the ground earlier.", A.Default)
    Line("what gun did you get", A.Casual)
    Line("ok i got an awful weapon lol", A.Casual)
    Line("Inventory check: what are you running?", A.Tryhard)
    Line("What loadout did you receive?", A.Stoic)
    Line("I got the worst gun in the game. Again.", A.Hothead)
    Line("I found a gun. It has bullets I think.", A.Dumb)
    Line("Did anyone find any health kits?", A.Nice)
    Line("My weapon is very good. That's all I'll say.", A.Bad)
    Line("My weapon choice says a lot about me.", A.Sus)

    RegisterCategory("DialogCasualWeaponReply", P.NORMAL, "Dialog: Bot B responds about their weapon.")
    Line("Nothing special. Could be worse.", A.Default)
    Line("Got something decent, yeah.", A.Default)
    Line("mine's okay i guess", A.Casual)
    Line("bro i have literally nothing", A.Casual)
    Line("Standard issue. Functional.", A.Tryhard)
    Line("Adequate for the task.", A.Stoic)
    Line("Mine is terrible and I hate it!", A.Hothead)
    Line("Mine has pictures on it. I like that.", A.Dumb)
    Line("Nothing amazing but I'm grateful for it!", A.Nice)
    Line("I'm doing fine. Don't worry about my weapon.", A.Bad)
    Line("I have exactly what I need.", A.Sus)

end

local DEPENDENCIES = { "Plans" }
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadCasualLang()
end
timer.Simple(1, loadModule_Deferred)
