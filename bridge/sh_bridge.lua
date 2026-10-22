--[[
    Detección de framework compartida (cliente y servidor).
    Orden en modo 'auto': qbx_core -> qb-core -> es_extended -> ox_core -> standalone.
    ox_core se trata como standalone (identidad por license, staff por ACE / lista de licencias).
]]

JGRReportsBridge = JGRReportsBridge or {}

local DETECT_ORDER = {
    { id = 'qbox', resource = 'qbx_core' },
    { id = 'qb', resource = 'qb-core' },
    { id = 'esx', resource = 'es_extended' },
    { id = 'standalone', resource = 'ox_core' },
}

local RESOURCE_BY_ID = {
    qb = 'qb-core',
    qbox = 'qbx_core',
    esx = 'es_extended',
}

local ALIASES = {
    qbx = 'qbox', qbx_core = 'qbox',
    qbcore = 'qb', ['qb-core'] = 'qb',
    es_extended = 'esx',
    ox = 'standalone', ox_core = 'standalone', none = 'standalone',
}

local function waitStarted(resource, timeoutMs)
    local waited = 0
    while GetResourceState(resource) ~= 'started' do
        local state = GetResourceState(resource)
        if state == 'missing' or state == 'stopped' or waited >= (timeoutMs or 30000) then
            return false
        end
        Wait(100)
        waited = waited + 100
    end
    return true
end

--- Devuelve 'qb' | 'qbox' | 'esx' | 'standalone'. Puede esperar (llamar dentro de un hilo).
function JGRReportsBridge.Resolve()
    if JGRReportsBridge.framework then return JGRReportsBridge.framework end

    local wanted = tostring(Config.Framework or 'auto'):lower()
    wanted = ALIASES[wanted] or wanted

    if wanted == 'auto' then
        wanted = 'standalone'
        for _, fw in ipairs(DETECT_ORDER) do
            if GetResourceState(fw.resource) ~= 'missing' and waitStarted(fw.resource, 30000) then
                wanted = fw.id
                break
            end
        end
    elseif RESOURCE_BY_ID[wanted] then
        if not waitStarted(RESOURCE_BY_ID[wanted], 60000) then
            print(('^1[JGR_Reports]^7 Config.Framework = \'%s\' pero %s no está iniciado. Se usa modo standalone.'):format(wanted, RESOURCE_BY_ID[wanted]))
            wanted = 'standalone'
        end
    elseif wanted ~= 'standalone' then
        print(('^3[JGR_Reports]^7 Config.Framework desconocido (\'%s\'); se usa detección automática.'):format(tostring(Config.Framework)))
        Config.Framework = 'auto'
        return JGRReportsBridge.Resolve()
    end

    JGRReportsBridge.framework = wanted
    return wanted
end

--- Framework ya resuelto (nil si todavía no ha terminado la detección).
function JGRReportsBridge.Current()
    return JGRReportsBridge.framework
end
