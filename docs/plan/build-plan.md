# Personal Spotify-to-HomePod app: review and build plan

Prepared October 23, 2026.

## Decision

Build a small Windows 11 application using **C# / .NET 10 / WPF for the interface and a Rust engine for Windows audio capture and AirPlay transport**. Start with a local, source-built adaptation of **AirFlash**, subject to passing a hardware compatibility test. Reuse its transport rather than reconstructing WinAirCast's native backend.

The user confirmed the target: **one full-size HomePod; Spotify audible only on HomePod; other laptop sounds remain local**. HomePod generation and software version remain to be recorded. This plan has not tested the receiver or established compatibility.

For the first version, route Spotify to **VB-CABLE**, an existing virtual audio device, using Windows Volume Mixer. Capture that dedicated endpoint and send its audio to HomePod. This solves local playback isolation without developing a kernel driver or relying on unreleased process-capture changes. Keep the laptop's normal default output unchanged. [Microsoft loopback documentation](https://learn.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording), [VB-CABLE](https://vb-audio.com/Cable/).

## Review of the supplied investigation

Source: [WinAirCast technical investigation reference](../research/README.md), 12 pages; full report retained locally pending publication approval.

The report is useful architectural evidence. It clearly separates reconstructed frontend behavior from native-backend inference. Its strongest findings for this project are the separation of UI/control from continuous audio work, explicit source selection, persistent receiver identity, recovery after source/backend exits, and careful distinction between requested settings and applied settings.

It is not a complete implementation specification. The report did not observe a successful audio stream. Native packet details, receiver-specific negotiation, timing algorithms and actual latency remain unresolved. The evidence archive and original binaries were not independently reviewed for this plan.

Specific implications:

- Adopt the UI/engine separation and keep PCM samples out of the UI command channel.
- Stop or wait when the selected source disappears; never silently capture all system audio.
- Treat PCM/ALAC as candidates for receiver negotiation. Dependency strings do not prove outbound AAC support.
- Do not copy the report's 30-60 ms tuning values into performance promises. They are policy values, not measured source-to-speaker latency.
- Implement one receiver and a stable buffer first. Multiroom clocks, stereo groups, EQ, acoustic calibration, cloud diagnostics and Store entitlement add little to this personal use case.
- A selected-process capture API captures audio; it does not redirect or silence local playback. This is the central additional design requirement in your confirmed setup.

## Recommended stack

| Responsibility | Choice | Reason |
|---|---|---|
| Desktop UI | C#, .NET 10, WPF; simple MVVM | Native Windows controls and tray integration; reuse the candidate project's shell. .NET 10 is the current LTS choice. |
| Audio and sender engine | Rust, MSVC Windows target | Reuse a native pipeline for capture, conversion, packet pacing and receiver sessions. |
| Capture for version 1 | WASAPI on a dedicated virtual endpoint | Only Spotify is routed there; ordinary laptop audio stays on the normal output. |
| Routing | VB-CABLE, configured through Windows Volume Mixer | Separates Spotify from physical speakers without writing our own audio driver. |
| AirPlay transport | Adapt AirFlash's source engine after qualification | Closely matches the required Windows-to-HomePod path. |
| Audio conversion | Existing engine's PCM/ALAC paths, `rubato`, `alac-encoder` | Negotiate a supported stereo format; avoid an extra lossy encode. Verify actual format during testing. |
| Discovery | Windows DNS-SD, browsing AirPlay/RAOP services | Native discovery; identify the receiver persistently rather than by IP alone. |
| Control channel | Versioned JSON Lines over redirected child-process pipes | Commands and state events; include request/session identifiers and reject stale events. |
| Settings and secrets | Atomic JSON settings; DPAPI user-bound pairing storage | Keep local preferences separate from receiver credentials. |
| Delivery | Self-contained Windows x64 portable build first | Simple personal deployment; add an installer only after acceptance. |
| Verification | Rust tests, existing .NET tests, real-device listening/soak checks | Software tests do not establish HomePod interoperability or audible continuity. |

The candidate's [tagged WPF project](https://github.com/Ding-Kyoma/AirFlash/blob/v0.4.0/desktop/AirFlash.App/AirFlash.App.csproj) and [Rust manifest](https://github.com/Ding-Kyoma/AirFlash/blob/v0.4.0/native/airflash-engine/Cargo.toml) substantiate the language/runtime and audio dependencies. Use pinned revisions and lockfiles rather than copying version numbers from the investigation. Microsoft recommends [.NET 10 for its longer support window](https://devblogs.microsoft.com/dotnet/dotnet-8-9-end-of-support/).

