# Build from source

This is a qualification checkpoint, not an accepted HomePod release.

Use Windows x64, .NET SDK **10.0.402**, Rust **1.99.1** MSVC with the `clippy`
component, Visual Studio C++ Build Tools and Windows SDK, and `uv` with Python
3.12 or newer. Install development prerequisites from their official vendors.
The desktop SDK and dependency lockfiles are committed. The Rust target must
remain `x86_64-pc-windows-msvc`; a Linux build cannot qualify WASAPI.

From a PowerShell prompt in the repository:

```powershell
./scripts/build.ps1 -Check
```

The script restores locked dependencies, tests, builds the native engine,
audits its Windows dependencies and publishes a self-contained WPF build in
`dist/PodCast/`. No installer, driver, routing change or receiver session runs.
`PodCast.exe` embeds the engine; notices and setup accompany it.
Use `PodCast.exe --settings` for source setup, or `--window` for a persistent
playback panel during qualification. Normal launch retains tray behavior.
Do not distribute residual output after any failed command.

A local SDK may be placed in `artifacts/dotnet/`; otherwise `dotnet` must be on
PATH. Rust's `cargo` and `uv` must be on PATH. If using repository-local Rust,
set CARGO_HOME and RUSTUP_HOME to its ignored artifact directories in that
PowerShell process. No downloaded toolchains or build output belong in Git.
For a Dropbox checkout, set CARGO_TARGET_DIR to an absolute local directory
outside Dropbox to avoid sync locks. The build audits that output and stages
the resulting executable at the WPF embedding path before publishing.

The imported upstream `src/AirFlash/scripts/build.ps1` reserves upstream release
versions and creates an AirFlash MSI. Use the root script for PodCast.
See [provenance](../../THIRD-PARTY-NOTICES.md) and
[hardware qualification](../testing/qualification.md) before playback.
