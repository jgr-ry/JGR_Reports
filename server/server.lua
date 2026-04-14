local CLOSE_REASON = {
    STAFF = 'staff',
    PLAYER = 'player',
    INACTIVITY = 'inactivity',
}

local function GetSteamName(src)
    return GetPlayerName(src) or JGRReportsT('ui_unknown')
end

local function NotifyAdminsReportStale()
    for _, v in ipairs(JGR_Fw.GetAllPlayerSources()) do
        if JGR_Fw.IsStaff(v) then
            TriggerClientEvent('jgr_reports:client:reportListStale', v)
        end
    end
end

--- Cierra un reporte activo y notifica a quien corresponda.
---@param reportId number
---@param reason string CLOSE_REASON.*
---@param closedByCitizenid string|nil
---@param closedByName string|nil
---@param staffCloserSrc number|nil si un staff cierra manualmente, recibe confirmación aquí
local function CloseReportInternal(reportId, reason, closedByCitizenid, closedByName, staffCloserSrc)
    MySQL.update(
        [[UPDATE jgr_reports SET status = 'Cerrado', close_reason = ?, closed_by_citizenid = ?, closed_by_name = ?,
            player_offline_since = NULL WHERE id = ? AND status IN ('Abierto', 'En progreso')]],
        { reason, closedByCitizenid, closedByName, reportId },
        function(affectedRows)
            if not affectedRows or affectedRows < 1 then return end

            MySQL.query('SELECT citizenid, adminCitizenid FROM jgr_reports WHERE id = ?', { reportId }, function(res)
                if not res[1] then return end
                local citizenid = res[1].citizenid
                local adminCid = res[1].adminCitizenid

                local targetPlayer = JGR_Fw.GetPlayerByIdentifier(citizenid)
                if targetPlayer then
                    local msg
                    if reason == CLOSE_REASON.INACTIVITY then
                        msg = JGRReportsT('notify_report_closed_inactivity')
                    elseif reason == CLOSE_REASON.PLAYER then
                        msg = JGRReportsT('notify_report_closed_by_you')
                    else
                        msg = JGRReportsT('notify_report_closed')
                    end
                    JGR_Fw.Notify(targetPlayer:getSource(), msg, 'primary')
                    TriggerClientEvent('jgr_reports:client:reportClosed', targetPlayer:getSource())
                end

                if adminCid and reason == CLOSE_REASON.INACTIVITY then
                    local adminPlayer = JGR_Fw.GetPlayerByIdentifier(adminCid)
                    if adminPlayer then
                        JGR_Fw.Notify(adminPlayer:getSource(), JGRReportsT('notify_report_inactivity_staff', reportId), 'primary')
                    end
                end

                if adminCid and reason == CLOSE_REASON.PLAYER then
                    local adminPlayer = JGR_Fw.GetPlayerByIdentifier(adminCid)
                    if adminPlayer and (not staffCloserSrc or adminPlayer:getSource() ~= staffCloserSrc) then
                        local who = closedByName or JGRReportsT('ui_unknown')
                        JGR_Fw.Notify(adminPlayer:getSource(), JGRReportsT('notify_report_closed_by_player_staff', who), 'primary')
                    end
                end

                if staffCloserSrc and reason == CLOSE_REASON.STAFF then
                    JGR_Fw.Notify(staffCloserSrc, JGRReportsT('notify_report_closed_staff_ok'), 'success')
                end

                NotifyAdminsReportStale()
            end)
        end
    )
end

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
            -- Intentar añadir columnas nuevas si la tabla ya existe (actualización)
            MySQL.query("SHOW COLUMNS FROM jgr_reports LIKE 'steamName'", {}, function(cols)
                if #cols == 0 then
                    MySQL.query("ALTER TABLE jgr_reports ADD COLUMN `steamName` varchar(100) DEFAULT NULL AFTER `playerName`")
                    MySQL.query("ALTER TABLE jgr_reports ADD COLUMN `adminName` varchar(100) DEFAULT NULL AFTER `adminCitizenid`")
                    print('^2[JGR_Reports] ^0Columnas steamName y adminName añadidas.^0')
                end
            end)
            MySQL.query("SHOW COLUMNS FROM jgr_report_messages LIKE 'sender_id'", {}, function(cols)
                if #cols == 0 then
                    MySQL.query("ALTER TABLE jgr_report_messages ADD COLUMN `sender_id` int(11) DEFAULT NULL AFTER `sender`")
                    MySQL.query("ALTER TABLE jgr_report_messages MODIFY COLUMN `sender` varchar(100) NOT NULL")
                    print('^2[JGR_Reports] ^0Columna sender_id añadida a jgr_report_messages.^0')
                end
            end)
            MySQL.query("SHOW COLUMNS FROM jgr_reports LIKE 'close_reason'", {}, function(cols)
                if #cols == 0 then
                    MySQL.query("ALTER TABLE jgr_reports ADD COLUMN `close_reason` varchar(32) DEFAULT NULL AFTER `adminName`")
                    MySQL.query("ALTER TABLE jgr_reports ADD COLUMN `closed_by_citizenid` varchar(50) DEFAULT NULL AFTER `close_reason`")
                    MySQL.query("ALTER TABLE jgr_reports ADD COLUMN `closed_by_name` varchar(100) DEFAULT NULL AFTER `closed_by_citizenid`")
                    MySQL.query("ALTER TABLE jgr_reports ADD COLUMN `player_offline_since` timestamp NULL DEFAULT NULL AFTER `closed_by_name`")
                    print('^2[JGR_Reports] ^0Columnas de cierre e inactividad añadidas.^0')
                end
            end)
            print('^2[JGR_Reports] ^0Database tables already exist. Skipping import.^0')
        end
    end)
