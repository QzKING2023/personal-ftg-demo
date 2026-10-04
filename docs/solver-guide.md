# Combo Solver 使用与回放

在项目目录直接运行，无需启动训练场或跑测试套件：

```powershell
$env:APPDATA = "$PWD/.scratch/ftg-combat-foundation/acceptance-2026-09-17/runtime"
& D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --log-file .scratch/ftg-combat-foundation/acceptance-2026-09-17/engine.log -s res://tools/solver_report.gd
# 加上静态空间网格
& D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --log-file .scratch/ftg-combat-foundation/acceptance-2026-09-17/engine.log -s res://tools/solver_report.gd -- --spatial
```

程序调用为 `ComboSolver.solve(options)`；`SolverOptions` 可指定 `manifest_path`、`move_table`、`start`、`facings`、`spatial`（以类声明为准）。默认共享表、地面中立、空缓存/方向历史、木桩地面中立、左右面向分别验证；显式空中起点通过 `SolverStartState.stance` 和 `air_frames` 描述。当前接口不能导入任意完整会话快照。

## 结论范围

2026-09-17 修正落地锁后，默认报告为 9 条配置边：8 有效、1 排除；34 条配置缺口、7 条可读路线、左右镜像一致、无已证明循环。

- `timing-valid`：70px 固定接触位探针的时序成立，木桩每帧被钉回相对距离。
- `spatial-valid`：可选地面左右镜像 48/64/80px **钉位**网格通过，身体为48×80、命中框取资源、垂直轨迹走真实会话；每个距离允许重新寻找空中延迟。它没有验证真实水平击退的累积，不是完整训练场命中保证。
- 真实击退回放：不钉位，从指定距离输入同一帧表才可验证该站位。当前地面和派生70px、空中48px在双面向训练场输入回放中接通；空中70px实际只完成前3击、伤害32.6，不能宣称五连可达。
- 配置缺口不进入合法路线；规则禁止的落地取消不再误报为“补配置即可成立”。循环仍需完整结算状态逐圈重现。8圈/2400帧/240帧恢复观测/40帧空中延迟上限均未增加，触顶仍报告截断或未完成观测。
- 被防路径标注（2026-09-25 票据 03）：每条链式/必杀边另在「来源招式被木桩站防/蹲防挡下」的探针中验证取消时序——来源在预期接触帧被防（ATTACK_BLOCKED，不产生命中）、目标在被防取消窗口内起手，目标自身接触结果（再被防/属性漏出命中/资料缺失/挥空）如实入注。被防不是 HIT：标注不改变路线/循环图；探针中预期命中帧收到被防结果按 blocked 断链上报。被防安全性（指定反击招式、时机、距离、版中/版边、左右面向）不在静态证明范围，一律 replay-required，由保留真实位置的训练场回放下结论（见 acceptance/03 反击矩阵）。

不搜索走位、中立、墙角、推挤、跨身或边界；循环仅属于 timing 层。旧落地边 jB→5D 被排除，因为空技着地恢复不可取消；恢复后的普通连接没有被证明。

## 代表帧表

F 为**正常战斗帧**；命中后的8个冻结物理帧用空输入跳过，不增加 F。未列帧为空输入，各动作键按一次后松开。输入恰在命中当帧的样本可用于脚本复现，不代表真人能在该帧看见命中后作出反应。

| 路线 | 正常帧输入（面向右） | 命中正常帧 | 总伤害 | 真实击退复验 |
| --- | --- | --- | --- | --- |
| 5A→5B→5D | F1 U；F6 I；F11 J | 6/11/16 | 35.2 | 70px，两侧3击 |
| 5B→214D | F1 I；F5 S；F6 S+A；F7 A；F8 J | 8/15 | 31.8 | 70px，两侧2击 |
| 5A→236C→jA→jB→jD | F1 U；F3 S；F4 S+D；F5 D；F6 K；F13 Space；F18 U；F22 I；F27 J | 6/13/22/27/31 | 53.0 | 48px，两侧5击；70px失败 |

面向左时仅镜像世界水平键：236 的 S+D/D 改为 S+A/A；214 的 S+A/A 改为 S+D/D。相对数字仍是236/214，U/I/K/J、Space和帧号不变。

