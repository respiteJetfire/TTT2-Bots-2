---@class CPersonality : Component
TTTBots.Components.Personality = {}

local lib = TTTBots.Lib
---@class CPersonality : Component
local BotPersonality = TTTBots.Components.Personality

BotPersonality.Traits = TTTBots.Traits

function BotPersonality:New(bot)
    local newPersonality = {}
    setmetatable(newPersonality, {
        __index = function(t, k) return BotPersonality[k] end,
    })
    newPersonality:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        --- print("Initialized Personality for bot " .. bot:Nick())
    end

    return newPersonality
end

TTTBots.Archetypes = {
    Tryhard = "Tryhard/nerd", --- Says nerdy/tryhard things often
    Hothead = "Hothead",      --- Quick to anger in his communication
    Stoic = "Stoic",          --- Rarely complains/gloats
    Dumb = "Dumb",            --- huh?
    Nice = "Nice",            --- Says nice things often, loves to compliment.
    Bad = "Bad",              --- just bad
    Teamer = "Teamer",        --- loves to say "us" instead of "me"
    Sus = "Sus/Quirky",       --- "guys im the traitor" ... that kind of thing
    Casual = "Casual",        --- loves to make jokes, talks in lowercase most of the time
    Default = "default",      --- default archetype; used as a fallback
}

local elevenLabsVoices = {
    male = {
        ["Tryhard/nerd"] = {
            "4AdGoETSmAOc9g6196TK",
            "3jXBJWtJEjgdwPqueyXT",
            "EK8qPxNaT7PcXc6340pQ"},
        Hothead = {
            "W015G87ObkhtiOgbl1yE",
            "pqHfZKP75CvOlQylNhV4",
            "zcAOhNBS3c14rBihAFp1"},
        Stoic = {
            "Zlb1dXrM653N07WRdFW3",
            "5Q0t7uMcjvnagumLfvZi",
            "CwhRBWXzGAHq8TQ4Fs17"},
        Dumb = {
            "t0jbNlBVZ17f02VDIeMI",
            "D38z5RcWu1voky8WS1ja",
            "wo6udizrrtpIxWGp2qJk"},
        Nice = {
            "N2lVS1w4EtoT3dr4eOWO",
            "2EiwWnXFnvU5JabPnv8n",
            "SOYHLrjzK2X1ezoPC6cr"},
        Bad = {
            "YEkUdc7PezGaXaRslSHB",
            "Ybqj6CIlqb6M85s9Bl4n",
            "efGTHf4ukBiG4n8lptfp"},
        Teamer = {
            "OhisAd2u8Q6qSA4xXAAT",
            "PPzYpIqttlTYA83688JI",
            "zGw1MayuXJEVWol6mFfg"},
        ["Sus/Quirky"] = {
            "2gPFXx8pN3Avh27Dw5Ma",
            "DUnzBkwtjRWXPr6wRbmL",
            "INDKfphIpZiLCUiXae4o",
            "3SF4rB1fGBMXU9xRM7pz"},
        Casual = {
            "iP95p4xoKVk53GoZ742B",
            "IKne3meq5aSn9XLyUdCD",
            "cjVigY5qzO86Huf0OWal"},
        Default = {
            "JBFqnCBsd6RMkjVDRZzb",
            "ZQe5CZNOzWyzPSCn5a3c",
            "TxGEqnHWrfWFTfGW9XjX"},
    },
    female = {
        ["Tryhard/nerd"] = {
            "MF3mGyEYCl7XYWbV9V6O",
            "jsCqWAovK2LkecY7zXl4",
            "pFZP5JQG7iQjIQuC4Bku"},
        Hothead = {
            "Pid5DJleNF2sxsuF6YKD",
            "AB9XsbSA4eLG12t2myjN"},
        Stoic = {
            "QMSGabqYzk8YAneQYYvR",
            "XB0fDUnXU5powFXDhCwa",
            "pFZP5JQG7iQjIQuC4Bku"},
        Dumb = {
            "LSah3F2oqv0qunZV6QDs"},
        Nice = {
            "9BWtsMINqrJLrRacOk9x",
            "cgSgspJ2msm6clMCkdW9",
            "jBpfuIE2acCO8z3wKNLl"},
        Bad = {
            "5PWbsfogbLtky5sxqtBz"},
        Teamer = {
            "LcfcDJNUP1GQjkzn1xUU",
            "oWAxZDx7w5VEj9dCyTzz"},
        ["Sus/Quirky"] = {
            "TC0Zp7WVFzhA8zpTlRqV",
            "flHkNRp1BlvT73UL6gyz",
            "eVItLK1UvXctxuaRV2Oq"},
        Casual = {
            "SAz9YHcvj6GT2YYXdXww",
            "zrHiDhphv9ZnVXBqCLjz",
            "piTKgcLEGmPE4e6mEKli"},
        Default = {
            "pMsXgVXv3BLzUgSXRplE",
            "21m00Tcm4TlvDq8ikWAM",
            "oWAxZDx7w5VEj9dCyTzz"},
    },
}

