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
