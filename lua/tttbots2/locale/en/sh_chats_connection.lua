--[[
    Connection/Disconnect/Entrance/Exit chat categories for TTT2 Bots.
    Contains: DisconnectBoredom, DisconnectRage, ServerConnected
    Split from sh_chats.lua for modularity.
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local LoadConnectionChats = function()
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
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadConnectionChats()
end
timer.Simple(1, loadModule_Deferred)