local FreeTTSVoices = {
    male = {
        ["Tryhard/nerd"] = {
            --- Should speak quickly and with a higher pitch
            Sam = {
                pitch = math.random(92, 110),
                speed = 160
            },
            Mike = {
                pitch = math.random(117, 130),
                speed = 170
            },
        },
        Hothead = {
            --- Should speak very quickly and with a comically high pitch
            Sam = {
                pitch = math.random(160, 175),
                speed = 200
            },
            Mike = {
                pitch = math.random(190, 210),
                speed = 230
            },
        },
        Stoic = {
            --- Should speak slowly and with a lower pitch
            Sam = {
                pitch = math.random(80, 90),
                speed = 140
            },
            Mike = {
                pitch = math.random(100, 110),
                speed = 150
            },
        },
        Dumb = {
            --- Should speak with a big random range of pitch with a relatively very low speed
            Sam = {
                pitch = math.random(60, 180),
                speed = 120
            },
            Mike = {
                pitch = math.random(60, 180),
                speed = 120
            },
        },
        Nice = {
            --- Should speak with a higher pitch and a normal speed
            Sam = {
                pitch = math.random(100, 120),
                speed = 150
            },
            Mike = {
                pitch = math.random(120, 140),
                speed = 160
            },
        },
        Bad = {
            --- Should speak with a lower pitch and a normal speed
            Sam = {
                pitch = math.random(70, 90),
                speed = 150
            },
            Mike = {
                pitch = math.random(90, 110),
                speed = 160
            },
        },
        Teamer = {
            --- Should speak with an even higher pitch and a normal speed
            Sam = {
                pitch = math.random(110, 130),
                speed = 150
            },
            Mike = {
                pitch = math.random(130, 150),
                speed = 160
            },
        },
        ["Sus/Quirky"] = {
            --- Should speak with a much lower pitch and a normal speed
            Sam = {
                pitch = math.random(50, 70),
                speed = 150
            },
            Mike = {
                pitch = math.random(70, 90),
                speed = 160
            },
        },
        Casual = {
            --- Should speak with a lower pitch and a faster speed
            Sam = {
                pitch = math.random(70, 90),
                speed = 170
            },
            Mike = {
                pitch = math.random(90, 110),
                speed = 180
            },
        },
        Default = {
            --- Should speak with a normal pitch and a normal speed
            Sam = {
                pitch = math.random(80, 100),
                speed = 150
            },
            Mike = {
                pitch = math.random(100, 120),
                speed = 160
            },
        },
    },
    female = {
        ["Tryhard/nerd"] = {
            --- Should speak quickly and with a higher pitch
            Mary = {
                pitch = math.random(160, 175),
                speed = 200
            },
        },
        Hothead = {
            --- Should speak very quickly and with a comically high pitch
            Mary = {
                pitch = math.random(190, 210),
                speed = 230
            },
        },
        Stoic = {
            --- Should speak slowly and with a lower pitch
            Mary = {
                pitch = math.random(140, 160),
                speed = 180
            },
        },
        Dumb = {
            --- Should speak with a big random range of pitch with a relatively very low speed
            Mary = {
                pitch = math.random(60, 180),
                speed = 120
            },
        },
        Nice = {
            --- Should speak with a higher pitch and a normal speed
            Mary = {
                pitch = math.random(170, 190),
                speed = 200
            },
        },
        Bad = {
            --- Should speak with a lower pitch and a normal speed
            Mary = {
                pitch = math.random(130, 150),
                speed = 200
            },
        },
        Teamer = {
            --- Should speak with an even higher pitch and a normal speed
            Mary = {
                pitch = math.random(190, 210),
                speed = 200
            },
        },
        ["Sus/Quirky"] = {
            --- Should speak with a much lower pitch and a normal speed
            Mary = {
                pitch = math.random(110, 130),
                speed = 200
            },
        },
        Casual = {
            --- Should speak with a lower pitch and a faster speed
            Mary = {
                pitch = math.random(130, 150),
                speed = 220
            },
        },
        Default = {
            --- Should speak with a normal pitch and a normal speed
            Mary = {
                pitch = math.random(150, 170),
                speed = 200
            },
        },
    },
}

