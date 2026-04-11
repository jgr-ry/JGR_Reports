Config = {}

-- Idioma: 'es' | 'en'
Config.Locale = 'es'

--[[
    ---------------------------------------------------------------------------
    FRAMEWORK 
    ---------------------------------------------------------------------------
    Pon UNA de estas cadenas (minúsculas recomendado):

    'qb'         → qb-core  (QBCore clásico, permisos con Config.AdminGroups)
    'qbox'       → qbx_core (Qbox; misma API que QB)
    'qbx'        → alias de 'qbox'

    'esx'        → es_extended (staff = grupo getGroup() o job en Config.AdminGroups)

    'standalone' → sin qb/esx (identidad por license; staff = ACE y/o lista abajo)
    ---------------------------------------------------------------------------
]]
Config.Framework = 'qb'

-- Comandos
Config.CommandPlayer = 'report'
Config.CommandAdmin = 'reportes'

-- Llamadas de voz (pma-voice; si no existe, se ignora)
Config.VoiceChannelBase = 8000

-- Staff: en qb/qbox = permisos ACE de QBCore | en esx = nombre de grupo o de job
Config.AdminGroups = {
    'mod',
    'admin',
    'god',
}

-- Solo si Config.Framework = 'standalone'
Config.StandaloneAce = 'jgr_reports.admin'
Config.StandaloneAdminLicenses = {
    -- 'license:xxxxxxxx',
}

Config.AutoCloseOfflineMinutes = 10
Config.StatusCheckIntervalMs = 60000
