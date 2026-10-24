# PodCast

Personal Windows 11 app: Spotify plays on one full-size Apple HomePod; other laptop audio stays local.

**Status:** planning complete; implementation and hardware qualification have not started.

- [Start building: orchestrator prompt](docs/prompts/build.md)
- [Build plan](docs/plan/build-plan.md)
- [Architecture](docs/design/architecture.md)
- [Acceptance tests](docs/testing/acceptance.md) and [results](docs/testing/results.md)
- [Current state](docs/STATUS.md)
- [Background investigation](docs/research/WinAirCast-Technical-Investigation.pdf)

## Layout

| Path | Purpose |
|---|---|
| `docs/` | Designs, plan, prompt, decisions and test evidence |
| `src/desktop/` | WPF application; create during implementation |
| `src/engine/` | Rust audio/AirPlay engine; create during implementation |
| `tests/` | Automated tests and hardware procedures |
| `scripts/` | Repeatable build and test entry points |

Upstream imports may retain their build layout when moving them would add needless work. Document the actual layout here.

Development repository: [funkymonkeyjam/PodCast](https://github.com/funkymonkeyjam/PodCast). Keep source, documentation and tests here; exclude credentials, recordings and generated output. Preserve upstream licenses when importing code.
