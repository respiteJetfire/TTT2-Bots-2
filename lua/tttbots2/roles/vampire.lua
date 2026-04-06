--- Vampire role integration for TTT Bots 2
--- The Vampire is a Traitor with a Bloodlust mechanic:
---   • Must kill at least one player every `ttt2_vamp_bloodtime` seconds (default 60).
---   • When the timer expires without a kill, the Vampire enters Bloodlust:
---       - Loses 1 HP every 2 seconds (passive drain).
---       - All damage dealt heals the Vampire (50% lifesteal).
---       - Deals 1.125× damage.
---       - Max health can increase up to ttt2_vamp_maxhealth (250) via lifesteal.
---   • The Vampire can transform into a pigeon/bat (MOVETYPE_FLY) while in Bloodlust.
---     Transformed: invisible, no weapons, fly mode. Untransforming restores weapons.
---
--- Bot strategy:
---   • Track InBloodlust NWBool — when Bloodlust is active, immediately hunt and kill.
---   • Periodically check how close the bloodlust timer is; escalate aggression as
---     the timer approaches expiry.
---   • While in Bloodlust, be aggressive (lifesteal means taking damage heals you).
---   • Do NOT use pigeon transform for combat — use it only to reposition if trapped.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_VAMPIRE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Vampire, a Traitor who must kill regularly to survive. "
    .. "If you go " .. (GetConVar("ttt2_vamp_bloodtime") and GetConVar("ttt2_vamp_bloodtime"):GetInt() or 60)
    .. " seconds without a kill, you enter Bloodlust: you take passive HP drain "
    .. "but your attacks heal you (50% lifesteal) and deal bonus damage. "
    .. "In Bloodlust, be aggressive — the lifesteal keeps you alive as long as you keep hitting enemies. "
    .. "You can also transform into a bat/pigeon while in Bloodlust for repositioning, "
    .. "but you lose all weapons while transformed so use it carefully."

local bTree = {
    _prior.Requests,
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Grenades,
    _bh.VampireHunt,        -- Urgency-based hunting tied to bloodlust timer
    _prior.Support,
    _prior.Deception,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local vampire = TTTBots.RoleData.New("vampire")
vampire:SetDefusesC4(false)
vampire:SetPlantsC4(true)
vampire:SetTeam(TEAM_TRAITOR)
vampire:SetBTree(bTree)
vampire:SetCanCoordinate(true)
vampire:SetCanHaveRadar(true)
vampire:SetStartsFights(true)
vampire:SetUsesSuspicion(false)
vampire:SetCanSnipe(true)
vampire:SetCanHide(true)
vampire:SetKnowsLifeStates(true)   -- isOmniscientRole
vampire:SetLovesTeammates(true)
vampire:SetAlliedTeams({ [TEAM_TRAITOR] = true })
vampire:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(vampire)

-- ---------------------------------------------------------------------------
-- Helper: is this vampire bot currently in Bloodlust?
-- ---------------------------------------------------------------------------

---@param bot Player
---@return boolean
function TTTBots.Vampire_IsInBloodlust(bot)
    if not IsValid(bot) then return false end
    return bot:GetNWBool("InBloodlust", false)
end

---@param bot Player
---@return number  Seconds remaining before bloodlust activates (0 = already active).
function TTTBots.Vampire_SecsUntilBloodlust(bot)
    if not IsValid(bot) then return 0 end
    if TTTBots.Vampire_IsInBloodlust(bot) then return 0 end
    local expiry = bot:GetNWInt("Bloodlust", 0)
    if expiry <= 0 then return 60 end  -- not set yet, assume full timer
    return math.max(0, expiry - CurTime())
end

print("[TTT Bots 2] Vampire role integration loaded.")
return true
