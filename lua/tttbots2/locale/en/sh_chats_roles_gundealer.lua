--[[
    Gun Dealer Role Chat Categories

    This file contains chat lines for Gun Dealer role events and interactions.
    Categories included:
        GunDealerDelivering, GunDealerDelivered,
        GunDealerCrateSpotted, GunDealerCrateBroken,
        GunDealerRequestWeapon, GunDealerRequestAmmo, GunDealerRequestThanks,
        GunDealerUnderAttack
]]

local P = {
    CRITICAL = 1,  --- KOS, user interaction, etc.
    IMPORTANT = 2, --- Important, but not necessarily critical
    NORMAL = 3,    --- Mostly flavor text or misc. chitchat
}

local function LoadGunDealerChats()
    local A = TTTBots.Archetypes
    local currentEvent = ""
    local Line = function(line, archetype)
        return TTTBots.Locale.AddLine(currentEvent, line, "en", archetype)
    end
    local RegisterCategory = function(event, priority, description)
        currentEvent = event
        return TTTBots.Locale.RegisterCategory(event, "en", priority, description)
    end

    -----------------------------------------------------------
    -- GUN DEALER DELIVERING A CRATE
    -----------------------------------------------------------

    RegisterCategory("GunDealerDelivering", P.NORMAL, "When a Gun Dealer bot is sending a consignment crate to a player.")
    Line("Sending a package your way!", A.Default)
    Line("Consignment incoming, stand by.", A.Default)
    Line("Got a delivery for you.", A.Default)
    Line("yo sending u a crate", A.Casual)
    Line("package inbound lol", A.Casual)
    Line("Here comes a little care package for you!", A.Nice)
    Line("Shipment dispatched.", A.Stoic)
    Line("CRATE INCOMING! GET READY!", A.Hothead)
    Line("Fine, I'll send you something.", A.Bad)
    Line("Sending supplies to the team!", A.Teamer)
    Line("Deploying consignment to optimal recipient.", A.Tryhard)
    Line("Oh, I'm just... sending something. Don't worry about it.", A.Sus)
    Line("Ooh I can send people presents! Here!", A.Dumb)

    -----------------------------------------------------------
    -- GUN DEALER DELIVERED A CRATE
    -----------------------------------------------------------

    RegisterCategory("GunDealerDelivered", P.NORMAL, "When a Gun Dealer bot has finished delivering a crate.")
    Line("Delivery complete!", A.Default)
    Line("Your package has arrived.", A.Default)
    Line("There you go, it's all yours.", A.Default)
    Line("delivered lol", A.Casual)
    Line("package sent gg", A.Casual)
    Line("I hope you enjoy what's inside!", A.Nice)
    Line("Shipment delivered successfully.", A.Stoic)
    Line("BOOM! Delivery done!", A.Hothead)
    Line("It's delivered. You're welcome.", A.Bad)
    Line("Supplies delivered for the team!", A.Teamer)
    Line("Consignment delivery confirmed.", A.Tryhard)
    Line("That crate? It's nothing suspicious, I promise.", A.Sus)
    Line("Did it work? I think I sent something!", A.Dumb)

    -----------------------------------------------------------
    -- CRATE SPOTTED
    -----------------------------------------------------------

    RegisterCategory("GunDealerCrateSpotted", P.NORMAL, "When a bot spots a consignment crate nearby.")
    Line("There's a crate over here!", A.Default)
    Line("I see a consignment crate.", A.Default)
    Line("Found a supply drop.", A.Default)
    Line("yo theres a crate here", A.Casual)
    Line("ooh loot crate", A.Casual)
    Line("Oh look, a delivery! Let me open it.", A.Nice)
    Line("Consignment crate located.", A.Stoic)
    Line("CRATE! MINE!", A.Hothead)
    Line("Free stuff? Don't mind if I do.", A.Bad)
    Line("Found supplies, breaking it open for the team!", A.Teamer)
    Line("Supply crate identified. Acquiring contents.", A.Tryhard)
    Line("What's in this box, I wonder...", A.Sus)
    Line("Ooh a box! What's inside?", A.Dumb)

    -----------------------------------------------------------
    -- CRATE BROKEN OPEN
    -----------------------------------------------------------

    RegisterCategory("GunDealerCrateBroken", P.NORMAL, "When a bot has broken open a consignment crate.")
    Line("Cracked open a crate!", A.Default)
    Line("Got the goods from the crate.", A.Default)
    Line("Crate opened, let's see what we got.", A.Default)
    Line("loot acquired lol", A.Casual)
    Line("cracked it open nice", A.Casual)
    Line("Oh wonderful, let me see what's inside!", A.Nice)
    Line("Crate contents secured.", A.Stoic)
    Line("SMASHED IT OPEN!", A.Hothead)
    Line("Finally. Took long enough to break.", A.Bad)
    Line("Got the supplies! Sharing with everyone!", A.Teamer)
    Line("Crate neutralized. Contents acquired.", A.Tryhard)
    Line("I didn't break anything important, right?", A.Sus)
    Line("Yay! The box broke! Stuff fell out!", A.Dumb)

    -----------------------------------------------------------
    -- REQUESTING WEAPONS FROM GUN DEALER
    -----------------------------------------------------------

    RegisterCategory("GunDealerRequestWeapon", P.IMPORTANT, "When a bot approaches the Gun Dealer to request a weapon.")
    Line("Hey Gun Dealer, I need a weapon!", A.Default)
    Line("Can I get a gun from you?", A.Default)
    Line("I'm unarmed, can you help me out?", A.Default)
    Line("yo dealer hook me up with a weapon", A.Casual)
    Line("need a gun pls", A.Casual)
    Line("Excuse me, could I please have a weapon?", A.Nice)
    Line("Requesting armament.", A.Stoic)
    Line("GIVE ME A GUN! NOW!", A.Hothead)
    Line("Gimme a weapon already.", A.Bad)
    Line("Gun Dealer, the team needs weapons!", A.Teamer)
    Line("Requesting weapon from Gun Dealer for optimal loadout.", A.Tryhard)
    Line("I don't have a weapon... for totally innocent reasons.", A.Sus)
    Line("Excuse me Mr. Gun Dealer sir, can I have a gun?", A.Dumb)

    -----------------------------------------------------------
    -- REQUESTING AMMO FROM GUN DEALER
    -----------------------------------------------------------

    RegisterCategory("GunDealerRequestAmmo", P.IMPORTANT, "When a bot approaches the Gun Dealer to request ammo.")
    Line("I'm running low on ammo!", A.Default)
    Line("Gun Dealer, got any spare ammo?", A.Default)
    Line("Need a resupply over here.", A.Default)
    Line("yo im almost out of ammo", A.Casual)
    Line("need ammo bad", A.Casual)
    Line("Could I trouble you for some ammunition?", A.Nice)
    Line("Ammunition reserves critical.", A.Stoic)
    Line("I NEED AMMO! GIVE ME AMMO!", A.Hothead)
    Line("Running dry here. Ammo. Now.", A.Bad)
    Line("Team needs ammo, Gun Dealer!", A.Teamer)
    Line("Ammo reserves below threshold. Requesting resupply.", A.Tryhard)
    Line("I seem to be... low on bullets. How convenient.", A.Sus)
    Line("I keep pulling the trigger but nothing comes out!", A.Dumb)

    -----------------------------------------------------------
    -- THANKING THE GUN DEALER
    -----------------------------------------------------------

    RegisterCategory("GunDealerRequestThanks", P.NORMAL, "When a bot thanks the Gun Dealer after receiving supplies.")
    Line("Thanks for the supplies!", A.Default)
    Line("Appreciate the help, Gun Dealer.", A.Default)
    Line("Much appreciated!", A.Default)
    Line("ty for the gear", A.Casual)
    Line("thanks fam", A.Casual)
    Line("Thank you so much! You're the best!", A.Nice)
    Line("Supplies received. Acknowledged.", A.Stoic)
    Line("ABOUT TIME! But thanks I guess.", A.Hothead)
    Line("Yeah yeah, thanks or whatever.", A.Bad)
    Line("Thanks Gun Dealer! The team appreciates it!", A.Teamer)
    Line("Resupply confirmed. Combat effectiveness restored.", A.Tryhard)
    Line("Thanks... I'll put these to good use.", A.Sus)
    Line("Yay! New stuff! Thank you!", A.Dumb)

    -----------------------------------------------------------
    -- GUN DEALER UNDER ATTACK
    -----------------------------------------------------------

    RegisterCategory("GunDealerUnderAttack", P.CRITICAL, "When the Gun Dealer bot is being attacked and calling for help.")
    Line("I'm being attacked! Help!", A.Default)
    Line("Someone's shooting at me! I'm just a dealer!", A.Default)
    Line("Stop! I'm the Gun Dealer, I'm neutral!", A.Default)
    Line("bro im getting shot at wtf", A.Casual)
    Line("HELP im just the gun dealer!!", A.Casual)
    Line("Please stop shooting! I'm just trying to help everyone!", A.Nice)
    Line("Under fire. Requesting assistance.", A.Stoic)
    Line("WHO'S SHOOTING AT ME?! I'LL REMEMBER THIS!", A.Hothead)
    Line("Really? Shooting the arms dealer? Smart move, genius.", A.Bad)
    Line("Help! They're attacking the Gun Dealer!", A.Teamer)
    Line("Under attack. Gun Dealer defense protocol engaged.", A.Tryhard)
    Line("Why would you shoot me? I'm harmless... mostly.", A.Sus)
    Line("Ow ow ow! Stop it! I'm the good guy!", A.Dumb)
end

local DEPENDENCIES = {}
local function loadModule_Deferred()
    for i, v in pairs(DEPENDENCIES) do
        if not TTTBots[v] then
            timer.Simple(1, loadModule_Deferred)
            return
        end
    end
    LoadGunDealerChats()
end
timer.Simple(1, loadModule_Deferred)
