# 03: Solver 耗时 profile 插桩

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 无,可与 01/02 并行(不同文件)

## What to build

给 ComboSolver 的 metrics 输出加耗时分解插桩:每个唯一请求的耗时按调用点分类——延迟叶子回放(`_delay_search` 的每次 `_run_schedule`)、边探测(`_build_edge` 路径)、缺口枚举、路线行进(`_walk_routes` 路径)与其他。产出默认表 solve/analyze 的 profile 报告,作为 04/05 的投资决策数据。插桩本身零语义影响。

背景量级:全量 ≈ 30 个唯一重请求 × 每个 ~1000s(票据 07 实测 solve() 双面向 1109s);我们目前**不知道**这 1000s 花在哪一类。

## User stories covered

8。

## Acceptance criteria

- [ ] metrics 输出扩展:至少四类耗时 + 总计,随现有 solver metrics 口径输出(或并行的独立 metrics 行),编排器可透传进 summary。
- [ ] 分类口径明确:哪些调用点计入哪类,写进本票 Comments(例如尾部发现/空间复验/镜像对拍归"其他"还是单列,以实际代码结构定,但必须无遗漏、不重复计)。
- [ ] 零语义影响:定向 test job(test_combo_solver、test_solver_route)插桩前后 fingerprint 与断言计数相等。
- [ ] 默认表的 profile 报告归档(重请求逐个列出分类耗时与占比),供 04 验收引用、05 触发判定引用。
- [ ] 插桩常开(不是调试开关):验收常规输出就带分类耗时,后续票据的前后对比才有统一口径。

## Blocked by

- 无,可与 01/02 并行(不同文件)

## Comments

### 分类口径(先于实现定案,2026-09-30)

**机制**:Solver 内加常开耗时分解插桩——分类作用域栈 + 最内层优先归属。作用域内的时间归最内层作用域;四个分类作用域之外的一切时间归「其他」。每微秒恰好归入一类:无遗漏、不重复计。请求数值在 `solve()`/`analyze()`/`analyze_manifest()` 入口清零,报告经 `ComboSolver.last_request_profile()` 读取;缓存命中请求四类为零(没有求解器工作发生,总耗时≈0,与 metrics 层零缓存观察互证)。profile 按请求聚合全部面向(镜像对拍的第二面向不单列——与 metrics 层 elapsed_ms 同口径)。

**五类与覆盖的调用点**(以当前工作树 combo_solver.gd 为准,行号为插桩前):

1. **delay_leaf 延迟叶子回放**:`_delay_search` 无可调槽基线回放(combo_solver.gd:3472)与 `_delay_dfs` 叶子回放(:3513)的每次 `_run_schedule`,路线模式与 proof_mode(逐圈快照)两种 opts 都算。`_delay_search` 只被 `_route_run`(:3573)与 `_simulate_cycle`(:3703)调用——边/缺口路径不做延迟向量搜索,全部延迟叶子都在路线/循环行进内发生;按最内层优先归 delay_leaf 而非 route_walk,理由:票据 04 的前缀恢复作用点就是这两个调用点本身。
2. **edge_probe 边探测**:`_analyze` 接续边双循环(:1252-1302,含 `_build_edge` :1273 与蓄力变体 :1292)整个子树——含 `_fill_cancel_edge`(:2177)、`_fill_special_entry_edge`(:2272)、`_fill_link_edge`(:2611)、`_run_tail_discovery` 尾部发现(:2691,**单列于边探测,不归「其他」**)、`_fill_jump_edge`(:2836/:2851)、`_fill_landing_edge`(:2915)、`_source_timing`(:3054,全部调用方都是边填充)、`_run_blocked_probe`(:2468,自跑会话循环不经 `_run_schedule`,耗时经作用域计入,runs 计数不自增)。缺口枚举复用 `_build_edge`(`_probe_gap` :1489),那部分在最内层 gap_enum 作用域内,归缺口枚举不归边探测。
3. **gap_enum 缺口枚举**:`_enumerate_gaps`(:1303)整个子树,含 `_probe_gap` 探针表构造与 `_fill_landing_gap` 落地试验回放(:3021)。
4. **route_walk 路线行进**:`_walk_routes` 起点循环(:1311)、循环模拟循环(:1313-1324,含 `_elementary_cycles` 图枚举)与 `_verify_routes_spatial`(:1326;**空间复验单列于路线行进**——它逐路线重放,是票据 05 前缀共享的候选作用点)三个作用域内、扣除 delay_leaf 后的剩余时间(入口链构造、图行走、`_route_run`/`_simulate_route` 外壳)。
5. **other 其他**:请求总耗时 − 四类 = `_build_contexts` 入口上下文构建、`_binding_variant_lines` 变体行回放(:1623,唯一不在四类作用域内的 `_run_schedule` 调用点,归其他)、报告构建/排序/摘要行、镜像对拍外壳与缓存 freeze/thaw。

每类同时输出 `_runs` 计数(该类最内层作用域内发生的 `_run_schedule` 次数)。计数是确定性的(同一搜索同一计数),可作前后等价证据;`*_ms` 是墙钟测量,与 seconds/solver_elapsed_ms 同类,进差分比对排除集(compare_summaries.py DEFAULT_EXCLUDE 扩 6 个键名)。
