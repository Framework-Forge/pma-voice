const mutedPlayers = new Map();
// muteply is a toggle; a cancelled timer must never survive a subsequent mute.
RegisterCommand('muteply', (source, args) => {
    const player = Number(args[0]);
    const duration = args[1] === undefined ? 900 : Number(args[1]);
    const voice = exports[GetCurrentResourceName()];
    if (!Number.isInteger(player) || player <= 0 || !Number.isInteger(duration)
        || duration < 1 || duration > 86400 || !voice.isValidPlayer(player)) return;

    const previous = mutedPlayers.get(player);
    if (previous) clearTimeout(previous.timer);
    mutedPlayers.delete(player);

    const muted = !MumbleIsPlayerMuted(player);
    MumbleSetPlayerMuted(player, muted);
    voice.SetVoiceState(player, 'muted', muted);
    emit('pma-voice:playerMuted', player, source, muted, duration);
    if (!muted) return;

    const entry = {};
    entry.timer = setTimeout(() => {
        // Ignore a cancelled timer or an ID reused by a different session.
        if (mutedPlayers.get(player) !== entry) return;
        mutedPlayers.delete(player);
        if (!voice.isValidPlayer(player)) return;
        MumbleSetPlayerMuted(player, false);
        voice.SetVoiceState(player, 'muted', false);
    }, duration * 1000);
    mutedPlayers.set(player, entry);
}, true);

on('playerDropped', () => {
    const player = Number(global.source);
    const entry = mutedPlayers.get(player);
    if (entry) clearTimeout(entry.timer);
    mutedPlayers.delete(player);
});