训练场注入含一帧前导空帧：地面命中 tick=7/20/33，派生=9/24，48px空中=7/22/39/52/64。这些是输入适配测试的物理 tick，不要直接当成人类按键节拍。

旧落地样本保留作负例：沿空中起手到 F13 Space，改为 F39 U、F48 I、F54 J。钉位70px只命中 F6/13/43/55，共4击、41伤害；落地不启动5D。48px真实输入也只完成4击。它是 `timing-invalid`，不能再作为合法连段或循环证明。

完整回放和失败断点在 `tests/test_replay_acceptance.gd` 输出。当前独立入口输出可读文本；规格要求的稳定 `version=1` JSON 导出仍未实现，不能把普通文本日志称为该导出。

## 性能 profile v2（确定性计数）

`ComboSolver.last_request_profile_v2()` 返回上一个请求（solve/analyze/analyze_manifest 三入口之一）的确定性计数——只按调用点累计结构性事件，不读时钟；同一请求在同型运行下逐字段确定，是性能基线与增长回归门的口径（P0）。插桩常开、零语义影响：搜索语义、枚举顺序、报告字段与 v1 耗时分解（`last_request_profile()`，进验收 summary 的 `profile_totals`）都不受它影响。

| 字段 | 口径 |
| --- | --- |
| `structure_candidates` | 从表配置与缺口枚举得出的 (from, to, kind) 结构候选总数（含蓄力派生候选与缺口候选）；恒等式 `structure_candidates == edge_built + gap_built` |
| `context_attempts` | `_build_contexts` 生长循环内每次 `_context_via_*` 尝试（jump/取消/落地/Rekka/蓄力/空中出口六类） |
| `edge_built` | 正式边 `_build_edge` 调用次数（含蓄力变体；solve 默认双面向各计一遍） |
| `gap_built` | 配置缺口探针 `_build_edge(gap_mode=true)` 调用次数 |
| `delay_dfs_nodes` | `_delay_dfs` 递归节点访问总数（含内部节点） |
| `delay_dfs_leaves` | 延迟向量叶子的实际执行次数（预算耗尽而未执行的叶子不计） |
| `prefix_restores` | 叶子/捕获经前缀快照恢复执行的次数（`restore_state` 成功；票据 04 机械等价变换 + P3 checkpoint/trie 恢复的启用证据） |
| `prefix_frozen_returns` | 前缀区间已终态、整棵子树同值返回的 frozen 短路次数 |
| `session_steps` | 探针喂给 `CombatSession.step` 的物理帧总数（含起始探针序、冻结帧步进与恢复观测；在 `_pin_dummy` 单点计数——全部 step 调用都紧跟它） |
| `cycle_state_snapshots` | 循环证明模式逐圈快照的 `settlement_state` 调用次数 |
| `spatial_rechecks` | 空间复验的 (timing-valid 路线 × 48/64/80 px 站位) 重跑次数（未提供空间数据为 0） |
| `cache_hits` / `cache_misses` / `cache_bypasses` | 本请求期间完整结果缓存的增量账面（hit/miss/bypass；缓存命中请求全部计数为零且 `cache_hits=1`，如实反映未做搜索） |

增长基线（`tests/test_solver_growth.gd`，1/2/4/8 条连段边夹具）与运行方式：`godot --headless --path . -s res://tests/test_solver_growth.gd`。P1 前基线（默认双面向合计）：E=1 → 结构候选 18、session_steps 1230；E=2 → 40/2932；E=4 → 120/6510；E=8 → 472/21826（缺口枚举按 O(N²) 增长是主导项）。旧路径（前缀恢复禁用）的完整语义指纹作为 oracle 入库 `tests/oracle/solver_growth_oracle.json`，语义变更获准后以 `-- --regen-oracle` 重生成。

## 不可变招式索引（P1，perf-index）

`CompiledMoveIndex`（`scripts/combat/compiled_move_index.gd`）在每个 `ComboSolver` 实例 `_init` 时把招式表预处理成不可变索引，消除请求内重复全表扫描：

