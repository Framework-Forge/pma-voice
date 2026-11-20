-- Amplification lives in PMA, so other resources never overwrite the voice
-- natives. Normal/custom proximity modes and radio/call channels stay intact.
PMAMegaphone = {}
local wanted, transmitting, pttRunning = nil, false, false
local transmitRange
local baseRange = MumbleGetTalkerProximity()
local speakers, applied = {}, {}
local effect = CreateAudioSubmix('ForgeMegaphone')
SetAudioSubmixEffectRadioFx(effect, 0)
SetAudioSubmixEffectParamInt(effect, 0, GetHashKey('default'), 1)
SetAudioSubmixEffectParamFloat(effect, 0, GetHashKey('freq_low'), 450.0)
SetAudioSubmixEffectParamFloat(effect, 0, GetHashKey('freq_hi'), 3500.0)
SetAudioSubmixEffectParamFloat(effect, 0, GetHashKey('o_freq_lo'), 450.0)
SetAudioSubmixEffectParamFloat(effect, 0, GetHashKey('o_freq_hi'), 3500.0)
SetAudioSubmixEffectParamFloat(effect, 0, GetHashKey('rm_mix'), 0.16)
AddAudioSubmixOutput(effect, 0)

-- Local sidetone uses an independent NUI microphone/output. Never replace
-- PMA's voice target with server loopback: that would stop normal recipients.
local monitorRequest, monitorStatus, monitorEnabled, monitorVolume = 0, 'idle', false, 0
local monitorEffect = true
local function refreshMonitor(active)
    local volume = math.max(0, math.min(100, GetConvarInt('voice_megaphoneMonitorVolume', 30))) / 100
    local enabled = active == true and GetConvarInt('voice_megaphoneMonitor', 1) == 1 and volume > 0
    local radioEffect = GetConvarInt('voice_megaphoneRadioEffect', 1) == 1
    if enabled == monitorEnabled and (not enabled or volume == monitorVolume and radioEffect == monitorEffect) then return end
    monitorRequest = monitorRequest + 1
    monitorEnabled, monitorVolume = enabled, volume
    monitorEffect = radioEffect
    monitorStatus = enabled and 'pending' or 'idle'
    -- Do not await uiReady or microphone permission on the transmission path.
    -- The browser's ready callback recovers a message sent before it loaded.
    SendNUIMessage({ action = 'pmaMegaphoneMonitor', enabled = enabled,
        request = monitorRequest, volume = volume, effect = radioEffect })
end

local monitorNotices = {
    permission_pending = 'Retorno de voz: na primeira utilizacao, abra F8 e autorize o microfone da interface. Depois segure a tecla do megafone novamente.',
    denied = 'Retorno de voz: acesso ao microfone da interface negado. Verifique a permissao do FiveM; a transmissao normal nao foi desligada.',
    unavailable = 'Retorno de voz: este cliente nao disponibilizou a captura de microfone da interface. A transmissao normal continua independente.',
    device_error = 'Retorno de voz: nao foi possivel acessar o microfone padrao do Windows. A transmissao normal nao foi desligada.',
    playback_error = 'Retorno de voz: a interface nao conseguiu iniciar o audio local. Verifique as permissoes e o dispositivo padrao; a transmissao normal continua independente.',
}
RegisterNUICallback('megaphoneMonitorStatus', function(data, cb)
    cb({ ok = true })
    if type(data) ~= 'table' or data.request ~= monitorRequest or not monitorEnabled or not transmitting then return end
    local status = data.status
    if status ~= 'active' and not monitorNotices[status] then return end
    if status == monitorStatus then return end
    monitorStatus = status
    if monitorNotices[status] then
        TriggerEvent('pma-voice:megaphoneMonitorNotice', monitorNotices[status], status == 'permission_pending' and 'inform' or 'error')
    end
end)
RegisterNUICallback('megaphoneMonitorReady', function(_, cb)
    cb({ action = 'pmaMegaphoneMonitor', enabled = monitorEnabled and transmitting,
        request = monitorRequest, volume = monitorVolume, effect = monitorEffect })
end)

