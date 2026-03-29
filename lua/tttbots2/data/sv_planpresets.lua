local PLANS = TTTBots.Plans
local ACTIONS = PLANS.ACTIONS
local TARGETS = PLANS.PLANTARGETS
local PRESETS = {
    LowPlayerCount_Standard = {
        Name = "LowPlayerCount_Standard",
        Description = "Standard plan for low player counts (1-4 players)",
        Conditions = {
            PlyMin = 1,
            PlyMax = 4,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 100,
        },
        Jobs = {
            -- 10% chance to plant bomb
            {
                Chance = 10,
                Action = ACTIONS.PLANT,
                Target = TARGETS.ANY_BOMBSPOT,
                MaxAssigned = 1,
                Conditions = {},
                Repeat = false,
            },
            -- everyone else will gather for 10-24 seconds
            {
                Chance = 80,
                Action = ACTIONS.GATHER,
                Target = TARGETS.RAND_UNPOPULAR_AREA,
                MaxAssigned = 99,
                MinDuration = 10,
                MaxDuration = 24,
                Conditions = {
                    MinTraitors = 2,
                },
                Repeat = false,
            },
            -- after gathering, attack any player
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.NEAREST_ENEMY,
                MaxAssigned = 99,
                Conditions = {
                    MinTraitors = 2,
                },
                Repeat = true,
            },
            -- SOLO TRAITOR FALLBACK: lone survivor picks off isolated enemies
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.SHARED_ISOLATED_ENEMY,
                MaxAssigned = 1,
                Conditions = {
                    MaxTraitors = 1,
                },
                Repeat = true,
            },
        }
    },
    MediumPlayerCount_Standard = {
        Name = "MediumPlayerCount_Standard",
        Description = "Standard plan for medium player counts (5-9 players)",
        Conditions = {
            PlyMin = 5,
            PlyMax = 9,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 100,
        },
        Jobs = {
            -- if there are only 2 or fewer traitors, just have one plant
            {
                Chance = 20,
                Action = ACTIONS.PLANT,
                Target = TARGETS.ANY_BOMBSPOT,
                MaxAssigned = 1,
                Conditions = {
                    MaxTraitors = 2,
                },
                Repeat = false,
            },
            -- gather for 5-20 seconds if no human traitors
            {
                Chance = 100,
                Action = ACTIONS.GATHER,
                Target = TARGETS.RAND_UNPOPULAR_AREA,
                MaxAssigned = 99,
                MinDuration = 10,
                MaxDuration = 24,
                Conditions = {
                    MaxHumanTraitors = 0,
                },
                Repeat = false,
            },
            -- kill everyone (multi-traitor)
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.NEAREST_ENEMY,
                MaxAssigned = 99,
                Conditions = {
                    MinTraitors = 2,
                },
                Repeat = true,
            },
            -- SOLO TRAITOR FALLBACK: lone survivor picks off isolated enemies
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.SHARED_ISOLATED_ENEMY,
                MaxAssigned = 1,
                Conditions = {
                    MaxTraitors = 1,
                },
                Repeat = true,
            },
        }
    },
    AveragePlayerCount_Standard = {
        Name = "AveragePlayerCount_Standard",
        Description = "Standard plan for average player counts (10-16 players)",
        Conditions = {
            PlyMin = 10,
            PlyMax = 16,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 100,
        },
        Jobs = {
            -- have 2x plant if there are at least 3 traitors
            {
                Chance = 40,
                Action = ACTIONS.PLANT,
                Target = TARGETS.ANY_BOMBSPOT,
                MaxAssigned = 2,
                Conditions = {
                    MinTraitors = 3,
                },
                Repeat = false,
            },
            -- if there are only 2 or fewer traitors, just have one plant
            {
                Chance = 20,
                Action = ACTIONS.PLANT,
                Target = TARGETS.ANY_BOMBSPOT,
                MaxAssigned = 1,
                Conditions = {
                    MaxTraitors = 2,
                },
                Repeat = false,
            },
            -- have 1 traitor follow a police (defaults to inno if none)
            {
                Chance = 50,
                Action = ACTIONS.FOLLOW,
                Target = TARGETS.RAND_POLICE,
                MaxAssigned = 1,
                Conditions = {},
                Repeat = false,
            },
            -- everyone idle should follow any human traitors for 20-40 seconds (fails if no human traitors)
            {
                Chance = 100,
                Action = ACTIONS.FOLLOW,
                Target = TARGETS.RAND_FRIENDLY_HUMAN,
                MaxAssigned = 99,
                MinDuration = 20,
                MaxDuration = 40,
                Conditions = {
                    MinHumanTraitors = 1,
                },
                Repeat = false,
            },
            -- gather for 5-20 seconds if no human traitors
            {
                Chance = 100,
                Action = ACTIONS.GATHER,
                Target = TARGETS.RAND_UNPOPULAR_AREA,
                MaxAssigned = 99,
                MinDuration = 10,
                MaxDuration = 24,
                Conditions = {
                    MaxHumanTraitors = 0,
                },
                Repeat = false,
            },
            -- kill everyone (multi-traitor coordinated attack)
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.NEAREST_ENEMY,
                MaxAssigned = 99,
                Conditions = {
                    MinTraitors = 2,
                },
                Repeat = true,
            },
            -- SOLO TRAITOR FALLBACK: when all other traitors are dead, the lone
            -- survivor hunts the most isolated enemy instead of being left jobless.
            -- Uses SHARED_ISOLATED_ENEMY so the solo traitor picks off weak targets.
            {
                Chance = 100,
                Action = ACTIONS.ATTACKANY,
                Target = TARGETS.SHARED_ISOLATED_ENEMY,
                MaxAssigned = 1,
                Conditions = {
                    MaxTraitors = 1,
                },
                Repeat = true,
            },
        }
    }
}

