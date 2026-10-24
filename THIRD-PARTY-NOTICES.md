# Third-party source

`src/AirFlash/` is an adaptation of [AirFlash](https://github.com/Ding-Kyoma/AirFlash),
tag `v0.4.0`, full revision `81fa26bab0d5b42acaa4e5a5953ed05ae26e6350`.
The source was imported with `git archive`, without binaries or its Git database.
No development-branch transport changes are included.

Copyright (C) 2026 AirFlash contributors. PodCast uses the **GPL version 3 or
later** licensing option. The original [license notice](src/AirFlash/LICENSE),
[GPL text](src/AirFlash/LICENSE-GPLv3), commercial-license notice and bundled
[dependency notices](src/AirFlash/desktop/AirFlash.App/Assets/ThirdPartyNotices.txt)
are preserved. Internal AirFlash project names remain to keep the adaptation small.

PodCast changes require one explicit VB-CABLE recording endpoint and one receiver,
disable microphone recording and physical-output muting, separate app identity and
storage, and add routing assistance and qualification checks. These changes have
not established HomePod interoperability. See [results](docs/testing/results.md).

The upstream README, release/installer workflows and historical documentation
describe upstream AirFlash. Use the root PodCast README and scripts for this fork.
Dependency versions remain in Cargo.lock, uv.lock and NuGet packages.lock.json.
