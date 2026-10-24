# Compile a synthetic lower-version installer. Never install it or put it in release/.
param(
    [string]$PublishDirectory = (Join-Path $PSScriptRoot '../dist/PodCast'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts/installer-fixture')
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifacts = [IO.Path]::GetFullPath((Join-Path $repo 'artifacts'))
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (-not $output.StartsWith($artifacts + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Synthetic fixture output must stay inside ignored artifacts/.'
}
if ((Test-Path -LiteralPath $output) -and (Get-Item -LiteralPath $output).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Fixture output must not be a junction or symbolic link.'
}
$publish = (Resolve-Path -LiteralPath $PublishDirectory).Path
$currentExe = Join-Path $publish 'PodCast.exe'
$currentHash = (Get-FileHash -LiteralPath $currentExe -Algorithm SHA256).Hash
$compiler = Join-Path $env:windir 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'The Windows .NET Framework 4 x64 fixture compiler is unavailable.' }
$tools = & (Join-Path $PSScriptRoot 'prepare-packaging.ps1')
$stage = Join-Path $output ('payload-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Get-ChildItem -LiteralPath $publish | Copy-Item -Destination $stage -Recurse
$fixtureExe = Join-Path $stage 'PodCast.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /debug- "/out:$fixtureExe" (Join-Path $repo 'tests/fixtures/InstallerPrevious.cs')
if ($LASTEXITCODE -ne 0) { throw 'Synthetic previous executable compilation failed.' }
$fixture = Get-Item -LiteralPath $fixtureExe
if ($fixture.VersionInfo.FileVersion -ne '0.0.0.0' -or (Get-FileHash -LiteralPath $fixtureExe).Hash -eq $currentHash) {
    throw 'Fixture must be a distinct executable with file version 0.0.0.0.'
}
$setup = Join-Path $output 'PodCast-0.0.0-rc.1-Setup.exe'
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$scratch = Join-Path $tempRoot ('PodCast-installer-fixture-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    # Inno updates PE resources in place; keep that transient output outside synced folders.
    & $tools.IsccPath '/Qp' "/DPublishPath=$stage" '/DProductVersion=0.0.0' '/DDisplayVersion=0.0.0-rc.1' "/DOutputDir=$scratch" "/DVBCableDir=$($tools.VBCableDirectory)" "/DRepoRoot=$repo" (Join-Path $repo 'installer/PodCast.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic lower-version installer compilation failed.' }
    Copy-Item -LiteralPath (Join-Path $scratch 'PodCast-0.0.0-rc.1-Setup.exe') -Destination $setup -Force
} finally {
    if (-not $scratch.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        (Get-Item -LiteralPath $scratch).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Unsafe fixture scratch cleanup target.' }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) { throw 'Synthetic fixture installer is missing.' }
if ((Get-FileHash -LiteralPath $currentExe).Hash -ne $currentHash) { throw 'Fixture compilation changed the checked production payload.' }
@{
    synthetic = $true; version = '0.0.0-rc.1'; productVersion = '0.0.0'
    note = 'Same production installer definition and current support files, with a synthetic no-op executable. Not a previously released application.'
    installerSha256 = (Get-FileHash -LiteralPath $setup).Hash.ToLowerInvariant()
    executableSha256 = (Get-FileHash -LiteralPath $fixtureExe).Hash.ToLowerInvariant()
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'fixture.json') -Encoding utf8
Get-Item -LiteralPath $setup
