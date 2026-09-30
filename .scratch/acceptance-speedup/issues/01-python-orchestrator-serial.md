# 01: Python 编排器——串行模式与输出契约对等

Status: done (2026-09-30)
Parent: [spec.md](../spec.md)
Blocked by: 无,可立即开始

## What to build

用 Python 编排器顶替现有 PowerShell 验收 runner 的串行路径:同样的 job 集与规范序(import → 字母序 test_* → diagnose_inputs → main-smoke)、同样的每 job 独立 APPDATA/LOCALAPPDATA 隔离、同样的失败谓词与 summary.json 输出。本票只做串行——并发扇出是票据 02。完成标志是"快 job 子集对拍":同一棵工作树上 PS 串行与 Python 串行的 summary 除 `seconds` 外逐字段相等。

环境事实:机器仅有 Windows PowerShell 5.1(无 pwsh 7),Python 可用;引擎路径、后台运行、退出码落盘、以输出文件行数判活等沿用验收运行约定。PS 日志经 `*>` 重定向为 UTF-16LE、Python 直接捕获引擎 stdout(UTF-8)——对拍只比解析后的计数字段,不比原始日志字节。

## User stories covered

3, 4, 5, 6, 20(部分)。

## Acceptance criteria

- [x] job 集与规范序与旧 runner 完全一致;每个 job 独立 runtime 目录与 APPDATA/LOCALAPPDATA。
- [x] 失败谓词同构:非零退出码或正数 script_errors 判失败;计数缺失/解码异常一律按 0,不产生假失败。
- [x] summary.json 字段与语义与旧 runner 同构(含 solver metrics 解析与透传);runner 状态文件落盘 `exit=N`,编排器以该谓词决定自身退出码。
- [x] CLI 参数:引擎路径、输出目录、并发数(本票固定 1)、缓存路径(占位不实现)。
- [x] 子集对拍门:挑选覆盖全部输出形态的快 job(有 metrics 的、无 metrics 的、import、diagnose_inputs、main-smoke),PS 串行与 Python 串行各跑一遍,summary 除 `seconds` 外逐字段相等,退出码一致。
- [x] 后台运行兼容:`nohup` 拉起、退出码可从落盘文件恢复、输出文件行数增长可判活。
- [x] 旧 PS runner 保留不删(差分基线与回退路径)。

## 验收记录(2026-09-30)

- 对拍门:`.scratch/acceptance-speedup/difftest-01/gate.sh`——子集树(import、test_smoke[有 metrics]、test_crouch_stationary、test_solver_cache[无 metrics]、diagnose_inputs、main-smoke)上 PS 串行与 Python 串行先后跑进同一输出目录,`tools/compare_summaries.py` 逐字段比对 PASS,退出码与状态文件一致;证据见同目录 summary.ps/py.json、status.ps/py.txt、gate.out(gate.status.txt `exit=0`)。
- 排除字段说明:比对排除 `seconds`/`total_seconds`/`solver_elapsed_ms`(同为墙钟测量,同一 runner 重跑也不相等);ADR-0006 已加修订记录。
- PS 5.1 序列化怪癖由比对工具归一:空数组写 `{}`、单元素数组塌缩为标量,与 Python 输出视为相等。
- `--no-reuse` 基线模式真跑通过(mode=baseline-no-acceptance-reuse,全绿);进程内 argv/env 契约检查(21 job、`--` 分隔符位置、no-reuse 范围排除 import/main-smoke、APPDATA 注入)通过。
- 后台兼容:编排器逐 job 输出单行紧凑 JSON(flush),nohup 重定向下以行数判活可用;runner.status.txt 落盘 exit=N。

## Blocked by

- 无,可立即开始
