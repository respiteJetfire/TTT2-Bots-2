--[[
    Social Interaction / Trust / Commands Chat Categories

    This file contains chat lines for social interaction, trust declarations,
    and player command responses. Categories included:
        DisguisedPlayer, DeclareSuspicious, DeclareInnocent, DeclareTrustworthy,
        Kill, FollowMe, FollowMeRefuse, FollowMeEnd,
        WaitStart, WaitRefuse, WaitEnd,
        ComeHereStart, ComeHereRefuse, ComeHereEnd,
        AttackStart, AttackRefuse, AttackEnd,
        RoleCheckerRequestAccepted, RoleCheckerRequestRefused, CallKOS
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadSocialChats()
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
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadSocialChats()
end
timer.Simple(1, loadModule_Deferred)
