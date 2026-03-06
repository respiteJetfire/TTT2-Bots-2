--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 70
CLGAMEMODESUBMENU.title = "submenu_tttbots_ai_providers_title"

function CLGAMEMODESUBMENU:Populate(parent)
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_ai_provider")

    form:MakeComboBox({
        serverConvar = "ttt_bot_chatter_api_provider",
        label = "label_tttbots_chatter_api_provider",
        choices = {
            { title = "ChatGPT",               value = "0" },
            { title = "Google Gemini",          value = "1" },
            { title = "Deepseek",               value = "2" },
            { title = "All (Random Per Bot)",   value = "3" },
            { title = "Local Ollama (ttsapi)",  value = "4" },
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

    -- API Keys (server-only)
    local form4 = vgui.CreateTTT2Form(parent, "header_tttbots_ai_keys")

    form4:MakeHelp({
        label = "help_tttbots_ai_keys",
    })

    form4:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_chatgpt_api_key",
        label = "label_tttbots_chatter_chatgpt_api_key",
    })

    form4:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_gemini_api_key",
        label = "label_tttbots_chatter_gemini_api_key",
    })

    form4:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_deepseek_api_key",
        label = "label_tttbots_chatter_deepseek_api_key",
    })
end
