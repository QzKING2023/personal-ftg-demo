# Combo Solver 性能改造执行文档

本文把 combo solver 的性能方案拆成可连续执行的阶段。每个阶段都包含目标、边界、交付物、验收条件和可直接复制的启动提示词。阶段必须按依赖顺序推进；后续阶段不能用新的缓存或剪枝掩盖前一阶段未测量的重复工作。

## 固定背景和约束

当前成本来自多层乘法：

```
solve ≈ facing × (edge probes + gap probes
                  + route leaves × delay vectors × replay frames
                  + spatial distances × route replays
                  + cycle candidates × delay vectors × laps × replay frames)
```

已测量的一次 10-solve 控制运行：`delay_leaf` 26,141 ms/40,082 次，`edge_probe` 21,014 ms/7,794 次，`gap_enum` 29,586 ms/12,364 次，`route_walk` 1,075 ms，总计约 78.4 s。另一次 cold acceptance 中，单个 descriptor 的 `delay_leaf_ms` 达到 13,649,678 ms；票据 09 的单个 worker 累计 CPU 约 18,469 s。

必须遵守以下约束：

- solver 的报告语义、失败分类、命中帧、输入顺序和循环结论保持等价；
- `CombatSession.clone_state()` 才是执行恢复的完整状态，`settlement_state()` 只能用于已证明完备的循环键；
- cache key 必须包含表语义摘要、facing、pin position、solver mode 和所有影响未来结算的配置；
- `MAX_ROUTE_REPORTS = 16` 只能作为交互式防失控保险，不能作为 complete acceptance 的正确性剪枝；
- 任何观察上限都必须显式报告 `incomplete`，不能把截断当成“没有找到”；
- 每个阶段都要保留旧路径作为差分 oracle，Tier A/B 等价性通过后才可删除旧路径；
- 不修改与本阶段无关的 move data、战斗规则和 acceptance ticket。

## 阶段总览

| 阶段 | 名称 | 依赖 | 主要结果 |
|---|---|---|---|
| P0 | 基线冻结与性能观测 | 无 | 可重复 profile、增长夹具、旧路径 oracle |
| P1 | Move/Edge 预编译索引 | P0 | 建图从全表扫描变为索引遍历 |
| P2 | Edge/Gap/Timing 缓存 | P1 | 相同探针只执行一次 |
| P3 | Checkpoint 与前缀转移 | P2 | 延迟叶子复用真实会话前缀 |
| P4 | 精确延迟 DP 与循环证书 | P3 | 消除延迟笛卡尔积的重复状态 |
| P5 | SCC、路线和空间层 | P2、P4 | 消除重复路径/环遍历与空间重放 |
| P6 | Acceptance runner 隔离 | P0、P2 | worker 可恢复、可观测、不会拖死 sweep |
| P7 | 最终切换与回归门 | P1-P6 | 关闭旧路径，建立长期性能门槛 |

---

## P0：基线冻结与性能观测

### 目标

先让搜索形状可量化，避免后续优化只比较一次偶然的墙钟时间。建立旧 solver 的确定性报告 fingerprint 和完整 profile。

### 读取范围

- `scripts/combat/combo_solver.gd`
- `scripts/combat/combat_session.gd`
- `tools/run_acceptance.py`
- `docs/adr/0006-acceptance-speedup-equivalence-discipline.md`
- 现有 `.scratch/acceptance-speedup/` 与 `.scratch/solver-scalability/` 记录

### 实施任务

1. 扩展 `solver_profile_v2`，增加结构候选、上下文尝试、实际 edge/gap 构造、delay DFS 节点/叶子、前缀恢复、逐帧 `step`、循环状态转移、空间复验和 cache hit/miss 计数。
2. 保证计数器只读观测，不改变搜索顺序或报告字段。
3. 新增固定小表和扩展边夹具，按 1、2、4、8 条同类型边运行。
4. 保存旧路径的完整报告 fingerprint、`*_runs`、失败原因和耗时摘要。
5. 给 acceptance runner 增加阶段心跳，但暂不改变 worker 调度策略。

