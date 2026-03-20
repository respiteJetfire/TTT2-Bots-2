--[[
    Necromancer / Necro Zombie role chat categories

    This file contains chat lines for necromancer role events, necro zombie mechanics,
    and all necromancer team interactions. Categories included:
        NecroRevivingZombie, ZombieRisen, NecroZombieSpotted, NecroMasterKilled,
        NecroMasterDied, NecroVictory, ZombieAmmoLow, ZombieSelfDestruct,
        NecroTeamRally, NecroTeamStrategy
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
    MODERATE = 2,  --- Between IMPORTANT and NORMAL; used by zombie/necro categories
}

local function LoadNecroChats()
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
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadNecroChats()
end
timer.Simple(1, loadModule_Deferred)
