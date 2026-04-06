local Registry = {}

local AllRolesSupported = roles.GetList()

local function GetAllRoles()
    local allRoles = {}
    for _, role in pairs(AllRolesSupported) do
        table.insert(allRoles, roles.Get(role.name))
    end
    return allRoles
end

local AllRoles = GetAllRoles()

local function GetRolesByTeam(team)
    local rolesByTeam = {}
    for _, role in pairs(AllRoles) do
        if role.defaultTeam == team then
            table.insert(rolesByTeam, role.name)
        end
    end
    return rolesByTeam
end

local function GetKillerRoles()
    local killerRoles = {}
    for _, role in pairs(AllRoles) do
        -- print(role.name, role.team)
        if role.defaultTeam ~= TEAM_INNOCENT then
            table.insert(killerRoles, role.name)
        end
    end
    return killerRoles
end

local function GetRoles()
    local innocentRoles = {}
    local killerRoles = {}
    for _, role in pairs(AllRoles) do
        if role.defaultTeam == TEAM_INNOCENT then
            table.insert(innocentRoles, role.name)
        elseif role.defaultTeam == TEAM_NONE then
            table.insert(innocentRoles, role.name)
        else
            table.insert(killerRoles, role.name)
        end
    end
    return innocentRoles, killerRoles
end

local InnocentRoles, KillerRoles = GetRoles()
print("Innocent Roles: ", table.concat(InnocentRoles, ", "))
print("Killer Roles: ", table.concat(KillerRoles, ", "))

local function testPlyHasTrait(ply, trait, N)
    local personality = ply:BotPersonality()
    if not personality then return false end
    return (personality:GetTraitBool(trait)) or math.random(1, N) == 1
end

local function testPlyIsArchetype(ply, archetype, N)
    local personality = ply:BotPersonality()
    if not personality then return false end
    return (personality:GetClosestArchetype() == archetype) or math.random(1, N) == 1
end

local function countAliveNonAllies(ply)
    local count = 0
    for _, other in ipairs(player.GetAll()) do
        if not IsValid(other) or not other:Alive() then continue end
        if other == ply then continue end
        if TTTBots.Roles.IsAllies(ply, other) then continue end
        count = count + 1
    end
    return count
end

local function countKnownCorpsesNear(ply, radius)
    local corpses = TTTBots.Match and TTTBots.Match.Corpses or {}
    local count = 0
    for _, corpse in ipairs(corpses) do
        if not IsValid(corpse) then continue end
        if ply:GetPos():Distance(corpse:GetPos()) > radius then continue end
        count = count + 1
    end
    return count
end

---@type Buyable
Registry.C4 = {
    Name = "C4",
    Class = "weapon_ttt_c4",
    Price = 1,
    Priority = 3,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "planter", 6)
    end,
    Roles = KillerRoles,
}

---@type Buyable
Registry.Jihad = {
    Name = "Jihad Bomb",
    Class = "weapon_ttt_jihad_bomb",
    Price = 0,
    Priority = 4,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "jihad", 6)
    end,
    Roles = KillerRoles,
}

---@type Buyable
Registry.HealthStation = {
    Name = "Health Station",
    Class = "weapon_ttt_health_station",
    Price = 1,
    Priority = 2,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "healer", 6)
    end,
    SituationalScore = function(ply)
        local role = TTTBots.Roles and TTTBots.Roles.GetRoleFor and TTTBots.Roles.GetRoleFor(ply)
        local isPolice = role and role.GetAppearsPolice and role:GetAppearsPolice()
        local base = 3
        -- Detective credit economy: Health Station is low priority — detective
        -- should spend credits on investigative tools first
        if isPolice then
            base = 10 -- Well below DNA Scanner (60) and Body Armor (30)
            -- Boost if health is low
            if ply:Health() < 50 then base = base + 5 end
        end
        return base
    end,
    Roles = { "detective", "survivalist" },
}

---@type Buyable
Registry.CursedDeagle = {
    Name = "Cursed Deagle",
    Class = "weapon_ttt2_cursed_deagle",
    Price = 1,
    Priority = 5,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "cursed", 6)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- Defector Jihad conversion item — bought by traitors and dropped for an
--- innocent to pick up, converting them to the defector role.
--- The weapon class is weapon_ttt_defector_jihad (the conversion item from the
--- ttt_defector_role addon). This is NOT the actual jihad bomb — that is
--- weapon_ttt_jihad_bomb, which the converted defector receives automatically.
Registry.DefectorJihad = {
    Name = "Defector Jihad (Conversion Item)",
    Class = "weapon_ttt_defector_jihad",
    Price = 1,
    Priority = 3,
    RandomChance = 2,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "defector", 4)
    end,
    SituationalScore = function(ply)
        local innocentCount = 0
        for _, target in pairs(player.GetAll()) do
            if IsValid(target) and target:Alive() and target:GetRole() == ROLE_INNOCENT and target:GetTeam() == TEAM_INNOCENT then
                innocentCount = innocentCount + 1
            end
        end

        if innocentCount < 3 then return 0 end
        if innocentCount >= 6 then return 5 end

        return 3
    end,
    Roles = GetRolesByTeam(TEAM_TRAITOR),
    PrimaryWeapon = false,
}

---@type Buyable
Registry.MedicDeagle = {
    Name = "Medic Deagle",
    Class = "weapon_ttt2_medic_deagle",
    Price = 1,
    Priority = 5,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "medic", 6)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
Registry.DoctorDeagle = {
    Name = "Doctor Deagle",
    Class = "weapon_ttt2_doctor_deagle",
    Price = 1,
    Priority = 5,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "doctor", 6)
    end,
    Roles = { "detective", "survivalist", "sheriff", "deputy", "decipherer", "sniffer", "doctor", "banker", "vigilante" },
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'item_ttt2_shellmet' into the shop of the detective
Registry.Shellmet = {
    Name = "Shellmet",
    Class = "item_ttt2_shellmet",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    Roles = { "detective", "survivalist", "sheriff", "deputy", "decipherer", "sniffer", "doctor", "banker", "vigilante" },
}

---@type Buyable
Registry.Defuser = {
    Name           = "Defuser",
    Class          = "weapon_ttt_defuser",
    Price          = 1,
    Priority       = 1,
    RandomChance   = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam   = false,
    CanBuy         = function(ply)
        return testPlyHasTrait(ply, "defuser", 3)
    end,
    Roles = { "detective", "survivalist", "sheriff", "deputy", "decipherer", "sniffer", "doctor", "banker", "vigilante" },
}

