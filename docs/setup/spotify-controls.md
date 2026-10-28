# Spotify dial controls

The 0.1.0-rc.2 desktop preview registers global shortcuts while PodCast runs:

| Shortcut | Action |
| --- | --- |
| Ctrl+Alt+F10 | Connected receiver volume down 3 points |
| Ctrl+Alt+F11 | Connected receiver volume up 3 points |
| Ctrl+Alt+F9 | Spotify play/pause |

Volume commands use the connected HomePod's volume and pending target. They
require an active streaming/standby receiver with available volume control.
There is no Windows-volume fallback. Keep Spotify routed to VB-CABLE and other
Windows audio on the local output as described in [routing](routing.md).

Play/pause selects the exact Spotify media-session identity. Missing or multiple
Spotify sessions report an error instead of sending a generic media key.
Shortcut conflicts report an error; streaming remains available. Restart PodCast
after resolving a conflicting shortcut. Diagnostic launches register no shortcuts.

For a USB XP-Pen ACK05, assign counterclockwise to Ctrl+Alt+F10 and clockwise to
Ctrl+Alt+F11 in the active custom roller mode. Disable the other roller modes
so its native mode switch keeps the volume mode selected. PodCast also listens
passively for the center button on the exact ACK05 MI02 vendor HID collection
(VID28BD/PID0202, usage FF0A/0001). A center press requests Spotify play/pause;
normal XP-Pen driver input remains enabled. Device absence is harmless and
reconnection refreshes identities. This does not establish Bluetooth support.
The passive [ACK05 probe](../../tools/ack05-probe/README.md) can check vendor
report visibility without changing the driver or existing button mappings.

Validation on 2026-10-27: 263 .NET tests, Release build, local self-contained
publish/static compatibility audit and isolated panel construction passed.
The unchanged installed native sender was reused with verified SHA-256
`987a5bc4a7a3a20dcd45b0d9dc753b704a9abdda00f6c66b6933f74702295658`.
Rust and full distribution checks were not rerun. In the installed hotkey preview,
F10/F11 changed Office receiver readback to 47 then 50, with master gain 100;
F9 changed Spotify's current track from paused to playing and back to paused.
Normal Windows profile settings were aligned with the configured tool-launch
profile after backing up both, keeping explicit CABLE capture, Office-only
auto-connect and startup enabled. The final installed preview registers one
ACK05 source and logged four physical center presses without a Spotify-control
error. The owner confirmed dial turns change only Office HomePod volume and
center presses pause/resume Spotify, including dial rotation after pressing the
center. Existing Wispr button mappings were preserved byte-for-byte. Actual
sign-in after restart remains untested. This preview does not
replace the immutable 0.1.0-rc.1 installer distribution.
