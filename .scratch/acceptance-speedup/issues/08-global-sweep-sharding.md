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

- [x] 枚举模式落地：全部 21 job 在枚举模式下完整跑完（无中途崩溃），per-job descriptor 序列落盘；同一树连跑两次序列确定（枚举确定性门）。
- [x] 清扫阶段：唯一 descriptor 集跨 job 去重后按并发 8 扇出，worker 各写 fragment，合并幂等（复用 06 合并器）；合并后规范缓存条目数 = 唯一 descriptor 数。
- [x] 热跑阶段：全部 job 以热缓存跑，summary mode 记 `acceptance-sweep`；各 Solver job 的 warm misses 记录（0 为通过形态，>0 如实记录为枚举缺口）。
- [x] Tier B 差分门：清扫全量 vs 02 串行基线——compare_summaries 排除集 = 计时排除集 + `appdata` + `combo_cache` + `solver_profile` + `mode`；不变量：各 Solver job `hits+misses==calls`、`report_fingerprints`（含 keys 请求序键）逐字段相等、断言总数与 pass_lines 相等（ADR-0006 修订四）。
- [x] 饱和度与墙钟实测：清扫段各车道 busy 时间占比、三段各自墙钟、总墙钟记录在案；清扫段墙钟与 Σ唯一请求耗时/并发数的量级关系解释在案（先例 = 02 的墙钟分解）。
- [x] `--acceptance-no-reuse` 基线模式行为不变：不枚举、不清扫、不加载不写入缓存（与 06 的基线模式同一开关语义）。

## Blocked by

- 06

## Comments

### 实现记录（2026-10-02 交付）

- `scripts/combat/combo_solver.gd`：①枚举模式 = env `FTG_SOLVER_ENUMERATE`（编排器专用、不进验收参数、`--acceptance-no-reuse` 下强制失效——先例 04 隐藏开关）；miss 记 `{digest, descriptor}` JSON 行（整文件重写，访问序含重复）、返回与 `_refused_base` 同形的完整拒绝 stub（`_enumerate_intercept` 仅拦 cacheable 请求，不可键请求照常现算）；命中返回真实报告；三入口（solve/analyze/analyze_manifest）统一拦截点。②`_canonical_variant` 的机械逆 `_CanonicalReader`（byte 游标；typed 数组按属性提示重建——hint 是 `PROPERTY_HINT_TYPE_STRING`、hint_string 形如 `4:`/`24/17:HitProfile`，脚本类元素逐元素进类型化局部数组：运行时构造器对非 ClassDB 类校验不可靠）+ `_rehydrate_canonical`/`_rehydrated_table`。③`_sweep_replay(descriptor)`：解码 → 重建 SolverOptions（manifest_path/注入表/.facings/.start/.spatial/options_present 逐字段）→ 调真实入口 → `_last_request`（`_cache_query` 对 cacheable 请求记录）与 descriptor 逐字节全等校验，不等即 ok=false（枚举缺口，热跑兜底）。
- `tools/solver_sweep_worker.gd`（新）：读 `FTG_SWEEP_TASK_FILE` JSONL → 逐条 `_sweep_replay` → `SWEEP_WORKER_RESULT=` 行 + quit(0/1)；存储路径即 06 fragment。
- `tools/run_acceptance.py`：`--sweep`（三段式：import 栅栏 → 枚举段并行[产物全部丢弃，只留 per-job descriptor 文件] → 跨 job 去重按 digest 序扇出 worker[每任务一进程、独立 APPDATA、写 sweep/workers/worker-*.fragment] → merge 进 canonical → 热跑 mode=`acceptance-sweep`）与 `--sweep-stage enumerate`（确定性门用：只跑枚举段）；`sweep.json`（三段墙钟/逐 job 枚举计数/逐任务行含 exit+seconds+replay_ok/lane_busy_ratio/warm misses）；worker 与非枚举 job 的 env 显式剔除 `FTG_SOLVER_ENUMERATE`（防编排器进程自身环境泄漏）；`--sweep --no-reuse` 直接 parser.error。
- 测试：`tests/test_solver_cache.gd` +4 组用例（枚举 stub 序列/双跑逐字节确定/命中返回真实报告、canonical round-trip 逐字节全等、replay 重建+损坏/未知入口响亮失败）——**双模式形态**：无 env 时全套断言（自有文件），验收枚举跑中运行时只断言 stub 行为并把请求照常记进 job 级序列（`_test_snapshot/restore_enumeration` 连序列一起恢复，防 job descriptor 文件被空序重写截断）；`tools/test_run_acceptance.py` SweepTests 6 例。

### 关键发现与教训

- **test_hit_profiles 有报告内容守卫的后续请求**（`_find_route(...) == null` 即 return，之后两个变异表 solve 不发生）：stub 枚举看不见它们 → 冷清扫首跑热跑 miss 2（约 500s 就地现算，tier B 仍全等=结果正确）。这是 AC#3 的枚举缺口实形：**跑一次后 warm fragment 并入 canonical 即自愈**（下次枚举段请求 1 命中→真报告→守卫通过→请求 2/3 也命中）。2026-10-02 的“六重 job 无数据依赖”grep 验证不含 hit_profiles，本票实测补上这一例外。
- **test_solver_cache 自清进程内缓存**（它测的就是缓存本身）：对满缓存照样枚举 34 条微表请求、热跑照样 miss——门断言按“重 job 0 请求 0 miss + solver_cache 如实记录”分层，不做全 0 死句。
- typed 数组还原的正确口径：`get_property_list` 对 `Array[String]`/`Array[HitProfile]` 报 hint=23（`PROPERTY_HINT_TYPE_STRING`）而非 31（`PROPERTY_HINT_ARRAY_TYPE`）；`Array(base, TYPE_OBJECT, class_name, script)` 构造器对脚本类元素校验失败（报 "does not inherit"），逐元素 append 进类型化局部数组才可靠。
- GDScript `var x := parse_value()` 之类从 Variant 推断会以 warning-as-error 拒绝编译；MSYS bash 下 gate 脚本的 heredoc 内 `EOF` 与外层 python 包装脚本撞分隔符会让 patch 静默错位。

