# Run elevated only for an agreed, temporary interruption of the selected sender.
param(
    [Parameter(Mandatory)][int]$SenderProcessId,
    [Parameter(Mandatory)][ipaddress]$ReceiverAddress,
    [ValidateRange(5,30)][int]$Seconds = 15
)
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Windows administrator approval is required for the temporary firewall rule.'
}
if ($ReceiverAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
    throw 'Use the selected receiver IPv4 address.'
}
$sender = Get-Process -Id $SenderProcessId
if ($sender.ProcessName -ne 'airflash-engine' -or -not $sender.Path) {
    throw 'The selected sender process identity changed; no rule created.'
}
$ruleName = 'PodCast-qualification-' + [guid]::NewGuid().ToString('N')
$directory = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) 'artifacts'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$report = Join-Path $directory ($ruleName + '.txt')
"Planned rule: $ruleName`nIf this elevated host is forcibly closed, remove only this rule with: Remove-NetFirewallRule -Name '$ruleName'" | Set-Content -LiteralPath $report
$createdRule = $null
try {
    $createdRule = New-NetFirewallRule -Name $ruleName -DisplayName $ruleName -Direction Outbound -Action Block -Profile Any -Program $sender.Path -RemoteAddress $ReceiverAddress.IPAddressToString
    'Rule created.' | Add-Content -LiteralPath $report
    Write-Output "Blocking this sender executable (including reconnects) to the selected receiver for $Seconds seconds. Recovery rule name: $ruleName"
    Start-Sleep -Seconds $Seconds
} finally {
    if ($createdRule) {
        $createdRule | Remove-NetFirewallRule -ErrorAction Stop
        'Rule removed.' | Add-Content -LiteralPath $report
    }
}
Write-Output 'Temporary sender rule removed. Verify app state, reconnect and listening separately.'
