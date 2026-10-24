# PodCast Windows installer

`PodCast.iss` targets the pinned Inno Setup 6.7.3 compiler selected by the root
release script. It produces `PodCast-<DisplayVersion>-Setup.exe` in the supplied
output directory. The root version manifest and release script own versioning,
compiler verification, vendor package verification, hashes and distribution.

Supply every preprocessor input explicitly:

```powershell
ISCC.exe installer/PodCast.iss /DPublishPath=<absolute-publish-folder> /DProductVersion=0.1.0 /DDisplayVersion=0.1.0-rc.1 /DOutputDir=<absolute-release-folder> /DVBCableDir=<absolute-unchanged-Pack45-folder> /DRepoRoot=<absolute-repository-folder>
```

The application payload is the **entire** publish folder, including all native
DLLs and notices. The entire extracted VB-CABLE package is installed unchanged
under `Support\VB-CABLE`. Only its interactive x64 setup is elevated, and only
when a matching recording device is absent. Its compile-time SHA-256 is checked
again immediately before execution. The root release process verifies the
official package and its signed vendor executable before compiling.

VB-Audio permits bundling under its [specific conditions](https://vb-audio.com/Services/licensing.htm).
Keep the full package, vendor identity, [official origin](https://vb-audio.com/Cable/)
and donationware information. `Prerequisites.txt` is shown before installation
and retained with the installed support files. No quiet driver arguments or
vendor success-code meanings are assumed.

The installer:

- Combines license, vendor and prerequisite information on one page, followed
  by the optional desktop shortcut task and Finish. Welcome, directory and
  duplicate confirmation pages are hidden; `/DIR` remains available for
  advanced staging. The complete GPL license remains in the app payload.
- Supports x64 Windows 11, build 22000 or newer; installs per user without
  elevating the application installation.
- Uses stable AppId `{2B8063F6-B964-431E-ACC8-3DFC7A943E00}`, Windows uninstall
  display name `PodCast`, and default directory `%LOCALAPPDATA%\Programs\PodCast`.
- Registers a Start menu shortcut and an optional `desktopicon` task. Both
  shortcuts open `--window`; the optional finish action opens `--setup`.
- Allows same-version repair and increasing `X.Y.Z` / `X.Y.Z-rc.N` releases.
  Preflight blocks a lower numeric core, stable-to-candidate downgrade at the
  same core, and decreasing candidate numbers. Unrecognized installed version
  labels require explicit removal before installation; no registry is rewritten
  to bypass this check.
- Detects VB-CABLE through exact recording-device base and adapter names in
  the 64-bit MMDevices registry, with `DeviceState` equal to active (1) or
  disabled (2). Disabled devices count as installed to avoid reinstalling a
  shared driver; stale NotPresent (4) and Unplugged (8) entries do not.
- Calls the installed application with `--quit` before replacement or removal;
  that command must return zero only after graceful exit, with a 30-second
  application-side timeout. Failure stops setup/removal without force-killing.
  A running portable copy in another folder must be quit by its owner; setup
  does not claim it as the installed copy.
- Never changes routing, enables sign-in startup or restarts Windows.
- Preserves personal settings, pairing data, logs, extracted engine cache and
  shared VB-CABLE on removal. It removes only an existing `HKCU` Run `PodCast`
  value whose executable is exactly the installed application.

An ordinary silent installation requires an existing cable. Explicit
`/SKIPDRIVER` permits staging/CI without a driver and never installs one. It
does **not** make streaming ready. Example lifecycle-test invocation:

```powershell
PodCast-0.1.0-rc.1-Setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SKIPDRIVER /DIR=<isolated-test-folder> /TASKS=desktopicon
```

Uninstall through Windows Installed apps or the installed `unins000.exe`.
The application folder's uninstaller accepts Inno Setup's standard silent
options. No vendor driver uninstaller is chained.

Installer lifecycle tests are separate from HomePod acceptance. The root
orchestrator owns compilation, installation, receiver sessions and Git work.
