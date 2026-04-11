local isInUI = false

local function NuiLocalePayload()
    return {
        strings = JGRReportsGetNuiLocale(),
        localeLang = Config.Locale or 'es',
    }
end
local currentCallChannel = 0
local activeAdminCallerSrc = nil
local activeCallTargetSrc = nil

-- Uso de pma-voice para llamadas (Call Channel en vez de Radio para evitar Push-to-Talk)
local function JoinCallChannel(channel)
    pcall(function()
        exports['pma-voice']:setCallChannel(channel)
    end)
    currentCallChannel = channel
    JGR_FW.Notify(JGRReportsT('notify_call_joined'), 'success')
end

local function LeaveCallChannel()
    pcall(function()
        exports['pma-voice']:setCallChannel(0)
    end)
    currentCallChannel = 0
    JGR_FW.Notify(JGRReportsT('notify_call_left'), 'primary')
end

-- ==========================================
-- ABRIR / CERRAR NUI
-- ==========================================
local function OpenNUI()
    if not isInUI then
        isInUI = true
        SetNuiFocus(true, true)
    end
end

RegisterNUICallback('closeUI', function(data, cb)
    isInUI = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    cb('ok')
end)

-- ==========================================
-- JUGADOR: CREAR REPORTE O CHAT ACTIVO
-- ==========================================
RegisterNetEvent('jgr_reports:client:openCreateForm', function()
    OpenNUI()
    -- Cargar lista de staff activo para mostrarlo al jugador
    JGR_FW.TriggerCallback('jgr_reports:server:getActiveStaff', function(staffList)
        local loc = NuiLocalePayload()
        SendNUIMessage({
            action = "open_create",
            staffList = staffList,
            strings = loc.strings,
            localeLang = loc.localeLang,
        })
    end)
end)

RegisterNetEvent('jgr_reports:client:openActiveReport', function(reportData)
    OpenNUI()
    JGR_FW.TriggerCallback('jgr_reports:server:getMessages', function(messages)
        local loc = NuiLocalePayload()
        SendNUIMessage({
            action = "open_chat",
            report = reportData,
            messages = messages,
            isAdmin = false,
            strings = loc.strings,
            localeLang = loc.localeLang,
        })
    end, reportData.id)
end)

RegisterNUICallback('createReport', function(data, cb)
    JGR_FW.TriggerCallback('jgr_reports:server:createReport', function(reportId)
        if reportId then
            JGR_FW.Notify(JGRReportsT('notify_report_sent'), 'success')
            cb({ success = true })
        else
            cb({ success = false })
            JGR_FW.Notify(JGRReportsT('notify_report_fail'), 'error')
        end
    end, data)
end)

RegisterNetEvent('jgr_reports:client:updateReportData', function()
    if isInUI then
        JGR_FW.Notify(JGRReportsT('notify_report_taken'), 'success')
    end
end)

RegisterNetEvent('jgr_reports:client:reportClosed', function()
    if isInUI then
        SendNUIMessage({ action = "report_closed_forcefully" })
    end
end)

-- ==========================================
-- ADMIN: PANEL
-- ==========================================
RegisterNetEvent('jgr_reports:client:openAdminPanel', function()
    OpenNUI()
    local loc = NuiLocalePayload()
    SendNUIMessage({
        action = "open_admin",
        autoCloseMinutes = Config.AutoCloseOfflineMinutes or 10,
        strings = loc.strings,
        localeLang = loc.localeLang,
    })
end)

RegisterNetEvent('jgr_reports:client:reportListStale', function()
    SendNUIMessage({ action = "refresh_admin_lists" })
end)

RegisterNUICallback('loadReports', function(data, cb)
    JGR_FW.TriggerCallback('jgr_reports:server:getActiveReports', function(reports)
        cb(reports)
    end)
end)

RegisterNUICallback('loadHistory', function(data, cb)
    JGR_FW.TriggerCallback('jgr_reports:server:getReportHistory', function(reports)
        cb(reports)
    end)
end)

RegisterNUICallback('takeReport', function(data, cb)
    local reportId = data.reportId
    TriggerServerEvent('jgr_reports:server:takeReport', reportId)
    cb('ok')
end)