---@type Buyable
Registry.MedicDefib = {
    Name = "Medic Defibrillator",
    Class = "weapon_ttt2_medic_defibrillator",
    Price = 0,
    Priority = 2, -- higher priority because this is an objectively useful item
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    Roles = { "doctor", "medic" },
}

---@type Buyable
Registry.Defib = {
    Name = "Defibrillator",
    Class = "weapon_ttt_defibrillator",
    Price = 2,
    Priority = 4, -- higher priority because this is an objectively useful item
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "healer", 5)
    end,
    Roles = { "traitor", "detective", "sheriff", "deputy", "decipherer", "survivalist", "brainwasher", "slave", "jackal", "sidekick", "pirate_captain", "defective", "banker", "vigilante" },
}

---@type Buyable
Registry.Medigun = {
    Name = "Medigun",
    Class = "weapon_ttt_medigun",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "healer", 3)
    end,
    Roles = { "traitor", "detective", "sheriff", "deputy", "decipherer", "survivalist", "brainwasher", "slave", "jackal", "sidekick", "pirate_captain", "defective", "banker", "vigilante" },
}

---@type Buyable
Registry.RoleDefib = {
    Name = "Role Defibrillator",
    Class = "weapon_ttt_defib_traitor",
    Price = 1,
    Priority = 3, -- higher priority because this is an objectively useful item
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "healer", 3)
    end,
    Roles = { "pirate", "pirate_captain", "detective", "restless", "sheriff", "hoovers", "families", "bloods", "crips", "ballas", "defective" },
}

---@type Buyable
Registry.RoleChecker = {
    Name = "Role Checker",
    Class = "weapon_ttt_traitorchecker",
    Price = 1,
    Priority = 5, -- highest priority; detective must always deploy the role checker
    RandomChance = 1, -- always attempt purchase
    -- No CanBuy gate — detectives should always buy and deploy the role checker
    SituationalScore = function(bot)
        -- Return a very high score so this always wins the buy-order sort,
        -- ensuring the detective gets the role-checker before any other equipment.
        local role = TTTBots.Roles and TTTBots.Roles.GetRoleFor and TTTBots.Roles.GetRoleFor(bot)
        if role and role.GetAppearsPolice and role:GetAppearsPolice() then
            return 100
        end
        return 5
    end,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    Roles = { "detective", "survivalist", "sheriff", "deputy", "decipherer", "sniffer", "banker", "vigilante" },
}

---@type Buyable
Registry.Stungun = {
    Name = "UMP Prototype",
    Class = "weapon_ttt_stungun",
    Price = 1,
    Priority = 1,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = true,
    Roles = { "detective", "survivalist", "sheriff", "sidekick", "deputy", "bodyguard" },
    PrimaryWeapon = true,
}

---@type Buyable
-- This is a custom buyable with the weapon name "Orbital Friendship Beam"
Registry.OrbitalFriendshipBeam = {
    Name = "Orbital Friendship Beam",
    Class = "swep_orbitalfriendshipbeam",
    Price = 1,
    Priority = 1,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = true,
    Roles = KillerRoles,
}

---@type Buyable
--- This is a custom buyable with the weapon name "AK-47"
Registry.AK47 = {
    Name = "AK-47",
    Class = "arccw_mw2_ak47",
    Price = 0,
    Priority = 1,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    Roles = AllRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name "weapon_prop_rain" into the shop of the traitor
Registry.PropRain = {
    Name = "Prop Rain",
    Class = "weapon_prop_rain",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "outdoorSWEPs", 6)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_artillerymarker' into the shop of the traitor
Registry.ArtilleryMarker = {
    Name = "Artillery Marker",
    Class = "weapon_ttt_artillerymarker",
    Price = 2,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "outdoorSWEPs", 6)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}


---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt2_arsonthrower' into the shop of the traitor
Registry.ArsonThrower = {
    Name = "Arson Thrower",
    Class = "weapon_ttt2_arsonthrower",
    Price = 2,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "heavy", 3)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'shared' into the shop of the traitor
Registry.BarrelGun = {
    Name = "Barrel Gun",
    Class = "shared",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "troll", 3)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_beenade' into the shop of the traitor
Registry.BeeNade = {
    Name = "BeeNade",
    Class = "weapon_ttt_beenade",
    Price = 2,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "grenades", 6)
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_headlauncher' into the shop of the traitor
Registry.HeadLauncher = {
    Name = "Head Launcher",
    Class = "weapon_ttt_headlauncher",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "outdoorSWEPs", 6)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_killersnail' into the shop of the traitor
Registry.KillerSnail = {
    Name = "Killer Snail",
    Class = "weapon_ttt_killersnail",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "troll", 4)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_osc_sym' into the shop of the traitor
Registry.OscSym = {
    Name = "Osc Sym",
    Class = "weapon_ttt_osc_sym",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "outdoorSWEPs", 6)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'wep_ttt_asdf_sience_show' into the shop of the traitor
Registry.SienceShow = {
    Name = "Sience Show",
    Class = "wep_ttt_asdf_sience_show",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "troll", 6)
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'ttt_thomas_swep' into the shop of the traitor
Registry.Thomas = {
    Name = "Thomas",
    Class = "ttt_thomas_swep",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "troll", 2)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'ttt_weeping_angel' into the shop of the traitor
Registry.WeepingAngel = {
    Name = "Weeping Angel",
    Class = "ttt_weeping_angel",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "troll", 6)
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_ttt2_minethrower' into the shop of the traitor
Registry.MineThrower = {
    Name = "Mine Thrower",
    Class = "weapon_ttt_ttt2_minethrower",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "grenades", 6)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_dancegun' into the shop of the traitor
Registry.DanceGun = {
    Name = "Dance Gun",
    Class = "weapon_ttt_dancegun",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "troll", 6)
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}