### 交付物

- `tests/test_solver_perf_profile.gd`
- `tests/test_solver_growth.gd`
- profile JSON schema 或稳定字段说明
- 一份 baseline 输出，记录 cold、warm、单请求和完整 sweep

### 验收条件

- 同一输入重复运行，语义 fingerprint 和所有确定性计数一致；
- profile 能明确区分结构工作、runtime replay 和 cache 命中；
- 增加边后能看到候选数、delay 叶数、逐帧步数的增长；
- 旧测试全部保持通过，未出现脚本解析错误。

### 启动提示词

```text
你负责 P0：为 combo solver 建立可重复的性能基线和增长回归门。

请先阅读 scripts/combat/combo_solver.gd、scripts/combat/combat_session.gd、tools/run_acceptance.py、docs/adr/0006-acceptance-speedup-equivalence-discipline.md，以及现有 .scratch/acceptance-speedup/ 和 .scratch/solver-scalability/ 记录。

只做观测和测试，不改变 solver 的搜索语义、搜索顺序、报告字段或 move data。为 solver_profile_v2 增加确定性计数：结构候选、上下文尝试、edge/gap 构造、delay DFS 节点/叶子、前缀恢复、CombatSession.step 次数、循环状态转移、空间复验和 cache hit/miss。新增可控的 1/2/4/8 条连段边增长夹具，并保存旧路径的完整语义 fingerprint 作为 oracle。

交付 tests/test_solver_perf_profile.gd、tests/test_solver_growth.gd、profile 字段说明和一组 baseline 输出。运行相关 Godot 测试和语法检查。最终报告必须包含：修改文件、profile 样例、增长结果、测试命令和任何未解决问题。不要修改无关文件，不要用超时或截断伪造通过。
```

---

## P1：Move/Edge 预编译索引

### 目标

消除 `_build_contexts` 的多轮全表扫描和 `_enumerate_gaps` 的 `V²` 全组合。新增一条边只应增加有限的索引项和真实候选。

### 实施任务

1. 在 `ComboSolver.solve()` 开始构造不可变 `CompiledMoveIndex`。
2. 建立 stance、起手键、取消窗口、jump cancel、landing、rekka、charge、air-exit target 的正向和反向索引。
3. 为每个 move 生成轻量 `EdgeDescriptor`，提前包含 posture、reaction、hit profile、方向和目标状态要求。
4. 用索引上的 BFS/拓扑传播替代 `_build_contexts` 的 `grew` 全表扫描。
5. 用候选邻接替代 `_enumerate_gaps` 的全组合；结构上不可能的候选不能进入 `CombatSession`。
6. 禁止每个 gap deep-copy `MoveData` resource；临时差异放入轻量 descriptor。

### 交付物

- `CompiledMoveIndex`、`EdgeDescriptor` 及其构造函数
- context/gap 建图的索引路径
- 结构候选统计和 P0 增长夹具的对比结果

### 验收条件

- 新旧路径报告 Tier A 逐字段一致；
- 结构不可能候选不会调用 `_run_schedule`；
- 上下文结果、边种类和确定性顺序不变；
- 结构探针数量随真实候选增长，不随全表平方增长；
- 所有现有 combo solver、move table、acceptance 测试通过。

### 启动提示词