RegisterNUICallback('openAdminChat', function(data, cb)
    local reportId = data.reportId
    JGR_FW.TriggerCallback('jgr_reports:server:getMessages', function(messages)
        local loc = NuiLocalePayload()
        SendNUIMessage({
            action = "open_chat",
            report = data.report,
            messages = messages,
            isAdmin = true,
            strings = loc.strings,
            localeLang = loc.localeLang,
        })
        cb('ok')
    end, reportId)
end)

RegisterNUICallback('loadMessages', function(data, cb)
    local reportId = data.reportId
    JGR_FW.TriggerCallback('jgr_reports:server:getMessages', function(messages)
        cb(messages)
    end, reportId)
end)

RegisterNUICallback('closeReport', function(data, cb)
    local reportId = data.reportId
    TriggerServerEvent('jgr_reports:server:closeReport', reportId)
    cb('ok')
end)

-- ==========================================
-- CHAT (AMBOS LADOS)
-- ==========================================
RegisterNUICallback('sendChatMessage', function(data, cb)
    TriggerServerEvent('jgr_reports:server:sendMessage', data.reportId, data.message, data.isAdmin)
    cb('ok')
end)

RegisterNetEvent('jgr_reports:client:receiveMessage', function(msgId, sender, message, isAdmin)
    SendNUIMessage({
        action = "receive_message",
        msgId = msgId,
        sender = sender,
        message = message,
        isAdmin = isAdmin
    })
end)

-- ==========================================
-- SISTEMA DE LLAMADAS (VOZ NO-TP CLIENT)
-- ==========================================
RegisterNUICallback('callPlayer', function(data, cb)
    local reportId = data.reportId
    TriggerServerEvent('jgr_reports:server:callPlayer', reportId)
    cb('ok')
end)

-- El jugador recibe la llamada
RegisterNetEvent('jgr_reports:client:receiveCall', function(adminSrc, reportId)
    activeAdminCallerSrc = adminSrc
    -- Notificación en pantalla
    JGR_FW.Notify(JGRReportsT('notify_call_incoming'), 'primary', 5000)
    -- Forzar a que la UI se abra para que el jugador pueda ver la llamada
    OpenNUI()
    local loc = NuiLocalePayload()
    SendNUIMessage({
        action = "incoming_call",
        reportId = reportId,
        strings = loc.strings,
        localeLang = loc.localeLang,
    })
    PlaySoundFrontend(-1, "Phone_Ring", "Phone_SoundSet_Default", 1)
end)

-- Jugador clickea Aceptar
RegisterNUICallback('answerCall', function(data, cb)
    local reportId = data.reportId
    TriggerServerEvent('jgr_reports:server:answerCall', activeAdminCallerSrc, reportId)
    cb('ok')
end)

-- Jugador clickea Rechazar
RegisterNUICallback('declineCall', function(data, cb)
    TriggerServerEvent('jgr_reports:server:declineCall', activeAdminCallerSrc)
    cb('ok')
end)

-- Admin recibe notificación si es rechazada
RegisterNetEvent('jgr_reports:client:callDeclined', function()
    JGR_FW.Notify(JGRReportsT('notify_call_declined'), 'error')
    SendNUIMessage({ action = "call_declined" })
end)

-- Ambos reciben el evento de llamada contestada (con el canal a usar)
RegisterNetEvent('jgr_reports:client:callAnswered', function(channel)
    JoinCallChannel(channel)
    SendNUIMessage({ action = "call_started" })
end)

RegisterNUICallback('hangUpCall', function(data, cb)
    TriggerServerEvent('jgr_reports:server:hangUp', data.reportId)
    LeaveCallChannel()
    cb('ok')
end)

RegisterNUICallback('playSound', function(data, cb)
    if data.sound == 'hover' then
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    elseif data.sound == 'click' then
        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    elseif data.sound == 'success' then
        PlaySoundFrontend(-1, "Hack_Success", "DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS", 1)
    elseif data.sound == 'error' then
        PlaySoundFrontend(-1, "Hack_Failed", "DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS", 1)
    elseif data.sound == 'message' then
        PlaySoundFrontend(-1, "Event_Message_Purple", "GTAO_FM_Events_Soundset", 1)
    end
    cb('ok')
end)

-- El servidor manda a ambos colgar
RegisterNetEvent('jgr_reports:client:callEnded', function()
    LeaveCallChannel()
    SendNUIMessage({ action = "call_ended" })
end)
