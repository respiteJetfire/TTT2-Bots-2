--- sv_TTS_url.lua — URL-mode TTS dispatch
---
--- Real implementation lives in the standalone `ttt2-tts` addon. See
--- sv_TTS.lua for details.

TTTBots          = TTTBots          or {}
TTTBots.TTSURL   = TTTBots.TTSURL   or {}
TTTBots.TTSURL.Cache = TTTBots.TTSURL.Cache or {}

if not TTTBots.TTSURL.SendVoice then
    function TTTBots.TTSURL.SendVoice(_, _, _, cb)
        print("[TTTBots.TTSURL] ttt2-tts addon not loaded — install it to enable TTS.")
        if cb and TTTBots.Providers and TTTBots.Providers.MakeError then
            cb(TTTBots.Providers.MakeError("TTSURL", 0, "ttt2-tts addon missing", nil))
        end
    end
end
