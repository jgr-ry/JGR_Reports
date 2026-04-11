--[[
    Client bridge: qb-core, qbx_core, es_extended, standalone.
]]

JGR_FW = JGR_FW or {}
JGR_FW._pending = {}
JGR_FW._req = 0

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

local function qbCoreExportName()
    local f = fw()
    if f == 'qb' then return 'qb-core' end
    if f == 'qbox' then return 'qbx_core' end
    return nil
end

local ESX_EXPORT = 'es_extended'

function JGR_FW.Init()
    if isQB() then
        local res = qbCoreExportName()
        if res then
            local ok, core = pcall(function()
                return exports[res]:GetCoreObject()
            end)
            QBCore = ok and core or nil
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

CreateThread(function()
    JGR_FW.Init()
    if fw() == 'esx' and not ESX then
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
    end
end)

function JGR_FW.Notify(msg, nType, duration)
    nType = nType or 'primary'
    duration = duration or 5000
    if isQB() and QBCore then
        QBCore.Functions.Notify(msg, nType, duration)
    elseif fw() == 'esx' and ESX then
        if ESX.ShowNotification then
            ESX.ShowNotification(msg)
        else
            TriggerEvent('esx:showNotification', msg)
        end
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

RegisterNetEvent('jgr_reports:client:notify', function(msg, nType, duration)
    JGR_FW.Notify(msg, nType, duration)
end)

function JGR_FW.TriggerCallback(name, cb, ...)
    if isQB() and QBCore then
        QBCore.Functions.TriggerCallback(name, cb, ...)
    elseif fw() == 'esx' and ESX then
        ESX.TriggerServerCallback(name, cb, ...)
    else
        JGR_FW._req = JGR_FW._req + 1
        local rid = JGR_FW._req
        JGR_FW._pending[rid] = cb
        TriggerServerEvent('jgr_reports:internal:cb', name, rid, ...)
    end
end

RegisterNetEvent('jgr_reports:internal:cb_res', function(rid, ...)
    local fn = JGR_FW._pending[rid]
    JGR_FW._pending[rid] = nil
    if fn then fn(...) end
end)
