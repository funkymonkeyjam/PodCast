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
The build collects actual license/notice texts from the locked Rust packages
and Rust toolchain into `ThirdPartyNotices.Native.txt`, failing if required texts
are unavailable. Install the pinned toolchain's `rust-docs` component if its
COPYRIGHT and license files are absent. Two published crates omit license bodies;
[reviewed supplements](../../licenses/native/README.md) pin their provenance and
hashes. Unknown omissions still fail. Existing .NET and UI dependency notices
are shipped separately. `-Check` also constructs the playback and Monitor
windows in an isolated mode without opening audio devices or contacting HomePod.
Use `PodCast.exe --settings` for source setup, or `--window` for a persistent
playback panel during qualification. Normal launch retains tray behavior.
For normal-user acceptance, launch through Explorer or Windows Run and configure
the source there. Tool-launched children can inherit an MSIX host's private
AppData view, which has separate preferences from a normal Windows launch.
Do not distribute residual output after any failed command.

A local SDK may be placed in `artifacts/dotnet/`; otherwise `dotnet` must be on
PATH. Rust's `cargo` and `uv` must be on PATH. If using repository-local Rust,
set CARGO_HOME and RUSTUP_HOME to its ignored artifact directories in that
PowerShell process. No downloaded toolchains or build output belong in Git.
For a Dropbox checkout, set CARGO_TARGET_DIR to an absolute local directory
outside Dropbox to avoid sync locks. The build audits that output and stages
the resulting executable at the WPF embedding path before publishing.
For the same reason, UV_CACHE_DIR and UV_PROJECT_ENVIRONMENT can point to
dedicated absolute directories outside Dropbox.

The imported upstream `src/AirFlash/scripts/build.ps1` reserves upstream release
versions and creates an AirFlash MSI. Use the root script for PodCast.
See [provenance](../../THIRD-PARTY-NOTICES.md) and
[hardware qualification](../testing/qualification.md) before playback.

## Versioned installer

The final app version is centralized in `Version.props`. With the same SDK/Rust/
Python tools available, run:

```powershell
./scripts/build-distribution.ps1 -Check
```

The script verifies pinned downloads and publishers, builds/tests the app,
collects notices and compiles Inno Setup 6.7.3. It writes a complete offline
installer, source ZIP, component/source manifest, checksums and user instructions
to `release/<version>/`. These versioned distribution files are intentionally
checked in at the owner's request; development caches and raw publish output
remain ignored. Each installer must remain below GitHub's 100 MiB file limit.

Source must be committed before a production distribution is built. A committed
release folder is immutable: bump `Version.props` for a new release, or use
`-OutputDirectory artifacts/verification/<version>` to rebuild without replacing
the published files. `-AllowDirty` creates an ignored local preview and must not
be used for the committed distribution. `-SkipAppBuild` is valid only when the
published app version/source stamp already matches the clean checkout.

The compiler and full base VB-CABLE archive are pinned in
`scripts/packaging-dependencies.json`; `scripts/prepare-packaging.ps1` validates
their SHA-256 values, publisher signatures and every extracted driver file. The
vendor package is preserved unchanged. It is identified as VB-Audio donationware
in setup and its installed support notices; the bundling basis is the vendor's
[specific VB-CABLE distribution conditions](https://vb-audio.com/Services/licensing.htm).
No undocumented silent driver switches, automatic restart or trust-store change
is used. Windows permission/vendor steps remain necessary on a machine without
the driver. The app setup itself is per-user and requires no elevation.

`scripts/test-installer.ps1 -DisposableEnvironment` is destructive and refuses
an existing PodCast profile, process or installation. Run it only in a fresh
disposable Windows runner/VM. CI checks payload hashes, repair/reinstall,
same-image graceful shutdown, foreign-image shutdown rejection, uninstall and
preservation of preferences/credentials/shared drivers. CI upgrade checks use an
explicitly labeled synthetic lower-version fixture. These checks never
connect a receiver or install the driver and do not replace listening acceptance.