PRESETS.Default = PRESETS.AveragePlayerCount_Standard

---------------------------------------------------------------------------
-- Coordinated group-attack presets
--
-- These plans require traitors to TRAVEL TOGETHER and SYNCHRONIZE their
-- attacks on the SAME target.  They use the SHARED_ENEMY / SHARED_ISOLATED_ENEMY
-- target types so every traitor in the job gets the exact same victim, and the
-- COORD_ATTACK action so they stage near the target before striking at once.
---------------------------------------------------------------------------

--- Wolf-Pack Ambush (low player count, 2+ traitors)
--- All traitors gather in an out-of-the-way area, then move as a pack to
--- ambush the most isolated enemy simultaneously.
PRESETS.LowPlayerCount_WolfPack = {
    Name = "LowPlayerCount_WolfPack",
    Description = "Traitors gather then ambush the most isolated enemy together.",
    Conditions = {
        PlyMin = 1,
        PlyMax = 4,
        MinTraitors = 2,
        Chance = 55, -- compete with LowPlayerCount_Standard
    },
    Jobs = {
        -- Gather briefly so traitors start near each other.
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 6,
            MaxDuration = 12,
            Conditions = {},
            Repeat = false,
        },
        -- Coordinated strike on the same isolated enemy.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Hit-Squad (medium player count, 2+ traitors)
--- Traitors converge on the most isolated enemy and strike together,
--- then chain-attack the next shared target.
PRESETS.MediumPlayerCount_HitSquad = {
    Name = "MediumPlayerCount_HitSquad",
    Description = "Traitors converge on isolated enemies and eliminate them one by one.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 9,
        MinTraitors = 2,
        Chance = 50, -- compete with MediumPlayerCount_Standard
    },
    Jobs = {
        -- Short gather so the pack forms up.
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 5,
            MaxDuration = 10,
            Conditions = {},
            Repeat = false,
        },
        -- All traitors attack the SAME isolated enemy at once.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Coordinated Blitz (high player count, 3+ traitors)
--- One traitor plants C4 as a distraction while the rest form a
--- hit-squad that picks off a shared target together, then repeats.
PRESETS.AveragePlayerCount_CoordinatedBlitz = {
    Name = "AveragePlayerCount_CoordinatedBlitz",
    Description = "One traitor plants C4 while the rest group up and attack a shared target in unison.",
    Conditions = {
        PlyMin = 10,
        PlyMax = 16,
        MinTraitors = 3,
        Chance = 45, -- compete with AveragePlayerCount_Standard
    },
    Jobs = {
        -- One traitor plants a bomb as a distraction.
        {
            Chance = 30,
            Action = ACTIONS.PLANT,
            Target = TARGETS.ANY_BOMBSPOT,
            MaxAssigned = 1,
            Conditions = {},
            Repeat = false,
        },
        -- Everyone else gathers first.
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 8,
            MaxDuration = 14,
            Conditions = {},
            Repeat = false,
        },
        -- Coordinated group attack on a shared enemy \u2014 repeats so they
        -- chain through multiple victims one at a time.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Detective Hunt (medium-high player count, 2+ traitors)
--- All traitors converge on the detective (police) first to remove the
--- biggest threat, then coordinate attacks on remaining enemies.
PRESETS.MediumPlayerCount_DetectiveHunt = {
    Name = "MediumPlayerCount_DetectiveHunt",
    Description = "All traitors gang up on the detective first, then hunt remaining enemies together.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 16,
        MinTraitors = 2,
        Chance = 30,
        RequiresPolice = true,
    },
    Jobs = {
        -- Short gather.
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 5,
            MaxDuration = 10,
            Conditions = {},
            Repeat = false,
        },
        -- Coordinated attack on the detective / police player.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.RAND_POLICE,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 25,
            Conditions = {},
            Repeat = false,
        },
        -- After the detective is down, chain-attack shared enemies.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

TTTBots.Plans.PRESETS = PRESETS

---------------------------------------------------------------------------
-- Revival / Conversion Recovery Presets
--
-- These plans activate when a hostile team (traitors, necromancers, etc.)
-- is outnumbered AND has the capability to revive corpses or convert
-- living enemies.  Instead of rushing into fights they can't win, the
-- team splits: some bots roam toward corpses to revive/convert, while
-- one or two create opportunities by isolating targets for kills.
--
-- Key design:
--   1.  One bot stalks / creates a fresh corpse (the "hunter").
--   2.  Bots with revival weapons roam toward corpse-rich areas.
--   3.  After the roam timer, any remaining bots attack to clean up.
--   4.  These presets have HIGHER Chance when the team is heavily
--       outnumbered, giving them priority over pure-aggression plans.
---------------------------------------------------------------------------

--- Revival Blitz — small server: outnumbered team with revive capability.
--- One bot hunts isolated targets to create corpses, others roam to revive.
PRESETS.LowPlayer_RevivalRecovery = {
    Name = "LowPlayer_RevivalRecovery",
    Description = "Outnumbered team with revival capability: create corpses and revive them as allies.",
    Conditions = {
        PlyMin = 1,
        PlyMax = 6,
        MinTraitors = 1,
        TeamOutnumberedRatio = 0.75,
        RequiresReviveOrConvert = true,
        Chance = 70,
    },
    Jobs = {
        -- Hunter: one bot stalks the most isolated enemy to create a corpse.
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 1,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- Revivers: roam toward corpse areas to use defibs/conversion weapons.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 35,
            Conditions = {},
            Repeat = false,
        },
        -- After revive window: coordinated attack on shared enemy.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Revival Recovery — medium server: outnumbered team with revive capability.
--- Split strategy: hunter creates corpses, revivers roam, then all attack.
PRESETS.MediumPlayer_RevivalRecovery = {
    Name = "MediumPlayer_RevivalRecovery",
    Description = "Outnumbered team creates kills then revives the corpses to rebuild numbers.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 9,
        MinTraitors = 1,
        TeamOutnumberedRatio = 0.6,
        RequiresReviveOrConvert = true,
        Chance = 65,
    },
    Jobs = {
        -- Hunter: one bot picks off an isolated enemy.
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 1,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- Revivers: bots with defibs roam toward corpse-rich areas.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 40,
            Conditions = {},
            Repeat = false,
        },
        -- Fallback coordinated attack once revival window is over.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Revival Recovery — large server: heavily outnumbered team.
--- More aggressive split: dedicated bomber distracts, multiple hunters create
--- corpses, revivers fan out to the bodies.
PRESETS.LargePlayer_RevivalRecovery = {
    Name = "LargePlayer_RevivalRecovery",
    Description = "Heavily outnumbered team: bomb distraction + targeted kills + mass revival.",
    Conditions = {
        PlyMin = 10,
        PlyMax = 16,
        MinTraitors = 2,
        TeamOutnumberedRatio = 0.5,
        RequiresReviveOrConvert = true,
        Chance = 60,
    },
    Jobs = {
        -- Bomber distraction: one bot plants C4 to draw attention away.
        {
            Chance = 30,
            Action = ACTIONS.PLANT,
            Target = TARGETS.ANY_BOMBSPOT,
            MaxAssigned = 1,
            Conditions = {},
            Repeat = false,
        },
        -- Hunters: up to 2 bots stalk isolated enemies to create corpses.
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 2,
            MinDuration = 10,
            MaxDuration = 25,
            Conditions = {},
            Repeat = false,
        },
        -- Revivers: remaining bots roam toward corpses.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 40,
            Conditions = {},
            Repeat = false,
        },
        -- Final push: coordinated attack.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Conversion Blitz — team has conversion weapons (sidekick deagle, etc.)
--- and is outnumbered. Bots roam to find living targets for conversion,
--- with one bot stalking isolated enemies in case conversion fails.
PRESETS.ConversionRecovery = {
    Name = "ConversionRecovery",
    Description = "Outnumbered team with conversion capability: seek out isolated targets to convert.",
    Conditions = {
        PlyMin = 4,
        PlyMax = 16,
        MinTraitors = 1,
        TeamOutnumberedRatio = 0.65,
        RequiresConvertCapability = true,
        Chance = 55,
    },
    Jobs = {
        -- Follow an isolated enemy at a distance (conversion prep).
        {
            Chance = 100,
            Action = ACTIONS.FOLLOW,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 2,
            MinDuration = 10,
            MaxDuration = 25,
            Conditions = {},
            Repeat = false,
        },
        -- Others roam unpopular areas looking for stragglers to convert.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 35,
            Conditions = {},
            Repeat = false,
        },
        -- Cleanup: attack remaining enemies.
        {
            Chance = 100,
            Action = ACTIONS.ATTACKANY,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Corpse Harvest — there are already corpses on the map AND the team has
--- revive capability. Skip the "create corpses" phase and immediately roam
--- to revive. This is the fastest recovery plan.
PRESETS.CorpseHarvest = {
    Name = "CorpseHarvest",
    Description = "Corpses already exist — immediately roam to revive them.",
    Conditions = {
        PlyMin = 1,
        PlyMax = 16,
        MinTraitors = 1,
        TeamOutnumberedRatio = 0.75,
        RequiresReviveCapability = true,
        MinCorpses = 1,
        Chance = 80,
    },
    Jobs = {
        -- Everyone roam to corpses for immediate revival.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 10,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- After revival window: coordinated strike.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

---------------------------------------------------------------------------
-- Knife-Stalk Presets (200-damage knife mod)
--
-- When the 200dmg knife mod is installed, traitor bots can silently
-- one-hit-kill isolated targets with the knife.  These plans send bots to
-- roam toward isolated enemies, stab them, then revive the corpse (if they
-- have a roledefib) or chain to the next target.
--
-- The KnifeModInstalled condition is checked at plan selection time via a
-- custom condition function.
---------------------------------------------------------------------------

--- Knife Hunter — low player count: all traitors spread out and silently
--- knife isolated targets one by one, using roledefib between kills.
PRESETS.KnifeHunter_LowPlayer = {
    Name = "KnifeHunter_LowPlayer",
    Description = "Traitors silently knife isolated targets (200dmg knife mod, low player count).",
    Conditions = {
        PlyMin = 1,
        PlyMax = 6,
        MinTraitors = 1,
        Chance = 65,
        KnifeModInstalled = true,
    },
    Jobs = {
        -- Roam toward isolated areas to find lone targets.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 10,
            MaxDuration = 20,
            Conditions = {},
            Repeat = false,
        },
        -- Stalk and attack the most isolated enemy.
        -- The KnifeStalk behavior in the traitor tree will pick up the knife
        -- automatically when close enough.
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 35,
            Conditions = {},
            Repeat = false,
        },
        -- After the first kill: roam to corpse areas to use roledefib.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 10,
            MaxDuration = 25,
            Conditions = {
                RequiresReviveOrConvert = true,
            },
            Repeat = false,
        },
        -- Chain: attack next isolated target.
        {
            Chance = 100,
            Action = ACTIONS.ATTACKANY,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Knife Pack — medium player count: one traitor plants C4 as distraction,
--- the rest spread out for silent knife kills then regroup for revives.
PRESETS.KnifeHunter_MediumPlayer = {
    Name = "KnifeHunter_MediumPlayer",
    Description = "Traitors spread out for silent knife kills, with C4 distraction (200dmg knife mod).",
    Conditions = {
        PlyMin = 5,
        PlyMax = 10,
        MinTraitors = 2,
        Chance = 55,
        KnifeModInstalled = true,
    },
    Jobs = {
        -- Optional C4 distraction.
        {
            Chance = 25,
            Action = ACTIONS.PLANT,
            Target = TARGETS.ANY_BOMBSPOT,
            MaxAssigned = 1,
            Conditions = {},
            Repeat = false,
        },
        -- Brief roam to spread out.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 8,
            MaxDuration = 16,
            Conditions = {},
            Repeat = false,
        },
        -- Each traitor stalks the most isolated enemy for a knife kill.
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- Roam to corpses for roledefib if available.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 10,
            MaxDuration = 25,
            Conditions = {
                RequiresReviveOrConvert = true,
            },
            Repeat = false,
        },
        -- Chain kills on remaining isolated enemies.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Knife Assassin — large player count: traitors split between distraction
--- (C4 + following police) and dedicated knife assassins who silently pick
--- off isolated targets and revive them as traitors.
PRESETS.KnifeHunter_LargePlayer = {
    Name = "KnifeHunter_LargePlayer",
    Description = "Dedicated knife assassins with distraction support (200dmg knife mod, large server).",
    Conditions = {
        PlyMin = 10,
        PlyMax = 16,
        MinTraitors = 2,
        Chance = 45,
        KnifeModInstalled = true,
    },
    Jobs = {
        -- One traitor plants C4 as distraction.
        {
            Chance = 35,
            Action = ACTIONS.PLANT,
            Target = TARGETS.ANY_BOMBSPOT,
            MaxAssigned = 1,
            Conditions = {},
            Repeat = false,
        },
        -- One traitor shadows the detective to monitor investigations.
        {
            Chance = 50,
            Action = ACTIONS.FOLLOW,
            Target = TARGETS.RAND_POLICE,
            MaxAssigned = 1,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- Remaining traitors roam to spread out.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 8,
            MaxDuration = 15,
            Conditions = {},
            Repeat = false,
        },
        -- Silent knife kills on isolated targets.
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- Revive corpses with roledefib.
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 10,
            MaxDuration = 25,
            Conditions = {
                RequiresReviveOrConvert = true,
            },
            Repeat = false,
        },
        -- Chain coordinated attacks on survivors.
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

---------------------------------------------------------------------------
-- Loadout-Aware Dynamic Plan Presets
--
-- These plans require specific weapon categories to be present on the
-- coordinating team.  Each preset includes a SynergyScore function that
-- dynamically adjusts its selection weight based on the team's actual
-- loadout, remaining credits, and enemy distribution.
--
-- SynergyScore(loadout, enemyDist) → number
--   loadout:  result of TTTBots.Plans.AnalyzeTeamLoadout()
--   enemyDist: result of TTTBots.Plans.AnalyzeEnemyDistribution()
--   Returns a bonus (positive) or penalty (negative) applied to the
--   preset's base Chance during weighted selection.
---------------------------------------------------------------------------

--- Firepower Blitz — team has heavy weapons; rush in with overwhelming DPS.
--- Multiple coordinators armed with miniguns/arson throwers gather briefly
--- then blitz a shared target.  Higher synergy when the entire team has
--- heavy firepower, and when enemies are clustered for maximum splash.
PRESETS.Loadout_FirepowerBlitz = {
    Name = "Loadout_FirepowerBlitz",
    Description = "Heavy-firepower team gathers and blitzes enemies with raw DPS.",
    Conditions = {
        PlyMin = 3,
        PlyMax = 16,
        MinTraitors = 2,
        RequiresHeavyFirepower = true,
        Chance = 40,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- More heavy-weapon carriers → stronger blitz
        bonus = bonus + (loadout.HeavyFirepowerCount or 0) * 12
        -- Smart weapons pair well with heavy firepower
        if loadout.HasSmartWeapons then bonus = bonus + 10 end
        -- Clustered enemies are ideal targets for raw DPS
        if enemyDist.ClusteredEnemies >= 2 then bonus = bonus + 15 end
        -- Penalty if enemies are mostly isolated (blitz is less efficient)
        if enemyDist.IsolatedEnemies > enemyDist.TotalEnemies * 0.6 then
            bonus = bonus - 10
        end
        return bonus
    end,
    Jobs = {
        -- Brief gather to form up
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 5,
            MaxDuration = 10,
            Conditions = {},
            Repeat = false,
        },
        -- Coordinated blitz on the shared target — raw DPS wins
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 25,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Stealth Assassination — team has stealth weapons (poison dart, dead ringer).
--- Traitors spread out and silently pick off isolated targets. Favored when
--- enemies are scattered and the team has good stealth scores.
PRESETS.Loadout_StealthAssassination = {
    Name = "Loadout_StealthAssassination",
    Description = "Stealth-equipped team fans out to silently eliminate isolated targets.",
    Conditions = {
        PlyMin = 3,
        PlyMax = 16,
        MinTraitors = 1,
        RequiresStealthWeapons = true,
        MinIsolatedEnemies = 1,
        Chance = 35,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- More stealth-equipped bots → more parallel kills
        bonus = bonus + (loadout.StealthWeaponsCount or 0) * 10
        -- High team stealth score → plan fits well
        bonus = bonus + (loadout.TeamStealthScore or 0) * 0.3
        -- Many isolated enemies → prime targets
        bonus = bonus + (enemyDist.IsolatedEnemies or 0) * 8
        -- Penalty if enemies are clustered (stealth is harder in crowds)
        if (enemyDist.ClusteredEnemies or 0) > (enemyDist.TotalEnemies or 1) * 0.5 then
            bonus = bonus - 15
        end
        -- Survival items help stealthy play
        if loadout.HasSurvivalItems then bonus = bonus + 5 end
        return bonus
    end,
    Jobs = {
        -- Spread out to find isolated targets
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 10,
            MaxDuration = 20,
            Conditions = {},
            Repeat = false,
        },
        -- Stalk and attack the most isolated enemy
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- If revival weapons available, roam to corpses after stealth kills
        {
            Chance = 80,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 10,
            MaxDuration = 20,
            Conditions = {
                RequiresReviveOrConvert = true,
            },
            Repeat = false,
        },
        -- Chain remaining kills
        {
            Chance = 100,
            Action = ACTIONS.ATTACKANY,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Smart Weapons Strike — team has smart pistols and/or smart bullets.
--- Gather to activate smart bullets during the gather phase, then coordinate
--- attack with tracking advantage.
PRESETS.Loadout_SmartWeaponsStrike = {
    Name = "Loadout_SmartWeaponsStrike",
    Description = "Smart-weapon equipped team gathers, activates buffs, and strikes with tracking advantage.",
    Conditions = {
        PlyMin = 3,
        PlyMax = 16,
        MinTraitors = 2,
        RequiresSmartWeapons = true,
        Chance = 45,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- Smart weapons count directly boosts this plan
        bonus = bonus + (loadout.SmartWeaponsCount or 0) * 15
        -- Heavy firepower pairs great with smart bullets
        if loadout.HasHeavyFirepower then bonus = bonus + 12 end
        -- Smart weapons excel in medium-range fights, not extreme isolation
        if (enemyDist.AvgEnemyGroupSize or 1) >= 1.5 then bonus = bonus + 8 end
        return bonus
    end,
    Jobs = {
        -- Extended gather: time for ActivateSmartBullets behavior to trigger
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 8,
            MaxDuration = 16,
            Conditions = {},
            Repeat = false,
        },
        -- Coordinated strike while smart bullets are active
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Area Denial Lockdown — team has turrets, mines, or C4.
--- Deploy area denial weapons around a position, then herd enemies into
--- the kill zone with coordinated attacks from the other side.
PRESETS.Loadout_AreaDenialLockdown = {
    Name = "Loadout_AreaDenialLockdown",
    Description = "Area-denial team deploys traps and turrets, then herds enemies into the kill zone.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 16,
        MinTraitors = 2,
        RequiresAreaDenial = true,
        Chance = 35,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- Multiple area denial tools compound effectiveness
        bonus = bonus + (loadout.AreaDenialCount or 0) * 10
        -- Explosives synergize with area denial
        if loadout.HasExplosives then bonus = bonus + 10 end
        -- Clustered enemies walk into traps more easily
        if (enemyDist.ClusteredEnemies or 0) >= 2 then bonus = bonus + 12 end
        -- Popular areas are better for trap placement
        bonus = bonus + (loadout.TeamUtilityScore or 0) * 0.2
        return bonus
    end,
    Jobs = {
        -- One bot plants C4 / deploys traps at a popular choke point
        {
            Chance = 50,
            Action = ACTIONS.PLANT,
            Target = TARGETS.ANY_BOMBSPOT,
            MaxAssigned = 1,
            Conditions = {},
            Repeat = false,
        },
        -- Remaining bots gather near a different area
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 8,
            MaxDuration = 15,
            Conditions = {},
            Repeat = false,
        },
        -- Coordinated attack to push enemies toward the trapped area
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Explosive Chaos — team has multiple explosive/grenade weapons.
--- Open with bomb planting for distraction, scatter for grenade attacks,
--- then swarm remaining targets.  Best when enemies are grouped.
PRESETS.Loadout_ExplosiveChaos = {
    Name = "Loadout_ExplosiveChaos",
    Description = "Explosives-heavy team plants distractions and creates chaos with AoE damage.",
    Conditions = {
        PlyMin = 4,
        PlyMax = 16,
        MinTraitors = 2,
        RequiresExplosives = true,
        Chance = 35,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- Multiple explosives = more chaos
        bonus = bonus + (loadout.ExplosivesCount or 0) * 10
        -- Grenades compound the effect
        bonus = bonus + (loadout.GrenadeCount or 0) * 6
        -- Clustered enemies are perfect for AoE
        if (enemyDist.ClusteredEnemies or 0) >= 3 then bonus = bonus + 20 end
        if (enemyDist.AvgEnemyGroupSize or 1) >= 2 then bonus = bonus + 10 end
        -- Penalty if enemies are all isolated (AoE is wasted)
        if (enemyDist.IsolatedEnemies or 0) >= (enemyDist.TotalEnemies or 1) * 0.7 then
            bonus = bonus - 15
        end
        return bonus
    end,
    Jobs = {
        -- Lead with a C4 distraction
        {
            Chance = 60,
            Action = ACTIONS.PLANT,
            Target = TARGETS.ANY_BOMBSPOT,
            MaxAssigned = 2,
            Conditions = {},
            Repeat = false,
        },
        -- Brief roam to position for grenade attacks
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.RAND_POPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 6,
            MaxDuration = 12,
            Conditions = {},
            Repeat = false,
        },
        -- Attack from range (grenades + explosives)
        {
            Chance = 100,
            Action = ACTIONS.ATTACKANY,
            Target = TARGETS.NEAREST_ENEMY,
            MaxAssigned = 99,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Disrupt and Strike — team has disruption weapons (EMP, timestop, dance gun).
--- Lead with disruption to disable equipment and freeze enemies, then follow
--- up with coordinated attack while enemies are helpless.
PRESETS.Loadout_DisruptAndStrike = {
    Name = "Loadout_DisruptAndStrike",
    Description = "Disruption-equipped team disables enemies first, then strikes while they're helpless.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 16,
        MinTraitors = 2,
        RequiresDisruption = true,
        RequiresPolice = true,
        Chance = 40,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- Multiple disruption tools increase effectiveness
        bonus = bonus + (loadout.DisruptionCount or 0) * 12
        -- Disruption is most valuable against police (EMP → equipment)
        if enemyDist.HasPoliceCluster then bonus = bonus + 15 end
        -- Smart or heavy weapons make the follow-up strike lethal
        if loadout.HasSmartWeapons then bonus = bonus + 10 end
        if loadout.HasHeavyFirepower then bonus = bonus + 10 end
        return bonus
    end,
    Jobs = {
        -- One bot follows the police to position for EMP/disruption
        {
            Chance = 80,
            Action = ACTIONS.FOLLOW,
            Target = TARGETS.RAND_POLICE,
            MaxAssigned = 1,
            MinDuration = 10,
            MaxDuration = 20,
            Conditions = {},
            Repeat = false,
        },
        -- Others gather to prepare the strike
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 8,
            MaxDuration = 14,
            Conditions = {},
            Repeat = false,
        },
        -- Coordinated strike on police first
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.RAND_POLICE,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 25,
            Conditions = {},
            Repeat = false,
        },
        -- Chain attack on remaining enemies
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Revival Snowball — team has revival weapons AND heavy firepower.
--- Instead of the desperate RevivalRecovery plans, this is an OFFENSIVE
--- revival strategy: use heavy weapons to create kills quickly, then
--- immediately revive corpses as traitors, snowballing the team size.
PRESETS.Loadout_RevivalSnowball = {
    Name = "Loadout_RevivalSnowball",
    Description = "Well-armed team with revival: kill fast, revive faster, snowball team size.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 16,
        MinTraitors = 2,
        RequiresReviveCapability = true,
        MinFirepowerScore = 25,
        Chance = 45,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- Revival + firepower is the core synergy
        bonus = bonus + (loadout.RevivalWeaponsCount or 0) * 15
        bonus = bonus + (loadout.TeamFirepowerScore or 0) * 0.3
        -- Smart weapons accelerate kill speed for faster revivals
        if loadout.HasSmartWeapons then bonus = bonus + 8 end
        -- Existing corpses mean we can start snowballing immediately
        local numCorpses = 0
        if TTTBots.Lib.GetRevivableCorpses then
            numCorpses = #TTTBots.Lib.GetRevivableCorpses()
        end
        bonus = bonus + numCorpses * 5
        return bonus
    end,
    Jobs = {
        -- Hunter: one or two bots attack to create corpses quickly
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 2,
            MinDuration = 10,
            MaxDuration = 20,
            Conditions = {},
            Repeat = false,
        },
        -- Revivers: remaining bots roam to corpses to revive as allies
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 12,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- After revival window: coordinate the now-larger team for assault
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Mixed Adaptive — team has a mix of weapon types but no single dominant
--- category. This plan adapts by splitting roles: scouts/flankers spread out
--- while the main strike group gathers. The SynergyScore rewards diverse
--- loadouts.
PRESETS.Loadout_MixedAdaptive = {
    Name = "Loadout_MixedAdaptive",
    Description = "Diverse-loadout team splits into flankers and a main strike group.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 16,
        MinTraitors = 3,
        Chance = 30,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- Reward loadout diversity: count how many different categories are present
        local categories = 0
        if loadout.HasHeavyFirepower then categories = categories + 1 end
        if loadout.HasStealthWeapons then categories = categories + 1 end
        if loadout.HasSmartWeapons then categories = categories + 1 end
        if loadout.HasExplosives then categories = categories + 1 end
        if loadout.HasAreaDenial then categories = categories + 1 end
        if loadout.HasGrenades then categories = categories + 1 end
        if loadout.HasDisruption then categories = categories + 1 end
        if loadout.HasRevivalWeapons then categories = categories + 1 end
        if loadout.HasConversionWeapons then categories = categories + 1 end
        -- Diverse loadout (3+ categories) benefits from adaptive plan
        if categories >= 4 then
            bonus = bonus + categories * 6
        elseif categories >= 3 then
            bonus = bonus + categories * 4
        else
            -- Not diverse enough — this plan isn't ideal
            bonus = bonus - 10
        end
        -- Mixed distribution of enemies rewards adaptive approach
        if enemyDist.IsolatedEnemies >= 1 and enemyDist.ClusteredEnemies >= 1 then
            bonus = bonus + 10
        end
        return bonus
    end,
    Jobs = {
        -- Flanker: one bot roams to find isolated targets
        {
            Chance = 80,
            Action = ACTIONS.ROAM,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 1,
            MinDuration = 10,
            MaxDuration = 20,
            Conditions = {},
            Repeat = false,
        },
        -- Scout: one bot follows police to gather intel
        {
            Chance = 50,
            Action = ACTIONS.FOLLOW,
            Target = TARGETS.RAND_POLICE,
            MaxAssigned = 1,
            MinDuration = 10,
            MaxDuration = 20,
            Conditions = {},
            Repeat = false,
        },
        -- Optional bomb distraction
        {
            Chance = 25,
            Action = ACTIONS.PLANT,
            Target = TARGETS.ANY_BOMBSPOT,
            MaxAssigned = 1,
            Conditions = {},
            Repeat = false,
        },
        -- Main group gathers
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 8,
            MaxDuration = 14,
            Conditions = {},
            Repeat = false,
        },
        -- Coordinated attack once flanker has engaged
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Credit Reserve Adaptive — team has significant unspent credits.
--- Start with passive observation (follow/roam) to assess the situation,
--- then buy reactively based on mid-round opportunities via deferred events.
--- The extra gather time also lets personality-driven behaviors (smart bullets
--- activation, grenade use) trigger naturally.
PRESETS.Loadout_CreditReserveAdaptive = {
    Name = "Loadout_CreditReserveAdaptive",
    Description = "Credit-rich team observes first, buys reactively mid-round, then strikes.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 16,
        MinTraitors = 2,
        MinTeamCredits = 4,
        Chance = 25,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- More unspent credits → more adaptive potential
        bonus = bonus + math.min((loadout.TotalCreditsRemaining or 0) * 4, 30)
        -- Multiple bots with credits → can all buy reactively
        bonus = bonus + (loadout.CoordinatorsWithCredits or 0) * 5
        -- Penalty if team already has strong loadout (no need to wait)
        if (loadout.TeamFirepowerScore or 0) > 60 then bonus = bonus - 15 end
        return bonus
    end,
    Jobs = {
        -- One bot follows a human traitor or police for intel
        {
            Chance = 70,
            Action = ACTIONS.FOLLOW,
            Target = TARGETS.RAND_FRIENDLY_HUMAN,
            MaxAssigned = 1,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {
                MinHumanTraitors = 1,
            },
            Repeat = false,
        },
        -- Others passively roam to spread out and observe
        {
            Chance = 100,
            Action = ACTIONS.ROAM,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- After observation phase: gather and strike with whatever was bought
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 5,
            MaxDuration = 10,
            Conditions = {},
            Repeat = false,
        },
        -- Final push
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Isolation Hunters — enemies are widely scattered with many isolated targets.
--- Instead of gathering (which wastes time), traitors immediately fan out and
--- pick off isolated enemies in parallel, then regroup for remaining clusters.
--- SynergyScore heavily rewards high isolation counts.
PRESETS.Loadout_IsolationHunters = {
    Name = "Loadout_IsolationHunters",
    Description = "Enemies are scattered — traitors fan out for parallel kills on isolated targets.",
    Conditions = {
        PlyMin = 5,
        PlyMax = 16,
        MinTraitors = 2,
        MinIsolatedEnemies = 2,
        Chance = 40,
    },
    SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        -- Reward high isolation count heavily
        bonus = bonus + (enemyDist.IsolatedEnemies or 0) * 12
        -- Penalty if enemies are mostly clustered (this plan is for scattered enemies)
        if (enemyDist.ClusteredEnemies or 0) > (enemyDist.IsolatedEnemies or 0) then
            bonus = bonus - 15
        end
        -- Stealth weapons are ideal for isolation hunting
        if loadout.HasStealthWeapons then bonus = bonus + 10 end
        -- Smart weapons also help pick off lone targets
        if loadout.HasSmartWeapons then bonus = bonus + 8 end
        -- Any combat weapons help
        bonus = bonus + (loadout.TeamFirepowerScore or 0) * 0.15
        return bonus
    end,
    Jobs = {
        -- Everyone immediately attacks isolated targets (no gather waste)
        {
            Chance = 100,
            Action = ACTIONS.ATTACK,
            Target = TARGETS.SHARED_ISOLATED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = false,
        },
        -- After initial picks: roam to corpses if revival is available
        {
            Chance = 80,
            Action = ACTIONS.ROAM,
            Target = TARGETS.NEAREST_CORPSE_AREA,
            MaxAssigned = 99,
            MinDuration = 10,
            MaxDuration = 20,
            Conditions = {
                RequiresReviveOrConvert = true,
            },
            Repeat = false,
        },
        -- Regroup for remaining enemies
        {
            Chance = 100,
            Action = ACTIONS.GATHER,
            Target = TARGETS.RAND_UNPOPULAR_AREA,
            MaxAssigned = 99,
            MinDuration = 5,
            MaxDuration = 10,
            Conditions = {
                MinTraitors = 2,
            },
            Repeat = false,
        },
        -- Final coordinated push on remaining (now clustered) enemies
        {
            Chance = 100,
            Action = ACTIONS.COORD_ATTACK,
            Target = TARGETS.SHARED_ENEMY,
            MaxAssigned = 99,
            MinDuration = 15,
            MaxDuration = 30,
            Conditions = {},
            Repeat = true,
        },
    },
}

--- Add synergy scores to EXISTING presets so they participate in the
--- weighted selection system rather than only relying on fixed Chance values.

-- Existing standard plans: small synergy bonuses based on general loadout strength
PRESETS.LowPlayerCount_Standard.SynergyScore = function(loadout, enemyDist)
    -- Standard plan is the fallback; slight bonus if loadout is weak (no specialization)
    local bonus = 0
    local categories = 0
    if loadout.HasHeavyFirepower then categories = categories + 1 end
    if loadout.HasStealthWeapons then categories = categories + 1 end
    if loadout.HasSmartWeapons then categories = categories + 1 end
    if loadout.HasExplosives then categories = categories + 1 end
    -- Few categories → standard plan is fine
    if categories <= 1 then bonus = bonus + 5 end
    return bonus
end

PRESETS.MediumPlayerCount_Standard.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    local categories = 0
    if loadout.HasHeavyFirepower then categories = categories + 1 end
    if loadout.HasStealthWeapons then categories = categories + 1 end
    if loadout.HasSmartWeapons then categories = categories + 1 end
    if loadout.HasExplosives then categories = categories + 1 end
    if categories <= 1 then bonus = bonus + 5 end
    return bonus
end

PRESETS.AveragePlayerCount_Standard.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    local categories = 0
    if loadout.HasHeavyFirepower then categories = categories + 1 end
    if loadout.HasStealthWeapons then categories = categories + 1 end
    if loadout.HasSmartWeapons then categories = categories + 1 end
    if loadout.HasExplosives then categories = categories + 1 end
    if categories <= 1 then bonus = bonus + 5 end
    return bonus
end

-- Existing coordinated attack plans: bonus when team has complementary weapons
PRESETS.LowPlayerCount_WolfPack.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    if loadout.HasSmartWeapons then bonus = bonus + 10 end
    if loadout.HasHeavyFirepower then bonus = bonus + 8 end
    if (enemyDist.IsolatedEnemies or 0) >= 1 then bonus = bonus + 5 end
    return bonus
end

PRESETS.MediumPlayerCount_HitSquad.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    if loadout.HasSmartWeapons then bonus = bonus + 12 end
    if loadout.HasGrenades then bonus = bonus + 5 end
    if (enemyDist.IsolatedEnemies or 0) >= 2 then bonus = bonus + 8 end
    return bonus
end

PRESETS.AveragePlayerCount_CoordinatedBlitz.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    if loadout.HasExplosives then bonus = bonus + 10 end
    if loadout.HasHeavyFirepower then bonus = bonus + 8 end
    if loadout.HasSmartWeapons then bonus = bonus + 6 end
    return bonus
end

PRESETS.MediumPlayerCount_DetectiveHunt.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    -- EMP grenades are crucial for detective hunts
    if loadout.HasDisruption then bonus = bonus + 20 end
    if loadout.HasHeavyFirepower then bonus = bonus + 8 end
    -- Police clustered with others means we'll fight multiple enemies
    if enemyDist.HasPoliceCluster then bonus = bonus + 5 end
    return bonus
end

-- Existing revival plans: bonus when team also has combat weapons
PRESETS.LowPlayer_RevivalRecovery.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    bonus = bonus + (loadout.RevivalWeaponsCount or 0) * 8
    if loadout.HasStealthWeapons then bonus = bonus + 10 end -- stealth + revive
    return bonus
end

PRESETS.MediumPlayer_RevivalRecovery.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    bonus = bonus + (loadout.RevivalWeaponsCount or 0) * 8
    if loadout.HasStealthWeapons then bonus = bonus + 8 end
    if loadout.HasHeavyFirepower then bonus = bonus + 5 end
    return bonus
end

PRESETS.LargePlayer_RevivalRecovery.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    bonus = bonus + (loadout.RevivalWeaponsCount or 0) * 8
    if loadout.HasExplosives then bonus = bonus + 10 end -- bombs distract while reviving
    return bonus
end

PRESETS.ConversionRecovery.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    bonus = bonus + (loadout.ConversionWeaponsCount or 0) * 12
    if (enemyDist.IsolatedEnemies or 0) >= 2 then bonus = bonus + 8 end
    return bonus
end

PRESETS.CorpseHarvest.SynergyScore = function(loadout, enemyDist)
    local bonus = 0
    bonus = bonus + (loadout.RevivalWeaponsCount or 0) * 10
    -- Existing corpses are already checked in conditions; bonus scales with count
    local numCorpses = 0
    if TTTBots.Lib.GetRevivableCorpses then
        numCorpses = #TTTBots.Lib.GetRevivableCorpses()
    end
    bonus = bonus + numCorpses * 5
    return bonus
end

-- Existing knife plans: bonus when paired with stealth or revival
if PRESETS.KnifeHunter_LowPlayer then
    PRESETS.KnifeHunter_LowPlayer.SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        if loadout.HasRevivalWeapons then bonus = bonus + 15 end
        if loadout.HasStealthWeapons then bonus = bonus + 8 end
        if (enemyDist.IsolatedEnemies or 0) >= 1 then bonus = bonus + 10 end
        return bonus
    end
end

if PRESETS.KnifeHunter_MediumPlayer then
    PRESETS.KnifeHunter_MediumPlayer.SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        if loadout.HasRevivalWeapons then bonus = bonus + 12 end
        if loadout.HasExplosives then bonus = bonus + 5 end
        if (enemyDist.IsolatedEnemies or 0) >= 2 then bonus = bonus + 8 end
        return bonus
    end
end

if PRESETS.KnifeHunter_LargePlayer then
    PRESETS.KnifeHunter_LargePlayer.SynergyScore = function(loadout, enemyDist)
        local bonus = 0
        if loadout.HasRevivalWeapons then bonus = bonus + 12 end
        if loadout.HasExplosives then bonus = bonus + 8 end
        if loadout.HasStealthWeapons then bonus = bonus + 5 end
        return bonus
    end
end
