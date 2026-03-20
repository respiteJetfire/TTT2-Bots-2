--[[
    Infected / Zombie / Doomguy chat categories

    This file contains chat lines for infected role events, zombie mechanics,
    and all Doomguy / Doom Slayer interactions. Categories included:
        ZombieSpotted, HostKilled, InfectedTeamRush, InfectedVictory,
        DoomguySpotted, DoomguyKilledPlayer, DoomguyWeak,
        DoomguyChasingMe, DoomguyAvoid, DoomguyAtLocation
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadInfectedChats()
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
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadInfectedChats()
end
timer.Simple(1, loadModule_Deferred)
