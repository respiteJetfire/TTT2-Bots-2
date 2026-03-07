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
    Roles = { "detective", "survivalist" },
}

---@type Buyable
Registry.CursedDeagle = {
    Name = "Cursed Deagle",
    Class = "weapon_ttt2_cursed_deagle",
    Price = 1,
    Priority = 4,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "cursed", 12)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
Registry.DefectorDeagle = {
    Name = "Defector Deagle",
    Class = "weapon_ttt2_defector_deagle",
    Price = 1,
    Priority = 4,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "defector", 12)
    end,
    Roles = GetRolesByTeam(TEAM_TRAITOR),
    PrimaryWeapon = true,
}

---@type Buyable
Registry.MedicDeagle = {
    Name = "Medic Deagle",
    Class = "weapon_ttt2_medic_deagle",
    Price = 1,
    Priority = 4,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "medic", 12)
    end,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
Registry.DoctorDeagle = {
    Name = "Doctor Deagle",
    Class = "weapon_ttt2_doctor_deagle",
    Price = 1,
    Priority = 4,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "doctor", 12)
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
    Priority = 3,
    RandomChance = 1,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "tester", 8)
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
    Priority = 2,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "gimmick", 3)
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = true,
}

---@type Buyable
--- This is a custom buyable with the weapon name 'weapon_ttt_defector_jihad'' into the shop of the defector
Registry.DefectorJihad = {
    Name = "Defector Jihad",
    Class = "weapon_ttt_defector_jihad",
    Price = 0,
    Priority = 5,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    Roles = { "defector" },
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
		local base = 4
		if aliveCount > 8 then base = base + 3 end
		if aliveCount > 5 then base = base + 1 end
		-- Extra value for detective (main target)
		if ply:GetRoleStringRaw() == "detective" then base = base + 2 end
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
		local base = 5
		-- Even more valuable if bodies exist
		if TTTBots.Match and TTTBots.Match.Corpses and #TTTBots.Match.Corpses > 0 then
			base = base + 3
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
		-- Only buy if we have credits and an ally just died
		return 6
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
