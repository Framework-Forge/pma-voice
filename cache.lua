-- Resource-owned voice cache. Channel assignment remains server-authoritative.
PMACache = {}
local cache, server = pr_lib.cache, IsDuplicityVersion()
local prefix = 'pma-voice:'
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}; for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function playerKey(id) return prefix .. 'player:' .. tostring(id) end
local function selfId() return GetPlayerServerId(PlayerId()) end
local generation = server and (os.time() + GetGameTimer() / 1000) or nil
if server then
    generation=math.max(generation,(cache.get(prefix..'generation') or 0)+1)
    cache.set(prefix..'generation',generation)
end
local revision, lastGeneration, lastRevision = 0, nil, -1
local function notify(id, old, value)
    if not equal(old.submix, value.submix) then TriggerEvent('pma-voice:cache:submix', id, value.submix) end
    TriggerEvent('pma-voice:cache:changed', id, copy(value))
end
function PMACache.get(id) return copy(cache.get(playerKey(tonumber(id))) or {}) end
function PMACache.set(id, key, value)
    id = tonumber(id); if not id then return false end
    local old = PMACache.get(id)
    if equal(old[key], value) then return true end
    local record = copy(old); record[key] = copy(value)
    cache.set(playerKey(id), record)
    notify(id, old, record)
    if server then
        revision = revision + 1
        TriggerClientEvent('pma-voice:cache:update', -1, generation, revision, id, record)
    end
    return true
