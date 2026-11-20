-- Only a trusted server resource can grant amplification. Never accept a
-- client-supplied source/range/submix, or add this key to cache.lua's writers.
local owners = {}
exports('setPlayerMegaphone', function(player, settings)
    local owner = GetInvokingResource()
    if owner ~= 'forge-siren' then return false end
    player = tonumber(player)
    if not player or not GetPlayerName(player) then return false end
    if settings == false then
        owners[player] = nil
        PMACache.set(player, 'megaphone', nil)
        return true
    end
    if GetConvarInt('voice_enableMegaphone', 1) ~= 1 or type(settings) ~= 'table' then return false end
    local range, volume, token = settings.range, settings.volume, settings.token
    local farVolume = settings.farVolume == nil and volume or settings.farVolume
    if type(range) ~= 'number' or range ~= range or range <= 0 or range == math.huge
        or type(volume) ~= 'number' or volume ~= volume or volume < 0 or volume > 1
        or type(farVolume) ~= 'number' or farVolume ~= farVolume or farVolume < 0 or farVolume > volume
        or type(token) ~= 'number' or token <= 0 or token % 1 ~= 0 or token == math.huge then return false end
    owners[player] = owner
    local cappedVolume = math.min(volume, math.max(0, math.min(100, GetConvarInt('voice_megaphoneListenerVolume', 100))) / 100)
    PMACache.set(player, 'megaphone', {
        range = math.min(range, math.max(1, GetConvarInt('voice_megaphoneMaxRange', 50)),
            math.max(1, GetConvarInt('voice_megaphoneRange', 200))),
        volume = cappedVolume, farVolume = math.min(farVolume, cappedVolume), token = token,
    })
    return true
end)

AddEventHandler('onResourceStop', function(resource)
    for player, owner in pairs(owners) do
        if resource == owner or resource == GetCurrentResourceName() then
            PMACache.set(player, 'megaphone', nil)
            owners[player] = nil
        end
    end
end)
AddEventHandler('playerDropped', function() owners[source] = nil end)
AddEventHandler('pr_bridge:server:OnPlayerUnloaded', function(player)
    player = tonumber(player)
    if player then owners[player] = nil PMACache.set(player, 'megaphone', nil) end
end)
-- A PMA restart must not revive a grant left in the bridge's resource cache.
CreateThread(function()
    for _, player in ipairs(GetPlayers()) do PMACache.set(tonumber(player), 'megaphone', nil) end
end)
