param(
    [switch]$Check,
    [switch]$SkipAppBuild,
    [switch]$AllowDirty,
    [string]$IsccPath,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
[xml]$versionFile = Get-Content -LiteralPath (Join-Path $repo 'Version.props')
$displayVersion = [string]$versionFile.Project.PropertyGroup.Version
$productVersion = ($displayVersion -split '-')[0]
if ($displayVersion -notmatch '^\d+\.\d+\.\d+(?:-rc\.[1-9]\d*)?$') { throw 'Use a stable version or a numbered release candidate.' }
$revision = & git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine source revision.' }
$dirty = @(& git -C $repo status --porcelain -- . ':(exclude)release/**').Count -gt 0
if ($dirty -and -not $AllowDirty) { throw 'Commit source changes before making a versioned distribution. Use -AllowDirty only for an ignored local preview.' }
if ($AllowDirty -and -not $OutputDirectory) { $OutputDirectory = Join-Path $repo 'artifacts/package-preview' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repo "release/$displayVersion" }
$output = [IO.Path]::GetFullPath($OutputDirectory)
if ($AllowDirty -and -not $output.StartsWith([IO.Path]::GetFullPath((Join-Path $repo 'artifacts')) + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Development previews must remain inside ignored artifacts/.'
}
if ($output -eq [IO.Path]::GetFullPath((Join-Path $repo "release/$displayVersion")) -and
    @(& git -C $repo ls-files -- "release/$displayVersion/manifest.json").Count) {
    throw 'This distribution version is already checked in. Bump Version.props, or use a separate output directory for verification.'
}
if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count) { throw 'Use an empty output directory to avoid mixing distributions.' }
$publish = Join-Path $repo 'dist/PodCast'
$tools = & (Join-Path $PSScriptRoot 'prepare-packaging.ps1')
if (-not $IsccPath) { $IsccPath = $tools.IsccPath }
$pins = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'packaging-dependencies.json') -Raw | ConvertFrom-Json
if ((Get-FileHash -LiteralPath $IsccPath -Algorithm SHA256).Hash -ne $pins.innoSetup.isccSha256) { throw 'Selected compiler does not match the pinned Inno Setup version.' }
if ((Get-FileHash -LiteralPath (Join-Path (Split-Path $IsccPath) 'ISCmplr.dll') -Algorithm SHA256).Hash -ne $pins.innoSetup.compilerDllSha256) { throw 'Selected compiler DLL does not match the pinned Inno Setup version.' }
if (-not $SkipAppBuild) {
    & (Join-Path $PSScriptRoot 'build.ps1') -Check:$Check
    if ($LASTEXITCODE -ne 0) { throw 'Checked app build failed.' }
}
$exe = Join-Path $publish 'PodCast.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Published PodCast executable is missing.' }
$actualVersion = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
if (($actualVersion -split '\+')[0] -ne $displayVersion) { throw "App version $actualVersion does not match distribution $displayVersion." }
$sourceStamp = (Get-Content -LiteralPath (Join-Path $publish 'SOURCE-REVISION.txt') -Raw).Trim()
if (-not $AllowDirty -and $sourceStamp -ne $revision) { throw 'Published app does not match the clean source revision; rebuild it.' }
Copy-Item -LiteralPath (Join-Path (Split-Path $tools.IsccPath) 'License.txt') -Destination (Join-Path $publish 'ThirdPartyNotices.Installer.txt')
New-Item -ItemType Directory -Path $output -Force | Out-Null
& $IsccPath '/Qp' "/DPublishPath=$publish" "/DProductVersion=$productVersion" "/DDisplayVersion=$displayVersion" "/DOutputDir=$output" "/DVBCableDir=$($tools.VBCableDirectory)" "/DRepoRoot=$repo" (Join-Path $repo 'installer/PodCast.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed; do not distribute residual output.' }
$setup = Join-Path $output "PodCast-$displayVersion-Setup.exe"
if ((Get-Item -LiteralPath $setup).Length -ge 100MB) { throw 'Installer exceeds the normal GitHub file limit; configure Git LFS before committing it.' }
if ((& git -C $repo rev-parse HEAD) -ne $revision -or (-not $AllowDirty -and @(& git -C $repo status --porcelain -- . ':(exclude)release/**').Count)) {
    throw 'Source changed during packaging. Rebuild from a stable source checkpoint.'
}

function File-Inventory([string]$Directory) {
    @(Get-ChildItem -LiteralPath $Directory -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($Directory, $_.FullName).Replace('\','/'); bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
$manifest = [ordered]@{
    version = $displayVersion; productVersion = $productVersion; architecture = 'win-x64'
    sourceRevision = $revision; sourceStamp = $sourceStamp; sourceDirty = $dirty
    sourceUrl = "https://github.com/funkymonkeyjam/PodCast/tree/$revision"
    acceptance = 'Release candidate: final two-hour listening and sleep/resume acceptance remain pending.'
    installer = [ordered]@{ file = (Split-Path $setup -Leaf); bytes = (Get-Item -LiteralPath $setup).Length; sha256 = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant(); signed = $false }
    tooling = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'packaging-dependencies.json') -Raw | ConvertFrom-Json
    payload = File-Inventory $publish
    vbCable = File-Inventory $tools.VBCableDirectory
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding utf8
if (-not $dirty) {
    & git -C $repo archive --format=zip "--prefix=PodCast-$displayVersion-source/" "--output=$(Join-Path $output "PodCast-$displayVersion-source.zip")" $revision
    if ($LASTEXITCODE -ne 0) { throw 'Corresponding-source archive failed.' }
}
$guide = (Get-Content -LiteralPath (Join-Path $repo 'docs/setup/install.md') -Raw).Replace('](routing.md)', "](https://github.com/funkymonkeyjam/PodCast/blob/$revision/docs/setup/routing.md)")
[IO.File]::WriteAllText((Join-Path $output 'README.md'), $guide)
if (Get-ChildItem -LiteralPath $output -File | Where-Object Length -ge 100MB) { throw 'A distribution file exceeds the normal GitHub file limit.' }
$checksums = Get-ChildItem -LiteralPath $output -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object { '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name }
$checksums | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ascii
Get-Item -LiteralPath $setup
