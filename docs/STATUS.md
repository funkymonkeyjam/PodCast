# Status

- Stage: qualification prototype implemented; live Spotify isolation passed on Office.
- Target: Spotify only on one full-size HomePod; other Windows audio local.
- Repository: `https://github.com/funkymonkeyjam/PodCast`.
- Ownership: orchestrator integrates/Git and owns all hardware sessions. Bounded audio, desktop and test/review subagents completed source work and review.
- Evidence: checked package 816d4aa passes 55 Rust, 227 .NET, 117 Python, five IPC and eight notice checks plus isolated WPF construction. Recovery guidance follow-up passes 56 Rust/Clippy and 246 .NET tests. Owner confirmed A3/A4, tray, Spotify restart, sender-crash, format-change and scoped network recovery; see [results](testing/results.md).
- Setup: VB-CABLE active; Listen disabled; normal output Poly Sync 40-M; Spotify-only CABLE Input route; explicit CABLE Output capture saved. Spotify volume 40% made the live signal audible.
- Latest hardware gate: initial 30-minute session passed listening; owner reports no gaps/stutters. Queue counters unchanged; sender private memory 5.59–5.85 MiB. Native notice collection and independent review pass.
- Stopped for the night at the owner's request on October 24. The owner accidentally powered off the PC during the proposed sleep check; sleep/resume is not passed. Receiver takeover/release/reconnect passed with owner-confirmed Spotify only on Office.
- Remaining: actual sleep/resume check; rebuild/package actionable recovery guidance from pushed code checkpoint 7afdbf8; final two-hour audible soak with a listener. Current package was built from 816d4aa. Normal-user startup/source persistence and local routing restoration passed. HomePod gen 2 / OS 27.0 reported by pyatv.
- Next: finish initial listening evidence, [qualification](testing/qualification.md), save and push checkpoint. Never equate protocol success with audible Spotify playback.

During implementation retain only current stage, task ownership, latest build/test evidence, blockers and next actions here. Record durable design changes beside the design; avoid repeating logs.
