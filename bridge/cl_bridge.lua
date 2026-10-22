--[[
    Client bridge: qb-core, qbx_core (Qbox), es_extended, standalone / ox_core.
]]

JGR_FW = JGR_FW or {}
JGR_FW._pending = {}
JGR_FW._req = 0

local QBCore = nil
local ESX = nil

local function fw()
    return JGRReportsBridge.Current()
end

CreateThread(function()
    local f = JGRReportsBridge.Resolve()
    if f == 'qb' then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        QBCore = ok and core or nil
    elseif f == 'esx' then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        ESX = ok and obj or nil
    end
    -- Qbox: exports.qbx_core:* directamente (exports.qbx_core:GetCoreObject() NO existe).
end)

function JGR_FW.Notify(msg, nType, duration)
    nType = nType or 'primary'
    duration = duration or 5000
    local f = fw()
    if f == 'qb' and QBCore then
        QBCore.Functions.Notify(msg, nType, duration)
    elseif f == 'qbox' then
        exports.qbx_core:Notify(msg, nType == 'primary' and 'inform' or nType, duration)
    elseif f == 'esx' and ESX then
        if ESX.ShowNotification then
            ESX.ShowNotification(msg)
        else
            TriggerEvent('esx:showNotification', msg)
        end
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(tostring(msg))
        EndTextCommandThefeedPostTicker(false, true)
    end
end

RegisterNetEvent('jgr_reports:client:notify', function(msg, nType, duration)
    JGR_FW.Notify(msg, nType, duration)
end)

--- QBCore y ESX usan sus callbacks; Qbox y standalone (o si el framework aún no ha cargado) usan
--- el sistema interno por eventos, que el servidor atiende siempre.
function JGR_FW.TriggerCallback(name, cb, ...)
    local f = fw()
    if f == 'qb' and QBCore then
        QBCore.Functions.TriggerCallback(name, cb, ...)
    elseif f == 'esx' and ESX then
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