- **查找映射**：`start_keys`（`_start_key_for` O(1) 化）、`charge_bases`（`_charge_base_of` O(1) 化，表序首中规则不变）。
- **反向表**：`rev_cancel` / `rev_jump_cancel` / `rev_landing_cancel` / `rev_rekka` / `rev_air_exit` 按**表序**收录全部通过对应 `_context_via_*` 同一结构谓词的来源；`_build_contexts` 的固点传播改为待定名单轮进（尝试序列、`context_attempts` 计数与首个命中选择与旧路径逐字节一致）——消费方仍逐谓词复验，索引过度收录只损失性能。
- **候选序冻结**：`configured_edges` / `gap_candidates`（轻量 `EdgeDescriptor`）逐条复刻 `_analyze` 边循环与 `_enumerate_gaps` 的枚举序（from 表序 × kind 固定序 × 目标声明序）；搜索顺序由此由数据结构承载。
- **结构死候选索引期剔除**：LANDING_CANCEL 缺口（空→地）被 `_build_edge` 在任何 CombatSession 之前无条件拒绝、探针必然返回 null 且零报告输出——索引期剔除，不再付探针表与计数成本。这是唯一一类结构不可能候选；其余候选的成立性仍全部由真实结算裁决。
- **缺口接种**：缺口探针的候选目标注入是**显式 compiled input**（P2 定形，取代 P1 的 staged 换表）：`_probe_gap` 每候选构造 from 的注入副本（深拷贝 + 目标数组追加 + 按需窗口垫值），只在探针窗口期内经 `_edge_source_move`（求解器侧 from 配置读取）与 `_probe_table`（浅拷贝换入会话表）显式可见——`_table` 表项全程零写入（P1 时期的换组换入/换出机制已移除）。
- **计数口径微调**：`structure_candidates` / `gap_built` 自 P1 起只统计实际进入探针的候选（结构死候选不再计数）；恒等式 `structure_candidates == edge_built + gap_built` 不变，增长基线相应下移（E=8：472 → 444，减去的恰是落地死候选数）。
- **差分开关**：`ComboSolver._compiled_index_disabled = true` 退回全表扫描旧枚举路径（等价性差分 oracle；与 `_delay_prefix_restore_disabled` 同款）。开关不进语义签名/请求键，差分测试跑第二路径前必须清结果缓存。等价性门：`tests/test_solver_index_equiv.gd`（夹具级双路径全语义指纹 + 形状冻结 + 接种无残留 + analyze 顺序敏感差分）；默认表级差分证据在 `.scratch/solver-scalability/perf-index-01/`。
- 语义签名（`_solver_semantics_signature`）自 P1 起收录 `compiled_move_index.gd` 文件摘要——索引实现变更会使持久结果缓存全量失效（一次性重建成本）。

## 接续探针精确结果缓存（P2，perf-edge-cache）

`_build_edge`（配置边与缺口探针共用）与 `_source_timing`（单招命中/恢复计时）的完整结果按进程内稳定键复用，消除**跨请求/跨实例**重复的同型探针重放（同表同面向的不同 descriptor 请求——如 solve 之后 analyze——探针域全部命中）：

