TTTBots.Locale.Dialog = {}
---@class TTTBots.DialogModule
local Dialog = TTTBots.Locale.Dialog

---@class Dialog
---@field name string
---@field participants table<Player> A list of current player participants
---@field targetNumber number The ideal number of participants (not the current number)
---@field lines table<number, DialogLine>
---@field currentLine number
---@field isFinished boolean
---@field onlyWhenDead boolean If the participants can only talk when all dead.
---@field waiting boolean If the dialog is waiting for a callback to continue.
---@alias DialogTemplate Dialog

---@class DialogLine
---@field line string The 'line' (actually the event name) of the dialog line.
---@field spoken boolean
---@field participantId number The ID of the participant who spoke/should speak this line.

Dialog.Templates = {} --- @type table<string, Dialog>

---Create a line for template creation.
---@param line string Basically just the ID of the chat_en entry.
---@param participantId number The ID of the participant who spoke/should speak this line.
---@return DialogLine
function Dialog.NewLine(line, participantId)
    return {
        line = line,
        spoken = false,
        participantId = participantId,
        isLLM = false,
    }
end

--- Create an LLM-generated line for template creation.
--- The bot will use the LLM provider to produce a contextual casual remark
--- instead of pulling from the locale.
---@param participantId number  The ID of the participant who will speak this line.
---@param triggerReason string  Passed to GetCasualPrompt (e.g. "idle", "post_combat").
---@return DialogLine
function Dialog.NewLLMLine(participantId, triggerReason)
    return {
        line = "__llm__",
        spoken = false,
        participantId = participantId,
        isLLM = true,
        triggerReason = triggerReason or "idle",
    }
end

function Dialog.NewTemplate(name, targetNumber, lines, onlyWhenDead)
    local newDialog = {
        name = name,
        targetNumber = targetNumber,
        lines = lines,
        currentLine = 1,
        isFinished = false,
        onlyWhenDead = onlyWhenDead,
        waiting = false,
    }
    Dialog.Templates[name] = newDialog
    return newDialog
end

---Selects some participants at random
---@param template DialogTemplate
---@return table<Player>|false participants
function Dialog.SelectParticipants(template)
    local num = template.targetNumber
    local possibleBots = TTTBots.Lib.FilterTable(TTTBots.Bots, function(bot)
        if not IsValid(bot) then return false end
        local botAlive = TTTBots.Lib.IsPlayerAlive(bot)
        return botAlive or template.onlyWhenDead
    end)

    local participants = {} ---@type table<Player>
    for i = 1, num do
        local rand = table.Random(possibleBots) ---@type Player|nil
        if not rand then return false end -- No more bots left, we can't do this one.
        table.insert(participants, rand)
        table.RemoveByValue(possibleBots, rand)
    end

    return participants
end

function Dialog.EndDialog(dialog)
    dialog.isFinished = true
    dialog.waiting = false
end

---Verify if a dialog can be continued.
---@param dialog Dialog
---@return boolean canContinue
function Dialog.VerifyLifeStates(dialog)
    local shouldBeAlive = not dialog.onlyWhenDead
    local participants = dialog.participants
    local IsAlive = TTTBots.Lib.IsPlayerAlive
    for i, participant in pairs(participants) do
        if not IsValid(participant) then return false end -- If one of them leaves the game then we can't continue
        if IsAlive(participant) ~= shouldBeAlive then
            return false
        end
    end

    return true
end

