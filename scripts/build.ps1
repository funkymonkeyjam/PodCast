# Build a qualification checkpoint; real-device acceptance is a separate procedure.
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $repo 'src/AirFlash'
. (Join-Path $source 'scripts/dotnet-common.ps1')
$context = Get-AirFlashDotnetContext -RepoRoot $source
$null = Assert-AirFlashDotnetSdk -Context $context

Push-Location -LiteralPath $source
try {
    & uv sync --locked
    if ($LASTEXITCODE -ne 0) { throw 'Python dependency setup failed.' }
    & ./scripts/build-native.ps1 -Check:$Check
    if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
    $nativeNotices = Join-Path $repo 'artifacts/ThirdPartyNotices.Native.txt'
    & uv run --no-sync python (Join-Path $repo 'scripts/collect-native-notices.py') --manifest './native/airflash-engine/Cargo.toml' --output $nativeNotices
    if ($LASTEXITCODE -ne 0) { throw 'Native license collection failed.' }
    if ($Check) {
        Invoke-AirFlashDotnet -Context $context -Arguments @('test', 'AirFlash.Tests/AirFlash.Tests.csproj', '-c', 'Release', '-p:RestoreLockedMode=true')
        if ($LASTEXITCODE -ne 0) { throw 'Desktop tests failed.' }
        & uv run --no-sync python -m pytest tests -q
        if ($LASTEXITCODE -ne 0) { throw 'Upstream Python checks failed.' }
        & uv run --no-sync python (Join-Path $repo 'tests/engine_safety.py') './native/airflash-engine/target/release/airflash-engine.exe'
        if ($LASTEXITCODE -ne 0) { throw 'Engine safety checks failed.' }
        & uv run --no-sync python -m pytest (Join-Path $repo 'tests/test_native_notices.py') -q
        if ($LASTEXITCODE -ne 0) { throw 'Native notice checks failed.' }
    }
    $output = Join-Path $repo 'dist/PodCast'
    Invoke-AirFlashDotnet -Context $context -Arguments @(
        'publish', 'AirFlash.App/AirFlash.App.csproj', '-c', 'Release', '-r', 'win-x64',
        '--self-contained', 'true', '-p:RestoreLockedMode=true', '-p:PublishTrimmed=false',
        '-p:DebugType=None', '-p:DebugSymbols=false', "-p:PathMap=$repo=/_/", '-o', $output
    )
    if ($LASTEXITCODE -ne 0) { throw 'Publish failed; do not use residual dist output.' }
    if ($Check) {
        $report = Join-Path $repo 'artifacts/ui-launch.json'
        Remove-Item -LiteralPath $report -ErrorAction SilentlyContinue
        $uiCheck = Start-Process -FilePath (Join-Path $output 'PodCast.exe') -ArgumentList @('--ui-smoke', '--window-only', '--output', "`"$report`"") -WindowStyle Hidden -PassThru
        if (-not $uiCheck.WaitForExit(30000)) { $uiCheck.Kill(); throw 'Window construction check timed out.' }
        if ($uiCheck.ExitCode -ne 0 -or -not (Get-Content -LiteralPath $report -Raw | ConvertFrom-Json).ok) { throw 'Window construction check failed.' }
    }
    Copy-Item -LiteralPath (Join-Path $source 'LICENSE-GPLv3'), (Join-Path $source 'LICENSE'), (Join-Path $repo 'THIRD-PARTY-NOTICES.md') -Destination $output
    Copy-Item -LiteralPath (Join-Path $source 'desktop/AirFlash.App/Assets/ThirdPartyNotices.txt') -Destination $output
    Copy-Item -LiteralPath $nativeNotices -Destination $output
    Copy-Item -LiteralPath (Join-Path $repo 'docs/setup/routing.md') -Destination (Join-Path $output 'SETUP.md')
    $revision = & git -C $repo rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot record source revision.' }
    if (@(& git -C $repo status --porcelain).Count) { $revision += ' (dirty qualification checkpoint)' }
    $revision | Set-Content -LiteralPath (Join-Path $output 'SOURCE-REVISION.txt')
    Get-Item -LiteralPath (Join-Path $output 'PodCast.exe')
} finally { Pop-Location }