- **EdgeProbeKey**（canonical 文本 → SHA-256）：表语义摘要（`_canonical_variant` 全表内容，实例内一次求值）+ facing + pin_dx + 显式起始状态 + from/to/kind + 接续上下文签名（ChainLink 全字段）+ 模式（`configured` / `gap`，后者携带接种字段与窗口垫值）+ 弹地/落地/时序常量摘要（`_bounce_landing_signature`，键内显式携带）。任何一维变化都是不同键：左右面向、空间档位、不同起始状态、不同表内容互不命中。
- **缓存值是不可变完整快照**：边 = SolverEdge 全字段（含 blocked/align/wait 标注与 `align_inputs` 输入表），timing = hit_frame/recover_age/recover_truncated 三字段；命中每次解冻**新对象**，调用方改写（如缺口收尾把 valid 翻 false、改写 reason）不回写缓存。结构判定（`_edge_structure_refusal`，纯配置检查，P2 自 `_build_edge` 抽出为零语义变化）、runtime timing、gap 报告包装三层独立，缓存只包装在 `_build_edge` / `_source_timing` 两个入口。
- **失效面**：Engine meta 进程内存储；代际 env = 引擎版本 + `_solver_semantics_signature`（全源码文件摘要，含 game_params/combat_session）+ 弹地/落地常量显式值——任一漂移整代表清。与完整结果缓存互不读写：整报命中不进求解器；探针缓存命中的是探针域，报告仍由当次搜索组装（路线/循环/空间重放照常执行）。
- **分层行为**：边缓存命中时 `_fill_*` 不再执行，timing 层被完全覆盖（热请求 timing 查询数为 0 是正确行为）；timing 命名空间独立付钱的场景是局部 timing 字典为空的来源限定连接流程与跨上下文计时。
- **差分开关**：`ComboSolver._edge_probe_cache_disabled = true` 同时旁路读与写（先例 `_compiled_index_disabled`；不进语义签名/请求键）。API：`set_edge_probe_cache_enabled` / `edge_probe_cache_enabled` / `clear_edge_probe_cache` / `edge_probe_cache_stats`（edge/timing 两命名空间的 hits/misses 与条目数）。
- 等价性门：`tests/test_solver_edge_cache_equivalence.gd`（键维隔离、冷/热指纹全等、Tier A/B 四形态、facing 隔离、返回值不可变、跨入口复用、注入无残留）；默认表级差分证据在 `.scratch/solver-scalability/perf-edge-cache-01/`。确定重放测试跑同请求对照时须同时清两层缓存（`test_solver_perf_profile` 的 `_solve` 已随 P2 更新）。
- 缓存命中不改任何 v2 计数语义：`edge_built`/`gap_built` 在包装层计数（调用即计），`session_steps` 如实反映本次请求实际重放——热请求显著低于冷请求，是缓存生效的确定性证据而非漂移。

## Checkpoint 前缀转移（P3，solver-checkpoint）

延迟搜索的执行域从「每叶子从零全量重放」改为「按输入内容寻址的 checkpoint 前缀转移」。三个不可变对象（`scripts/combat/combo_solver.gd` 内部类）：

- **`CompiledSchedule`**：`_compile_chain` 输出的不可变视图（输入表/预期命中表深拷贝 + 按帧索引一次建成 + 有序帧游标）；运行结果 dict 的 `compiled` 字段仍指原始编译 dict（内容一致，消费方不变）。
- **`SessionCheckpoint`**：一次真实前缀执行的不可变快照——`clone_state` **全量执行状态**（绝不用 `settlement_state` 代替：那只覆盖影响未来结算的子集，缺 HP/位置/输入史）外加 `_run_schedule` 循环全部跨帧计数器（frame/physics/verified/ended 累积/循环快照序列/extra 命中记录/proven_period/laps_observed/boundary）。构造深冻结、无写入方法；legacy Dictionary 前缀在 `_run_schedule` 入口归一化为 checkpoint（票据 04 测试口径的 `_capture_delay_prefix` 公共契约保持返回 Dictionary 投影）。
- **`TransitionMemo`**：持久化 trie——节点 = 某编译表在某输入帧完成当帧事件处理后的 checkpoint，子边键 = (帧号, 输入内容摘要)。会话执行是输入确定性的：同 scope（表摘要 + 缺口注入副本摘要 + facing + pin_dx + 显式起始 + 选项形状）下输入前缀逐帧相同的两张表到任何帧的执行与计数器都相同，故任意运行可从最深匹配节点恢复（与显式父 checkpoint 取更深者）。trie 求解器实例内存活：同请求内路线兄弟、边/缺口探针的公共上下文重放只执行一次；每 scope 容量 8192 节点，满后确定性地停止登记（只损失共享，访问序确定可复现）。

机制要点：