function decideOnVoiceBadTTS(self)
    --- using the bot's gender and archetype, decide on a voice
    local gender = self.gender
    --- print("gender", gender)
    local archetype = self.archetype
    --- print("archetype", archetype)

    local selectedVoiceKey
    if not FreeTTSVoices[gender] or not FreeTTSVoices[gender][archetype] then
        -- Fallback to default if no specific voice is found
        --- print("No voice found")
        self.voice = FreeTTSVoices[gender]["Default"]
        self.voice.name = "Sam"
        self.voice.type = "FreeTTS"
        self.voice.speed = 150
        self.voice.pitch = 100
    else
        -- Select a random voice configuration for the given gender and archetype
        --- print("Voice found")
        local voices = FreeTTSVoices[gender][archetype]
        --- print("Voices", voices)
        local voiceKeys = {}
        for k in pairs(voices) do
            table.insert(voiceKeys, k)
        end
        selectedVoiceKey = voiceKeys[math.random(#voiceKeys)]
        self.voice = voices[selectedVoiceKey]
        self.voice.name = selectedVoiceKey
        self.voice.speed = voices[selectedVoiceKey].speed
        self.voice.pitch = voices[selectedVoiceKey].pitch
        self.voice.type = "FreeTTS"
        --- print("Selected voice name", self.voice.name, "speed", self.voice.speed, "pitch", self.voice.pitch)
    end
end

function decideOnVoiceElevenLabs(self, bot)
    --- using the bot's name first decide on a voice ID, then if not then do it via gender and archetype
    -- --- print("decideOnVoiceElevenLabs")
    local name = bot.name
    -- --- print("name", name)
    ---if mufcshadow99 or connor is in the name, then use the voice "oByejetP0L8VFcHZtxaO" (not case sensitive)
    if string.find(string.lower(name), "mufcshadow99") or string.find(string.lower(name), "connor") then
        self.voice = { id = "oByejetP0L8VFcHZtxaO", type = "elevenlabs" }
        self.archetype = "Hothead"
        --- print("Using voice for mufcshadow99 or connor")
        return
    --- else if callum or armedjetfire23 is in the name, then use the voice "OvGLOVTuYN2qDoW5MAR5" (not case sensitive)
    elseif string.find(string.lower(name), "callum") or string.find(string.lower(name), "armedjetfire23") then
        self.voice = { id = "HGkbumsunOcslYeS8ww4", type = "elevenlabs" }
        self.archetype = "Tryhard/nerd"
        --- print("Using voice for callum or armedjetfire23")
        return
    --- else if violentnerve or emily is in the name, then use the voice "JxPtpTnTYYaRhdB6dpaw" (not case sensitive)
    elseif string.find(string.lower(name), "violentnerve") or string.find(string.lower(name), "emily") then
        self.voice = { id = "JxPtpTnTYYaRhdB6dpaw", type = "elevenlabs" }
        self.archetype = "Nice"
        --- print("Using voice for violentnerve or emily")
        return
    else
        --- using the bot's gender and archetype, decide on a voice
        local gender = self.gender
        --- print("gender", gender)
        local archetype = self.archetype
        --- print("archetype", archetype)

        local selectedVoiceKey
        if not elevenLabsVoices[gender] or not elevenLabsVoices[gender][archetype] then
            -- Fallback to default if no specific voice is found
            --- print("No voice found")
            local voices = elevenLabsVoices[gender]["Default"]
            selectedVoiceKey = math.random(#voices)
            --- print("Selected default voice key", selectedVoiceKey)
            self.voice = { id = voices[selectedVoiceKey], type = "elevenlabs" }
            --- print("Selected default voice", self.voice)
        else
            -- Select a random voice configuration for the given gender and archetype
            --- print("Voice found")
            local voices = elevenLabsVoices[gender][archetype]
            --- print("Voices", voices)
            selectedVoiceKey = math.random(#voices)
            --- print("Selected voice key", selectedVoiceKey)
            self.voice = { id = voices[selectedVoiceKey], type = "elevenlabs" }
            --- print("Selected voice", self.voice)
        end
    end
end

local AzureVoices = {
    male = {
        "en-US-ChristopherMultilingualNeural",
        "en-US-AndrewMultilingualNeural",
        "en-US-ChristopherMultilingualNeural",
        "en-US-BrandonMultilingualNeural",
        "en-US-BrianMultilingualNeural",
        "en-US-RyanMultilingualNeural",
        "en-US-KaiNeural",
        "en-US-GuyNeural",
        "en-US-JasonNeural",
        "en-US-DavisNeural",
        "en-US-TonyNeural",
        "en-US-EricNeural",
        "en-US-JacobNeural",
        "en-US-RogerNeural",
        "en-US-SteffanNeural",
        "en-GB-OllieMultilingualNeural",
        "fr-FR-RemyMultilingualNeural",
        "fr-FR-LucienMultilingualNeural",
        "de-DE-FlorianMultilingualNeural",
        "it-IT-AlessioMultilingualNeural",
        "it-IT-GiuseppeMultilingualNeural",
        "it-IT-MarcelloMultilingualNeural",
        "pt-BR-MacerioMultilingualNeural",
        "es-ES-TristanMultilingualNeural",

    },
    female = {
        "en-US-AvaMultilingualNeural",
        "en-US-CoraMultilingualNeural",
        "en-US-EmmaMultilingualNeural",
        "en-US-MichelleNeural",
        "en-US-ElizabethNeural",
        "en-US-AnaNeural",
        "en-US-AshleyNeural",
        "en-US-AmberNeural",
        "en-US-SaraNeural",
        "en-US-LunaNeural",
        "en-US-JennyNeural",
        "en-US-EmmaNeural",
        "fr-FR-VivienneMultilingualNeural",
        "de-DE-SeraphinaMultilingualNeural",
        "it-IT-IsabellaMultilingualNeural",
        "pt-BR-ThalitaMultilingualNeural",
        "es-ES-ArabellaMultilingualNeural",
        "es-ES-IsidoraMultilingualNeural",
        "es-ES-XimenaMultilingualNeural",
    }
}

function decideOnVoiceMicrosoftTTS(self)
    --- using Azure TTS, decide on a voice, up to 6 voices for each gender
    local gender = self.gender
    local voices = AzureVoices[gender]
    if not voices then
        -- Fallback to default if no specific voice is found
        self.voice = { id = "en-US-TonyNeural", type = "Azure" }
    else
        -- Select a random voice for the given gender
        local selectedVoiceKey = math.random(#voices)
        self.voice = { id = voices[selectedVoiceKey], type = "Azure" }
    end
end

-- Piper voices available in the ttsapi Docker container.
-- Each entry has piperVoice (model name) and name (display label).
local PiperVoices = {
    male = {
        { piperVoice = "en_US-lessac-medium",              name = "Lessac" },   -- US male, natural
        { piperVoice = "en_US-ryan-medium",                name = "Ryan" },     -- US male, expressive
        { piperVoice = "en_US-joe-medium",                 name = "Joe" },      -- US male, casual
        { piperVoice = "en_US-danny-low",                  name = "Danny" },    -- US male, soft-spoken
        { piperVoice = "en_US-norman-medium",              name = "Norman" },   -- US male, warm baritone
        { piperVoice = "en_US-bryce-medium",               name = "Bryce" },    -- US male, deep/calm
        { piperVoice = "en_GB-alan-medium",                name = "Alan" },     -- GB male, authoritative
        { piperVoice = "en_GB-northern_english_male-medium", name = "Callum" }, -- GB male, Northern
    },
    female = {
        { piperVoice = "en_US-amy-medium",       name = "Amy" },     -- US female, clear
        { piperVoice = "en_GB-cori-medium",      name = "Cori" },    -- GB female, distinct
        { piperVoice = "en_US-kathleen-low",     name = "Kathleen" },-- US female, calm
        { piperVoice = "en_US-ljspeech-medium",  name = "Lydia" },   -- US female, expressive
        { piperVoice = "en_GB-jenny_dioco-medium", name = "Jenny" }, -- GB female, natural
    },
}

function decideOnVoiceLocal(self)
    local gender = self.gender or "male"
    local pool = PiperVoices[gender] or PiperVoices.male
    local chosen = pool[math.random(#pool)]
    self.voice = {
        piperVoice = chosen.piperVoice,
        name       = chosen.name,
        speed      = 1.26 + math.random() * 0.42, -- 1.26 to 1.68 speaking rate (40% faster)
        type       = "local",
    }
end

function BotPersonality:Initialize(bot)
    -- --- print("Initializing")
    bot.components = bot.components or {}
    bot.components.personality = self

    self.componentID = string.format("Personality (%s)", lib.GenerateID()) -- Component ID, used for debugging
    self.ThinkRate = 5 -- Run every 5th tick (1Hz)
    self.gender = (math.random(1, 100) < 50 and "male") or "female"
    self.HIM = (self.gender == "male" and "him") or "her"
    self.HIS = (self.gender == "male" and "his") or "hers"
    self.HE = (self.gender == "male" and "he") or "her"

    self.textAPI = (function()
        local apiProvider = lib.GetConVarInt("chatter_api_provider")
        if apiProvider == 3 then
            -- Mixed mode: weighted random across all four providers.
            -- Ollama is free/local so gets the largest share.
            local rand = math.random(100)
            if rand <= 40 then
                return "Ollama"   -- 40% chance
            elseif rand <= 65 then
                return "ChatGPT"  -- 25% chance
            elseif rand <= 75 then
                return "Gemini"   -- 10% chance
            else
                return "DeepSeek" -- 25% chance
            end
        else
            -- Directly map apiProvider values to API names
            if apiProvider == 0 then
                return "ChatGPT"
            elseif apiProvider == 1 then
                return "Gemini"
            elseif apiProvider == 2 then
                return "DeepSeek"
            elseif apiProvider == 4 then
                return "Ollama"
            else
                return "ChatGPT" -- safe fallback
            end
        end
    end)()


    local gameDiff = lib.GetConVarInt("difficulty")

    -- These are different to normal traits, as I want them to be more common and specific to the current difficulty
    -- Extreme scaling: diff 1 = never headshot/strafe, diff 5 = almost always headshot/strafe
    local HEADSHOT_CHANCES = {
        [1] = 0,    -- Very easy: NEVER headshot
        [2] = 8,    -- Easy: 8% chance
        [3] = 20,   -- Normal: 20% chance
        [4] = 40,   -- Hard: 40% chance
        [5] = 65,   -- Very hard: 65% chance - laser precision
    }
    local STRAFE_CHANCES = {
        [1] = 0,    -- Very easy: NEVER strafe, stand still like targets
        [2] = 30,   -- Easy: occasionally strafe
        [3] = 55,   -- Normal: strafe more than half the time
        [4] = 80,   -- Hard: almost always strafe
        [5] = 95,   -- Very hard: nearly always strafing, extremely hard to hit
    }
    self.isHeadshotter = math.random(1, 100) <= (HEADSHOT_CHANCES[gameDiff] or 20)
    self.isStrafer = math.random(1, 100) <= (STRAFE_CHANCES[gameDiff] or 55)

    -- just some shorthands
    bot.canHeadshot = self.isHeadshotter
    bot.canStrafe = self.isStrafer

    -- Extreme difficulties get more trait slots so the personality is more pronounced
    local TRAIT_COUNTS = {
        [1] = 5,  -- Very easy: 5 traits, more chances for bad traits to stack
        [2] = 4,  -- Easy: standard
        [3] = 4,  -- Normal: standard
        [4] = 4,  -- Hard: standard
        [5] = 5,  -- Very hard: 5 traits, more chances for good traits to stack
    }
    local traitCount = TRAIT_COUNTS[gameDiff] or 4
    local traits_enabled = lib.GetConVarBool("personalities")
    self.traits = (traits_enabled and self:GetNoConflictTraits(traitCount)) or
        {} -- The bot's traits. These are just keynames and not the actual trait objects.
    self.archetype = self:GetClosestArchetype()
    ---ch
    if TTTBots.Lib.GetConVarString("chatter_voice_elevenlabs_api_key") == "" then
        print("ElevenLabs API key is not set. Ignore if not using ElevenLabs TTS.")
    end

    if TTTBots.Lib.GetConVarString("chatter_voice_azure_resource_api_key") == "" then
        print("Azure TTS API key is not set. Ignore if not using Azure TTS.")
    end

    if TTTBots.Lib.GetConVarString("chatter_voice_azure_region") == "" then
        print("Azure TTS region is not set. Ignore if not using Azure TTS.")
    end

    local mode = "freetts"

    if TTTBots.Lib.GetConVarInt("chatter_voice_tts_provider") == 0 then
        mode = "freetts only"
    elseif TTTBots.Lib.GetConVarInt("chatter_voice_tts_provider") == 1 then
        mode = "elevenlabs only"
    elseif TTTBots.Lib.GetConVarInt("chatter_voice_tts_provider") == 2 then
        mode = "microsoft only"
    elseif TTTBots.Lib.GetConVarInt("chatter_voice_tts_provider") == 3 then
        mode = "mixed"
    elseif TTTBots.Lib.GetConVarInt("chatter_voice_tts_provider") == 4 then
        mode = "local only"
    end

    local FreeTTSChance = TTTBots.Lib.GetConVarFloat("chatter_voice_free_tts_chance") / 100
    local MicrosoftTTSChance = TTTBots.Lib.GetConVarFloat("chatter_voice_microsoft_tts_chance") / 100
    local ElevenLabsChance = TTTBots.Lib.GetConVarFloat("chatter_voice_elevenlabs_tts_chance") / 100
    local LocalTTSChance = TTTBots.Lib.GetConVarFloat("chatter_voice_local_tts_chance") / 100

    local ElevenlabsNameOverride = TTTBots.Lib.GetConVarBool("chatter_voice_good_tts_custom_name_override")
    local done = false

    if ElevenlabsNameOverride and TTTBots.Lib.GetConVarString("chatter_voice_elevenlabs_api_key") ~= "" then
        local customNames = lib.GetConVarString("names_custom")
        if customNames and customNames ~= "" then
            local namesList = {}
            for name in string.gmatch(customNames, '([^,]+)') do
                table.insert(namesList, name:match("^%s*(.-)%s*$"):lower()) -- trim spaces and convert to lowercase
            end
            if table.HasValue(namesList, bot:Nick():lower()) then
                decideOnVoiceElevenLabs(self, bot)
                done = true
            end
        end
    end

    if not done then
        if mode == "freetts only" then
            decideOnVoiceBadTTS(self)
        elseif mode == "elevenlabs only" then
            decideOnVoiceElevenLabs(self, bot)
        elseif mode == "microsoft only" then
            decideOnVoiceMicrosoftTTS(self)
        elseif mode == "local only" then
            decideOnVoiceLocal(self)
        elseif mode == "mixed" then
            local rand = math.random()
            if rand < LocalTTSChance then
                decideOnVoiceLocal(self)
            elseif rand < LocalTTSChance + ElevenLabsChance then
                decideOnVoiceElevenLabs(self, bot)
            elseif rand < LocalTTSChance + ElevenLabsChance + MicrosoftTTSChance then
                decideOnVoiceMicrosoftTTS(self)
            else
                decideOnVoiceBadTTS(self)
            end
        end
    end

    --- How angry the bot is, from 1-100. Adds onto pressure. At 100% rage, the bot will leave voluntary (if enabled).
    self.rage = 0
    --- How pressured the bot is feeling (effects aim) from 1-100.
    self.pressure = 0
    --- How bored the bot is. Affects how long until they voluntarily leave the server (and get replaced)
    self.boredom = 0

    -- -----------------------------------------------------------------------
    -- Mutable mood modifiers (float on top of the immutable base traits)
    -- Values range from -1 to 1; 0 = no shift from baseline.
    -- -----------------------------------------------------------------------
    self.mood = {
        confidence    = 0,  -- +1 = more confident in accusations / engaging fights
        groupAffinity = 0,  -- +1 = strongly prefers staying near others
        calloutTrust  = 0,  -- -1 = very sceptical of KOS callouts by others
    }

    self.bot = bot
end

function BotPersonality:IsStrafer() return self.isStrafer or false end

function BotPersonality:IsHeadshotter() return self.isHeadshotter or false end

function BotPersonality:GetStatRateFor(name)
    return self[name .. "Rate"] or 1
end

function BotPersonality:GetClosestArchetype()
    local traitData = self:GetTraitData()
    local archetypes = {}
    for i, trait in pairs(traitData) do
        if trait.archetype then
            archetypes[trait.archetype] = (archetypes[trait.archetype] or 0) + 1
        end
    end
    local sortedArchetypes = {}
    for archetype, count in pairs(archetypes) do
        table.insert(sortedArchetypes, { archetype = archetype, count = count })
    end
    table.sort(sortedArchetypes, function(a, b) return a.count > b.count end)
    if sortedArchetypes[1] then
        return sortedArchetypes[1].archetype
    else
        return "default"
    end
end

--- flavors text based on gender pronouns (self.HIM, .HIS, .HE)
function BotPersonality:FlavorText(text)
    local str, _int = string.gsub(text, "%[HIM%]", self.HIM):gsub("%[HIS%]", self.HIS):gsub("%[HE%]", self.HE)
    return str
end

--- Return the bot's list of traits. These are just keynames and not the actual trait objects.
function BotPersonality:GetTraits()
    return self.traits
end

--- Returns a table of trait data, which is a table of actual trait objects, instead of the keys themselves (like GetTraits())
function BotPersonality:GetTraitData()
    if self.traitData then return self.traitData end
    self.traitData = {}
    for _, trait in ipairs(self.traits) do
        table.insert(self.traitData, BotPersonality.Traits[trait])
    end
    return self.traitData
end

--- Returns a table of strings that are the flavored trait descriptions. Basically human-readable explanations of each trait.
function BotPersonality:GetFlavoredTraits()
    local traits = {}
    for i, trait in ipairs(self.traits) do
        -- --- print(self:FlavorText(self.Traits[trait].description))
        table.insert(traits, self:FlavorText(self.Traits[trait].description))
    end
    return traits
end

function BotPersonality:PrintFlavoredTraits()
    for _, trait in ipairs(self:GetFlavoredTraits()) do
        --- print(trait)
    end
end

local DECAY_BOREDOM = -0.0005 -- at 100% rate, with no interruptions, this is about 2000 secs (32 mins) to reach 1 from 0
local DECAY_PRESSURE = 0.025  -- at 100% rate, with no interruptions, this is about 40 secs to reach 0 from 1
local DECAY_RAGE = 0.002      -- at 100% rate, with no interruptions, this is about 500 secs (8 mins) to reach 0 from 1

local BOREDOM_ENABLED = 1
local PRESSURE_ENABLED = 1
local RAGE_ENABLED = 1

local function clamp(n, min, max)
    return math.min(math.max(n, min), max)
end

--- decrement the value n by decayAmt, while saying within [0,1]
local function decayN(n, decayAmt)
    return clamp((n or 0) - decayAmt, 0, 1)
end
--- Returns the bot's rage, if enabled, else 0.
function BotPersonality:GetRage() return RAGE_ENABLED and self.rage or 0 end

--- Returns the bot's pressure, if enabled, else 0.
function BotPersonality:GetPressure() return PRESSURE_ENABLED and self.pressure or 0 end

--- Returns the bot's boredom, if enabled, else 0.
function BotPersonality:GetBoredom() return BOREDOM_ENABLED and self.boredom or 0 end

--- Returns a chat frequency multiplier (0.5 – 2.0) for casual/idle events,
--- driven by the bot's current mood stats and talkative/silent traits.
---
--- • High boredom  → more likely to start casual chatter (up to ×2.0)
--- • High pressure → suppresses casual chatter (down to ×0.3)
--- • High rage     → suppresses casual chatter slightly (down to ×0.6)
--- • talkative trait → base boost ×1.5
--- • silent trait    → base suppression ×0.0 (returns 0 immediately)
---
---@return number multiplier in range [0.0, 2.0]
function BotPersonality:GetChatMoodMultiplier()
    -- Hard stop for silent bots
    if self:HasTrait("silent") then return 0.0 end

    local boredom  = self:GetBoredom()   -- 0-1
    local pressure = self:GetPressure()  -- 0-1
    local rage     = self:GetRage()      -- 0-1

    -- Base: boredom boosts casual chat linearly 1.0 → 2.0
    local mult = 1.0 + boredom

    -- Pressure and rage suppress it
    mult = mult * (1.0 - pressure * 0.7)
    mult = mult * (1.0 - rage     * 0.4)

    -- Trait bonuses / penalties
    if self:HasTrait("talkative") then mult = mult * 1.5 end
    if self:HasTrait("veryTalkative") then mult = mult * 2.0 end  -- future-proof
    if self:HasTrait("quiet")     then mult = mult * 0.5 end

    return math.max(0.0, math.min(2.0, mult))
end

--- Increment the given statistic and return the new value.
---@param x number
---@return number
function BotPersonality:AddRage(x)
    local modifier = self:GetStatRateFor("rage") * (lib.GetConVarFloat("rage_rate") / 100)
    modifier = math.max(0.05, modifier)
    self.rage = clamp(self.rage + (x * modifier), 0, 1)

    return self.rage
end

--- Increment the given statistic and return the new value.
---@param x number
---@return number
function BotPersonality:AddPressure(x)
    local modifier = self:GetStatRateFor("pressure") * (lib.GetConVarFloat("pressure_rate") / 100)
    self.pressure = clamp(self.pressure + (x * modifier), 0, 1)

    return self.pressure
end

-- -------------------------------------------------------------------------
-- Mood shift helpers (personality evolution)
-- -------------------------------------------------------------------------

--- Shift a mutable mood modifier by delta, clamped to [-1, 1].
---@param key string  "confidence" | "groupAffinity" | "calloutTrust"
---@param delta number
function BotPersonality:ShiftMood(key, delta)
    if not self.mood then self.mood = { confidence = 0, groupAffinity = 0, calloutTrust = 0 } end
    self.mood[key] = clamp((self.mood[key] or 0) + delta, -1, 1)
end

--- Returns the current value of a mood key (0 if not found).
---@param key string
---@return number
function BotPersonality:GetMood(key)
    if not self.mood then return 0 end
    return self.mood[key] or 0
end

--- Returns an effective aggression multiplier combining base traits and current mood.
--- Used by behaviors and morality when deciding whether to engage.
---@return number
function BotPersonality:GetEffectiveAggressionMult()
    local base       = self:GetTraitMult("aggressiveness") or 1.0
    local confidence = self:GetMood("confidence")
    -- confidence shifts aggression by up to ±40 %
    return clamp(base * (1.0 + confidence * 0.4), 0.2, 3.0)
end

local pressureEvents = { --- The amount that is added to our pressure when an event (the keys) happens.
    KillEnemy = -0.3,    --- When we kill an enemy
    Hurt = 0.1,          --- When we are hurt
    HurtEnemy = -0.1,    --- When we hurt an enemy
    HearGunshot = 0.02,  --- Upon hearing gunshots
    HearDeath = 0.1,     --- Upon hearing a death
    HearExplosion = 0.2, --- Upon hearing an explosion
    BulletClose = 0.05,  --- Player's bullet flies past our character
    NewTarget = 0.15,    --- Target changes to a new opponent
}
function BotPersonality:OnPressureEvent(event_name)
    local pressure = pressureEvents[event_name]
    if pressure then
        -- Killer roles (any team not TEAM_NONE/TEAM_INNOCENT) gain less
        -- positive pressure (they stay calm under fire) but still benefit
        -- fully from negative pressure events (kills, hurting enemies).
        if pressure > 0 and self.bot and IsValid(self.bot) and self.bot.GetTeam then
            local team = self.bot:GetTeam()
            if team ~= TEAM_NONE and team ~= TEAM_INNOCENT then
                pressure = pressure * 0.6 -- 40% less pressure gain for killer roles
            end
        end
        self:AddPressure(pressure)
    end

    -- Pressure-driven personality shift: high pressure makes cautious bots temporarily
    -- more aggressive (fight-or-flight response).
    if TTTBots.Lib.GetConVarBool("personality_evolution") then
        local currentPressure = self:GetPressure()
        if currentPressure > 0.65 then
            local isCautious = self:HasTrait("cautious")
            if isCautious then
                -- Temporarily boost confidence so they engage rather than flee
                self:ShiftMood("confidence", 0.05)
            end
        end
    end
end

--- Increment the given statistic and return the new value.
---@param x number
---@return number
function BotPersonality:AddBoredom(x)
    local modifier = self:GetStatRateFor("boredom") * (lib.GetConVarFloat("boredom_rate") / 100)
    modifier = math.max(0.05, modifier)
    self.boredom = clamp(self.boredom + (x * modifier), 0, 1)

    return self.boredom
end

--- Decay boredom, pressure, and rage.
function BotPersonality:DecayStats()
    local stats = {
        { name = "boredom",  decay = DECAY_BOREDOM,  addfunc = self.AddBoredom,  enabled = BOREDOM_ENABLED },
        { name = "pressure", decay = DECAY_PRESSURE, addfunc = self.AddPressure, enabled = PRESSURE_ENABLED },
        { name = "rage",     decay = DECAY_RAGE,     addfunc = self.AddRage,     enabled = RAGE_ENABLED },
    }

    for _, stat in ipairs(stats) do
        if not stat.enabled then continue end
        if stat.decay ~= 0 then
            local amt = (-stat.decay / TTTBots.Tickrate) * (self:GetStatRateFor(stat.name))
            stat.addfunc(self, amt) -- stats are not affected by personality traits
        end
    end
end

local DISCONNECT_BOREDOM_THRESHOLD = 0.95
local DISCONNECT_RAGE_THRESHOLD = 0.98
function BotPersonality:DisconnectIfDesired()
    local roundActive = TTTBots.Match.RoundActive
    local isAlive = TTTBots.Lib.IsPlayerAlive(self.bot)
    if (roundActive or not isAlive) then return false end -- don't dc during a round, that's rude!
    if self.disconnecting then return true end
    local cvar = lib.GetConVarBool("allow_leaving")
    if not cvar then return end -- module is disabled
    if self:GetBoredom() >= DISCONNECT_BOREDOM_THRESHOLD then
        self.disconnecting = TTTBots.Lib.VoluntaryDisconnect(self.bot, "Boredom")
    elseif self:GetRage() >= DISCONNECT_RAGE_THRESHOLD then
        self.disconnecting = TTTBots.Lib.VoluntaryDisconnect(self.bot, "Rage")
    end
end

function BotPersonality:Think()
    if not (self.rageRate and self.pressureRate and self.boredomRate) then
        self.rageRate = (self:GetTraitMult("rageRate") or 1)         --- The multiplier of the given stat based off the bot's personality. Applies to increases and decreases
        self.pressureRate = (self:GetTraitMult("pressureRate") or 1) --- The multiplier of the given stat based off the bot's personality. Applies to increases and decreases
        self.boredomRate = (self:GetTraitMult("boredomRate") or 1)   --- The multiplier of the given stat based off the bot's personality. Applies to increases and decreases
    end

    BOREDOM_ENABLED = TTTBots.Lib.GetConVarBool("boredom")
    PRESSURE_ENABLED = TTTBots.Lib.GetConVarBool("pressure")
    RAGE_ENABLED = TTTBots.Lib.GetConVarBool("rage")

    self:DecayStats()

    self:DisconnectIfDesired()
end

--- Get a pure random trait name.
---@return string
function BotPersonality:GetRandomTrait()
    local keys = {}
    for k, _ in pairs(self.Traits) do
        table.insert(keys, k)
    end
    return keys[math.random(#keys)]
end

--- Detect if a trait conflicts with anything in the a of traits
---@param trait string
---@param traitSet table
---@return boolean
function BotPersonality:TraitHasConflict(trait, traitSet)
    for _, selectedTrait in ipairs(traitSet) do
        for _, conflict in ipairs(self.Traits[selectedTrait].conflicts) do
            if conflict == trait then
                return true
            end
        end
    end
    return false
end

--- Returns a set of num traits that are non-conflicting. Don't get too many, otherwise it'll crash or take a long time.
---@param num number
---@return table
function BotPersonality:GetNoConflictTraits(num)
    local selectedTraits = {}
    local traitorTraits = 0

    local DIFFICULTY_RANGES = TTTBots.Lib.DIFFICULTY_RANGES
    local GAME_DIFFICULTY = TTTBots.Lib.GetConVarInt("difficulty")
    local EXPECTED_DIFF = DIFFICULTY_RANGES[GAME_DIFFICULTY]
    local TOLERANCE = TTTBots.Lib.DIFFICULTY_TOLERANCE

    local DIFF_MIN = EXPECTED_DIFF - TOLERANCE
    local DIFF_MAX = EXPECTED_DIFF + TOLERANCE

    local difficultySoFar = 0

    while #selectedTraits < num do
        local trait = self:GetRandomTrait()
        local tryCount = 0

        while (self:TraitHasConflict(trait, selectedTraits) or table.HasValue(selectedTraits, trait) or difficultySoFar + (self.Traits[trait].effects.difficulty or 0) > DIFF_MAX) and tryCount < 10 do
            trait = self:GetRandomTrait()
            tryCount = tryCount + 1
        end

        if tryCount < 10 then
            local traitDiff = (self.Traits[trait].effects.difficulty or 0)
            -- Check if adding this trait keeps the total difficulty within the range
            if difficultySoFar + traitDiff >= DIFF_MIN and difficultySoFar + traitDiff <= DIFF_MAX then
                if self.Traits[trait].traitor_only then
                    if traitorTraits < 1 then
                        table.insert(selectedTraits, trait)
                        traitorTraits = traitorTraits + 1
                        difficultySoFar = difficultySoFar + traitDiff
                    end
                else
                    table.insert(selectedTraits, trait)
                    difficultySoFar = difficultySoFar + traitDiff
                end
            end
        else
            break
        end
    end

    return selectedTraits
end

--- Functionally same as Player:HasTrait(trait_name)
---@param trait_name string
---@return boolean
function BotPersonality:HasTrait(trait_name)
    return self.bot:HasTrait(trait_name)
end

function BotPersonality:HasTraitIn(hashtable)
    return self.bot:HasTraitIn(hashtable)
end

function BotPersonality:GetIgnoresOrders()
    if self.bot.ignoreOrders ~= nil then return self.bot.ignoreOrders end
    -- go through each trait and check if it has "ignoreOrders" in its effects set to true
    local traits = self:GetTraitData()
    for _, trait in ipairs(traits) do
        if trait.effects and trait.effects.ignoreOrders then
            self.bot.ignoreOrders = true
            return true
        end
    end
    self.bot.ignoreOrders = false
    return false
end

---Wrapper for bot:GetTraitMult(attribute)
---@param attribute string
---@return number
function BotPersonality:GetTraitMult(attribute)
    return self.bot:GetTraitMult(attribute)
end

function BotPersonality:GetTraitAdditive(attribute)
    return self.bot:GetTraitAdditive(attribute)
end

function BotPersonality:GetDifficulty()
    return self.bot:GetDifficulty()
end

function BotPersonality:GetTraitBool(attribute, falseHasPriority)
    return self.bot:GetTraitBool(attribute, falseHasPriority)
end

---@class Player
local plyMeta = FindMetaTable("Player")

function plyMeta:GetPersonalityTraits()
    local personality = self:BotPersonality()
    return personality:GetTraits()
end

---Get the average trait multiplier for a given personality attribute. This could be hearing, fov, etc.
---@param attribute string
---@return number
function plyMeta:GetTraitMult(attribute)
    local traits = self:BotPersonality():GetTraitData()
    local total = 1
    if not traits then return total end
    for i, trait in pairs(traits) do
        local val = trait.effects and trait.effects[attribute]
        total = total * (tonumber(val) or 1)
    end
    return total
end

function plyMeta:GetTraitAdditive(attribute)
    local traits = self:BotPersonality():GetTraitData()
    local total = 0
    if not traits then return total end
    for i, trait in pairs(traits) do
        local val = trait.effects and trait.effects[attribute]
        total = total + (tonumber(val) or 0)
    end
    return total
end

--- Return a boolean for the given attribute based on the bots traits. If false has priority (defaults true), then any traits that are false will make the entire function return false.
---@param attribute string The name of the attribute to check
---@param falseHasPriority boolean|nil Defaults to true. Should we escape early if we have a trait that conflicts with this attribute (aka is false)?
function plyMeta:GetTraitBool(attribute, falseHasPriority)
    if falseHasPriority == nil then falseHasPriority = true end
    local traits = self:BotPersonality():GetTraitData()
    local total = false
    if not traits then return total end
    for i, trait in pairs(traits) do
        local val = (trait.effects and trait.effects[attribute]) or
            nil                                     -- IMPORTANT to default to nil, otherwise false will probably be returned when it shouldn't be
        if falseHasPriority and (val == false) then -- check if val is explicitly false
            return false
        else
            total = total or (val ~= nil and true)
        end
    end
    return total
end

--- Check if the bot has a specific trait, by name.
---@param trait_name string
---@return boolean hasTrait
function plyMeta:HasTrait(trait_name)
    local traits = self:BotPersonality():GetTraits()
    for _, trait in ipairs(traits) do
        if trait == trait_name then
            return true
        end
    end

    return false
end

--- Check if the bot has any traits that match the entries in the hashtable.
---@param hashtable table<string, boolean>
---@return boolean hasTrait
function plyMeta:HasTraitIn(hashtable)
    local traits = self:BotPersonality():GetTraits()
    for _, trait in ipairs(traits) do
        if hashtable[trait] then
            return true
        end
    end
    return false
end

---Get the difficulty of the bot. Returns nil if bot isn't fully initialized.
---@param self Bot
---@return number? difficulty The calculated bot difficulty
function plyMeta:GetDifficulty()
    if not self.components then return end
    if self.calcDifficulty ~= nil then return self.calcDifficulty end
    local personality = self:BotPersonality()
    if not personality then return nil end

    local diff = personality:GetTraitAdditive("difficulty")

    local strafeFactor = personality.isStrafer and 2 or 0
    local headshotFactor = personality.isHeadshotter and 3 or 0

    self.calcDifficulty = diff + strafeFactor + headshotFactor
    return diff
end

-- ON DYING
local DEATH_RAGE_BASE = 0.2    -- Increase rage on death by this amount
local DEATH_PRESSURE_BASE = -1 -- Remove pressure when dying
local DEATH_BOREDOM_BASE = 0.1 -- Increase boredom on death by this amount

-- ON KILLING ANOTHER PLAYER
local KILL_RAGE_BASE = -0.1     -- Decrease rage on kill by this amount
local KILL_PRESSURE_BASE = -0.2 -- Decrease pressure on kill by this amount
local KILL_BOREDOM_BASE = -0.1  -- Decrease boredom on kill by this amount

hook.Add("PlayerDeath", "TTTBots.Personality.PlayerDeath", function(bot, inflictor, attacker)
    if bot:IsBot() then
        local personality = bot and bot.components and bot.components.personality
        if not personality then return end
        personality:AddRage(DEATH_RAGE_BASE)
        personality:AddPressure(DEATH_PRESSURE_BASE)
        personality:AddBoredom(DEATH_BOREDOM_BASE)
    end

    if attacker and IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot() then
        local personality = attacker and attacker.components and attacker.components.personality
        if not personality then return end
        personality:AddRage(KILL_RAGE_BASE)
        personality:AddPressure(KILL_PRESSURE_BASE)
        personality:AddBoredom(KILL_BOREDOM_BASE)
    end
end)

-- -------------------------------------------------------------------------
-- Experience Adaptation (personality evolution)
-- -------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.Personality.ExperienceAdaptation", function(victim, inflictor, attacker)
    if not TTTBots.Lib.GetConVarBool("personality_evolution") then return end

    -- Record what killed the victim so mood adaptation can reference it
    if IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot() then
        -- attacker.attackSource is set by SetAttackTarget; copy it to victim
        if IsValid(victim) and victim:IsBot() then
            victim.lastDeathSource = attacker.attackSource or ""
        end
    end

    -- Momentum: killer gains confidence, victim loses confidence next-round
    if IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot() then
        local p = attacker.components and attacker.components.personality
        if p then p:ShiftMood("confidence", 0.1) end
    end
    if IsValid(victim) and victim:IsBot() then
        local p = victim.components and victim.components.personality
        if not p then return end

        -- Adapt based on how we died:
        -- Killed by a stalker → become more group-oriented next round
        local deathSource = victim.lastDeathSource or ""
        if deathSource == "STALK_ATTACK" then
            -- Store adaptation for next round
            p:ShiftMood("groupAffinity",  0.25)
        end

        -- Was this bot false-KOS'd? (accusedBy is set when KOS is called)
        if victim.accusedBy and IsValid(victim.accusedBy) then
            local accuserRole = TTTBots.Roles.GetRoleFor(victim.accusedBy)
            local accuserIsTraitor = accuserRole and accuserRole:GetTeam() == TEAM_TRAITOR
            if accuserIsTraitor then
                -- We were KOS'd by a traitor — become more sceptical of callouts
                p:ShiftMood("calloutTrust", -0.2)
            end
        end

        -- Mood modifiers decay slowly between rounds — handled in TTTEndRound below
        -- Store for cross-round persistence
        local memory = victim:BotMemory()
        if memory then
            memory:SetMemory("game", "savedMood", table.Copy(p.mood))
        end
    end
end)

-- -------------------------------------------------------------------------
-- Social feedback: wrong accusations reduce confidence
-- -------------------------------------------------------------------------

hook.Add("TTTBots.AccusePlayer", "TTTBots.Personality.SocialFeedback", function(accuser, target)
    if not TTTBots.Lib.GetConVarBool("personality_evolution") then return end
    if not (IsValid(accuser) and accuser:IsBot()) then return end

    -- We record pending accusations; validate them at round end
    accuser.pendingAccusations = accuser.pendingAccusations or {}
    table.insert(accuser.pendingAccusations, { target = target, time = CurTime() })
end)

hook.Add("TTTEndRound", "TTTBots.Personality.AccuracyFeedback", function(result)
    if not TTTBots.Lib.GetConVarBool("personality_evolution") then return end
    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local p = bot.components.personality
        if not p then continue end

        local accusations = bot.pendingAccusations or {}
        local correct, wrong = 0, 0
        for _, acc in ipairs(accusations) do
            if not IsValid(acc.target) then continue end
            local targetRole = TTTBots.Roles.GetRoleFor(acc.target)
            local wasTraitor  = targetRole and targetRole:GetTeam() == TEAM_TRAITOR
            if wasTraitor then correct = correct + 1 else wrong = wrong + 1 end
        end

        -- Shift confidence based on accuracy
        if wrong > correct and wrong > 1 then
            p:ShiftMood("confidence", -0.15)  -- consistently wrong → less confident
        elseif correct > 0 then
            p:ShiftMood("confidence",  0.10)  -- right accusations → confidence boost
        end

        bot.pendingAccusations = nil

        -- Decay mood modifiers toward 0 between rounds (partial reversion)
        if p.mood then
            for k, v in pairs(p.mood) do
                p.mood[k] = v * 0.6  -- 40% decay each round
            end
        end

        -- Cross-round memory: restore saved mood
        if TTTBots.Lib.GetConVarBool("crossround_memory") then
            local memory = bot:BotMemory()
            if memory then
                local savedMood = memory:GetMemory("game", "savedMood", nil)
                if savedMood then
                    for k, v in pairs(savedMood) do
                        p.mood[k] = (p.mood[k] or 0) + v * 0.3  -- 30% bleed-over
                    end
                    memory:SetMemory("game", "savedMood", nil)
                end
            end
        end
    end
end)

local LOSE_RAGE_BASE = 0.1         -- Increase rage by this amount when losing a round
local LOSE_PRESSURE_BASE = 0.1     -- Increase pressure by this amount when losing a round
local LOSE_BOREDOM_BASE = 0.05     -- Increase boredom by this amount when losing a round
local SURVIVAL_LOSE_MODIFIER = 0.5 -- Multiply the above values by this amount if the bot survives the round

local WIN_RAGE_BASE = -0.3         -- Decrease rage by this amount when winning a round
local WIN_PRESSURE_BASE = -1       -- Decrease pressure by this amount when winning a round
local WIN_BOREDOM_BASE = -0.05     -- Decrease boredom by this amount when winning a round
local SURVIVAL_WIN_MODIFIER = 2    -- Multiply the above values by this amount if the bot survives the round

local function updateBotAttributes(winTeam)
    for i, bot in pairs(TTTBots.Bots) do
        local personality = bot and bot.components and bot.components.personality
        if not personality then continue end
        local botTeam = bot:GetTeam()
        local botSurvived = lib.IsPlayerAlive(bot)
        local botWon = (winTeam == botTeam)

        if botWon then
            personality:AddRage(WIN_RAGE_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
            personality:AddPressure(WIN_PRESSURE_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
            personality:AddBoredom(WIN_BOREDOM_BASE * (botSurvived and SURVIVAL_WIN_MODIFIER or 1))
        else
            personality:AddRage(LOSE_RAGE_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
            personality:AddPressure(LOSE_PRESSURE_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
            personality:AddBoredom(LOSE_BOREDOM_BASE * (botSurvived and SURVIVAL_LOSE_MODIFIER or 1))
        end
    end
end

hook.Add("TTTEndRound", "TTTBots.Personality.EndRound", function(result)
    -- result is usually a string like "innocents" or "traitors", which is = to TEAM_INNOCENT and TEAM_TRAITOR
    updateBotAttributes(result)
end)

-- -------------------------------------------------------------------------
-- Cross-round memory: record who was a traitor for "metagame" awareness
-- -------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.Personality.CrossRoundMemory", function(result)
    if not TTTBots.Lib.GetConVarBool("crossround_memory") then return end

    -- Build a list of confirmed-traitor steam IDs from this round
    local traitorList = {}
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local roleData = TTTBots.Roles.GetRoleFor(ply)
        if roleData and roleData:GetTeam() == TEAM_TRAITOR then
            traitorList[ply:SteamID()] = true
        end
    end

    -- Store in each bot's "game" memory
    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local memory = bot:BotMemory()
        if not memory then continue end
        local history = memory:GetMemory("game", "recentTraitors", {})
        -- Rotate: keep last 3 rounds
        table.insert(history, 1, traitorList)
        while #history > 3 do table.remove(history) end
        memory:SetMemory("game", "recentTraitors", history)
    end
end)

--- Returns true if the given player was a traitor in any of the last N rounds
--- according to this bot's cross-round memory. Only meaningful when
--- tttbots_crossround_memory is enabled.
---@param bot Bot
---@param ply Player
---@return boolean
function BotPersonality:WasRecentTraitor(ply)
    if not TTTBots.Lib.GetConVarBool("crossround_memory") then return false end
    if not IsValid(ply) then return false end
    local memory = self.bot:BotMemory()
    if not memory then return false end
    local history = memory:GetMemory("game", "recentTraitors", {})
    local sid = ply:SteamID()
    for _, roundList in ipairs(history) do
        if roundList[sid] then return true end
    end
    return false
end
local RDM_BOREDOM_MIN = 0.7
local RDM_RAGE_MIN = 0.7
local RDM_PCT_CHANCE = 20 -- 10% chance to rdm every 2.5 seconds if criteria are met
timer.Create("TTTBots.Personality.RDM", 2.5, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not lib.GetConVarBool("rdm") then return end
    for i, bot in pairs(TTTBots.Bots) do
        ---@cast bot Bot
        if not lib.IsPlayerAlive(bot) then continue end -- skip if bot not loaded
        local personality = bot:BotPersonality()
        if not personality then continue end            -- skip if bot not loaded
        if bot.attackTarget ~= nil then continue end    -- no rdm if we're already attacking someone

        local boredom = personality:GetBoredom()
        local rage = personality:GetRage()
        local isRdmer = personality:GetTraitBool("rdmer")
        local chanceTest = math.random(1, 100) <= RDM_PCT_CHANCE

        if chanceTest and (isRdmer or (boredom > RDM_BOREDOM_MIN) or (rage > RDM_RAGE_MIN)) then
            local targets = lib.GetAllWitnessesBasic(bot:GetPos(), TTTBots.Match.AlivePlayers, bot)
            local grudge = (IsValid(bot.grudge) and lib.IsPlayerAlive(bot.grudge) and bot.grudge)
            local randomTarget = grudge or table.Random(targets)
            if targets and #targets > 0 then
                bot:SetAttackTarget(randomTarget, "RDM_RAGE", 1)
            end
        end
    end
end)

---@return CPersonality
function plyMeta:BotPersonality()
    ---@cast self Bot
    return self.components and self.components.personality or nil
end