---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_banana' into the shop of the traitor
Registry.Banana = {
    Name = "Banana",
    Class = "weapon_ttt_banana",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "grenades", 6)
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'ttt_smart_pistol' into the shop of the traitor
Registry.SmartPistol = {
    Name = "Smart Pistol",
    Class = "ttt_smart_pistol",
    Price = 1,
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        if ply:HasWeapon("ttt_smart_pistol") then return false end
        return testPlyHasTrait(ply, "gimmick", 3)
            or testPlyHasTrait(ply, "aggressive", 4)
            or testPlyIsArchetype(ply, "CQB", 5)
    end,
    SituationalScore = function(ply)
        local enemies = countAliveNonAllies(ply)
        local base = 6
        if enemies >= 4 then base = base + 2 end
        if enemies >= 7 then base = base + 2 end
        if IsValid(ply.attackTarget) then base = base + 3 end
        return base
    end,
    AnnounceTeam = false,
    Roles = GetRolesByTeam(TEAM_TRAITOR),
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'm9k_minigun' into the shop of the traitor.
Registry.Minigun = {
    Name = "Minigun",
    Class = "m9k_minigun",
    Price = 1,
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("m9k_minigun") then return false end
        return testPlyHasTrait(ply, "heavy", 2)
            or testPlyHasTrait(ply, "aggressive", 4)
            or testPlyHasTrait(ply, "hothead", 4)
    end,
    SituationalScore = function(ply)
        local enemies = countAliveNonAllies(ply)
        local base = 5
        if enemies >= 3 then base = base + 2 end
        if enemies >= 6 then base = base + 3 end
        if IsValid(ply.attackTarget) then base = base + 2 end
        if ply:Health() > 70 then base = base + 1 end
        return base
    end,
    Roles = GetRolesByTeam(TEAM_TRAITOR),
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_reveal_nade' into the shop of the traitor.
Registry.RevealGrenade = {
    Name = "Reveal Grenade",
    Class = "weapon_ttt_reveal_nade",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt_reveal_nade") then return false end
        return testPlyHasTrait(ply, "grenades", 4)
            or testPlyHasTrait(ply, "gimmick", 4)
            or testPlyHasTrait(ply, "strategic", 5)
    end,
    SituationalScore = function(ply)
        local enemies = countAliveNonAllies(ply)
        local nearbyCorpses = countKnownCorpsesNear(ply, 1600)
        local base = 2 + math.min(enemies, 5)
        if nearbyCorpses > 0 then
            base = base + math.min(nearbyCorpses * 2, 6)
        end
        return base
    end,
    Roles = GetRolesByTeam(TEAM_TRAITOR),
    PrimaryWeapon = false,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_snake_gun' into the shop of the traitor
Registry.SnakeGun = {
    Name = "Snake Gun",
    Class = "weapon_snake_gun",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "troll", 4)
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_holyhand_grenade' into the shop of the traitor
Registry.HolyHandGrenade = {
    Name = "Holy Hand Grenade",
    Class = "weapon_holyhand_grenade",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "grenades", 6)
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'ttte_swep' into the shop of the traitor
Registry.TTTE = {
    Name = "TTTE",
    Class = "ttte_swep",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "gimmick", 3)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'melonlauncher' into the shop of the traitor
Registry.MelonLauncher = {
    Name = "Melon Launcher",
    Class = "melonlauncher",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "gimmick", 3)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_deadringer' into the shop of the spy
Registry.DeadRinger = {
    Name = "Dead Ringer",
    Class = "weapon_ttt_deadringer",
    Price = 1,
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    Roles = { "spy" },
    PrimaryWeapon = true,
}

-- ============================================================
-- Serial Killer — Buyable Equipment
-- ============================================================

---@type Buyable
--- Body Armor for Serial Killer — SK is melee-heavy and needs survivability.
Registry.SKBodyArmor = {
    Name = "Body Armor (Serial Killer)",
    Class = "item_ttt_armor",
    Price = 1,
    Priority = 4,
    SituationalScore = function(ply)
        -- Always high value for SK — melee role needs survivability
        local base = 6
        local aliveCount = #getAlivePlayers()
        if aliveCount > 6 then base = base + 2 end
        -- Extra value if SK has taken damage (armor depleted)
        if ply:Armor() < 30 then base = base + 3 end
        return base
    end,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    TTT2 = true,
    Roles = { "serialkiller" },
}

---@type Buyable
--- Radar for SK — useful if tracker_mode ConVar is set to 0 (no default tracker).
Registry.SKRadar = {
    Name = "Radar (Serial Killer)",
    Class = "item_ttt_radar",
    Price = 1,
    Priority = 3,
    SituationalScore = function(ply)
        local base = 4
        local aliveCount = #getAlivePlayers()
        if aliveCount > 6 then base = base + 2 end
        return base
    end,
    RandomChance = 2,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    TTT2 = true,
    Roles = { "serialkiller" },
}

---@type Buyable
--- Disguiser for SK — helps maintain stealth identity.
Registry.SKDisguiser = {
    Name = "Disguiser (Serial Killer)",
    Class = "item_ttt_disguiser",
    Price = 1,
    Priority = 2,
    SituationalScore = function(ply)
        local base = 3
        -- More valuable early in the round when identity is unknown
        local awareness = ply.BotRoundAwareness and ply:BotRoundAwareness()
        if awareness then
            local phase = awareness:GetPhase()
            if phase == 1 or phase == 2 then base = base + 3 end -- EARLY or MID
        end
        return base
    end,
    RandomChance = 2,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    TTT2 = true,
    Roles = { "serialkiller" },
}

-- ============================================================
-- Killer Clown — Buyable Equipment
-- ============================================================
-- The Killer Clown has SHOP_TRAITOR fallback, giving full traitor shop access.
-- Typically has 2 credits at transformation (1 from Clown base + 1 activation).
-- Prioritize immediate combat effectiveness — weapons first, then utility.

---@type Buyable
--- Body Armor for Killer Clown — immediate survivability boost post-transformation.
Registry.KCBodyArmor = {
    Name = "Body Armor (Killer Clown)",
    Class = "item_ttt_armor",
    Price = 1,
    Priority = 4,
    SituationalScore = function(ply)
        -- High value — the Killer Clown is a public target, needs survivability
        local base = 7
        local aliveCount = #getAlivePlayers()
        if aliveCount > 5 then base = base + 2 end
        -- Extra value if Killer Clown has taken damage or low armor
        if ply:Armor() < 30 then base = base + 3 end
        return base
    end,
    RandomChance = 1,  -- Always try to buy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    TTT2 = true,
    Roles = { "killerclown" },
}

---@type Buyable
--- Radar for Killer Clown — essential for hunting remaining players.
Registry.KCRadar = {
    Name = "Radar (Killer Clown)",
    Class = "item_ttt_radar",
    Price = 1,
    Priority = 5,
    SituationalScore = function(ply)
        -- Very high value — the Killer Clown needs to find and hunt everyone
        local base = 8
        local aliveCount = #getAlivePlayers()
        if aliveCount > 4 then base = base + 2 end
        return base
    end,
    RandomChance = 1,  -- Always try to buy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    TTT2 = true,
    Roles = { "killerclown" },
}

---@type Buyable
--- C4 for Killer Clown — area denial / ambush tool.
Registry.KCC4 = {
    Name = "C4 (Killer Clown)",
    Class = "weapon_ttt_c4",
    Price = 1,
    Priority = 2,
    SituationalScore = function(ply)
        local base = 3
        local aliveCount = #getAlivePlayers()
        -- C4 is more valuable with more targets alive
        if aliveCount > 5 then base = base + 3 end
        return base
    end,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "planter", 4)
    end,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    Roles = { "killerclown" },
}

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name "'arccw_mw2_g17'" into the shop of the innocent
-- Registry.G17MW2 = {
--     Name = "G17",
--     Class = "arccw_mw2_g17",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = false,
--     Roles = AllRoles,
--     PrimaryWeapon = false,
-- }
-- ---@type Buyable
-- --- This is a custom buyable with the weapon name "'arccw_mw2_anaconda'" into the shop of the innocent
-- Registry.AnacondaMW2 = {
--     Name = "Anaconda",
--     Class = "arccw_mw2_anaconda",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = false,
--     Roles = AllRoles,
--     PrimaryWeapon = false,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name "'arccw_mw2_m1911'" into the shop of the innocent
-- Registry.M1911MW2 = {
--     Name = "M1911",
--     Class = "arccw_mw2_m1911",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = false,
--     Roles = AllRoles,
--     PrimaryWeapon = false,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name "arccw_mw2_deagle" into the shop of the innocent
-- Registry.DeagleMW2 = {
--     Name = "Deagle",
--     Class = "arccw_mw2_deagle",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = false,
--     Roles = AllRoles,
--     PrimaryWeapon = false,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name "'arccw_mw2_m9'" into the shop of the innocent
-- Registry.M9MW2 = {
--     Name = "M9",
--     Class = "arccw_mw2_m9",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = false,
--     Roles = AllRoles,
--     PrimaryWeapon = false,
-- }
-- ---@type Buyable
-- --- This is a custom buyable with the weapon name "'arccw_mw2_acr'" into the shop of the detective
-- Registry.ACRMW2 = {
--     Name = "ACR",
--     Class = "arccw_mw2_acr",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "rifles", 6)
--     end,
--     AnnounceTeam = false,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_steyr_lmg' into the shop of the detective
-- Registry.SteyrLMGMW2 = {
--     Name = "Steyr LMG",
--     Class = "arccw_mw2_steyr_lmg",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "heavy", 6)
--     end,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_scarl' into the shop of the detective
-- Registry.ScarLMW2 = {
--     Name = "SCAR-L",
--     Class = "arccw_mw2_scarl",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "rifles", 6)
--     end,
--     AnnounceTeam = false,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_w1200' into the shop of the detective
-- Registry.W1200MW2 = {
--     Name = "W1200",
--     Class = "arccw_mw2_w1200",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "CQB", 6)
--     end,
--     AnnounceTeam = false,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name ''arccw_suppressorlmg'' into the shop of the detective
-- Registry.SuppressorLMG = {
--     Name = "Suppressor LMG",
--     Class = "arccw_suppressorlmg",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "heavy", 6)
--     end,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_m4' into the shop of the traitor
-- Registry.M4MW2 = {
--     Name = "M4",
--     Class = "arccw_mw2_m4",
--     Price = 1,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = true,
--     AnnounceTeam = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "rifles", 6)
--     end,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_rpd' into the shop of the traitor and hostile roles
-- Registry.RPDMW2 = {
--     Name = "RPD",
--     Class = "arccw_mw2_rpd",
--     Price = 2,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = true,
--     AnnounceTeam = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "heavy", 6)
--     end,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_aa12' into the shop of the bodyguard and infected roles
-- Registry.AA12MW2 = {
--     Name = "AA12",
--     Class = "arccw_mw2_aa12",
--     Price = 2,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "CQB", 6)
--     end,
--     AnnounceTeam = true,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_m1014' into the shop of infected roles'
-- Registry.M1014MW2 = {
--     Name = "M1014",
--     Class = "arccw_mw2_m1014",
--     Price = 2,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "CQB", 6)
--     end,
--     AnnounceTeam = true,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_m240' into the shop of infected roles
-- Registry.M240MW2 = {
--     Name = "M240",
--     Class = "arccw_mw2_m240",
--     Price = 2,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "heavy", 6)
--     end,
--     AnnounceTeam = true,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'item_ttt_speedrun' into the shop of infected roles
-- Registry.Speedrun = {
--     Name = "Speedrun",
--     Class = "item_ttt_speedrun",
--     Price = 1,
--     Priority = 2,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = true,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_mg4' into the shop of jackal roles
-- Registry.MG4MW2 = {
--     Name = "MG4",
--     Class = "arccw_mw2_mg4",
--     Price = 2,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     AnnounceTeam = true,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "heavy", 6)
--     end,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }

-- ---@type Buyable
-- --- This is a custom buyable with the weapon name 'arccw_mw2_barrett' into the shop of jackal roles
-- Registry.BarrettMW2 = {
--     Name = "Barrett",
--     Class = "arccw_mw2_barrett",
--     Price = 2,
--     Priority = 1,
--     RandomChance = 1,
--     ShouldAnnounce = false,
--     CanBuy = function(ply)
--         return testPlyIsArchetype(ply, "heavy", 6)
--     end,
--     AnnounceTeam = true,
--     Roles = AllRoles,
--     PrimaryWeapon = true,
-- }


-- ============================================================
-- TTT2 Core Equipment — Situational Buyables
-- ============================================================

-- Helper: get count of alive players without relying on player.GetAlive()
local function getAlivePlayers()
	local t = {}
	for _, p in pairs(player.GetAll()) do
		if p:Alive() then t[#t + 1] = p end
	end
	return t
end

---@type Buyable
Registry.BodyArmor = {
	Name = "Body Armor",
	Class = "item_ttt_armor",
	Price = 1,
	Priority = 4,
	SituationalScore = function(ply)
		-- More valuable with many players alive (more threats)
		local aliveCount = #getAlivePlayers()
		local role = TTTBots.Roles and TTTBots.Roles.GetRoleFor and TTTBots.Roles.GetRoleFor(ply)
		local isPolice = role and role.GetAppearsPolice and role:GetAppearsPolice()
		local base = 4
		if aliveCount > 8 then base = base + 3 end
		if aliveCount > 5 then base = base + 1 end
		-- Detective credit economy: Body Armor is 3rd priority after RoleChecker + DNA Scanner
		-- Give it a strong but lower-than-DNA-Scanner score for police roles
		if isPolice then
			base = 30  -- Below DNA Scanner (60) and RoleChecker (100)
			-- Boost if detective has already been hurt
			if ply:Armor() < 30 then base = base + 10 end
		else
			if ply:GetRoleStringRaw() == "detective" then base = base + 2 end
		end
		return base
	end,
	RandomChance = 2,  -- 50% chance
	ShouldAnnounce = false,
	AnnounceTeam = false,
	TTT2 = true,
	Roles = { "detective", "survivalist", "sheriff", "deputy", "decipherer", "sniffer", "banker", "vigilante" },
}

---@type Buyable
Registry.TraitorArmor = {
	Name = "Body Armor (Traitor)",
	Class = "item_ttt_armor",
	Price = 1,
	Priority = 2,
	SituationalScore = function(ply)
		local aliveCount = #getAlivePlayers()
		local base = 2
		if aliveCount > 8 then base = base + 2 end
		return base
	end,
	RandomChance = 3,  -- ~33% chance
	ShouldAnnounce = false,
	AnnounceTeam = false,
	TTT2 = true,
	Roles = GetRolesByTeam(TEAM_TRAITOR),
}

---@type Buyable
Registry.Radar = {
	Name = "Radar",
	Class = "item_ttt_radar",
	Price = 1,
	Priority = 3,
	SituationalScore = function(ply)
		local aliveCount = #getAlivePlayers()
		local base = 3
		-- More valuable with many players alive
		if aliveCount > 7 then base = base + 3 end
		if aliveCount > 10 then base = base + 2 end
		return base
	end,
	CanBuy = function(ply)
		local roleData = TTTBots.Roles.GetRoleFor(ply)
		return roleData and roleData.CanHaveRadar or false
	end,
	RandomChance = 2,
	ShouldAnnounce = false,
	AnnounceTeam = true,
	TTT2 = true,
	Roles = GetRolesByTeam(TEAM_TRAITOR),
}

---@type Buyable
Registry.DetectiveRadar = {
	Name = "Radar (Detective)",
	Class = "item_ttt_radar",
	Price = 1,
	Priority = 3,
	SituationalScore = function(ply)
		local aliveCount = #getAlivePlayers()
		local base = 3
		if aliveCount > 7 then base = base + 2 end
		return base
	end,
	RandomChance = 2,
	ShouldAnnounce = false,
	AnnounceTeam = false,
	TTT2 = true,
	Roles = { "detective", "survivalist", "sheriff", "sniffer" },
}

---@type Buyable
Registry.Disguiser = {
	Name = "Disguiser",
	Class = "item_ttt_disguiser",
	Price = 1,
	Priority = 2,
	SituationalScore = function(ply)
		local base = 2
		-- More useful mid-round when suspicion is building
		local awareness = ply.BotRoundAwareness and ply:BotRoundAwareness()
		if awareness then
			local phase = awareness:GetPhase()
			if phase == 2 or phase == 3 then base = base + 2 end -- MID or LATE
		end
		if testPlyHasTrait(ply, "disguiser", 1) then base = base + 3 end
		return base
	end,
	CanBuy = function(ply)
		return testPlyHasTrait(ply, "disguiser", 4)
	end,
	RandomChance = 1,
	ShouldAnnounce = false,
	AnnounceTeam = false,
	TTT2 = true,
	Roles = GetRolesByTeam(TEAM_TRAITOR),
}

---@type Buyable
Registry.DNAScanner = {
	Name = "DNA Scanner",
	Class = "weapon_ttt_cse",
	Price = 1,
	Priority = 5,  -- High priority for detective
	SituationalScore = function(ply)
		local role = TTTBots.Roles and TTTBots.Roles.GetRoleFor and TTTBots.Roles.GetRoleFor(ply)
		local isPolice = role and role.GetAppearsPolice and role:GetAppearsPolice()
		local base = 5
		-- Detective credit economy: DNA Scanner is the #2 must-buy after RoleChecker
		-- It is core investigative equipment — higher priority than armor or utility
		if isPolice then
			base = 60  -- Very high score so it wins the buy-order after RoleChecker (100)
		end
		-- Even more valuable if bodies exist
		if TTTBots.Match and TTTBots.Match.Corpses and #TTTBots.Match.Corpses > 0 then
			base = base + 5
		end
		return base
	end,
	RandomChance = 1,
	ShouldAnnounce = false,
	AnnounceTeam = false,
	TTT2 = true,
	Roles = { "detective", "survivalist", "sniffer", "decipherer" },
}

---@type Buyable
Registry.TraitorC4Deferred = {
	Name = "C4 (Deferred)",
	Class = "weapon_ttt_c4",
	Price = 1,
	Priority = 0,
	DeferredEvent = "round_mid",
	SituationalScore = function(ply)
		local aliveCount = #getAlivePlayers()
		local base = 0
		-- C4 is most valuable with many targets alive
		if aliveCount > 6 then base = 5 end
		if aliveCount > 9 then base = base + 3 end
		return base
	end,
	CanBuy = function(ply)
		-- Only buy if don't already have C4
		return not ply:HasWeapon("weapon_ttt_c4") and testPlyHasTrait(ply, "planter", 4)
	end,
	RandomChance = 2,
	ShouldAnnounce = false,
	AnnounceTeam = false,
	TTT2 = false,
	Roles = GetRolesByTeam(TEAM_TRAITOR),
}

---@type Buyable
Registry.DetectiveDefibrillator = {
	Name = "Defibrillator (Deferred)",
	Class = "weapon_ttt_defibrillator",
	Price = 1,
	Priority = 0,
	DeferredEvent = "ally_died",
	SituationalScore = function(ply)
		-- Detective credit economy: deferred defib is reactive — only bought when
		-- an ally actually dies. Higher score when multiple allies are down.
		local role = TTTBots.Roles and TTTBots.Roles.GetRoleFor and TTTBots.Roles.GetRoleFor(ply)
		local isPolice = role and role.GetAppearsPolice and role:GetAppearsPolice()
		local base = 6
		if isPolice then
			-- Count confirmed dead allies to assess value
			local deadAllies = 0
			for deadPly, _ in pairs(TTTBots.Match.ConfirmedDead or {}) do
				if IsValid(deadPly) and TTTBots.Roles.IsAllies(ply, deadPly) then
					deadAllies = deadAllies + 1
				end
			end
			base = 6 + math.min(deadAllies * 3, 9) -- up to 15 score with many dead allies
		end
		return base
	end,
	CanBuy = function(ply)
		return not ply:HasWeapon("weapon_ttt_defibrillator") and testPlyHasTrait(ply, "healer", 3)
	end,
	RandomChance = 1,
	ShouldAnnounce = false,
	AnnounceTeam = false,
	TTT2 = false,
	Roles = { "detective", "survivalist", "sheriff", "deputy" },
}

--- Traitor Defibrillator (Deferred) — reactive purchase when a traitor ally dies.
--- Traitors can buy the standard defibrillator to revive their OWN dead team-mates
--- (the Defib behavior enforces allyOnly=true for non-doctor/non-medic roles).
--- This mirrors DetectiveDefibrillator but for traitor-team roles, so traitors
--- reactively acquire a defib mid-round when allies start dying — especially
--- important for revival-plan coordination.
---@type Buyable
Registry.TraitorDefibrillator = {
	Name = "Defibrillator (Traitor Deferred)",
	Class = "weapon_ttt_defibrillator",
	Price = 1,
	Priority = 0,
	DeferredEvent = "ally_died",
	SituationalScore = function(ply)
		-- Higher score when the traitor team is outnumbered — reviving an ally
		-- is more valuable than any other mid-round purchase at that point.
		local aliveAllies = 0
		local deadAllies = 0
		for _, other in ipairs(player.GetAll()) do
			if not IsValid(other) or other == ply then continue end
			if not TTTBots.Roles.IsAllies(ply, other) then continue end
			if TTTBots.Lib.IsPlayerAlive(other) then
				aliveAllies = aliveAllies + 1
			end
		end
		for deadPly, _ in pairs(TTTBots.Match.ConfirmedDead or {}) do
			if IsValid(deadPly) and TTTBots.Roles.IsAllies(ply, deadPly) then
				deadAllies = deadAllies + 1
			end
		end

		local base = 4
		-- More dead allies → more valuable to revive
		base = base + math.min(deadAllies * 3, 9)
		-- Fewer alive allies → more urgent
		if aliveAllies <= 1 then base = base + 4 end
		return base
	end,
	CanBuy = function(ply)
		-- Don't buy if we already have a defib or role-defib
		if ply:HasWeapon("weapon_ttt_defibrillator") then return false end
		if ply:HasWeapon("weapon_ttt_defib_traitor") then return false end
		-- Trait gate: healer trait or 1-in-4 random chance (more permissive than
		-- the round-start buy so traitors are more willing to react mid-round)
		return testPlyHasTrait(ply, "healer", 4)
	end,
	RandomChance = 1,
	ShouldAnnounce = false,
	AnnounceTeam = false,
	TTT2 = false,
	Roles = GetRolesByTeam(TEAM_TRAITOR),
}

-- ============================================================
-- TTT2 Weapons — Newly Supported Equipment
-- ============================================================

---@type Buyable
--- Deployable turret NPC that auto-targets players.
Registry.Turret = {
    Name = "Turret",
    Class = "weapon_ttt_turret",
    Price = 1,
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "planter", 5)
    end,
    SituationalScore = function(ply)
        local aliveCount = #getAlivePlayers()
        return aliveCount > 6 and 6 or 4
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Timestop weapon — freezes nearby enemies in place.
Registry.Timestop = {
    Name = "Timestop",
    Class = "weapon_ttt_timestop",
    Price = 1,
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "gimmick", 4)
    end,
    SituationalScore = function(ply)
        local aliveCount = #getAlivePlayers()
        return aliveCount > 4 and 5 or 3
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Peacekeeper / "High Noon" weapon — charges visible enemies and fires lethal homing shots.
Registry.Peacekeeper = {
    Name = "Peacekeeper",
    Class = "weapon_ttt_peacekeeper",
    Price = 1,
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "heavy", 4)
    end,
    SituationalScore = function(ply)
        local aliveCount = #getAlivePlayers()
        return aliveCount > 5 and 6 or 4
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Role Change Deagle — detective fires at an enemy to randomly change their role within their team.
Registry.RoleChangeDeagle = {
    Name = "Role Change Deagle",
    Class = "weapon_ttt2_role_change_deagle",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "gimmick", 4)
    end,
    Roles = { "detective", "survivalist", "sheriff", "deputy", "decipherer", "sniffer", "banker", "vigilante" },
    PrimaryWeapon = false,
}

---@type Buyable
--- Infinite Ammo passive item — grants unlimited ammunition.
Registry.InfiniShoot = {
    Name = "Infinite Ammo",
    Class = "item_ttt_infinishoot",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "heavy", 4)
    end,
    SituationalScore = function(ply)
        local aliveCount = #getAlivePlayers()
        return aliveCount > 5 and 5 or 3
    end,
    TTT2 = true,
    Roles = KillerRoles,
}

---@type Buyable
--- Smart Bullets: one-time use traitor equipment that grants auto-aim headshots
--- for a limited duration. Consumed on activation. Produces extremely visible
--- red energy tracers that reveal the user as a traitor.
Registry.SmartBullets = {
    Name = "Smart Bullets",
    Class = "weapon_ttt2_smart_bullets",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        -- Don't buy if buff is already active
        if ply.ttt2_smart_bullets_active then return false end
        -- Don't buy if we already have one in inventory
        if ply:HasWeapon("weapon_ttt2_smart_bullets") then return false end
        -- Trait preferences: aggressive, gimmick, or tryhard bots
        return testPlyHasTrait(ply, "aggressive", 4)
            or testPlyHasTrait(ply, "gimmick", 3)
            or testPlyHasTrait(ply, "tryhard", 5)
    end,
    SituationalScore = function(ply)
        local base = 5
        -- More enemies alive = more value from the buff
        local enemies = countAliveNonAllies(ply)
        if enemies >= 3 then base = base + 2 end
        if enemies >= 5 then base = base + 3 end
        -- Currently in combat = higher urgency
        if IsValid(ply.attackTarget) then base = base + 4 end
        -- Bonus if we have a good weapon to pair with the buff
        local inv = ply.BotInventory and ply:BotInventory()
        if inv then
            local bestSpecial = inv:GetSpecialPrimary()
            if bestSpecial then base = base + 3 end
            local primary = inv:GetPrimary()
            if primary then base = base + 2 end
        end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Silent ranged DOT weapon — ideal for stealthy traitor play.
Registry.PoisonDartGun = {
    Name = "Poison Dart Gun",
    Class = "weapon_ttt2_poison_dart",
    Price = 1,
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt2_poison_dart") then return false end
        -- Stealth-oriented bots prefer this weapon
        return testPlyHasTrait(ply, "disguiser", 3)
            or testPlyHasTrait(ply, "cautious", 3)
            or testPlyHasTrait(ply, "strategic", 4)
    end,
    SituationalScore = function(ply)
        local base = 5
        local enemies = countAliveNonAllies(ply)
        -- More valuable when many targets (poison multiple)
        if enemies >= 4 then base = base + 3 end
        if enemies >= 6 then base = base + 2 end
        -- Stealth bonus when not in active combat
        if not IsValid(ply.attackTarget) then base = base + 3 end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false, -- It's a utility sidearm, not a primary
}

---@type Buyable
--- Spawns a fake player model that walks forward, distracting innocents.
Registry.HologramDecoy = {
    Name = "Hologram Decoy",
    Class = "weapon_ttt2_hologram_decoy",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt2_hologram_decoy") then return false end
        return testPlyHasTrait(ply, "gimmick", 3)
            or testPlyHasTrait(ply, "disguiser", 4)
            or testPlyHasTrait(ply, "strategic", 4)
    end,
    SituationalScore = function(ply)
        local base = 4
        local enemies = countAliveNonAllies(ply)
        -- More useful with many innocents to distract
        if enemies >= 5 then base = base + 3 end
        -- Less useful in overtime (people are cautious)
        local awareness = ply.BotRoundAwareness and ply:BotRoundAwareness()
        if awareness then
            local phase = awareness:GetPhase()
            if phase == "EARLY" or phase == 1 then base = base + 2 end
        end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Disables nearby equipment (health stations, radars) for a duration.
Registry.EMPGrenade = {
    Name = "EMP Grenade",
    Class = "weapon_ttt2_emp_grenade",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt2_emp_grenade") then return false end
        return testPlyHasTrait(ply, "grenades", 3)
            or testPlyHasTrait(ply, "strategic", 4)
    end,
    SituationalScore = function(ply)
        local base = 3
        -- Higher value if health stations exist nearby
        for _, ent in ipairs(ents.FindByClass("ttt_health_station")) do
            if IsValid(ent) and ply:GetPos():Distance(ent:GetPos()) < 2000 then
                base = base + 5
                break
            end
        end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Throwable mine that pulls players toward it, then detonates.
Registry.GravityMine = {
    Name = "Gravity Mine",
    Class = "weapon_ttt2_gravity_mine",
    Price = 1,
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt2_gravity_mine") then return false end
        return testPlyHasTrait(ply, "grenades", 3)
            or testPlyHasTrait(ply, "planter", 3)
            or testPlyHasTrait(ply, "aggressive", 5)
    end,
    SituationalScore = function(ply)
        local base = 5
        local enemies = countAliveNonAllies(ply)
        -- More valuable with clusters of enemies
        if enemies >= 3 then base = base + 3 end
        if enemies >= 6 then base = base + 2 end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Fires a canister that deploys 2-3 Combine soldiers from orbit.
--- Gated by the outdoorSWEPs trait since it requires sky access.
Registry.CombineLauncher = {
    Name = "Combine Launcher",
    Class = "weapon_ttt_combinelauncher",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt_combinelauncher") then return false end
        return testPlyHasTrait(ply, "outdoorSWEPs", 4)
            or testPlyHasTrait(ply, "aggressive", 5)
            or testPlyHasTrait(ply, "gimmick", 4)
    end,
    SituationalScore = function(ply)
        local base = 4
        local enemies = countAliveNonAllies(ply)
        if enemies >= 3 then base = base + 2 end
        if enemies >= 5 then base = base + 2 end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Fires a canister that deploys 2-4 fast zombies from orbit.
--- Fast zombies are highly mobile and disruptive to innocents.
Registry.FastZombieLauncher = {
    Name = "Fast Zombie Launcher",
    Class = "weapon_ttt_fastzombielauncher",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt_fastzombielauncher") then return false end
        return testPlyHasTrait(ply, "outdoorSWEPs", 4)
            or testPlyHasTrait(ply, "aggressive", 5)
            or testPlyHasTrait(ply, "gimmick", 4)
    end,
    SituationalScore = function(ply)
        local base = 4
        local enemies = countAliveNonAllies(ply)
        if enemies >= 3 then base = base + 2 end
        if enemies >= 5 then base = base + 2 end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Fires a headcrab canister that releases 4-6 headcrabs on impact.
--- The env_headcrabcanister entity handles all NPC spawning natively.
Registry.HeadcrabLauncher = {
    Name = "Headcrab Launcher",
    Class = "weapon_ttt_headlauncher",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = false,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt_headlauncher") then return false end
        return testPlyHasTrait(ply, "outdoorSWEPs", 4)
            or testPlyHasTrait(ply, "grenades", 4)
            or testPlyHasTrait(ply, "gimmick", 4)
    end,
    SituationalScore = function(ply)
        local base = 4
        local enemies = countAliveNonAllies(ply)
        if enemies >= 3 then base = base + 2 end
        if enemies >= 5 then base = base + 2 end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}

---@type Buyable
--- Unified Apocalypse SWEP: opens a menu to choose between Zombie or Combine
--- apocalypse. For bots, it auto-selects randomly. Spawns a team-aware NPC horde.
Registry.Apocalypse = {
    Name = "Apocalypse",
    Class = "weapon_ttt_apocalypse",
    Price = 1,
    Priority = 6,
    RandomChance = 1,
    ShouldAnnounce = true,
    AnnounceTeam = true,
    CanBuy = function(ply)
        if ply:HasWeapon("weapon_ttt_apocalypse") then return false end
        -- Also skip if they already have one of the standalone apocalypse weapons
        if ply:HasWeapon("weapon_ttt_zombieapocalypse") then return false end
        if ply:HasWeapon("weapon_ttt_combineapocalypse") then return false end
        return testPlyHasTrait(ply, "aggressive", 3)
            or testPlyHasTrait(ply, "gimmick", 4)
            or math.random(1, 4) == 1
    end,
    SituationalScore = function(ply)
        local base = 6
        local enemies = countAliveNonAllies(ply)
        if enemies >= 3 then base = base + 3 end
        if enemies >= 5 then base = base + 3 end
        -- Higher priority when solo traitor (needs force multiplier)
        local aliveAllies = 0
        for _, other in ipairs(player.GetAll()) do
            if not IsValid(other) or not other:Alive() or other == ply then continue end
            if TTTBots.Roles.IsAllies(ply, other) then aliveAllies = aliveAllies + 1 end
        end
        if aliveAllies == 0 then base = base + 4 end
        return base
    end,
    Roles = KillerRoles,
    PrimaryWeapon = false,
    LimitedStock = true,
}

for key, data in pairs(Registry) do
	TTTBots.Buyables.RegisterBuyable(data)
end

-- Hook: try deferred buys at mid-round
timer.Create("TTTBots.Buyables.DeferredBuyMid", 1.0, 0, function()
	if not TTTBots.Match or not TTTBots.Match.IsRoundActive() then return end
	for _, bot in pairs(TTTBots.Bots) do
		if not (IsValid(bot) and bot.components) then continue end
		if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
		local awareness = bot.BotRoundAwareness and bot:BotRoundAwareness()
		local phase = awareness and awareness:GetPhase()
		if phase == "MID" or phase == "LATE" or phase == "OVERTIME" then  -- MID or later
			TTTBots.Buyables.TryDeferredBuy(bot, "round_mid")
		end
	end
end)

-- Hook: ally death → try deferred defib purchase
hook.Add("PostPlayerDeath", "TTTBots_DeferredBuy_AllyDied", function(victim)
	if not (IsValid(victim) and victim:IsPlayer()) then return end
	timer.Simple(1, function()
		for _, bot in pairs(TTTBots.Bots) do
			if not (IsValid(bot) and bot.components) then continue end
			if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
			if TTTBots.Roles.IsAllies(bot, victim) then
				TTTBots.Buyables.TryDeferredBuy(bot, "ally_died")
			end
		end
	end)
end)

-- ── New Deferred Buy Event Hooks ────────────────────────────────────────

-- Solo Traitor: when all other traitor allies are dead, trigger solo_traitor
-- deferred buys for survivability (radar, body armor).
hook.Add("PostPlayerDeath", "TTTBots_DeferredBuy_SoloTraitor", function(victim)
	if not (IsValid(victim) and victim:IsPlayer()) then return end
	timer.Simple(1.5, function()
		if not TTTBots.Match or not TTTBots.Match.IsRoundActive() then return end
		for _, bot in pairs(TTTBots.Bots) do
			if not (IsValid(bot) and bot.components) then continue end
			if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
			if not TTTBots.Roles.IsAllies(bot, victim) then continue end
			-- Check if this bot is now alone on their team
			local aliveAllies = 0
			for _, ply in ipairs(player.GetAll()) do
				if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
				if TTTBots.Roles.IsAllies(bot, ply) then aliveAllies = aliveAllies + 1 end
			end
			if aliveAllies == 0 then
				TTTBots.Buyables.TryDeferredBuy(bot, "solo_traitor")
			end
		end
	end)
end)

-- Equipment Spotted: periodically check if enemy equipment (health stations,
-- etc.) exists near traitor bots, and trigger deferred EMP purchase.
timer.Create("TTTBots.Buyables.DeferredBuyEquipment", 5.0, 0, function()
	if not TTTBots.Match or not TTTBots.Match.IsRoundActive() then return end
	-- Only check after early round phase
	for _, bot in pairs(TTTBots.Bots) do
		if not (IsValid(bot) and bot.components) then continue end
		if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
		-- Only for traitor-team bots
		local team = bot.GetTeam and bot:GetTeam()
		if team ~= TEAM_TRAITOR then continue end
		-- Check if any enemy equipment is nearby
		local hasNearbyEquipment = false
		for _, ent in ipairs(ents.FindByClass("ttt_health_station")) do
			if IsValid(ent) and bot:GetPos():Distance(ent:GetPos()) < 2000 then
				hasNearbyEquipment = true
				break
			end
		end
		if hasNearbyEquipment then
			TTTBots.Buyables.TryDeferredBuy(bot, "equipment_spotted")
		end
	end
end)

-- Many Corpses: periodically check if there are multiple revivable corpses
-- and trigger deferred defib/role-defib purchase for traitor bots.
timer.Create("TTTBots.Buyables.DeferredBuyCorpses", 8.0, 0, function()
	if not TTTBots.Match or not TTTBots.Match.IsRoundActive() then return end
	local corpses = TTTBots.Lib.GetRevivableCorpses and TTTBots.Lib.GetRevivableCorpses() or {}
	if #corpses < 2 then return end
	for _, bot in pairs(TTTBots.Bots) do
		if not (IsValid(bot) and bot.components) then continue end
		if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
		local team = bot.GetTeam and bot:GetTeam()
		if team ~= TEAM_TRAITOR then continue end
		-- Only buy if we don't already have revival capability
		if bot:HasWeapon("weapon_ttt_defibrillator") then continue end
		if bot:HasWeapon("weapon_ttt_defib_traitor") then continue end
		TTTBots.Buyables.TryDeferredBuy(bot, "many_corpses")
	end
end)

-- Team Advantage: when the coordinating team has a numbers advantage,
-- trigger deferred buy for aggression boosters (smart bullets).
timer.Create("TTTBots.Buyables.DeferredBuyAdvantage", 6.0, 0, function()
	if not TTTBots.Match or not TTTBots.Match.IsRoundActive() then return end
	for _, bot in pairs(TTTBots.Bots) do
		if not (IsValid(bot) and bot.components) then continue end
		if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
		local team = bot.GetTeam and bot:GetTeam()
		if team ~= TEAM_TRAITOR then continue end
		-- Count allies vs enemies
		local aliveAllies = 0
		local aliveEnemies = 0
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
			if TTTBots.Roles.IsAllies(bot, ply) then
				aliveAllies = aliveAllies + 1
			else
				aliveEnemies = aliveEnemies + 1
			end
		end
		-- Only trigger when team has numbers advantage
		if aliveAllies >= aliveEnemies and aliveEnemies > 0 then
			TTTBots.Buyables.TryDeferredBuy(bot, "team_advantage")
		end
	end
end)
