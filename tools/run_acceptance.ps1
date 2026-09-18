param(
    [string]$Engine = 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe',
    [string]$Output = '.scratch/ftg-combat-foundation/acceptance-2026-09-17/final'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
$previousAppData = $env:APPDATA
try {
    $logRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Output))
    New-Item -ItemType Directory -Force $logRoot | Out-Null
    $env:APPDATA = Join-Path $logRoot 'runtime'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    $jobs = @(@{name='import'; args=@('--editor','--quit')})
    $jobs += @(Get-ChildItem tests/test_*.gd | Sort-Object Name | ForEach-Object {
        @{name=$_.BaseName; args=@('-s', "res://tests/$($_.Name)")}
    })
    $jobs += @{name='diagnose_inputs'; args=@('-s','res://tests/diagnose_inputs.gd')}
    $jobs += @{name='main-smoke'; args=@('--quit-after','300')}
    $results = @()
    foreach ($job in $jobs) {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $jobArgs = @('--headless','--path',$projectRoot,'--log-file',(Join-Path $logRoot 'engine.log')) + $job.args
        $log = Join-Path $logRoot "$($job.name).log"
        & $Engine @jobArgs *> $log
        $code = $LASTEXITCODE
        $watch.Stop()
        # Godot 脚本错误可能中止单个测试函数而退出码仍是 0，必须另外检查。
        $scriptErrors = @(Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|Parse Error:|^FAIL|TEST\(S\) FAILED|CrashHandlerException').Count
        $row = [pscustomobject]@{
            test=$job.name; exit=$code; script_errors=$scriptErrors
            pass_lines=@(Select-String -LiteralPath $log -Pattern '^PASS').Count
            seconds=[math]::Round($watch.Elapsed.TotalSeconds,2)
        }
        $results += $row
        $row | ConvertTo-Json -Compress | Write-Output
        $results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logRoot 'summary.json')
    }
    if (@($results | Where-Object { $_.exit -ne 0 -or $_.script_errors -ne 0 }).Count) { exit 1 }
} finally {
    $env:APPDATA = $previousAppData
    Pop-Location
}
