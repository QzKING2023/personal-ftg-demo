param([string]$run = "serial-full")
$base = "D:\Godot\Program\ftgdemo\.scratch\acceptance-speedup\baseline-02"
$stdout = Join-Path $base "$run.stdout"
$dir = Join-Path $base $run
$status = Join-Path $dir "runner.status.txt"

if (-not (Test-Path $dir)) { Write-Host "no such run dir: $dir"; exit 1 }
$jobs = (Get-Content $stdout -ErrorAction SilentlyContinue).Count
if ($null -eq $jobs) { $jobs = 0 }
Write-Host ("run={0}   jobs completed: {1} / 21   (now: {2})" -f $run, $jobs, (Get-Date -Format "HH:mm:ss"))

$latest = Get-ChildItem "$dir\*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latest) {
    Write-Host ("latest job log : {0}   last write: {1}" -f $latest.Name, $latest.LastWriteTime.ToString("HH:mm:ss"))
    $age = ((Get-Date) - $latest.LastWriteTime).TotalMinutes
    if ($age -gt 30) { Write-Host ("WARNING: latest log silent for {0:N0} minutes" -f $age) }
}
$running = Get-ChildItem "$dir\runtime-*" -Directory -ErrorAction SilentlyContinue | Where-Object { ((Get-Date) - $_.LastWriteTime).TotalMinutes -lt 10 }
if ($running) { Write-Host ("active runtime dirs: {0}" -f ($running.Name -join ", ")) }

if (Test-Path $status) {
    Write-Host ("RUN FINISHED -> " + (Get-Content $status -Raw).Trim())
    $summary = Get-Content (Join-Path $dir "summary.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host ("mode={0}  total_seconds={1}  total_assertions={2}" -f $summary.mode, $summary.total_seconds, $summary.total_assertions)
    $bad = $summary.tests | Where-Object { $_.exit -ne 0 -or $_.script_errors -gt 0 }
    if ($bad) { $bad | ForEach-Object { Write-Host ("FAILED JOB: {0} exit={1} script_errors={2}" -f $_.test, $_.exit, $_.script_errors) } }
    else { Write-Host "all jobs green" }
    $longest = $summary.tests | Sort-Object seconds -Descending | Select-Object -First 1
    Write-Host ("longest job: {0} ({1} s)" -f $longest.test, $longest.seconds)
} else {
    Write-Host "run not finished yet (runner.status.txt absent)"
}
