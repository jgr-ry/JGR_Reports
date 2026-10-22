--[[
    Server bridge: qb-core, qbx_core (Qbox), es_extended, standalone / ox_core.
    El resto del servidor solo usa JGR_Fw.*; nunca llama a un framework directamente.
]]

if GetCurrentResourceName() ~= 'JGR_Reports' then
    print(('^1[JGR]^0 Renombra la carpeta del recurso a ^3JGR_Reports^0 (actual: ^1%s^0).'):format(GetCurrentResourceName()))
    StopResource(GetCurrentResourceName())
    return
end

JGR_Fw = JGR_Fw or {}
JGR_Fw._serverCallbacks = {}

local QBCore = nil
local ESX = nil

local function fw()
    return JGRReportsBridge.Current()
end

--- QBCore clásico con objeto cargado.
local function isQB()
    return fw() == 'qb' and QBCore ~= nil
end

local function isQbox()
    return fw() == 'qbox'
end

local ESX_EXPORT = 'es_extended'

local function tableHas(t, val)
    if not t or not val then return false end
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

function JGR_Fw.LicenseIdentifier(src)
    return GetPlayerIdentifierByType(src, 'license')
        or GetPlayerIdentifierByType(src, 'license2')
        or ('license:temp_' .. tostring(src))
end

local function wrapQBPlayer(p)
    if not p or not p.PlayerData then return nil end
    return {
        _raw = p,
        getIdentifier = function(self)
            return self._raw.PlayerData.citizenid
        end,
        getCharName = function(self)
            local c = self._raw.PlayerData.charinfo
            if not c then return GetPlayerName(self._raw.PlayerData.source) end
            return ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
        end,
        getSource = function(self)
            return self._raw.PlayerData.source
        end,
    }
end

local function wrapESXPlayer(xP)
    if not xP then return nil end
    return {
        _raw = xP,
        getIdentifier = function(self)
            return self._raw.identifier
        end,
        getCharName = function(self)
            if self._raw.getName then
                local n = self._raw.getName()
                if n and n ~= '' then return n end
            end
            if self._raw.get then
                local fn = self._raw.get('firstName')
                local ln = self._raw.get('lastName')
                if fn or ln then
                    return ((fn or '') .. ' ' .. (ln or '')):gsub('^%s*(.-)%s*$', '%1')
                end
            end
            return GetPlayerName(self._raw.source)
        end,
        getSource = function(self)
            return self._raw.source
        end,
    }
end

local function wrapStandalonePlayer(src)
    if not src or not GetPlayerName(src) then return nil end
    return {
        _raw = src,
        getIdentifier = function(self)
            return JGR_Fw.LicenseIdentifier(self._raw)
        end,
        getCharName = function(self)
            return GetPlayerName(self._raw) or JGRReportsT('ui_unknown')
        end,
        getSource = function(self)
            return self._raw
        end,
    }
end

function JGR_Fw.Init()
    local f = JGRReportsBridge.Resolve()
    print(('^2[JGR_Reports]^7 Framework: ^5%s^7'):format(f))
    if f == 'qb' then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        QBCore = ok and core or nil
        if not QBCore then
            print('^1[JGR_Reports] ^0No se pudo cargar qb-core (Framework=' .. tostring(Config.Framework) .. ')^0')
        end
    elseif f == 'esx' then
        local ok, obj = pcall(function()
            return exports[ESX_EXPORT]:getSharedObject()
        end)
        if ok and obj then
            ESX = obj
        end
    end
end

function JGR_Fw.WaitForESX()
    if fw() ~= 'esx' then return true end
    local t = 0
    while not ESX and t < 150 do
        local ok, obj = pcall(function()
            return exports[ESX_EXPORT]:getSharedObject()
        end)
        if ok and obj then
            ESX = obj
            break
        end
        Wait(100)
        t = t + 1
    end
    if not ESX then
        print('^1[JGR_Reports] ^0ESX no disponible (Framework=esx, recurso ' .. ESX_EXPORT .. ').^0')
        return false
    end
    return true
end

function JGR_Fw.GetPlayer(src)
    src = tonumber(src)
    if not src then return nil end
    if isQbox() then
        return wrapQBPlayer(exports.qbx_core:GetPlayer(src))
    elseif isQB() then
        return wrapQBPlayer(QBCore.Functions.GetPlayer(src))
    elseif fw() == 'esx' and ESX then
        return wrapESXPlayer(ESX.GetPlayerFromId(src))
    elseif fw() == 'standalone' then
        return wrapStandalonePlayer(src)
    end
    return nil
end

function JGR_Fw.GetPlayerByIdentifier(identifier)
    if not identifier then return nil end
    if isQbox() then
        return wrapQBPlayer(exports.qbx_core:GetPlayerByCitizenId(identifier))
    elseif isQB() then
        return wrapQBPlayer(QBCore.Functions.GetPlayerByCitizenId(identifier))
    elseif fw() == 'esx' and ESX then
        local xP = nil
        if ESX.GetPlayerFromIdentifier then
            xP = ESX.GetPlayerFromIdentifier(identifier)
        end
        if not xP then
            for _, pid in ipairs(GetPlayers()) do
                local xp = ESX.GetPlayerFromId(tonumber(pid))
                if xp and xp.identifier == identifier then
                    xP = xp
                    break
                end
            end
        end
        return wrapESXPlayer(xP)
    elseif fw() == 'standalone' then
        for _, pid in ipairs(GetPlayers()) do
            local p = JGR_Fw.GetPlayer(tonumber(pid))
            if p and p:getIdentifier() == identifier then return p end
        end
    end
    return nil
