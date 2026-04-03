TTTBots.Behaviors = {}

---@enum BStatus
TTTBots.STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

-- Load meta files first so factories are available to individual behavior files
include("tttbots2/behaviors/meta_base.lua")
include("tttbots2/behaviors/meta_roleweapon.lua")
TTTBots.Lib.IncludeDirectory("tttbots2/behaviors")

---@alias Tree table<BBase|Tree>

TEAM_TRAITOR = TEAM_TRAITOR or "traitors"
TEAM_INNOCENT = TEAM_INNOCENT or "innocents"
TEAM_NONE = TEAM_NONE or "none"


local _bh = TTTBots.Behaviors

TTTBots.Behaviors.PriorityNodes = {
    --- Fight back vs the environment (blocking props) or other players.
    FightBack = {
        _bh.PanicRetreat,
        _bh.ClearBreakables,
        _bh.AttackTarget,
        _bh.SeekCover,
    },

    --- Defend self from accusations or KOS calls (below FightBack, above social)
    SelfDefense = {
        _bh.CombatRetreat,
        _bh.Retreat,
        _bh.DefendSelf,
    },

    --- Throw grenades situationally
    Grenades = {
        _bh.UseGrenade,
        _bh.UseRevealGrenade,
    },

    --- Accuse players based on evidence (between SelfDefense and Chatter)
    Accuse = {
        _bh.AccusePlayer,
    },

    Chatter = {
        _bh.ChatterHelp,
        _bh.VouchForPlayer,
    },

    Convert = {
        _bh.CreateDefector,
        _bh.CreateMedic,
        _bh.CreateDoctor,
        _bh.PriestConvert,
        _bh.CreateCursed,
        _bh.CreateDeputy,
        _bh.CreateSidekick,
        _bh.CreateSlave,
        _bh.SwapDeagle,
        _bh.SwapRole,
        _bh.CopyRole,
        _bh.DropContract,
        _bh.RoleChangeDeagle,
    },

    --- Lock doors after kills to trap bodies
    TrapPlayer = {
        _bh.TrapPlayer,
    },

    --- Knife-stalk: silent melee kills on isolated targets (200dmg knife mod)
    KnifeStalk = {
        _bh.KnifeStalk,
    },

    --- Restore values, like health, ammo, etc.
    Restore = {
        _bh.GetPirateContract,
        _bh.GetWeapons,
        _bh.LootNearby,
        _bh.ClaimConsignment,
        _bh.BreakConsignment,
        _bh.RequestConsignment,
        _bh.UseHealthStation
    },
    --- Investigate corpses/noises.
    Investigate = {
        _bh.InvestigateCorpse,
        _bh.InvestigateNoise
    },
    --- Patrolling stuffs
    Patrol = {
        _bh.Follow,
        _bh.GroupUp,
        _bh.Wander
    },
    --- Minge around with others
    Minge = {
        _bh.MingeCrowbar,
    },

    --- Activate traitor buttons on the map
    TraitorButton = {
        _bh.UseTraitorButton,
    },

    --- Use Traitor Checkers, heal players and revive players
    Support = {
        _bh.Defib,
        _bh.Healgun,
        _bh.Roledefib
    },
    --- Deploy turrets, use timestop, use peacekeeper, NPC launchers
    TacticalEquipment = {
        _bh.UseTurret,
        _bh.UseTimestop,
        _bh.UseGravityMine,
        _bh.UseCombineLauncher,
        _bh.UseFastZombieLauncher,
        _bh.UseHeadcrabLauncher,
    },
    --- DNA Scanner usage for detective roles
    DNAScanner = {
        _bh.UseDNAScanner,
    },
    --- Traitor deception behaviors (alibi building, fake investigation, false KOS, excuses)
    Deception = {
        _bh.AlibiBuilding,
        _bh.FakeInvestigate,
        _bh.FalseKOS,
        _bh.PlausibleIgnorance,
    },
    Requests = {
        _bh.CeaseFire,
        _bh.Wait,
        _bh.RequestUseRoleChecker,
        _bh.ComeHere,
        _bh.FollowMe,
        _bh.UseRoleChecker,
    }
}

local _prior = TTTBots.Behaviors.PriorityNodes

---@type table<string, Tree>
TTTBots.Behaviors.DefaultTrees = {
    innocent = {
        _bh.EvadeGravityMine,
        _prior.FightBack,
        _prior.SelfDefense,
        _prior.Requests,
        _prior.Chatter,
        _prior.Grenades,
        _prior.Accuse,
        _bh.InvestigateCorpse,    -- High priority: ID bodies ASAP for intel
        _bh.FollowInnocentPlan,
        _prior.Support,
        _bh.Defuse,
        _prior.Restore,
        _bh.Interact,
        _prior.Investigate,
        _prior.Minge,
        _bh.Decrowd,
        _prior.Patrol
    },
    traitor = {
        _bh.EvadeGravityMine,
        _bh.Jihad,
        _bh.UsePeacekeeper,
        _bh.ActivateSmartBullets,
        _prior.Grenades,
        _prior.Chatter,
        _prior.FightBack,
        _prior.SelfDefense,
        _prior.Requests,
        _prior.Convert,
        _prior.TacticalEquipment,
        _prior.TrapPlayer,
        _prior.KnifeStalk,
        _prior.Support,
        _bh.Roledefib,
        _bh.PlantBomb,
        _prior.TraitorButton,
        _bh.InvestigateCorpse,
        _prior.Restore,
        _bh.FollowPlan,
        _prior.Deception,
        _bh.Interact,
        _prior.Minge,
        _prior.Investigate,
        _prior.Patrol
    },
    detective = {
        _bh.EvadeGravityMine,
        _prior.FightBack,
        _prior.SelfDefense,
        _prior.Chatter,
        _prior.Grenades,
        _prior.Requests,
        _prior.Accuse,
        _bh.InvestigateCorpse,    -- High priority: detectives MUST ID bodies for intel
        _prior.DNAScanner,        -- Promoted: DNA scanning is core detective work, right after body ID
        _prior.Convert,           -- Sheriffs should deputize early; high priority
        _prior.Restore,           -- Detectives must acquire weapons early (before plans)
        _bh.FollowInnocentPlan,
        _prior.Support,
        _prior.TacticalEquipment,
        _bh.Defuse,
        _bh.ActiveInvestigate,    -- Detective proactively searches quiet areas when no leads
        _bh.Interact,
        _prior.Minge,
        _prior.Investigate,
        _bh.Decrowd,
        _prior.Patrol
    }
}
TTTBots.Behaviors.DefaultTreesByTeam = {
    [TEAM_TRAITOR] = TTTBots.Behaviors.DefaultTrees.traitor,
    [TEAM_INNOCENT] = TTTBots.Behaviors.DefaultTrees.innocent,
    [TEAM_NONE] = TTTBots.Behaviors.DefaultTrees.innocent,
}

