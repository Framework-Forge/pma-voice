## PLEASE NOTE: Currently master branch has some breaking changes

If you previously used `voice_defaultPhoneVolume` you will instead need to use `voice_defaultCallVolume`
If you previously used `voice_enablePhones` you will instead need to use `voice_enableCalls`

If you were previously using the state bag getter `Player(source).state.phone` you will instead need to use `Player(source).state.call`

# pma-voice
A voice system designed around the use of FiveM/RedM internal mumble server.

## Support

Please report any issues you have in the GitHub [Issues](https://github.com/AvarianKnight/pma-voice/issues)

# Compatibility Notice:

This script is not compatible with other voice systems (duh), that means if you have vMenus voice chat you will **have** to [disable](https://docs.vespura.com/vmenu/faq/#q-how-do-i-disable-voice-chat) it.

Please do not override `NetworkSetTalkerProximity`, `MumbleSetTalkerProximity`, `MumbleSetAudioInputDistance`, `MumbleSetAudioOutputDistance` or `NetworkSetVoiceActive` in any of your other scripts as there have been cases where it breaks pma-voice.

# Credits

- @Frazzle for mumble-voip (for which the concept came from)
- @pichotm for pVoice (where the grid concept came from)

# FiveM/RedM Config

### NOTE: Only use one of the Audio options (don't enable 3d Audio & Native Audio at the same time), its also recommended to always use voice_useSendingRangeOnly.

You only need to add the convar **if** you're changing the value.

All of the configs here are set using `setr [voice_configOption] [boolean]`

| ConVar                     | Default | Description                                                   | Parameter(s) |
|----------------------------|---------|---------------------------------------------------------------|--------------|
| voice_useNativeAudio       |  false  | Uses the games native audio, will add 3d sound, echo, reverb, and more. **Required for submixs**   | boolean      |
| voice_use2dAudio           |  false  | Uses 2d audio, will result in same volume sound no matter where they're at until they leave proximity. | boolean
| voice_use3dAudio           |  false  | Uses 3d audio | boolean |
| voice_useSendingRangeOnly  |  false  | Only allows you to hear people within your hear/send range, prevents people from connecting to your mumble server and trolling. | boolean      |

# Config

### PLEASE NOTE: Any keybind changes only affect new players, if you want to change your key bind go to Key Bindings -> FiveM -> Look for keybinds under 'pma-voice'.

All of the config is done via ConVars in order to streamline the process.

The ints are used like a boolean to 0 would be false, 1 true.

All of the configs here are set using `setr [voice_configOption] [int]` OR `setr [voice_configOption] "[string]"`

#### Note: If a convar defaults to 1 (true) you don't have set it again unless you want to disable it.

### General Voice Settings

| ConVar                  | Default | Description                                                        | Parameter(s) |
|-------------------------|---------|--------------------------------------------------------------------|--------------|
| voice_enableUi               |    1    | Enables the built in user interface                            | int          |
| voice_enableProximityCycle   |    1    | Enables the usage of the F11 proximity key, if disabled players are stuck on the first proximity  | int          |
| voice_defaultCycle           |   F11   | The default key to cycle the players proximity. You can find a list of valid keys [in the Cfx docs](https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/)                | string       |
| voice_defaultRadioVolume          |   30   | The default volume to set the radio to (has to be between 1 and 100) *NOTE: Only new joins will have the new value, players that already joined will not.* | float       |
| voice_defaultCallVolume          |   60   | The default volume to set the call to (has to be between 1 and 100) *NOTE: Only new joins will have the new value, players that already joined will not.* | float       |
| voice_onClickVolume          |   10   | The default volume to set the radio turn on mic click's to (has to be between 1 and 100) *NOTE: Only new joins will have the new value, players that already joined will not.* | float       |
| voice_offClickVolume          |   3   | The default volume to set the radio turn off mic click's to (has to be between 1 and 100) *NOTE: Only new joins will have the new value, players that already joined will not.* | float       |
| voice_defaultVoiceMode  |  2      | Default proximity voice value when player joins server. (Voice Modes; 1:Whisper, 2:Normal, 3:Shouting) | int      |

### Call & Radio

| ConVar                  | Default | Description                                                        | Parameter(s) |
|-------------------------|---------|--------------------------------------------------------------------|--------------|
| voice_enableRadios           |    1    | Enables the radio sub-modules                                 | int          |
| voice_enableCalls           |    1    | Enables the call sub-modules                                 | int          |
| voice_enableSubmix      |    1    | Enables the submix which adds a radio/call style submix to their voice **NOTE: Submixs require native audio** | int          |
| voice_enableRadioAnim        |   1     | Enables (grab shoulder mic) animation while talking on the radio.          | int          |
| voice_defaultRadio           |   LMENU  | The default key to use the radio. You can find a list of valid keys [in the FiveM docs](https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/)                             | string       |

### Sync

| ConVar                  | Default | Description                                                        | Parameter(s) |
|-------------------------|---------|--------------------------------------------------------------------|--------------|
| voice_refreshRate   |   200    | How often the UI/Proximity is refreshed | int     |

### External Server & Misc.
| ConVar                  | Default | Description                                                        | Parameter(s) |
|-------------------------|---------|--------------------------------------------------------------------|--------------|
| voice_allowSetIntent         |   1  | Whether or not to allow players to set their audio intents (you can see more [here](https://docs.fivem.net/natives/?_0x6383526B))  | int       |
| voice_externalAddress        |   none  | The external address to use to connect to the mumble server   | string       |
| voice_externalPort           |   0     | The external port to use                                      | int          |
| voice_debugMode              |   0     | 1 for basic logs, 4 for verbose logs                          | int          |
| voice_externalDisallowJoin   |   0     | Disables players being allowed to join the server, should only be used if you're using a FXServer as a external mumble server. | int          |
| voice_hideEndpoints     | 1   | Hides the mumble address in logs *NOTE: You should only care to hide this for a external server.* | int        |



### Aces

pma-voice comes with a built in /muteply (tgtPly) (duration) command, in order to allow your staff to use it you will have to grand them the ace!

Example:
`add_ace group.superadmin command.muteply allow;`

This would only allow the superadmin group to mute players.

### Exports

#### Client

##### Setters

| Export              | Description                 | Parameter(s) |
|---------------------|-----------------------------|--------------|
| [setVoiceProperty](docs/client-setters/setVoiceProperty.md)    | Set config options          | string, any  |
| [setRadioChannel](docs/client-setters/setRadioChannel.md)     | Set radio channel           | int          |
| [setCallChannel](docs/client-setters/setCallChannel.md)      | Set call channel            | int          |
| [setRadioVolume](docs/client-setters/setRadioVolume.md)      | Set radio volume for player | int          |
| [setCallVolume](docs/client-setters/setCallVolume.md)        | Set call volume for player  | int          |
| [setMicClickOnVolume](docs/client-setters/setMicClickOnVolume.md)      | Set mic click on volume for player | int          |
| [setMicClickOffVolume](docs/client-setters/setCallVolume.md)        | Set mic click off volume for player  | int          |
| [addPlayerToRadio](docs/client-setters/setRadioChannel.md)      | Set radio channel        | int          |
| [addPlayerToCall](docs/client-setters/setCallChannel.md)       | Set call channel         | int          |
| [removePlayerFromRadio](docs/client-setters/removePlayerFromRadio.md) | Remove player from radio |              |
| [removePlayerFromCall](docs/client-setters/removePlayerFromCall.md)  | Remove player from call  |              |

##### Toggles

| Export              | Description                                            | Parameter(s) |
|---------------------|--------------------------------------------------------|--------------|
| toggleMutePlayer    | Toggles the selected player muted for the local client | int          |

Supported from mumble-voip / toko-voip

| Export                | Description              | Parameter(s) |
|-----------------------|--------------------------|--------------|
| [SetMumbleProperty](docs/client-setters/setVoiceProperty.md)     | Set config options       | string, any  |
| [SetTokoProperty](docs/client-setters/setVoiceProperty.md)       | Set config options       | string, any  |
| [SetRadioChannel](docs/client-setters/setRadioChannel.md)       | Set radio channel        | int          |
| [SetCallChannel](docs/client-setters/setCallChannel.md)        | Set call channel         | int          |

#### Getters

The majority of setters are done through player states.


| State Bag     | Description                                                  | Return Type  |
|---------------|--------------------------------------------------------------|--------------|
| [proximity](docs/state-getters/stateBagGetters.md)     | Returns a table with the mode index, distance, and mode name | table        |
| [radioChannel](docs/state-getters/stateBagGetters.md)  | Returns the players current radio channel, or 0 for none     | int          |
| [callChannel](docs/state-getters/stateBagGetters.md)   | Returns the players current call channel, or 0 for none      | int          |
| [disableRadio](docs/state-getters/stateBagGetters.md)   | Returns if the players radio is currently disabled, or 0 if its not. This is expected to be use as a bitwise, do *not* use a bool | int          |

#### Events

These are events designed for third-party resource integration. These are emitted only to the current client.

| Event                    | Description                                                  | Event Params   |
|--------------------------|--------------------------------------------------------------|----------------|
| [pma-voice:settingsCallback](docs/client-getters/events.md) | When emited it will return the current pma-voice settings. | cb(voiceSettings) |
| [pma-voice:radioActive](docs/client-getters/events.md) | Triggered when the radio is activated / deactivated | boolean |
| [pma-voice:setTalkingMode](docs/client-getters/events.md) | Triggered on proximity mode change with the voice mode id | int |


#### Server

##### Setters

| Export               | Description                          | Parameter(s) |
|----------------------|--------------------------------------|--------------|
| [setPlayerRadio](docs/server-setters/setPlayerRadio.md)       | Sets the players radio channel       | int, int     |
| [setPlayerCall](docs/server-setters/setPlayerCall.md)        | Sets the players call channel        | int, int     |
| [addChannelCheck](docs/server-setters/addChannelCheck.md)      | Adds a channel check to the players radio channel | int, function |


##### Getters

###### State Bags
You can access the state with `Player(source).state['state bag here']`

| State Bag     | Description                                                  | Return Type  |
|---------------|--------------------------------------------------------------|--------------|
| [proximity](docs/state-getters/stateBagGetters.md)     | Returns a table with the mode index, distance, and mode name | table        |
| [radioChannel](docs/state-getters/stateBagGetters.md)  | Returns the players current radio channel, or 0 for none     | int          |
| [callChannel](docs/state-getters/stateBagGetters.md)   | Returns the players current call channel, or 0 for none      | int          |
| [voiceIntent](docs/state-getters/stateBagGetters.md) | Returns the players current voice intent, either 'speech' or 'music' | string |
| [disableRadio](docs/state-getters/stateBagGetters.md)   | Returns if the players radio is currently disabled, or 0 if its not. This is expected to be use as a bitwise, do *not* use a bool | int          |

```ts
enum DisabledRadioStates {
	Enabled = 0,
	IsDead = 1,
	IsCuffed = 2,
	IsPdCuffed = 4,
	IsUnderWater = 8,
	DoesntHaveItem = 16,
	PlayerDisabledRadio = 32,
}
```

###### Exports

| Export                       | Description                                       | Parameter(s) |
|------------------------------|---------------------------------------------------|------|
| [getPlayersInRadioChannel](docs/server-getters/getPlayersInRadioChannel.md)     | Gets the current players in a radio channel       | int  |

## Forge megaphone: initialization and diagnostics

This Forge integration keeps transmission authorization in the server and voice
cache. Resource startup also recovers initialization when Mumble is already
connected; it does not require a new `mumbleConnected` event. Concurrent recovery
requests are deduplicated, and each attempt has a 10-second total timeout for
authoritative channel assignment and native acknowledgement. Disconnect cancels
stale attempts. Later cache/connection events or a readiness check can retry.
Custom `setVoiceState('channel', ...)` sessions are not overwritten by recovery.

The client `canUseMegaphone()` export returns `boolean, reason?`, preserving its
existing boolean result. Failure reasons distinguish configuration, connection,
initialization, character readiness, proximity, radio transmission, call and
incapacitation. `getMegaphoneStatus()` returns the same readiness/reason plus
local status flags, without character identifiers or assigned-channel IDs.
Neither export bypasses server grants or forces microphone transmission.

With Forge Siren running, `/megafonediag` displays a notification and prints the
status in F8. It works without a second player; querying readiness may schedule
a bounded initialization attempt. After updating, restart `pma-voice` before
`forge-siren`. Actual audibility/range/effects still require in-game testing with
another player. The existing `voice.cfg` settings in this base already enable
native audio, submix and megaphone.

Run `lua tests/megaphone_ready_test.lua` and `lua tests/megaphone_test.lua` from
this resource directory, alongside the cache/death/PTT/mute suites. The tests
load actual modules with mocked native boundaries; they do not send game audio.

### Local megaphone voice return (sidetone)

The default local return is enabled at 30% volume, for both authorized vehicle
and handheld transmissions. The PMA NUI opens an independent microphone stream
only after transmission is actually authorized. A 450–3500 Hz bandpass,
midrange boost, compressor and bounded speaker saturation approximate the
megaphone/radio sound locally. Remote listeners use FiveM's native RadioFX
submix with the same bandwidth. The local approximation is not bit-identical.
This does not replace or
modify Mumble voice targets, proximity, radio/call routing or other listeners'
volume. It is not a server-loopback test or proof that another player hears you.

The first use requires the FiveM NUI microphone permission: check F8 for the
`pma-voice` permission request, authorize it, then hold the megaphone key again.
This browser stream uses the default Windows/browser input and output; it does
not inherit the separately selected GTA microphone/headphones. Set the intended
devices as Windows defaults if they differ. Headphones are recommended to avoid
feedback. Some client builds/device setups can reject NUI capture/playback; the
local notice explains this without disabling the normal Mumble transmission.

No audio is recorded, stored or uploaded by this monitor. Releasing the key,
losing authorization, an interruption, device loss or resource/page teardown
mutes/disconnects playback and stops the tracks. A late permission grant cannot
revive a released transmission. There is no idle capture or new polling loop;
playback startup is bounded to three seconds, and volume updates are deduplicated.
An unanswered browser permission request can remain pending until the user acts,
but any resulting stream is discarded if that hold is no longer current.

Standalone fallback convars (Forge Siren's saved global policy overrides them):

```cfg
setr voice_megaphoneMonitor 1
setr voice_megaphoneMonitorVolume 30
setr voice_megaphoneRadioEffect 1
```

Volume is 0–100. Set the enable option or volume to `0` to disable only the local
return. `getMegaphoneStatus()` / `/megafonediag` include `monitorEnabled`,
`monitorVolume`, `monitorStatus`, `monitorActive` and `effectEnabled`. The latter
effect flag controls coloration, independently of the monitor switch;
`monitorActive` is acknowledged
browser playback, not merely the key being held. Normal voice readiness and
local monitor readiness are separate.

Run `node --test tests/megaphone_monitor_test.mjs` for lifecycle/filter/permission
regressions without opening a microphone. The same module is loaded by the
shipped NUI and the Vue public HTML, so rebuilding the original UI preserves it.
Actual permissions, sound quality and device selection still need a FiveM test.

For native browser timer/receiver checks, run
`node --test tests/megaphone_monitor_browser_test.mjs`. This optional development
suite reuses the installed Playwright package in Forge Siren's `web/node_modules`
(or the module URL supplied in `PMA_PLAYWRIGHT_MODULE`). Install its matching
Chromium beforehand, or set `FORGE_TEST_BROWSER` to an existing Chromium
executable. Audio capture/playback is simulated: it never asks for microphone
permission or accesses audio devices. These tests cover repeated holds, pending
permission and playback timeouts using real Window timers; permissive Node timer
mocks alone do not detect browser `Illegal invocation` errors. An additional
OfflineAudioContext test renders synthetic signals through the actual monitor
graph to check bandwidth and gain, without accessing a microphone or physical
output device.

### Forge Siren global megaphone policy

The Forge Siren settings popup includes an ADMIN tab. Its server owns permission
checks, schema validation, revision checks and persistent global settings in
resource KVP. PMA consumes replicated convars and server-authorized cache grants,
not player state bags. No global-setting key was added to the client cache writer
allowlist. Only Forge Siren's server export caller can grant amplification.

Effective policy convars are `voice_enableMegaphone`, `voice_megaphoneRange`,
`voice_megaphoneListenerVolume`, `voice_megaphoneFarVolume`,
`voice_megaphoneMonitor`, `voice_megaphoneMonitorVolume` and
`voice_megaphoneRadioEffect`. Gains are percentages; range is meters.
`voice_megaphoneMaxRange` remains the operator's independent hard ceiling
(50m by default), rather than a field writable from the NUI.

The trusted `setPlayerMegaphone` grant accepts `range`, `volume` (0–1),
optional `farVolume` (0–volume) and `token`. Near gain is held until 5m or 20%
of range, whichever is smaller, then fades linearly to far gain at the boundary;
outside range it is muted. Omitted `farVolume` preserves old constant-gain grants.
Listener changes are quantized/deduplicated in the existing proximity refresh.
Radio, calls, explicit mute and normal/custom proximity restoration retain
priority. Global saves reapply active grants without extending heartbeat expiry.

See Forge Siren's README for ACE configuration, defaults and the admin workflow.
