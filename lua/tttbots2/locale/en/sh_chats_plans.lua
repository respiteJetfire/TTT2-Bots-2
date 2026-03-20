--[[
    Plan Action chat categories for TTT2 Bots.
    Contains: Plan.ATTACKANY, Plan.ATTACK, Plan.PLANT, Plan.DEFUSE, Plan.FOLLOW,
              Plan.GATHER, Plan.DEFEND, Plan.ROAM, Plan.IGNORE
    Split from sh_chats.lua for modularity.
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local LoadPlanChats = function()
    local A = TTTBots.Archetypes
    local f = string.format
    local ACTS = TTTBots.Plans.ACTIONS
    local ATTACKANY, ATTACK, PLANT, DEFUSE, FOLLOW, GATHER, DEFEND, ROAM, IGNORE =
        ACTS.ATTACKANY, ACTS.ATTACK, ACTS.PLANT, ACTS.DEFUSE, ACTS.FOLLOW,
        ACTS.GATHER, ACTS.DEFEND, ACTS.ROAM, ACTS.IGNORE
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end

    -----------------------------------------------------------
    -- TRAITORS SHARING PLANS
    -----------------------------------------------------------

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

    RegisterCategory(f("Plan.%s", PLANT), P.CRITICAL, "When a traitor bot is going to plant a C4 bomb.")
    Line("I'm going to plant a bomb.", A.Default)
    Line("I'm planting a bomb.", A.Default)
    Line("Placing a bomb!", A.Default)
    Line("Gonna rig this place to blow.", A.Default)

    RegisterCategory(f("Plan.%s", DEFUSE), P.CRITICAL, "When a traitor bot is going to defuse a C4 bomb.")
    Line("I'm going to defuse a bomb.", A.Default)

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


    RegisterCategory(f("Plan.%s", DEFEND), P.CRITICAL, "When a bot is going to defend an area.")
    Line("I'm going to defend this area.", A.Default)

    RegisterCategory(f("Plan.%s", ROAM), P.CRITICAL, "When a bot is going to roam around.")
    Line("I'm going to roam around for a bit.", A.Default)

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
end

local DEPENDENCIES = { "Plans" }
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadPlanChats()
end
timer.Simple(1, loadModule_Deferred)
