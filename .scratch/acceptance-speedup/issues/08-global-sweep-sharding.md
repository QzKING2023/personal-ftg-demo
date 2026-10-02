# 08: 全局前置清扫分片（枚举 → 唯一请求扇出 → 热跑）

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 06

## What to build

分片的获批形态（2026-10-02 grilling 定案，由条件票转正）：不按 job 逐个预热，而是全局三段式——import 栅栏后，编排器先以**枚举模式**把全部 job 快速过一遍（每个 Solver 请求只记录 descriptor、返回拒绝形态的完整 stub 报告、不计算，分钟级），收集全局唯一 descriptor 集（跨 job 去重）；然后唯一请求铺满并发车道并行算完（每条写 06 的缓存 fragment）；合并进规范缓存后，所有 job 以热缓存正常跑。饱和是结构性的：清扫阶段是一张平坦的独立计算单元清单，车道天然填满，无需动态补位。

关键机制：

- **枚举模式**：ComboSolver 加编排器专用开关（env/参数传递，不进验收参数，先例 = 票据 04 的隐藏回退开关）。开启时 miss 记 descriptor 并返回拒绝形态的完整 SolverReport（不计算）；命中（06 规范缓存已有该条目）则返回真实报告。枚举跑的 stdout、summary、退出码全部丢弃，不进任何门。
- **worker 入口**："descriptor → 重算 → 写 fragment"。descriptor 已含完整表与选项（`_build_solve_request` 全量序列化），重建请求是纯机械操作；与 06 的 fragment 格式一并设计。
- **正确性兜底**：热跑阶段出现 miss 就地现算（慢但结果正确）；`_check` 非致命（FAIL 只计数，tests/test_combo_solver.gd:828）且重 job 请求序列无数据依赖（2026-10-02 grep 验证六个重 job 零命中"用 report 内容构造后续请求"），枚举跑能完整走完；warm misses>0 记录为枚举缺口（性能债），不判死。

## User stories covered

22（2026-10-02 起为无条件票）、23、25。

## Acceptance criteria

- [ ] 枚举模式落地：全部 21 job 在枚举模式下完整跑完（无中途崩溃），per-job descriptor 序列落盘；同一树连跑两次序列确定（枚举确定性门）。
- [ ] 清扫阶段：唯一 descriptor 集跨 job 去重后按并发 8 扇出，worker 各写 fragment，合并幂等（复用 06 合并器）；合并后规范缓存条目数 = 唯一 descriptor 数。
- [ ] 热跑阶段：全部 job 以热缓存跑，summary mode 记 `acceptance-sweep`；各 Solver job 的 warm misses 记录（0 为通过形态，>0 如实记录为枚举缺口）。
- [ ] Tier B 差分门：清扫全量 vs 02 串行基线——compare_summaries 排除集 = 计时排除集 + `appdata` + `combo_cache` + `solver_profile` + `mode`；不变量：各 Solver job `hits+misses==calls`、`report_fingerprints`（含 keys 请求序键）逐字段相等、断言总数与 pass_lines 相等（ADR-0006 修订四）。
- [ ] 饱和度与墙钟实测：清扫段各车道 busy 时间占比、三段各自墙钟、总墙钟记录在案；清扫段墙钟与 Σ唯一请求耗时/并发数的量级关系解释在案（先例 = 02 的墙钟分解）。
- [ ] `--acceptance-no-reuse` 基线模式行为不变：不枚举、不清扫、不加载不写入缓存（与 06 的基线模式同一开关语义）。

## Blocked by

- 06

## Comments

### 定案依据（2026-10-02 grilling）

- **用户目标**：solver 性能尽量高（为未来连段边增长保持 ≤1h 余量）+ 全量期间 8 核饱和；分片由条件票转正（取代 spec/ADR-0006 原 ">20min 才触发" 条款，修订四记录）。修复先行：04 → 06（含 AC#1 analyze 入口缓存修复）→ 本票 → 07 终证。
- **机制选型 B2（全局前置清扫）胜出** vs B1（单 job 预热）：饱和结构性（平坦清单天然填满车道）、跨 job 去重白拿（去重发生在 job 开跑之前，消解"并行 job 互相看不见缓存"的冷跑劣势）、三段静态时序无调度智慧、墙钟模型可预测（枚举分钟级 + Σ唯一请求耗时/并发 + Σ热跑轻 job）。
- **前置验证**：`_check` 非致命；六重 job（combo/route/cycles/spatial/entry/move_table）无 report 内容数据依赖；warm miss 就地现算兜底正确性。
- **量级（02 基线实测，含争用膨胀，比例为准）**：test_combo_solver 16,637s/27 请求/4.64M 叶次（唯一 ~1.7M）、cycles 9,607s/10/2.90M、route 8,601s/15/2.83M、spatial 4,269s/13/1.45M、replay 3,209s/3/1.09M、move_table 2,791s/6/0.86M、hit 2,043s/4/0.70M、entry 1,816s/19/0.62M——全局唯一请求总量 ≈ 11M+ 叶次是清扫段墙钟的下界换算依据；04 落地后按比例缩小。