```text
你负责 P1：把 combo solver 的招式表预处理成不可变索引，消除重复全表扫描。

先阅读 P0 的 profile 和 growth 输出，再阅读 ComboSolver 的 _build_contexts、_context_via_*、_enumerate_gaps、_build_edge 及相关 MoveData/HitProfile 结构。

新增 CompiledMoveIndex 和轻量 EdgeDescriptor。为 stance、起手键、cancel/jump/landing/rekka/charge/air-exit 建立正反向索引；用索引 BFS/拓扑传播生成 context；用真实候选邻接替代 gap 的 V² 全组合。结构上不可能的候选必须在创建 CombatSession 前拒绝，不能为每个 gap deep-copy MoveData resource。保持旧路径作为差分 oracle，严格保留报告字段、失败分类和搜索顺序。

先实现索引路径，再写等价性测试和增长 profile。运行现有 solver 测试、P0 测试和语法检查。若发现旧路径本身的语义歧义，记录并停止在该点，不要用新规则偷偷修复。最终报告列出缓存/索引结构、复杂度变化、差分结果和未完成事项。
```

---

## P2：Edge、Gap、Source Timing 精确缓存

### 目标

让相同的 edge/gap/source timing 探针只执行一次，同时避免通过修改 solver 全局 `_table` 造成缓存污染。

### 实施任务

1. 定义稳定的 `EdgeProbeKey`：表语义摘要、facing、pin_dx、from/to、edge kind、context signature、solver mode、bounce/landing 配置。
2. 缓存完整不可变结果：通过/失败、断点类别、命中帧、输入、报告原因和必要的中间 timing 数据。
3. 将结构判定、source timing 和 gap report 包装拆开；gap 复用同一 descriptor 和 timing 结果。
4. 将临时 table/config 从全局变量改为显式传参或 compiled variant。
5. 为 cold cache、warm cache、不同 facing、pin、mode 增加差分测试。

### 交付物

- `EdgeProbeCache`、`SourceTimingCache` 和稳定 key 序列化
- cache hit/miss profile
- `tests/test_solver_edge_cache_equivalence.gd`

### 验收条件

- 冷缓存与热缓存最终报告逐字段一致；
- cache 命中不改变报告顺序、失败原因和语义计数；
- 不同 facing/pin/mode 之间没有错误复用；
- P0 growth 中实际 `_run_schedule` 数量显著下降；
- 缓存值不可变，测试中修改一次返回值不会污染下一次 solve。

### 启动提示词

```text
你负责 P2：给 combo solver 增加 edge、gap 和 source timing 的精确结果缓存。

先阅读 P1 的 CompiledMoveIndex/EdgeDescriptor 和 P0 的差分 profile。重点检查 _build_edge、_probe_gap、_source_timing、_run_schedule，以及所有会读写 _table、_pin_dx、facing、solver mode 的路径。

实现稳定完整的 EdgeProbeKey，至少包含 table semantic digest、facing、pin_dx、from_id、to_id、edge_kind、context signature、solver mode 和 bounce/landing 配置。缓存不可变的完整结果，不要只缓存 bool。把结构判定、runtime timing 和 gap 报告包装分层；禁止通过修改全局 _table 做临时探针，改为显式 compiled input。

新增 tests/test_solver_edge_cache_equivalence.gd，验证冷/热缓存、facing、pin、mode 和返回值不可变性。保留旧路径做 Tier A/B 差分。运行 P0、P1、现有 solver 测试和语法检查。最终报告给出 cache 命中率、实际 replay 降幅和所有失败样例。
```

---

## P3：Checkpoint、Compiled Schedule 与前缀转移

### 目标

消除延迟向量之间重复执行的公共前缀，让每个分支从真实会话 checkpoint 恢复，而不是从帧 0 重放。

### 实施任务

1. 新增不可变 `CompiledSchedule`，把帧输入、预期命中和 link 边界分离。
2. 新增 `SessionCheckpoint`，保存完整 `CombatSession.clone_state()` 以及 solver 的 frame、physics、verified、失败和循环计数器。
3. 新增 `TransitionMemo`，key 为 checkpoint、link、delay、pin_dx、facing，value 为下一个 checkpoint 或完整失败结果。
4. 用持久化 prefix trie 复用 route prefix + delay prefix；禁止共享可变 Dictionary。
5. 只有能证明没有输入、命中和边界事件的连续区间才可批量推进；其他区间继续逐帧 `step`。

### 交付物

