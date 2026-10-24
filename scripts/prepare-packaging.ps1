# Fetch verified build tooling and the complete, unchanged vendor driver package.
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pins = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'packaging-dependencies.json') -Raw | ConvertFrom-Json
$tools = Join-Path $repo 'artifacts/packaging'
New-Item -ItemType Directory -Path $tools -Force | Out-Null

function Get-PinnedFile($Pin, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Destination)) {
        Invoke-WebRequest -Uri $Pin.url -OutFile ($Destination + '.partial')
        if ((Get-FileHash -LiteralPath ($Destination + '.partial') -Algorithm SHA256).Hash -ne $Pin.sha256) {
            throw "Downloaded file hash did not match its pin: $Destination"
        }
        Move-Item -LiteralPath ($Destination + '.partial') -Destination $Destination
    }
    if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $Pin.sha256) {
        throw "Cached file hash did not match its pin: $Destination"
    }
}
function Assert-Publisher([string]$Path, [string]$Publisher) {
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false) -ne $Publisher) {
        throw "Authenticode publisher validation failed: $Path"
    }
}

$compilerSetup = Join-Path $tools 'innosetup-6.7.3.exe'
Get-PinnedFile $pins.innoSetup $compilerSetup
Assert-Publisher $compilerSetup $pins.innoSetup.publisher
$compilerDirectory = Join-Path $tools 'inno-6.7.3'
$compiler = Join-Path $compilerDirectory 'ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $install = Start-Process -FilePath $compilerSetup -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/CURRENTUSER','/NOICONS',('/DIR="' + $compilerDirectory + '"')) -WindowStyle Hidden -PassThru -Wait
    if ($install.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $compiler)) { throw 'Inno Setup compiler installation failed.' }
}
if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -ne $pins.innoSetup.isccSha256 -or
    (Get-FileHash -LiteralPath (Join-Path $compilerDirectory 'ISCmplr.dll') -Algorithm SHA256).Hash -ne $pins.innoSetup.compilerDllSha256) {
    throw 'Inno Setup compiler files did not match the pinned distribution.'
}

$driverZip = Join-Path $tools 'VBCABLE_Driver_Pack45.zip'
Get-PinnedFile $pins.vbCable $driverZip
$driverDirectory = Join-Path $tools 'VBCABLE-45'
Expand-Archive -LiteralPath $driverZip -DestinationPath $driverDirectory -Force
$archive = [IO.Compression.ZipFile]::OpenRead($driverZip)
try {
    $entries = @($archive.Entries | Where-Object { $_.Name })
    if (@(Get-ChildItem -LiteralPath $driverDirectory -File -Recurse).Count -ne $entries.Count) { throw 'Unexpected files in the vendor package directory.' }
    foreach ($entry in $entries) {
        $stream = $entry.Open()
        try { $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) } finally { $stream.Dispose() }
        if ((Get-FileHash -LiteralPath (Join-Path $driverDirectory $entry.FullName) -Algorithm SHA256).Hash -ne $digest) { throw 'Extracted vendor file differs from its original archive.' }
    }
} finally { $archive.Dispose() }
Assert-Publisher (Join-Path $driverDirectory 'VBCABLE_Setup_x64.exe') $pins.vbCable.publisher
[pscustomobject]@{ IsccPath = $compiler; VBCableDirectory = $driverDirectory; DriverArchive = $driverZip }