---Executes the next line of a dialog.
---@param dialog Dialog
---@return Dialog dialog
function Dialog.ExecuteDialog(dialog)
    if dialog.isFinished or dialog.waiting then return dialog end
    local dline = dialog.lines[dialog.currentLine]
    if not dline then
        Dialog.EndDialog(dialog)
        return dialog
    end
    local participant = dialog.participants[dline.participantId] ---@type Bot

    if not Dialog.VerifyLifeStates(dialog) then -- We cannot run a dialog if the participants are alive when they shouldn't be
        Dialog.EndDialog(dialog)
        return dialog
    end

    local lastdline = dialog.lines[dialog.currentLine - 1]
    local lastParticipant = lastdline and dialog.participants[lastdline.participantId] ---@type Player|nil
    local lastParticipantName = lastParticipant and lastParticipant:Nick() or ""

    local nextdline = dialog.lines[dialog.currentLine + 1]
    local nextParticipant = nextdline and dialog.participants[nextdline.participantId] ---@type Player|nil
    local nextParticipantName = nextParticipant and nextParticipant:Nick() or ""

    local chatter = participant:BotChatter()
    if not chatter then
        Dialog.EndDialog(dialog)
        print("no chatter on bot`")
        return dialog
    end

    -- LLM-generated line branch
    if dline.isLLM then
        local casualLLMEnabled = TTTBots.Lib.GetConVarBool("chatter_casual_llm") ~= false
        local casualLLMChance  = TTTBots.Lib.GetConVarFloat("chatter_casual_llm_chance") or 0.40
        if not casualLLMEnabled or math.random() > casualLLMChance then
            -- Skip this line gracefully (advance without speaking)
            dialog.currentLine = dialog.currentLine + 1
            return Dialog.ExecuteDialog(dialog)
        end

        local triggerReason = dline.triggerReason or "idle"
        local prompt, sendOpts
        local apiProvider = TTTBots.Lib.GetConVarInt("chatter_api_provider") or 0
        if apiProvider == 4 then  -- local/Ollama
            local promptData = TTTBots.LlamaPrompts.GetCasualPrompt(participant, triggerReason)
            prompt = promptData.prompt
            sendOpts = {
                teamOnly = false,
                wasVoice = false,
                systemPrompt = promptData.system,
                triggerReason = triggerReason,
            }
        else
            prompt = TTTBots.PromptContext.GetCasualCloudPrompt(participant, triggerReason)
            sendOpts = {
                teamOnly = false,
                wasVoice = false,
                systemPrompt = prompt and prompt.system or nil,
                triggerReason = triggerReason,
            }
            prompt = prompt and prompt.prompt or prompt  -- extract user prompt from table
        end

        dialog.waiting = true
        dline.spoken = true
        TTTBots.Providers.SendText(prompt, participant, sendOpts, function(envelope)
            if not IsValid(participant) then
                Dialog.EndDialog(dialog)
                return
            end
            local text = envelope.ok and envelope.text or nil
            if text then
                chatter:Say(text, false, dialog.onlyWhenDead, function()
                    dialog.currentLine = dialog.currentLine + 1
                    dialog.waiting = false
                end)
            else
                -- LLM failed — skip line silently
                dialog.currentLine = dialog.currentLine + 1
                dialog.waiting = false
            end
        end)
        return dialog
    end

    local translatedLine = TTTBots.Locale.GetLocalizedLine("Dialog" .. dline.line, participant,
        { lastBot = lastParticipantName, nextBot = nextParticipantName, bot = participant:Nick() })

    if not translatedLine then
        Dialog.EndDialog(dialog)
        return dialog
    end

    dialog.waiting = true
    dline.spoken = true
    chatter:Say(translatedLine, false, dialog.onlyWhenDead, function()
        dialog.currentLine = dialog.currentLine + 1
        dialog.waiting = false
    end)

    return dialog
end

---Generate a dialog based on a template.
---@param templateName string
---@param participants? table<Player>
---@return Dialog|false dialog The dialog object, or false if it failed to generate.
function Dialog.New(templateName, participants)
    local template = Dialog.Templates[templateName]
    local dialog = table.Copy(template) ---@type Dialog
    dialog.participants = participants or Dialog.SelectParticipants(template) or {}

    if table.Count(dialog.participants) == 0 then return false end

    return dialog
end

--- Handles the execution of a dialog until it is finished.
---@param dialog Dialog
function Dialog.ExecuteUntilDone(dialog)
    if not (dialog and Dialog.VerifyLifeStates(dialog)) then return end
    dialog = Dialog.ExecuteDialog(dialog)
    if dialog.isFinished then return end
    timer.Simple(5, function()
        Dialog.ExecuteUntilDone(dialog)
    end)
end

function Dialog.NewFromRandom()
    local template = table.Random(Dialog.Templates)
    local participants = Dialog.SelectParticipants(template)
    if not participants then return false end
    return Dialog.New(template.name, participants)
end

-- ---------------------------------------------------------------------------
-- Context-weighted template selection (Tier 6 — Personality & Immersion)
-- ---------------------------------------------------------------------------

--- Returns the current dialog context string based on round state.
--- Used to weight which template is most appropriate right now.
---@return string context
function Dialog.GetCurrentContext()
    if not TTTBots.Match.RoundActive then
        return "postround"
    end

    -- Check standoff conditions (LATE/OVERTIME with ≤3 alive)
    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    if #alivePlayers <= 3 then
        local ra = TTTBots.Bots[1] and TTTBots.Bots[1]:BotRoundAwareness()
        if ra then
            local PHASE = TTTBots.Components.RoundAwareness.PHASE
            local phase = ra:GetPhase()
            if phase == PHASE.LATE or phase == PHASE.OVERTIME then
                return "standoff"
            end
        end
    end

    -- Check if there are recent unprocessed corpses (body found in last 30s)
    local corpsesExist = TTTBots.Match.Corpses and #TTTBots.Match.Corpses > 0
    if corpsesExist then
        return "corpse"
    end

    -- Check if anyone has been accused recently
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) and bot.accusedBy and IsValid(bot.accusedBy) then
            if (CurTime() - (bot.accusedTime or 0)) < 45 then
                return "accusation"
            end
        end
    end

    return "generic"
