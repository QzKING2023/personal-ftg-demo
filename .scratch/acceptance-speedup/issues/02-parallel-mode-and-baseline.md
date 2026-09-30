# 02: 并行模式与串行全量基线

Status: in-progress(2026-09-30:并行实现+子集门+探针已交付;全量串行基线与并行差分门为余项)
Parent: [spec.md](../spec.md)
Blocked by: 01

## What to build

在 01 的编排器上加并发:import job 先单独完成(共享导入缓存目录的写保护栅栏),测试 job 以默认并发 8 扇出,每个 job 保持 01 的隔离口径。本票同时交付**唯一的全量串行基线**:Python 串行全量过夜跑一次并归档,此后所有差分门(并行、`_delay_dfs`、缓存、终证)都对着它比,不再跑第二遍串行全量。

## User stories covered

1, 2, 6, 7。

## Acceptance criteria

- [x] import 先行栅栏:import job 退出后测试 job 才启动;测试 job 对共享目录只读的假设用"两个并发实例实跑一次"经验验证(结果记录在 Comments)。
- [x] 并发默认 8、`--concurrency` 可调;等待池满员补位,不按完成序写 summary(保持规范 job 序)。
- [ ] 串行全量基线:一次后台过夜运行完成,summary、状态文件、总耗时归档到本票的 scratch 验收目录。
- [ ] 并行差分门:并行全量 vs 串行基线,summary 除 `seconds` 外逐字段相等(含各 job 的 solver metrics、fingerprint 集合、退出码、script_errors)。
- [ ] 记录并行墙钟与最长 job 耗时(预期墙钟 ≈ 最长 job + 栅栏时间);若与预期量级不符,先解释再收票。
- [x] 操作注意写进 Comments:并行期间不得按进程名批量杀 Godot(会误杀并行实例);开发与验收并行时留意核数与共享目录。

## Blocked by

- 01

## Comments

### 交付与证据(2026-09-30)

- 实现:`tools/run_acceptance.py` 加并行模式——import 同步先行(栅栏:共享导入缓存目录的写保护),其余 job 按规范序提交进 ThreadPoolExecutor(`--concurrency` 默认 8、`--jobs` 别名、`--serial` 强制 1),池满员自动补位;summary.json 渐进写且**恒为规范 job 序**(非完成序),stdout 逐 job 完成行(完成序,行内自带 job 名,行数判活不受影响);失败谓词、summary schema、runner.status.txt 契约与串行完全一致。
- 调度单测:`tools/test_run_acceptance.py` 8 例全绿——乱序完成下 summary 保持规范序、import 栅栏(全部测试 job 开始时刻 ≥ import 结束)、并发上限不被突破、默认并发确实扇出、`--serial`/`--jobs 1` 恒不重叠、失败谓词(非零退出码与正 script_errors 两分支)。
- 子集对拍门:`.scratch/acceptance-speedup/difftest-02/gate.sh` PASS(gate.status.txt `exit=0`)——同一子集树(import、test_smoke、test_crouch_stationary、test_solver_cache、diagnose_inputs、main-smoke)三跑:PS 串行 vs Py 串行(新调度器的串行路径与旧 runner 仍对等)、Py 串行 vs Py 并行,summary 除计时字段逐字段相等,退出码与状态文件三侧一致(全 0)。
- 共享目录只读性探针:`difftest-02/shared-dir-probe.sh` PASS——两并发 test_smoke 实例(各自 APPDATA/LOCALAPPDATA/runtime,与编排器同发射方式)对真实树:双双 exit=0、PASS 行全等、solver metrics 除 `*_ms` 墙钟字段外逐字段相等(与 compare_summaries.py 的排除同类)、运行期间 `.godot` **零写入**。
- 子集量级(仅形态参考,非全量结论):ps 墙钟 27s / py 串行 29s / py 并行 23s,最长 job ~18s——并行墙钟 ≈ 最长 job + import 栅栏时间,符合预期形态;子集太小,墙钟判据以全量差分门实测为准。

### 操作注意(并行期间)

- **不得按进程名批量杀 Godot**(`taskkill //IM` 会误杀并行实例与其他会话的验收实例);要停单个 job 用其 PID。
- 开发与验收并行时留意:默认并发 8 占 8 逻辑核(机器 24 逻辑核),`--concurrency` 可下调留核;重 Solver job 并行时留意内存峰值(31.5GB 物理内存)。
- **全量基线运行期间工作树不得改动**——此后所有差分门对着它;基线树状态 = commit d425814 + 本票编排器提交。

### 待办(过夜后)

- 串行全量基线归档:`.scratch/acceptance-speedup/baseline-02/serial-full/`(summary.json、runner.status.txt、编排器 stdout、总耗时)。
- 并行全量差分门 + 墙钟/最长 job 实测记录,两项落 Comments 后收票。
