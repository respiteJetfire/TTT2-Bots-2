TTTBots.Behaviors.GetPirateContract = {}

local lib = TTTBots.Lib

local GetPirateContract = TTTBots.Behaviors.GetPirateContract
GetPirateContract.Name = "Get Pirate Contract"
GetPirateContract.Description = "Look for and pick up a pirate contract"
GetPirateContract.Interruptible = true
GetPirateContract.UseRange = 50 --- The range at which we can pick up a pirate contract

GetPirateContract.TargetClass = "weapon_ttt2_contract"

local STATUS = TTTBots.STATUS

function GetPirateContract.IsPirate(bot)
    local role = bot:GetSubRole()
    return role == ROLE_PIRATE_CAPTAIN or role == ROLE_PIRATE
end

function GetPirateContract.ValidateContract(contract)
    for i, v in pairs(player.GetAll()) do
        if v:HasWeapon(GetPirateContract.TargetClass) then
            return false
        end
    end
    return IsValid(contract) and contract:GetClass() == GetPirateContract.TargetClass
end

function GetPirateContract.GetNearestContract(bot)
    local contracts = ents.FindByClass(GetPirateContract.TargetClass)
    local validContracts = {}
    for i, v in pairs(contracts) do
        if not GetPirateContract.ValidateContract(v) then
            continue
        end
        table.insert(validContracts, v)
    end

    local nearestContract = lib.GetClosest(validContracts, bot:GetPos())
    return nearestContract
end

function GetPirateContract.PickUpContract(bot, contract)
    contract:Use(bot)
end

--- Validate the behavior
function GetPirateContract.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end --- We are preoccupied with an attacker.
    if GetPirateContract.IsPirate(bot) then return false end --- We are already a pirate.

    local isContractNearby = (bot.targetContract or GetPirateContract.GetNearestContract(bot) ~= nil)

    return isContractNearby
end

--- Called when the behavior is started
function GetPirateContract.OnStart(bot)
    local contract = GetPirateContract.GetNearestContract(bot)
    bot.targetContract = contract
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function GetPirateContract.OnRunning(bot)
    if not GetPirateContract.ValidateContract(bot.targetContract) then
        return STATUS.FAILURE
    end

    local contract = bot.targetContract
    local locomotor = bot:BotLocomotor()
    locomotor:SetGoal(contract:GetPos())
    locomotor:PauseRepel()
    local distToContract = bot:GetPos():Distance(contract:GetPos())

    if distToContract < 300 then
        locomotor:LookAt(contract:GetPos())
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function GetPirateContract.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function GetPirateContract.OnFailure(bot)
end

--- Called when the behavior ends
function GetPirateContract.OnEnd(bot)
    bot.targetContract = nil
    local locomotor = bot:BotLocomotor()
    locomotor:ResumeRepel()
end

timer.Create("TTTBots.Behaviors.GetPirateContract.PickUpNearbyContracts", 0.5, 0, function()
    for i, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        local contract = bot.targetContract
        if not (contract and GetPirateContract.ValidateContract(contract)) then continue end
        local distToContract = bot:GetPos():Distance(contract:GetPos())
        if distToContract < GetPirateContract.UseRange then
            GetPirateContract.PickUpContract(bot, contract)
        end
    end
end)