- `CompiledSchedule`、`SessionCheckpoint`、`TransitionMemo`
- 前缀恢复路径和恢复失败诊断
- checkpoint 与从零重放的差分 harness

### 验收条件

- 从 checkpoint 恢复和从帧 0 重放产生完全相同的状态、事件和报告；
- `CombatSession.clone_state()` 缺失字段时测试能失败；
- 不同分支之间不存在状态污染；
- 逐帧 `step` 次数和 `delay_leaf_ms` 明显下降；
- 现有 hitstop、landing、air exit、bounce、charge、side swap 测试通过。

### 启动提示词

```text
你负责 P3：把 ComboSolver 的逐叶完整重放改成基于真实 CombatSession checkpoint 的前缀转移。

先阅读 P2 的缓存键和 _run_schedule/_delay_dfs/_compile_chain，以及 CombatSession.clone_state/restore_state 的完整性测试。新增不可变 CompiledSchedule、SessionCheckpoint、TransitionMemo。checkpoint 必须包含 clone_state 和 solver 的全部跨帧计数器；不要用 settlement_state 代替完整执行状态。

让 delay 分支从最近的真实 checkpoint 恢复，公共 route/delay prefix 使用持久化 trie。仅在可证明无输入、无命中、无边界事件的区间批量推进，否则继续逐帧 step。缓存对象必须不可变，恢复后不能被下一分支改写。

新增从零重放 vs checkpoint 恢复的差分 harness，覆盖 hitstop、landing、air exit、bounce、charge、side swap 和失败断点。保留旧路径 oracle，运行完整相关测试和语法检查。若状态字段不完整，先修复状态契约再继续，不要用较小键规避问题。
```

---

## P4：精确延迟 DP 与循环证书

### 目标

把 `_delay_dfs` 的重复笛卡尔积改成在完整状态上的精确转移去重，同时把当前弹地单调性判断变成有前置条件、有回退路径的正式证书。

### 实施任务

1. 将搜索节点定义为 `(link_index, checkpoint_state_key, remaining_link_signature)`。
2. 只有完整可变状态相同才合并执行节点；`settlement_state` 只用于已证明完备的循环复现。
3. 相同 checkpoint 的不同 delay 只展开一次，并保留原字典序和报告贡献。
4. 循环使用 P3 的 transition memo；对无回边或已知不可回归的分量提前结束。
5. 将 `time_scale` 优化实现为 `CycleInvariant` 插件，前置条件至少包括：每圈有有效 HIT、所有倍率有限且 `0 < factor < 1`、time_scale 在完整循环键中、未发生浮点下溢。
6. 任一前置条件不满足时回退到精确 DP/状态复现，不得直接判定。

### 交付物

- 精确 delay state DP
- `CycleInvariant` 接口及 bounce/slide 实现
- `tests/test_solver_state_dp_equivalence.gd`
- 不变量正例、倍率为 1、非法倍率、浮点边界、多 HIT 测试

### 验收条件

- DP 与旧 DFS 的报告、失败分类、命中帧和输入逐字段一致；
- 不存在无界的 `product(delay_caps)` 重复重放；
- 状态合并只减少执行，不改变可观察结果；
- 单调证书失败时能明确回退并通过 oracle；
- P0 growth 中 delay 叶数不随可调槽数按 41 的幂增长。

### 启动提示词

```text
你负责 P4：在 P3 checkpoint/transition memo 之上实现精确 delay state DP，并正式化循环不变量。

先阅读 P3 的状态恢复契约、_delay_dfs、_simulate_cycle、settlement_state，以及现有票据 09 的弹地/滑行实现。搜索节点必须包含 link index、完整 checkpoint state key 和剩余 link signature；只有完整未来行为相同的状态才能合并，不能拿删减的 settlement_state 做执行缓存键。

保持旧 DFS 的确定性顺序和报告语义，新增旧 DFS vs DP 的 Tier A 差分 harness。把 time_scale 单调判断抽成 CycleInvariant，声明并检查所有前置条件：每圈有效 HIT、倍率有限且严格小于 1、time_scale 在完整循环键中、无浮点下溢。条件不满足必须回退到精确状态复现。

覆盖 bounce、slide、倍率等于 1、非法倍率、浮点边界、多 HIT 和失败延迟向量。运行全部 solver 测试、P0-P3 测试、增长夹具和语法检查。不得通过增大/减小观察常量或 route report cap 来掩盖 DP 错误。
```