local STATUS = TTTBots.STATUS

---@class Bot
---@field lastBehavior BBase?

--- Returns the highest priority tree that has a callback which returned true on this bot.
---@param bot Bot
---@return Tree
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end
    local role = TTTBots.Roles.GetRoleFor(bot)
    if not role then return nil end
    return role:GetBTree()
end

--- Iterates over the node (or Tree if you're pedantic)
--- and performs logic accordingly. Can set bot.lastBehavior if successful
---@param bot Bot
---@param tree Tree
---@return boolean yield Should we stop any further calls?
function TTTBots.Behaviors.IterateNode(bot, tree)
    local lastBehavior = bot.lastBehavior
    -- Iterate through each node in this tree to see if we can find something that will work.
    for _, node in ipairs(tree) do
        if node.Validate == nil then
            -- If validate is nil then this is another Tree within this Tree, which is acceptable.
            local yield = TTTBots.Behaviors.IterateNode(bot, node)
            if yield then return true end

            -- If our tree-child didn't want us to yield, let's keep iterating through our other kiddos.
            -- Continue to the next node.
            continue
        end

        ---@cast node BBase
        local valid = node.Validate(bot)
        if not valid then continue end

        if lastBehavior == node then
            -- If we have already ran this action once just now, then try OnRunning instead.
            local ranResult = node.OnRunning(bot)

            if ranResult == STATUS.RUNNING then
                return true
            elseif ranResult == STATUS.FAILURE then
                bot.lastBehavior = nil
                node.OnFailure(bot)
                node.OnEnd(bot)
            elseif ranResult == STATUS.SUCCESS then
                bot.lastBehavior = nil
                node.OnSuccess(bot)
                node.OnEnd(bot)
            end

            return true
        end

        if lastBehavior ~= nil then
            -- If we have a last behavior, then we need to end it.
            lastBehavior.OnFailure(bot)
            lastBehavior.OnEnd(bot)
        end

        -- We just got here. Run OnStart.
        node.OnStart(bot)
        bot.lastBehavior = node

        return true
    end

    return false
end

---Executes the tree of a bot
---@param bot Bot
---@param tree Tree
function TTTBots.Behaviors.RunTree(bot, tree)
    local lastBehavior = bot.lastBehavior

    -- Obligatory nil-safety.
    if not (bot and IsValid(bot)) then return end
    if not bot.initialized then return end

    -- If we have a behavior that is currently running and cannot be suddenly stopped, then we must
    -- try to run it again and see what happens.
    -- EXCEPTION: Self-defense (priority 5) always breaks through non-interruptible behaviors.
    -- A bot being shot at must be allowed to fight back regardless of what social/request
    -- behavior it was in (ComeHere, FollowMe, UseRoleChecker, etc.)
    if lastBehavior and not lastBehavior.Interruptible then
        local selfDefensePri = TTTBots.Morality and TTTBots.Morality.PRIORITY and TTTBots.Morality.PRIORITY.SELF_DEFENSE or 5
        local hasSelfDefenseTarget = (bot.attackTarget ~= nil and (bot.attackTargetPriority or 0) >= selfDefensePri)
        if hasSelfDefenseTarget and lastBehavior ~= TTTBots.Behaviors.AttackTarget then
            -- Force-end the current non-interruptible behavior so AttackTarget can run
            lastBehavior.OnFailure(bot)
            lastBehavior.OnEnd(bot)
            bot.lastBehavior = nil
        else
            local result = lastBehavior.OnRunning(bot)
            if result == STATUS.RUNNING then return end
        end
    end

    -- Now we've either finished the last behavior or it was interruptible.
    -- Try running the tree.
    TTTBots.Behaviors.IterateNode(bot, tree)
end

function TTTBots.Behaviors.RunTreeOnBots()
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not bot.components then continue end
        local tree = TTTBots.Behaviors.GetTreeFor(bot)
        if not tree then continue end
        TTTBots.Behaviors.RunTree(bot, tree)
    end
end


timer.Create("TTTBots.Debug.Brain", 0.5, 0, function()
    if not TTTBots.DebugServer then return end
    if not TTTBots.Lib.GetConVarBool("debug_brain") then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (bot and IsValid(bot)) then continue end
        if not (TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        if not (bot.lastBehavior and bot.lastBehavior.Name) then continue end

        TTTBots.DebugServer.DrawText(
            bot:GetPos(),
            bot:Nick() .. ": " .. bot.lastBehavior.Name,
            0.5,
            bot:Nick() .. "_behavior"
        )
    end
end)