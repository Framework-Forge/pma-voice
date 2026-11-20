isInitialized = false

local initializationGeneration, pendingGeneration, runningGeneration = 0, nil, nil
local initializedChannel

local function initializeVoice(generation)
	local deadline = GetGameTimer() + 10000
	local function current()
		return generation == initializationGeneration and MumbleIsConnected() and PMAUsesProximityVoice ~= false
	end
	local channel = PMAState.assignedChannel
	while type(channel) ~= 'number' or channel <= 0 or channel % 1 ~= 0 do
		if not current() then return false, 'disconnected' end
		if GetGameTimer() >= deadline then return false, 'assigned_channel_timeout' end
		Wait(100)
		channel = PMAState.assignedChannel
	end
	if not current() then return false, 'disconnected' end
	local voiceModeData = Cfg.voiceModes[mode]
	PMAStateSet('proximity', { index = mode, distance = voiceModeData[1], mode = voiceModeData[2] })
	if PMAMegaphone then PMAMegaphone.setBaseRange(voiceModeData[1])
	else MumbleSetTalkerProximity(voiceModeData[1] + 0.0) end
	MumbleClearVoiceTarget(voiceTarget)
	MumbleSetVoiceTarget(voiceTarget)
	MumbleSetVoiceChannel(channel)

	while MumbleGetVoiceChannelFromServerId(playerServerId) ~= channel do
		if not current() then return false, 'disconnected' end
		if PMAState.assignedChannel ~= channel then return false, 'channel_changed' end
		if GetGameTimer() >= deadline then return false, 'channel_sync_timeout' end
		Wait(100)
		if not current() then return false, 'disconnected' end
		if PMAState.assignedChannel ~= channel then return false, 'channel_changed' end
		MumbleSetVoiceChannel(channel)
	end
	if not current() then return false, 'disconnected' end
	if PMAState.assignedChannel ~= channel then return false, 'channel_changed' end

	isInitialized = true
	initializedChannel = channel
	MumbleAddVoiceTargetChannel(voiceTarget, channel)
	addNearbyPlayers()
	return true
end

-- One bounded attempt at a time. Disconnect invalidates suspended attempts so
-- an old coroutine cannot overwrite the next connection's targets/readiness.
function handleInitialState()
	local generation = initializationGeneration
	if not MumbleIsConnected() or PMAUsesProximityVoice == false or runningGeneration == generation then return false end
	runningGeneration = generation
	isInitialized = false
	local ok, initialized, reason = pcall(initializeVoice, generation)
	if runningGeneration == generation then runningGeneration = nil end
	if generation ~= initializationGeneration then return false end
	if not ok or not initialized then
		isInitialized = false
		if not ok then logger.warn('Voice initialization failed: %s', tostring(initialized))
		elseif reason ~= 'disconnected' then logger.warn('Voice initialization failed: %s', reason) end
		if reason == 'channel_changed' then PMAEnsureVoiceInitialized() end
		return false
	end
	logger.log('Finished connection logic')
	return true
end

function PMAEnsureVoiceInitialized()
	if not MumbleIsConnected() or PMAUsesProximityVoice == false then return false end
	if isInitialized then return true end
	local generation = initializationGeneration
	if runningGeneration == generation or pendingGeneration == generation then return false end
	pendingGeneration = generation
	CreateThread(function()
		if generation ~= initializationGeneration then return end
		pendingGeneration = nil
		if not isInitialized then handleInitialState() end
	end)
	return false
end

function PMACancelVoiceInitialization(keepReady)
	initializationGeneration = initializationGeneration + 1
	pendingGeneration, runningGeneration = nil, nil
	if not keepReady then isInitialized = false; initializedChannel = nil end
end

AddEventHandler('mumbleConnected', function(address, isReconnecting)
	logger.info('Connected to mumble server with address of %s, is this a reconnect %s',
		GetConvarInt('voice_hideEndpoints', 1) == 1 and 'HIDDEN' or address, isReconnecting)

	logger.log('Connecting to mumble, setting targets.')
	PMAEnsureVoiceInitialized()
end)

AddEventHandler('mumbleDisconnected', function(address)
	PMACancelVoiceInitialization()
	logger.info('Disconnected from mumble server with address of %s',
		GetConvarInt('voice_hideEndpoints', 1) == 1 and 'HIDDEN' or address)
end)

AddEventHandler('pma-voice:cache:changed', function(player, state)
	if player ~= playerServerId or PMAUsesProximityVoice == false then return end
	if isInitialized and state and type(state.assignedChannel) == 'number'
		and state.assignedChannel > 0 and state.assignedChannel ~= initializedChannel then
		PMACancelVoiceInitialization()
	end
	PMAEnsureVoiceInitialized()
end)

-- TODO: Convert the last Cfg to a Convar, while still keeping it simple.
AddEventHandler('pma-voice:settingsCallback', function(cb)
	cb(Cfg)
end)
