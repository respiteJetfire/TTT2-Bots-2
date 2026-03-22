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
