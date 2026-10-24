# Numeric process observations only. Listening and queue checks remain separate.
param([ValidateRange(1,120)][int]$Minutes = 30)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$processes = @(Get-Process -Name PodCast,airflash-engine -ErrorAction SilentlyContinue)
if (@($processes | Where-Object ProcessName -eq 'PodCast').Count -ne 1 -or
    @($processes | Where-Object ProcessName -eq 'airflash-engine').Count -ne 1) {
    throw 'Start exactly one PodCast playback session before observing.'
}
$processIds = $processes.Id
$directory = Join-Path $repo 'artifacts'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$report = Join-Path $directory ("session-{0}.jsonl" -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
Write-Output "Observing $Minutes minutes; report: $report"
for ($sample = 0; $sample -le $Minutes * 2; $sample++) {
    foreach ($targetId in $processIds) {
        $process = Get-Process -Id $targetId
        $row = [ordered]@{
            utc = [DateTime]::UtcNow.ToString('o'); process = $process.ProcessName; process_id = $targetId
            private_bytes = $process.PrivateMemorySize64; working_set = $process.WorkingSet64
            handles = $process.HandleCount; cpu_seconds = $process.CPU
        }
        $row | ConvertTo-Json -Compress | Add-Content -LiteralPath $report -Encoding utf8
    }
    if ($sample % 2 -eq 0) { Write-Output ("Observed {0}/{1} minutes" -f ($sample / 2), $Minutes) }
    if ($sample -lt $Minutes * 2) { Start-Sleep -Seconds 30 }
}
Write-Output 'Observation finished. This does not establish audible continuity.'
