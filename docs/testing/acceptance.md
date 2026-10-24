# Acceptance cases

For each run record build/commit, Windows build/architecture, Spotify variant, HomePod model/software, source endpoint, negotiated format and network conditions. Use PASS, FAIL, BLOCKED or NOT RUN in [results](results.md), with evidence. Reset affected results after relevant code or environment changes.

| ID | Procedure | Pass criterion |
|---|---|---|
| A1 | Launch delivered build as a normal user without development tools | App starts and remains usable |
| A2 | Discover/select HomePod, complete supported pairing, connect | Correct receiver streams; status and negotiated format are accurate |
| A3 | Play live Spotify through the dedicated endpoint | Music audible on HomePod, silent from laptop physical output |
| A4 | Play a separate app sound/notification during A3 | Sound audible locally, absent from HomePod |
| A5 | Pause/resume Spotify; adjust HomePod volume; use tray/Disconnect | Playback and controls respond; UI stays responsive |
| A6 | Restart Spotify; remove source; change source format; interrupt engine/network; preempt receiver; resume from sleep | Bounded recovery or actionable error; no microphone/system fallback, stale replay or unbounded queues |
| A7 | Run initial 30-minute session, then final two-hour music soak | No reported audible dropouts; stable queue/memory trend; observed gaps investigated |
| A8 | Disconnect, wait beyond reconnect delays, return Spotify to local output using documented controls | Receiver released; no unwanted reconnect; routing instructions match actual behavior |
| A9 | Restart app and inspect persistence/logging | Preferences persist; credentials protected and omitted from logs |
| A10 | Rebuild/package from documented source; independent review | Repeatable build, source/notices/setup delivered; material findings resolved |

Actual listening confirmation is required for A3, A4 and audible A7 acceptance. Network writes, logs and mocks are insufficient. Do not record music or microphone audio without an explicit request. Serialize receiver tests; use isolated fault injection before disrupting network or sleep state.