---

## P5：SCC、路线枚举和空间层复用

### 目标

消除从每个起点重复 DFS 的路径/环开销，并让空间复验复用 timing 结果和已验证前缀。

### 实施任务

1. 用 Tarjan/Kosaraju 求 SCC；无回边分量不进入 cycle solver。
2. 需要完整简单环时，在 SCC 内使用 Johnson 风格枚举并 canonicalize 去重。
3. 用 prefix trie 保存已验证路线前缀和失败 suffix；相同 prefix 的后缀只求一次。
4. complete mode 不以 `MAX_ROUTE_REPORTS` 截断语义；路线采用流式结果，资源 watchdog 只产生 checkpoint/incomplete。
5. 空间结果按 `(route_id, pin_dx, facing)` 缓存；只重放受几何影响的 suffix。

### 交付物

- SCC/cycle enumerator
- route prefix/suffix memo
- timing/spatial 分层缓存
- 路线完整性和中断恢复测试

### 验收条件

- 新旧路线、循环集合和 canonical order 一致；
- complete mode 不因固定报告上限丢失路线；
- 多钉位空间结果和旧路径一致；
- 相同 timing route 不重复做完整 delay search；
- 高密度合成图的路径/环搜索不会重复遍历相同前缀。

### 启动提示词

```text
你负责 P5：重构 combo solver 的路线、循环和空间验证层。

先阅读 P4 的 transition DP 和现有 _walk_routes、_elementary_cycles、_walk_cycles、_verify_routes_spatial、_route_run。使用 SCC 预处理；在需要完整简单环时使用 Johnson 风格的去重枚举；路线使用 prefix/suffix memo。complete mode 不得把 MAX_ROUTE_REPORTS 当语义剪枝，资源 watchdog 只能暂停并持久化 incomplete 状态。

空间复验按 route_id、pin_dx、facing 分层缓存 timing 结果，只重放几何确实可能受影响的 suffix；仍然使用真实 CombatSession，不用纯几何近似替代碰撞结算。

新增路线集合、canonical order、空间多钉位和中断恢复的差分测试。运行 P0-P4 测试、所有现有 route/cycle/spatial 测试和语法检查。最终报告说明报告完整性、重复遍历减少量和任何需要更新的 ADR。
```

---

## P6：Acceptance runner 失控隔离

### 目标

让单个慢 request 可观测、可恢复、可隔离；runner 只负责 liveness，不用超时或杀进程改变 solver 语义。

### 实施任务

1. 使用可复用 worker pool，减少每个 descriptor 的 Godot 启动和导入成本。
2. 每个 request 写 heartbeat、阶段计数、profile 增量和 checkpoint。
3. 支持无进展超时后只重启当前 request，并从 checkpoint 继续。
4. 按历史 profile 做 longest-job-first，慢 request 进入 quarantine lane。
5. 分层持久化子问题缓存和完整 descriptor 缓存。
6. 输出 `complete`、`incomplete`、`failed` 三态；被杀进程不得静默成为通过。

### 交付物

- worker pool 和 request lifecycle
- heartbeat/checkpoint schema
- runner 重启/恢复测试
- slow request quarantine 报告

### 验收条件

- worker 被杀或重启后可以恢复，不重复已完成子问题；
- 一个慢 request 不会阻塞其他 request 的进度和结果回收；
- incomplete/failed 状态不会被 acceptance 汇总为通过；
- runner 不改变 solver 的 semantic fingerprint；
- 冷启动和热缓存的进程开销可在 profile 中区分。