end)

CreateThread(function()
    Wait(8000)
    local interval = Config.StatusCheckIntervalMs or 60000
    while true do
        MySQL.query(
            "SELECT id, citizenid, player_offline_since FROM jgr_reports WHERE status IN ('Abierto', 'En progreso')",
            {},
            function(rows)
                for _, row in ipairs(rows or {}) do
                    local target = JGR_Fw.GetPlayerByIdentifier(row.citizenid)
                    if target then
                        MySQL.update(
                            'UPDATE jgr_reports SET player_offline_since = NULL, serverId = ? WHERE id = ?',
                            { target:getSource(), row.id }
                        )
                    elseif row.player_offline_since then
                        MySQL.query(
                            [[SELECT id FROM jgr_reports WHERE id = ? AND status IN ('Abierto', 'En progreso')
                                AND player_offline_since IS NOT NULL
                                AND TIMESTAMPDIFF(MINUTE, player_offline_since, NOW()) >= ?]],
                            { row.id, Config.AutoCloseOfflineMinutes or 10 },
                            function(expired)
                                if expired[1] then
                                    CloseReportInternal(row.id, CLOSE_REASON.INACTIVITY, nil, nil, nil)
                                end
                            end
                        )
                    else
                        MySQL.update(
                            'UPDATE jgr_reports SET player_offline_since = NOW() WHERE id = ? AND player_offline_since IS NULL',
                            { row.id }
                        )
                    end
                end
            end
        )
        Wait(interval)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local cid = JGR_Fw.GetDroppedCitizenId(src)
    if not cid then return end
    MySQL.update(
        [[UPDATE jgr_reports SET player_offline_since = COALESCE(player_offline_since, NOW()), serverId = NULL
            WHERE citizenid = ? AND status IN ('Abierto', 'En progreso')]],
        { cid }
    )
end)

-- ==========================================
-- CALLBACKS Y EVENTOS (comandos en bridge/sv_bridge.lua)
-- ==========================================
JGR_Fw.CreateCallback('jgr_reports:server:createReport', function(source, cb, data)
    local src = source
    local P = JGR_Fw.GetPlayer(src)
    if not P then return cb(false) end
    if type(data) ~= 'table' then return cb(false) end

    local title = tostring(data.title or ''):sub(1, 120)
    local description = tostring(data.description or ''):sub(1, 2000)
    local priority = tostring(data.priority or 'media')
    if title:gsub('%s+', '') == '' or description:gsub('%s+', '') == '' then
        return cb(false)
    end
    local steamName = GetSteamName(src)
    local charName = P:getCharName()
    local notifyShort = (steamName:match('^(%S+)') or steamName)

    MySQL.insert("INSERT INTO jgr_reports (citizenid, playerName, steamName, serverId, title, description, priority) VALUES (?, ?, ?, ?, ?, ?, ?)", {
        P:getIdentifier(),
        charName,
        steamName,
        src,
        title,
        description,
        priority
    }, function(id)
        if id then
            for _, v in ipairs(JGR_Fw.GetAllPlayerSources()) do
                if JGR_Fw.IsStaff(v) then
                    JGR_Fw.Notify(v, JGRReportsT('notify_new_report', notifyShort, src), 'primary', 5000)
                end
            end
            cb(id)
        else
            cb(false)
        end
    end)
end)

JGR_Fw.CreateCallback('jgr_reports:server:getActiveReports', function(source, cb)
    if not JGR_Fw.IsStaff(source) then return cb({}) end

    MySQL.query('SELECT * FROM jgr_reports WHERE status IN (\'Abierto\', \'En progreso\') ORDER BY created_at DESC', {}, function(result)
        for _, rep in ipairs(result or {}) do
            local target = JGR_Fw.GetPlayerByIdentifier(rep.citizenid)
            rep.reporterOnline = target ~= nil
            rep.reporterServerId = target and target:getSource() or nil
        end
        cb(result)
    end)
end)