local function settingsValid(settings)
    return type(settings) == 'table' and type(settings.range) == 'number' and settings.range > 0
        and settings.range <= math.max(1, GetConvarInt('voice_megaphoneMaxRange', 50))
        and type(settings.volume) == 'number' and settings.volume >= 0 and settings.volume <= 1
        and (settings.farVolume == nil or type(settings.farVolume) == 'number'
            and settings.farVolume >= 0 and settings.farVolume <= settings.volume)
end
local function effectiveRange(settings)
    return math.min(settings.range, math.max(1, GetConvarInt('voice_megaphoneRange', 200)))
end

function PMAMegaphone.canTransmit()
    if gameVersion ~= 'fivem' then return false, 'unsupported_game' end
    if GetConvarInt('voice_enableMegaphone', 1) ~= 1 then return false, 'megaphone_disabled' end
    if GetConvar('voice_useNativeAudio', 'false') ~= 'true' then return false, 'native_audio_disabled' end
    if GetConvarInt('voice_enableSubmix', 1) ~= 1 then return false, 'submix_disabled' end
    if not MumbleIsConnected() then return false, 'voice_disconnected' end
    if PMAUsesProximityVoice == false then return false, 'proximity_disabled' end
    if not isInitialized then
        if PMAEnsureVoiceInitialized then PMAEnsureVoiceInitialized() end
        return false, 'voice_initializing'
    end
    if PMAState.identifier == nil then return false, 'character_unavailable' end
    if PMAState.disableProximity then return false, 'proximity_disabled' end
    if radioPressed or PMAState.radioActive then return false, 'radio_active' end
    if (PMAState.callChannel or 0) ~= 0 then return false, 'call_active' end
    if isDead() then return false, 'incapacitated' end
    return true
end

function PMAMegaphone.range()
    return transmitting and transmitRange or nil
end

function PMAMegaphone.setBaseRange(range)
    baseRange = range + 0.0
    MumbleSetTalkerProximity(PMAMegaphone.range() or baseRange)
end

local function refreshTransmission()
    local settings = PMAState.megaphone
    local enabled = wanted ~= nil and settingsValid(settings) and settings.token == wanted and PMAMegaphone.canTransmit()
    local range = enabled and effectiveRange(settings) or nil
    if enabled ~= transmitting or enabled and transmitRange ~= range then
        transmitting = enabled
        transmitRange = range
        MumbleSetTalkerProximity(range or baseRange)
        if isInitialized then addNearbyPlayers() end
        TriggerEvent('pma-voice:megaphoneActive', enabled)
    end
    refreshMonitor(enabled)
    if enabled and not pttRunning then
        pttRunning = true
        CreateThread(function()
            while transmitting do
                if not PMAMegaphone.canTransmit() then PMAMegaphone.interrupt() break end
                SetControlNormal(0, 249, 1.0)
                SetControlNormal(1, 249, 1.0)
                SetControlNormal(2, 249, 1.0)
                Wait(0) -- Only while actually transmitting, no idle frame loop.
            end
            pttRunning = false
        end)
    end
    return enabled
end

function PMAMegaphone.interrupt()
    local wasWanted = wanted ~= nil
    wanted = nil
    refreshTransmission()
    if wasWanted then TriggerEvent('pma-voice:megaphoneInterrupted') end
end

exports('canUseMegaphone', PMAMegaphone.canTransmit)
exports('getMegaphoneStatus', function()
    local ready, reason = PMAMegaphone.canTransmit()
    return {
        ready = ready, reason = reason,
        connected = MumbleIsConnected(), initialized = isInitialized == true,
        characterLoaded = PMAState.identifier ~= nil,
        nativeAudio = GetConvar('voice_useNativeAudio', 'false') == 'true',
        submix = GetConvarInt('voice_enableSubmix', 1) == 1,
        megaphoneEnabled = GetConvarInt('voice_enableMegaphone', 1) == 1,
        proximityEnabled = PMAUsesProximityVoice ~= false and not PMAState.disableProximity,
        radioActive = radioPressed == true or PMAState.radioActive == true,
        callActive = (PMAState.callChannel or 0) ~= 0, incapacitated = isDead(),
        monitorEnabled = GetConvarInt('voice_megaphoneMonitor', 1) == 1,
        monitorVolume = math.max(0, math.min(100, GetConvarInt('voice_megaphoneMonitorVolume', 30))),
        monitorStatus = monitorStatus, monitorActive = monitorStatus == 'active' and monitorEnabled and transmitting,
        effectEnabled = GetConvarInt('voice_megaphoneRadioEffect', 1) == 1,
    }
end)
exports('setMegaphoneInput', function(token)
    if GetInvokingResource() ~= 'forge-siren' then return false end
    if token ~= false and (type(token) ~= 'number' or token <= 0 or token % 1 ~= 0 or token == math.huge) then return false end
    wanted = token ~= false and token or nil
    refreshTransmission()
    return true
end)

