local QBCore = exports[Config.CoreName]:GetCoreObject()
local isInUI = false
local currentCallChannel = 0
local activeAdminCallerSrc = nil
local activeCallTargetSrc = nil

-- Uso de pma-voice para llamadas (Call Channel en vez de Radio para evitar Push-to-Talk)
local function JoinCallChannel(channel)
    exports['pma-voice']:setCallChannel(channel)
    currentCallChannel = channel
    QBCore.Functions.Notify('Conectado a la llamada de soporte.', 'success')
end

local function LeaveCallChannel()
    exports['pma-voice']:setCallChannel(0)
    currentCallChannel = 0
    QBCore.Functions.Notify('Llamada finalizada.', 'primary')
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
    SendNUIMessage({ action = "open_create" })
end)

RegisterNetEvent('jgr_reports:client:openActiveReport', function(reportData)
    OpenNUI()
    QBCore.Functions.TriggerCallback('jgr_reports:server:getMessages', function(messages)
        SendNUIMessage({ 
            action = "open_chat", 
            report = reportData,
            messages = messages,
            isAdmin = false
        })
    end, reportData.id)
end)

RegisterNUICallback('createReport', function(data, cb)
    QBCore.Functions.TriggerCallback('jgr_reports:server:createReport', function(reportId)
        if reportId then
            QBCore.Functions.Notify('Reporte enviado con éxito.', 'success')
            cb({ success = true })
        else
            cb({ success = false })
            QBCore.Functions.Notify('Error al enviar el reporte.', 'error')
        end
    end, data)
end)

RegisterNetEvent('jgr_reports:client:updateReportData', function()
    if isInUI then
        QBCore.Functions.Notify('Un admin ha tomado tu reporte. Se ha actualizado el estado.', 'success')
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
    SendNUIMessage({ action = "open_admin" })
end)

RegisterNUICallback('loadReports', function(data, cb)
    QBCore.Functions.TriggerCallback('jgr_reports:server:getActiveReports', function(reports)
        cb(reports)
    end)
end)

RegisterNUICallback('loadHistory', function(data, cb)
    QBCore.Functions.TriggerCallback('jgr_reports:server:getReportHistory', function(reports)
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
    QBCore.Functions.TriggerCallback('jgr_reports:server:getMessages', function(messages)
        SendNUIMessage({ 
            action = "open_chat", 
            report = data.report,
            messages = messages,
            isAdmin = true
        })
        cb('ok')
    end, reportId)
end)

RegisterNUICallback('loadMessages', function(data, cb)
    local reportId = data.reportId
    QBCore.Functions.TriggerCallback('jgr_reports:server:getMessages', function(messages)
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
    QBCore.Functions.Notify('Llamada entrante de Soporte...', 'primary', 5000)
    -- Forzar a que la UI se abra para que el jugador pueda ver la llamada
    OpenNUI()
    SendNUIMessage({
        action = "incoming_call",
        reportId = reportId
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
    QBCore.Functions.Notify('Llamada rechazada por el jugador.', 'error')
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
