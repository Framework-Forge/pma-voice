AddEventHandler('pma-voice:cache:submix', function(playerSource, value)
	local tgtId = tonumber(playerSource)
	if not tgtId then return end
	-- We got an invalid submix, discard we don't care about it
	if value and not submixIndicies[value] then
		return logger.warn("Player %s applied submix %s but it isn't valid",
			tgtId, value)
	end

	-- Cache updates must not replace an active radio/call/megaphone effect.
	if not radioData[tgtId] and not callData[tgtId] then restoreDefaultSubmix(tgtId) end
end)

RegisterNetEvent("onPlayerDropped", function(tgtId)
	if not radioData[tgtId] and not callData[tgtId] then
		logger.info("Resetting submix for player %s", tgtId)
		MumbleSetSubmixForServerId(tgtId, -1)
	end
end)
