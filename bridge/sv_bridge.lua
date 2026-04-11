--[[
    Server bridge: qb-core, qbx_core (Qbox), es_extended, standalone.
]]

JGR_Fw = JGR_Fw or {}
JGR_Fw._serverCallbacks = {}

local QBCore = nil
local ESX = nil

local function fw()
    local f = (Config.Framework or 'qb'):lower()
    if f == 'qbx' then return 'qbox' end
    return f
end

local function isQB()
    local f = fw()
    return f == 'qb' or f == 'qbox'
end

--- Recurso de export según Config.Framework (sin entradas extra en config).
local function qbCoreExportName()
    local f = fw()
    if f == 'qb' then return 'qb-core' end
    if f == 'qbox' then return 'qbx_core' end
    return nil
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
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return 'license:temp_' .. tostring(src)
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
    if isQB() then
        local res = qbCoreExportName()
        if not res then return end
        local ok, core = pcall(function()
            return exports[res]:GetCoreObject()
        end)
        QBCore = ok and core or nil
        if not QBCore then
            print('^1[JGR_Reports] ^0No se pudo cargar ' .. res .. ' (Framework=' .. tostring(Config.Framework) .. ')^0')
        end
    elseif fw() == 'esx' then
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
    if isQB() and QBCore then
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
    if isQB() and QBCore then
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
    if isQB() and QBCore then
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
    if isQB() and QBCore then
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

function JGR_Fw.RegisterAllCallbacks()
    if isQB() and QBCore then
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
    local fn = JGR_Fw._serverCallbacks[name]
    if not fn then return end
    fn(src, function(...)
        TriggerClientEvent('jgr_reports:internal:cb_res', src, reqId, ...)
    end, ...)
end)

function JGR_Fw.RegisterCommands()
    local function openReport(src)
        local P = JGR_Fw.GetPlayer(src)
        if not P then return end
        MySQL.query('SELECT * FROM jgr_reports WHERE citizenid = ? AND status IN (\'Abierto\', \'En progreso\') LIMIT 1', { P:getIdentifier() }, function(result)
            if result[1] then
                TriggerClientEvent('jgr_reports:client:openActiveReport', src, result[1])
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

    if isQB() and QBCore then
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
