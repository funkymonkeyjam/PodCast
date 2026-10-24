# Destructive lifecycle checks for a fresh disposable Windows VM/hosted runner only.
# Build input: scripts/build-distribution.ps1; never downloads an upstream installer.
param(
    [Parameter(Mandatory)][string]$Installer,
    [string]$PublishDirectory = (Join-Path $PSScriptRoot '../dist/PodCast'),
    [string]$VBCableDirectory = (Join-Path $PSScriptRoot '../artifacts/packaging/VBCABLE-45'),
    [string]$PreviousInstaller,
    [switch]$SyntheticPreviousInstaller,
    [switch]$DisposableEnvironment
)
$ErrorActionPreference = 'Stop'
if (-not $DisposableEnvironment) { throw 'Explicit -DisposableEnvironment is required; never run against a normal user profile.' }
if ($env:GITHUB_ACTIONS -eq 'true' -and $env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Installer tests refuse self-hosted Actions runners.' }
if (-not $IsWindows -or -not $env:RUNNER_TEMP -or -not (Test-Path -LiteralPath $env:RUNNER_TEMP -PathType Container)) {
    throw 'Use PowerShell 7 in a disposable Windows environment with RUNNER_TEMP set.'
}
$installerPath = (Resolve-Path -LiteralPath $Installer).Path
$publish = (Resolve-Path -LiteralPath $PublishDirectory).Path
$vendor = (Resolve-Path -LiteralPath $VBCableDirectory).Path
function Installer-Version([string]$Path) {
    if ([IO.Path]::GetFileName($Path) -notmatch '^PodCast-(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)-Setup\.exe$') {
        throw 'Use an explicitly versioned PodCast-X.Y.Z[-prerelease]-Setup.exe.'
    }
    return $Matches[1]
}
$version = Installer-Version $installerPath
$previousPath = $null
if ($SyntheticPreviousInstaller -and -not $PreviousInstaller) { throw 'A synthetic upgrade fixture requires -PreviousInstaller.' }
if ($PreviousInstaller) {
    $previousPath = (Resolve-Path -LiteralPath $PreviousInstaller).Path
    $previousVersion = Installer-Version $previousPath
    if ([version]$previousVersion.Split('-')[0] -ge [version]$version.Split('-')[0]) {
        throw 'The previous installer must have a strictly lower three-field product version.'
    }
}
$productKey = '{2B8063F6-B964-431E-ACC8-3DFC7A943E00}_is1'
$runKey = 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run'
$arpRoots = @(
    'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'Registry::HKEY_CURRENT_USER\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'Registry::HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
function Product-Entries {
    foreach ($root in $arpRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($key in Get-ChildItem -LiteralPath $root) {
            $name = $key.GetValue('DisplayName')
            if ($key.PSChildName -eq $productKey -or $name -match '^PodCast(?:\s|$)') {
                [pscustomobject]@{
                    Key = $key.PSChildName; Root = $root; Name = $name
                    Version = $key.GetValue('DisplayVersion'); Location = $key.GetValue('InstallLocation')
                }
            }
        }
    }
}
function Read-Autorun {
    if (Test-Path -LiteralPath $runKey) { (Get-Item -LiteralPath $runKey).GetValue('PodCast') }
}
$roaming = [Environment]::GetFolderPath('ApplicationData')
$local = [Environment]::GetFolderPath('LocalApplicationData')
$profileFolders = @($roaming, $local, $env:APPDATA, $env:LOCALAPPDATA) |
    Where-Object { $_ } | ForEach-Object { Join-Path $_ 'PodCast' } | Select-Object -Unique
$programs = [Environment]::GetFolderPath('Programs')
$desktop = [Environment]::GetFolderPath('DesktopDirectory')
$shortcutPaths = @(
    (Join-Path $programs 'PodCast.lnk'), (Join-Path $desktop 'PodCast.lnk'),
    (Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'PodCast.lnk'),
    (Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'PodCast.lnk')
)
if (@(Product-Entries).Count -or @(Get-Process -Name PodCast,airflash-engine -ErrorAction SilentlyContinue).Count) {
    throw 'Existing PodCast registration or sender/app process found; no mutation is allowed.'
}
if ($null -ne (Read-Autorun) -or @($profileFolders + $shortcutPaths | Where-Object { Test-Path -LiteralPath $_ }).Count) {
    throw 'Existing PodCast preferences/cache/autorun/shortcuts found; use a fresh disposable profile.'
}
if (-not (Test-Path -LiteralPath (Join-Path $publish 'PodCast.exe') -PathType Leaf)) { throw 'Checked published payload is missing.' }
$payload = @(Get-ChildItem -LiteralPath $publish -File -Recurse | ForEach-Object {
    [pscustomobject]@{ Relative = [IO.Path]::GetRelativePath($publish, $_.FullName); Hash = (Get-FileHash -LiteralPath $_.FullName).Hash }
})
$vendorPayload = @(Get-ChildItem -LiteralPath $vendor -File -Recurse | ForEach-Object {
    [pscustomobject]@{ Relative = [IO.Path]::GetRelativePath($vendor, $_.FullName); Hash = (Get-FileHash -LiteralPath $_.FullName).Hash }
})
if (-not $vendorPayload.Count) { throw 'The complete verified VB-CABLE support payload is required.' }
$nativeFile = $payload | Where-Object Relative -Like '*.dll' | Select-Object -First 1
if (-not $nativeFile) { throw 'A native DLL is required for the repair check.' }
function Driver-Inventory {
    # OEM INF hashes detect staging/removal even when no matching audio endpoint exists.
    @(Get-ChildItem -LiteralPath (Join-Path $env:windir 'INF') -Filter 'oem*.inf' -File |
        Sort-Object Name | ForEach-Object { $_.Name + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
}
$driversBefore = Driver-Inventory
$runnerRoot = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\', '/')
$sandbox = Join-Path $runnerRoot ('PodCast-installer-test-' + [guid]::NewGuid().ToString('N'))
$appDirectory = Join-Path $sandbox 'app with spaces'
if (-not $appDirectory.StartsWith($runnerRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Sandbox must remain under RUNNER_TEMP.'
}
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$preferences = Join-Path $roaming 'PodCast'
New-Item -ItemType Directory -Path $preferences | Out-Null
$sentinel = Join-Path $preferences 'installer-test-sentinel.txt'
[IO.File]::WriteAllText($sentinel, [guid]::NewGuid().ToString())
$config = Join-Path $preferences 'config.json'
[IO.File]::WriteAllText($config, '{"schema_version":2,"capture_mode":"endpoint","capture_endpoint":null,"auto_connect_on_discover":false,"start_at_login":false,"ui_language":"en","master_volume":10}')
$credentialDirectory = Join-Path $preferences 'native-credentials'
New-Item -ItemType Directory -Path $credentialDirectory | Out-Null
$credentialSentinel = Join-Path $credentialDirectory 'synthetic-installer-fixture.txt'
[IO.File]::WriteAllText($credentialSentinel, 'Synthetic preservation fixture; not a pairing credential.')
$sentinelHash = (Get-FileHash -LiteralPath $sentinel).Hash
$configHash = (Get-FileHash -LiteralPath $config).Hash
$credentialHash = (Get-FileHash -LiteralPath $credentialSentinel).Hash
$checks = [Collections.Generic.List[string]]::new()
$installedExe = Join-Path $appDirectory 'PodCast.exe'
$installedAutorun = '"' + $installedExe + '" --startup'
$portableAutorun = '"' + (Join-Path $sandbox 'portable/PodCast.exe') + '" --startup'
function Assert-Preferences {
    if ((Get-FileHash -LiteralPath $sentinel).Hash -ne $sentinelHash -or (Get-FileHash -LiteralPath $config).Hash -ne $configHash -or
        (Get-FileHash -LiteralPath $credentialSentinel).Hash -ne $credentialHash) {
        throw 'Installer or app changed the disposable preference fixtures.'
    }
}
function Run-Program([string]$Path, [string[]]$Arguments, [int]$Timeout = 180000) {
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit($Timeout)) { throw "Process timed out; no force-kill or reboot attempted: $Path" }
    if ($process.ExitCode -ne 0) { throw "Process failed or requested a reboot ($($process.ExitCode)): $Path" }
}
function Install-Package([string]$Path, [string]$Label) {
    Run-Program $Path @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SKIPDRIVER', '/TASKS=desktopicon',
        ('/DIR="' + $appDirectory + '"'), ('/LOG="' + (Join-Path $sandbox ($Label + '.log')) + '"'))
}
function Assert-Installed([string]$ExpectedVersion, [switch]$CheckPayload) {
    $entries = @(Product-Entries)
    if ($entries.Count -ne 1 -or $entries[0].Key -ne $productKey -or
        $entries[0].Root -notlike 'Registry::HKEY_CURRENT_USER*' -or $entries[0].Version -ne $ExpectedVersion -or
        $entries[0].Location.TrimEnd('\') -ne $appDirectory) { throw 'Unexpected product registration, scope, version or install directory.' }
    if ($CheckPayload) {
        foreach ($file in $payload) {
            if ((Get-FileHash -LiteralPath (Join-Path $appDirectory $file.Relative)).Hash -ne $file.Hash) { throw "Installed payload differs: $($file.Relative)" }
        }
        foreach ($file in $vendorPayload) {
            if ((Get-FileHash -LiteralPath (Join-Path $appDirectory ('Support/VB-CABLE/' + $file.Relative))).Hash -ne $file.Hash) { throw "Bundled VB-CABLE file differs: $($file.Relative)" }
        }
    }
    foreach ($link in @((Join-Path $programs 'PodCast.lnk'), (Join-Path $desktop 'PodCast.lnk'))) {
        if (-not (Test-Path -LiteralPath $link)) { throw "Expected shortcut is missing: $link" }
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
        if ($shortcut.TargetPath -ne $installedExe) { throw 'Shortcut targets a different executable.' }
    }
    Assert-Preferences
}
function Uninstall-Package([string]$Label) {
    Run-Program (Join-Path $appDirectory 'unins000.exe') @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART',
        ('/LOG="' + (Join-Path $sandbox ($Label + '.log')) + '"'))
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while ((Test-Path -LiteralPath $appDirectory) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (@(Product-Entries).Count -or (Test-Path -LiteralPath $appDirectory)) { throw 'Uninstall left product registration or installed files.' }
    if (@($shortcutPaths | Where-Object { Test-Path -LiteralPath $_ }).Count) { throw 'Uninstall left a PodCast shortcut.' }
    Assert-Preferences
}
try {
    if ($previousPath) {
        Install-Package $previousPath 'previous-install'
        Assert-Installed $previousVersion
        $oldExeHash = (Get-FileHash -LiteralPath $installedExe).Hash
        Install-Package $installerPath 'upgrade'
        Assert-Installed $version -CheckPayload
        if ($oldExeHash -eq (Get-FileHash -LiteralPath $installedExe).Hash) { throw 'Upgrade fixture must contain a different application binary to prove payload replacement.' }
        $checks.Add($(if ($SyntheticPreviousInstaller) { 'Synthetic lower-version fixture upgrade replaces payload and preserves preferences; this is not a previously released application.' }
            else { 'Supplied lower-version installer upgrade replaces payload and preserves preferences.' }))
    } else {
        Install-Package $installerPath 'fresh-install'
        Assert-Installed $version -CheckPayload
        $checks.Add('Fresh per-user install: registration, shortcuts and all checked payload hashes.')
    }
    $damagedFile = Join-Path $appDirectory $nativeFile.Relative
    if (-not $damagedFile.StartsWith($appDirectory + '\', [StringComparison]::OrdinalIgnoreCase) -or
        (Get-Item -LiteralPath $damagedFile).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Unsafe repair fixture path.' }
    Remove-Item -LiteralPath $damagedFile
    Install-Package $installerPath 'repair-reinstall'
    Assert-Installed $version -CheckPayload
    $checks.Add('Reinstall repairs a missing owned native DLL and preserves preferences.')
    $uiReport = Join-Path $sandbox 'installed-ui.json'
    Run-Program $installedExe @('--ui-smoke', '--window-only', '--output', ('"' + $uiReport + '"')) 30000
    if (-not (Get-Content -LiteralPath $uiReport -Raw | ConvertFrom-Json).ok) { throw 'Installed isolated UI check failed.' }
    Run-Program $installedExe @('--quit') 15000
    $owner = Start-Process -FilePath $installedExe -ArgumentList '--setup' -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not $owner.HasExited -and $owner.MainWindowHandle -eq 0 -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100; $owner.Refresh() }
    if ($owner.HasExited -or $owner.MainWindowHandle -eq 0) { throw 'Normal installed app did not open its window.' }
    if ($owner.MainWindowTitle -ne 'PodCast settings') { throw '--setup did not open the settings window.' }
    $portableDirectory = Join-Path $sandbox 'portable'
    New-Item -ItemType Directory -Path $portableDirectory | Out-Null
    Get-ChildItem -LiteralPath $publish | Copy-Item -Destination $portableDirectory -Recurse
    $foreignQuit = Start-Process -FilePath (Join-Path $portableDirectory 'PodCast.exe') -ArgumentList '--quit' -WindowStyle Hidden -PassThru
    if (-not $foreignQuit.WaitForExit(15000) -or $foreignQuit.ExitCode -eq 0 -or $owner.HasExited) {
        throw 'Different-image --quit was not refused while the installed owner stayed running.'
    }
    Run-Program $installedExe @('--quit') 15000
    $owner.Refresh()
    if (-not $owner.HasExited -or $owner.ExitCode -ne 0 -or
        @(Get-Process -Name PodCast,airflash-engine -ErrorAction SilentlyContinue).Count) { throw 'Graceful --quit left an app or engine running.' }
    Assert-Preferences
    $checks.Add('Installed mock UI constructs; --setup opens settings without preference changes; same-image --quit stops its owner, different-image --quit is refused.')
    New-Item -Path $runKey -Force | Out-Null
    Set-ItemProperty -LiteralPath $runKey -Name PodCast -Value $installedAutorun
    Uninstall-Package 'uninstall-installed-autorun'
    if ($null -ne (Read-Autorun)) { throw 'Uninstall left its own installed autorun entry.' }
    $checks.Add('Uninstall removes owned files, registration, shortcuts and installed-path autorun; preferences survive.')
    Install-Package $installerPath 'portable-autorun-install'
    Assert-Installed $version -CheckPayload
    Set-ItemProperty -LiteralPath $runKey -Name PodCast -Value $portableAutorun
    Uninstall-Package 'uninstall-portable-autorun'
    if ((Read-Autorun) -ne $portableAutorun) { throw 'Uninstall changed a portable copy autorun entry.' }
    if ((Driver-Inventory) -ne $driversBefore) { throw 'OEM driver inventory changed despite /SKIPDRIVER.' }
    $checks.Add('Portable-path autorun and shared driver inventory are preserved.')
    @{ ok = $true; version = $version; checks = $checks.ToArray(); upgrade = $(if ($previousPath) { 'PASS' } else { 'NOT RUN: no lower-version installer supplied' });
       upgradeInput = $(if ($SyntheticPreviousInstaller) { 'Synthetic lower-version fixture, not a previous released application.' } elseif ($previousPath) { 'Supplied lower-version installer.' } else { 'None.' });
       note = 'Disposable environment only; no Spotify routing, receiver session or driver installation exercised.' } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $sandbox 'results.json') -Encoding utf8
    Write-Output "Installer lifecycle PASS. Evidence: $sandbox"
} catch {
    @{ ok = $false; version = $version; checks = $checks.ToArray(); error = $_.Exception.Message } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $sandbox 'results.json') -Encoding utf8
    throw
} finally {
    # Preflight proved the value absent; remove only fixtures created by this run.
    if ((Read-Autorun) -in @($installedAutorun, $portableAutorun)) { Remove-ItemProperty -LiteralPath $runKey -Name PodCast }
}
