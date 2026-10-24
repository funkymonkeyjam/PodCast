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
Normal output remains **LG Ultra HD**. PodCast saved explicit CABLE Output by
stable ID. Spotify-only CABLE Input routing is prepared; live isolation is pending.

| ID | Status | Current evidence / remaining procedure |
|---|---|---|
| A1 | NOT RUN | Self-contained qualification executable launches; embedded-engine hello and endpoint enumeration pass. Final delivered startup acceptance pending. |
| A2 | PASS | Office discovery, transient authentication, PCM 44100 negotiation and five-second PTP stream complete. Owner confirmed the stronger synthetic tone from Office. Current receiver policy does not require persistent PIN pairing. |
| A3 | FAIL | Actual app connects to Office; owner hears no live Spotify. Investigating per-app routing and source activity. Synthetic tone is audible. |
| A4 | NOT RUN | Separate local sound during Spotify pending. |
| A5 | NOT RUN | Native receiver volume 38 confirmed; UI/pause/resume/tray acceptance pending. |
| A6 | NOT RUN | Automated cancellation, buffer and source rejection checks pass; actual recovery matrix pending. |
| A7 | NOT RUN | Neither 30-minute music session nor two-hour audible soak has run. |
| A8 | NOT RUN | Finite probes disconnect; persistent app disconnect/routing restoration pending. |
| A9 | NOT RUN | Selected source persisted; DPAPI and bounded/redacted log tests pass. Final persistence/credential acceptance pending. |
| A10 | NOT RUN | Locked checked build and independent review pass; final packaged/rebuilt delivery acceptance pending. |

### Completed software checks

- Unmodified tag: .NET 202 tests pass; WPF builds with SDK 10.0.401, zero
  warnings/errors. Native 49 pass, two ignored (hardware capture and wall-clock
  localhost soak). No baseline playback success is claimed.
- Adapted `scripts/build.ps1 -Check`: Rust 54 pass, two ignored; Clippy with
  warnings denied passes; .NET 219 pass; Python 112 pass; black-box IPC safety
  five pass. Five additional helper rejection cases also pass in the affected
  35-case probe suite. Self-contained Windows x64 publish succeeds.
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
6. Actual PodCast UI opens the saved CABLE Output source and connects Office;
   Spotify plays with the active mixer entry showing CABLE Input. Owner reports
   no music from HomePod. A3 remains failed pending source-level diagnosis.

Continue [qualification](qualification.md). Reset affected results after relevant
changes; packet counts and mocks never establish listening acceptance.
