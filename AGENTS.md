# Development rules

- Goal: Spotify on one HomePod only; other Windows audio stays local.
- Use one orchestrator and bounded audio, desktop and test/review subagents. The orchestrator owns integration and Git operations. Only one process owns hardware testing.
- Follow `docs/prompts/build.md`, `docs/plan/build-plan.md` and `docs/testing/acceptance.md`. Resume from `docs/STATUS.md`.
- Keep designs, plan, tests and code in this repository. Update documentation when behavior changes.
- Write the smallest correct, readable implementation. Prefer two clear lines to ten. Avoid code golf, speculative abstractions, dead code, redundant checks and comments that repeat the code. Preserve necessary error handling, cleanup and tests. Comments explain only non-obvious intent or constraints.
- Assign non-overlapping files before concurrent edits. Keep shared contracts stable; integrate and review each meaningful change.
- Test the affected behavior; broaden checks at integration boundaries. Never equate a successful build or mock with successful HomePod playback.
- Stop on a missing source; never fall back silently to system audio or microphone capture.
- Preserve upstream provenance/licenses. Do not commit secrets, user settings, music recordings or generated build output, except reviewed versioned install distributions under `release/` explicitly requested by the owner.
- Commit and push coherent checkpoints. Fetch and inspect before integrating remote work. Do not force-push, discard user work or bypass protected branches.
