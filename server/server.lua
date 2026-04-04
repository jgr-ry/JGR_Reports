local QBCore = exports[Config.CoreName]:GetCoreObject()

-- ==========================================
-- AUTO IMPORT SQL
-- ==========================================
CreateThread(function()
    MySQL.query("SHOW TABLES LIKE 'jgr_reports'", {}, function(result)
        if #result == 0 then
            print('^3[JGR_Reports] ^0Tables not found. Auto-importing install.sql...^0')
            local sqlFile = LoadResourceFile(GetCurrentResourceName(), "install.sql")
            if sqlFile then
                -- Dividimos el archivo por punto y coma para ejecutar múltiples sentencias
                local statements = {}
                for statement in sqlFile:gmatch("([^;]+)") do
                    if statement:match("%S") then
                        table.insert(statements, statement .. ";")
                    end
                end
                
                for _, stmt in ipairs(statements) do
                    MySQL.query.await(stmt)
                end
                print('^2[JGR_Reports] ^0Database tables successfully imported.^0')
            else
                print('^1[JGR_Reports] ^0Error: install.sql not found!^0')
            end
        else
            print('^2[JGR_Reports] ^0Database tables already exist. Skipping import.^0')
        end
    end)
end)

-- ==========================================
-- COMANDOS
-- ==========================================
QBCore.Commands.Add(Config.CommandPlayer, "Abrir sistema de reportes", {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Verificar si tiene un reporte activo
    MySQL.query("SELECT * FROM jgr_reports WHERE citizenid = ? AND status IN ('Abierto', 'En progreso') LIMIT 1", {Player.PlayerData.citizenid}, function(result)
        if result[1] then
            TriggerClientEvent('jgr_reports:client:openActiveReport', src, result[1])
        else
            TriggerClientEvent('jgr_reports:client:openCreateForm', src)
        end
    end)
end)

QBCore.Commands.Add(Config.CommandAdmin, "Abrir panel de reportes (Admin)", {}, false, function(source, args)
    local src = source
    if QBCore.Functions.HasPermission(src, Config.AdminGroups) then
        TriggerClientEvent('jgr_reports:client:openAdminPanel', src)
    else
        TriggerClientEvent('QBCore:Notify', src, 'No tienes permisos', 'error')
    end
end)

-- ==========================================
-- CALLBACKS Y EVENTOS
-- ==========================================
QBCore.Functions.CreateCallback('jgr_reports:server:createReport', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    
    local title = data.title
    local description = data.description
    local priority = data.priority
    
    MySQL.insert("INSERT INTO jgr_reports (citizenid, playerName, serverId, title, description, priority) VALUES (?, ?, ?, ?, ?, ?)", {
        Player.PlayerData.citizenid, 
        Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        src,
        title,
        description,
        priority
    }, function(id)
        if id then
            -- Notificar admins conectados
            local players = QBCore.Functions.GetPlayers()
            for _, v in pairs(players) do
                if QBCore.Functions.HasPermission(v, Config.AdminGroups) then
                    TriggerClientEvent('QBCore:Notify', v, 'Nuevo reporte recibido de '..Player.PlayerData.charinfo.firstname, 'primary', 5000)
                end
            end
            cb(id)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('jgr_reports:server:getActiveReports', function(source, cb)
    local src = source
    if not QBCore.Functions.HasPermission(src, Config.AdminGroups) then return cb({}) end
    
    MySQL.query("SELECT * FROM jgr_reports WHERE status IN ('Abierto', 'En progreso') ORDER BY created_at DESC", {}, function(result)
        cb(result)
    end)
end)

QBCore.Functions.CreateCallback('jgr_reports:server:getReportHistory', function(source, cb)
    local src = source
    if not QBCore.Functions.HasPermission(src, Config.AdminGroups) then return cb({}) end
    
    MySQL.query("SELECT * FROM jgr_reports WHERE status = 'Cerrado' ORDER BY updated_at DESC LIMIT 50", {}, function(result)
        cb(result)
    end)
end)

QBCore.Functions.CreateCallback('jgr_reports:server:getMessages', function(source, cb, reportId)
    MySQL.query("SELECT * FROM jgr_report_messages WHERE report_id = ? ORDER BY created_at ASC", {reportId}, function(result)
        cb(result)
    end)
end)

RegisterNetEvent('jgr_reports:server:takeReport', function(reportId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroups) then return end
    
    MySQL.update("UPDATE jgr_reports SET status = 'En progreso', adminCitizenid = ? WHERE id = ?", {Player.PlayerData.citizenid, reportId}, function(affectedRows)
        if affectedRows > 0 then
            -- Buscar jugador original y notificarle
            MySQL.query("SELECT serverId FROM jgr_reports WHERE id = ?", {reportId}, function(res)
                if res[1] and res[1].serverId then
                    local targetId = res[1].serverId
                    TriggerClientEvent('QBCore:Notify', targetId, 'Un administrador está atendiendo tu reporte', 'success')
                    TriggerClientEvent('jgr_reports:client:updateReportData', targetId)
                end
            end)
        end
    end)
end)

RegisterNetEvent('jgr_reports:server:sendMessage', function(reportId, message, isAdmin)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local senderName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    if isAdmin then senderName = "Admin " .. senderName end
    
    MySQL.insert("INSERT INTO jgr_report_messages (report_id, sender, message, is_admin) VALUES (?, ?, ?, ?)", {
        reportId, senderName, message, isAdmin and 1 or 0
    }, function(msgId)
        if msgId then
            -- Tenemos que enviarle el nuevo mensaje al otro extremo.
            MySQL.query("SELECT citizenid, adminCitizenid FROM jgr_reports WHERE id = ?", {reportId}, function(res)
                if res[1] then
                    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(res[1].citizenid)
                    local targetSrc = targetPlayer and targetPlayer.PlayerData.source or nil
                    
                    -- Si es el admin quien envía, notificar al jugador
                    if isAdmin and targetSrc then
                        TriggerClientEvent('jgr_reports:client:receiveMessage', targetSrc, msgId, senderName, message, isAdmin)
                    end
                    
                    -- Si es el jugador quien envía, notificar al admin
                    if not isAdmin and res[1].adminCitizenid then
                        local adminPlayer = QBCore.Functions.GetPlayerByCitizenId(res[1].adminCitizenid)
                        if adminPlayer then
                            TriggerClientEvent('jgr_reports:client:receiveMessage', adminPlayer.PlayerData.source, msgId, senderName, message, isAdmin)
                        end
                    end
                    
                    -- Enviarselo al que lo escribió para que también lo vea reflejado si estaba enviando
                    TriggerClientEvent('jgr_reports:client:receiveMessage', src, msgId, senderName, message, isAdmin)
                end
            end)
        end
    end)
end)

RegisterNetEvent('jgr_reports:server:closeReport', function(reportId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local isAdmin = QBCore.Functions.HasPermission(src, Config.AdminGroups)
    
    MySQL.query("SELECT citizenid FROM jgr_reports WHERE id = ?", {reportId}, function(res)
        if res[1] then
            if isAdmin or res[1].citizenid == Player.PlayerData.citizenid then
                MySQL.update("UPDATE jgr_reports SET status = 'Cerrado' WHERE id = ?", {reportId}, function(affectedRows)
                    if affectedRows > 0 then
                        local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(res[1].citizenid)
                        if targetPlayer then
                            TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, 'El reporte ha sido cerrado', 'primary')
                            TriggerClientEvent('jgr_reports:client:reportClosed', targetPlayer.PlayerData.source)
                        end
                        if isAdmin and (not targetPlayer or targetPlayer.PlayerData.source ~= src) then
                            TriggerClientEvent('QBCore:Notify', src, 'Reporte cerrado con éxito', 'success')
                        end
                    end
                end)
            end
        end
    end)
end)

-- ==========================================
-- SISTEMA DE LLAMADAS (VOZ CON CANALES DINÁMICOS)
-- ==========================================

local activeCallChannels = {} -- { reportId = channel }

RegisterNetEvent('jgr_reports:server:callPlayer', function(reportId)
    local src = source
    if not QBCore.Functions.HasPermission(src, Config.AdminGroups) then return end
    
    MySQL.query("SELECT citizenid FROM jgr_reports WHERE id = ?", {reportId}, function(res)
        if res[1] and res[1].citizenid then
            local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(res[1].citizenid)
            if targetPlayer then
                local targetSrc = targetPlayer.PlayerData.source
                -- Envía el evento al jugador para mostrar UI de recibir llamada
                TriggerClientEvent('jgr_reports:client:receiveCall', targetSrc, src, reportId)
            else
                TriggerClientEvent('QBCore:Notify', src, 'El jugador no está online', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'Reporte no válido', 'error')
        end
    end)
end)

RegisterNetEvent('jgr_reports:server:answerCall', function(adminSrc, reportId)
    local src = source
    
    -- Generar un canal aleatorio alto para no pisar canales de policía u otros reportes
    local channel = math.random(8000, 9999)
    -- Opcional: Podrías comprobar si ese channel ya existe en activeCallChannels, 
    -- pero con 2000 posibilidades la colisión es casi imposible en uso simultáneo.
    activeCallChannels[reportId] = channel
    
    -- Notificar al admin que contestó
    TriggerClientEvent('jgr_reports:client:callAnswered', adminSrc, channel)
    -- Asignar canal al jugador (el cliente lo hace)
    TriggerClientEvent('jgr_reports:client:callAnswered', src, channel)
end)

RegisterNetEvent('jgr_reports:server:declineCall', function(adminSrc)
    local src = source
    -- Notificar al admin
    TriggerClientEvent('jgr_reports:client:callDeclined', adminSrc)
end)

RegisterNetEvent('jgr_reports:server:hangUp', function(reportId)
    local src = source
    if not reportId then return end
    
    MySQL.query("SELECT citizenid, adminCitizenid FROM jgr_reports WHERE id = ?", {reportId}, function(res)
        if res[1] then
            -- Manda evento de Colgar al creador del reporte
            local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(res[1].citizenid)
            if targetPlayer then
                TriggerClientEvent('jgr_reports:client:callEnded', targetPlayer.PlayerData.source)
            end
            
            -- Manda evento de Colgar al administrador que lo atendía
            if res[1].adminCitizenid then
                local adminPlayer = QBCore.Functions.GetPlayerByCitizenId(res[1].adminCitizenid)
                if adminPlayer then
                    TriggerClientEvent('jgr_reports:client:callEnded', adminPlayer.PlayerData.source)
                end
            end
            
            -- Por si acaso, se lo mandamos también al que ejecutó la acción (fallback)
            TriggerClientEvent('jgr_reports:client:callEnded', src)
            
            -- Liberar el canal de memoria
            if activeCallChannels[reportId] then
                activeCallChannels[reportId] = nil
            end
        end
    end)
end)
