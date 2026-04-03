--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 60
CLGAMEMODESUBMENU.title = "submenu_tttbots_voice_title"

function CLGAMEMODESUBMENU:Populate(parent)
    -- General voice settings
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_voice_general")

    local enbTTS = form:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_enable_tts",
        label = "label_tttbots_chatter_enable_tts",
    })

    form:MakeHelp({
        label = "help_tttbots_chatter_proximity",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_proximity",
        label = "label_tttbots_chatter_proximity",
    })

    local enbVoice = form:MakeSlider({
        serverConvar = "ttt_bot_chatter_voice_chance",
        label = "label_tttbots_chatter_voice_chance",
        min = 0,
        max = 100,
        decimal = 0,
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_voice_force_reply_player",
        label = "label_tttbots_chatter_voice_force_reply_player",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_voice_url_mode",
        label = "label_tttbots_chatter_voice_url_mode",
    })

    -- TTS Provider
    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_voice_provider")

    form2:MakeHelp({
        label = "help_tttbots_voice_provider",
    })

    form2:MakeComboBox({
        serverConvar = "ttt_bot_chatter_voice_tts_provider",
        label = "label_tttbots_chatter_voice_tts_provider",
        choices = {
            { title = "Free TTS Only",          value = "0" },
            { title = "ElevenLabs Only",         value = "1" },
            { title = "Azure TTS Only",          value = "2" },
            { title = "Mixed",                   value = "3" },
            { title = "Local Piper TTS (ttsapi)", value = "4" },
        },
    })

    -- Mixed mode chance sliders
    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_voice_mixed")

    form3:MakeSlider({
        serverConvar = "ttt_bot_chatter_voice_free_tts_chance",
        label = "label_tttbots_chatter_voice_free_tts_chance",
        min = 0,
        max = 100,
        decimal = 0,
    })

    form3:MakeSlider({
        serverConvar = "ttt_bot_chatter_voice_microsoft_tts_chance",
        label = "label_tttbots_chatter_voice_microsoft_tts_chance",
        min = 0,
        max = 100,
        decimal = 0,
    })

    form3:MakeSlider({
        serverConvar = "ttt_bot_chatter_voice_elevenlabs_tts_chance",
        label = "label_tttbots_chatter_voice_elevenlabs_tts_chance",
        min = 0,
        max = 100,
        decimal = 0,
    })

    form3:MakeSlider({
        serverConvar = "ttt_bot_chatter_voice_local_tts_chance",
        label = "label_tttbots_chatter_voice_local_tts_chance",
        min = 0,
        max = 100,
        decimal = 0,
    })

    -- ElevenLabs
    local form4 = vgui.CreateTTT2Form(parent, "header_tttbots_voice_elevenlabs")

    form4:MakeSlider({
        serverConvar = "ttt_bot_chatter_voice_good_tts_chance",
        label = "label_tttbots_chatter_voice_good_tts_chance",
        min = 0,
        max = 100,
        decimal = 0,
    })

    form4:MakeComboBox({
        serverConvar = "ttt_bot_chatter_elevenlabs_voice_model",
        label = "label_tttbots_chatter_elevenlabs_voice_model",
        choices = {
            { title = "eleven_turbo_v2_5",      value = "0" },
            { title = "eleven_multilingual_v2",  value = "1" },
            { title = "eleven_monolingual_v1",   value = "2" },
            { title = "eleven_monolingual_v1 (alt)", value = "3" },
        },
    })

    form4:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_voice_good_tts_custom_name_override",
        label = "label_tttbots_chatter_voice_good_tts_custom_name_override",
    })

    form4:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_voice_elevenlabs_api_key",
        label = "label_tttbots_chatter_voice_elevenlabs_api_key",
    })

    -- Azure TTS
    local form5 = vgui.CreateTTT2Form(parent, "header_tttbots_voice_azure_tts")

    form5:MakeSlider({
        serverConvar = "ttt_bot_chatter_voice_azure_voice_quality",
        label = "label_tttbots_chatter_voice_azure_voice_quality",
        min = 1,
        max = 5,
        decimal = 0,
    })

    -- Speech-to-Text
    local form6 = vgui.CreateTTT2Form(parent, "header_tttbots_voice_stt")

    form6:MakeHelp({
        label = "help_tttbots_stt",
    })

    local enbSTT = form6:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_voice_stt",
        label = "label_tttbots_chatter_voice_stt",
    })

    form6:MakeComboBox({
        serverConvar = "ttt_bot_chatter_voice_stt_backend",
        label = "label_tttbots_chatter_voice_stt_backend",
        choices = {
            { title = "Local Whisper (ttsapi, no API key)", value = "whisper" },
            { title = "Azure STT",                          value = "azure"   },
        },
        master = enbSTT,
    })

    form6:MakeHelp({
        label = "help_tttbots_stt_azure",
    })

    form6:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_voice_azure_resource_api_key",
        label = "label_tttbots_chatter_voice_azure_resource_api_key",
    })

    form6:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_voice_azure_resource_name",
        label = "label_tttbots_chatter_voice_azure_resource_name",
    })

    form6:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_voice_azure_region",
        label = "label_tttbots_chatter_voice_azure_region",
    })

    -- Local Piper TTS
    local form7 = vgui.CreateTTT2Form(parent, "header_tttbots_voice_local")

    form7:MakeTextEntry({
        serverConvar = "ttt_bot_chatter_voice_local_tts_url",
        label = "label_tttbots_chatter_voice_local_tts_url",
    })
end