-- Return true when this module owns the volume/submix. Radio, phone and
-- explicit player muting always have priority over megaphone reception.
function PMAMegaphone.apply(player, force)
    local settings = speakers[player]
    if not settings or radioData[player] or callData[player] then applied[player] = nil return false end
    local target = GetPlayerFromServerId(player)
    local ped = target ~= -1 and GetPlayerPed(target) or 0
    local distance = ped ~= 0 and DoesEntityExist(ped)
        and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped)) or math.huge
    local range = effectiveRange(settings)
    local inRange = distance <= range
    local muted = isVoicePlayerMuted(player)
    local nearVolume = math.min(settings.volume,
        math.max(0, math.min(100, GetConvarInt('voice_megaphoneListenerVolume', 100))) / 100)
    local farVolume = math.min(settings.farVolume or settings.volume, nearVolume,
        math.max(0, math.min(100, GetConvarInt('voice_megaphoneFarVolume', 100))) / 100)
    local nearDistance = math.min(5.0, range * 0.2)
    local fade = math.max(0.0, math.min(1.0, (distance - nearDistance) / (range - nearDistance)))
    local volume = not muted and inRange and (nearVolume + (farVolume - nearVolume) * fade) or 0.0
    -- Quantization prevents redundant native calls for imperceptible movement.
    volume = math.floor(volume * 100 + 0.5) / 100
    local submix = inRange and not muted and GetConvarInt('voice_enableSubmix', 1) == 1
        and GetConvarInt('voice_megaphoneRadioEffect', 1) == 1 and effect or -1
    local signature = tostring(volume) .. ':' .. submix
    if force or applied[player] ~= signature then
        MumbleSetVolumeOverrideByServerId(player, volume)
        MumbleSetSubmixForServerId(player, submix)
        applied[player] = signature
    end
    return true
end

function PMAMegaphone.refresh()
    if transmitting then
        if not PMAMegaphone.canTransmit() then PMAMegaphone.interrupt()
        elseif settingsValid(PMAState.megaphone) and transmitRange ~= effectiveRange(PMAState.megaphone) then refreshTransmission() end
    end
    refreshMonitor(transmitting)
    for player in pairs(speakers) do PMAMegaphone.apply(player) end
end

local function clearSpeaker(player)
    speakers[player], applied[player] = nil, nil
    if not radioData[player] and not callData[player] then
        MumbleSetVolumeOverrideByServerId(player, isVoicePlayerMuted(player) and 0.0 or -1.0)
        restoreDefaultSubmix(player)
    end
end

AddEventHandler('pma-voice:cache:changed', function(player, state)
    if player == playerServerId then
        if wanted and (state.disableProximity or state.radioActive or (state.callChannel or 0) > 0) then
            PMAMegaphone.interrupt()
        else refreshTransmission() end
        return
    end
    if settingsValid(state.megaphone) then
        speakers[player], applied[player] = state.megaphone, nil
        PMAMegaphone.apply(player)
    elseif speakers[player] then clearSpeaker(player) end
end)
AddEventHandler('pma-voice:radioActive', function(active) if active then PMAMegaphone.interrupt() end end)
AddEventHandler('mumbleDisconnected', PMAMegaphone.interrupt)
AddEventHandler('pr_bridge:client:OnPlayerUnloaded', PMAMegaphone.interrupt)
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() and resource ~= 'forge-siren' then return end
    PMAMegaphone.interrupt()
    if resource == GetCurrentResourceName() then
        for player in pairs(speakers) do clearSpeaker(player) end
    end
end)