JGR_Fw.CreateCallback('jgr_reports:server:getReportHistory', function(source, cb)
    if not JGR_Fw.IsStaff(source) then return cb({}) end

    MySQL.query("SELECT * FROM jgr_reports WHERE status = 'Cerrado' ORDER BY updated_at DESC LIMIT 50", {}, function(result)
        cb(result)
    end)
end)

JGR_Fw.CreateCallback('jgr_reports:server:getMessages', function(source, cb, reportId)
    reportId = tonumber(reportId)
    if not reportId then return cb({}) end
    local P = JGR_Fw.GetPlayer(source)
    if not P then return cb({}) end
    local isStaff = JGR_Fw.IsStaff(source)
    local citizenid = P:getIdentifier()

    if isStaff then
        MySQL.query("SELECT * FROM jgr_report_messages WHERE report_id = ? ORDER BY created_at ASC", {reportId}, function(result)
            cb(result or {})
        end)
        return
    end

    MySQL.query("SELECT id FROM jgr_reports WHERE id = ? AND citizenid = ? LIMIT 1", { reportId, citizenid }, function(ownerRows)
        if not ownerRows or not ownerRows[1] then
            cb({})
            return
        end
        MySQL.query("SELECT * FROM jgr_report_messages WHERE report_id = ? ORDER BY created_at ASC", {reportId}, function(result)
            cb(result or {})
        end)
    end)
end)

JGR_Fw.CreateCallback('jgr_reports:server:getActiveStaff', function(source, cb)
    local staffList = {}
    for _, v in ipairs(JGR_Fw.GetAllPlayerSources()) do
        if JGR_Fw.IsStaff(v) and JGR_Fw.GetPlayer(v) then
            table.insert(staffList, {
                serverId = v,
                name = GetSteamName(v),
            })
        end
    end
    cb(staffList)
end)

RegisterNetEvent('jgr_reports:server:takeReport', function(reportId)
    local src = source
    local P = JGR_Fw.GetPlayer(src)
    if not P or not JGR_Fw.IsStaff(src) then return end

    local adminName = GetSteamName(src)

    reportId = tonumber(reportId)
    if not reportId then return end
    MySQL.update("UPDATE jgr_reports SET status = 'En progreso', adminCitizenid = ?, adminName = ? WHERE id = ?", { P:getIdentifier(), adminName, reportId }, function(affectedRows)
        if affectedRows > 0 then
            MySQL.query('SELECT citizenid FROM jgr_reports WHERE id = ?', { reportId }, function(res)
                if not res[1] or not res[1].citizenid then return end
                local targetPlayer = JGR_Fw.GetPlayerByIdentifier(res[1].citizenid)
                if targetPlayer then
                    JGR_Fw.Notify(targetPlayer:getSource(), JGRReportsT('notify_staff_attending', adminName), 'success')
                    TriggerClientEvent('jgr_reports:client:updateReportData', targetPlayer:getSource())
                end
            end)
        end
    end)
end)

RegisterNetEvent('jgr_reports:server:sendMessage', function(reportId, message, isAdmin)
    reportId = tonumber(reportId)
    message = tostring(message or ''):sub(1, 1500)
    if not reportId or message:gsub('%s+', '') == '' then return end

    local src = source
    local P = JGR_Fw.GetPlayer(src)
    if not P then return end

    local steamName = GetSteamName(src)
    local senderDisplay
    if isAdmin then
        senderDisplay = "[Staff] " .. steamName .. " [ID:" .. src .. "]"
    else
        senderDisplay = steamName .. " [ID:" .. src .. "]"
    end
    
    MySQL.insert("INSERT INTO jgr_report_messages (report_id, sender, sender_id, message, is_admin) VALUES (?, ?, ?, ?, ?)", {
        reportId, senderDisplay, src, message, isAdmin and 1 or 0
    }, function(msgId)
        if msgId then
            -- Tenemos que enviarle el nuevo mensaje al otro extremo.
            MySQL.query("SELECT citizenid, adminCitizenid FROM jgr_reports WHERE id = ?", {reportId}, function(res)
                if res[1] then
                    local targetPlayer = JGR_Fw.GetPlayerByIdentifier(res[1].citizenid)
                    local targetSrc = targetPlayer and targetPlayer:getSource() or nil

                    if isAdmin and targetSrc then
                        TriggerClientEvent('jgr_reports:client:receiveMessage', targetSrc, msgId, senderDisplay, message, isAdmin)
                    end

                    if not isAdmin and res[1].adminCitizenid then
                        local adminPlayer = JGR_Fw.GetPlayerByIdentifier(res[1].adminCitizenid)
                        if adminPlayer then
                            TriggerClientEvent('jgr_reports:client:receiveMessage', adminPlayer:getSource(), msgId, senderDisplay, message, isAdmin)
                        end
                    end

                    for _, v in ipairs(JGR_Fw.GetAllPlayerSources()) do
                        if v ~= src and JGR_Fw.IsStaff(v) then
                            TriggerClientEvent('jgr_reports:client:receiveMessage', v, msgId, senderDisplay, message, isAdmin)
                        end
                    end
                    
                    -- Enviarselo al que lo escribió para que también lo vea reflejado
                    TriggerClientEvent('jgr_reports:client:receiveMessage', src, msgId, senderDisplay, message, isAdmin)
                end
            end)
        end
    end)
end)

