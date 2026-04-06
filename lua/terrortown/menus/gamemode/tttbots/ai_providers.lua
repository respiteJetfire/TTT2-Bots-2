--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 70
CLGAMEMODESUBMENU.title = "submenu_tttbots_ai_providers_title"

function CLGAMEMODESUBMENU:Populate(parent)
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_ai_provider")

    form:MakeCheckBox({
        serverConvar = "ttt_bot_llm_enabled",
        label = "label_tttbots_llm_enabled",
    })

    form:MakeHelp({
        label = "help_tttbots_llm_enabled",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_precache_llm",
        label = "label_tttbots_chatter_precache_llm",
    })

    form:MakeHelp({
        label = "help_tttbots_chatter_precache_llm",
    })

    form:MakeComboBox({
        serverConvar = "ttt_bot_chatter_api_provider",
        label = "label_tttbots_chatter_api_provider",
        choices = {
            { title = "ChatGPT",               value = "0" },
            { title = "Google Gemini",          value = "1" },
            { title = "Deepseek",               value = "2" },
            { title = "All (Random Per Bot)",   value = "3" },
            { title = "Local Ollama (ttsapi)",  value = "4" },
            { title = "OpenRouter",             value = "5" },
        },
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_local_api_enabled",
        label = "label_tttbots_chatter_local_api_enabled",
    })

    -- Model names
    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_ai_models")

    form2:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_gpt_model",
        label = "label_tttbots_chatter_gpt_model",
    })

    form2:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_gemini_model",
        label = "label_tttbots_chatter_gemini_model",
    })

    form2:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_deepseek_model",
        label = "label_tttbots_chatter_deepseek_model",
    })

    -- Ollama
    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_ai_ollama")

    form3:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_ollama_model",
        label = "label_tttbots_chatter_ollama_model",
    })

    form3:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_ollama_url",
        label = "label_tttbots_chatter_ollama_url",
    })

    -- OpenRouter
    local form4 = vgui.CreateTTT2Form(parent, "header_tttbots_ai_openrouter")

    form4:MakeHelp({
        label = "help_tttbots_ai_openrouter",
    })

    -- Preset picker — selecting a preset writes the model slug to the cvar.
    -- The TextEntry below is bound to the same cvar so it stays in sync and
    -- also allows fully custom model slugs to be typed manually.
    form4:MakeComboBox({
        serverConvar = "ttt_bot_chatter_openrouter_model",
        label = "label_tttbots_chatter_openrouter_model_preset",
        choices = {
            -- Free tier
            { title = "[Free] Arcee Trinity Large Preview (default)",    value = "arcee-ai/trinity-large-preview:free" },
            { title = "[Free] Llama Nemotron Embed VL 1B v2",             value = "nvidia/llama-nemotron-embed-vl-1b-v2:free" },
            { title = "[Free] Nvidia Nemotron 3 Nano 30B",                value = "nvidia/nemotron-3-nano-30b-a3b:free" },
            { title = "[Free] OpenAI GPT-OSS 120B",                       value = "openai/gpt-oss-120b:free" },
            { title = "[Free] StepFun Step 3.5 Flash",                    value = "stepfun/step-3.5-flash:free" },
            -- Cheap tier
            { title = "[Cheap] Qwen3 235B A22B 2507",                     value = "qwen/qwen3-235b-a22b-2507" },
            { title = "[Cheap] Google Gemini 2.5 Flash Lite",             value = "google/gemini-2.5-flash-lite" },
            { title = "[Cheap] Nvidia Nemotron Nano 9B v2",               value = "nvidia/nemotron-nano-9b-v2" },
            { title = "[Cheap] Mistral Small 24B 2501",                   value = "mistralai/mistral-small-24b-instruct-2501" },
            { title = "[Cheap] OpenAI GPT-5 Nano",                        value = "openai/gpt-5-nano" },
            { title = "[Cheap] OpenAI GPT-5 Mini",                        value = "openai/gpt-5-mini" },
            -- Medium tier
            { title = "[Medium] Sourceful Riverflow v2 Fast",             value = "sourceful/riverflow-v2-fast" },
            { title = "[Medium] xAI Grok 4.1 Fast",                      value = "x-ai/grok-4.1-fast" },
            { title = "[Medium] Google Gemini 3 Flash Preview",           value = "google/gemini-3-flash-preview" },
            { title = "[Medium] DeepSeek v3.2",                           value = "deepseek/deepseek-v3.2" },
            { title = "[Medium] MiniMax M2.5",                            value = "minimax/minimax-m2.5" },
            { title = "[Medium] OpenAI GPT-4o Mini",                      value = "openai/gpt-4o-mini" },
            -- Expensive tier
            { title = "[Premium] OpenAI GPT-5.2",                         value = "openai/gpt-5.2" },
            { title = "[Premium] Anthropic Claude Haiku 4.5",             value = "anthropic/claude-haiku-4.5" },
            { title = "[Premium] Anthropic Claude Sonnet 4.6",            value = "anthropic/claude-sonnet-4.6" },
            -- Custom
            { title = "[Custom] Type model slug below",                   value = "" },
        },
    })

    form4:MakeHelp({
        label = "help_tttbots_openrouter_model_custom",
    })

    form4:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_openrouter_model",
        label = "label_tttbots_chatter_openrouter_model",
    })

    form4:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_openrouter_site_url",
        label = "label_tttbots_chatter_openrouter_site_url",
    })

    form4:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_openrouter_site_name",
        label = "label_tttbots_chatter_openrouter_site_name",
    })

    -- API Keys (server-only)
    local form5 = vgui.CreateTTT2Form(parent, "header_tttbots_ai_keys")

    form5:MakeHelp({
        label = "help_tttbots_ai_keys",
    })

    form5:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_chatgpt_api_key",
        label = "label_tttbots_chatter_chatgpt_api_key",
    })

    form5:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_gemini_api_key",
        label = "label_tttbots_chatter_gemini_api_key",
    })

    form5:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_deepseek_api_key",
        label = "label_tttbots_chatter_deepseek_api_key",
    })

    form5:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_openrouter_api_key",
        label = "label_tttbots_chatter_openrouter_api_key",
    })
end
