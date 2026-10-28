# Status

- Desktop preview 0.1.0-rc.2: global Spotify-specific play/pause and receiver-volume shortcuts, plus passive USB ACK05 center-button support. 263 .NET tests and Release build pass; hotkey-only preview publish/static audit and isolated UI launch pass. Runtime shortcuts changed Office receiver volume 47→50 and toggled Spotify play/pause. Physical ACK05 rotation/center recognition and audible isolation are pending. See [controls](setup/spotify-controls.md). The rc.1 distribution remains unchanged.
- Stage: versioned Windows x64 release candidate 0.1.0-rc.1 delivered at the owner's request; remaining listening tests deferred.
- Target: Spotify only on Office HomePod; other Windows audio local. Repository: https://github.com/funkymonkeyjam/PodCast.
- Ownership: orchestrator integrates/Git and owns hardware sessions. Audio and desktop agents review bounded changes; test/review owns disposable installer checks.
- Packaging: per-user Inno Setup includes self-contained .NET/WPF app, embedded sender, native sidecars, notices and unchanged official base VB-CABLE package. A missing driver uses its official administrator installer and may need a manual restart. Spotify and receiver are external prerequisites.
- Evidence: checked build passes 56 Rust, 246 .NET, 117 Python, five IPC and eight notice checks, Clippy and isolated WPF construction. Installer preview compiles (~53 MB); prerequisite and optional shortcut pages inspected without installation. No-instance --quit works with a WPF native DLL missing. Disposable hosted Windows install/upgrade-fixture/repair/uninstall verification passes (run 40093906451). Final package source dd50727; checksums and isolated published UI verify.
- Prior hardware: owner confirmed isolation, tray, 30-minute listening without gaps, Spotify restart, sender crash, source removal/format change, scoped network interruption and receiver takeover/release. See [results](testing/results.md).
- Setup: VB-CABLE active; Listen disabled; normal output Poly Sync 40-M; Spotify-only CABLE Input route; explicit CABLE Output capture saved. HomePod gen 2 / OS 27.0. No hardware session started during packaging.
- Remaining: Actual sleep/resume and final two-hour audible soak remain NOT RUN; owner will complete later. Never infer listening acceptance from builds or logs.

Keep durable evidence in [results](testing/results.md), packaging procedures in [build setup](setup/build.md), and user instructions in [install guide](setup/install.md).
