# PodCast

Personal Windows 11 app: Spotify plays on one full-size Apple HomePod; other laptop audio stays local.

[Windows installer 0.1.0-rc.1](release/0.1.0-rc.1/PodCast-0.1.0-rc.1-Setup.exe) · [Install/uninstall guide](docs/setup/install.md) · [Source and checksums](release/0.1.0-rc.1/)

**Status:** release candidate 0.1.0-rc.1 is available. A self-contained Windows x64 build
launches and streams Spotify to Office. The owner confirmed Spotify only on
HomePod and a separate notification only on the local Poly Sync speaker.
The initial 30-minute session passed listening; final soak and sleep/resume
acceptance remain. See [current evidence](docs/testing/results.md).

- [Start building: orchestrator prompt](docs/prompts/build.md)
- [Build plan](docs/plan/build-plan.md)
- [Architecture](docs/design/architecture.md)
- [Acceptance tests](docs/testing/acceptance.md) and [results](docs/testing/results.md)
- [Current state](docs/STATUS.md)
- [Background investigation reference](docs/research/README.md)

## Layout

| Path | Purpose |
|---|---|
| `docs/` | Designs, plan, prompt, decisions and test evidence |
| `src/AirFlash/desktop/` | Adapted .NET 10/WPF application and tests |
| `src/AirFlash/native/airflash-engine/` | Adapted Rust WASAPI/AirPlay engine and tests |
| `tests/` | Automated tests and hardware procedures |
| `scripts/` | Repeatable build and test entry points |

Use [build instructions](docs/setup/build.md) and the root `scripts/build.ps1 -Check`.
Intermediate builds are generated under `dist/PodCast/`; they are excluded
from Git. Versioned distributions are checked in under `release/`; see the [install/uninstall guide](docs/setup/install.md). Follow [Spotify routing and restoration](docs/setup/routing.md).

Select **CABLE Output (VB-Audio Virtual Cable)** explicitly. PodCast rejects
missing sources, microphones, physical playback capture and multiple receivers.
Route only Spotify to **CABLE Input**; retain the normal Windows output.
Disconnect releases HomePod and leaves Windows per-app routing in place.

This fork uses GPLv3-or-later. [Pinned upstream provenance and notices](THIRD-PARTY-NOTICES.md)
are retained alongside the source. Upstream documents inside `src/AirFlash/`
describe AirFlash; root documents describe PodCast.

Development repository: [funkymonkeyjam/PodCast](https://github.com/funkymonkeyjam/PodCast). Keep source, documentation and tests here; exclude credentials, recordings and intermediate build output. Preserve upstream licenses when importing code.
