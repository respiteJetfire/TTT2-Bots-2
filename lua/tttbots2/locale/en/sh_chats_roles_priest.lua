--[[
    Priest role chatter categories.
    Covers:
      PriestConverting, PriestConvertSuccess, PriestBrotherDied,
      PriestDetectiveShot, PriestEvilKill, PriestBrotherhoodStrong
]]

local P = {
    CRITICAL = 1,
    IMPORTANT = 2,
    NORMAL = 3,
}

local function LoadPriestChats()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end

    RegisterCategory("PriestConverting", P.IMPORTANT, "Priest bot is about to test {{player}} with the Holy Deagle.")
    Line("{{player}}, hold still. I need to verify you.", A.Default)
    Line("yo {{player}}, quick holy deagle check", A.Casual)
    Line("{{player}}, trust me. This will keep us safer.", A.Nice)
    Line("{{player}}. Stand still for verification.", A.Stoic)
    Line("DON'T MOVE {{player}}!", A.Hothead)
    Line("{{player}}, don't make me waste this shot.", A.Bad)
    Line("Team, checking {{player}} for Brotherhood entry.", A.Teamer)
    Line("Confirming {{player}}. Building innocent intel graph.", A.Tryhard)
    Line("Relax {{player}}, this is totally normal...", A.Sus)
    Line("pew test on {{player}}!", A.Dumb)

    RegisterCategory("PriestConvertSuccess", P.IMPORTANT, "Priest bot successfully added {{player}} to the Brotherhood.")
    Line("Welcome to the Brotherhood, {{player}}.", A.Default)
    Line("nice, {{player}} is with us now", A.Casual)
    Line("Glad to have you with us, {{player}}.", A.Nice)
    Line("Conversion successful: {{player}} is now Brotherhood.", A.Stoic)
    Line("YES! {{player}} IS ONE OF US!", A.Hothead)
    Line("Good. {{player}} is useful now.", A.Bad)
    Line("Great work team, {{player}} joined the Brotherhood.", A.Teamer)
    Line("Trust network expanded: {{player}} confirmed.", A.Tryhard)
    Line("See? I knew {{player}} was fine... probably.", A.Sus)
    Line("it worked! {{player}} is friend-shaped", A.Dumb)

    RegisterCategory("PriestBrotherDied", P.CRITICAL, "A Brotherhood member {{player}} has died.")
    Line("We lost a brother: {{player}}.", A.Default)
    Line("damn, brother {{player}} is down", A.Casual)
    Line("No... {{player}} was one of ours.", A.Nice)
    Line("Brotherhood loss confirmed: {{player}}.", A.Stoic)
    Line("WHO KILLED {{player}}?!", A.Hothead)
    Line("Great. {{player}} is dead now.", A.Bad)
    Line("Team, we lost {{player}}. Stay together.", A.Teamer)
    Line("Brotherhood attrition detected: {{player}} eliminated.", A.Tryhard)
    Line("{{player}} died... this is getting bad.", A.Sus)
    Line("uh oh, {{player}} got un-alived", A.Dumb)

    RegisterCategory("PriestDetectiveShot", P.NORMAL, "Priest bot accidentally shot detective-like target {{player}}.")
    Line("That's on me — {{player}} is detective-side.", A.Default)
    Line("oops, {{player}} was a detective", A.Casual)
    Line("Sorry {{player}}, that was my mistake.", A.Nice)
    Line("Invalid target: {{player}} is detective-class.", A.Stoic)
    Line("UGH, {{player}} WAS DETECTIVE?!", A.Hothead)
    Line("Fantastic. Wasted shot on {{player}}.", A.Bad)
    Line("My bad team, {{player}} is detective-side.", A.Teamer)
    Line("Target classification error: detective hit on {{player}}.", A.Tryhard)
    Line("Right... {{player}} was detective. Totally intentional.", A.Sus)
    Line("i shot the wrong hat guy, my bad {{player}}", A.Dumb)

    RegisterCategory("PriestEvilKill", P.IMPORTANT, "Priest bot killed special evil target {{player}} with Holy Deagle.")
    Line("Holy Deagle worked — {{player}} was evil.", A.Default)
    Line("{{player}} popped. definitely not innocent", A.Casual)
    Line("We did it. {{player}} was a threat.", A.Nice)
    Line("Confirmed elimination: {{player}} hostile role.", A.Stoic)
    Line("GET SMITED, {{player}}!", A.Hothead)
    Line("{{player}} had it coming.", A.Bad)
    Line("Team, {{player}} was hostile. Good shot confirmed.", A.Teamer)
    Line("Outcome positive: hostile {{player}} removed.", A.Tryhard)
    Line("Well... {{player}} sure died fast.", A.Sus)
    Line("zap! {{player}} was bad guy", A.Dumb)

    RegisterCategory("PriestBrotherhoodStrong", P.NORMAL, "Priest bot notices the Brotherhood is strong (3+ members).")
    Line("Our Brotherhood is growing strong.", A.Default)
    Line("we got a solid brotherhood now", A.Casual)
    Line("I'm proud of us. We're stronger together.", A.Nice)
    Line("Brotherhood strength threshold reached.", A.Stoic)
    Line("NOW THIS IS A REAL CREW!", A.Hothead)
    Line("At least this group is finally useful.", A.Bad)
    Line("Great teamwork everyone — Brotherhood is strong.", A.Teamer)
    Line("Network density high. Coordination advantage online.", A.Tryhard)
    Line("Big Brotherhood... hopefully none of this backfires.", A.Sus)
    Line("we made a big friend club!", A.Dumb)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for _, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadPriestChats()
end
timer.Simple(1, loadModule_Deferred)
