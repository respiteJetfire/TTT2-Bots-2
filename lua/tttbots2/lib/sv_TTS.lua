--- sv_TTS.lua — BINARY TTS dispatch
---
--- NOTE: The real implementation lives in the standalone `ttt2-tts` addon.
--- That addon installs `TTTBots.TTS.SendVoice` (and the per-backend helpers)
--- at load time, so leaving this file nearly empty is intentional and keeps
--- the old `include(...)` in sh_tttbots2.lua valid.
---
--- If the ttt2-tts addon is missing, the call-sites in sv_providers.lua will
--- gracefully error via the MakeError envelope.

TTTBots        = TTTBots        or {}
TTTBots.TTS    = TTTBots.TTS    or {}
TTTBots.TTS.Cache = TTTBots.TTS.Cache or {}

-- Fallback stub: if ttt2-tts hasn't loaded yet, surface a clear error instead
-- of a nil-call crash. ttt2-tts will overwrite this when it loads.
if not TTTBots.TTS.SendVoice then
    function TTTBots.TTS.SendVoice(_, _, _, cb)
        print("[TTTBots.TTS] ttt2-tts addon not loaded — install it to enable TTS.")
        if cb and TTTBots.Providers and TTTBots.Providers.MakeError then
            cb(TTTBots.Providers.MakeError("TTS", 0, "ttt2-tts addon missing", nil))
        end
    end
end
