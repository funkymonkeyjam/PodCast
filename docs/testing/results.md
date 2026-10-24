# Test results

## Qualification checkpoint — October 23, 2026

Build: implementation checkpoint importing AirFlash v0.4.0,
`81fa26bab0d5b42acaa4e5a5953ed05ae26e6350`; modifications are described in
[architecture](../design/architecture.md). This is not final release acceptance.

Environment: Windows build 26300.9711, x64; Store Spotify 1.306.1921.0;
Intel Wi-Fi 6 AX203 on the reachable home LAN. Selected receiver: **Office**,
model AudioAccessory6,1. Pyatv 0.18.0 reports HomePod gen 2 / OS 27.0; native
`/info` reports sourceVersion 980.77.2. Owner reports access **Anyone On the
Same Network**; unchanged. Reported Home version 11.0 has not been treated as
HomePod firmware. Addresses and local preferences stay out of Git.

VB-CABLE's official signed x64 installer was opened at the owner's request.
CABLE Input/Output are active; Sound properties show **Listen unchecked**.
The owner connected **Poly Sync 40-M**, now the normal Windows output. PodCast
saved explicit CABLE Output by stable ID. Spotify alone uses CABLE Input.

| ID | Status | Current evidence / remaining procedure |
|---|---|---|
| A1 | NOT RUN | Self-contained qualification executable launches; embedded-engine hello and endpoint enumeration pass. Final delivered startup acceptance pending. |
| A2 | PASS | Office discovery, transient authentication, PCM 44100 negotiation and five-second PTP stream complete. Owner confirmed the stronger synthetic tone from Office. Current receiver policy does not require persistent PIN pairing. |
| A3 | PASS | After raising Spotify's volume to 40%, owner confirmed music only on Office, silent on the local Poly Sync speaker. |
| A4 | PASS | Owner confirmed the separate notification only on Poly Sync while Spotify remained only on Office. |
| A5 | PASS | Actual pause/resume and source silence/activity observed; receiver volume 73→68 confirmed and restored to 73. Disconnect stops the engine cleanly. Owner confirmed tray panel opens while music continues. |
| A6 | NOT RUN | Automated cancellation, buffer and source rejection checks pass; actual recovery matrix pending. |
| A7 | NOT RUN | Initial 30-minute session passed with owner-confirmed no gaps/stutters. Final two-hour audible soak remains unrun; owner needs to listen at a later session. |
| A8 | NOT RUN | Finite probes disconnect; persistent app disconnect/routing restoration pending. |
| A9 | NOT RUN | Selected source persisted; DPAPI and bounded/redacted log tests pass. Final persistence/credential acceptance pending. |
| A10 | NOT RUN | Locked checked build and independent review pass; final packaged/rebuilt delivery acceptance pending. |

### Completed software checks

- Unmodified tag: .NET 202 tests pass; WPF builds with SDK 10.0.401, zero
  warnings/errors. Native 49 pass, two ignored (hardware capture and wall-clock
  localhost soak). No baseline playback success is claimed.
- Adapted checks: Rust 55 pass, two ignored; Clippy with warnings denied passes;
  .NET 225 pass; upstream Python 117 pass; black-box IPC safety five pass.
  Self-contained Windows x64 publish succeeds. The isolated `--ui-smoke
  --window-only` check constructs and lays out the playback and Monitor windows
  without hardware access; actual app launch also passes. Eight native-notice
  collector fixture cases pass; actual offline collection covers 98 packages and
  Rust toolchain notices. The generated artifact contains no local user path.
- Two additional focused .NET recovery cases pass: Disconnect during retry backoff
  never opens another engine; two configured retries produce three total starts
  then terminal Error. Default reconnect remains disabled; actual recovery tests
  must verify either bounded recovery or an actionable error followed by Connect.
- Static-CRT dependency inspection passes. Windows API/bundle audits pass their
  static policy with 144 native and 1555 bundle imports labelled unconfirmed;
  these are not Windows 10 runtime compatibility certification.
- Independent review found and resolved unsafe capture defaults/physical mute,
  unbounded IPC/logs, stale external-engine staging, dirty revision stamping,
  resource URI and SDK-policy test assumptions. Subagents did not operate hardware.

[Build guide](../setup/build.md). Raw reports remain in ignored `artifacts/`.
No music or microphone audio was recorded; synthetic WAV files were temporary.

### Hardware diagnosis

1. Baseline `/info` succeeds, then `POST /pair-pin-start` exceeds four seconds.
   No media starts. Pyatv first-request comparison succeeds in 0.02–0.05 seconds;
   `/info` followed by authentication on the same socket takes 5.11 seconds.
2. Scoped first-pairing deadline becomes ten seconds, restoring four seconds
   afterward. Delayed reply, restoration and cancellation regressions pass.
3. Corrected native PCM 44100/PTP sends 627 packets, receives feedback/PTP,
   confirms volume 38 and stops cleanly, with no media-send errors. Owner hears
   nothing at original effective synthetic peak 0.005: listening initially FAIL.
4. Pyatv finite stream comparison times out in AirPlay 2 audio SETUP before media.
5. Raising only synthetic level (raw 0.5 × gain 0.1 = effective peak 0.05), with
   the same receiver volume and PCM/PTP format, produces an audible tone confirmed
   by the owner. This passes the short receiver path, not Spotify isolation or soak.
6. Actual PodCast opens saved CABLE Output and connects Office. At Spotify's
   original 10% volume, the source signal is present but very quiet and the owner
   hears no music. A source meter now reports pre-gain input separately from
   output; it does not establish audible playback. Raising Spotify to 40% makes
   music audible, confirmed by the owner. Connecting Poly Sync enables the
   separate local-audio test; the owner confirms both routes are correct.
7. Pause shows source silence; resume restores activity in the same receiver
   session. Receiver volume adjustment is acknowledged. The owner confirms the
   tray icon opens the panel without interrupting music. Intentional pause and
   setup changes precede the timed listening session.

### Initial 30-minute listening session

October 24, 2026, 03:11:31–03:41:33 UTC (October 23, 11:11–11:42 pm Eastern).
The owner reports **no gaps or stutters**. One unchanged sender and app process
remained throughout 61 resource samples; no audio was recorded.

- Capture 48 kHz; transport PCM 44.1 kHz / 16-bit with PTP.
- Queue maximum age 45.1 ms; local underruns 2 and dropped frames 288540 at both
  start and end. Capture starts before authentication; this cumulative baseline
  includes startup overflow/stale-frame discard and did not grow during the run.
- Zero sender recoveries, reconnects, media-send/sync errors or feedback failures.
  End snapshot: 349398 packets sent, feedback responding in 11.7 ms.
- Sender private memory 5.59–5.85 MiB (5.71→5.85), handles 241→241.
  Desktop private memory 113.91–136.53 MiB (113.91→123.40), handles 764→765,
  with panel/Monitor activity during the run. The final two-hour trend remains
  unverified; this initial result does not pass all of A7.

Continue [qualification](qualification.md). Reset affected results after relevant
changes; packet counts and mocks never establish listening acceptance.
