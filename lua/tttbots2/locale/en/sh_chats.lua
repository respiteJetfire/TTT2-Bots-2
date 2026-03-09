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
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end
    local f = string.format
    local ACTS = TTTBots.Plans.ACTIONS

    -----------------------------------------------------------
    -- ENTRANCE/EXIT FROM SERVER
    -----------------------------------------------------------


    RegisterCategory("DisconnectBoredom", P.CRITICAL, "When a bot is bored and sends a message when leaving the server.")
    Line("I'm bored. Bye.",  A.Default)
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


    RegisterCategory("DisconnectRage", P.CRITICAL, "When a bot is angry and sends a message when leaving the server.")
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


    RegisterCategory("ServerConnected", P.NORMAL, "When a bot joins the server they will send a message to announce it.")
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

    RegisterCategory("DisguisedPlayer", P.IMPORTANT, "When a bot spots a disguised player they will announce it or tell the disguised player.")
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

    RegisterCategory("DeclareSuspicious", P.IMPORTANT, "When a bot finds another {{player}} suspicious they will tell the {{player}} or everyone else.")
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

    RegisterCategory("DeclareInnocent", P.IMPORTANT, "When a bot slightly trusts another {{player}} they will tell them or everyone else.")
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

    RegisterCategory("DeclareTrustworthy", P.IMPORTANT, "When a bot trusts another {{player}} they will tell them or everyone else.")
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
    RegisterCategory("Kill", P.CRITICAL, "When a bot witnesses {{victim}} being killed by {{attacker}} they will report this.")
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
    RegisterCategory("FollowMe", P.NORMAL, "When a bot is asked to follow the player, named {{target}}, they will respond affirmatively.")
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

    RegisterCategory("FollowMeRefuse", P.IMPORTANT, "When a bot refuses to follow the player, named {{target}}, they will respond negatively.")
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


    RegisterCategory("FollowMeEnd", P.NORMAL, "When a bot decides to stop following the player, named {{target}}, they will announce this.")
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
    RegisterCategory("WaitStart", P.NORMAL, "When a bot is asked to wait for the player, named {{target}}, they will respond affirmatively.")
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
    RegisterCategory("WaitRefuse", P.IMPORTANT, "When a bot refuses to wait for the player, named {{target}}, they will respond negatively.")
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

    RegisterCategory("WaitEnd", P.NORMAL, "When a bot decides to stop waiting for the player, named {{target}}, they will announce this.")
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

    RegisterCategory("ComeHereStart", P.NORMAL, "When a bot is asked to come to the player, named {{target}}, they will respond affirmatively.")
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

    RegisterCategory("ComeHereRefuse", P.IMPORTANT, "When a bot refuses to come to the player, named {{target}}, vary sentence structure massively")
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

    RegisterCategory("ComeHereEnd", P.NORMAL, "When a bot decides to stop coming to the player, named {{target}}, they will announce this.")
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
    RegisterCategory("AttackStart", P.CRITICAL, "When a bot is asked to attack the player, named {{target}} they will respond affirmatively.")
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
    RegisterCategory("AttackRefuse", P.IMPORTANT, "When a bot refuses to attack the player, named {{target}}")
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

    RegisterCategory("AttackEnd", P.NORMAL, "When a bot decides to stop attacking the player, named {{target}}, they will announce this.")
    Line("I'm done attacking.", A.Default)
    Line("I'm moving now.", A.Default)
    Line("I'm not attacking anymore.", A.Default)

    RegisterCategory("RoleCheckerRequestAccepted", P.NORMAL, "When a bot is asked to use the role checker to reveal their role to the player, named {{target}}.")
    Line("Sure, I'll show you my role {{target}}.", A.Default)
    Line("I'll show you my role, {{target}}.", A.Default)
    Line("I'll reveal my role to you, {{target}}.", A.Default)
    Line("Yes.", A.Default)


    RegisterCategory("RoleCheckerRequestRefused", P.IMPORTANT, "When a bot refuses to use the role checker to reveal their role to the player, named {{target}}.")
    Line("I can't show you my role, {{target}}.", A.Default)
    Line("I'm not showing you my role, {{target}}.", A.Default)
    Line("I'm not revealing my role to you, {{target}}.", A.Default)

    RegisterCategory("CallKOS", P.CRITICAL, "When a bot calls KOS on a {{player}} They will announce it.")
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
    RegisterCategory(f("Plan.%s", ATTACKANY), P.CRITICAL, "When a bot is going to attack {{player}} as planned.")
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
    RegisterCategory(f("Plan.%s", ATTACK), P.CRITICAL, "When a bot is going to attack {{player}} as planned.")
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
    RegisterCategory(f("Plan.%s", PLANT), P.CRITICAL, "When a traitor bot is going to plant a C4 bomb.")
    Line("I'm going to plant a bomb.", A.Default)
    Line("I'm planting a bomb.", A.Default)
    Line("Placing a bomb!", A.Default)
    Line("Gonna rig this place to blow.", A.Default)

    local DEFUSE = ACTS.DEFUSE
    RegisterCategory(f("Plan.%s", DEFUSE), P.CRITICAL, "When a traitor bot is going to defuse a C4 bomb.")
    Line("I'm going to defuse a bomb.", A.Default)

    local FOLLOW = ACTS.FOLLOW
    RegisterCategory(f("Plan.%s", FOLLOW), P.CRITICAL, "When a traitor bot is going to follow another {{player}}.")
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
    RegisterCategory(f("Plan.%s", GATHER), P.CRITICAL, "When a bot is asking other bots to come here.")
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
    RegisterCategory(f("Plan.%s", DEFEND), P.CRITICAL, "When a bot is going to defend an area.")
    Line("I'm going to defend this area.", A.Default)

    local ROAM = ACTS.ROAM
    RegisterCategory(f("Plan.%s", ROAM), P.CRITICAL, "When a bot is going to roam around.")
    Line("I'm going to roam around for a bit.", A.Default)

    local IGNORE = ACTS.IGNORE
    RegisterCategory(f("Plan.%s", IGNORE), P.CRITICAL, "When a bot is going to ignore the player.")
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

    RegisterCategory("FollowRequest", P.CRITICAL, "When a bot is asked to follow the player, named {{player}}")
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


    RegisterCategory("FollowStarted", P.NORMAL, "When a bot starts following the player, named {{player}}")
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

    RegisterCategory("PersonalSpace", P.IMPORTANT, "When a bot is asked to give the {{player}} some personal space.")
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


    RegisterCategory("InvestigateCorpse", P.IMPORTANT, "When a bot finds a dead body and wants to investigate it.")
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

    RegisterCategory("InvestigateNoise", P.NORMAL, "When a bot hears a noise and wants to investigate it.")
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

    RegisterCategory("HoldingTraitorWeapon", P.IMPORTANT, "When a bot sees another {{player}} holding a traitor weapon.")
    Line("{{player}} is holding a traitor weapon!", A.Default)
    Line("traitor weapon on {{player}}", A.Casual)
    Line("hey he's holding a traitor weapon", A.Casual)

    RegisterCategory("SpottedC4", P.CRITICAL, "When a bot sees a C4 bomb.")
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

    RegisterCategory("DefusingC4", P.IMPORTANT, "When a bot is defusing a C4 bomb.")
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

    RegisterCategory("DefusingSuccessful", P.IMPORTANT, "When a bot successfully defuses a C4 bomb.")
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

    RegisterCategory("RevivingPlayer", P.IMPORTANT, "When a bot is reviving a {{player}}.")
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

    RegisterCategory("CreatingDoctor", P.IMPORTANT, "When a bot is creating a doctor named {{player}}.")
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

    RegisterCategory("CreatingDeputy", P.IMPORTANT, "When a bot is creating a deputy named {{player}}.")
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

    RegisterCategory("CreatingCursed", P.IMPORTANT, "When a bot is converting a role to a Cursed for a player named {{player}} they will announce it to their teammates.")
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

    RegisterCategory("CreatingDefector", P.IMPORTANT, "When a bot is creating a defector (Team Only).")
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

    RegisterCategory("CreatingSidekick", P.IMPORTANT, "When a bot is creating a sidekick (Team Only).")
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

    RegisterCategory("CreatingMedic", P.IMPORTANT, "When a bot is creating a medic (Team Only).")
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

    RegisterCategory("RoleDefibPlayer", P.IMPORTANT, "When a bot is reviving a player with a role defibrillator.")
    Line("I'm reviving {{player}} with a role defibrillator.", A.Default)
    Line("Reviving {{player}} with a role defibrillator.", A.Casual)
    Line("Bringing {{player}} back to life with a role defibrillator.", A.Nice)
    Line("{{player}} is getting revived with a role defibrillator.", A.Stoic)
    

    RegisterCategory("UsingRoleChecker", P.IMPORTANT, "When a bot is using the role checker.")
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

    RegisterCategory("OracleReveal", P.IMPORTANT, "When a bot is revealing two players' possible team (one of them is the team name and the other is a random name). Args are {{name1}}, {{name2}}, {{team}}")
    Line("{{name1}} or {{name2}} is on the {{team}} team.", A.Default)
    Line("sweet, looks like {{name1}} or {{name2}} is on the {{team}} team", A.Casual)
    Line("{{name1}} or {{name2}} is on the {{team}} team, interesting", A.Nice)
    Line("Consulting my Oracular powers, I see that {{name1}} or {{name2}} is on the {{team}} team.", A.Stoic)
    Line("Those Idiots {{name1}} or {{name2}} are on the {{team}} team.", A.Hothead)
    Line("{{name1}} or {{name2}} is on the {{team}} team, what a surprise", A.Bad)
    Line("Coolio, {{name1}} or {{name2}} is on the {{team}} team", A.Teamer)
    Line("uhh, i'm not sure but {{team}} might have {{name1}} or {{name2}}", A.Dumb)
    Line("{{name1}} or {{name2}} is on the {{team}} team, I think", A.Sus)

    RegisterCategory("ClairvoyantReveal", P.IMPORTANT, "When a bot is revealing a player's role as a special role (this could be good or bad). Args are {{name}}")
    Line("{{name}} is a special role.", A.Default)
    Line("{{name}} is a special role, interesting", A.Casual)
    Line("you got anything to hide, {{name}}?", A.Nice)


    RegisterCategory("CeaseFireStart", P.IMPORTANT, "When a bot is stopping shooting.")
    Line("I'll stop shooting.", A.Default)
    Line("I'll stop shooting, {{player}}.", A.Default)
    Line("I'll stop shooting, okay?", A.Default)

    RegisterCategory("CeaseFireRefuse", P.IMPORTANT, "When a bot is refusing to stop shooting.")
    Line("I'm not stopping.", A.Default)
    Line("I'm not stopping, {{player}}.", A.Default)
    Line("I'm not stopping, okay?", A.Default)

    RegisterCategory("HealAccepted", P.IMPORTANT, "When a bot is accepting a request for them to heal someone")
    Line("I'll heal you.", A.Default)
    Line("I'll heal you, {{player}}.", A.Default)
    Line("I'll heal you, okay?", A.Default)

    RegisterCategory("HealRefused", P.IMPORTANT, "When a bot is refusing a request for them to heal someone")
    Line("I'm not healing you.", A.Default)
    Line("I'm not healing you, {{player}}.", A.Default)
    Line("I'm not healing you, okay?", A.Default)

    RegisterCategory("ReviveAccepted", P.IMPORTANT, "When a bot is accepting a request for them to revive {{player}}")
    Line("I'll revive {{player}}.", A.Default)
    Line("I'll revive {{player}}, okay?", A.Default)
    Line("I'll revive {{player}} for you.", A.Default)

    RegisterCategory("ReviveRefused", P.IMPORTANT, "When a bot is refusing a request for them to revive {{player}}")
    Line("I'm not reviving {{player}}.", A.Default)
    Line("I'm not reviving {{player}}, okay?", A.Default)
    Line("I'm not reviving {{player}} for you.", A.Default)

    RegisterCategory("JihadBombWarn", P.IMPORTANT, "When a bot is warning themselves using a Jihad bomb.")
    Line("Guys, watch out! Using a Jihad!", A.Default)
    Line("RUN! GET OUT OF HERE! JIHAD!", A.Default)
    Line("It's been fun, but I'm going out with a bang!", A.Default)
    Line("I'm going to blow up, get away!", A.Default)

    RegisterCategory("JihadBombUse", P.IMPORTANT, "When a bot is using a Jihad bomb")
    Line("May God Help you all", A.Default)
    Line("Fuck you all!", A.Default)
    Line("I misclicked, don't run!", A.Default)
    Line("Hahahahahahaha", A.Default)

    RegisterCategory("UseTraitorButton", P.IMPORTANT, "When a bot activates a traitor button")
    Line("Heh, that should ruin their day.", A.Default)
    Line("Button pressed. Enjoy the chaos.", A.Default)
    Line("Time to press the big red button.", A.Hothead)
    Line("yo i just hit the button lmao", A.Casual)
    Line("That should take care of a few of them.", A.Nice)

    RegisterCategory("DroppingContract", P.CRITICAL, "When a bot is dropping a contract to {{player}} so they can join {{player}}'s team")
    Line("Pick up the contract I've just dropped for you {{player}}!", A.Default)
    Line("Freeze {{player}}, I've dropped a contract to you!", A.Default)
    Line("Oi Dickhead fucking stop so I can give you a contract", A.Hothead)
    Line("yo yo hold up one sec lemme give you a contract", A.Casual)
    Line("Hey beautiful, let me give you a present!", A.Nice)
    Line("Yo lets make my team and your team allies {{player}}", A.Teamer)

    RegisterCategory("NewContract", P.IMPORTANT, "When a bot is offering a new contract to a {{player}}.")
    Line("{{player}}, we're on your side now", A.Default)
    Line("Hey fuckhead, try not to shoot us now we're on your team!", A.Hothead)

    RegisterCategory("SwappingRole", P.IMPORTANT, "When a Cursed bot wants to swap roles with {{player}}")
    Line("{{player}} stand still, don't be alarmed!", A.Default)
    Line("come here {{player}}", A.Default)
    Line("{{player}}, I need your role!", A.Default)
    Line("yo {{player}}, wait up, I'm swapping with you.", A.Casual)
    Line("{{player}}, hold up a sec!", A.Casual)
    Line("{{player}}, gotta swap roles real quick.", A.Nice)
    Line("{{player}}, don't move. Swapping roles.", A.Stoic)
    Line("GET OVER HERE {{player}}! I need your role!", A.Hothead)
    Line("{{player}}, just hold still and it'll be over.", A.Bad)
    Line("{{player}}, for the good of the team, give me your role!", A.Teamer)
    Line("{{player}}, swapping with you. Optimal play.", A.Tryhard)
    Line("{{player}}, don't worry... I just want to talk.", A.Sus)
    Line("{{player}}, wait up! I wanna be friends!", A.Dumb)

    RegisterCategory("CopyingRole", P.IMPORTANT, "When a bot is copying another {{player}}'s role.")
    Line("{{player}}, wait up!", A.Default)
    Line("hold up {{player}}", A.Default)
    Line("{{player}}, copying your role.", A.Default)
    Line("{{player}}, hold still, copying your role.", A.Default)
    Line("{{player}}, don't move, mimicking you.", A.Default)
    Line("{{player}}, taking your role.", A.Default)
    Line("{{player}}, stay put, copying your role.", A.Default)
    Line("{{player}}, gonna mimic your role.", A.Default)
    Line("{{player}}, wait up, copying your role.", A.Default)
    Line("{{player}}, I'm becoming you.", A.Default)

    -----------------------------------------------------------
    -- CURSED ROLE CHATTER
    -----------------------------------------------------------

    -- When a bot receives the Cursed role (round start or mid-round swap)
    RegisterCategory("CursedRoleReceived", P.IMPORTANT, "When a bot receives the Cursed role.")
    Line("Oh no, I'm cursed!", A.Default)
    Line("Great, I'm cursed... someone come here.", A.Default)
    Line("I've been cursed! I need to find someone to swap with.", A.Default)
    Line("ugh, i'm cursed. this sucks", A.Casual)
    Line("bruh i got cursed lol", A.Casual)
    Line("I'm so sorry everyone, I'm cursed now.", A.Nice)
    Line("I've been afflicted with the curse.", A.Stoic)
    Line("WHO CURSED ME?! I'M GONNA GET YOU BACK!", A.Hothead)
    Line("Great, I'm cursed. Just my luck.", A.Bad)
    Line("I'm cursed! Someone help me out here!", A.Teamer)
    Line("Cursed role. Need to swap ASAP.", A.Tryhard)
    Line("I'm totally not cursed... don't run.", A.Sus)
    Line("Ooh I'm cursed! What does that mean?", A.Dumb)

    -- When a Cursed bot successfully swaps roles with someone
    RegisterCategory("CursedSwapSuccess", P.IMPORTANT, "When a Cursed bot successfully swaps with {{player}}.")
    Line("Ha! Have fun being cursed, {{player}}!", A.Default)
    Line("Sorry {{player}}, better you than me!", A.Default)
    Line("I'm free! Thanks {{player}}!", A.Default)
    Line("lol bye {{player}}, enjoy the curse", A.Casual)
    Line("seeya {{player}} haha", A.Casual)
    Line("Sorry {{player}}, I had to do it!", A.Nice)
    Line("The curse has been passed.", A.Stoic)
    Line("HAHA! {{player}} IS CURSED NOW!", A.Hothead)
    Line("Later, {{player}}! Sucker!", A.Bad)
    Line("Swapped with {{player}}! Let's go team!", A.Teamer)
    Line("Swap complete. I'm back in the game.", A.Tryhard)
    Line("Oh {{player}}, I didn't mean to do that...", A.Sus)
    Line("Wait, did I just give {{player}} the curse? Oops!", A.Dumb)

    -- When a Cursed bot is chasing/approaching a swap target
    RegisterCategory("CursedChasing", P.NORMAL, "When a Cursed bot is approaching {{player}} to swap.")
    Line("Hold still {{player}}!", A.Default)
    Line("Come here {{player}}, I just want to talk!", A.Default)
    Line("{{player}}, don't run!", A.Default)
    Line("yo {{player}} come back here", A.Casual)
    Line("{{player}} wait up dude", A.Casual)
    Line("{{player}}, please don't run, I need your help!", A.Nice)
    Line("Approaching target.", A.Stoic)
    Line("GET BACK HERE {{player}}!", A.Hothead)
    Line("{{player}}, stop running you coward!", A.Bad)
    Line("{{player}}, take one for the team!", A.Teamer)
    Line("Closing distance on {{player}}.", A.Tryhard)
    Line("{{player}}, I'm not gonna hurt you... I promise.", A.Sus)
    Line("{{player}}! I wanna give you a hug!", A.Dumb)

    -- When a Cursed bot fires the RoleSwap Deagle
    RegisterCategory("CursedDeagleFired", P.NORMAL, "When a Cursed bot fires the RoleSwap Deagle.")
    Line("Don't dodge!", A.Default)
    Line("Tag, you're it!", A.Default)
    Line("Swap deagle, baby!", A.Default)
    Line("yeet", A.Casual)
    Line("pew pew swap time", A.Casual)
    Line("Sorry, I have to shoot!", A.Nice)
    Line("Firing RoleSwap Deagle.", A.Stoic)
    Line("EAT DEAGLE!", A.Hothead)
    Line("Enjoy the curse!", A.Bad)
    Line("Deagle shot for the team!", A.Teamer)
    Line("Optimal target acquired. Firing.", A.Tryhard)
    Line("Oops, my finger slipped!", A.Sus)
    Line("Is this how you use this thing?", A.Dumb)

    -- When a Cursed bot respawns after dying
    RegisterCategory("CursedRespawned", P.NORMAL, "When a Cursed bot respawns after dying.")
    Line("I'm back!", A.Default)
    Line("You can't get rid of me that easily!", A.Default)
    Line("The curse brings me back!", A.Default)
    Line("im back lol", A.Casual)
    Line("respawned, time to find someone", A.Casual)
    Line("I'm alive again! Let's try this again.", A.Nice)
    Line("Respawned. Resuming objective.", A.Stoic)
    Line("I'M BACK AND I'M ANGRY!", A.Hothead)
    Line("Miss me? Didn't think so.", A.Bad)
    Line("Back in action, team!", A.Teamer)
    Line("Respawn timer expired. Re-engaging.", A.Tryhard)
    Line("Did you guys miss me? No? Okay.", A.Sus)
    Line("Woah, I'm alive again! Cool!", A.Dumb)

    -- When a Cursed bot can't tag someone due to no-backsies
    RegisterCategory("CursedNoBacksies", P.NORMAL, "When a Cursed bot hits the no-backsies restriction.")
    Line("Ugh, no backsies...", A.Default)
    Line("I can't tag them back yet!", A.Default)
    Line("No backsies! I need to find someone else.", A.Default)
    Line("dang, no backsies", A.Casual)
    Line("cant swap back, need another target", A.Casual)
    Line("Oh no, I can't swap with them yet.", A.Nice)
    Line("Backsies protection active. Seeking new target.", A.Stoic)
    Line("WHAT?! NO BACKSIES?! UGH!", A.Hothead)
    Line("Stupid no-backsies rule...", A.Bad)
    Line("Can't swap back. Finding another target.", A.Teamer)
    Line("No-backsies timer active. Retargeting.", A.Tryhard)
    Line("That's... convenient for them.", A.Sus)
    Line("Why can't I tag them? That's unfair!", A.Dumb)

    -- When a Cursed bot can't tag a Detective
    RegisterCategory("CursedCantTagDet", P.NORMAL, "When a Cursed bot can't tag a Detective.")
    Line("I can't curse a Detective!", A.Default)
    Line("Detectives are protected...", A.Default)
    Line("damn, can't tag detectives", A.Casual)
    Line("That's a Detective, I can't swap with them.", A.Nice)
    Line("Target is Detective-class. Protected.", A.Stoic)
    Line("WHY CAN'T I TAG THE DETECTIVE?!", A.Hothead)
    Line("Of course the detective is protected...", A.Bad)
    Line("Can't tag detectives. Need a different target.", A.Teamer)
    Line("Detective protection active. Adjusting.", A.Tryhard)
    Line("The detective seems... immune to me.", A.Sus)
    Line("I tried to tag the detective but nothing happened!", A.Dumb)

    -- When the round is late and the Cursed is desperate
    RegisterCategory("CursedDesperateLate", P.IMPORTANT, "When the round is late and the Cursed is desperate to swap.")
    Line("I need to curse someone NOW!", A.Default)
    Line("Running out of time!", A.Default)
    Line("I'm running out of options!", A.Default)
    Line("oh god oh god i need to swap quick", A.Casual)
    Line("SOMEONE PLEASE LET ME TAG YOU", A.Casual)
    Line("Please, someone, I need to swap before it's too late!", A.Nice)
    Line("Time is running out. Must swap immediately.", A.Stoic)
    Line("SOMEONE GET OVER HERE RIGHT NOW!", A.Hothead)
    Line("I'm screwed if I don't swap NOW!", A.Bad)
    Line("Team, I need someone to swap with urgently!", A.Teamer)
    Line("Critical: must execute swap before round end.", A.Tryhard)
    Line("Haha, I'm fine, everything's fine...", A.Sus)
    Line("Wait, do I lose if I don't swap? HELP!", A.Dumb)

    -- When a Cursed bot self-immolates
    RegisterCategory("CursedSelfImmolate", P.NORMAL, "When a Cursed bot self-immolates.")
    Line("AAAGH! *sets self on fire*", A.Default)
    Line("Burning myself for a fresh start!", A.Default)
    Line("lmao im on fire", A.Casual)
    Line("Sorry, I had to burn myself.", A.Nice)
    Line("Self-immolation initiated.", A.Stoic)
    Line("BURN BABY BURN!", A.Hothead)
    Line("Time to make some ashes.", A.Bad)
    Line("Burning for the team!", A.Teamer)
    Line("Strategic immolation executed.", A.Tryhard)
    Line("Don't mind me, just... on fire.", A.Sus)
    Line("Ooh, pretty flames!", A.Dumb)

    -- When another bot spots a Cursed player
    RegisterCategory("CursedSpotted", P.IMPORTANT, "When a bot spots a known Cursed player {{player}}.")
    Line("Watch out, {{player}} is Cursed!", A.Default)
    Line("Cursed player spotted!", A.Default)
    Line("{{player}} is the Cursed, stay away!", A.Default)
    Line("yo {{player}} is cursed, run", A.Casual)
    Line("heads up, {{player}} is cursed", A.Casual)
    Line("Everyone be careful, {{player}} is Cursed!", A.Nice)
    Line("Cursed identified: {{player}}.", A.Stoic)
    Line("{{player}} IS CURSED! DON'T LET THEM NEAR YOU!", A.Hothead)
    Line("{{player}} is cursed. Not my problem.", A.Bad)
    Line("Team, watch out for {{player}}, they're Cursed!", A.Teamer)
    Line("Cursed player {{player}} identified. Avoid contact.", A.Tryhard)
    Line("Is {{player}} cursed? I think they are...", A.Sus)
    Line("{{player}} looks... different. Are they cursed?", A.Dumb)

    -- When the Cursed is approaching another bot
    RegisterCategory("CursedApproachingMe", P.CRITICAL, "When the Cursed player is approaching this bot.")
    Line("Stay away from me!", A.Default)
    Line("The Cursed is coming for me!", A.Default)
    Line("Don't come any closer!", A.Default)
    Line("oh no the cursed is coming for me", A.Casual)
    Line("nope nope nope stay back", A.Casual)
    Line("Please don't curse me!", A.Nice)
    Line("Cursed player approaching. Evading.", A.Stoic)
    Line("GET AWAY FROM ME CURSED!", A.Hothead)
    Line("Touch me and I'll end you. Oh wait...", A.Bad)
    Line("Help! The Cursed is after me!", A.Teamer)
    Line("Cursed player in proximity. Maintaining distance.", A.Tryhard)
    Line("Why are you walking toward me like that...", A.Sus)
    Line("Are you trying to tag me? That's not nice!", A.Dumb)

    -- When a bot can't damage the Cursed
    RegisterCategory("CursedCantDamage", P.NORMAL, "When a bot tries to damage the Cursed and fails.")
    Line("I can't hurt them!", A.Default)
    Line("The Cursed is immune!", A.Default)
    Line("My shots aren't doing anything!", A.Default)
    Line("bro is unkillable wtf", A.Casual)
    Line("my shots aint doing jack", A.Casual)
    Line("I can't damage them, they're immune!", A.Nice)
    Line("Damage output: zero. Target is immune.", A.Stoic)
    Line("WHY WON'T YOU DIE?!", A.Hothead)
    Line("Waste of ammo on that freak.", A.Bad)
    Line("Team, don't bother shooting the Cursed!", A.Teamer)
    Line("Confirmed: Cursed has damage immunity.", A.Tryhard)
    Line("Interesting... they can't be hurt.", A.Sus)
    Line("Why aren't my bullets working?!", A.Dumb)

    -- When a bot witnesses a role swap
    RegisterCategory("CursedSwappedWithSomeone", P.IMPORTANT, "When a bot witnesses {{player1}} cursing {{player2}}.")
    Line("They just swapped roles!", A.Default)
    Line("{{player1}} cursed {{player2}}!", A.Default)
    Line("Did you see that? They swapped!", A.Default)
    Line("yo they just swapped roles", A.Casual)
    Line("{{player1}} tagged {{player2}} lol", A.Casual)
    Line("Oh no, {{player2}} just got cursed!", A.Nice)
    Line("Role swap observed: {{player1}} → {{player2}}.", A.Stoic)
    Line("{{player1}} JUST CURSED {{player2}}!", A.Hothead)
    Line("Ha, {{player2}} got cursed. Sucks to be them.", A.Bad)
    Line("Watch out, {{player2}} is the new Cursed!", A.Teamer)
    Line("Swap confirmed. {{player2}} is now Cursed.", A.Tryhard)
    Line("Something weird just happened between {{player1}} and {{player2}}...", A.Sus)
    Line("Wait, did {{player1}} just curse {{player2}}? Whoa!", A.Dumb)

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
    RegisterCategory("BeingShotAt", P.IMPORTANT, "Bot is being shot at and reacts before fighting back")
    Line("Hey! Who's shooting at me?!", A.Default)
    Line("Stop shooting! Who is that?!", A.Default)
    Line("I'm getting shot! Show yourself!", A.Default)

    Line("WHO THE HELL IS SHOOTING AT ME", A.Hothead)
    Line("STOP IT! I WILL KILL YOU!", A.Hothead)

    Line("ayo who's shooting lmao", A.Casual)
    Line("yo stop shooting at me bro wtf", A.Casual)

    Line("Hostile fire detected. Identifying shooter.", A.Stoic)
    Line("Taking fire. Assessing threat.", A.Stoic)

    Line("ow!! stop that!! who's doing that!!", A.Dumb)
    Line("hey that hurts!! cut it out!!", A.Dumb)

    Line("Please stop shooting! I'm innocent!", A.Nice)
    Line("Hey, easy! I haven't done anything!", A.Nice)

    Line("You're shooting at the wrong person.", A.Tryhard)
    Line("Wasting ammo on me? Bold move.", A.Tryhard)

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

    -----------------------------------------------------------
    -- INFECTED ROLE EVENTS
    -----------------------------------------------------------

    RegisterCategory("ZombieSpotted", P.CRITICAL, "When a bot sees {{player}} get converted into an infected zombie.")
    Line("{{player}} just turned into a zombie!", A.Default)
    Line("{{player}} got infected! Watch out!", A.Default)
    Line("They got {{player}}! They're one of them now!", A.Default)
    Line("{{player}} is a zombie now, stay away!", A.Default)

    Line("bro {{player}} just turned into a zombie wtf", A.Casual)
    Line("yo {{player}} got infected lol", A.Casual)
    Line("{{player}} is a zombie now omg", A.Casual)
    Line("rip {{player}} they're infected", A.Casual)

    Line("{{player}} has been converted. Eliminate immediately.", A.Tryhard)
    Line("{{player}} is compromised. New threat active.", A.Tryhard)
    Line("Infection confirmed on {{player}}. Adjusting priorities.", A.Tryhard)

    Line("{{player}} JUST TURNED INTO A ZOMBIE!! KILL THEM!", A.Hothead)
    Line("WHAT THE HELL?! {{player}} is a zombie now!", A.Hothead)
    Line("Are you kidding me?! {{player}} got infected!", A.Hothead)

    Line("{{player}} is now a zombie.", A.Stoic)
    Line("Noted: {{player}} has been infected.", A.Stoic)
    Line("{{player}} has turned. Proceeding accordingly.", A.Stoic)

    Line("Oh no! {{player}} got infected! We have to help them!", A.Nice)
    Line("Poor {{player}}... they got turned into a zombie.", A.Nice)
    Line("{{player}} is infected now! Stay safe everyone!", A.Nice)

    Line("Heh, {{player}} got what they deserved.", A.Bad)
    Line("{{player}} is a zombie now. Not my problem.", A.Bad)
    Line("That's what happens when you're not careful, {{player}}.", A.Bad)

    Line("I KNEW {{player}} was going to turn. I could feel it.", A.Sus)
    Line("{{player}} is a zombie... interesting. Very interesting.", A.Sus)
    Line("Watch out, {{player}} just turned. Who's next?", A.Sus)

    Line("uhhhh {{player}} just turned into a zombie thing", A.Dumb)
    Line("wait is {{player}} a zombie now? are they ok?", A.Dumb)
    Line("{{player}} looks different... are they sick?", A.Dumb)

    Line("Team alert! {{player}} has been infected! Stick together!", A.Teamer)
    Line("{{player}} got turned! Everyone group up NOW!", A.Teamer)
    Line("We lost {{player}} to the infection! Stay with the team!", A.Teamer)

    RegisterCategory("HostKilled", P.CRITICAL, "When the infected host {{player}} is killed.")
    Line("We got the host! {{player}} is down!", A.Default)
    Line("{{player}} was the source! The host is dead!", A.Default)
    Line("The infected host is down! All zombies should drop!", A.Default)

    Line("yooo we got {{player}}! the host is dead!", A.Casual)
    Line("{{player}} is down, that was the host right?", A.Casual)
    Line("bye bye {{player}} lmao host eliminated", A.Casual)

    Line("Host eliminated. Threat neutralized.", A.Tryhard)
    Line("{{player}} was the host. Mission complete.", A.Tryhard)
    Line("Primary target {{player}} confirmed down.", A.Tryhard)

    Line("HAHA GET REKT {{player}}!! THE HOST IS DEAD!", A.Hothead)
    Line("That's what you get, {{player}}! Host DOWN!", A.Hothead)

    Line("The host has been dealt with.", A.Stoic)
    Line("{{player}}, the host, is dead. The infection should stop.", A.Stoic)

    Line("I'm glad we stopped them. Good job everyone!", A.Nice)
    Line("{{player}} is down! The zombies should fall too!", A.Nice)

    Line("About time. {{player}} was annoying.", A.Bad)
    Line("Good riddance, {{player}}.", A.Bad)

    Line("The host is dead... but was that really all of them?", A.Sus)
    Line("{{player}} went down. Let's make sure there aren't more.", A.Sus)

    Line("we killed the main zombie guy! yay!", A.Dumb)
    Line("wait does that mean the other zombies die too?", A.Dumb)

    Line("Host down, team! Great teamwork!", A.Teamer)
    Line("{{player}} eliminated! The infection is over, team!", A.Teamer)

    RegisterCategory("InfectedTeamRush", P.IMPORTANT, "Infected team-only: rallying zombies to attack (team chat).")
    Line("Let's rush them together!", A.Default)
    Line("All of us, now! Attack!", A.Default)
    Line("Swarm them! Go go go!", A.Default)

    Line("lets gooo rush them", A.Casual)
    Line("everyone attack now lol", A.Casual)

    Line("Coordinated assault. Move.", A.Tryhard)
    Line("Execute swarm protocol.", A.Tryhard)

    Line("CHARGE!! KILL THEM ALL!", A.Hothead)
    Line("RUSH THEM NOW!!", A.Hothead)

    Line("We move together.", A.Stoic)
    Line("Attack.", A.Stoic)

    Line("Go get them, friends!", A.Nice)

    Line("They don't stand a chance.", A.Bad)

    Line("uhhh attack?", A.Dumb)

    Line("Team, attack together! NOW!", A.Teamer)

    RegisterCategory("InfectedVictory", P.IMPORTANT, "Infected celebrating victory.")
    Line("The infection spreads! We win!", A.Default)
    Line("Nobody can stop the infected!", A.Default)
    Line("The horde prevails!", A.Default)

    Line("GG infected win lets gooo", A.Casual)
    Line("zombies on top lol", A.Casual)

    Line("Flawless infection strategy.", A.Tryhard)
    Line("Optimal conversion rate achieved.", A.Tryhard)

    Line("GET WRECKED!! ZOMBIES WIN!!", A.Hothead)
    Line("HAHAHA THE INFECTED DOMINATE!", A.Hothead)

    Line("The infection is complete.", A.Stoic)

    Line("Good game everyone! Even though we were zombies!", A.Nice)

    Line("They never stood a chance. Pathetic.", A.Bad)

    Line("wait we won? yay zombies!", A.Dumb)

    Line("Great teamwork, infected crew!", A.Teamer)

    -----------------------------------------------------------
    -- DOOMGUY / DOOM SLAYER EVENTS
    -- Triggered when bots spot, react to, or call out Doomguy.
    -----------------------------------------------------------

    RegisterCategory("DoomguySpotted", P.CRITICAL, "When a bot spots the active Doomguy / Doom Slayer.")
    Line("Watch out! Doom Slayer is here!", A.Default)
    Line("Doomguy spotted! Stay back!", A.Default)
    Line("The Slayer is in the area — be careful!", A.Default)
    Line("Doom Slayer just showed up. Be ready.", A.Default)
    Line("Watch it, Doomguy is nearby!", A.Default)
    Line("It's the Doom Slayer! Don't get caught alone!", A.Default)

    Line("yo doomguy is HERE be careful", A.Casual)
    Line("uh oh doomguy lol", A.Casual)
    Line("doom slayer spotted!! run or fight idk", A.Casual)
    Line("ohhh no doom is here", A.Casual)

    Line("Target: Doom Slayer. Engage with caution.", A.Tryhard)
    Line("Slayer confirmed on site. Do not engage solo.", A.Tryhard)
    Line("High-value threat spotted. Adjust strategy.", A.Tryhard)

    Line("DOOMGUY IS HERE!! EVERYONE REACT!", A.Hothead)
    Line("OH GOD IT'S THE SLAYER! SHOOT HIM!!", A.Hothead)
    Line("THE DOOM GUY IS HERE AND I'M GOING TO FIGHT HIM!", A.Hothead)

    Line("Doom Slayer is present. Exercise extreme caution.", A.Stoic)
    Line("The Slayer is here. Do not engage recklessly.", A.Stoic)

    Line("Careful everyone — Doom Slayer is here! Stay together!", A.Nice)
    Line("Heads up! Doomguy is nearby — let's help each other out!", A.Nice)

    Line("ugh great it's doomguy. we're all gonna die.", A.Bad)
    Line("Oh wonderful. The Doom Slayer showed up. Just what we needed.", A.Bad)

    Line("uhhh there's a really scary guy with a big gun???", A.Dumb)
    Line("is doom slayer the friendly one or the bad one", A.Dumb)

    Line("Alert! Doom Slayer spotted! All units respond!", A.Teamer)
    Line("Team, Doomguy is here! Group up NOW!", A.Teamer)


    RegisterCategory("DoomguyKilledPlayer", P.CRITICAL, "When Doomguy kills someone in front of the bot.")
    Line("Doom Slayer just killed {{player}}! Everyone watch out!", A.Default)
    Line("{{player}} is down! The Slayer got them!", A.Default)
    Line("The Doom Slayer took out {{player}}. Stay away!", A.Default)
    Line("Doomguy killed {{player}}! He's on a rampage!", A.Default)
    Line("Slayer got {{player}}. Nobody is safe!", A.Default)

    Line("doomguy just slapped {{player}} lmao rip", A.Casual)
    Line("gg {{player}}, doom slayer said no", A.Casual)
    Line("{{player}} caught the doomguy treatment lol", A.Casual)

    Line("Slayer eliminated {{player}}. Threat is mobile.", A.Tryhard)
    Line("Kill confirmed. {{player}} down. Slayer repositioning.", A.Tryhard)

    Line("HE GOT {{player}}!! RUN OR FIGHT BACK!", A.Hothead)
    Line("{{player}} IS DOWN! THIS SLAYER IS INSANE!", A.Hothead)

    Line("{{player}} is gone. The Slayer is still active.", A.Stoic)
    Line("The Doom Slayer has killed {{player}}. Noted.", A.Stoic)

    Line("Oh no, {{player}} is down... please be careful everyone!", A.Nice)
    Line("{{player}} was killed by Doomguy. Let's stick together!", A.Nice)

    Line("Well there goes {{player}}. Useless.", A.Bad)
    Line("RIP {{player}} I guess. Doom Slayer doesn't mess around.", A.Bad)

    Line("oh no doom killed {{player}}... am I next?", A.Dumb)
    Line("AHHH {{player}} is dead!!!", A.Dumb)

    Line("{{player}} is down! Regroup team, Doomguy is still active!", A.Teamer)


    RegisterCategory("DoomguyWeak", P.IMPORTANT, "When Doomguy appears to be at low health — now is the time to push.")
    Line("Doomguy looks hurt! Push now!", A.Default)
    Line("The Slayer is weakened! Focus fire!", A.Default)
    Line("Doomguy is low on health! Now's our chance!", A.Default)
    Line("Hit him while he's down! The Slayer is weak!", A.Default)

    Line("yo doomguy is almost dead PUSH HIM", A.Casual)
    Line("doom slayer is low go go go", A.Casual)
    Line("he's weak!! finish him!!", A.Casual)

    Line("High-value target is low. All in.", A.Tryhard)
    Line("Slayer at critical HP. Execute.", A.Tryhard)

    Line("HE'S WEAK!! ALL ON HIM NOW!!", A.Hothead)
    Line("GET HIM WHILE HE'S HURT!!", A.Hothead)

    Line("The Slayer is weakened. Strike now.", A.Stoic)
    Line("Doom Slayer is low. Press the advantage.", A.Stoic)

    Line("He's hurt — together we can stop him!", A.Nice)
    Line("Now's our chance everyone! Doomguy is almost down!", A.Nice)

    Line("About time. Someone hurt the big guy.", A.Bad)
    Line("Finally. Push him before he heals.", A.Bad)

    Line("wait doomguy can get hurt?? attack him i guess!", A.Dumb)

    Line("Team push! Doomguy is low! NOW!", A.Teamer)


    RegisterCategory("DoomguyChasingMe", P.CRITICAL, "When the bot is being actively chased by Doomguy.")
    Line("Doomguy is chasing me! Somebody help!", A.Default)
    Line("The Slayer is on me! I need backup!", A.Default)
    Line("Doomguy is hunting me — help!", A.Default)
    Line("Running from the Slayer! Anyone nearby?!", A.Default)

    Line("OMG doomguy is literally chasing me rn", A.Casual)
    Line("help doom guy is after me lol this is not good", A.Casual)
    Line("the slayer is on my tail!! HELP", A.Casual)

    Line("Under pursuit by Slayer. Requesting support.", A.Tryhard)
    Line("Slayer is on me. Need intercept or distraction.", A.Tryhard)

    Line("HE'S CHASING ME!! SOMEONE SHOOT HIM!!", A.Hothead)
    Line("GET THIS DOOM GUY OFF ME!!! HELP!!!", A.Hothead)

    Line("The Slayer is pursuing me.", A.Stoic)
    Line("I am being hunted by the Doom Slayer.", A.Stoic)

    Line("Please help! Doomguy is following me!", A.Nice)
    Line("I really need some backup — Doomguy is right behind me!", A.Nice)

    Line("Great. Doom Slayer decided I'm his target.", A.Bad)
    Line("Of course he's chasing me. Why not.", A.Bad)

    Line("AHHHH DOOM IS AFTER ME SOMEONE HELP", A.Dumb)
    Line("why is the big scary guy running at me", A.Dumb)

    Line("Doomguy is on me! Team intercept!", A.Teamer)


    RegisterCategory("DoomguyAvoid", P.IMPORTANT, "When bots advise others to avoid Doomguy.")
    Line("Don't go near the Slayer alone. It's suicide.", A.Default)
    Line("Avoid Doomguy — he's way too strong to fight solo.", A.Default)
    Line("Keep your distance from the Doom Slayer!", A.Default)
    Line("Don't let Doomguy close the gap on you.", A.Default)

    Line("seriously don't solo doomguy you'll die", A.Casual)
    Line("avoid the slayer unless you have backup", A.Casual)
    Line("dont go near doom slayer omg", A.Casual)

    Line("Advise: do not engage Slayer without numerical advantage.", A.Tryhard)
    Line("One-on-one with the Slayer is a losing trade.", A.Tryhard)

    Line("Stay away from him if you can't back it up.", A.Hothead)
    Line("Don't get cocky near Doomguy — you'll regret it.", A.Hothead)

    Line("Avoid the Slayer unless you have clear advantage.", A.Stoic)
    Line("Do not engage Doom Slayer alone.", A.Stoic)

    Line("Please be careful around Doomguy, everyone!", A.Nice)
    Line("Let's stay away from the Slayer unless we're together!", A.Nice)

    Line("Unless you want to die, stay away from Doomguy.", A.Bad)
    Line("If you're dumb enough to fight him alone, that's on you.", A.Bad)

    Line("is doomguy friendly??? he seems mean", A.Dumb)
    Line("should i go say hi to doom slayer", A.Dumb)

    Line("Team: avoid the Slayer unless we can coordinate!", A.Teamer)


    RegisterCategory("DoomguyAtLocation", P.IMPORTANT, "When a bot calls out Doomguy's location.")
    Line("Doomguy is near {{location}}! Everyone knows!", A.Default)
    Line("Doom Slayer was spotted at {{location}}!", A.Default)
    Line("The Slayer is somewhere near {{location}}!", A.Default)
    Line("Heads up — Doomguy was at {{location}} just now.", A.Default)

    Line("yo doomguy is by {{location}} heads up", A.Casual)
    Line("saw the slayer near {{location}} lol careful", A.Casual)
    Line("doom slayer: {{location}} area, watch out", A.Casual)

    Line("Slayer last seen near {{location}}. Avoid or intercept.", A.Tryhard)
    Line("Doom Slayer: {{location}}. Tactical note.", A.Tryhard)

    Line("Doomguy is around {{location}}! Keep an eye out!", A.Hothead)
    Line("The Slayer is by {{location}}! Don't get caught off guard!", A.Hothead)

    Line("Doom Slayer was sighted near {{location}}.", A.Stoic)
    Line("The Slayer's last known position: {{location}}.", A.Stoic)

    Line("Careful near {{location}} — Doomguy was just there!", A.Nice)
    Line("I spotted the Slayer by {{location}}. Heads up!", A.Nice)

    Line("Slayer around {{location}}. Try not to be stupid about it.", A.Bad)
    Line("I saw Doomguy near {{location}}. Lucky you.", A.Bad)

    Line("i think i saw the doom guy near {{location}} maybe?", A.Dumb)
    Line("he was somewhere around {{location}} i think", A.Dumb)

    Line("Team! Doomguy last seen at {{location}}! Plan accordingly!", A.Teamer)

    -----------------------------------------------------------
    -- NECROMANCER / ZOMBIE (NECRO) ROLE EVENTS
    -----------------------------------------------------------

    RegisterCategory("NecroRevivingZombie", P.IMPORTANT, "Necromancer is raising a dead player as a zombie (team-only chat).")
    Line("Rise, my minion... I'm raising the dead.", A.Default)
    Line("I'm converting a corpse into a zombie. Cover me.", A.Default)
    Line("Raising the dead. This one will serve us well.", A.Default)
    Line("Another soldier for our army... rising now.", A.Default)

    Line("yo im raising a zombie rn cover me", A.Casual)
    Line("making another zombie lets gooo", A.Casual)
    Line("reviving this one as a zombie, hold on", A.Casual)

    Line("Initiating revival protocol. Cover my position.", A.Tryhard)
    Line("Converting corpse to zombie asset. Maintain perimeter.", A.Tryhard)
    Line("New zombie inbound. 3 seconds.", A.Tryhard)

    Line("RISE!! RISE FROM THE DEAD!!", A.Hothead)
    Line("GET UP! YOU SERVE ME NOW!", A.Hothead)
    Line("ANOTHER ONE FOR THE ARMY!!", A.Hothead)

    Line("The dead shall rise.", A.Stoic)
    Line("Converting another. Stand by.", A.Stoic)
    Line("Raising a new zombie.", A.Stoic)

    Line("Sorry about this, but I need your help... rise, please!", A.Nice)
    Line("I know it's not ideal, but welcome back! As a zombie!", A.Nice)

    Line("Get up. You're mine now.", A.Bad)
    Line("Another puppet for my collection.", A.Bad)
    Line("Rise, servant. You don't have a choice.", A.Bad)

    Line("I KNEW this corpse would be useful.", A.Sus)
    Line("Nobody's watching... perfect time to raise the dead.", A.Sus)

    Line("uhhh im doing the zombie thing on this body", A.Dumb)
    Line("making a zombie i think? is this how it works?", A.Dumb)

    Line("Team, I'm raising a zombie. Cover this position!", A.Teamer)
    Line("Converting a corpse — protect me while I work!", A.Teamer)

    RegisterCategory("ZombieRisen", P.IMPORTANT, "A bot has just been raised as a necro zombie.")
    Line("I... I'm back. But different.", A.Default)
    Line("Braaains... I serve the master now.", A.Default)
    Line("The dead walk again.", A.Default)
    Line("I... serve...", A.Default)

    Line("bruh im a zombie now lol", A.Casual)
    Line("wait what happened... why am i undead", A.Casual)
    Line("ok so im a zombie i guess", A.Casual)

    Line("Zombie operational. Awaiting target designation.", A.Tryhard)
    Line("Reanimated. Combat ready. 7 rounds loaded.", A.Tryhard)

    Line("I'M BACK!! AND I'M HUNGRY!!", A.Hothead)
    Line("BRAAAINS!! LET ME AT THEM!!", A.Hothead)
    Line("RAAAAAGH!! I LIVE AGAIN!!", A.Hothead)

    Line("I have returned.", A.Stoic)
    Line("Reanimated. Ready.", A.Stoic)

    Line("Oh! I'm... alive? Sort of? Hello everyone!", A.Nice)
    Line("I'm back! Even if I'm a bit... dead-looking!", A.Nice)

    Line("Ugh. Being undead is annoying.", A.Bad)
    Line("Great. I'm a zombie. Fantastic.", A.Bad)

    Line("wait am i dead or alive??? im confused", A.Dumb)
    Line("BRAINS??? do i want brains now???", A.Dumb)

    Line("Zombie reporting in! Ready to serve the team!", A.Teamer)

    RegisterCategory("NecroZombieSpotted", P.CRITICAL, "When a bot sees a player get raised as a necro zombie.")
    Line("{{player}} just came back from the dead! They're a zombie!", A.Default)
    Line("The necromancer revived {{player}}! Watch out!", A.Default)
    Line("{{player}} is back as a zombie! Someone's a necromancer!", A.Default)
    Line("A zombie just rose from {{player}}'s corpse!", A.Default)

    Line("yo {{player}} just got raised from the dead wtf", A.Casual)
    Line("bruh {{player}} is a zombie now lmao", A.Casual)
    Line("the necromancer got {{player}}, they're undead now", A.Casual)

    Line("{{player}} reanimated. Necromancer confirmed active.", A.Tryhard)
    Line("Corpse of {{player}} converted. High-priority threat.", A.Tryhard)
    Line("Zombie creation witnessed. {{player}} is compromised.", A.Tryhard)

    Line("WHAT THE HELL?! {{player}} JUST CAME BACK TO LIFE!", A.Hothead)
    Line("THEY RAISED {{player}} FROM THE DEAD!! KILL IT!", A.Hothead)
    Line("{{player}} IS A ZOMBIE NOW!! SHOOT THEM!", A.Hothead)

    Line("{{player}} has been reanimated. Noted.", A.Stoic)
    Line("A zombie rose from {{player}}'s corpse.", A.Stoic)

    Line("Oh no! {{player}} got turned into a zombie! Be careful!", A.Nice)
    Line("Poor {{player}}... they've been raised from the dead.", A.Nice)

    Line("Heh. {{player}} is a zombie now. Not my problem.", A.Bad)
    Line("{{player}} got zombified. Sucks to be them.", A.Bad)

    Line("I KNEW there was a necromancer. Look at {{player}}!", A.Sus)
    Line("{{player}} is a zombie... who's the necromancer?", A.Sus)

    Line("uhhh {{player}} is standing up from being dead???", A.Dumb)
    Line("wait can dead people do that?? {{player}} is alive again!", A.Dumb)

    Line("Alert! {{player}} raised as zombie! Necromancer is active!", A.Teamer)
    Line("Team, {{player}} is a zombie now! Group up!", A.Teamer)

    RegisterCategory("NecroMasterKilled", P.CRITICAL, "When the necromancer master is killed (non-necro team reacts).")
    Line("We got the necromancer! {{player}} is down!", A.Default)
    Line("{{player}} was the necromancer! The master is dead!", A.Default)
    Line("The necromancer is down! No more zombies!", A.Default)

    Line("yooo we got the necromancer! {{player}} is done!", A.Casual)
    Line("{{player}} was the necro, they're dead now", A.Casual)
    Line("bye bye necromancer lmao", A.Casual)

    Line("Necromancer eliminated. Threat neutralized.", A.Tryhard)
    Line("{{player}} was the necromancer. Mission complete.", A.Tryhard)

    Line("HAHA GET WRECKED {{player}}!! NO MORE ZOMBIES!", A.Hothead)
    Line("THE NECROMANCER IS DEAD!! EAT THAT!", A.Hothead)

    Line("The necromancer has been dealt with.", A.Stoic)
    Line("{{player}}, the necromancer, is dead.", A.Stoic)

    Line("Good job everyone! The necromancer is down!", A.Nice)
    Line("We stopped {{player}} from raising more zombies!", A.Nice)

    Line("About time. {{player}} was getting annoying with those zombies.", A.Bad)
    Line("Good riddance, necromancer.", A.Bad)

    Line("The zombie master is dead... right? Right??", A.Sus)
    Line("{{player}} went down. But are there more?", A.Sus)

    Line("we killed the zombie boss person! yay!", A.Dumb)
    Line("wait so no more zombies now right?", A.Dumb)

    Line("Necromancer down! Great teamwork everyone!", A.Teamer)

    RegisterCategory("NecroMasterDied", P.IMPORTANT, "Zombie reacts when their necromancer master dies.")
    Line("Master? MASTER?! No...", A.Default)
    Line("The master is dead... I'm on my own now.", A.Default)
    Line("I feel the bond breaking... the necromancer has fallen.", A.Default)

    Line("wait the necromancer died?? uh oh", A.Casual)
    Line("rip master... guess im solo now", A.Casual)
    Line("necromancer down, im on my own lol", A.Casual)

    Line("Master eliminated. Switching to solo combat mode.", A.Tryhard)
    Line("Lost command. Operating independently.", A.Tryhard)

    Line("MASTER!! NOOO!! I'LL AVENGE YOU!!", A.Hothead)
    Line("THEY KILLED THE MASTER!! THEY ALL PAY!!", A.Hothead)

    Line("The master has fallen.", A.Stoic)
    Line("I am alone now.", A.Stoic)

    Line("Oh no... the necromancer... I'm sorry I couldn't protect you.", A.Nice)

    Line("Tch. The master was weak. I'll finish this myself.", A.Bad)
    Line("Pathetic. I have to do everything alone.", A.Bad)

    Line("uh... master? where did you go??", A.Dumb)
    Line("wait the zombie boss is dead??? what do i do", A.Dumb)

    Line("Master down! All zombies, fight to the last!", A.Teamer)

    RegisterCategory("NecroVictory", P.IMPORTANT, "Team Necromancer won the round.")
    Line("The dead have risen! We win!", A.Default)
    Line("Death comes for all! Team Necromancer victorious!", A.Default)
    Line("The necromancer's army prevails!", A.Default)

    Line("GG necro team wins lets gooo", A.Casual)
    Line("zombies on top lol", A.Casual)
    Line("necromancer was too cracked", A.Casual)

    Line("Optimal zombie conversion strategy executed.", A.Tryhard)
    Line("Team Necromancer: flawless victory.", A.Tryhard)

    Line("HAHAHA THE DEAD RULE!! GET WRECKED!!", A.Hothead)
    Line("ZOMBIES WIN!! EAT IT!!", A.Hothead)

    Line("The dead have claimed their victory.", A.Stoic)
    Line("Team Necromancer is victorious.", A.Stoic)

    Line("Good game everyone! Even though we were zombies!", A.Nice)
    Line("That was fun! Glad we pulled through as a team!", A.Nice)

    Line("They never stood a chance against the undead.", A.Bad)
    Line("Pathetic resistance. The dead always win.", A.Bad)

    Line("wait we won? yay zombies!", A.Dumb)
    Line("did the zombie team win? cool!", A.Dumb)

    Line("Great coordination, necro team!", A.Teamer)

    RegisterCategory("ZombieAmmoLow", P.MODERATE, "Zombie bot is running low on ammo.")
    Line("Only {{ammo}} bullets left... I have to make them count.", A.Default)
    Line("Running dry... not many shots left.", A.Default)
    Line("Ammo's almost gone. Every shot matters now.", A.Default)

    Line("bro i only have {{ammo}} bullets left", A.Casual)
    Line("running out of ammo lol this is bad", A.Casual)

    Line("{{ammo}} rounds remaining. Engaging conservatively.", A.Tryhard)
    Line("Critically low ammo. Prioritizing headshots.", A.Tryhard)

    Line("I'M ALMOST OUT!! {{ammo}} BULLETS LEFT!!", A.Hothead)
    Line("RUNNING DRY!! GOTTA MAKE THESE COUNT!!", A.Hothead)

    Line("Low ammo. Proceeding carefully.", A.Stoic)

    Line("Oh no, I'm almost out of ammo... {{ammo}} left!", A.Nice)

    Line("Great. {{ammo}} bullets. This is going well.", A.Bad)

    Line("how many bullets do i have?? oh no only {{ammo}}", A.Dumb)

    Line("Team, I'm low on ammo! {{ammo}} rounds!", A.Teamer)

    RegisterCategory("ZombieSelfDestruct", P.CRITICAL, "Zombie's last words before self-destructing from empty ammo.")
    Line("No more ammo... this is the end.", A.Default)
    Line("Empty... I can feel the death returning.", A.Default)
    Line("Out of bullets. The grave calls me back.", A.Default)

    Line("im out of ammo gg", A.Casual)
    Line("welp no bullets left rip me", A.Casual)

    Line("Ammunition depleted. Self-destruct imminent.", A.Tryhard)
    Line("Zero rounds. Mission... incomplete.", A.Tryhard)

    Line("NO!! NOT LIKE THIS!! I'M OUT!!", A.Hothead)
    Line("EMPTY!! NOOOOO!!", A.Hothead)

    Line("It is over.", A.Stoic)
    Line("Ammunition exhausted. Farewell.", A.Stoic)

    Line("I'm sorry everyone... no more bullets.", A.Nice)

    Line("What a waste. Out of ammo.", A.Bad)

    Line("wait why is my gun empty??? oh no", A.Dumb)
    Line("i think my gun broke... it won't shoot anymore", A.Dumb)

    Line("Out of ammo. Going down. GG team.", A.Teamer)

    RegisterCategory("NecroTeamRally", P.MODERATE, "Necromancer rallying zombies to attack (team chat).")
    Line("Attack {{player}}! Go, my minions!", A.Default)
    Line("All of you — focus {{player}} now!", A.Default)
    Line("Swarm them! Target {{player}}!", A.Default)

    Line("yo zombies go get {{player}}", A.Casual)
    Line("everyone attack {{player}} now lol", A.Casual)

    Line("All units focus {{player}}. Execute.", A.Tryhard)
    Line("Coordinated assault on {{player}}. Move.", A.Tryhard)

    Line("KILL {{player}}!! ALL OF YOU, NOW!!", A.Hothead)
    Line("CHARGE!! GET {{player}}!!", A.Hothead)

    Line("Target: {{player}}. Attack.", A.Stoic)

    Line("Please go get {{player}}, my zombie friends!", A.Nice)

    Line("Destroy {{player}}. Now.", A.Bad)

    Line("uhh zombies go attack {{player}} i think", A.Dumb)

    Line("Team, focus {{player}}! Attack together!", A.Teamer)

    RegisterCategory("NecroTeamStrategy", P.MODERATE, "Necromancer team-only strategy talk.")
    Line("Protect me while I revive more bodies.", A.Default)
    Line("Stay together. We're stronger as a pack.", A.Default)
    Line("I need to find more corpses. Cover me.", A.Default)

    Line("cover me while i make more zombies", A.Casual)
    Line("stay close guys we got this", A.Casual)

    Line("Maintain formation. I'll secure more assets.", A.Tryhard)
    Line("Defending revive operations. Priority alpha.", A.Tryhard)

    Line("PROTECT ME OR I CAN'T MAKE MORE ZOMBIES!!", A.Hothead)
    Line("STICK TOGETHER!! WE'RE AN ARMY!!", A.Hothead)

    Line("Stay close. More zombies incoming.", A.Stoic)

    Line("Let's stick together everyone! I'll raise more help!", A.Nice)

    Line("Guard me. I have work to do.", A.Bad)

    Line("uhhh everyone stay near me i think?", A.Dumb)

    Line("Team, cover me while I raise more zombies!", A.Teamer)

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
