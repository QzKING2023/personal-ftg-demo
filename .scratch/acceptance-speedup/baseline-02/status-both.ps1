# Ticket 02 dual-run status: serial-full + parallel-full in one shot (PS 5.1, ASCII).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File status-both.ps1
$base = "D:\Godot\Program\ftgdemo\.scratch\acceptance-speedup\baseline-02"
$runs = @("serial-full", "parallel-full")

function Show-Run([string]$run) {
    Write-Host ("==================== {0} ====================" -f $run)
    $dir = Join-Path $base $run
    $stdout = Join-Path $base "$run.stdout"
    $status = Join-Path $dir "runner.status.txt"

    if (-not (Test-Path $dir)) { Write-Host "no such run dir: $dir"; Write-Host ""; return }

    # pid files hold MSYS pids (Git Bash), invisible to Get-Process; match by command line instead.
    $py = Get-CimInstance Win32_Process -Filter "Name like 'python%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*run_acceptance.py*" -and $_.CommandLine -like "*$run*" }
    if ($py) { Write-Host ("runner process : alive (win pid {0})" -f (($py.ProcessId | Sort-Object) -join ",")) }
    else { Write-Host "runner process : not found" }

    $jobs = 0
    if (Test-Path $stdout) { $jobs = @(Get-Content $stdout).Count }
    Write-Host ("jobs completed : {0} / 21   (now: {1})" -f $jobs, (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

    $launchLog = Join-Path $base "launch.log"
    if ($run -eq "parallel-full") { $launchLog = Join-Path $base "parallel-launch.log" }
    if (Test-Path $launchLog) {
        $first = Get-Content $launchLog -TotalCount 1
        if ($first -match "^launch: (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})") {
            $t = [datetime]::ParseExact($matches[1], "yyyy-MM-dd HH:mm:ss", $null)
            $end = Get-Date
            if (Test-Path $status) { $end = (Get-Item $status).LastWriteTime }
            $span = $end - $t
            Write-Host ("wall clock     : {0}  (launched {1})" -f ("{0:d\.hh\:mm\:ss}" -f $span), $t.ToString("MM-dd HH:mm:ss"))
        }
    }

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
    Write-Host ""
}

foreach ($r in $runs) { Show-Run $r }
