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

### 基线前置:08 测试期望债的发现与修复(2026-09-30)

- **发现**:03 的 before-run(真实树真实测试)暴露 `test_combo_solver` 3 条 FAIL——边计数 55(08 后实为 71)、空中路线终局 `[FINISHER]`(j5D 不设终结技)、pairs 配置关系清单缺 08 的 16 条。03 等价门已把它定性为"票据 08 边基线 71 条后测试未同步的既有债,与插桩无关"(dd756fe);在唯一串行全量基线发射前必须修绿,否则红灯烧进基线、08 修完树变基线作废。
- **权威值实测**:`baseline-02/probe_expectations.gd` 以测试同代码路径(analyze_reused("default") + 逐字复制的 _replay_inputs/_step_logical)实测:edges=71、routes=1753、空中 D 相关边 17 条(jA/jB/jC→三新招取消 9 全 valid;6D→三新招 AIR_EXIT 3 valid;2D→三新招 AIR_EXIT 3 枚举但 invalid;j6D→5B NORMAL_LINK;j2D→214C HIT_LANDING_CANCEL)、路线 5A→5B→6A→jA→jB→j5D 回放 end_reasons=[]。与 test_solver_route 已通过的 71 期望互证。
- **修复**(commit bd7a0be):边计数 55→71(净增 16 = 17 − 旧 jB→jD 迁移)、pairs 清单 +16、终局期望 `[FINISHER]`→`[]`(08 设计裁量"收束不设 is_finisher,终局经取消窗关闭在观测窗口之后")。
- **时序**:等 03 的 before/after 引擎全部退出(15:12)后才改文件——避免跨会话污染其验收;修复后单 job 定向验证(`baseline-02/verify-fix.sh`,编排器同口径)全绿才发射基线。

### 修复验证与基线发射(2026-09-30 晚)

- **定向验证全绿**:`baseline-02/verify-fix/summary.txt`——单 job 裸机 3h55m,PASS=3714 / FAIL=0 / exit=0(= 03 before 基线 3711 PASS + 3 条修复转绿,算术吻合);三条修复断言(71 边、combo-end 开放、pairs 配置关系)逐条 PASS;metrics calls=27。
- **串行全量基线已发射**:19:10:46(pid 见 launch.log),`--serial` 全量 21 job,输出 `baseline-02/serial-full/`,stdout 逐 job 行判活。预计 12-16h(test_combo_solver 单 job 裸机即 3h55m),明晨完成。
- **基线运行期间(至归档完成)工作树冻结**:任何会话不得改动战斗脚本、测试、招式数据——基线是唯一串行全量,树变即作废。

### 基线第一跑(attempt1)与二轮 08 期望债(2026-10-01 晨)

- attempt1 完成(2026-09-30 19:10:46 → 10-01 07:56,总 45948.69s ≈ 12.76h,21 job):19 绿 2 红——test_replay_acceptance(exit=1)与 test_solver_entry(exit=1)。红色基线不能作差分参照,已归档 `baseline-02/serial-full-attempt1/`;最长 job test_combo_solver 14017.5s(3.9h,前日修复在真实全量下站住)。
- 定性(与 combo_solver 债同类——08 会话纸面更新测试期望但从未运行):
  - entry 候选序:实际为字典序 `j2D/j5D/j6D/jA/jB/jC`(集合与 J 键记法均正确,旧期望沿 jA/jB/jC 时代目录序,两者在当时恰好一致);
  - entry 空中链:显式空中起始下 `jA→jB→j5D` 不再成立——j5D 起手 6 帧使第三击落在木桩自然受身之后(07 时代旧 jD 第 14 帧勉强挤进);显式起始实际验证链为 `j5D` 单击 [7] 与 `jA→j6D` [5,12](timing-valid),`["jA","jB"]` 等三条为断链如实上报(证据 `probe-entry4.stdout` 全路线清单);
  - replay:左向镜像记录断言仍指 `jB → jD`,实际记录已迁 `jB → j5D`(镜像 `6[A]` 仍在)。
- 修复(commit 4b900d9)+ 定向验证全绿(`verify-fix2/`,编排器同口径):test_solver_entry 53/0、test_replay_acceptance 123/0(`ALL REPLAY ACCEPTANCE TESTS PASSED`)。
- 注意:显式空中起始三击链消失是 j5D 帧数的数据后果(非回归)——若设计上要恢复,属 08 会话的 j5D 帧数据决策,与本票无关。

### 待办(基线完成后)

- 串行全量基线(第二跑,`serial-full/`)归档:summary.json、runner.status.txt、编排器 stdout、总耗时。
- 并行全量差分门(`--concurrency 8` 全量 vs 基线,compare_summaries 逐字段)+ 并行墙钟与最长 job 实测记录,两项落 Comments 后收票。