end
local allowed = {
    radio = function(v) return type(v)=='number' and v>=0 and v<=100 end,
    call = function(v) return type(v)=='number' and v>=0 and v<=100 end,
    click_on = function(v) return type(v)=='number' and v>=0 and v<=100 end,
    click_off = function(v) return type(v)=='number' and v>=0 and v<=100 end,
    radioActive = function(v) return type(v)=='boolean' end,
    disableProximity = function(v) return type(v)=='boolean' end,
    disableRadio = function(v) return type(v)=='number' and v>=0 and v<=65535 and v%1==0 end,
    voiceIntent = function(v) return v=='speech' or v=='music' end,
    submix = function(v) return v==nil or (type(v)=='string' and #v<=64) end,
    proximity = function(v) return type(v)=='table' and type(v.index)=='number' and v.index>=1 and v.index<=100
        and type(v.distance)=='number' and v.distance>=0 and v.distance<=1000 and type(v.mode)=='string' and #v.mode<=64 end,
}
exports('GetVoiceState', function(id) return PMACache.get(id or (not server and selfId())) end)
if server then
    function PMACache.clear(id)
        id = tonumber(id); if not id then return end
        cache.clear(playerKey(id)); revision = revision + 1
        TriggerClientEvent('pma-voice:cache:update', -1, generation, revision, id, false)
    end
    exports('SetVoiceState', PMACache.set)
    pr_lib.callback.register('pma-voice:cache:snapshot', function(src)
        voiceData[src] = voiceData[src] or defaultTable(src)
        local players = {}
        for _, id in ipairs(GetPlayers()) do players[tostring(id)] = PMACache.get(id) end
        return { generation=generation, revision=revision, players=players }
    end)
    RegisterNetEvent('pma-voice:cache:write', function(key, value)
        local src = source
        if not voiceData[src] or not allowed[key] or not allowed[key](value) then return end
        PMACache.set(src, key, value)
    end)
    AddEventHandler('pr_bridge:server:OnPlayerLoaded', function(src)
        src=tonumber(src); if not src then return end
        voiceData[src] = voiceData[src] or defaultTable(src)
        local identifier = pr_lib.framework.GetIdentifier(src)
        PMACache.set(src, 'identifier', identifier)
    end)
    AddEventHandler('pr_bridge:server:OnPlayerUnloaded', function(src)
        src=tonumber(src); if not src or not voiceData[src] then return end
        setPlayerRadio(src, 0); setPlayerCall(src, 0)
        PMACache.set(src, 'identifier', nil)
        PMACache.set(src, 'radioActive', false)
        PMACache.set(src, 'disableRadio', 0)
        PMACache.set(src, 'submix', nil)
    end)
else
    local known, versions, pending = {}, {}, {}
    local function preservePending(id,record)
        record=copy(record)
        if id==selfId() then
            for key,change in pairs(pending) do
                if equal(record[key],change.value) then pending[key]=nil
                else record[key]=copy(change.value) end
            end
        end
        return record
    end
    local function flushPending()
        if not PMACache.get(selfId()).assignedChannel then return end
        for key,change in pairs(pending) do TriggerServerEvent('pma-voice:cache:write',key,change.value) end
    end
    local function accept(gen, rev)
        if type(gen)~='number' or type(rev)~='number' then return false end
        if lastGeneration and (gen<lastGeneration or (gen==lastGeneration and rev<=lastRevision)) then return false end
        if gen~=lastGeneration then
            for id in pairs(known) do cache.clear(playerKey(id)) end
            known={}; versions={}; lastRevision=-1
        end
        lastGeneration, lastRevision = gen, rev
        return true
    end
    RegisterNetEvent('pma-voice:cache:update', function(gen, rev, id, record)
        if source~=65535 or not accept(gen,rev) then return end
        local old=PMACache.get(id)
        versions[id]=rev
        if record==false then
            cache.clear(playerKey(id)); known[id]=nil
            notify(id,old,{})
        elseif type(record)=='table' then
            record=preservePending(id,record)
            cache.set(playerKey(id),copy(record)); known[id]=true; notify(id,old,record)
        end
    end)
    function PMACache.refresh()
        local ok, packet=pcall(pr_lib.callback.await,'pma-voice:cache:snapshot',false)
        if not ok or type(packet)~='table' or type(packet.players)~='table' then return false end
        if type(packet.generation)~='number' or type(packet.revision)~='number' then return false end
        if lastGeneration and packet.generation<lastGeneration then return true end
        if packet.generation~=lastGeneration then accept(packet.generation,packet.revision) end
        lastRevision=math.max(lastRevision,packet.revision)
        for playerId,record in pairs(packet.players) do
            local id=tonumber(playerId)
            if id and type(record)=='table' and (versions[id] or -1)<=packet.revision then
                record=preservePending(id,record)
                local old=PMACache.get(id); cache.set(playerKey(id),copy(record)); known[id]=true; notify(id,old,record)
                versions[id]=packet.revision
            end
        end
        for id in pairs(known) do
            if packet.players[tostring(id)]==nil and packet.players[id]==nil and (versions[id] or -1)<=packet.revision then
                local old=PMACache.get(id); cache.clear(playerKey(id)); known[id]=nil; versions[id]=packet.revision; notify(id,old,{})
            end
        end
        flushPending()
        return true
    end
    PMAState=setmetatable({}, {
        __index=function(_,key) return PMACache.get(selfId())[key] end,
        __newindex=function(_,key,value)
            if allowed[key] and allowed[key](value) then pending[key]={value=copy(value)} end
            PMACache.set(selfId(),key,value)
            if allowed[key] and allowed[key](value) and PMACache.get(selfId()).assignedChannel then TriggerServerEvent('pma-voice:cache:write',key,value) end
        end,
    })
    function PMAStateSet(key,value) PMAState[key]=value end
    exports('SetVoiceState', function(key,value)
        if not allowed[key] or not allowed[key](value) then return false end
        PMAStateSet(key,value); return true
    end)
    CreateThread(function()
        while not PMACache.refresh() do Wait(2000) end
    end)
    AddEventHandler('pr_bridge:client:OnPlayerLoaded', function() PMACache.refresh() end)
    AddEventHandler('pr_bridge:client:OnPlayerUnloaded', function()
        pending={}
        local id=selfId()
        PMACache.set(id,'identifier',nil)
        PMACache.set(id,'radioChannel',0)
        PMACache.set(id,'callChannel',0)
        PMACache.set(id,'radioActive',false)
        PMACache.set(id,'disableRadio',0)
    end)
end