### 启动提示词

```text
你负责 P6：改造 tools/run_acceptance.py 及其 worker 生命周期，解决单个慢 solver 拖死 sweep 的问题。

先阅读 P0 的 heartbeat/profile 结构、P2 的缓存持久化边界和仓库 ADR。实现可复用 worker pool、每 request 的 heartbeat/阶段计数/checkpoint、单 request 重启恢复、longest-job-first 和 slow quarantine。输出 complete/incomplete/failed 三态，禁止被杀进程静默计为通过。

runner 层不得通过减少 solver 搜索、改变报告上限或隐藏超时来制造速度。模拟 worker 被杀、缓存命中、缓存损坏、无进展和恢复中断，验证 semantic fingerprint 不变。运行 Python runner 测试、现有 acceptance 小集和语法检查。最终报告包含恢复证据和失败状态样例。
```

---

## P7：最终切换与回归门

### 目标

在所有优化通过差分后切换为新路径，保留可回滚 oracle，并把“连段边扩展不产生指数爆炸”固定成长期验收规则。

### 实施任务

1. 运行 Tier A：同 mode、同表、同 facing/pin，旧新报告逐字段相等。
2. 运行 Tier B：跨 mode 只排除明确的 cache/profile/runtime 字段，其余语义 fingerprint 相等。
3. 运行 cold/warm cache、worker restart、facing mirror、3 个空间钉位和高密度增长夹具。
4. 确认 complete acceptance 总时长不超过 ADR 目标 1 小时，最长任务始终有 heartbeat 和阶段进展。
5. 将 profile 阈值、增长曲线和失败样例写入 acceptance；旧路径降为仅差分/回滚用途。
6. 更新 ADR、票据 09 和 solver 性能记录，明确所有观察上限和 incomplete 语义。

### 交付物

- 最终差分报告
- 性能增长报告
- 更新后的 ADR/票据记录
- 新旧路径开关及回滚说明

### 验收条件

- 所有 Tier A/B、现有测试和增长夹具通过；
- 新增连段边主要增加结构 descriptor 和唯一状态转移，不再乘上所有旧延迟槽；
- 无未说明的 route cap、delay cap 或隐藏超时；
- 完整 acceptance 能在中断后恢复，并明确报告 complete/incomplete/failed；
- 旧 oracle 可在发现回归时重放同一 request。

### 启动提示词

```text
你负责 P7：完成 combo solver 性能改造的最终差分、切换和长期回归门。

先收集 P0-P6 的交付物和未解决项。运行 Tier A/B 全量差分、cold/warm cache、worker restart、facing mirror、空间多钉位、高密度连段边增长夹具和完整 acceptance。检查报告字段、失败分类、命中帧、输入顺序、循环集合、semantic fingerprint、complete/incomplete/failed 状态。

只有所有差分和增长门通过后，才把新路径设为默认；旧路径保留为 oracle/回滚。确认 complete mode 不依赖 MAX_ROUTE_REPORTS 语义截断，所有观察上限都显式产生 incomplete。更新 ADR、票据 09、性能记录和回滚说明。

最终报告必须给出：各阶段测试结果、冷/热耗时、结构候选/唯一转移/逐帧 step 的增长曲线、最长 request heartbeat、剩余风险和回滚入口。任何失败都要保留复现命令和完整产物。
```

## 阶段完成后的长期规则

以后新增 combo edge 时，提交必须同时附带：结构候选增量、唯一状态转移增量、逐帧 `step` 增量、cold/warm profile 和增长夹具结果。若某项按 delay 槽数呈指数增长，先停止功能扩展，修复状态图或缓存边界后再继续。

性能优化的完成标准是搜索形状受唯一结构/状态转移控制，而不是某次运行刚好更快；并行、缓存命中和 runner 超时只能改善资源利用，不能替代 solver 的精确状态复用。