- **每层 DFS 节点捕获**：`_delay_dfs` 在 d-循环前按既有边界差分（`_first_input_difference`）捕获本子树共享 checkpoint，捕获从父 checkpoint 增量执行（不再从零重放）；证明模式维持原 frozen 短路语义，**路线模式只恢复、绝不短路**——叶子数/字典序/预算/最远失败排序与旧路径逐字节一致（形状量不变）。路径赋值在 d-循环显式落链（此前 pivot 捕获依赖「上一叶子残留赋值」的侥幸不变式——可调链接自然 wait 恰为最早值时无症状，显式化后对任意表成立）。
- **捕获点围栏**：memo 恢复不越过 `capture_before_frame`（`deepest` 帧上界）；恰好恢复在捕获点时直接发出 `prefix_capture`，不步进。
- **惰性区间批量推进**：到下一围栏（计划输入/预期命中/捕获点/观测终点）之间无输入、无预期命中、无捕获点，且会话**可证明无事件**（玩家空闲、`CombatSession.has_deferred_event_sources()` 为假、无 Hitstop、连段不活跃——活跃期间取消/恢复窗与木桩计时器都能发 COMBO_ENDED，不廉价证明）时整段步过，只省逐帧事件解析，物理步进与 `_pin_dummy` 照常；证明不了的区间保持逐帧。
- **变异测试口径**：`_test_prefix_mutator` 装载时 memo 读写整体旁路（被腐蚀的 checkpoint 进 trie 会跨样本串扰）；`_delay_prefix_restore_disabled` 仍是全机制（根捕获/pivot/trie/惰性批量）的旧路径 oracle 总开关。
- 等价性门：`tests/test_solver_checkpoint_trie.gd`（从零重放 vs checkpoint 恢复三层对拍：oracle/冷恢复/热恢复，覆盖 hitstop/landing/air exit/bounce/charge/side swap/失败断点 frozen·超长·预算·观测上限/空中起始 prologue-skip，外加冻结纪律、热确定性、跨搜索不干扰、pin_dx scope 隔离与深层 pivot 变异）；票据 04 的 `tests/test_delay_prefix_restore.gd` 保持全绿（含其变异验证）。`session_steps` 随共享程度下降（增长夹具 E=8：21826 → 958），形状量与语义指纹不变。

## 循环不变量 CycleInvariant（P4，solver-delay-dp）

票据 09 起在用的「逐圈证明被单调时间修正排除」从 `_simulate_cycle` 的内联启发式升级为声明式契约（`ComboSolver.CycleInvariant` 内部类）。`_simulate_cycle` 对每个结构循环先评估不变量：APPLY 时按证明级排除上报 BROKEN（文案与票据 09 起逐字节一致，指纹不漂移），任一前置条件不满足即 FALLBACK，回退原有的精确逐圈状态复现搜索。

四项声明前置条件（`evaluate` 依次检查，首个失败者记入 `failed_precondition`）：

- **每圈有效 HIT**：每个循环成员都是表内打击招式——存活链里每次预期命中都把 time_scale 乘上 <1 因子（连段中段资源重置被 `_run_schedule` 的连段计数校验断链，不会出现在存活链里）。
- **倍率有限且严格小于 1**：starter 初始化（逐起手等级）与普通/滑行/弹地/落地连接四类每击倍率一起检查；出现 1.0（快照可原值重现）、0/负数（乘积恒 0 可重现）或非有限值时严格递减论证失效，回退。
- **time_scale 在完整循环键中**：活探针 `settlement_state()` 必须携带 float 型 `time_scale`——键丢字段的运行时契约漂移会令排除失去依据，回退（`settlement_covers_time_scale` 独立可测）。
- **无浮点下溢**：观测视野内（`MAX_CYCLE_LAPS` × 每圈判定段数）最小可达 time_scale = min(倍率)^(视野命中数−1) 必须保持 float64 正规数（≥ pow(2,−1022)）——正规数域内 t×f < t 对 f<1 严格成立（相对舍入 2⁻⁵³ ≪ 1−f），下溢/非正规域后乘法可能原地舍入。注意 GDScript 解析器会把 ≤1e-308 的字面量冲洗成 0.0，下界必须运行时 `pow(2.0, -1022.0)` 计算。

