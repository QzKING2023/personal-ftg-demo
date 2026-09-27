param(
    [string]$Engine = 'D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe',
    [string]$Output = '.scratch/ftg-combat-foundation/acceptance-2026-09-17/final',
    [switch]$NoReuse
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $logRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Output))
    New-Item -ItemType Directory -Force $logRoot | Out-Null
    $jobs = @(@{name='import'; args=@('--editor','--quit')})
    $jobs += @(Get-ChildItem tests/test_*.gd | Sort-Object Name | ForEach-Object {
        @{name=$_.BaseName; args=@('-s', "res://tests/$($_.Name)")}
    })
    $jobs += @{name='diagnose_inputs'; args=@('-s','res://tests/diagnose_inputs.gd')}
    $jobs += @{name='main-smoke'; args=@('--quit-after','300')}
    $results = @()
    foreach ($job in $jobs) {
        $runtime = Join-Path $logRoot ('runtime-' + $job.name)
        New-Item -ItemType Directory -Force $runtime | Out-Null
        $env:APPDATA = $runtime
        $env:LOCALAPPDATA = $runtime
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $jobArgs = @('--headless','--path',$projectRoot,'--log-file',(Join-Path $runtime 'engine.log')) + $job.args
        if ($NoReuse -and $job.name -ne 'import' -and $job.name -ne 'main-smoke') {
            $jobArgs += @('--', '--acceptance-no-reuse')
        }
        $log = Join-Path $logRoot "$($job.name).log"
        $savedPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $Engine @jobArgs *> $log
        $code = $LASTEXITCODE
        $ErrorActionPreference = $savedPreference
        $watch.Stop()
        # Godot 脚本错误可能中止单个测试函数而退出码仍是 0，必须另外检查。
        # 计数必须显式归一为整数：缺行、null 或解码异常一律按 0 处理，不得产生假失败。
        $scriptErrors = [int](@(Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|Parse Error:|^FAIL|TEST\(S\) FAILED|CrashHandlerException').Count)
        $metricsLine = Get-Content -LiteralPath $log -Encoding UTF8 | Where-Object { $_ -match '^ACCEPTANCE_SOLVER_METRICS_JSON=' } | Select-Object -Last 1
        $metrics = if ($metricsLine) { $metricsLine.Substring('ACCEPTANCE_SOLVER_METRICS_JSON='.Length) | ConvertFrom-Json } else { $null }
        $row = [pscustomobject]@{
            test=$job.name; exit=[int]$code; script_errors=$scriptErrors
            pass_lines=[int](@(Select-String -LiteralPath $log -Pattern '^PASS').Count)
            assertions=[int](@(Select-String -LiteralPath $log -Pattern '^PASS').Count)
            seconds=[math]::Round($watch.Elapsed.TotalSeconds,2)
            solver_calls=if ($metrics) {[int]$metrics.calls} else {0}
            solver_underlying_calls=if ($metrics) {[int]$metrics.underlying_calls} else {0}
            solver_reuse_hits=if ($metrics) {[int]$metrics.reuse_hits} else {0}
            solver_reuse_hit_rate=if ($metrics) {[double]$metrics.reuse_hit_rate} else {0.0}
            solver_elapsed_ms=if ($metrics) {[double]$metrics.elapsed_ms} else {0.0}
            combo_cache=if ($metrics) {$metrics.combo_cache} else {@{}}
            report_fingerprints=if ($metrics) {@($metrics.reports | ForEach-Object {[string]$_.fingerprint})} else {@()}
            appdata=$runtime
        }
        $results += $row
        $row | ConvertTo-Json -Compress | Write-Output
        $results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logRoot 'summary.json')
    }
    $totalCalls = [int](@($results | Measure-Object -Property solver_calls -Sum).Sum)
    $totalReuseHits = [int](@($results | Measure-Object -Property solver_reuse_hits -Sum).Sum)
    $summary = [ordered]@{
        mode=if ($NoReuse) {'baseline-no-acceptance-reuse'} else {'acceptance-reuse'}
        total_seconds=[math]::Round([double](@($results | Measure-Object -Property seconds -Sum).Sum),2)
        total_assertions=[int](@($results | Measure-Object -Property assertions -Sum).Sum)
        total_solver_calls=$totalCalls
        total_solver_underlying_calls=[int](@($results | Measure-Object -Property solver_underlying_calls -Sum).Sum)
        total_solver_reuse_hits=$totalReuseHits
        solver_reuse_hit_rate=if ($totalCalls -gt 0) { [double]$totalReuseHits / [double]$totalCalls } else { 0.0 }
        tests=$results
    }
    $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $logRoot 'summary.json') -Encoding UTF8
    # 失败只认真实的非零进程退出码或正数脚本错误；计数缺失按 0 处理，不产生假失败。
    $exitCode = if (@($results | Where-Object { [int]$_.exit -ne 0 -or [int]$_.script_errors -gt 0 }).Count) { 1 } else { 0 }
    Set-Content -LiteralPath (Join-Path $logRoot 'runner.status.txt') -Value ("exit=" + $exitCode)
    exit $exitCode
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    Pop-Location
}
