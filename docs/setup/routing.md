# Route Spotify to HomePod

PodCast requires a dedicated audio endpoint. Spotify sends to **CABLE Input** (playback); PodCast captures **CABLE Output** (recording). Other applications keep the normal laptop output. Never select a microphone or Stereo Mix as a substitute.

## Prepare the cable

1. If the endpoints are absent, obtain VB-CABLE from the [official vendor](https://vb-audio.com/Cable/). Extract the package and run its setup as administrator. Follow the vendor's restart instruction at a convenient time; PodCast does not install a driver or restart Windows automatically.
2. Open Windows **Settings > System > Sound**. Keep your speakers/headphones as the normal output; do not make CABLE Input the default.
3. Open **More sound settings > Recording > CABLE Output > Properties > Listen**. Clear **Listen to this device**, then apply. Disable any other cable monitoring in audio software.

## Route only Spotify

1. Open Spotify and start playback at low volume so Windows can list it.
2. Open **Settings > System > Sound > Volume mixer**. Under **Apps**, expand Spotify and set its **Output device** to **CABLE Input (VB-Audio Virtual Cable)**. Leave other applications on their normal output.
3. In PodCast, explicitly select **CABLE Output** as the capture source and the intended HomePod as receiver. If that source is missing, stop and restore it; do not use a default source.
4. Connect at low HomePod volume. Confirm by listening that Spotify plays on HomePod and is silent on the laptop. Play a separate app sound and confirm it remains local and is absent from HomePod.

If Spotify is absent from Volume mixer, confirm it is playing and reopen the page. If a route change does not take effect, restart Spotify and check its output selection again. A moving source meter alone does not prove audible playback or isolation.

## Disconnect and return Spotify to the laptop

Disconnect releases the HomePod session. **Windows keeps Spotify's selected output after Disconnect and after PodCast exits**, so Spotify can remain silent locally.

To restore local playback, pause Spotify, disconnect PodCast, then open Volume mixer and set Spotify's output to **Default** (with normal speakers/headphones still the system default) or explicitly choose those speakers/headphones. Resume at low volume and confirm local sound.

## Before reporting a streaming failure

- Missing CABLE Output: check driver installation and whether the device is enabled. PodCast must stop rather than capture another device.
- No source activity: check Spotify's per-app output, mute state and playback; confirm CABLE Input/CABLE Output belong to the same cable.
- Spotify audible locally: check its route, cable **Listen** setting and other monitoring software.
- Other app sounds reach HomePod: check that CABLE Input has not become the system default and those apps are not explicitly routed to it.
- HomePod absent or pairing rejected: confirm the intended receiver and same reachable LAN. Have the owner inspect access restrictions; do not weaken receiver access automatically.

Windows per-app output selection is documented by [Microsoft Support](https://support.microsoft.com/en-us/windows/hardware/audio/fix-app-audio-not-working-while-system-sounds-work-in-windows). Endpoint direction and driver installation are documented by [VB-Audio](https://vb-audio.com/Cable/).

These steps are the intended workflow. Hardware playback and isolation remain unverified until recorded in [acceptance results](../testing/results.md).
