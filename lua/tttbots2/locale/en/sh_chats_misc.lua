-- Miscellaneous / simple event / buy event chat categories

local P = {
    CRITICAL = 1,
    IMPORTANT = 2,
    NORMAL = 3,
}

local function LoadMiscChats()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end

    local function RegisterSimpleEvent(eventName, priority, description, defaultLines, extraLines)
        RegisterCategory(eventName, priority, description)

        for _, line in ipairs(defaultLines or {}) do
            Line(line, A.Default)
        end

        if extraLines then
            for archetype, lines in pairs(extraLines) do
                for _, line in ipairs(lines) do
                    Line(line, archetype)
                end
            end
        end
    end

    local function RegisterBuyEvent(itemName)
        RegisterSimpleEvent(
            "Buy" .. itemName,
            P.NORMAL,
            "When a bot buys " .. itemName .. ".",
            {
                "Bought " .. itemName .. ".",
                itemName .. " acquired.",
            },
            {
                [A.Casual] = {
                    "got " .. string.lower(itemName) .. " lol",
                },
                [A.Stoic] = {
                    "Purchased " .. itemName .. ".",
                },
            }
        )
    end

    RegisterSimpleEvent("AskAttack", P.IMPORTANT,
        "When a bot asks {{player}} to attack a target.",
        {
            "{{player}}, attack them.",
            "{{player}}, help me pressure them.",
        },
        {
            [A.Casual] = { "yo {{player}}, push them with me" },
        }
    )

    RegisterSimpleEvent("CallHelp", P.CRITICAL,
        "When a bot urgently calls for help against {{player}}.",
        {
            "Help! {{player}} is on me!",
            "Need backup on {{player}}!",
        },
        {
            [A.Casual] = { "help lol {{player}} is pushing me" },
            [A.Hothead] = { "GET {{player}} OFF ME!" },
        }
    )

    RegisterSimpleEvent("ContractAccepted", P.IMPORTANT,
        "When a bot accepts a pirate contract.",
        {
            "Contract accepted.",
            "I'm taking the contract.",
        },
        {
            [A.Casual] = { "alright, contract taken" },
        }
    )

    RegisterSimpleEvent("DeployedRoleChecker", P.IMPORTANT,
        "When a bot finishes deploying a role checker.",
        {
            "Role checker deployed.",
            "The role checker is set up here.",
        },
        {
            [A.Casual] = { "role checker is down" },
        }
    )

    RegisterSimpleEvent("DeployingTurret", P.IMPORTANT,
        "When a bot starts deploying a turret.",
        {
            "Deploying a turret.",
            "Setting up turret coverage here.",
        },
        {
            [A.Casual] = { "dropping a turret here" },
        }
    )

    RegisterSimpleEvent("HighNoon", P.IMPORTANT,
        "When a bot starts charging the Peacekeeper's High Noon attack.",
        {
            "High noon.",
            "Charging the Peacekeeper.",
        },
        {
            [A.Casual] = { "high noon time" },
            [A.Hothead] = { "IT'S HIGH NOON!" },
        }
    )

    RegisterSimpleEvent("KOS", P.CRITICAL,
        "When a bot quickly marks {{player}} for KOS.",
        {
            "KOS {{player}}!",
            "{{player}} is KOS!",
        },
        {
            [A.Casual] = { "kos {{player}}" },
        }
    )

    RegisterSimpleEvent("PeacekeeperFired", P.IMPORTANT,
        "When a bot fires the Peacekeeper's High Noon attack.",
        {
            "Peacekeeper fired.",
            "Shot's out.",
        },
        {
            [A.Casual] = { "let it rip" },
        }
    )

    RegisterSimpleEvent("PlacingHealthStation", P.NORMAL,
        "When a bot places a health station.",
        {
            "Placing a health station.",
            "Dropping health here.",
        },
        {
            [A.Casual] = { "putting health down here" },
        }
    )

    RegisterSimpleEvent("RoleDefibStart", P.IMPORTANT,
        "When a bot starts reviving {{target}} with a role defibrillator.",
        {
            "Starting a role defib on {{target}}.",
            "I'm bringing {{target}} back with the role defib.",
        },
        {
            [A.Casual] = { "trying to role defib {{target}}" },
        }
    )

    RegisterSimpleEvent("SpottedMurderWeapon", P.IMPORTANT,
        "When a bot spots a likely murder weapon near {{victim}}'s scene.",
        {
            "I found a possible murder weapon near {{victim}}'s scene.",
            "There might be a murder weapon connected to {{victim}} here.",
        },
        {
            [A.Casual] = { "yo this might be the weapon used on {{victim}}" },
        }
    )

    RegisterSimpleEvent("ThrowGrenade", P.NORMAL,
        "When a bot throws a grenade.",
        {
            "Throwing a grenade.",
            "Frag out.",
        },
        {
            [A.Casual] = { "nade out" },
        }
    )

    RegisterSimpleEvent("UsingTimestop", P.IMPORTANT,
        "When a bot begins using the timestop item.",
        {
            "Using timestop.",
            "Freezing time now.",
        },
        {
            [A.Casual] = { "popping timestop" },
        }
    )

    RegisterSimpleEvent("TimestopUsed", P.IMPORTANT,
        "When a bot has successfully activated timestop.",
        {
            "Timestop is active.",
            "Time's frozen. Move.",
        },
        {
            [A.Casual] = { "time is stopped go go" },
        }
    )

    RegisterSimpleEvent("TimestopHunting", P.IMPORTANT,
        "When a bot picks a frozen target to execute during timestop.",
        {
            "Target acquired.",
            "Moving to target.",
            "They can't run.",
        },
        {
            [A.Casual] = { "easy pickings", "sitting ducks", "they can't move lol" },
        }
    )

    RegisterSimpleEvent("TimestopKill", P.IMPORTANT,
        "When a bot kills a frozen player during timestop.",
        {
            "Target eliminated.",
            "One down.",
            "Next.",
        },
        {
            [A.Casual] = { "got one", "rip", "deleted" },
        }
    )

    RegisterSimpleEvent("TimestopMassacre", P.IMPORTANT,
        "When a bot finishes a timestop killing spree.",
        {
            "Time stop complete. All targets eliminated.",
            "That was productive.",
            "Cleanup complete.",
        },
        {
            [A.Casual] = { "ez clap", "that was free", "too easy" },
        }
    )

    RegisterSimpleEvent("TurretDeployed", P.IMPORTANT,
        "When a bot finishes deploying a turret.",
        {
            "Turret deployed.",
            "Turret is online.",
        },
        {
            [A.Casual] = { "turret is up" },
        }
    )

    -- Missing event keys that were appearing in debug logs.
    RegisterSimpleEvent("IC_GroupUp", P.IMPORTANT,
        "Detective leadership call to group up.",
        {
            "Group up on me.",
            "Everyone regroup now.",
        },
        {
            [A.Casual] = { "group up team" },
        }
    )

    RegisterSimpleEvent("IC_AssignTest", P.IMPORTANT,
        "Detective leadership call assigning tester queue.",
        {
            "Form a queue for role checks.",
            "One at a time on the tester.",
        },
        {
            [A.Casual] = { "line up for tester" },
        }
    )

    RegisterSimpleEvent("Plan.CoordAttack", P.CRITICAL,
        "When traitors execute a coordinated strike on the same target.",
        {
            "Coordinated strike now.",
            "Hit together on my mark.",
        },
        {
            [A.Casual] = { "focus same target now" },
        }
    )

    -- -----------------------------------------------------------------------
    -- Specific buy events — richer lines than the generic RegisterBuyEvent
    -- -----------------------------------------------------------------------
    RegisterSimpleEvent("BuyApocalypse", P.IMPORTANT,
        "When a traitor bot buys the Apocalypse SWEP.",
        {
            "I've got the Apocalypse. Hang tight.",
            "Apocalypse acquired. Things are about to get very interesting.",
            "Got the Apocalypse. Ready to unleash hell.",
        },
        {
            [A.Casual] = { "apocalypse go brr", "uh oh i got the apocalypse lol" },
            [A.Hothead] = { "APOCALYPSE ONLINE! INCOMING!", "WE HAVE THE APOCALYPSE!" },
            [A.Stoic] = { "Apocalypse. Standby." },
            [A.Tryhard] = { "Apocalypse SWEP secured. Awaiting optimal deployment window." },
        }
    )

    RegisterSimpleEvent("BuyC4 (Deferred)", P.NORMAL,
        "When a bot buys C4 but plans to plant it later.",
        {
            "Got the C4. Waiting for the right moment to plant it.",
            "C4 in hand. I'll plant when the time is right.",
            "Bought the bomb. Sitting on it for now.",
        },
        {
            [A.Casual] = { "got c4, will plant later lol", "bomb is in my pocket lmao" },
            [A.Hothead] = { "C4 READY. JUST WAITING FOR MY SHOT.", "GOT THE BOMB. IT GOES DOWN SOON." },
            [A.Stoic] = { "C4. Holding." },
            [A.Tryhard] = { "Explosive ordnance acquired. Deferring detonation sequence pending optimal positioning." },
        }
    )

    RegisterSimpleEvent("BuyJerma Launcher", P.IMPORTANT,
        "When a traitor bot buys the Jerma Launcher.",
        {
            "Got the Jerma Launcher. Someone's getting a surprise.",
            "Jerma Launcher acquired. Time to unleash chaos.",
            "They won't see this coming.",
        },
        {
            [A.Casual] = { "jerma launcher lets gooooo", "lmao i got the jerma launcher" },
            [A.Hothead] = { "JERMA LAUNCHER READY! SOMEONE IS DEAD!", "UNLEASHING THE JERMA!" },
            [A.Stoic] = { "Jerma Launcher. Loaded." },
            [A.Tryhard] = { "Jerma Launcher acquired. Deploying on nearest enemy cluster." },
        }
    )

    RegisterSimpleEvent("BuyJihad Bomb", P.IMPORTANT,
        "When a traitor bot buys the Jihad Bomb.",
        {
            "I've got a jihad bomb. I'll use it when the moment's perfect.",
            "Jihad bomb acquired. I'm not afraid to use it.",
            "Got the bomb vest. I won't hesitate.",
        },
        {
            [A.Casual] = { "uh oh jihad bomb acquired lmao", "got the jihad bomb, rip everyone nearby" },
            [A.Hothead] = { "JIHAD BOMB! I'LL BLOW THEM ALL UP!", "THEY'RE ALL DYING WITH ME!" },
            [A.Stoic] = { "Jihad. Ready." },
            [A.Tryhard] = { "Jihad bomb secured. Calculating optimal enemy cluster for detonation." },
        }
    )

    RegisterSimpleEvent("BuyPeacekeeper", P.IMPORTANT,
        "When a traitor bot buys the Peacekeeper.",
        {
            "Got the Peacekeeper. High noon incoming.",
            "Peacekeeper acquired. Don't blink.",
            "They won't know what hit them. Peacekeeper ready.",
        },
        {
            [A.Casual] = { "peacekeeper acquired lets gooo", "time to cowboy up, got the peacekeeper" },
            [A.Hothead] = { "PEACEKEEPER ONLINE! IT'S HIGH NOON!", "ALL OF THEM ARE GETTING SHOT!" },
            [A.Stoic] = { "Peacekeeper. Ready." },
            [A.Tryhard] = { "Peacekeeper secured. High-noon sequence primed." },
        }
    )

    RegisterSimpleEvent("BuyProp Rain", P.IMPORTANT,
        "When a traitor bot buys the Prop Rain SWEP.",
        {
            "Got the Prop Rain. Things are about to get messy.",
            "Prop rain acquired. Watch your heads.",
            "Incoming debris. Lots of it.",
        },
        {
            [A.Casual] = { "prop rain lmaooo", "about to make it rain props everywhere" },
            [A.Hothead] = { "PROP RAIN READY! EVERYONE IS GETTING CRUSHED!", "INCOMING!!" },
            [A.Stoic] = { "Prop rain. Standby." },
            [A.Tryhard] = { "Environmental hazard weapon acquired. Deploying area-denial payload." },
        }
    )

    RegisterSimpleEvent("BuyTimestop", P.IMPORTANT,
        "When a traitor bot buys the Timestop item.",
        {
            "Got the timestop. Enjoy your last few seconds of movement.",
            "Timestop acquired. Nobody runs from this.",
            "Time is about to stop. Literally.",
        },
        {
            [A.Casual] = { "timestop acquired lmaoo they cant run", "about to freeze time lol" },
            [A.Hothead] = { "TIMESTOP! NOBODY MOVES! NOBODY!", "TIME IS STOPPING! EVERYONE DIES!" },
            [A.Stoic] = { "Timestop. Acquired." },
            [A.Tryhard] = { "Temporal manipulation device secured. Initiating freeze sequence on your mark." },
        }
    )

    RegisterSimpleEvent("BuyTurret", P.IMPORTANT,
        "When a traitor bot buys a Turret.",
        {
            "Got a turret. I'll set it up somewhere good.",
            "Turret acquired. Somebody's going to walk right into this.",
            "Going to place this turret somewhere strategic.",
        },
        {
            [A.Casual] = { "turret acquired time to be lazy", "gonna set up a turret somewhere sneaky" },
            [A.Hothead] = { "TURRET TIME! NOTHING GETS THROUGH!", "PLACING THE TURRET NOW! STAY BACK!" },
            [A.Stoic] = { "Turret. Deploying." },
            [A.Tryhard] = { "Automated fire platform acquired. Identifying optimal placement zone." },
        }
    )

    -- -----------------------------------------------------------------------
    -- Ability activation chatter (team-only)
    -- -----------------------------------------------------------------------
    RegisterSimpleEvent("ApocalypseActivated", P.IMPORTANT,
        "When a traitor bot successfully activates the Apocalypse SWEP (team-only).",
        {
            "Apocalypse is live. The horde is coming.",
            "I activated the apocalypse. Clean up time.",
            "The NPCs are loose. Use the chaos.",
        },
        {
            [A.Casual] = { "apocalypse is active lmaoo", "i let the horde loose hehehe" },
            [A.Hothead] = { "APOCALYPSE ACTIVATED! LET THEM BURN!", "THE HORDE IS LOOSE! CHAOS BEGINS!" },
            [A.Stoic] = { "Activated." },
            [A.Tryhard] = { "Apocalypse sequence initiated. NPC horde engaged. Push during the confusion." },
        }
    )

    RegisterSimpleEvent("JermaLauncherFired", P.IMPORTANT,
        "When a traitor bot fires the Jerma Launcher (team-only).",
        {
            "Jerma's out! Go while they're distracted!",
            "I launched the Jerma. Use the chaos.",
            "Jerma is in play. Push now.",
        },
        {
            [A.Casual] = { "JERMA IS LOOSE LMAO", "jerma is chasing someone rn lol" },
            [A.Hothead] = { "JERMA DEPLOYED! NOW WE ATTACK!", "THE JERMA IS OUT! PUSH THEM!" },
            [A.Stoic] = { "Launched." },
            [A.Tryhard] = { "Jerma nextbot deployed. Initiating coordinated assault under cover of distraction." },
        }
    )

    -- -----------------------------------------------------------------------
    -- Detective leadership dispatch
    -- -----------------------------------------------------------------------
    RegisterSimpleEvent("IC_DispatchInvestigate", P.IMPORTANT,
        "When the detective bot dispatches innocents to investigate an area.",
        {
            "Someone check out that area. Report back.",
            "I need eyes on that zone. Go investigate.",
            "Team, search that location and tell me what you find.",
        },
        {
            [A.Casual] = { "yo go check that area out", "someone go look over there for me" },
            [A.Hothead] = { "SOMEONE CHECK THAT AREA NOW!", "GO INVESTIGATE! MOVE IT!" },
            [A.Stoic] = { "Investigate that zone." },
            [A.Tryhard] = { "Dispatching unit to investigate designated sector. All findings to be reported immediately." },
            [A.Nice] = { "Would someone mind checking that area? Thank you so much." },
        }
    )

    RegisterBuyEvent("Artillery Marker")
    RegisterBuyEvent("Arson Thrower")
    RegisterBuyEvent("Banana")
    RegisterBuyEvent("Barrel Gun")
    RegisterBuyEvent("BeeNade")
    RegisterBuyEvent("C4")
    RegisterBuyEvent("Dance Gun")
    RegisterBuyEvent("Head Launcher")
    RegisterBuyEvent("Holy Hand Grenade")
    RegisterBuyEvent("Killer Snail")
    RegisterBuyEvent("Melon Launcher")
    RegisterBuyEvent("Mine Thrower")
    RegisterBuyEvent("Minigun")
    RegisterBuyEvent("Osc Sym")
    RegisterBuyEvent("Sience Show")
    RegisterBuyEvent("Smart Pistol")
    RegisterBuyEvent("Snake Gun")
    RegisterBuyEvent("Thomas")
    RegisterBuyEvent("TTTE")
    RegisterBuyEvent("Weeping Angel")
    RegisterBuyEvent("Smart Bullets")
    RegisterBuyEvent("Poison Dart Gun")
    RegisterBuyEvent("Hologram Decoy")
    RegisterBuyEvent("EMP Grenade")
    RegisterBuyEvent("Gravity Mine")

    -- -----------------------------------------------------------------------
    -- Poison Dart Gun — Traitor-side chatter (team-only)
    -- -----------------------------------------------------------------------
    RegisterSimpleEvent("UsingPoisonDart", P.NORMAL,
        "When a traitor bot fires a poison dart at a target.",
        {
            "Firing a poison dart. They won't notice until it's too late.",
            "Dart away. Poison will do the work.",
            "Tagged them with a poison dart.",
        },
        {
            [A.Casual] = { "darted someone lol", "poison go brrr" },
            [A.Stoic] = { "Poison dart deployed." },
        }
    )

    -- -----------------------------------------------------------------------
    -- Hologram Decoy — Traitor-side chatter (team-only)
    -- -----------------------------------------------------------------------
    RegisterSimpleEvent("DeployingDecoy", P.NORMAL,
        "When a bot deploys a hologram decoy.",
        {
            "Deploying a distraction...",
            "Sending out a decoy.",
            "Hologram deployed, use the confusion.",
        },
        {
            [A.Casual] = { "decoy out, watch the chaos", "fake player deployed lol" },
            [A.Stoic] = { "Decoy active." },
        }
    )

    -- -----------------------------------------------------------------------
    -- Gravity Mine — Traitor-side chatter (team-only)
    -- -----------------------------------------------------------------------
    RegisterSimpleEvent("DeployingGravityMine", P.NORMAL,
        "When a bot throws a gravity mine.",
        {
            "Throwing a gravity mine...",
            "Mine deployed, stay clear.",
            "Gravity mine out. It'll pull them in.",
        },
        {
            [A.Casual] = { "grav mine out, don't get caught", "yeet gravity mine" },
            [A.Stoic] = { "Gravity mine deployed." },
        }
    )

    -- -----------------------------------------------------------------------
    -- Smart Bullets — Traitor-side chatter (team-only)
    -- -----------------------------------------------------------------------
    RegisterSimpleEvent("SmartBulletsActivated", P.NORMAL,
        "When a traitor bot activates smart bullets.",
        {
            "Smart bullets online. Let's clean up.",
            "Activating auto-aim. Cover me.",
            "Lock and load. Smart bullets active.",
        },
        {
            [A.Casual] = { "smart bullets go brrr", "aimbot engaged lol" },
            [A.Hothead] = { "SMART BULLETS ONLINE! PUSHING NOW!" },
            [A.Stoic] = { "Smart bullets activated." },
        }
    )

    RegisterSimpleEvent("SmartBulletsKill", P.NORMAL,
        "When a traitor bot kills someone during smart bullets buff.",
        {
            "Got one with the tracking rounds.",
            "Target down. This thing is nasty.",
            "Easy kill. Love these bullets.",
        },
        {
            [A.Casual] = { "another one bites the dust lol", "too easy" },
        }
    )

    RegisterSimpleEvent("SmartBulletsExpired", P.NORMAL,
        "When a traitor bot's smart bullets buff expires.",
        {
            "Smart bullets wore off.",
            "Auto-aim expired. Back to manual.",
            "Tracking rounds are done.",
        },
        {
            [A.Casual] = { "aimbot ran out sadge" },
        }
    )

    -- -----------------------------------------------------------------------
    -- Smart Bullets — Innocent/Detective-side chatter (public)
    -- -----------------------------------------------------------------------
    RegisterSimpleEvent("SmartBulletsDetected", P.IMPORTANT,
        "When a bot witnesses smart bullet tracers from {{player}}.",
        {
            "What are those red beams?! That's not normal!",
            "Those tracers — someone has some kind of auto-aim!",
            "Those aren't normal bullets — they're tracking!",
            "RED BEAMS! Someone has traitor tech!",
        },
        {
            [A.Casual] = { "yo what are those red lasers", "bro has aimbot bullets" },
            [A.Hothead] = { "WHAT THE HELL ARE THOSE RED BEAMS?!" },
        }
    )

    RegisterSimpleEvent("SmartBulletsKOS", P.CRITICAL,
        "When a bot identifies the smart bullets user as a traitor.",
        {
            "KOS {{player}}! They're using smart bullets!",
            "It's {{player}}! They have auto-aim bullets, kill them!",
            "{{player}} has tracking rounds — they're a traitor!",
        },
        {
            [A.Casual] = { "kos {{player}} they got aimbot bullets" },
        }
    )

    RegisterSimpleEvent("SmartBulletsWarning", P.IMPORTANT,
        "When a bot warns others about a smart bullets user.",
        {
            "Be careful, someone has homing bullets out there.",
            "Watch the red tracers — stay behind cover!",
            "Don't go out in the open, there's a smart bullets user.",
        },
        {
            [A.Casual] = { "careful there's aimbot bullets flying around" },
        }
    )

    RegisterSimpleEvent("SmartBulletsSurvived", P.NORMAL,
        "When a bot survives the smart bullets buff duration.",
        {
            "I think the tracking effect wore off...",
            "The red beams stopped. Safe to peek?",
            "Smart bullets seem to be done — pushing!",
        },
        {
            [A.Casual] = { "i think the aimbot wore off" },
        }
    )

end


local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadMiscChats()
end
timer.Simple(1, loadModule_Deferred)