适用域沿用票据 09 口径（循环内存在**首命中资料**为 GROUND_BOUNCE / LOW_FLOAT_TO_SLIDE 的招式；普通循环保持精确逐圈模拟的诚实上报），域外回退不携带失败前置条件名。判定始终取 GameParams 实值——把任一倍率调成 1.0 自动回退完整逐圈搜索，不静默弱化求解器；`_test_cycle_factor_override` 是仅测试可见的注入缝（键为常量名），不进验收参数与语义签名。等价性门：`tests/test_solver_cycle_invariant.gd`（bounce/slide APPLY、倍率=1/0/负/inf/nan 回退、下溢边界与多 HIT 指数、键漂移、每圈 HIT 缺失、端到端回退确实产生逐圈快照而 APPLY 时为零）。

## 精确 delay state DP（P4，solver-delay-dp）

证明模式（`snapshot_every > 0`，循环证明搜索）的 `_delay_dfs` 增加子树结果备忘录：每个内部节点在 pivot 捕获后按**节点键**查表，命中即返回首访者的子树结果；正常出口登记。

- **节点键四元组**：剩余 link signature 哈希（本搜索全部链接身份字段 + 不可调链接固定等待 + 逐槽枚举上限——可调槽的当前等待是搜索过程量不入签名）｜可调槽深度（link index）｜前缀延迟赋值｜完整 `SessionCheckpoint` 内容哈希。前缀赋值必须入键：pivot 边界可能落在上一可调链接的预期命中之前（wait=0 时边界=锚点帧），此时该链接的编译预测尚未进入 checkpoint——两个 checkpoint 相同但前缀赋值不同的子树编译表不同、未来不同，禁止合并。**删减的 `settlement_state` 绝不做执行缓存键**（缺 HP/位置/输入史/求解器计数器）；命中前对 checkpoint 全量内容做深比较（哈希前缀冲突续查探针键，绝不误合并）。
- **报告语义保持**：字典序首访 + 失败并列保先使最终上报与旧 DFS 全等；证明成立在首访即向上早停，缓存条目不会被读到；frozen 短路仍在 DP 之前。路线模式（延迟预算按叶子执行扣减、与「哪些向量被验证过」耦合）**不启用 DP**——合并会移动 64 向量观测上限的截断点与最远失败归属。
- **计账与开关**：`delay_dp_stats()`/`reset_delay_dp_stats()` 实例级计账（searches/nodes/stores/hits），不进验收参数；`_delay_dp_disabled = true` 强制旧 DFS（Tier A oracle，先例 `_delay_prefix_restore_disabled`），叶子日志/变异钩子装载时 DP 自动旁路。
- **合并域的实测口径**：当前编译/复验契约下合并域为空——存活的延迟前缀把绝对帧钉进完整 checkpoint（预期帧=实际帧的逐帧复验），不同赋值必不同态；会收敛的赋值（越窗缓冲后被清、滞空耗尽作废）恰是会断链/截断的赋值，先被 frozen 短路。默认表全部差分样本（hitstop/landing/air exit/bounce/charge/side swap/多段/空中起始/失败域）stores>0 而 hits=0。DP 在此语义下的价值是**精确性保险**：输入缓冲窗口、尾部发现等使不同延迟前缀收敛到同一完整状态的语义一旦出现，合并自动生效且由 Tier A 门保证语义不变。
- 等价性门：`tests/test_solver_delay_dp.gd`（旧 DFS vs DP 最终投影对拍 + DP 确定性 + 搜索形状不增 + 路线模式结果与逐叶日志不受开关影响 + 预算截断点不移动 + 计账非空洞）。

## 路线/循环/空间验证层重构（P5，solver-routes-cycles）

三个机械等价变换 + 一个报告完整性机制；同树差分（开关两跑）输出逐字节一致（P7 全栈终差分复证，见「P7 终差分与默认切换」节）：

