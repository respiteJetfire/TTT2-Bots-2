if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PHARAOH then return false end

local pharaoh = TTTBots.RoleData.New("pharaoh")
local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.Requests,
    _prior.FightBack,
    _bh.DefendAnkh,
    _bh.PostRevival,
    _bh.RelocateAnkh,
    _bh.PlantAnkh,
    _bh.CaptureAnkh,
    _bh.GuardAnkh,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.UseHealthStation,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription = "The Pharaoh is an Innocent-aligned role with a special ability: they receive an Ankh weapon that they can place on the ground. If the Pharaoh dies while their Ankh is placed, they automatically revive at the Ankh's position with 50 HP. Standing near your own Ankh heals both you and the Ankh over time. When the Ankh is first placed, a random Traitor is converted into a Graverobber who will try to steal it. Protect your Ankh at all costs!"

pharaoh:SetDefusesC4(true)
pharaoh:SetTeam(TEAM_INNOCENT)
pharaoh:SetCanHide(true)
pharaoh:SetCanSnipe(true)
pharaoh:SetUsesSuspicion(true)
pharaoh:SetBTree(bTree)
pharaoh:SetAlliedRoles({})
pharaoh:SetAlliedTeams({})
pharaoh:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(pharaoh)

return true

