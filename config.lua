Config = {}

-- Idioma: 'es' | 'en'
Config.Locale = 'es'

--[[
    ---------------------------------------------------------------------------
    FRAMEWORK
    ---------------------------------------------------------------------------
    'auto'       → detecta en este orden: qbx_core → qb-core → es_extended → ox_core → standalone

    'qb'         → qb-core  (QBCore clásico, permisos con Config.AdminGroups)
    'qbox'       → qbx_core (Qbox; staff = ACE group.<grupo> o HasPermission de Qbox)
    'qbx'        → alias de 'qbox'

    'esx'        → es_extended (staff = grupo getGroup() o job en Config.AdminGroups)

    'standalone' → sin qb/esx, también ox_core (identidad por license; staff = ACE y/o lista abajo)
    ---------------------------------------------------------------------------
]]
Config.Framework = 'auto'

-- Comandos
Config.CommandPlayer = 'report'
Config.CommandAdmin = 'reportes'

-- Llamadas de voz (pma-voice; si no existe, se ignora).
-- Cada llamada usa un canal aleatorio entre VoiceChannelBase y VoiceChannelBase + 1999.
Config.VoiceChannelBase = 8000

-- Staff: en qb = permisos de QBCore | en qbox = ACE group.<nombre> | en esx = nombre de grupo o de job
Config.AdminGroups = {
    'mod',
    'admin',
    'god',
}

-- Solo en modo standalone / ox_core
Config.StandaloneAce = 'jgr_reports.admin'
Config.StandaloneAdminLicenses = {
    -- 'license:xxxxxxxx',
}

Config.AutoCloseOfflineMinutes = 10
Config.StatusCheckIntervalMs = 60000