- **环枚举 = SCC 预处理 + Johnson 风格去重**（`_elementary_cycles`）：顶点序取 adj 插入序——每个环在其「序最小成员」处生根、恰好枚举一次。三面剪枝：根迭代按序移除顶点（更小序成员的环归更小序根，纯重复遍历）；DFS 限制在根的强连通分量内（到不了根的顶点不可能闭合成当前根的环）；blocked 集 + B 表（Johnson 教科书形态）剪掉当前栈前缀下到不了根的分支。被剪分支都不含任何被上报的环（旧 seen 去重本就丢弃它们），DFS 前缀序不变——输出与旧全起点 DFS + canonical 去重**同序同集**（差分 oracle：`ComboSolver._cycle_enum_legacy = true` 退回旧实现；`_canonical_cycle` 字典序旋转归一保持不变）。默认表的非平凡 SCC 外起点（纯 DAG 区域）不再整棵遍历。
- **路线叶 trie 登记（prefix/suffix memo）**：`_route_run`（路线枚举与空间复验共用）的叶子执行也在每个输入帧向 P3 scope trie 登记 checkpoint——同 scope（编译调度语义一致）的后续搜索从最深节点恢复，只重放输入分歧之后的 suffix。登记⇔恢复与 P3 同一输入内容寻址语义，不改任何搜索行为（字典序/预算/最远失败归属不变）；差分开关 `ComboSolver._route_leaf_memo_disabled`。**compiled-scope 契约（2026-10-04 恢复等价票据）**：memo scope 并入 `_compiled_semantics_key`（预期命中帧×招式 + jump/land + unpredicted_tail）——兄弟路线若编译调度不同则不共享（跨调度复用 checkpoint 的 `verified` 计数不安全）；`tests/test_solver_restore_schedule_scope.gd` 锁死该键维度。
- **空间复验分层缓存**：scope 键含 facing 与 pin_dx，即 (路线输入前缀 × 面向 × 48/64/80 钉位档) 分层——同档兄弟路线的公共前缀执行（含已结算的几何判定）只跑一次，新增 suffix 的碰撞判定仍全部走真实 CombatSession（不做纯几何近似）。`_verify_route_spatial`（P5 抽出）单条复验，`_verify_routes_spatial` 保持全量入口。
- **报告完整性 + 资源看门狗**（ADR 0007）：`SolverOptions.complete = true` 时 `MAX_ROUTE_REPORTS` 不作语义剪枝（全部 ≤8 招简单路径照常枚举模拟，进请求键）；`SolverOptions.watchdog_ms` 到点只在安全点（一个路线源/结构循环/空间复验之后）暂停并持久化 incomplete 状态（`resume_path`，回退 `FTG_SOLVER_RESUME`），`ComboSolver.resume_analysis` 续算（快照自包含 canonical 表文本 + 冻结报告 + 进度游标；恢复腿不重跑边/缺口阶段；solve 级暂停以面向为包裹粒度，续算收尾与 solve 同一镜像对拍/合并路径）。暂停报告 `paused_incomplete` 如实标记且不进结果缓存；暂停注记在续算完成的报告中被剥离，最终与不中断路径指纹全等。
- 等价性门：`tests/test_solver_routes_cycles_refactor.gd`（46 断言）——合成图（K4/桥接双 SCC/自环/DAG/插入序≠字典序）+ 120 张确定性随机图 + 夹具表真实邻接图的 Johnson vs 旧路径**顺序敏感**逐字节对拍 + canonical 旋转/无重复；叶登记开关两跑全语义指纹全等 + `session_steps` 不增 + 空间失败逐条相等；complete 模式路线数 == 邻接图暴力叶计数（94 == 94）+ 默认截断集合为子集；分析级/solve 级中断恢复最终指纹全等；坏/缺失快照拒绝。分支夹具上 `prefix_restores == 0`（全跨调度共享被阻断）是钉死保守口径的回归方向——重新打开跨调度共享须先附 restore on/off 逐字节等价证明并更新断言。

## P7 终差分与默认切换（solver-finalize）

P0-P6 全部优化路径自交付起即为默认；P7 的职责是把「默认正确」证成**同树全栈 Tier A**并交接长期回归门。证据 `.scratch/solver-p7-01/`。

