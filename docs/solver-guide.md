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
| `prefix_restores` | 叶子经前缀快照恢复执行的次数（`restore_state` 成功；票据 04 机械等价变换的启用证据） |
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
