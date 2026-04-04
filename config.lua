Config = {}

-- Configuración general
Config.CoreName = 'qb-core'
Config.CommandPlayer = 'report'
Config.CommandAdmin = 'reportes'

-- Sistema de Voz (pma-voice)
-- Si llamas a un jugador, se les asigna un canal de radio temporal.
-- Empezará desde este canal y sumará el ID del reporte (ej: Reporte 5 = Canal 8000 + 5)
Config.VoiceChannelBase = 8000

-- Permisos de admin
Config.AdminGroups = {
    'admin',
    'god'
}
