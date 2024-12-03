--[[
    This file defines a list of chats that bots will say upon a certain kind of event. It is designed for one-off chatter events, instead of back-and-forth conversation.
    For that, we will have a separate file, and likely use the Localized String system.
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local LoadLang = function()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority)
    end
    local f = string.format
    local ACTS = TTTBots.Plans.ACTIONS

    -----------------------------------------------------------
    -- ENTRANCE/EXIT FROM SERVER
    -----------------------------------------------------------


    RegisterCategory("DisconnectBoredom", P.CRITICAL)
    Line("I'm bored. Bye.", A.Default)
    Line("Nothing's happening here. I'm out.", A.Default)
    Line("See ya when there's more action.", A.Default)
    Line("Not much going on. Catch you later.", A.Default)
    Line("This isn't my jam. Later.", A.Default)
    Line("I'm checking out. Peace.", A.Default)

    Line("cya later", A.Casual)
    Line("brb, this ain't it", A.Casual)
    Line("catch ya on the flip side.", A.Casual)
    Line("later", A.Casual)
    Line("holla later, peeps.", A.Casual)
    Line("ill be back (no i wont)", A.Casual)

    Line("What a snore-fest. I'm gone.", A.Bad)
    Line("Wake me up when it's interesting. Out.", A.Bad)
    Line("Yawn... Later losers.", A.Bad)
    Line("This game is boring. I'm leaving.", A.Bad)
    Line("This sucks. I'm done.", A.Bad)
    Line("You guys are boring. Bye.", A.Bad)

    Line("where's the exit button lol", A.Dumb)
    Line("how do you quit garry's mod", A.Dumb)
    Line("how do you turn this off?", A.Dumb)
    Line("duh... bye or something", A.Dumb)
    Line("I'm stuck. Oh wait, there's a quit button.", A.Dumb)
    Line("This too complicated. Bai.", A.Dumb)

    Line("Later pricks", A.Hothead)
    Line("You're all insufferable. Goodbye.", A.Hothead)
    Line("I'm out before I lose it.", A.Hothead)
    Line("Enough of this nonsense. Later.", A.Hothead)
    Line("I can't with you people. Bye.", A.Hothead)
    Line("Ugh, I'm done. Peace.", A.Hothead)

    Line("I'm gonna do something else. Bye!!", A.Nice)
    Line("It's been fun, but I'm heading out. Take care!", A.Nice)
    Line("You all are great, but I need a break. Bye!", A.Nice)
    Line("Had a good time, see you all soon!", A.Nice)
    Line("Thanks for the company. Until next time!", A.Nice)
    Line("It's been lovely. Catch you later!", A.Nice)

    Line("Goodbye.", A.Stoic)
    Line("Farewell.", A.Stoic)
    Line("I am leaving now.", A.Stoic)
    Line("It is time for me to go.", A.Stoic)
    Line("I shall depart.", A.Stoic)
    Line("Farewell for now.", A.Stoic)

    Line("Going to play Valorant.", A.Tryhard)
    Line("Switching to a more competitive game. Bye.", A.Tryhard)
    Line("Need more challenge. Later.", A.Tryhard)
    Line("Off to practice. Ciao.", A.Tryhard)
    Line("gonna play aimlabs cya", A.Tryhard)
    Line("Going to up my game elsewhere. Ta-ta.", A.Tryhard)


    RegisterCategory("DisconnectRage", P.CRITICAL)
    Line("Screw you guys.", A.Default)
    Line("I've had it with this!", A.Default)
    Line("This is just too much. I'm out!", A.Default)
    Line("Seriously?! Done with this nonsense.", A.Default)
    Line("Enough's enough.", A.Default)
    Line("This is the last straw. Bye.", A.Default)

    Line("ugh, screw this", A.Casual)
    Line("I'm done, y'all. Peace.", A.Casual)
    Line("Nope. Can't even.", A.Casual)
    Line("This ain't it, chief.", A.Casual)
    Line("I'm outtie. This sucks.", A.Casual)

    Line("What a pathetic waste of time.", A.Bad)
    Line("You all are the worst. Later.", A.Bad)
    Line("Good riddance. I'm out.", A.Bad)
    Line("I can't stand this garbage. Bye.", A.Bad)
    Line("This game's a joke. Later losers.", A.Bad)

    Line("Why game hard? I leave.", A.Dumb)
    Line("This too tough. Bye bye.", A.Dumb)
    Line("Me mad. Me go.", A.Dumb)
    Line("Game make head hurt. Bai.", A.Dumb)
    Line("Why everyone mean? Me out.", A.Dumb)

    Line("Screw all of you!", A.Hothead)
    Line("I can't take you idiots anymore!", A.Hothead)
    Line("Done with this BS. Peace!", A.Hothead)
    Line("Everyone here sucks. I'm gone.", A.Hothead)
    Line("I swear, you people... I'm out!", A.Hothead)

    Line("Sorry everyone, I need to cool down. Bye.", A.Nice)
    Line("I'm getting a bit frustrated. Need to step away. Take care.", A.Nice)
    Line("I think I need a break. See you all later!", A.Nice)
    Line("I'm feeling overwhelmed. Until next time.", A.Nice)
    Line("Sorry, this isn't my day. Catch you all later!", A.Nice)

    Line("I am departing now.", A.Stoic)
    Line("This is not worth my time.", A.Stoic)
    Line("I shall leave.", A.Stoic)
    Line("It's best I go.", A.Stoic)
    Line("I see no point in continuing. Goodbye.", A.Stoic)

    Line("Team, we'll regroup later. I'm out.", A.Teamer)
    Line("I need REAL competition. This is a joke.", A.Tryhard)
    Line("Pathetic. I'm off to a better game.", A.Tryhard)
    Line("I can't level up with this trash. Later.", A.Tryhard)
    Line("Waste of my skills. I'm gone.", A.Tryhard)
    Line("This isn't worth my time. Bye losers.", A.Tryhard)

    RegisterCategory("DisconnectRage", P.CRITICAL)
    Line("Damn to all of you.", A.Default)
    Line("I've had enough of this!", A.Default)
    Line("This is just too much. I'm out!", A.Default)
    Line("Seriously?! I'm tired of this nonsense.", A.Default)
    Line("Enough is enough.", A.Default)
    Line("This is the last straw. Goodbye.", A.Default)

    Line("argh, fed up with this", A.Casual)
    Line("I'm done, guys. Peace.", A.Casual)
    Line("Nope. Can't even.", A.Casual)
    Line("It's not worth it, chief.", A.Casual)
    Line("I'm out. This sucks.", A.Casual)

    Line("What a pathetic waste of time.", A.Bad)
    Line("You all are the worst. See you later.", A.Bad)
    Line("Good riddance. I'm out.", A.Bad)
    Line("I can't stand this garbage. Goodbye.", A.Bad)
    Line("This game is a joke. Later losers.", A.Bad)

    Line("Why is the game hard? I'm leaving.", A.Dumb)
    Line("It's too tough. Bye bye.", A.Dumb)
    Line("I'm angry. I'm leaving.", A.Dumb)
    Line("The game gives me a headache. Goodbye.", A.Dumb)
    Line("Why is everyone mean? I'm out.", A.Dumb)

    Line("Damn to all of you!", A.Hothead)
    Line("I can't stand you idiots anymore!", A.Hothead)
    Line("I'm done with this bullshit. Peace!", A.Hothead)
    Line("Everyone here sucks. I'm leaving.", A.Hothead)
    Line("I swear, all of you... I'm out!", A.Hothead)

    Line("Sorry everyone, I need to calm down. Goodbye.", A.Nice)
    Line("I'm a bit frustrated. I need to step away. Take care.", A.Nice)
    Line("I think I need a break. See you all later!", A.Nice)
    Line("I'm feeling overwhelmed. Until next time.", A.Nice)
    Line("Sorry, it's not my day. Catch you all later!", A.Nice)

    Line("I'm leaving now.", A.Stoic)
    Line("It's not worth my time.", A.Stoic)
    Line("I'm going to leave.", A.Stoic)
    Line("It's best for me to go.", A.Stoic)
    Line("I see no point in continuing. Goodbye.", A.Stoic)

    Line("Team, we'll regroup later. I'm leaving.", A.Teamer)
    Line("I need real competition. This is a joke.", A.Tryhard)
    Line("Pathetic. I'm off to a better game.", A.Tryhard)
    Line("I can't progress with this trash. See you later.", A.Tryhard)
    Line("Waste of my skills. I'm gone.", A.Tryhard)
    Line("It's not worth it. Goodbye losers.", A.Tryhard)


    RegisterCategory("ServerConnected", P.NORMAL)
    Line("I'm back!", A.Default)
    Line("Hi everyone.", A.Default)
    Line("Ready to go.", A.Default)
    Line("I'm here.", A.Default)
    Line("I'm back.", A.Default)
    Line("Happy to be here", A.Default)
    Line("I'm in!", A.Default)
    Line("I'm here!", A.Default)
    Line("I'm back, everyone!", A.Default)
    Line("I'm back, let's do this!", A.Default)
    Line("Let's gooooo", A.Default)
    Line("Hello", A.Default)
    Line("yo im here lol", A.Casual)
    Line("sup everyone", A.Casual)
    Line("hey, just joined in", A.Casual)
    Line("we do a little gaming", A.Casual)
    Line("uhhh hi", A.Dumb)
    Line("this server is definitely not a fastdl", A.Dumb)
    Line("hi", A.Dumb)
    Line("i am in server", A.Dumb)
    Line("i love ttt", A.Dumb)
    Line("Finally, I'm in! Let's do this!", A.Hothead)
    Line("That load time was terrible. Excited to play.", A.Hothead)
    Line("Took a while to get in here", A.Hothead)
    Line("What's up losers", A.Hothead)
    Line("Wsg idiots", A.Hothead)
    Line("Ready to rumble!", A.Hothead)
    Line("I'm here to win!", A.Hothead)
    Line("Happy to be here!", A.Nice)
    Line("Looking forward to this!", A.Nice)
    Line("Hello everyone!!", A.Nice)
    Line("Hey guys, I'm back!", A.Nice)
    Line("I'm here to have fun!", A.Nice)
    Line("I'm back, let's have a good time!", A.Nice)

    -----------------------------------------------------------
    -- TARGET ASSIGNMENT / ATTACK
    -----------------------------------------------------------

    RegisterCategory("DisguisedPlayer", P.IMPORTANT) -- When a bot spots someone with a disguise
    Line("This guy is disguised!", A.Default)
    Line("Seems like someone's playing hide and seek!", A.Default)
    Line("A mystery guest among us, huh?", A.Default)
    Line("disguised dude over here", A.Casual)
    Line("nice mask, buddy", A.Casual)
    Line("playing incognito huh?", A.Casual)
    Line("Why cant i see your name??", A.Bad)
    Line("What are you hiding, sneaky?", A.Bad)
    Line("Not fooling anyone, you know", A.Bad)
    Line("who you", A.Dumb)
    Line("Uhh, where did you go?", A.Dumb)
    Line("Hey, why can't I see your face?", A.Dumb)
    Line("Little baby with the disguiser", A.Hothead)
    Line("Take off that silly disguise!", A.Hothead)
    Line("Stop hiding, coward!", A.Hothead)
    Line("my friend is disguised", A.Sus)
    Line("That disguise is super sus", A.Sus)
    Line("erm what the flip", A.Sus)
    Line("Disguising won't save you", A.Tryhard)
    Line("Disguise or not, I'll find you", A.Tryhard)
    Line("You're not escaping my sight", A.Tryhard)

    RegisterCategory("DeclareSuspicious", P.IMPORTANT) -- When a bot spots {{player}} acting suspicious
    -- Default
    Line("{{player}} is acting suspicious.", A.Default)
    Line("I think {{player}} is up to something.", A.Default)
    Line("{{player}} is acting weird.", A.Default)
    Line("{{player}} is acting strange.", A.Default)
    Line("{{player}} is acting sus.", A.Default)
    Line("{{player}} seems suspicious.", A.Default)
    Line("{{player}} is behaving oddly.", A.Default)
    Line("{{player}} is acting fishy.", A.Default)
    Line("{{player}} is up to something.", A.Default)
    Line("What are you up to, {{player}}?", A.Default)
    Line("Hey {{player}}, why are you acting so weird?", A.Default)

    -- Casual
    Line("Yo, {{player}} is acting kinda sus.", A.Casual)
    Line("Hey, {{player}} is being weird.", A.Casual)
    Line("{{player}} is acting off.", A.Casual)
    Line("{{player}} is acting funny.", A.Casual)
    Line("{{player}} is acting sketchy.", A.Casual)
    Line("{{player}} is looking shady.", A.Casual)
    Line("{{player}} is up to something fishy.", A.Casual)
    Line("{{player}} is doing something weird.", A.Casual)
    Line("What's up, {{player}}? You're acting strange.", A.Casual)
    Line("{{player}}, you're being kinda weird.", A.Casual)

    -- Bad
    Line("{{player}} is acting suspiciously.", A.Bad)
    Line("{{player}} is up to no good.", A.Bad)
    Line("{{player}} is being shady.", A.Bad)
    Line("{{player}} is acting fishy.", A.Bad)
    Line("{{player}} is acting dodgy.", A.Bad)
    Line("{{player}} is plotting something.", A.Bad)
    Line("{{player}} is definitely up to something.", A.Bad)
    Line("{{player}} is acting very suspicious.", A.Bad)
    Line("{{player}}, what are you hiding?", A.Bad)
    Line("{{player}}, you're up to no good.", A.Bad)

    -- Dumb
    Line("Uhh, {{player}} is acting weird.", A.Dumb)
    Line("{{player}} is doing something strange.", A.Dumb)
    Line("{{player}} is acting funny.", A.Dumb)
    Line("{{player}} is being odd.", A.Dumb)
    Line("{{player}} is acting goofy.", A.Dumb)
    Line("{{player}} is behaving strangely.", A.Dumb)
    Line("{{player}} is up to something weird.", A.Dumb)
    Line("{{player}} is acting kinda funny.", A.Dumb)
    Line("Hey {{player}}, why are you acting so weird?", A.Dumb)
    Line("{{player}}, you're being goofy.", A.Dumb)

    -- Hothead
    Line("{{player}} is acting suspicious, idiots!", A.Hothead)
    Line("{{player}} is up to something, morons!", A.Hothead)
    Line("{{player}} is acting weird, fools!", A.Hothead)
    Line("{{player}} is acting strange, losers!", A.Hothead)
    Line("{{player}} is acting sus, jerks!", A.Hothead)
    Line("{{player}} is plotting something, idiots!", A.Hothead)
    Line("{{player}} is definitely up to no good, idiots!", A.Hothead)
    Line("{{player}} is acting very shady, morons!", A.Hothead)
    Line("{{player}}, what the hell are you doing?", A.Hothead)
    Line("{{player}}, stop acting so suspicious!", A.Hothead)

    -- Nice
    Line("{{player}} is acting suspicious, stay safe.", A.Nice)
    Line("I think {{player}} is up to something, be careful.", A.Nice)
    Line("{{player}} is acting weird, watch out.", A.Nice)
    Line("{{player}} is acting strange, be cautious.", A.Nice)
    Line("{{player}} is acting sus, stay alert.", A.Nice)
    Line("{{player}} is behaving oddly, be careful.", A.Nice)
    Line("{{player}} is up to something, stay safe.", A.Nice)
    Line("{{player}} is acting very suspicious, be careful.", A.Nice)
    Line("{{player}}, are you okay? You're acting strange.", A.Nice)
    Line("{{player}}, please be careful. You're acting weird.", A.Nice)

    -- Stoic
    Line("{{player}} is acting suspicious.", A.Stoic)
    Line("I think {{player}} is up to something.", A.Stoic)
    Line("{{player}} is acting weird.", A.Stoic)
    Line("{{player}} is acting strange.", A.Stoic)
    Line("{{player}} is acting sus.", A.Stoic)
    Line("{{player}} is behaving suspiciously.", A.Stoic)
    Line("{{player}} is up to something.", A.Stoic)
    Line("{{player}} is acting very suspicious.", A.Stoic)
    Line("{{player}}, what are you doing?", A.Stoic)
    Line("{{player}}, you're acting strange.", A.Stoic)

    -- Teamer
    Line("{{player}} is acting suspicious, team.", A.Teamer)
    Line("I think {{player}} is up to something, team.", A.Teamer)
    Line("{{player}} is acting weird, team.", A.Teamer)
    Line("{{player}} is acting strange, team.", A.Teamer)
    Line("{{player}} is acting sus, team.", A.Teamer)
    Line("{{player}} is behaving oddly, team.", A.Teamer)
    Line("{{player}} is up to something, team.", A.Teamer)
    Line("{{player}} is acting very suspicious, team.", A.Teamer)
    Line("{{player}}, what are you up to, team?", A.Teamer)
    Line("{{player}}, you're acting strange, team.", A.Teamer)

    -- Tryhard
    Line("{{player}} is acting suspicious, keep an eye out.", A.Tryhard)
    Line("I think {{player}} is up to something, stay sharp.", A.Tryhard)
    Line("{{player}} is acting weird, be vigilant.", A.Tryhard)
    Line("{{player}} is acting strange, stay focused.", A.Tryhard)
    Line("{{player}} is acting sus, be alert.", A.Tryhard)
    Line("{{player}} is behaving suspiciously, stay sharp.", A.Tryhard)
    Line("{{player}} is up to something, stay sharp.", A.Tryhard)
    Line("{{player}} is acting very suspicious, stay focused.", A.Tryhard)
    Line("{{player}}, what are you planning?", A.Tryhard)
    Line("{{player}}, you're acting very suspicious.", A.Tryhard)

    -- Sus/Quirky
    Line("Hey {{player}}, why are you looking at me like that?", A.Sus)
    Line("{{player}}, you seem to be hiding something.", A.Sus)
    Line("I saw {{player}} doing something weird.", A.Sus)
    Line("{{player}}, what are you up to?", A.Sus)
    Line("Why is {{player}} acting so strange?", A.Sus)
    Line("{{player}}, you're not fooling anyone.", A.Sus)
    Line("I think {{player}} is planning something.", A.Sus)
    Line("{{player}}, what's with the sneaky behavior?", A.Sus)
    Line("{{player}}, you're being awfully quiet.", A.Sus)
    Line("{{player}}, why are you acting so weird?", A.Sus)
    Line("there is an imposter among us", A.Sus)

    RegisterCategory("DeclareInnocent", P.IMPORTANT) -- When a bot trusts {{player}}'s innocence
    -- Default
    Line("I trust {{player}}.", A.Default)
    Line("I think {{player}} is innocent.", A.Default)
    Line("I believe {{player}} is innocent.", A.Default)
    Line("I trust {{player}}'s innocence.", A.Default)
    Line("I think {{player}} is a good person.", A.Default)

    -- Casual
    Line("yo {{player}} is cool", A.Casual)
    Line("{{player}} is a good person", A.Casual)
    Line("{{player}} is chill", A.Casual)
    Line("I don't think {{player}} did anything wrong", A.Casual)
    Line("{{player}} seems alright to me", A.Casual)

    -- Bad
    Line("{{player}} is probably innocent", A.Bad)
    Line("I guess {{player}} didn't do it", A.Bad)
    Line("{{player}} seems like they're not guilty", A.Bad)
    Line("I don't think {{player}} is the traitor", A.Bad)
    Line("{{player}} looks innocent enough", A.Bad)

    -- Dumb
    Line("I think {{player}} is good", A.Dumb)
    Line("{{player}} didn't do anything bad", A.Dumb)
    Line("{{player}} is not a bad guy", A.Dumb)
    Line("{{player}} is innocent, right?", A.Dumb)
    Line("{{player}} is a good person, I think", A.Dumb)

    -- Hothead
    Line("{{player}} is innocent, idiots!", A.Hothead)
    Line("Stop accusing {{player}}, they're innocent!", A.Hothead)
    Line("{{player}} didn't do anything, morons!", A.Hothead)
    Line("{{player}} is not guilty, fools!", A.Hothead)
    Line("{{player}} is innocent, get off their back!", A.Hothead)

    -- Nice
    Line("I trust {{player}} completely", A.Nice)
    Line("{{player}} is definitely innocent", A.Nice)
    Line("{{player}} is a good person, no doubt", A.Nice)
    Line("I believe in {{player}}'s innocence", A.Nice)
    Line("{{player}} is trustworthy", A.Nice)

    -- Stoic
    Line("{{player}} is innocent", A.Stoic)
    Line("I believe {{player}} is not guilty", A.Stoic)
    Line("{{player}} did not commit the crime", A.Stoic)
    Line("{{player}} is trustworthy", A.Stoic)
    Line("{{player}} is not the traitor", A.Stoic)

    -- Teamer
    Line("{{player}} is on our side", A.Teamer)
    Line("I trust {{player}}, team", A.Teamer)
    Line("{{player}} is innocent, team", A.Teamer)
    Line("{{player}} is one of us", A.Teamer)
    Line("{{player}} is not the traitor, team", A.Teamer)

    -- Sus/Quirky
    Line("{{player}} seems innocent... for now", A.Sus)
    Line("I think {{player}} is innocent, but who knows?", A.Sus)
    Line("{{player}} is probably not guilty... I guess", A.Sus)
    Line("{{player}} seems like a good person... maybe", A.Sus)
    Line("I trust {{player}}, but let's keep an eye on them", A.Sus)

    -- Tryhard
    Line("{{player}} is definitely innocent, no doubt", A.Tryhard)
    Line("I trust {{player}}'s innocence completely", A.Tryhard)
    Line("{{player}} is not guilty, 100%", A.Tryhard)
    Line("{{player}} is innocent, trust me", A.Tryhard)
    Line("{{player}} is not the traitor, guaranteed", A.Tryhard)

    RegisterCategory("DeclareTrustworthy", P.IMPORTANT) -- When a bot trusts {{player}} but still not 100% on them being innocent
    -- Default
    Line("{{player}} seems trustworthy.", A.Default)
    Line("I think {{player}} may be innocent but not sure yet.", A.Default)
    Line("I trust {{player}} but I'm not 100% sure.", A.Default)
    Line("{{player}} seems like a good person, but I'm not certain.", A.Default)
    Line("I think {{player}} is trustworthy, but I'm not sure.", A.Default)

    -- Casual
    Line("yo, {{player}} seems cool but idk.", A.Casual)
    Line("{{player}} is probably alright, but who knows.", A.Casual)
    Line("{{player}} seems chill, but I'm not totally sure.", A.Casual)
    Line("{{player}} is kinda trustworthy, I guess.", A.Casual)
    Line("{{player}} seems okay, but I'm not 100% on it.", A.Casual)

    -- Bad
    Line("{{player}} might be trustworthy, but I'm skeptical.", A.Bad)
    Line("I think {{player}} is innocent, but I have my doubts.", A.Bad)
    Line("{{player}} seems alright, but I'm not convinced.", A.Bad)
    Line("{{player}} is probably trustworthy, but I'm not sure.", A.Bad)
    Line("I trust {{player}}, but not completely.", A.Bad)

    -- Dumb
    Line("I think {{player}} is good, but I'm not sure.", A.Dumb)
    Line("{{player}} seems nice, but who knows?", A.Dumb)
    Line("{{player}} is probably trustworthy, but I'm not certain.", A.Dumb)
    Line("I trust {{player}}, but I'm not 100% sure.", A.Dumb)
    Line("{{player}} seems okay, but I'm not sure.", A.Dumb)

    -- Hothead
    Line("{{player}} seems trustworthy, but don't mess it up!", A.Hothead)
    Line("I think {{player}} is innocent, but I'm watching you!", A.Hothead)
    Line("{{player}} seems alright, but don't screw it up!", A.Hothead)
    Line("{{player}} is probably trustworthy, but I'm not sure.", A.Hothead)
    Line("I trust {{player}}, but don't make me regret it!", A.Hothead)

    -- Nice
    Line("{{player}} seems trustworthy, but let's be careful.", A.Nice)
    Line("I think {{player}} is innocent, but let's stay cautious.", A.Nice)
    Line("{{player}} seems like a good person, but let's be sure.", A.Nice)
    Line("{{player}} is probably trustworthy, but let's keep an eye out.", A.Nice)
    Line("I trust {{player}}, but let's be careful.", A.Nice)

    -- Stoic
    Line("{{player}} seems trustworthy.", A.Stoic)
    Line("I think {{player}} may be innocent, but not sure yet.", A.Stoic)
    Line("I trust {{player}}, but I'm not 100% sure.", A.Stoic)
    Line("{{player}} seems like a good person, but I'm not certain.", A.Stoic)
    Line("I think {{player}} is trustworthy, but I'm not sure.", A.Stoic)

    -- Teamer
    Line("{{player}} seems trustworthy, team.", A.Teamer)
    Line("I think {{player}} may be innocent, team, but not sure yet.", A.Teamer)
    Line("I trust {{player}}, team, but I'm not 100% sure.", A.Teamer)
    Line("{{player}} seems like a good person, team, but I'm not certain.", A.Teamer)
    Line("I think {{player}} is trustworthy, team, but I'm not sure.", A.Teamer)

    -- Sus/Quirky
    Line("{{player}} seems trustworthy... for now.", A.Sus)
    Line("I think {{player}} is innocent, but who knows?", A.Sus)
    Line("{{player}} seems like a good person... maybe.", A.Sus)
    Line("I trust {{player}}, but let's keep an eye on them.", A.Sus)
    Line("{{player}} is probably trustworthy, but I'm not sure.", A.Sus)

    -- Tryhard
    Line("{{player}} seems trustworthy, but stay sharp.", A.Tryhard)
    Line("I think {{player}} is innocent, but let's be vigilant.", A.Tryhard)
    Line("{{player}} seems like a good person, but let's stay focused.", A.Tryhard)
    Line("{{player}} is probably trustworthy, but let's be sure.", A.Tryhard)
    Line("I trust {{player}}, but let's not let our guard down.", A.Tryhard)

    --- Report witnessing an attacker murder a victim
    RegisterCategory("Kill", P.CRITICAL)
    Line("{{attacker}} killed {{victim}}!", A.Default)
    Line("I saw {{attacker}} murder {{victim}}!", A.Default)
    Line("{{attacker}} murdered {{victim}}!", A.Default)
    Line("{{attacker}} is a murderer!", A.Default)
    Line("{{attacker}} took out {{victim}}!", A.Default)
    Line("{{victim}} was just killed by {{attacker}}!", A.Default)
    Line("{{victim}} got murdered by {{attacker}}!", A.Default)
    Line("{{attacker}} just ended {{victim}}!", A.Default)
    Line("{{victim}} is dead because of {{attacker}}!", A.Default)
    Line("{{attacker}} just took down {{victim}}!", A.Default)

    Line("yo, {{attacker}} killed {{victim}}", A.Casual)
    Line("{{attacker}} murked {{victim}}", A.Casual)
    Line("{{attacker}} offed {{victim}}", A.Casual)
    Line("{{attacker}} whacked {{victim}}", A.Casual)
    Line("{{attacker}} iced {{victim}}", A.Casual)
    Line("{{victim}} just got murked by {{attacker}}", A.Casual)
    Line("{{victim}} got offed by {{attacker}}", A.Casual)
    Line("{{attacker}} just smoked {{victim}}", A.Casual)
    Line("{{victim}} got whacked by {{attacker}}", A.Casual)
    Line("{{attacker}} just dropped {{victim}}", A.Casual)

    Line("{{attacker}} killed {{victim}}, what a jerk!", A.Bad)
    Line("{{attacker}} murdered {{victim}}, unbelievable!", A.Bad)
    Line("{{attacker}} took out {{victim}}, disgusting!", A.Bad)
    Line("{{attacker}} offed {{victim}}, pathetic!", A.Bad)
    Line("{{attacker}} eliminated {{victim}}, despicable!", A.Bad)
    Line("{{victim}} was killed by {{attacker}}, how awful!", A.Bad)
    Line("{{victim}} got murdered by {{attacker}}, so cruel!", A.Bad)
    Line("{{attacker}} just took out {{victim}}, so heartless!", A.Bad)
    Line("{{victim}} was offed by {{attacker}}, so brutal!", A.Bad)
    Line("{{attacker}} just eliminated {{victim}}, so vicious!", A.Bad)

    Line("uhh, {{attacker}} killed {{victim}}", A.Dumb)
    Line("{{attacker}} made {{victim}} go bye-bye", A.Dumb)
    Line("{{attacker}} ended {{victim}}", A.Dumb)
    Line("{{attacker}} made {{victim}} disappear", A.Dumb)
    Line("{{attacker}} sent {{victim}} to sleep", A.Dumb)
    Line("{{victim}} just got killed by {{attacker}}, oops", A.Dumb)
    Line("{{victim}} was offed by {{attacker}}, uh-oh", A.Dumb)
    Line("{{attacker}} just eliminated {{victim}}, whoops", A.Dumb)
    Line("{{victim}} got ended by {{attacker}}, oh no", A.Dumb)
    Line("{{attacker}} just murdered {{victim}}, yikes", A.Dumb)

    Line("{{attacker}}, that idiot, killed {{victim}}!", A.Hothead)
    Line("{{attacker}}, that fool, took out {{victim}}!", A.Hothead)
    Line("{{attacker}}, that loser, offed {{victim}}!", A.Hothead)
    Line("{{attacker}}, that jerk, eliminated {{victim}}!", A.Hothead)
    Line("{{victim}}, that idiot, got killed by {{attacker}}!", A.Hothead)
    Line("{{victim}}, that moron, got murdered by {{attacker}}!", A.Hothead)
    Line("{{attacker}}, that fool, just took out {{victim}}!", A.Hothead)
    Line("{{victim}}, that loser, was offed by {{attacker}}!", A.Hothead)
    Line("{{attacker}}, that jerk, just eliminated {{victim}}!", A.Hothead)

    Line("{{attacker}} killed {{victim}}, stay safe!", A.Nice)
    Line("{{attacker}} murdered {{victim}}, be careful!", A.Nice)
    Line("{{attacker}} took out {{victim}}, watch out!", A.Nice)
    Line("{{attacker}} offed {{victim}}, stay alert!", A.Nice)
    Line("{{attacker}} eliminated {{victim}}, be cautious!", A.Nice)
    Line("{{victim}} was killed by {{attacker}}, stay vigilant!", A.Nice)
    Line("{{victim}} got murdered by {{attacker}}, be on guard!", A.Nice)
    Line("{{attacker}} just took out {{victim}}, be watchful!", A.Nice)
    Line("{{victim}} was offed by {{attacker}}, stay aware!", A.Nice)
    Line("{{attacker}} just eliminated {{victim}}, be careful out there!", A.Nice)

    Line("{{attacker}} killed {{victim}}.", A.Stoic)
    Line("{{attacker}} murdered {{victim}}.", A.Stoic)
    Line("{{attacker}} took out {{victim}}.", A.Stoic)
    Line("{{attacker}} offed {{victim}}.", A.Stoic)
    Line("{{attacker}} eliminated {{victim}}.", A.Stoic)
    Line("{{victim}} was killed by {{attacker}}.", A.Stoic)
    Line("{{victim}} got murdered by {{attacker}}.", A.Stoic)
    Line("{{attacker}} just ended {{victim}}.", A.Stoic)
    Line("{{victim}} was offed by {{attacker}}.", A.Stoic)
    Line("{{attacker}} just took down {{victim}}.", A.Stoic)

    Line("{{attacker}} killed {{victim}}, team.", A.Teamer)
    Line("{{attacker}} murdered {{victim}}, team.", A.Teamer)
    Line("{{attacker}} took out {{victim}}, team.", A.Teamer)
    Line("{{attacker}} offed {{victim}}, team.", A.Teamer)
    Line("{{attacker}} eliminated {{victim}}, team.", A.Teamer)
    Line("{{victim}} was killed by {{attacker}}, team.", A.Teamer)
    Line("{{victim}} got murdered by {{attacker}}, team.", A.Teamer)
    Line("{{attacker}} just ended {{victim}}, team.", A.Teamer)
    Line("{{victim}} was offed by {{attacker}}, team.", A.Teamer)
    Line("{{attacker}} just took down {{victim}}, team.", A.Teamer)

    Line("{{attacker}} killed {{victim}}, stay sharp.", A.Tryhard)
    Line("{{attacker}} murdered {{victim}}, stay focused.", A.Tryhard)
    Line("{{attacker}} took out {{victim}}, be vigilant.", A.Tryhard)
    Line("{{attacker}} offed {{victim}}, stay alert.", A.Tryhard)
    Line("{{attacker}} eliminated {{victim}}, be ready.", A.Tryhard)
    Line("{{victim}} was killed by {{attacker}}, stay prepared.", A.Tryhard)
    Line("{{victim}} got murdered by {{attacker}}, stay on guard.", A.Tryhard)
    Line("{{attacker}} just took out {{victim}}, stay aware.", A.Tryhard)
    Line("{{victim}} was offed by {{attacker}}, stay cautious.", A.Tryhard)
    Line("{{attacker}} just dispatched {{victim}}, stay vigilant.", A.Tryhard)

        --- Respond affirmatively to a request to follow the player, named {target}
    RegisterCategory("FollowMe", P.NORMAL)
    Line("I'll follow {{target}}.", A.Default)
    Line("Sure {{target}}, I'll follow you.", A.Default)
    Line("I'll stick with you, {{target}}.", A.Default)
    Line("I'll follow you, {{target}}.", A.Default)
    Line("Right behind you, {{target}}.", A.Default)
    Line("Let's go, {{target}}.", A.Default)
    Line("I'm with you, {{target}}.", A.Default)
    Line("Following your lead, {{target}}.", A.Default)
    Line("You got it, {{target}}.", A.Default)
    Line("I'm on your six, {{target}}.", A.Default)
    Line("Lead the way, {{target}}.", A.Default)
    Line("I'll be your shadow, {{target}}.", A.Default)
    Line("I'm right here, {{target}}.", A.Default)
    Line("Let's move, {{target}}.", A.Default)
    Line("I'm coming with you, {{target}}.", A.Default)
    
    Line("sure bro, i'll follow you", A.Casual)
    Line("yeah, i'll follow you", A.Casual)
    Line("i'll stick with you", A.Casual)
    Line("i'll follow you", A.Casual)
    Line("right behind you {{target}}", A.Casual)
    Line("let's go {{target}}", A.Casual)
    Line("i'm with you {{target}}", A.Casual)
    Line("following your lead {{target}}", A.Casual)
    Line("you got it {{target}}", A.Casual)
    Line("i'm on your six {{target}}", A.Casual)
    Line("lead the way {{target}}", A.Casual)

    Line("Oh, fine. I'll follow you, {{target}}", A.Bad)
    Line("I guess I'll follow you, {{target}}", A.Bad)
    Line("Sounds boring, but I'll follow you, {{target}}", A.Bad)
    Line("I'll follow you, {{target}}, but I'm not happy about it", A.Bad)
    Line("You better not get me killed, {{target}}", A.Bad)
    Line("Okay sure but I don't trust you, {{target}}", A.Bad)

    Line("hang on one second let me figure out how to move", A.Dumb)
    Line("oops i spilled my drink one second ill follow you", A.Dumb)
    Line("we can be friends forever! i'll follow you", A.Dumb)
    Line("you are my best friend i'll follow you", A.Dumb)
    Line("okay friend i'll follow you", A.Dumb)

    Line("I'll follow you, {{target}}, but don't get me killed", A.Hothead)
    Line("Alright bitch, I'll follow you", A.Hothead)
    Line("Fucking hell fine then, this better not waste my time", A.Hothead)
    Line("For fucks sake okay then {{target}}", A.Hothead)
    Line("Okay shithead, sorry I meant {{target}}", A.Hothead)

    Line("Yeah man sounds good, you're trustworthy!", A.Nice)
    Line("Sure thing, {{target}}!", A.Nice)
    Line("I'll follow you, {{target}}. Let's go!", A.Nice)
    Line("Absolutely, {{target}}. Right behind you!", A.Nice)
    Line("Of course, {{target}}. Lead the way!", A.Nice)
    Line("You got it, {{target}}. Let's move!", A.Nice)

    -- Stoic
    Line("I'll follow you, {{target}}.", A.Stoic)
    Line("Following you, {{target}}.", A.Stoic)
    Line("I'm with you, {{target}}.", A.Stoic)
    Line("I'll stick with you, {{target}}.", A.Stoic)
    Line("Right behind you, {{target}}.", A.Stoic)

    -- Teamer
    Line("Let's team up, {{target}}. I'll follow you.", A.Teamer)
    Line("I'm teaming up with you, {{target}}.", A.Teamer)
    Line("Together as a team, {{target}}. I'm with you.", A.Teamer)
    Line("I'll be your teammate, {{target}}. Let's stick together.", A.Teamer)
    Line("Right behind you, {{target}}. Let's work as a team.", A.Teamer)

    -- Sus/Quirky
    Line("I'll follow you, {{target}}, but don't ask about my past.", A.Sus)
    Line("Just ignore the rumors, {{target}}, I'm following you.", A.Sus)
    Line("I'm with you, {{target}}, but don't ask too many questions.", A.Sus)
    Line("I have my secrets, {{target}}, but I'll stick with you.", A.Sus)
    Line("Right behind you, {{target}}, just don't look in my bag.", A.Sus)
    Line("I'll follow you, but don't tell anyone, {{target}}.", A.Sus)
    Line("Following you, but I might disappear suddenly, {{target}}.", A.Sus)
    Line("I have my own agenda, {{target}}, but I'm with you.", A.Sus)
    Line("I'll stick with you, but I can't explain everything, {{target}}.", A.Sus)
    Line("Don't ask about my past, {{target}}, I'm right behind you.", A.Sus)
    Line("Keep it quiet, {{target}}, I'll follow you.", A.Sus)
    Line("I have some unfinished business, but I'm following you, {{target}}.", A.Sus)
    Line("I might need to leave quickly, {{target}}, but I'm with you.", A.Sus)
    Line("Don't pry into my affairs, {{target}}, but I'll stick with you.", A.Sus)
    Line("Don't ask why, {{target}}, I'm right behind you.", A.Sus)
    Line("I have my reasons, {{target}}, but I'll follow you.", A.Sus)
    Line("I can't promise I'll stay, {{target}}, but I'm following you.", A.Sus)
    Line("I have my own plans, {{target}}, but I'm with you.", A.Sus)
    Line("Don't expect answers, {{target}}, but I'll stick with you.", A.Sus)
    Line("Don't ask too much, {{target}}, I'm right behind you.", A.Sus)
    Line("I have my own secrets, {{target}}, but I'll follow you.", A.Sus)
    Line("I might vanish, {{target}}, but I'm following you.", A.Sus)
    Line("I have my own goals, {{target}}, but I'm with you.", A.Sus)
    Line("Don't question me, {{target}}, but I'll stick with you.", A.Sus)
    Line("Don't get too close, {{target}}, I'm right behind you.", A.Sus)

    -- Tryhard
    Line("I'll follow you, {{target}}, let's do this.", A.Tryhard)
    Line("Following you, {{target}}, stay sharp.", A.Tryhard)
    Line("I'm with you, {{target}}, let's be efficient.", A.Tryhard)
    Line("I'll stick with you, {{target}}, no mistakes.", A.Tryhard)
    Line("Right behind you, {{target}}, let's execute the plan.", A.Tryhard)

    RegisterCategory("FollowMeRefuse", P.IMPORTANT) -- When a bot refuses to follow the player, named {target}, mostly due to suspicion
    -- Default
    Line("I can't follow you, {{target}}.", A.Default)
    Line("I'm not following you, {{target}}.", A.Default)
    Line("I'm going my own way, {{target}}.", A.Default)
    Line("I'm not following you, {{target}}. I don't trust you.", A.Default)
    Line("I'm not following you, {{target}}. I have my own plans.", A.Default)

    -- Casual
    Line("nah bro, i'm good", A.Casual)
    Line("i'm good, thanks", A.Casual)
    Line("i'm going my own way", A.Casual)
    Line("i'm not following you", A.Casual)
    Line("bad vibes, i'm out", A.Casual)

    -- Bad
    Line("Sorry mate, wrong path.", A.Bad)
    Line("Nah, I'm not following you.", A.Bad)
    Line("Nope, I'm going my own way.", A.Bad)
    Line("You smell {{target}}, I'm out.", A.Bad)
    Line("Why would I follow you, {{target}}?", A.Bad)

    -- Dumb
    Line("I'm lost, {{target}}. I can't follow you.", A.Dumb)
    Line("I'm not sure where I'm going, {{target}}.", A.Dumb)
    Line("I think I need to go somewhere else, {{target}}.", A.Dumb)
    Line("Oh, sorry what? I can't follow you, {{target}}.", A.Dumb)
    Line("Can you repeat that {{target}} I didn't hear you.", A.Dumb)

    -- Hothead
    Line("Don't ask me to follow you, {{target}}!", A.Hothead)
    Line("I'm not following you, {{target}}! Get lost!", A.Hothead)
    Line("I'm not following you, {{target}}! You're a joke!", A.Hothead)
    Line("Never! I'm not following you, {{target}}!", A.Hothead)
    Line("Why would I follow you, {{target}}? You're a loser!", A.Hothead)
    Line("I don't like you, {{target}}. I'm not following you!", A.Hothead)

    -- Nice
    Line("I'm going my own way, {{target}}. Sorry.", A.Nice)
    Line("Hi {{target}}, I'm not following you. Sorry.", A.Nice)
    Line("I'm sure you're great, {{target}}, but I'm not following you.", A.Nice)
    Line("I like you but not enough to follow you, {{target}}.", A.Nice)
    Line("I'm not following you, {{target}}. I'm sure you understand.", A.Nice)

    -- Stoic
    Line("I can't follow you, {{target}}.", A.Stoic)
    Line("My personal path diverges from yours, {{target}}.", A.Stoic)
    Line("I think It's wiser if I go my own way, {{target}}.", A.Stoic)
    Line("Our paths don't align, {{target}}.", A.Stoic)
    Line("I'm not following you, {{target}}. It's nothing personal.", A.Stoic)

    -- Teamer
    Line("I'm not following you, {{target}}. I'll stick with the team.", A.Teamer)
    Line("As much as I'd like to, I can't follow you, {{target}}.", A.Teamer)
    Line("I have to stay with the team, {{target}}. I can't follow you.", A.Teamer)
    Line("Sorry but my duty lies with others, {{target}}. I can't follow you.", A.Teamer)
    Line("I'm not following you, {{target}}. I have to stay with the team.", A.Teamer)

    -- Sus/Quirky
    Line("I can't follow you, {{target}}, you're not on my team.", A.Sus)
    Line("I'm not following you, {{target}}, I have my own agenda.", A.Sus)
    Line("I have my own path to follow, {{target}}, I can't follow you.", A.Sus)
    Line("I'm not following you, {{target}}, I have my own secrets.", A.Sus)
    Line("No can do, {{target}}, I have my own reasons.", A.Sus)

    -- Tryhard
    Line("I can't follow you, {{target}}. I have my own mission.", A.Tryhard)
    Line("I'm not following you, {{target}}. I have my own objectives.", A.Tryhard)
    Line("I have my own goals, {{target}}, and you're not part of them.", A.Tryhard)
    Line("I'm not following you, {{target}}. I have my own plans.", A.Tryhard)
    Line("I can't follow you, {{target}}. I have my own strategy.", A.Tryhard)


    RegisterCategory("FollowMeEnd", P.NORMAL)
    Line("I'm done following you.", A.Default)
    Line("I'm going my own way now.", A.Default)
    Line("I'm not following you anymore.", A.Default)
    Line("I'm done following you, {{target}}.", A.Default)
    Line("I'm going my own way now, {{target}}.", A.Default)
    Line("That's it for me, {{target}}.", A.Default)
    Line("I'm heading off on my own.", A.Default)
    Line("I'm breaking off now.", A.Default)
    Line("I'm going solo from here.", A.Default)
    Line("I'm done tagging along.", A.Default)
    Line("I'm on my own now.", A.Default)
    Line("I'm splitting off, {{target}}.", A.Default)
    Line("I'm going my separate way.", A.Default)
    Line("I'm done here, {{target}}.", A.Default)
    Line("I'm off on my own.", A.Default)
    Line("I'm leaving now, {{target}}.", A.Default)
    Line("I'm done with this.", A.Default)
    Line("I'm heading out.", A.Default)
    Line("I'm going my own way.", A.Default)
    Line("I'm done following.", A.Default)
    Line("I'm out of here.", A.Default)
    Line("I'm done sticking around.", A.Default)
    Line("I'm going my own path.", A.Default)
    Line("I'm done with you, {{target}}.", A.Default)
    Line("I'm off on my own path.", A.Default)

    Line("i'm done following you", A.Casual)
    Line("i'm going my own way now", A.Casual)
    Line("i'm not following you anymore", A.Casual)
    Line("i'm done following you, {{target}}", A.Casual)
    Line("i'm going my own way now, {{target}}", A.Casual)
    Line("i'm heading out on my own", A.Casual)
    Line("i'm splitting off now", A.Casual)
    Line("i'm going solo from here", A.Casual)
    Line("i'm done tagging along", A.Casual)
    Line("i'm off on my own now", A.Casual)
    Line("i'm done here", A.Casual)
    Line("i'm going my own way", A.Casual)
    Line("i'm leaving now", A.Casual)
    Line("i'm done with this", A.Casual)
    Line("i'm heading out", A.Casual)
    Line("i'm going my own path", A.Casual)
    Line("i'm done sticking around", A.Casual)
    Line("i'm out of here", A.Casual)
    Line("i'm done following", A.Casual)
    Line("i'm going my separate way", A.Casual)
    Line("i'm done with you, {{target}}", A.Casual)
    Line("i'm off on my own path", A.Casual)
    Line("i'm breaking off now", A.Casual)
    Line("i'm done tagging along, {{target}}", A.Casual)
    Line("i'm heading off on my own", A.Casual)

    -- Bad
    Line("I'm done following you, {{target}}.", A.Bad)
    Line("I can't follow you anymore, {{target}}.", A.Bad)
    Line("I'm going my own way, {{target}}.", A.Bad)
    Line("I don't trust you, {{target}}. I'm out.", A.Bad)
    Line("Following you was a mistake, {{target}}.", A.Bad)

    -- Dumb
    Line("I forgot why I was following you, {{target}}.", A.Dumb)
    Line("Wait, where are we going, {{target}}?", A.Dumb)
    Line("I think I need to go somewhere else, {{target}}.", A.Dumb)
    Line("Oops, I need to stop following you, {{target}}.", A.Dumb)
    Line("I got lost, {{target}}. I'm going my own way.", A.Dumb)

    -- Hothead
    Line("I'm done with you, {{target}}!", A.Hothead)
    Line("I can't stand following you anymore, {{target}}!", A.Hothead)
    Line("You're wasting my time, {{target}}. I'm out!", A.Hothead)
    Line("Enough of this, {{target}}. I'm going my own way!", A.Hothead)
    Line("I'm done following you, {{target}}. Don't bother me again!", A.Hothead)

    -- Nice
    Line("I'm going to go my own way now, {{target}}.", A.Nice)
    Line("Thanks for the company, {{target}}. I'm heading off.", A.Nice)
    Line("It was nice following you, {{target}}. See you around.", A.Nice)
    Line("I'm done following you for now, {{target}}. Take care!", A.Nice)
    Line("I'm going my own way now, {{target}}. Stay safe!", A.Nice)

    -- Stoic
    Line("I'm done following you.", A.Stoic)
    Line("I'm going my own way now.", A.Stoic)
    Line("I will no longer follow you.", A.Stoic)
    Line("I am going my own way now.", A.Stoic)
    Line("I will proceed alone.", A.Stoic)

    -- Teamer
    Line("I'm done following you, team.", A.Teamer)
    Line("I'm going my own way now, team.", A.Teamer)
    Line("I won't follow you anymore, team.", A.Teamer)
    Line("I'm done following you, {{target}}, team.", A.Teamer)
    Line("I'm going my own way now, {{target}}, team.", A.Teamer)

    -- Sus/Quirky
    Line("I'm done following you, {{target}}. This better be good.", A.Sus)
    Line("I think I'll go my own way now, {{target}}.", A.Sus)
    Line("I'm not following you anymore, {{target}}. Something's off.", A.Sus)
    Line("I'm done following you, {{target}}. Don't mess up.", A.Sus)
    Line("I'm going my own way now, {{target}}. Let's see what happens.", A.Sus)

    -- Tryhard
    Line("I'm done following you, {{target}}. Let's stay sharp.", A.Tryhard)
    Line("I'm going my own way now, {{target}}. Stay focused.", A.Tryhard)
    Line("I won't follow you anymore, {{target}}. Be vigilant.", A.Tryhard)
    Line("I'm done following you, {{target}}. No mistakes.", A.Tryhard)
    Line("I'm going my own way now, {{target}}. Let's execute the plan.", A.Tryhard)

    --- Respond affirmatively (so Yes) to a request to wait (or stand still) for the player, named {target}, vary sentence structure massively
    RegisterCategory("WaitStart", P.NORMAL)
    Line("I'll wait for you, {{target}}.", A.Default)
    Line("I'll stand still, {{target}}.", A.Default)
    Line("I'll hold position, {{target}}.", A.Default)
    Line("Sure {{target}}, I'll wait.", A.Default)
    Line("I'll stay put, {{target}}.", A.Default)
    Line("{{target}}, I'll wait for you.", A.Default)
    Line("No Problem, {{target}}, I'll wait.", A.Default)
    Line("I'll be here, {{target}}.", A.Default)
    Line("I'll wait for you, {{target}}, no problem.", A.Default)
    Line("Yes, {{target}}, I'll wait.", A.Default)

    Line("sure bro, i'll wait for you", A.Casual)
    Line("yeah, i'll stand still for you", A.Casual)
    Line("coolio i'll wait for you", A.Casual)
    Line("sure man whatever i'll wait", A.Casual)
    Line("okay i'll hold position", A.Casual)
    Line("i'll be here waiting for you", A.Casual)
    Line("i'll wait for you, no problem", A.Casual)

    Line("I'll wait for you, {{target}}, but I'm not happy about it", A.Bad)
    Line("I guess I'll wait for you, {{target}}", A.Bad)
    Line("Sounds boring, but I'll wait for you, {{target}}", A.Bad)
    Line("You better not get me killed, {{target}}", A.Bad)
    Line("Okay sure but I don't trust you, {{target}}", A.Bad)

    Line("hang on one second let me figure out how to stand still", A.Dumb)
    Line("oops i spilled my drink one second ill wait for you", A.Dumb)
    Line("we can be friends forever! i'll wait for you", A.Dumb)
    Line("you are my best friend i'll wait for you", A.Dumb)
    Line("okay friend i'll wait for you", A.Dumb)

    Line("I'll wait for you, {{target}}, but don't mess it up!", A.Hothead)
    Line("I think I'll wait for you, {{target}}, but I'm watching you!", A.Hothead)
    Line("I'll wait for you, {{target}}, but don't screw it up!", A.Hothead)
    Line("For fucks sake okay then {{target}}", A.Hothead)
    Line("Okay shithead, sorry I meant {{target}}", A.Hothead)
    Line("I'll wait for you, {{target}}, but don't make me regret it!", A.Hothead)

    --- Nice
    Line("I'll wait for you, {{target}}. Take your time.", A.Nice)
    Line("I'll wait for you, {{target}}. No rush.", A.Nice)
    Line("Of Course, {{target}}, I'll wait.", A.Nice)
    Line("Absolutely {{target}}, I'll wait.", A.Nice)
    Line("Yes, {{target}}, I'll wait.", A.Nice)
    Line("I'll wait for you, {{target}}. I'm patient.", A.Nice)
    Line("I'll wait for you, {{target}}. I'm not in a hurry.", A.Nice)
    Line("I'll wait for you, {{target}}. I'm not going anywhere.", A.Nice)

    -- Stoic
    Line("I'll wait for you, {{target}}.", A.Stoic)
    Line("I'll stand still, {{target}}.", A.Stoic)
    Line("I'll hold position, {{target}}.", A.Stoic)
    Line("Sure {{target}}, I'll wait.", A.Stoic)
    Line("I'll stay put, {{target}}.", A.Stoic)
    Line("{{target}}, I'll wait for you.", A.Stoic)
    Line("No Problem, {{target}}, I'll wait.", A.Stoic)

    -- Teamer
    Line("Okay sure, I trust you, {{target}}. I'll wait.", A.Teamer)
    Line("Sure thing, we should stick together, {{target}}. I'll wait.", A.Teamer)
    Line("I'll wait for you, {{target}}", A.Teamer)
    Line("I'll stand still, {{target}}. I trust you.", A.Teamer)
    Line("I'll hold position, {{target}}. I'm with you.", A.Teamer)
    Line("Sure {{target}}, I'll wait. Let's stick together.", A.Teamer)

    -- Sus/Quirky
    Line("I'll wait for you, {{target}}, but don't ask about my past.", A.Sus)
    Line("Just ignore the rumors, {{target}}, I'm waiting.", A.Sus)
    Line("I'm with you, {{target}}, but don't ask too many questions.", A.Sus)
    Line("I have my secrets, {{target}}, but I'll wait.", A.Sus)
    Line("Right behind you, {{target}}, just don't look in my bag.", A.Sus)
    Line("I'll wait for you, but don't tell anyone, {{target}}.", A.Sus)

    -- Tryhard
    Line("I'll wait for you, {{target}}, let's do this.", A.Tryhard)
    Line("I'm with you, {{target}}, let's be efficient.", A.Tryhard)
    Line("I'll hold position, {{target}}, no mistakes.", A.Tryhard)
    Line("Right behind you, {{target}}, let's execute the plan.", A.Tryhard)
    Line("I'll wait for you, {{target}}, stay sharp.", A.Tryhard)

    --- Refuse to wait for the player, named {target}, vary sentence structure massively
    RegisterCategory("WaitRefuse", P.IMPORTANT)
    Line("I can't wait for you, {{target}}.", A.Default)
    Line("I'm not waiting for you, {{target}}.", A.Default)
    Line("I'm going my own way, {{target}}.", A.Default)
    Line("I'm not waiting for you, {{target}}. I don't trust you.", A.Default)
    Line("I'm not waiting for you, {{target}}. I have my own plans.", A.Default)

    Line("nah bro, i'm good", A.Casual)
    Line("i'm good, thanks", A.Casual)
    Line("i'm going my own way", A.Casual)
    Line("i'm not waiting for you", A.Casual)
    Line("bad vibes, i'm out", A.Casual)

    Line("Sorry mate, wrong path.", A.Bad)
    Line("Nah, I'm not waiting for you.", A.Bad)
    Line("Nope, I'm going my own way.", A.Bad)
    Line("You smell {{target}}, I'm out.", A.Bad)
    Line("Why would I wait for you, {{target}}?", A.Bad)

    Line("I'm lost, {{target}}. I can't wait for you.", A.Dumb)
    Line("I'm not sure where I'm going, {{target}}.", A.Dumb)
    Line("I think I need to go somewhere else, {{target}}.", A.Dumb)
    Line("Oh, sorry what? I can't wait for you, {{target}}.", A.Dumb)
    Line("Can you repeat that {{target}} I didn't hear you.", A.Dumb)

    Line("Don't ask me to wait for you, {{target}}!", A.Hothead)
    Line("I'm not waiting for you, {{target}}! Get lost!", A.Hothead)
    Line("I'm not waiting for you, {{target}}! You're a joke!", A.Hothead)
    Line("Never! I'm not waiting for you, {{target}}!", A.Hothead)
    Line("Why would I wait for you, {{target}}? You're a loser!", A.Hothead)
    Line("I don't like you, {{target}}. I'm not waiting for you!", A.Hothead)

    Line("I'm going my own way, {{target}}. Sorry.", A.Nice)
    Line("Hi {{target}}, I'm not waiting for you. Sorry.", A.Nice)
    Line("I'm sure you're great, {{target}}, but I'm not waiting for you.", A.Nice)
    Line("I like you but not enough to wait for you, {{target}}.", A.Nice)
    Line("I'm not waiting for you, {{target}}. I'm sure you understand.", A.Nice)

    -- Stoic
    Line("I can't wait for you, {{target}}.", A.Stoic)
    Line("My personal path diverges from yours, {{target}}.", A.Stoic)
    Line("My code of ethics prevents me from waiting for you, {{target}}.", A.Stoic)
    Line("Our paths don't align, {{target}}.", A.Stoic)
    Line("I'm not waiting for you, {{target}}. It's nothing personal.", A.Stoic)

    -- Teamer
    Line("I'm with my buddies, {{target}}. I can't wait for you.", A.Teamer)
    Line("I'm not waiting for you, {{target}}. I have to stay with the team.", A.Teamer)
    Line("As much as I'd like to, I can't wait for you, {{target}}.", A.Teamer)
    Line("I have to stay with the team, {{target}}. I can't wait for you.", A.Teamer)
    Line("Sorry but my duty lies with others, {{target}}. I can't wait for you.", A.Teamer)

    -- Sus/Quirky
    Line("I can't wait for you, {{target}}, you're not on my team.", A.Sus)
    Line("I'm not waiting for you, {{target}}, I have my own agenda.", A.Sus)
    Line("I have my own path to follow, {{target}}, I can't wait for you.", A.Sus)
    Line("I'm not waiting for you, {{target}}, I have my own secrets.", A.Sus)

    -- Tryhard
    Line("I can't wait for you, {{target}}. I have my own mission.", A.Tryhard)
    Line("I'm not waiting for you, {{target}}. I have my own objectives.", A.Tryhard)
    Line("I have my own goals, {{target}}, and you're not part of them.", A.Tryhard)
    Line("I'm not waiting for you, {{target}}. I have my own plans.", A.Tryhard)
    Line("I can't wait for you, {{target}}. I have my own strategy.", A.Tryhard)

    RegisterCategory("WaitEnd", P.NORMAL)
    Line("I'm done waiting.", A.Default)
    Line("I'm moving now.", A.Default)
    Line("I'm not waiting anymore.", A.Default)
    Line("I'm done waiting, {{target}}.", A.Default)
    Line("I'm moving now, {{target}}.", A.Default)
    Line("That's it for me, {{target}}.", A.Default)
    Line("I'm heading off now.", A.Default)
    Line("I'm breaking off now.", A.Default)
    Line("I'm going solo from here.", A.Default)
    Line("I'm done waiting.", A.Default)

    Line("i'm done waiting", A.Casual)
    Line("i'm moving now", A.Casual)
    Line("okay i'm done waiting", A.Casual)
    Line("bro i'm moving now", A.Casual)
    Line("i'm heading off now", A.Casual)

    Line("Where did you go {{target}}? I'm done waiting.", A.Bad)
    Line("I'm done waiting, {{target}}. You're wasting my time.", A.Bad)
    Line("I'm moving now, {{target}}. You took too long.", A.Bad)
    Line("I'm not waiting anymore, {{target}}. You missed your chance.", A.Bad)
    Line("I'm done waiting, {{target}}. You're too slow.", A.Bad)

    Line("I forgot why I was waiting, {{target}}. I'm moving now.", A.Dumb)
    Line("Wait, where are we going, {{target}}? I'm done waiting.", A.Dumb)
    Line("I think I need to go somewhere else, {{target}}. I'm moving now.", A.Dumb)
    Line("Oops, I need to stop waiting, {{target}}. I'm moving now.", A.Dumb)
    Line("I got lost, {{target}}. I'm going my own way.", A.Dumb)

    Line("I'm done waiting, {{target}}! You're wasting my time.", A.Hothead)
    Line("I can't stand waiting anymore, {{target}}! I'm moving now.", A.Hothead)
    Line("You're too slow, {{target}}! I'm done waiting.", A.Hothead)
    Line("Enough of this, {{target}}! I'm going my own way!", A.Hothead)
    Line("I'm done waiting, {{target}}! Don't bother me again!", A.Hothead)

    Line("I'm moving now, {{target}}. It was nice waiting.", A.Nice)
    Line("I'm done waiting, {{target}}. Take care!", A.Nice)
    Line("I'm going my own way now, {{target}}. Stay safe!", A.Nice)
    Line("I'm done waiting, {{target}}. See you around.", A.Nice)
    
    -- Stoic
    Line("I'm done waiting.", A.Stoic)
    Line("I'm moving now.", A.Stoic)
    Line("I'm not waiting anymore.", A.Stoic)
    Line("I'm done waiting, {{target}}.", A.Stoic)
    Line("I'm moving now, {{target}}.", A.Stoic)
    Line("That's it for me, {{target}}.", A.Stoic)

    -- Teamer
    Line("It was fun teaming up, {{target}}. I'm moving now.", A.Teamer)
    Line("I'm done waiting now {{target}}, let's stick together.", A.Teamer)
    Line("I'm moving now, {{target}}. I trust you.", A.Teamer)
    Line("I'm not waiting anymore, team. Let's go.", A.Teamer)
    Line("I'm done waiting, {{target}}. Let's work as a team.", A.Teamer)

    -- Sus/Quirky
    Line("I'm done waiting, {{target}}. This better be good.", A.Sus)
    Line("I think I'll go my own way now, {{target}}.", A.Sus)
    Line("I'm not waiting anymore, {{target}}. Something's off.", A.Sus)
    Line("I'm done waiting, {{target}}. Don't mess up.", A.Sus)
    Line("I'm moving now, {{target}}. Let's see what happens.", A.Sus)

    -- Tryhard
    Line("I'm done waiting, {{target}}. Let's stay sharp.", A.Tryhard)
    Line("I'm moving now, {{target}}. Stay focused.", A.Tryhard)
    Line("I'm not waiting anymore, {{target}}. Be vigilant.", A.Tryhard)
    Line("I'm done waiting, {{target}}. No mistakes.", A.Tryhard)
    Line("I'm moving now, {{target}}. Let's execute the plan.", A.Tryhard)

    -----------------------------------------------------------

    RegisterCategory("ComeHereStart", P.NORMAL) -- When a bot is going to the same location as the player, named {target}.
    Line("I'm coming to you, {{target}}.", A.Default)
    Line("I'm on my way, {{target}}.", A.Default)
    Line("I'm coming, {{target}}.", A.Default)
    Line("I'm heading to you, {{target}}.", A.Default)
    Line("I'm coming to you, {{target}}.", A.Default)
    
    Line("yo bro sounds good i'm coming", A.Casual)
    Line("i'm on my way", A.Casual)
    Line("yeah sure man i'm coming", A.Casual)
    Line("i'm heading to you", A.Casual)
    Line("i'm coming to you", A.Casual)

    Line("Sure man hope nothing bad happens", A.Bad)
    Line("I hope this is worth it", A.Bad)
    Line("I'm coming, but I don't trust you", A.Bad)
    Line("I'm coming, but I'm not happy about it", A.Bad)
    Line("Lois, I'm coming.", A.Bad)
    
    Line("I'm coming, but I'm not sure why", A.Dumb)
    Line("Where are we going again?", A.Dumb)
    Line("Sure man I think I dropped something over there", A.Dumb)
    Line("Okay? Why am I coming?", A.Dumb)

    Line("Fine, I'm coming, but I don't like you", A.Hothead)
    Line("You better not get me killed {{target}}", A.Hothead)
    Line("Listen here {{target}}, I'm coming but I don't trust you", A.Hothead)
    Line("Let's get this over with {{target}}", A.Hothead)
    Line("Fine, whatever, I'm coming", A.Hothead)

    Line("I'm coming to you, {{target}}, can't wait!", A.Nice)
    Line("I'm on my way, {{target}}, see you soon!", A.Nice)
    Line("I'm coming, {{target}}, let's do this!", A.Nice)
    Line("I'm heading to you, {{target}}, let's go!", A.Nice)
    Line("I'm coming to you, {{target}}, let's stick together!", A.Nice)

    -- Stoic
    Line("I'm coming to you, {{target}}.", A.Stoic)
    Line("I'm on my way, {{target}}.", A.Stoic)
    Line("I'm coming, {{target}}.", A.Stoic)
    Line("I'm heading to you, {{target}}.", A.Stoic)
    
    -- Teamer
    Line("Sure man let's stick together, I'm coming", A.Teamer)
    Line("I'm on my way, {{target}}, let's stick together.", A.Teamer)
    Line("I'm coming, {{target}}, let's stick together!", A.Teamer)
    Line("I'm heading to you, {{target}}, let's stick together!", A.Teamer)
    Line("I'm coming to you, {{target}}, let's stick together!", A.Teamer)

    -- Sus/Quirky
    Line("I'm coming to you, {{target}}, but don't ask about my past.", A.Sus)
    Line("Just ignore the rumors, {{target}}, I'm coming.", A.Sus)
    Line("I'm with you, {{target}}, but don't ask too many questions.", A.Sus)
    Line("Sure man this place is getting too weird, I'm coming", A.Sus)
    Line("I'm coming to you, but don't tell anyone, {{target}}.", A.Sus)

    -- Tryhard
    Line("I'm coming to you, {{target}}, let's do this.", A.Tryhard)
    Line("I'm on my way, {{target}}, let's be efficient.", A.Tryhard)
    Line("Don't get in my way, I'm coming, {{target}}.", A.Tryhard)
    Line("I'm heading to you, {{target}}, let's execute the plan.", A.Tryhard)
    Line("I'm coming to you, {{target}}, stay sharp.", A.Tryhard)

    RegisterCategory("ComeHereRefuse", P.IMPORTANT) -- When a bot is refusing to go to the same location as the player, named {target}.
    Line("I can't come to you, {{target}}.", A.Default)
    Line("I'm not coming to you, {{target}}.", A.Default)
    Line("I'm going my own way, {{target}}.", A.Default)

    Line("nah bro, i'm good", A.Casual)
    Line("i'm good, thanks", A.Casual)
    Line("i'm going my own way", A.Casual)

    Line("Sorry mate, wrong path.", A.Bad)
    Line("Nah, I'm not coming to you.", A.Bad)
    Line("Nope, I'm going my own way.", A.Bad)

    Line("I'm lost, {{target}}. I can't come to you.", A.Dumb)
    Line("I'm not sure where I'm going, {{target}}.", A.Dumb)
    Line("I think I need to go somewhere else, {{target}}.", A.Dumb)

    Line("Don't ask me to come to you, {{target}}!", A.Hothead)
    Line("I'm not coming to you, {{target}}! Get lost!", A.Hothead)
    Line("I'm not coming to you, {{target}}! You're a joke!", A.Hothead)

    Line("I'm going my own way, {{target}}. Sorry.", A.Nice)    
    Line("Hi {{target}}, I'm not coming to you. Sorry.", A.Nice)
    Line("I'm sure you're great, {{target}}, but I'm not coming to you.", A.Nice)

    -- Stoic
    Line("I can't come to you, {{target}}.", A.Stoic)
    Line("My personal path diverges from yours, {{target}}.", A.Stoic)
    Line("My code of ethics prevents me from coming to you, {{target}}.", A.Stoic)

    -- Teamer
    Line("I'm with my buddies, {{target}}. I can't come to you.", A.Teamer)
    Line("I'm not coming to you, {{target}}. I have to stay with the team.", A.Teamer)
    Line("As much as I'd like to, I can't come to you, {{target}}.", A.Teamer)

    -- Sus/Quirky
    Line("I can't come to you, {{target}}, you're not on my team.", A.Sus)
    Line("I'm not coming to you, {{target}}, I have my own agenda.", A.Sus)
    Line("I have my own path to follow, {{target}}, I can't come to you.", A.Sus)

    -- Tryhard
    Line("I can't come to you, {{target}}. I have my own mission.", A.Tryhard)
    Line("I'm not coming to you, {{target}}. I have my own objectives.", A.Tryhard)
    Line("I have my own goals, {{target}}, and you're not part of them.", A.Tryhard)

    RegisterCategory("ComeHereEnd", P.NORMAL) -- When a bot is done going to the same location as the player, named {target}.
    Line("I'm here.", A.Default)
    Line("I've arrived.", A.Default)
    Line("I'm at your location.", A.Default)
    Line("I'm here, {{target}}.", A.Default)
    Line("I've arrived, {{target}}.", A.Default)

    Line("i'm here", A.Casual)
    Line("i've arrived", A.Casual)
    Line("yo i'm at your location", A.Casual)
    Line("i'm here, {{target}}", A.Casual)
    Line("i've arrived, {{target}}", A.Casual)

    Line("I'm here, {{target}}. You're welcome.", A.Bad)
    Line("I've arrived, {{target}}. You're welcome.", A.Bad)

    Line("I'm here, {{target}}. I'm not sure why.", A.Dumb)
    Line("I've arrived, {{target}}. I'm not sure why.", A.Dumb)

    Line("I'm here, {{target}}. You're welcome.", A.Hothead)
    Line("I've arrived, {{target}}. You're welcome.", A.Hothead)

    Line("I'm here, {{target}}. Let's do this.", A.Nice)
    Line("I've arrived, {{target}}. Let's do this.", A.Nice)

    -- Stoic
    Line("I'm here.", A.Stoic)
    Line("I've arrived.", A.Stoic)

    -- Teamer
    Line("I'm here, {{target}}. Let's stick together.", A.Teamer)
    Line("I've arrived, {{target}}. Let's stick together.", A.Teamer)

    -- Sus/Quirky
    Line("I'm here, {{target}}. Let's do this.", A.Sus)
    Line("I've arrived, {{target}}. Let's do this.", A.Sus)

    -- Tryhard
    Line("I'm here, {{target}}. Let's do this.", A.Tryhard)
    Line("I've arrived, {{target}}. Let's do this.", A.Tryhard)

    -----------------------------------------------------------
    RegisterCategory("AttackStart", P.CRITICAL) -- When a bot is responding positively to a request to attack the player, named {target}.
    Line("I'm going to attack {{target}}.", A.Default)
    Line("I've got {{target}}.", A.Default)
    Line("I'll take {{target}}.", A.Default)

    Line("sure man lets kill {{target}}", A.Casual)
    Line("yeah i'll take {{target}}", A.Casual)
    Line("that bastard took my weed, i'll kill {{target}}", A.Casual)

    Line("I'm going to attack {{target}}. I hope it's worth it.", A.Bad)
    Line("I've got {{target}}. I hope this is the right choice.", A.Bad)
    Line("I'll take {{target}}. I hope this is the right move.", A.Bad)

    Line("I'm going to attack {{target}}. I'm not sure why.", A.Dumb)
    Line("Who is {{target}} again? I'm going to attack them.", A.Dumb)
    Line("Instructions unclear, immediately attacking {{target}}.", A.Dumb)

    Line("Finally, so happy I get to kill that bastard {{target}}", A.Hothead)
    Line("I've got {{target}}. I'm going to enjoy this.", A.Hothead)
    Line("I'll take that motherfucker {{target}} down.", A.Hothead)

    --- Nice
    Line("Sure thing, {{target}}. Let's go!", A.Nice)
    Line("Absolutely, {{target}}. Right behind you!", A.Nice)
    Line("Of course, {{target}}. Lead the way!", A.Nice)
    Line("You got it, {{target}}. Let's move!", A.Nice)

    -- Stoic
    Line("I'll attack {{target}}.", A.Stoic)
    Line("Target acquired: {{target}}.", A.Stoic)
    Line("Engaging {{target}}.", A.Stoic)
    Line("Proceeding to attack {{target}}.", A.Stoic)
    Line("Initiating attack on {{target}}.", A.Stoic)

    -- Teamer
    Line("I'll take down {{target}} for the team.", A.Teamer)
    Line("Attacking {{target}} as planned.", A.Teamer)
    Line("Going after {{target}} for us.", A.Teamer)
    Line("Targeting {{target}} for the team.", A.Teamer)
    Line("I'll handle {{target}} for the team.", A.Teamer)

    -- Sus/Quirky
    Line("I'm going to attack {{target}}, hope they don't mind.", A.Sus)
    Line("Attacking {{target}}, this should be fun.", A.Sus)
    Line("Going after {{target}}, let's see what happens.", A.Sus)
    Line("Targeting {{target}}, this could get interesting.", A.Sus)
    Line("I'll attack {{target}}, hope they don't see it coming.", A.Sus)

    -- Tryhard
    Line("I'm going to attack {{target}}, let's do this.", A.Tryhard)
    Line("Attacking {{target}}, stay sharp.", A.Tryhard)
    Line("Going after {{target}}, stay focused.", A.Tryhard)
    Line("Targeting {{target}}, no mistakes.", A.Tryhard)
    Line("I'll take down {{target}}, let's execute the plan.", A.Tryhard)

    -----------------------------------------------------------
    RegisterCategory("AttackRefuse", P.IMPORTANT) -- When a bot is refusing to attack the player, named {target}.
    Line("I can't attack {{target}}.", A.Default)
    Line("I'm not attacking {{target}}.", A.Default)
    Line("I'm going my own way, {{target}}.", A.Default)

    Line("nah bro, i'm good", A.Casual)
    Line("i'm good, thanks", A.Casual)
    Line("i'm going my own way", A.Casual)

    Line("Sorry mate, wrong path.", A.Bad)
    Line("Nah, I'm not attacking {{target}}.", A.Bad)
    Line("Nope, I'm going my own way.", A.Bad)

    Line("Who is {{target}} again? I'm not attacking them.", A.Dumb)


    Line("Don't ask me to attack {{target}}!", A.Hothead)
    Line("I'm not attacking {{target}}! Get lost!", A.Hothead)
    Line("I'm not attacking {{target}}! You're a joke!", A.Hothead)

    Line("I'm going my own way, {{target}}. Sorry.", A.Nice)
    Line("Hi {{target}}, I'm not attacking you. Sorry.", A.Nice)
    Line("I'm sure you're great, {{target}}, but I'm not attacking you.", A.Nice)

    -- Stoic
    Line("I can't attack {{target}}.", A.Stoic)
    Line("My personal path diverges from yours, {{target}}.", A.Stoic)
    Line("My code of ethics prevents me from attacking {{target}}.", A.Stoic)

    -- Teamer
    Line("I'm with my buddies, I can't attack {{target}} .", A.Teamer)
    Line("I'm not attacking you, {{target}}. I have to stay with the team.", A.Teamer)
    Line("As much as I'd like to, I can't attack {{target}}.", A.Teamer)

    -- Sus/Quirky
    Line("I can't attack {{target}}, you're not on my team.", A.Sus)
    Line("Nah, I'm not attacking {{target}}, I have my own agenda.", A.Sus)
    Line("I have my own path to follow, I can't attack {{target}}.", A.Sus)

    -- Tryhard
    Line("I can't attack {{target}}. I have my own mission.", A.Tryhard)
    Line("I'm not attacking {{target}}. I have my own objectives.", A.Tryhard)
    Line("I have my own goals, and you're not part of them.", A.Tryhard)

    RegisterCategory("AttackEnd", P.NORMAL) -- When a bot is done attacking the player, named {target}.
    Line("I'm done attacking.", A.Default)
    Line("I'm moving now.", A.Default)
    Line("I'm not attacking anymore.", A.Default)

    RegisterCategory("RoleCheckerRequestAccepted", P.NORMAL) -- When a bot is accepting a request to check the role of the player, named {target}.
    Line("Sure, I'll show you my role {{target}}.", A.Default)

    RegisterCategory("RoleCheckerRequestRefused", P.IMPORTANT) -- When a bot is refusing to check the role of the player, named {target}.
    Line("I can't show you my role, {{target}}.", A.Default)

    RegisterCategory("CallKOS", P.CRITICAL) -- When a bot is going to call KOS on another player.
    Line("KOS on {{player}}!", A.Default)
    Line("{{player}} is KOS", A.Default)
    Line("KOS on {{player}}", A.Default)
    Line("KOS {{player}}", A.Default)
    Line("{{player}} is a traitor!", A.Default)
    Line("{{player}} is a traitor.", A.Default)
    Line("KOS on {{player}}!!", A.Default)
    Line("kos {{player}}", A.Casual)
    Line("{{player}} is a traitor", A.Casual)
    Line("kos on {{player}}", A.Casual)
    Line("KOS on {{player}}", A.Casual)
    Line("you should probably kill {{player}} at some point, just saying", A.Bad)
    Line("kill {{player}} i think", A.Bad)
    Line("kill {{player}}", A.Bad)
    Line("{{player}} is mean", A.Dumb)
    Line("{{player}} is making people go to sleep", A.Dumb)
    Line("{{player}} is making large bang bang sounds!!", A.Dumb)
    Line("{{player}} YOU DICK K.O.S THEM NOW", A.Hothead)
    Line("{{player}} you asshole why are you shooting people?", A.Hothead)
    Line("kill {{player}}!!!!!11", A.Dumb)
    Line("{{player}} is a traitor ;)", A.Sus)
    Line("you should probably kos {{player}}", A.Sus)
    Line("KOS on {{player}}, I think...", A.Sus)
    Line("KOS {{player}}. For sure.", A.Tryhard)
    Line("KOS on {{player}}, no doubt.", A.Tryhard)
    Line("KOS {{player}}", A.Tryhard)
    Line("KOS {{player}} NOW!", A.Tryhard)

    -----------------------------------------------------------
    -- TRAITORS SHARING PLANS
    -----------------------------------------------------------

    local ATTACKANY = ACTS.ATTACKANY
    RegisterCategory(f("Plan.%s", ATTACKANY), P.CRITICAL) -- When a traitor bot is going to attack a player/bot.
    Line("I'm going to attack {{player}}.", A.Default)
    Line("I've got {{player}}.", A.Default)
    Line("I'll take {{player}}.", A.Default)
    Line("I call {{player}}.", A.Default)
    Line("I will go after {{player}}.", A.Default)
    Line("I'm going to attack {{player}}.", A.Default)
    Line("I've got {{player}}", A.Default)
    Line("I'll take {{player}}", A.Default)
    Line("I call {{player}}", A.Default)
    Line("I will deal with {{player}}", A.Default)
    Line("dibs on {{player}}.", A.Casual)
    Line("gonna kill {{player}}.", A.Casual)
    Line("I'll try to get {{player}}", A.Bad)
    Line("I'll try to kill {{player}}", A.Bad)
    Line("ion gonna kill {{player}}", A.Dumb)
    Line("{{player}} is my kill target", A.Dumb)
    Line("{{player}} is mine, idiots.", A.Hothead)
    Line("{{player}} is mine.", A.Hothead)
    Line("Gonna wreck {{player}}.", A.Hothead)
    Line("Let me get {{player}}!", A.Teamer)
    Line("Let's take on {{player}}!!", A.Teamer)
    Line("I'll take {{player}} on alone. Easy-peasy", A.Tryhard)
    Line("Dibs on {{player}}. Don't take my ace", A.Tryhard)

    local ATTACK = ACTS.ATTACK
    RegisterCategory(f("Plan.%s", ATTACK), P.CRITICAL) -- When a traitor bot is going to attack a player/bot.
    Line("I'm going to attack {{player}}.", A.Default)
    Line("I've got {{player}}.", A.Default)
    Line("I'll take {{player}}.", A.Default)
    Line("I call {{player}}.", A.Default)
    Line("I will go after {{player}}.", A.Default)
    Line("I'm going to attack {{player}}.", A.Default)
    Line("I've got {{player}}", A.Default)
    Line("I'll take {{player}}", A.Default)
    Line("I call {{player}}", A.Default)
    Line("I will deal with {{player}}", A.Default)
    Line("dibs on {{player}}.", A.Casual)
    Line("gonna kill {{player}}.", A.Casual)
    Line("I'll try to get {{player}}", A.Bad)
    Line("I'll try to kill {{player}}", A.Bad)
    Line("ion gonna kill {{player}}", A.Dumb)
    Line("{{player}} is my kill target", A.Dumb)
    Line("{{player}} is mine, idiots.", A.Hothead)
    Line("{{player}} is mine.", A.Hothead)
    Line("Gonna wreck {{player}}.", A.Hothead)
    Line("Let me get {{player}}!", A.Teamer)
    Line("Let's take on {{player}}!!", A.Teamer)
    Line("I'll take {{player}} on alone. Easy-peasy", A.Tryhard)
    Line("Dibs on {{player}}. Don't take my ace", A.Tryhard)

    local PLANT = ACTS.PLANT
    RegisterCategory(f("Plan.%s", PLANT), P.CRITICAL) -- When a traitor bot is going to plant a bomb.
    Line("I'm going to plant a bomb.", A.Default)
    Line("I'm planting a bomb.", A.Default)
    Line("Placing a bomb!", A.Default)
    Line("Gonna rig this place to blow.", A.Default)

    local DEFUSE = ACTS.DEFUSE
    RegisterCategory(f("Plan.%s", DEFUSE), P.CRITICAL) -- When a traitor bot is going to defuse a bomb.
    Line("I'm going to defuse a bomb.", A.Default)

    local FOLLOW = ACTS.FOLLOW
    RegisterCategory(f("Plan.%s", FOLLOW), P.CRITICAL) -- When a traitor bot is going to follow a player/bot.
    -- Default
    Line("I'm going to follow {{player}}", A.Default)
    Line("I'll follow {{player}}", A.Default)
    Line("I'm following {{player}}", A.Default)
    Line("I'm going to follow {{player}}", A.Default)
    Line("I'll follow {{player}}", A.Default)

    -- Casual
    Line("hey team, I'm following {{player}}", A.Casual)
    Line("just so you know, I'm on {{player}}'s tail", A.Casual)
    Line("following {{player}} now", A.Casual)
    Line("gonna stick with {{player}} for a bit", A.Casual)

    -- Hothead
    Line("I'm on {{player}}'s ass!", A.Hothead)
    Line("Following {{player}}, don't get in my way!", A.Hothead)
    Line("I'm tailing {{player}}, let's get this done!", A.Hothead)
    Line("{{player}} is mine to follow!", A.Hothead)

    -- Stoic
    Line("I'll follow {{player}}", A.Stoic)
    Line("Following {{player}}", A.Stoic)
    Line("I'm on {{player}}", A.Stoic)
    Line("I'll be with {{player}}", A.Stoic)

    -- Dumb
    Line("I'm gonna follow {{player}} now", A.Dumb)
    Line("Following {{player}}... I think", A.Dumb)
    Line("Hey, I'm with {{player}}", A.Dumb)
    Line("I'm going after {{player}}", A.Dumb)

    -- Nice
    Line("I'll keep an eye on {{player}} for us", A.Nice)
    Line("Following {{player}}, stay safe everyone", A.Nice)
    Line("I'm with {{player}}, let's do this together", A.Nice)
    Line("I'll follow {{player}}, don't worry", A.Nice)

    -- Bad
    Line("I guess I'll follow {{player}}", A.Bad)
    Line("Following {{player}}, I hope this works", A.Bad)
    Line("I'm on {{player}}, let's see how this goes", A.Bad)
    Line("I'll follow {{player}}, wish me luck", A.Bad)

    -- Teamer
    Line("I'll follow {{player}}, we've got this team", A.Teamer)
    Line("Following {{player}}, let's stick together", A.Teamer)
    Line("I'm with {{player}}, let's move as a unit", A.Teamer)
    Line("I'll follow {{player}}, teamwork makes the dream work", A.Teamer)

    -- Sus/Quirky
    Line("I'm following {{player}}, hope they don't mind", A.Sus)
    Line("Following {{player}}, this should be fun", A.Sus)
    Line("I'm on {{player}}, let's see what happens", A.Sus)
    Line("I'll follow {{player}}, this could get interesting", A.Sus)

    -- Tryhard
    Line("I'm on {{player}}, let's execute the plan", A.Tryhard)
    Line("Following {{player}}, stay sharp team", A.Tryhard)
    Line("I'm tailing {{player}}, let's be efficient", A.Tryhard)
    Line("I'll follow {{player}}, no mistakes", A.Tryhard)
    


    local GATHER = ACTS.GATHER
    RegisterCategory(f("Plan.%s", GATHER), P.CRITICAL) -- When a traitor bot is going to gather with other bots.
    Line("Let's all gather over there.", A.Default)
    Line("Gather over here.", A.Default)
    Line("come hither lads", A.Casual)
    Line("come here", A.Casual)
    Line("gather", A.Casual)
    Line("gather here", A.Casual)
    Line("Come on, you idiots, over here.", A.Hothead)
    Line("Gather up, you idiots.", A.Hothead)
    Line("Teamwork makes the dream work", A.Teamer)
    Line("We are not a house divided", A.Teamer)
    Line("Come bunch up so I can use you guys as bullet sponges.", A.Tryhard)
    Line("Gather up, I need you guys to be my meat shields.", A.Tryhard)
    Line("uhhh... let's assemble, lol", A.Dumb)
    Line("let's gather n lather", A.Dumb)
    Line("Come on now, huddle up. Where's my hug at?", A.Stoic)
    Line("Let's gather up, I need a hug.", A.Stoic)
    Line("Where all my friends at? Let's all work together.", A.Nice)
    Line("Let's all gather up, I need some friends for this one.", A.Nice)


    local DEFEND = ACTS.DEFEND
    RegisterCategory(f("Plan.%s", DEFEND), P.CRITICAL) -- When a traitor bot is going to defend an area.
    Line("I'm going to defend this area.", A.Default)


    local ROAM = ACTS.ROAM
    RegisterCategory(f("Plan.%s", ROAM), P.CRITICAL) -- When a traitor bot is going to roam.
    Line("I'm going to roam around for a bit.", A.Default)

    local IGNORE = ACTS.IGNORE
    RegisterCategory(f("Plan.%s", IGNORE), P.CRITICAL) -- When a traitor bot wants to ignore the plans.
    Line("I feel like doing my own thing this time around.", A.Default)
    Line("Going rogue sounds fun right now.", A.Default)
    Line("Let's mix things up, I'm not following the plan.", A.Default)
    Line("Eh, plans are overrated anyway.", A.Casual)
    Line("I'm just gonna wing it this time.", A.Casual)
    Line("Who cares about plans? I'll do what I want.", A.Bad)
    Line("Forget the plan, I have my own ideas.", A.Bad)
    Line("Plans are hard. I'll just do something.", A.Dumb)
    Line("What was the plan again? Eh, nevermind.", A.Dumb)
    Line("Plans are for losers. I'm doing this my way!", A.Hothead)
    Line("I don't follow plans, I make my own!", A.Hothead)
    Line("Ignoring the plan. Seems more fun to surprise you all.", A.Sus)
    Line("Who needs a plan? Not me, that's for sure.", A.Sus)
    Line("Plans are for the weak. Time for a bold move.", A.Tryhard)
    Line("Strategy? Nah, improvisation is the key to victory.", A.Tryhard)

    -----------------------------------------------------------
    -- FOLLOWING
    -----------------------------------------------------------

    RegisterCategory("FollowRequest", P.CRITICAL) -- When a traitor bot is responding to a request to follow from teammie
    Line("Sure, I'll follow you.", A.Default)
    Line("Okay, I'll follow you.", A.Default)
    Line("Alright, I'll follow you.", A.Default)
    Line("Gotcha, {{player}}", A.Default)
    Line("On my way, {{player}}", A.Default)
    Line("I'm coming", A.Default)
    Line("I'm on my way", A.Default)
    Line("I'm coming with you, {{player}}", A.Default)
    Line("Sure thing", A.Default)
    Line("Okay", A.Default)
    Line("Sure, I'll follow you.", A.Default)
    Line("Okay, I'll follow you.", A.Default)
    Line("Alright, I'll follow you.", A.Default)
    Line("Gotcha, {{player}}.", A.Default)
    Line("On my way, {{player}}.", A.Default)
    Line("I'm coming.", A.Default)
    Line("I'm on my way.", A.Default)
    Line("I'm coming with you, {{player}}.", A.Default)
    Line("Sure thing.", A.Default)
    Line("Okay.", A.Default)
    Line("Gotcha.", A.Default)
    Line("On my way.", A.Default)
    Line("Sure.", A.Default)
    Line("Okay.", A.Default)
    Line("On it.", A.Default)
    Line("Following your lead, {{player}}.", A.Default)
    Line("Roger that.", A.Default)
    Line("Affirmative.", A.Default)
    Line("Copy that, {{player}}.", A.Default)
    Line("Understood.", A.Default)
    Line("You lead, I'll follow.", A.Default)
    Line("Right behind you, {{player}}.", A.Default)
    Line("Acknowledged.", A.Default)
    Line("I got your back.", A.Default)
    Line("You got it.", A.Default)
    Line("I hear you, {{player}}. Following.", A.Default)
    Line("You got it, champ.", A.Default)
    Line("Roger.", A.Default)
    Line("Let's roll, {{player}}!", A.Default)
    Line("yup", A.Casual)
    Line("gotcha", A.Casual)
    Line("on my way", A.Casual)
    Line("sure", A.Casual)
    Line("okay", A.Casual)
    Line("on it", A.Casual)
    Line("on my way", A.Casual)
    Line("sure, bud", A.Casual)


    RegisterCategory("FollowStarted", P.NORMAL) -- When a inno/other bot begins following someone random
    Line("I'm gonna follow you for a bit, {{player}}.", A.Default)
    Line("I'll follow you for a bit, {{player}}.", A.Default)
    Line("Mind if I tag along?", A.Default)
    Line("I'll follow you.", A.Default)
    Line("You look rather follow-able today.", A.Default)
    Line("I'll watch your back {{player}}.", A.Default)
    Line("What's up, {{player}}? Imma tag along.", A.Default)

    Line("hi {{player}}", A.Casual)
    Line("wsg {{player}}? im on your back", A.Casual)
    Line("what's up {{player}}", A.Casual)
    Line("what's good {{player}}? im following you", A.Casual)
    Line("hey imma follow you for a bit", A.Casual)
    Line("dont worry bud i got your back", A.Casual)
    Line("imma follow you", A.Casual)
    Line("imma follow you for a bit", A.Casual)
    Line("imma follow you for a bit, {{player}}", A.Casual)
    Line("im gonna come with", A.Casual)
    Line("mind if little old me comes along?", A.Casual)

    Line("Let's stick together, {{player}}!", A.Teamer)
    Line("I'll follow you, {{player}}!", A.Teamer)
    Line("I'll watch your behind, {{player}}!", A.Teamer)
    Line("Let's keep each other safe, {{player}}!", A.Teamer)
    Line("I'm going to follow you, {{player}}!", A.Teamer)
    Line("Imma follow {{player}}, keep me safe, ok?", A.Teamer)

    Line("haha", A.Dumb)
    Line("haha im following you", A.Dumb)
    Line("im following you for a bit", A.Dumb)
    Line("{{player}}", A.Dumb)
    Line("hi", A.Dumb)
    Line("im glued to you bud", A.Dumb)

    Line("I hope you're good enough.", A.Hothead)
    Line("I guess you'll do, {{player}}", A.Hothead)
    Line("Good enough, I'm following you now.", A.Hothead)
    Line("I'm gonna follow this kid.", A.Hothead)
    Line("You'd better have room for 2, {{player}}", A.Hothead)

    RegisterCategory("PersonalSpace", P.IMPORTANT) -- Warning another player about their personal space
    Line("Hey, {{player}}, you're a bit close.", A.Default)
    Line("Please back off.", A.Default)
    Line("Please back off {{player}}", A.Default)
    Line("A little bit of space, please?", A.Default)
    Line("Some room?", A.Default)
    Line("Step away for a moment", A.Default)
    Line("Could you please give me some space?", A.Default)
    Line("Excuse me, {{player}}.", A.Default)
    Line("I need some breathing room, {{player}}", A.Default)
    Line("What do you want, {{player}}?", A.Default)
    Line("I'm with {{player}}.", A.Default)
    Line("{{player}} acts suspicious.", A.Default)
    -----------------------------------------------------------
    -- INVESTIGATIONS
    -----------------------------------------------------------


    RegisterCategory("InvestigateCorpse", P.IMPORTANT) -- When a bot begins the InvestigateCorpse behavior (sees a revivable player)
    Line("I found someone's corpse.", A.Default)
    Line("There's a dead player here.", A.Default)
    Line("Someone's dead over here.", A.Default)
    Line("I see a dead person.", A.Default)
    Line("Found someone who needs help.", A.Default)

    Line("yo, someone's knocked out", A.Casual)
    Line("hey, there's a deaded player here", A.Casual)
    Line("someone's taking a nap over here", A.Casual)
    Line("found someone's corpse, lol", A.Casual)
    Line("uh, someone's out cold", A.Casual)

    Line("This guy's out cold.", A.Bad)
    Line("Found a loser knocked out.", A.Bad)
    Line("Someone's dead, typical.", A.Bad)
    Line("Look at this fool, corpse.", A.Bad)
    Line("Another one bites the dust.", A.Bad)

    Line("uhh, why is this guy dead?", A.Dumb)
    Line("hey, this guy's not moving", A.Dumb)
    Line("is this guy dead or what?", A.Dumb)
    Line("uh oh, someone's not awake", A.Dumb)
    Line("why is this person lying dead?", A.Dumb)

    Line("Someone's corpse, idiots.", A.Hothead)
    Line("Found a dead moron.", A.Hothead)
    Line("This guy's out, what a joke.", A.Hothead)
    Line("Look at this idiot, corpse.", A.Hothead)
    Line("Someone's dead, figures.", A.Hothead)

    Line("I found someone who needs help.", A.Nice)
    Line("There's a dead player here, let's help.", A.Nice)
    Line("Someone's dead, let's assist.", A.Nice)
    Line("I see someone corpse, let's help them.", A.Nice)
    Line("Found someone who needs our help.", A.Nice)

    Line("I found a dead player.", A.Stoic)
    Line("There's a dead person here.", A.Stoic)
    Line("Someone is dead.", A.Stoic)
    Line("I see a dead individual.", A.Stoic)
    Line("Found a dead player.", A.Stoic)

    Line("Found someone corpse, team.", A.Teamer)
    Line("There's a deaded player here, team.", A.Teamer)
    Line("Someone's out cold, team.", A.Teamer)
    Line("I see a dead player, team.", A.Teamer)
    Line("Found someone who needs help, team.", A.Teamer)

    Line("Found a dead player, let's revive.", A.Tryhard)
    Line("There's a deaded player, let's get them up.", A.Tryhard)
    Line("Someone's out cold, let's revive them.", A.Tryhard)
    Line("I see a dead player, let's help.", A.Tryhard)
    Line("Found someone who needs reviving, let's go.", A.Tryhard)

    RegisterCategory("InvestigateNoise", P.NORMAL) -- When a bot hears a noise and it wants to investigate it.
    Line("I heard something.", A.Default)
    Line("What was that?", A.Default)
    Line("What was that noise?", A.Default)
    Line("Did you hear that?", A.Default)
    Line("Gonna go see what that was about", A.Default)
    Line("pew pew pew", A.Casual)
    Line("that sounded not good", A.Casual)
    Line("that sounded bad", A.Casual)
    Line("that sounded like a gun or smn", A.Casual)
    Line("uh-oh", A.Casual)
    Line("uhhh", A.Casual)
    Line("okay that's not good", A.Casual)
    Line("Did anyone else hear that?", A.Default)
    Line("Something's out there...", A.Default)
    Line("pew pew pew", A.Casual)
    Line("that sounded not good", A.Casual)
    Line("uhh, was that important?", A.Casual)
    Line("hmm, whatever", A.Casual)
    Line("Who's there? Show yourself!", A.Bad)
    Line("I'm not afraid of you!", A.Bad)
    Line("Come out and fight!", A.Bad)
    Line("You can't hide forever!", A.Bad)
    Line("Huh? What's that thing?", A.Dumb)
    Line("I don't get it...", A.Dumb)
    Line("Sounds funny, hehe", A.Dumb)
    Line("Duh, what was I doing?", A.Dumb)
    Line("Who's making noise?!", A.Hothead)
    Line("I'll punch whoever that is!", A.Hothead)
    Line("This is annoying!", A.Hothead)
    Line("Quiet down, I'm busy!", A.Hothead)
    Line("Is someone there? Can I help?", A.Nice)
    Line("Hello? Do you need assistance?", A.Nice)
    Line("I hope they're okay...", A.Nice)
    Line("Maybe they need a friend?", A.Nice)
    Line("Acknowledged.", A.Stoic)
    Line("Proceeding to investigate.", A.Stoic)
    Line("Disturbance detected.", A.Stoic)
    Line("Alertness increased.", A.Stoic)
    Line("I definitely didn't do that.", A.Sus)
    Line("Wasn't me, I swear.", A.Sus)
    Line("You can't prove anything!", A.Sus)
    Line("Why is everyone looking at me?", A.Sus)
    Line("Did you guys hear that too?", A.Teamer)
    Line("We should check it out together.", A.Teamer)
    Line("Us teamers gotta stick together.", A.Teamer)
    Line("Together, we can handle anything!", A.Teamer)
    Line("That sound again?", A.Default)
    Line("I'll check it out.", A.Default)
    Line("Is everything okay there?", A.Default)
    Line("This could be serious.", A.Default)
    Line("I better take a look.", A.Default)
    Line("Sounds suspicious...", A.Default)
    Line("Should I be worried?", A.Default)
    Line("What's happening over there?", A.Default)
    Line("Could be trouble...", A.Default)
    Line("Let's see what that was.", A.Default)
    Line("lol what was that", A.Casual)
    Line("sounds weird but ok", A.Casual)
    Line("eh, probably nothing", A.Casual)
    Line("do i have to check it out?", A.Casual)
    Line("haha, nice sound", A.Casual)
    Line("not my problem, right?", A.Casual)
    Line("who cares lol", A.Casual)
    Line("whatever that is, im chill", A.Casual)
    Line("just another noise", A.Casual)
    Line("meh, sounds boring", A.Casual)
    Line("Someone's asking for trouble!", A.Bad)
    Line("I'm not scared of anything!", A.Bad)
    Line("I'll find out and they'll regret it!", A.Bad)
    Line("Who dares disturb me?", A.Bad)
    Line("Time to show who's boss!", A.Bad)
    Line("They picked the wrong guy to mess with!", A.Bad)
    Line("I'll teach them a lesson!", A.Bad)
    Line("Nobody messes with me!", A.Bad)
    Line("This is my territory!", A.Bad)
    Line("I'm coming for whoever did that!", A.Bad)
    Line("Sounds like a thingy!", A.Dumb)
    Line("What's that doohickey?", A.Dumb)
    Line("I heard a thing!", A.Dumb)
    Line("Dunno what that is, but it's funny!", A.Dumb)
    Line("Sounds like... something?", A.Dumb)
    Line("Hehe, that tickles my ears!", A.Dumb)
    Line("What's that jiggly sound?", A.Dumb)
    Line("Is that a thingamajig?", A.Dumb)
    Line("Ooh, what was that?", A.Dumb)
    Line("Funny noise, makes me giggle!", A.Dumb)
    Line("What was that?!", A.Hothead)
    Line("I'll make you regret it!", A.Hothead)
    Line("So irritating!", A.Hothead)
    Line("I've had enough of this!", A.Hothead)
    Line("This is the last straw!", A.Hothead)
    Line("They're asking for a fight!", A.Hothead)
    Line("I'll shut them up!", A.Hothead)
    Line("Enough of these games!", A.Hothead)
    Line("They won't like me angry!", A.Hothead)
    Line("I'm losing my patience!", A.Hothead)
    Line("Anyone need help?", A.Nice)
    Line("I'm here if you need me!", A.Nice)
    Line("Everything alright there?", A.Nice)
    Line("Can I be of assistance?", A.Nice)
    Line("I hope no one's in trouble.", A.Nice)


    -----------------------------------------------------------
    -- SPOTTING A PLAYER OR ENTITY
    -----------------------------------------------------------

    RegisterCategory("HoldingTraitorWeapon", P.IMPORTANT) -- When a bot sees a player with a traitor-exclusive weapon.
    Line("{{player}} is holding a traitor weapon!", A.Default)
    Line("traitor weapon on {{player}}", A.Casual)
    Line("hey he's holding a traitor weapon", A.Casual)

    RegisterCategory("SpottedC4", P.CRITICAL) -- When an innocent bot sees a C4.
    Line("I found a bomb!", A.Default)
    Line("I found a C4!", A.Default)
    Line("C4 over here!", A.Default)
    Line("oh look a bomb", A.Casual)
    Line("bomb here", A.Casual)
    Line("C4 here", A.Casual)
    Line("I think someone left dropped a defibrillator", A.Bad)
    Line("I found a defibrillator", A.Bad)
    Line("I think I hear beeping", A.Dumb)
    Line("There's a beeping sound", A.Dumb)
    Line("Okay who's got a defuser there's a bomb", A.Tryhard)
    Line("I found a bomb, someone get a defuser", A.Tryhard)
    Line("C4 around, kill whoever planted it", A.Tryhard)
    Line("GET DOWN, THERE'S A BOMB", A.Hothead)
    Line("BOMB, BOMB, BOMB", A.Hothead)
    Line("BOMB ALERT", A.Hothead)
    Line("Interesting... a bomb", A.Sus)
    Line("I found a bomb, what do we do?", A.Sus)

    RegisterCategory("DefusingC4", P.IMPORTANT) -- When an innocent bot is defusing a C4.
    Line("I'm defusing that bomb.", A.Default)
    Line("Defusing the bomb, stay sharp.", A.Tryhard)
    Line("I'm defusing this bomb, cover me!", A.Hothead)
    Line("Defusing the bomb.", A.Stoic)
    Line("How do I defuse this thing?", A.Dumb)
    Line("I'm defusing the bomb, wish me luck!", A.Nice)
    Line("Defusing the bomb, hope it doesn't blow.", A.Bad)
    Line("I'm defusing the bomb, team.", A.Teamer)
    Line("Defusing the bomb, hope it works.", A.Sus)
    Line("I'm defusing the bomb, no big deal.", A.Casual)

    RegisterCategory("DefusingSuccessful", P.IMPORTANT) -- When an innocent bot is defusing a C4.
    Line("I defused it!", A.Default)
    Line("Bomb defused successfully.", A.Default)
    Line("Bomb defused.", A.Default)
    Line("Defused the bomb.", A.Default)
    Line("Bomb defused, we're safe.", A.Default)
    Line("Bomb defused, good job team.", A.Default)

    Line("bomb defused", A.Casual)
    Line("we're safe now", A.Casual)
    Line("defused it", A.Casual)
    Line("bomb's defused", A.Casual)
    Line("all clear", A.Casual)

    Line("Bomb defused, losers.", A.Bad)
    Line("Defused it, no thanks to you.", A.Bad)
    Line("Bomb's defused, you're welcome.", A.Bad)
    Line("Handled it, as usual.", A.Bad)
    Line("Bomb's defused, try harder next time.", A.Bad)

    Line("I defused the bomb, duh.", A.Dumb)
    Line("Bomb's not gonna blow now.", A.Dumb)
    Line("I did it, bomb's defused.", A.Dumb)
    Line("Bomb's defused, yay.", A.Dumb)
    Line("No more boom boom, I defused it.", A.Dumb)

    Line("Bomb defused, idiots.", A.Hothead)
    Line("Defused the bomb, morons.", A.Hothead)
    Line("Bomb's defused, finally.", A.Hothead)
    Line("Handled the bomb, you fools.", A.Hothead)
    Line("Bomb's defused, about time.", A.Hothead)

    Line("Bomb defused, stay safe!", A.Nice)
    Line("Defused the bomb, we're good.", A.Nice)
    Line("Bomb's defused, all clear.", A.Nice)
    Line("Handled the bomb, no worries.", A.Nice)
    Line("Bomb's defused, great job everyone.", A.Nice)

    Line("Bomb defused.", A.Stoic)
    Line("Defused the bomb.", A.Stoic)
    Line("Bomb's defused.", A.Stoic)
    Line("Handled the bomb.", A.Stoic)
    Line("Bomb's defused, proceed.", A.Stoic)

    Line("Bomb defused, team.", A.Teamer)
    Line("Defused the bomb, good job team.", A.Teamer)
    Line("Bomb's defused, we're safe.", A.Teamer)
    Line("Handled the bomb, team effort.", A.Teamer)
    Line("Bomb's defused, well done team.", A.Teamer)

    Line("Bomb defused, no big deal.", A.Tryhard)
    Line("Defused the bomb, easy.", A.Tryhard)
    Line("Bomb's defused, as expected.", A.Tryhard)
    Line("Handled the bomb, no sweat.", A.Tryhard)
    Line("Bomb's defused, let's keep going.", A.Tryhard)

    RegisterCategory("RevivingPlayer", P.IMPORTANT) -- When a bot is reviving a player.
    Line("I'm reviving {{player}}.", A.Default)
    Line("Reviving {{player}} now.", A.Casual)
    Line("Bringing {{player}} back to life.", A.Nice)
    Line("{{player}} is getting revived.", A.Stoic)
    Line("{{player}}, you're coming back.", A.Teamer)
    Line("Reviving {{player}}. Stay still.", A.Tryhard)
    Line("{{player}}, I'm reviving you.", A.Hothead)
    Line("{{player}}, hold on. Reviving you.", A.Bad)
    Line("Reviving {{player}}. Don't move.", A.Sus)
    Line("{{player}}, I'm reviving you. Hang tight.", A.Dumb)

    RegisterCategory("CreatingDoctor", P.IMPORTANT) -- When a bot is creating a doctor.
    Line("{{player}}, I'm making you a doctor", A.Default)
    Line("{{player}}, you're gonna be a doctor", A.Casual)
    Line("{{player}}, I'm making you a doctor. Congrats!", A.Nice)
    Line("{{player}}, you're now a doctor", A.Stoic)
    Line("{{player}}, I'm making you a doctor. Don't mess it up.", A.Hothead)
    Line("{{player}}, you're a doctor now. Try not to screw up.", A.Bad)
    Line("{{player}}, I'm making you a doctor. Good luck!", A.Teamer)
    Line("{{player}}, you're gonna be a doctor. Don't die.", A.Tryhard)
    Line("{{player}}, I'm making you a doctor. Hope you know what you're doing.", A.Sus)
    Line("{{player}}, you're a doctor now. Yay!", A.Dumb)

    RegisterCategory("CreatingDeputy", P.IMPORTANT) -- When a bot is creating a deputy.
    Line("{{player}}, I'm making you a deputy", A.Default)
    Line("{{player}}, you're gonna be a deputy", A.Casual)
    Line("{{player}}, I'm making you a deputy. Congrats!", A.Nice)
    Line("{{player}}, you're now a deputy", A.Stoic)
    Line("{{player}}, I'm making you a deputy. Don't get everyone killed.", A.Hothead)
    Line("{{player}}, you're a deputy now. Try not to screw up.", A.Bad)
    Line("{{player}}, I'm making you a deputy. Good luck!", A.Teamer)
    Line("{{player}}, you're gonna be a deputy. Don't die.", A.Tryhard)
    Line("{{player}}, I'm making you a deputy. Hope you know what you're doing.", A.Sus)
    Line("{{player}}, you're a deputy now. Yay!", A.Dumb)

    RegisterCategory("CreatingCursed", P.IMPORTANT) -- When a bot is creating a cursed (Team Only).
    Line("I'm going to make {{player}} a cursed", A.Default)
    Line("making {{player}} a cursed", A.Casual)
    Line("I feel bad for {{player}}, they're gonna be a cursed", A.Nice)
    Line("Giving {{player}} the cursed role", A.Stoic)
    Line("Let's see how {{player}} likes the cursed role!", A.Hothead)
    Line("{{player}} is gonna be a cursed. Good luck!", A.Bad)
    Line("Helping the team by making {{player}} a cursed", A.Teamer)
    Line("Shooting {{player}} with cursed deagle", A.Tryhard)
    Line("Oops, going to make {{player}} a cursed", A.Sus)
    Line("Hope I dont miss {{player}} with the cursed deagle", A.Dumb)

    RegisterCategory("CreatingDefector", P.IMPORTANT) -- When a bot is creating a defector (Team Only).
    Line("I'm going to make {{player}} a defector", A.Default)
    Line("making {{player}} a defector", A.Casual)
    Line("Going to make {{player}} a defector. Good luck!", A.Nice)
    Line("{{player}} is going to become a defector", A.Stoic)
    Line("going to shoot that asshole {{player}} with the defector deagle", A.Hothead)
    Line("shooting {{player}} with the defector deagle", A.Bad)
    Line("Going to make {{player}} a defector. Hope they don't die.", A.Teamer)
    Line("{{player}} is going to be a defector. Hope they don't screw up.", A.Tryhard)
    Line("Oops, going to make {{player}} a defector", A.Sus)
    Line("Hope I dont miss {{player}} with the defector deagle", A.Dumb)

    RegisterCategory("CreatingSidekick", P.IMPORTANT) -- When a bot is creating a sidekick (Team Only).
    Line("I'm going to make {{player}} a sidekick", A.Default)
    Line("making {{player}} a sidekick", A.Casual)
    Line("Going to make {{player}} a sidekick. Good luck!", A.Nice)
    Line("{{player}} is going to become a sidekick", A.Stoic)
    Line("Let's see how {{player}} likes the sidekick role!", A.Hothead)
    Line("{{player}} is going to be a sidekick. Good luck!", A.Bad)
    Line("Helping the team by making {{player}} a sidekick", A.Teamer)
    Line("Shooting {{player}} with sidekick deagle", A.Tryhard)
    Line("Oops, going to make {{player}} a sidekick", A.Sus)
    Line("Hope I dont miss {{player}} with the sidekick deagle", A.Dumb)

    RegisterCategory("CreatingMedic", P.IMPORTANT) -- When a bot is creating a medic (Team Only).
    Line("I'm going to make {{player}} a medic", A.Default)
    Line("making {{player}} a medic", A.Casual)
    Line("Going to make {{player}} a medic. Good luck!", A.Nice)
    Line("{{player}} is going to become a medic", A.Stoic)
    Line("Let's see how {{player}} likes the medic role!", A.Hothead)
    Line("{{player}} is going to be a medic. Good luck!", A.Bad)
    Line("Helping the team by making {{player}} a medic", A.Teamer)
    Line("Shooting {{player}} with medic deagle", A.Tryhard)
    Line("Oops, going to make {{player}} a medic", A.Sus)
    Line("Hope I dont miss {{player}} with the medic deagle", A.Dumb)

    RegisterCategory("RoleDefibPlayer", P.IMPORTANT) -- When a bot is reviving a player with a defibrillator (Team Only).
    Line("I'm reviving {{player}} with a role defibrillator.", A.Default)
    Line("Reviving {{player}} with a role defibrillator.", A.Casual)
    Line("Bringing {{player}} back to life with a role defibrillator.", A.Nice)
    Line("{{player}} is getting revived with a role defibrillator.", A.Stoic)
    

    RegisterCategory("UsingRoleChecker", P.IMPORTANT) -- When a bot is heading to use a role checker.
    Line("I'm going to use the role checker.", A.Default)
    Line("Heading to the role checker.", A.Default)
    Line("I'm going to report in to the role checker.", A.Default)
    Line("I'm going to check my role.", A.Default)
    Line("using the role checker", A.Casual)
    Line("gonna check my role", A.Casual)
    Line("role checker time", A.Casual)
    Line("checking my role", A.Casual)
    Line("Going to do my bit and check my role.", A.Nice)
    Line("I'm going to check my role now.", A.Stoic)
    Line("FINE, ILL GO TO THE ROLE CHECKER", A.Hothead)
    Line("I'm going to check my role, okay?", A.Bad)
    Line("I'm going to check my role, team.", A.Teamer)
    Line("I'm going to check my role, wish me luck.", A.Tryhard)
    Line("Role Checker? You can't make me but I'll go anyway", A.Sus)

    RegisterCategory("OracleReveal", P.IMPORTANT) -- When a bot is revealing two players's possible team (one of them is the team name and the other is a random name). Args are {{name1}}, {{name2}}, {{team}}
    Line("{{name1}} or {{name2}} is on the {{team}} team.", A.Default)
    Line("sweet, looks like {{name1}} or {{name2}} is on the {{team}} team", A.Casual)
    Line("{{name1}} or {{name2}} is on the {{team}} team, interesting", A.Nice)
    Line("Consulting my Oracular powers, I see that {{name1}} or {{name2}} is on the {{team}} team.", A.Stoic)
    Line("Those Idiots {{name1}} or {{name2}} are on the {{team}} team.", A.Hothead)
    Line("{{name1}} or {{name2}} is on the {{team}} team, what a surprise", A.Bad)
    Line("Coolio, {{name1}} or {{name2}} is on the {{team}} team", A.Teamer)
    Line("uhh, i'm not sure but {{team}} might have {{name1}} or {{name2}}", A.Dumb)
    Line("{{name1}} or {{name2}} is on the {{team}} team, I think", A.Sus)

    RegisterCategory("ClairvoyantReveal", P.IMPORTANT) -- When a bot is revealing a player's role as special. Args are {{name}}
    Line("{{name}} is a special role.", A.Default)

    RegisterCategory("CeaseFireStart", P.IMPORTANT) -- When a bot is accepting a request to cease fire.
    Line("I'll stop shooting.", A.Default)
    Line("I'll stop shooting, {{player}}.", A.Default)
    Line("I'll stop shooting, okay?", A.Default)

    RegisterCategory("CeaseFireRefuse", P.IMPORTANT) -- When a bot is refusing a request to cease fire.
    Line("I'm not stopping.", A.Default)
    Line("I'm not stopping, {{player}}.", A.Default)
    Line("I'm not stopping, okay?", A.Default)

    RegisterCategory("HealAccepted", P.IMPORTANT) -- When a bot is accepting a request for them to heal you
    Line("I'll heal you.", A.Default)
    Line("I'll heal you, {{player}}.", A.Default)
    Line("I'll heal you, okay?", A.Default)

    RegisterCategory("HealRefused", P.IMPORTANT) -- When a bot is refusing a request for them to heal you
    Line("I'm not healing you.", A.Default)
    Line("I'm not healing you, {{player}}.", A.Default)
    Line("I'm not healing you, okay?", A.Default)

    RegisterCategory("ReviveAccepted", P.IMPORTANT) -- When a bot is accepting a request for them to revive you
    Line("I'll revive {{player}}.", A.Default)
    Line("I'll revive {{player}}, okay?", A.Default)
    Line("I'll revive {{player}} for you.", A.Default)

    RegisterCategory("ReviveRefused", P.IMPORTANT) -- When a bot is refusing a request for them to revive you
    Line("I'm not reviving {{player}}.", A.Default)
    Line("I'm not reviving {{player}}, okay?", A.Default)
    Line("I'm not reviving {{player}} for you.", A.Default)

    RegisterCategory("JihadBombWarn", P.IMPORTANT) -- When a bot is warning their team about the jihad bomb (Team Only).
    Line("Guys, watch out! Using a Jihad!", A.Default)
    Line("RUN! GET OUT OF HERE! JIHAD!", A.Default)
    Line("It's been fun, but I'm going out with a bang!", A.Default)
    Line("I'm going to blow up, get away!", A.Default)

    RegisterCategory("JihadBombUse", P.IMPORTANT) -- When a bot is about to set off a suicide bomb.
    Line("May God Help you all", A.Default)
    Line("Fuck you all!", A.Default)
    Line("I misclicked, don't run!", A.Default)
    Line("Hahahahahahaha", A.Default)

    RegisterCategory("DroppingContract", P.CRITICAL) --- When a bot is dropping a contract to another player.
    Line("Pick up the contract I've just dropped for you {{player}}!", A.Default)
    Line("Freeze {{player}}, I've dropped a contract to you!", A.Default)
    Line("Oi Dickhead fucking stop so I can give you a contract", A.Hothead)
    Line("yo yo hold up one sec lemme give you a contract", A.Casual)
    Line("Hey beautiful, let me give you a present!", A.Nice)
    Line("Yo lets make my team and your team allies {{player}}", A.Teamer)

    RegisterCategory("NewContract", P.IMPORTANT) --- When a bot has joined a player's team.
    Line("{{player}}, we're on your side now", A.Default)
    Line("Hey fuckhead, try not to shoot us now we're on your team!", A.Hothead)

    RegisterCategory("SwappingRole", P.IMPORTANT) --- When a bot is trying to swap roles with you, they will pretend to be a mimic.
    Line("{{player}} stand still, don't be alarmed!", A.Default)
    Line("I'm definitely a mimic {{player}}, please stand still and let me copy your role!", A.Sus)
    Line("Stand still fucking {{player}} I don't want to be this fucking role anymore!", A.Hothead)
    Line("{{player}}, be still, it will all be over soon.", A.Stoic)
    Line("Hey don't shoot, I want to join your team!", A.Teamer)
    Line("yo stand still {{player}} i wanna show you somethin", A.Casual)

    RegisterCategory("CopyingRole", P.IMPORTANT) --- When a bot is trying to copy roles with you
    Line("{{player}} stand still, I want to copy your role!", A.Default)
    Line("I'm definitely a mimic {{player}}, please stand still and let me copy your role!", A.Sus)
    Line("Oi, Don't shoot me you moron, I'm trying to copy your role {{player}}!", A.Hothead)
    Line("{{player}}, be still, it will all be over soon.", A.Stoic)
    Line("Hey don't shoot {{player}}, I want to join your team!", A.Teamer)
    Line("yo stand still {{player}} your role seems cool", A.Casual)


    -----------------------------------------------------------
    -- TRAITOROUS ACTIONS
    -----------------------------------------------------------

    RegisterCategory("BombArmed", P.CRITICAL)
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


    RegisterCategory("LifeCheck", P.IMPORTANT) -- Response to "life check" or "lc" in chat.
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


    -----------------------------------------------------------
    -- SILLY CHATS
    -----------------------------------------------------------

    RegisterCategory("SillyChat", P.NORMAL) -- When a bot is chatting randomly.
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
    RegisterCategory("DialogGreetNext", P.NORMAL)
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

    RegisterCategory("DialogGreetLast", P.NORMAL)
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

    RegisterCategory("DialogHowAreYou", P.NORMAL)
    Line("How are you?")
    Line("How are you doing, {{nextBot}}?")
    Line("How's it going?")
    Line("How's life treating you?")
    Line("How's it hanging?")
    Line("How's it going, {{nextBot}}?")
    Line("hru", A.Casual)
    Line("how r u", A.Casual)
    Line("how's it goin'", A.Casual)

    RegisterCategory("DialogWhatsUp", P.NORMAL)
    Line("what did you do today", A.Casual)
    Line("What did you do today?")
    Line("What's up?")
    Line("wsg", A.Casual)
    Line("whats up?", A.Casual)

    RegisterCategory("DialogHowAreYouResponse", P.NORMAL)
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

    RegisterCategory("DialogWhatsUpResponse", P.NORMAL)
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

    RegisterCategory("DialogAnyoneBored", P.NORMAL)
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

    RegisterCategory("DialogNegativeResponse", P.NORMAL)
    Line("Nope")
    Line("Nah")
    Line("Not really")
    Line("Not much")
    Line("Not a whole lot")

    RegisterCategory("DialogPositiveResponse", P.NORMAL)
    Line("Yeah")
    Line("Yep")
    Line("Sure")
    Line("Mhm")
    Line("Yup")
    Line("Yeah, I guess")
    Line("I suppose")
    Line("I guess")

    RegisterCategory("DialogRudeResponse", P.NORMAL)
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
end

local DEPENDENCIES = { "Plans" }
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadLang()
end
timer.Simple(1, loadModule_Deferred)