end

function JGR_Fw.GetAllPlayerSources()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        table.insert(out, tonumber(id))
    end
    return out
end

function JGR_Fw.IsStaff(src)
    local groups = Config.AdminGroups or {}
    if isQbox() then
        -- Qbox: permisos por ACE (group.<nombre>) o exports.qbx_core:HasPermission
        for _, g in ipairs(groups) do
            if IsPlayerAceAllowed(src, 'group.' .. g) then return true end
            local ok, allowed = pcall(function() return exports.qbx_core:HasPermission(src, g) end)
            if ok and allowed then return true end
        end
        return false
    elseif isQB() then
        return QBCore.Functions.HasPermission(src, groups)
    elseif fw() == 'esx' and ESX then
        local xP = ESX.GetPlayerFromId(src)
        if not xP then return false end
        if xP.getGroup then
            if tableHas(groups, xP.getGroup()) then return true end
        end
        if xP.getJob then
            local job = xP.getJob()
            if job and job.name and tableHas(groups, job.name) then return true end
        end
        return false
    elseif fw() == 'standalone' then
        if Config.StandaloneAce and Config.StandaloneAce ~= '' then
            if IsPlayerAceAllowed(src, Config.StandaloneAce) then return true end
        end
        local lic = JGR_Fw.LicenseIdentifier(src)
        for _, a in ipairs(Config.StandaloneAdminLicenses or {}) do
            if a == lic then return true end
        end
        return false
    end
    return false
end

function JGR_Fw.Notify(src, msg, nType, duration)
    nType = nType or 'primary'
    duration = duration or 5000
    if isQbox() then
        exports.qbx_core:Notify(src, msg, nType == 'primary' and 'inform' or nType, duration)
    elseif isQB() then
        TriggerClientEvent('QBCore:Notify', src, msg, nType, duration)
    elseif fw() == 'esx' then
        TriggerClientEvent('esx:showNotification', src, msg)
    else
        TriggerClientEvent('jgr_reports:client:notify', src, msg, nType, duration)
    end
end

function JGR_Fw.CreateCallback(name, fn)
    JGR_Fw._serverCallbacks[name] = fn
end

--- Qbox y standalone usan solo el sistema interno (jgr_reports:internal:cb), que siempre está activo.
function JGR_Fw.RegisterAllCallbacks()
    if isQB() then
        for name, fn in pairs(JGR_Fw._serverCallbacks) do
            QBCore.Functions.CreateCallback(name, fn)
        end
    elseif fw() == 'esx' and ESX then
        for name, fn in pairs(JGR_Fw._serverCallbacks) do
            ESX.RegisterServerCallback(name, function(source, cb, ...)
                fn(source, cb, ...)
            end)
        end
    end
end

RegisterNetEvent('jgr_reports:internal:cb', function(name, reqId, ...)
    local src = source
    local fn = type(name) == 'string' and JGR_Fw._serverCallbacks[name]
    if not fn or type(reqId) ~= 'number' then return end
    fn(src, function(...)
        TriggerClientEvent('jgr_reports:internal:cb_res', src, reqId, ...)
    end, ...)
end)

function JGR_Fw.RegisterCommands()
    local function openReport(src)
        local P = JGR_Fw.GetPlayer(src)
        if not P then return end
        MySQL.query('SELECT * FROM jgr_reports WHERE citizenid = ? AND status IN (\'Abierto\', \'En progreso\') LIMIT 1', { P:getIdentifier() }, function(result)
            if result and result[1] then
                -- El jugador no debe recibir nombre de personaje ni Steam en el NUI (solo staff lo ve en panel)
                local row = result[1]
                row.playerName = nil
                row.steamName = nil
                TriggerClientEvent('jgr_reports:client:openActiveReport', src, row)
            else
                TriggerClientEvent('jgr_reports:client:openCreateForm', src)
            end
        end)
    end

    local function openStaff(src)
        if not JGR_Fw.IsStaff(src) then
            JGR_Fw.Notify(src, JGRReportsT('notify_no_permission'), 'error')
            return
        end
        TriggerClientEvent('jgr_reports:client:openAdminPanel', src)
    end

    if isQB() then
        QBCore.Commands.Add(Config.CommandPlayer, JGRReportsT('cmd_report_desc'), {}, false, function(source, _)
            openReport(source)
        end)
        QBCore.Commands.Add(Config.CommandAdmin, JGRReportsT('cmd_reportes_desc'), {}, false, function(source, _)
            openStaff(source)
        end)
    else
        RegisterCommand(Config.CommandPlayer, function(s, _, _)
            if s == 0 then return end
            openReport(s)
        end, false)
        RegisterCommand(Config.CommandAdmin, function(s, _, _)
            if s == 0 then return end
            openStaff(s)
        end, false)
    end
end

function JGR_Fw.GetDroppedCitizenId(src)
    local P = JGR_Fw.GetPlayer(src)
    if P then return P:getIdentifier() end
    return JGR_Fw.LicenseIdentifier(src)
end

CreateThread(function()
    JGR_Fw.Init()
    if fw() == 'esx' then
        JGR_Fw.WaitForESX()
    end
    JGR_Fw.RegisterAllCallbacks()
    JGR_Fw.RegisterCommands()
end)
