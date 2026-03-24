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