RegisterNetEvent('jgr_reports:server:closeReport', function(reportId)
    reportId = tonumber(reportId)
    if not reportId then return end

    local src = source
    local P = JGR_Fw.GetPlayer(src)
    if not P then return end

    local isAdmin = JGR_Fw.IsStaff(src)

    MySQL.query('SELECT citizenid FROM jgr_reports WHERE id = ?', { reportId }, function(res)
        if not res[1] then return end
        if not isAdmin and res[1].citizenid ~= P:getIdentifier() then return end

        local reason = isAdmin and CLOSE_REASON.STAFF or CLOSE_REASON.PLAYER
        local name = GetSteamName(src)
        local cid = P:getIdentifier()
        local staffCloser = isAdmin and src or nil

        CloseReportInternal(reportId, reason, cid, name, staffCloser)
    end)
end)

-- ==========================================
-- SISTEMA DE LLAMADAS (VOZ CON CANALES DINÁMICOS)
-- ==========================================

local activeCallChannels = {} -- { reportId = channel }

RegisterNetEvent('jgr_reports:server:callPlayer', function(reportId)
    local src = source
    if not JGR_Fw.IsStaff(src) then return end
    reportId = tonumber(reportId)
    if not reportId then return end

    MySQL.query("SELECT citizenid FROM jgr_reports WHERE id = ?", { reportId }, function(res)
        if res[1] and res[1].citizenid then
            local targetPlayer = JGR_Fw.GetPlayerByIdentifier(res[1].citizenid)
            if targetPlayer then
                TriggerClientEvent('jgr_reports:client:receiveCall', targetPlayer:getSource(), src, reportId)
            else
                JGR_Fw.Notify(src, JGRReportsT('notify_player_offline'), 'error')
            end
        else
            JGR_Fw.Notify(src, JGRReportsT('notify_invalid_report'), 'error')
        end
    end)
end)

RegisterNetEvent('jgr_reports:server:answerCall', function(adminSrc, reportId)
    local src = source
    adminSrc = tonumber(adminSrc)
    reportId = tonumber(reportId)
    if not adminSrc or not reportId then return end

    local P = JGR_Fw.GetPlayer(src)
    if not P then return end

    MySQL.query('SELECT citizenid FROM jgr_reports WHERE id = ?', { reportId }, function(res)
        if not res[1] or res[1].citizenid ~= P:getIdentifier() then return end

        local channel = math.random(8000, 9999)
        activeCallChannels[reportId] = channel

        TriggerClientEvent('jgr_reports:client:callAnswered', adminSrc, channel)
        TriggerClientEvent('jgr_reports:client:callAnswered', src, channel)
    end)
end)

RegisterNetEvent('jgr_reports:server:declineCall', function(adminSrc)
    local src = source
    adminSrc = tonumber(adminSrc)
    if not adminSrc then return end
    -- Notificar al admin
    TriggerClientEvent('jgr_reports:client:callDeclined', adminSrc)
end)

RegisterNetEvent('jgr_reports:server:hangUp', function(reportId)
    local src = source
    reportId = tonumber(reportId)
    if not reportId then return end
    
    MySQL.query("SELECT citizenid, adminCitizenid FROM jgr_reports WHERE id = ?", {reportId}, function(res)
        if res[1] then
            -- Manda evento de Colgar al creador del reporte
            local targetPlayer = JGR_Fw.GetPlayerByIdentifier(res[1].citizenid)
            if targetPlayer then
                TriggerClientEvent('jgr_reports:client:callEnded', targetPlayer:getSource())
            end

            if res[1].adminCitizenid then
                local adminPlayer = JGR_Fw.GetPlayerByIdentifier(res[1].adminCitizenid)
                if adminPlayer then
                    TriggerClientEvent('jgr_reports:client:callEnded', adminPlayer:getSource())
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