### Gate 证据（`.scratch/acceptance-speedup/sweep-08/`，gate.sh 可复跑，GATE_SKIP 支持阶段复用；gate.log/gate2.log/gate3.log 为增量执行日志，最终门以 gate3.log 的完整后置检查为准）

- **gate 1a（子集枚举确定性）PASS**：冷缓存枚举跑两次，3 个含请求 job 的 descriptor 序列逐字节相等（53 请求行）。
- **gate 1b（全树枚举 = AC#1）PASS**：全部 21 job 枚举模式完整跑完（stub 下 FAIL 计数非致命、job 退出码非零按约丢弃），11 个含请求 job 的序列双跑逐字节相等；**127 请求行 → 62 全局唯一 descriptor**（比 02 metrics 口径的 ~30 唯一多——charge_motion/launcher_air_exits 直调 ComboSolver 不经 metrics，枚举把它们全看见了）；**枚举段墙钟 46.5s（全树）**——分钟级目标达成，实为秒级。
- **gate 2（stub 形态 Tier B）PASS**：普通并行跑垫满缓存（gate-2-seed tier B 对 02 基线子集逐字段相等）后，sweep 跑对满缓存：重 job（smoke/entry/hit）枚举 0 请求、0 任务、热跑 0 miss（枚举段每 job 2-3s）——门自洽先于真扇出；gate-2 tier B 同样全等。
- **gate 3（冷清扫全链路 Tier B）PASS**：冷缓存 sweep：枚举 28 唯一 → 28 worker 全 replay_ok/exit 0 → merge +28 新条目 → 热跑；tier B 对 02 基线子集逐字段相等（fingerprint/keys/断言计数/退出码，`--invariant-side right`）+ test_solver_cache 指纹包含（本票 +断言，pass_lines 排除）。warm misses 如实记录：`{test_hit_profiles: 2}`（见上）。
- `--no-reuse`：SweepTests 断言与 06 同语义（不枚举不清扫不进缓存 IO，二者同给直接报错）；门 2 的 seed 普通跑同时回归了“非 sweep 模式零变化”。

### 饱和度与墙钟（定向子集：smoke/solver_cache/solver_entry/hit_profiles）

- 三段墙钟：import 4.6s、枚举 18.2s、清扫 547.7s、热跑 530.7s、总 1101s。
- 清扫段：28 任务/8 车道，busy 1478.5s，lane busy ratio **0.338**；理想下界 Σbusy/8 = 184.8s vs 实际 547.6s。
- **量级关系解释**：定向子集只有 5 个重任务（合计 1460s，其中单最长 546.1s）+ 23 个微表任务（19s）——墙钟 = max(最长任务, Σbusy/lanes) = 546s ≈ 实测 547.6s，**尾部主导而非车道不足**；微任务把 busy 摊薄。全量（62 唯一、重任务占绝大多数）车道在最长任务之后有充足填舱，busy 比将显著抬升——结构性饱和的完整实测留 07 终证。
- 热跑墙钟 530.7s 中 ~500s = hit_profiles 枚举缺口的 2 个请求就地现算（串行在 job 内）——首跑一次性成本，跑后自愈（见上）。

### 定案依据（2026-10-02 grilling）

- **用户目标**：solver 性能尽量高（为未来连段边增长保持 ≤1h 余量）+ 全量期间 8 核饱和；分片由条件票转正（取代 spec/ADR-0006 原 ">20min 才触发" 条款，修订四记录）。修复先行：04 → 06（含 AC#1 analyze 入口缓存修复）→ 本票 → 07 终证。
- **机制选型 B2（全局前置清扫）胜出** vs B1（单 job 预热）：饱和结构性（平坦清单天然填满车道）、跨 job 去重白拿（去重发生在 job 开跑之前，消解"并行 job 互相看不见缓存"的冷跑劣势）、三段静态时序无调度智慧、墙钟模型可预测（枚举分钟级 + Σ唯一请求耗时/并发 + Σ热跑轻 job）。
- **前置验证**：`_check` 非致命；六重 job（combo/route/cycles/spatial/entry/move_table）无 report 内容数据依赖；warm miss 就地现算兜底正确性。
- **量级（02 基线实测，含争用膨胀，比例为准）**：test_combo_solver 16,637s/27 请求/4.64M 叶次（唯一 ~1.7M）、cycles 9,607s/10/2.90M、route 8,601s/15/2.83M、spatial 4,269s/13/1.45M、replay 3,209s/3/1.09M、move_table 2,791s/6/0.86M、hit 2,043s/4/0.70M、entry 1,816s/19/0.62M——全局唯一请求总量 ≈ 11M+ 叶次是清扫段墙钟的下界换算依据；04 落地后按比例缩小。