- **全栈差分（默认表 `solve()`）**：新路径（六开关全默认）vs 旧路径 oracle（六开关全 legacy：`_compiled_index_disabled`/`_edge_probe_cache_disabled`/`_delay_prefix_restore_disabled`/`_delay_dp_disabled`/`_route_leaf_memo_disabled`/`_cycle_enum_legacy` 全 true）全语义指纹逐字节相等（105c43c7…）。冷 89.7s / 探针缓存热 70.9s（session_steps 657,434→435,304）/ 旧路径 1031.8s——默认表单请求 11.5×，较 P2 时代（376.8s，HEAD 工作树复测）4.2×。探针 `fullstack_diff_probe.gd`，报告落盘 `report-*.json`。
- **跨期指纹漂移的裁决（ADR 0006 修订七）**：HEAD（票据09+P0-P2 树）锚点 e071fdc6 复现后，证明票据 04 恢复别名污染在 79 边表上早已使 HEAD 的 restore-on（e071fd）≠ restore-off（abfcfcce）；字段级 diff 把差异隔离到 6 条空中链结构性循环注记（污染侧早断，干净侧晚断）。P7 树两侧全等且与 HEAD-restore-off 内容全等（仅注记措辞与 `paused_incomplete` schema 差异）——旧归档默认表 solve/analyze 指纹 e071fd/85ec8b → 105c43c7/bb638738 的旋转是已裁决的 bugfix，不是回归。
- **重建门补漏**：`_sweep_replay` 漏重建 `SolverOptions.complete`（语义维度进请求键），complete 模式请求在清扫重放时必被「重建请求不相等」拒绝——P7 补齐（重建分支显式 `opts.complete = descriptor.complete.value`），定向 sweep 复证 4/4 complete 零缺口。test_move_table 的 2 条 analyze_manifest 请求按设计记 failed/gap（枚举捕捉的 manifest 盘中态在带外重放时已被测试改为终态；热跑就地现算兜底，ADR 0006 修订四口径）。
- **worker-restart 实机复验（P6 机制的 P7 再证）**：外部 taskkill 击杀在途重请求（watchdog 2000ms）→ runner `exit-handled`（worker-exit-code-1）→ gen1 重生从 checkpoint 续算（`resumed: true`，22.3s 完成）→ 仍入缓存；spawn 对 pool（含两次击杀场景）canonical 缓存 30/30 digest 全等且逐条 entry 字节相等。
- **全量验收（79 边表首个完整跑，pool 默认参数）**：74 唯一请求，complete 71 / failed 3（上述 move_table 2 + complete 重建 1，后者修复后不复现），gaps/quarantine/kill 全量入流水；总墙 483.6s（import 7.4 + 枚举 51.0 + 清扫 370.9 + 热跑 140.7，8 车道 busy 2249.6s / 饱和 0.758）；最长单请求 229.6s（心跳/暂停点全期可见）。票据 09 在途 FAIL 族与 P0 时代逐字一致（test_combo_solver 11 条 FAIL 行 diff 为空；route 1 / entry 4 / hit_profiles 1+尾行；move_table 3 / replay 13 / spatial 1 / charge 1 / diagnose S6 均为 08-09 扩表测试重写在途，票据 07 末全绿归档可查），3745 断言全过，无新增失败。
- **增长曲线（`tests/test_solver_growth` 六门全绿，oracle 未再生成）**：E=1→2→4→8 结构候选 16→36→108→324、缺口探针 14→32→100→428、逐帧 session_steps 52→76→306→958（P0 基线 E=8 为 21,826 步级）、叶子 2→2→6→220——枚举域 O(N²) 增长保持语义事实，重放域被 P3/P5 压平。
- **回滚入口（旧路径全部保留为 oracle）**：任一层回退＝置对应开关 true（P1 索引 / P2 探针缓存 / P3 前缀恢复 / P4 DP / P5 叶登记 / P5 旧环枚举）+ **差分第二路径前清两层缓存**（`clear_result_cache()` + `clear_edge_probe_cache()`，先例 test_solver_perf_profile `_solve`）；清扫层回退＝`--sweep-mode spawn`。任何 combo_solver.gd 文本改动轮换全部持久缓存 digest（semantics 签名），回滚后首次冷跑自愈。恢复别名修复与 compiled-scope 是**正确性修复**，不提供行为回退开关（回退它们＝回到已知 bug）。
