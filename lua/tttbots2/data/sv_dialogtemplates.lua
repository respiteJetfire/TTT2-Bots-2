local Dialog = TTTBots.Locale.Dialog ---@type TTTBots.DialogModule

-- Greet each other v1
Dialog.NewTemplate(
    "Greetings1",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
        Dialog.NewLine("GreetLast", 2),
    },
    false
)

-- Greet each other v2 - what's up
Dialog.NewTemplate(
    "Greetings2",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
        Dialog.NewLine("GreetLast", 2),
        Dialog.NewLine("WhatsUp", 1),
        Dialog.NewLine("WhatsUpResponse", 2),
    },
    false
)


-- Greet each other v3 - how are you
Dialog.NewTemplate(
    "Greetings3",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
        Dialog.NewLine("GreetLast", 2),
        Dialog.NewLine("HowAreYou", 1),
        Dialog.NewLine("HowAreYouResponse", 2),
    },
    false
)

-- Greet each other v4 - unreciprocated
Dialog.NewTemplate(
    "Greetings4",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
    },
    false
)

-- Say self is bored v1 - 1 positive response
Dialog.NewTemplate(
    "Bored1",
    2,
    {
        Dialog.NewLine("AnyoneBored", 1),
        Dialog.NewLine("PositiveResponse", 2),
    },
    false
)

-- Say self is bored v2 - 2 negative response
Dialog.NewTemplate(
    "Bored2",
    3,
    {
        Dialog.NewLine("AnyoneBored", 1),
        Dialog.NewLine("NegativeResponse", 2),
        Dialog.NewLine("NegativeResponse", 3),
    },
    false
)

-- Say self is bored v3 - rude response
Dialog.NewTemplate(
    "Bored3",
    2,
    {
        Dialog.NewLine("AnyoneBored", 1),
        Dialog.NewLine("RudeResponse", 2),
    },
    false
)

-- ===========================================================================
-- Tier 6 — Personality & Immersion: New dialog templates
-- ===========================================================================

-- "The Investigation" — 3 bots discuss a recent death and suspects
Dialog.NewTemplate(
    "TheInvestigation",
    3,
    {
        Dialog.NewLine("InvestigationAsk",     1),
        Dialog.NewLine("InvestigationWitness", 2),
        Dialog.NewLine("InvestigationSuspect", 3),
        Dialog.NewLine("InvestigationChallenge", 1),
    },
    false
)
Dialog.Templates["TheInvestigation"].context = "corpse"  -- prefer after a body is found

-- "The Accusation" — 2 bots call and challenge a KOS
Dialog.NewTemplate(
    "TheAccusation",
    2,
    {
        Dialog.NewLine("AccusationClaim",       1),
        Dialog.NewLine("AccusationChallenge",   2),
        Dialog.NewLine("AccusationEvidence",    1),
        Dialog.NewLine("AccusationVerdict",     2),
    },
    false
)
Dialog.Templates["TheAccusation"].context = "accusation"

-- "The Defense" — 2 bots: accused defends themselves
Dialog.NewTemplate(
    "TheDefense",
    2,
    {
        Dialog.NewLine("DefenseProtest",   1),
        Dialog.NewLine("DefenseConfront",  2),
        Dialog.NewLine("DefenseDeny",      1),
    },
    false
)
Dialog.Templates["TheDefense"].context = "accusation"

-- "The Standoff" — 2 bots, late game only (gated externally in sv_dialog.lua)
Dialog.NewTemplate(
    "TheStandoff",
    2,
    {
        Dialog.NewLine("StandoffObserve",  1),
        Dialog.NewLine("StandoffDeny",     2),
        Dialog.NewLine("StandoffDrop",     1),
        Dialog.NewLine("StandoffCounter",  2),
    },
    false
)
Dialog.Templates["TheStandoff"].context = "standoff"  -- only fires in LATE/OVERTIME with ≤3 alive

-- "Post-Round Banter" — 2-4 bots celebrating or lamenting, only when dead
Dialog.NewTemplate(
    "PostRoundBanter",
    2,
    {
        Dialog.NewLine("PostRoundWinner",   1),
        Dialog.NewLine("PostRoundLoser",    2),
        Dialog.NewLine("PostRoundExplain",  1),
    },
    true  -- onlyWhenDead = true
)
Dialog.Templates["PostRoundBanter"].context = "postround"