## Reuse decision and alternatives

**Preferred foundation: a qualified AirFlash fork.** Begin with release `v0.4.0` (release page identifies commit prefix `81fa26b`); record the full commit hash when obtaining source. Keep changes small so fixes can be brought forward. Preserve license notices and use the project's GPLv3+ licensing route. [Release](https://github.com/Ding-Kyoma/AirFlash/releases/tag/v0.4.0), [license](https://github.com/Ding-Kyoma/AirFlash/blob/main/LICENSE).

There is a material version distinction: the 0.4.0 release lists per-application capture as future work and acknowledges unresolved crackling/timeouts. The current development README describes application capture, but that does not establish its availability or reliability in 0.4.0. The development engine also advertises partial qualification and `production_ready: false`. Treat it as a candidate to validate, not a proven SDK. [Release limitations](https://github.com/Ding-Kyoma/AirFlash/releases/tag/v0.4.0), [engine entry point](https://github.com/Ding-Kyoma/AirFlash/blob/main/native/airflash-engine/src/main.rs).

| Alternative | Assessment for this project |
|---|---|
| Python + pyatv | Good fallback interoperability probe. Its documented API accepts files and streaming inputs, but live capture, buffering and packaging still need engineering. Use it if the preferred sender fails qualification; do not maintain two engines initially. |
| Rust + Tauri | Viable if starting a new UI. AirSend uses it, but identifies itself as pre-alpha; changing UI frameworks offers little benefit when adapting the chosen WPF foundation. |
| New C# or Rust AirPlay implementation | Highest uncertainty: pairing, encryption, clocks, retransmission and firmware behavior must all be implemented and qualified. Avoid for the first personal version. |

Sources: [pyatv streaming API](https://pyatv.dev/development/stream/), [AirSend source/README](https://github.com/Pabldi08/AirSend).

## Version 1 behavior

```text
Spotify Windows app
  -> Windows per-app output: CABLE Input (playback device)
  -> VB-CABLE
  -> CABLE Output (recording device)
  -> Rust WASAPI capture / bounded buffer / format conversion
  -> negotiated AirPlay audio session
  -> your HomePod

Other apps -> normal laptop speakers/headphones
WPF app <-> control/status JSONL <-> Rust engine
```

The cable names are counterintuitive: Spotify sends to **CABLE Input**, and the app captures **CABLE Output**. Disable Windows "Listen to this device" and other monitoring on the cable. Do not make the cable the system-wide default output. A device installation needs administrator access and may require a restart, as described by its vendor. Installation belongs to implementation, not this planning task. [Vendor instructions](https://vb-audio.com/Cable/).

The initial app needs a receiver selector, Connect/Disconnect, HomePod volume, a source activity meter, connection/error status, tray controls and an obvious way to return Spotify to local playback. Remember the selected HomePod and dedicated endpoint by stable identity.

Keep Spotify as the player. The first version requires no Spotify OAuth, developer application or Web API integration. Spotify's transfer API controls an existing Spotify client/Connect device; it is not an AirPlay audio transport. This design does not promise that HomePod will appear inside Spotify's device picker. [Spotify transfer API](https://developer.spotify.com/documentation/web-api/reference/transfer-a-users-playback).

Manual Windows routing persists independently of our app. Disconnecting releases HomePod but does not automatically route Spotify back to laptop speakers. Version 1 must clearly expose the Volume Mixer and explain that state. Automatic route/restore is a later feature, conditional on finding and validating a reliable Windows mechanism; do not promise it from the outset.

## Build stages and acceptance gates

### 1. Prove the actual hardware path — allowance: 1-2 development days

Record Windows build, CPU architecture, installed Spotify variant, HomePod generation/software, network adapter and HomePod access settings. Assume x64 only until checked. Use the same reachable home LAN and test discovery before changing settings. An owner-performed access-setting change may be needed; do not weaken access automatically.

Obtain the pinned source, inspect repository instructions, build the unmodified candidate and run its relevant checks. Start with a short, low-volume test signal, then live Spotify. Establish endpoint isolation with the dedicated cable; if the driver is absent, prepare the vendor installation step for the user.

**Gate:** hear Spotify on HomePod for 30 minutes, with the laptop silent for Spotify and a separate notification still audible locally. Record actual negotiated codec/rate, connection failures and audible gaps. Confirm pause/resume and volume work. Capture short diagnostic counters, not music recordings.

If this fails, time-box diagnosis: distinguish discovery, authentication, source capture and transport problems. Use pyatv as a comparison only where useful. If neither sender works on this receiver, revise the transport decision and estimate before polishing a UI.

### 2. Create the personal build — allowance: 2-3 development days

Create a local fork with a separate app name, storage directory and pairing identity. Retain third-party notices. Preserve functioning engine paths; simplify the visible controls to one source and one receiver. Keep advanced features hidden before considering removal. Do not copy WinAirCast executables, proprietary backend code, credentials or Store logic.

Use the engine's existing IPC contract where possible. Ensure capture/packet work stays in Rust, command/event parsing is bounded, and old-session events cannot revive a stopped session. Show distinct waiting-for-source, connecting, authentication-required, streaming and failed states.

**Gate:** a repeatable build launches without development runtimes installed, selects the right endpoint/receiver, streams live audio and disconnects cleanly. Verify protected credentials and atomic settings in the personal app's directory.

### 3. Make everyday use reliable — allowance: 2-4 development days

Handle Spotify restarts, source silence, cable disconnection, output format changes, Wi-Fi loss, resume from sleep, receiver preemption and engine exit. Reconnect with bounded backoff and cancellation; return to current live audio rather than replaying an old backlog. Never switch from a missing cable to microphone or whole-system capture.

Expose the actual source rate and negotiated transport format in diagnostics. Let the receiver and tested engine determine buffering. Tune for stable music playback first; measure audible latency only if needed. PCM/ALAC transport does not make the upstream Spotify stream lossless or guarantee bit-perfect output.

**Gate:** complete a two-hour music session without audible interruptions attributable to the app, demonstrate recovery in controlled failure tests, and confirm no growth in queue depth or continuing growth in memory. Repeat isolation checks after restart/sleep and verify Disconnect prevents unwanted reconnect.

### 4. Package and hand over — allowance: 1-3 development days

Produce a self-contained portable build with version, source revision, build instructions, notices, concise setup guide and local diagnostic export. Include a routing troubleshooting guide and a clear process for returning Spotify to normal local output. Test on the laptop as a normal Windows user. Pin the tested dependency set and record the HomePod firmware used for acceptance.

**Gate:** launch from the delivered folder, connect from the tray, play Spotify only on HomePod, hear other apps locally, disconnect, and restore local Spotify output using the documented controls. Keep local logs bounded and omit credentials.

The overall allowance is **roughly 6-12 focused development days after a successful compatibility gate**, including stages 2-4 and integration contingency. This is a planning estimate, not a delivery commitment. Stage 1 determines whether that estimate is credible. Firmware/protocol failures can materially extend it.

## Later improvements, only after acceptance

- Add driver-free process-tree capture for optional mirroring. Microsoft's API supports capturing a process and its children on Windows build 20348 or later. Track executable identity and reacquire PIDs after restart; stop on ambiguous matches. This still does not silence local playback. [Microsoft application-loopback sample](https://learn.microsoft.com/en-us/samples/microsoft/windows-classic-samples/applicationloopbackaudio-sample/).
- Add Windows media-session title/playback controls if useful, without making audio depend on metadata.
- Investigate reliable per-app output switching and restoration; retain manual routing as a fallback.
- Consider a second HomePod only as a separate synchronization project.

## Evidence and current status

Completed for this task: read all 12 report pages; visually inspected the architecture page; checked primary Microsoft, Spotify, library and candidate-project sources; distinguished current development descriptions from tagged-release limitations; prepared this plan for the confirmed listening setup.

Not performed: source checkout/build, driver installation, network/receiver access, Spotify capture, pairing, streaming, acoustic latency measurement or runtime reliability tests. The recommended stack is an engineering judgment; the sender foundation remains conditional on stage 1.

## Repository and implementation handoff

Use [funkymonkeyjam/PodCast](https://github.com/funkymonkeyjam/PodCast) for all designs, plans, tests and code. The user authorizes fetching/pulling, committing and pushing project work. Keep the repository organized and write the smallest correct, readable implementation and necessary comments. Preserve existing work and upstream licenses.

Execute the [orchestrator graph-loop prompt](../prompts/build.md). One orchestrator directs bounded audio, desktop and test/review subagents through build, test, review and repair until [acceptance](../testing/acceptance.md) passes on the actual setup. Resume from [status](../STATUS.md); maintain [test evidence](../testing/results.md).