end

--- Returns whether the current round is in a 'quiet/idle' phase:
--- no kills recently and no active accusations/standoffs.
---@return boolean
function Dialog.IsIdleContext()
    if not TTTBots.Match.RoundActive then return false end

    -- Any corpses means we are in an active investigation context
    if TTTBots.Match.Corpses and #TTTBots.Match.Corpses > 0 then return false end

    -- Any recent accusation disqualifies idle context
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) and bot.accusedBy and IsValid(bot.accusedBy) then
            if (CurTime() - (bot.accusedTime or 0)) < 45 then return false end
        end
    end

    return true
end

--- Selects a dialog template weighted toward the current context.
--- Context-matching templates get 3× weight; generic templates get 1× weight.
---@return Dialog|false dialog
function Dialog.NewFromContext()
    local context = Dialog.GetCurrentContext()

    local weighted = {}
    for name, template in pairs(Dialog.Templates) do
        local tContext = template.context or "generic"
        local weight
        if tContext == context then
            weight = 3  -- context-matched: high weight
        elseif tContext == "idle" and Dialog.IsIdleContext() then
            weight = 2  -- casual templates get extra weight during quiet rounds
        else
            weight = 1
        end
        for _ = 1, weight do
            table.insert(weighted, template)
        end
    end

    if #weighted == 0 then return false end
    local chosen     = weighted[math.random(1, #weighted)]
    local participants = Dialog.SelectParticipants(chosen)
    if not participants then return false end
    return Dialog.New(chosen.name, participants)
end

include("tttbots2/data/sv_dialogtemplates.lua")

local currentDialog = nil ---@type Dialog|nil
timer.Create("TTTBots.Dialog.StartRandomDialogs", 60, 0, function()
    if math.random(1, 4) > 1 then return end
    if (currentDialog and not Dialog.VerifyLifeStates(currentDialog)) then currentDialog = nil end
    -- if (currentDialog) then PrintTable(currentDialog) end
    if (currentDialog and not currentDialog.isFinished) then return end
    local dialog = Dialog.NewFromContext()  -- context-weighted selection
    if not dialog then return end
    -- print("--- NEW ---")
    -- PrintTable(dialog)
    currentDialog = dialog
    Dialog.ExecuteUntilDone(dialog)
end)

-- ---------------------------------------------------------------------------
-- Casual / idle dialog timer
-- Fires more often during quiet rounds and when bots are bored.
-- Runs every 30 seconds; chance scaled by average bot boredom.
-- ---------------------------------------------------------------------------
timer.Create("TTTBots.Dialog.CasualIdle", 30, 0, function()
    if not TTTBots.Match.RoundActive then return end
    if not Dialog.IsIdleContext() then return end
    -- If the main dialog is mid-flow, don't interrupt it
    if currentDialog and not currentDialog.isFinished then return end

    -- Compute average boredom across bots to scale chance
    local bots = TTTBots.Lib.GetAliveBots()
    if #bots == 0 then return end

    local totalBoredom = 0
    for _, bot in ipairs(bots) do
        if IsValid(bot) and bot.components then
            local pers = bot:BotPersonality()
            if pers then totalBoredom = totalBoredom + (pers:GetBoredom() or 0) end
        end
    end
    local avgBoredom = totalBoredom / #bots  -- 0.0 – 1.0

    -- Base 20% chance, boosted up to 60% when boredom is high
    local chance = 0.20 + (avgBoredom * 0.40)
    if math.random() > chance then return end

    -- Prefer casual/idle templates; fall back to NewFromContext if none available
    local idleTemplates = {}
    for name, template in pairs(Dialog.Templates) do
        if (template.context or "generic") == "idle" then
            table.insert(idleTemplates, template)
        end
    end

    local chosen
    if #idleTemplates > 0 then
        chosen = idleTemplates[math.random(1, #idleTemplates)]
    else
        local dialog = Dialog.NewFromContext()
        if dialog then
            currentDialog = dialog
            Dialog.ExecuteUntilDone(dialog)
        end
        return
    end

    local participants = Dialog.SelectParticipants(chosen)
    if not participants then return end
    local dialog = Dialog.New(chosen.name, participants)
    if not dialog then return end
    currentDialog = dialog
    Dialog.ExecuteUntilDone(dialog)
end)
