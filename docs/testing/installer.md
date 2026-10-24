# Installer verification

Run `scripts/build-distribution.ps1 -Check` from a clean source commit. This builds
the x64 application, runs affected suites and creates a versioned installer,
source archive, component manifest and SHA256SUMS. See [build setup](../setup/build.md).

The installer workflow uses a fresh hosted Windows runner. Its
`scripts/test-installer.ps1` harness refuses existing PodCast installations,
profiles or processes and requires disposable-environment flags. Do not run it
on the owner's PC. It skips driver installation and never streams audio.

Checks cover silent install, payload hashes, shortcuts/Installed Apps, repair of
a missing native DLL, setup launch, graceful same-image shutdown, rejection of a
copied foreign shutdown helper, uninstall, preserved settings/credentials, scoped
startup-entry cleanup and unchanged driver inventory. Upgrade uses a synthetic
lower-version executable with the production installer definition. Its report
labels this explicitly; it is not compatibility evidence for a prior release.

Actual first-driver installation/UAC/restart and HomePod playback need interactive
acceptance. Sleep/resume and final two-hour listening remain deferred.

October 24, 2026: hosted Windows runs
[40093906451](https://github.com/funkymonkeyjam/PodCast/actions/runs/40093906451) and
[40094006644](https://github.com/funkymonkeyjam/PodCast/actions/runs/40094006644)
pass all build and lifecycle steps. See [recorded results](results.md).
