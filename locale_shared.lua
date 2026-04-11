--- Translation helper (shared: client + server).
--- Config.Locale must be set in config.lua before this file loads.

function JGRReportsT(key, ...)
    local lang = (Config and Config.Locale) or 'es'
    local pack = JGRReportsLocales[lang] or JGRReportsLocales['en']
    local fallback = JGRReportsLocales['en'] or {}
    if type(pack) ~= 'table' then pack = fallback end
    local template = pack[key] or fallback[key] or key
    if select('#', ...) > 0 then
        return string.format(template, ...)
    end
    return template
end

--- Flat table for NUI (same keys as locale files).
function JGRReportsGetNuiLocale()
    local lang = (Config and Config.Locale) or 'es'
    return JGRReportsLocales[lang] or JGRReportsLocales['en'] or {}
end
