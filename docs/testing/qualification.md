# Qualification procedure

Run receiver tests from one orchestrator process. Close other AirPlay senders first. Do not record music or microphone audio. A successful build, engine status or packet counter does not establish audible playback.

## Record before testing

- PodCast commit, imported AirFlash tag/full revision and local modifications.
- Windows version/build and architecture; Spotify desktop/Store variant and version.
- HomePod name, generation, software version and owner-confirmed access policy.
- Active network adapter and whether laptop and receiver share the same LAN.
- Stable capture endpoint ID, endpoint name and native format; Spotify output route; normal Windows default output; cable monitoring state.
- Actual negotiated codec/rate and sender diagnostics once connected. Leave unknown fields unknown.

Keep raw diagnostic output in ignored `artifacts/`. Add concise, redacted observations to [results](results.md); never include pairing secrets or audio samples.

## Automated safety checks

After source-building the engine, run:

```powershell
python tests/engine_safety.py src/AirFlash/native/airflash-engine/target/release/airflash-engine.exe
```

The harness exercises invalid IPC, bounded command handling and rejection of missing sources/multiple receivers before connection. It only supplies loopback network addresses and never supplies a microphone-recording request. Run native unit tests as well: their pure validation tests cover the recording prohibition without opening a capture device. These checks do not prove endpoint capture, source isolation or receiver compatibility.

## Establish the path

1. Source-build the pinned, unmodified candidate and run its relevant automated checks before testing the adaptation. Record exact commands and outcomes. Preserve the upstream license and lockfiles.
2. Enumerate receivers without connecting. Select the owner's intended HomePod by stable identity; ask the owner when selection is ambiguous. Discovery failure is a discovery blocker, not evidence of an authentication or transport failure.
3. Verify a dedicated source exists. Route only Spotify to **CABLE Input** in Windows Volume Mixer. Select **CABLE Output** for capture. Keep normal speakers/headphones as the default and disable cable monitoring. Follow [routing setup](../setup/routing.md). Stop if the endpoint is unavailable; do not substitute another input.
4. Connect at a low receiver volume. If pairing is required, let the owner supply the requested input; do not change receiver access policy. Record authentication and negotiated-format evidence without credentials.
5. Send a short, low-volume signal through the dedicated source. Ask the owner to confirm sound from the intended HomePod. Stop on the wrong receiver, unexpected local monitoring or an unexplained source.
6. Play live Spotify, then play a separate local sound. Ask explicitly whether Spotify is audible only on HomePod and the separate sound only on the laptop. These observations are required for A3/A4; a meter alone cannot pass them.
7. Exercise pause/resume, receiver volume and Disconnect. Wait beyond all reconnect delays and verify the receiver stays released. Demonstrate restoration of Spotify's local output through Volume Mixer.
8. Reconnect for the initial 30-minute session. Record start/end time, listener-confirmed gaps, diagnostic queue/memory samples and negotiated format. Investigate every reported gap before advancing.

## Recovery and final acceptance

Use isolated fault injection for engine failure, source loss, format changes and simulated transport interruption first. Verify actionable errors, bounded buffers, current-live-audio recovery and Disconnect cancellation. A missing source must never activate default input, microphone or system loopback.

After controlled tests pass, coordinate real Spotify restart, receiver preemption, network interruption and sleep/resume with the owner. Do not interrupt the user's network or suspend the laptop merely to obtain an early test result. Recheck isolation after recovery.

Run the two-hour soak only on the intended setup with listening confirmation. Sample memory and queue diagnostics without recording audio. Launch the final self-contained package as a normal user, repeat basic routing/control checks, and review credential storage, log redaction and rebuild instructions. Track A1-A10 separately; mark unavailable hardware checks BLOCKED and unattempted checks NOT RUN.

## Initial authentication delay

Receiver qualification exposed a delayed response to `POST /pair-pin-start` after `/info`, exceeding the native engine's normal four-second control timeout. A pyatv request comparison isolated this startup delay; changing discovery or the audio source was unnecessary. The engine now allows ten seconds for this first authentication request and restores four seconds on success or failure. Cancellation remains active throughout. Local protocol tests cover a five-second response, rejection, timeout restoration and cancellation.

The subsequent orchestrator test completed authentication, negotiated PCM at 44,100 Hz and stopped a finite signal stream normally. This establishes protocol progress; listening confirmation and live Spotify isolation remain separate acceptance requirements. Record run-specific evidence in [results](results.md).

For a similar authentication failure, the orchestrator can use [compare-auth.py](../../scripts/compare-auth.py) from a separately provisioned pyatv environment. Set `$receiverAddress` locally to the selected receiver; do not save its address or credentials in Git. Run one comparison at a time with other sender sessions closed:

```powershell
python scripts/compare-auth.py --host $receiverAddress --profile native --info-first
python scripts/compare-auth.py --host $receiverAddress --profile pyatv --info-first
```

The script sends `/info` and the initial authentication request, then closes the connection. It sends no audio, completes no pairing and saves no credentials. Compare status, CSeq and elapsed time; omit `--info-first` to isolate the preceding request. This is an optional diagnosis tool, not a second sender or an application runtime dependency.

## Failure record

For each failure record: commit/environment, exact action, expected versus observed behavior, failing layer (discovery, authentication, capture, conversion, transport or UI), redacted evidence, next hypothesis and owner. A repeated failure needs new evidence or a different hypothesis. Keep acceptance blocked until actual receiver behavior and required listening observations are established.
