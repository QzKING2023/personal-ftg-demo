# P5（solver-routes-cycles）验收记录 — 2026-10-04

## 交付内容

四项（feature 分支工作树，叠加在 P4 未提交在途树上）：

1. **环枚举：SCC 预处理 + Johnson 风格保序去重**（`_elementary_cycles` 重写）
   - 迭代 Tarjan SCC（`_scc_membership`）+ 逐根 Johnson 闭路搜索（`_circuit_dfs`：
     blocked 集 + B 表解锁，教科书形态）。顶点序取 **adj 插入序**：每个环在其
     「序最小成员」处生根、恰好枚举一次；根迭代按序移除顶点、DFS 限制在根的
     强连通分量内、blocked 剪枝——三面剪掉的分支都不含被上报的环（旧 seen
     去重本就丢弃它们），DFS 前缀序不变。
   - **输出与旧全起点 DFS + canonical 去重同序同集**（notes 顺序敏感的指纹
     不漂移）；`_canonical_cycle` 字典序旋转归一保持。旧实现保留为
     `ComboSolver._cycle_enum_legacy` 差分 oracle（先例 `_compiled_index_disabled`）。
   - 非平凡 SCC 外的起点（DAG 区域）不再整棵遍历——重复遍历减少的主要来源。
2. **路线叶 trie 登记（prefix/suffix memo）+ 空间分层缓存**
   - `_route_run` 叶子执行设 `record_checkpoints`（开关
     `_route_leaf_memo_disabled`）：兄弟路线与同档空间复验从最深输入帧恢复，
     只重放输入分歧后的 suffix；scope 键含 facing/pin_dx，即
     (路线输入前缀 × 面向 × 48/64/80 钉位档) 分层缓存。碰撞判定仍全部走真实
     CombatSession（不做纯几何近似）。
   - `_verify_route_spatial`（单条复验，P5 抽出）+ `_verify_routes_spatial`
     （全量入口）。
3. **complete 模式：MAX_ROUTE_REPORTS 与语义解耦**
   - `SolverOptions.complete = true`：`_route_report_cap` 换入无上界值，全部
     ≤ MAX_ROUTE_NODES=8 的简单路径照常枚举并逐帧模拟；语义维度，进 solve
     请求 descriptor（`"complete": {"present":…, "value":…}`），与默认截断
     模式互不命中结果缓存。
4. **资源看门狗：只能暂停并持久化 incomplete 状态**
   - `SolverOptions.watchdog_ms`（0=不启用；资源控制量，不进请求键）：安全点
     = 一个路线源/结构循环/空间复验完成之后；`_pause_and_persist` 冻结快照
     （canonical 表文本 + 冻结报告 + 进度游标）写 `resume_path`（回退
     FTG_SOLVER_RESUME；未配置则如实注记「未能持久化」）。
   - `ComboSolver.resume_analysis(path)`：续算腿不重跑边/缺口阶段（结论在冻结
     报告里），路线/循环/空间从游标继续；可多次暂停。solve 级暂停以面向为
     包裹粒度（线程快照 + 冻结 primary + pristine_sections + pending_facings），
     续算收尾与 solve 同一镜像对拍/合并路径（`_merge_facing_run` 共用助手）。
   - 暂停报告 `paused_incomplete = true`、暂停注记前缀「资源看门狗暂停：」、
     续算入口剥离暂停注记；暂停报告不进结果缓存。

## 新增测试

`tests/test_solver_routes_cycles_refactor.gd`（46 断言，全绿）：

- 环枚举差分：合成图（空/自环/DAG/二环/插入序≠字典序/双 SCC 桥接/K4=20 环/
  汇点）+ 120 张确定性 LCG 随机图 + 夹具表 E=4 真实邻接图 + 插入序反转——
  Johnson vs 旧路径**顺序敏感逐字节对拍**；每环恰一次 + 字典序最小起点旋转。
- 路线叶登记差分（小分支夹具 S→L1{a,b}→L2{a,b}，10 条路线 + 空间复验 12 档）：
  开关两跑全语义指纹全等、`session_steps` 严格下降（1737→1733）、
  `prefix_restores`>0、`spatial_rechecks` 不变、空间失败按路线逐条相等。
- complete 模式（分支夹具 11 招 192 叶路径）：默认截断恰 16 条 + 注记；
  complete 94 条 == 邻接图暴力叶计数 94、无截断注记、默认集合是子集。
- 中断恢复：分析级（看门狗 1ms 多次暂停 → resume_analysis 循环）与 solve 级
  （双面向）最终指纹都与不中断路径全等；暂停腿如实注记 + 快照落盘；缺失/
  损坏快照文件被拒绝并说明原因。

## 回归（PASS/FAIL 序列与基线逐项一致；零新增失败）

| 测试 | 结果 | 基线对比 |
| --- | --- | --- |
| test_solver_perf_profile (P0) | 24/0 exit=0 | PASS/FAIL IDENTICAL（全行逐字节同，session_steps 2932 同值） |
| test_solver_index_equiv (P1) | 76/0 exit=0 | PASS/FAIL IDENTICAL |
| test_solver_edge_cache_equivalence (P2) | 47/0 exit=0 | PASS/FAIL IDENTICAL |
| test_solver_checkpoint_trie (P3 门) | 25/0 exit=0 | PASS/FAIL IDENTICAL |
| test_delay_prefix_restore (票据 04) | 34/0 exit=0 | PASS/FAIL IDENTICAL |
| test_solver_delay_dp (P4) | 45/0 exit=0 | exit=0（无 P4 档案对照，全过） |
| test_solver_cycle_invariant (P4) | 30/0 exit=0 | exit=0（同上） |
| test_solver_growth（+oracle 门） | 59/0 exit=0 | PASS/FAIL IDENTICAL；SOLVER_GROWTH_JSON 与 P4 基线**逐字节全等**（含 E=8 fingerprint/session_steps 958/prefix_restores 30） |
| test_solver_cache | 63/0 exit=0 | exit=0 |
| test_solver_spatial | 558/1 exit=1 | PASS/FAIL IDENTICAL（P3 基线既有 1 在途 FAIL 不变） |
| test_solver_route | 541/1 exit=1 | PASS/FAIL 与全部断言行逐字节同（票据 09 在途 1 FAIL 不变）；测试日志除 metrics JSON 行外全等 |
| test_solver_entry | 46/4 exit=1 | PASS/FAIL IDENTICAL（在途 4 FAIL 不变） |
| test_solver_routes_cycles_refactor (P5 门) | 46/0 exit=0 | 新门，恢复文件重跑再确认 |
| test_solver_cycles | 30/0 exit=0 | PASS/FAIL IDENTICAL |
| test_combo_solver | 226/11 exit=1 | PASS/FAIL IDENTICAL（在途 11 FAIL 不变） |

观察常量未动：MAX_CYCLE_LAPS/MAX_CYCLE_FRAMES/MAX_ROUTE_DELAY_TRIALS/
MAX_ROUTE_REPORTS/MAX_ROUTE_NODES/MAX_AIR_DELAY/RECOVER_HORIZON/PIN_DX/
SPATIAL_PROBE_DISTANCES 全部保持原值。

### metrics JSON 指纹值的跨期漂移（调查结论，如实记录）

route/entry/cycles/combo 各测试 metrics 行内的 per-key report fingerprint 值
与 P4 档案不一致（断言序列、报告内容、growth JSON 全等；fingerprint 值漂移）。
追查到底：

1. 逐开关二分（叶登记/Johnson/恢复总开关）都不还原 P4 值；
2. **把 `_analyze`/solve 循环/`_route_run` 字节级回退为 P4 原文（P5 全部执行
   路径还原），默认 solve 指纹仍为今日值 fce77999…，不是 P4 档案的 e071fd…**
   ——漂移先于 P5 改动存在；
3. 敏感面定位：默认表约 75 条结构性循环注记中数条「走得最远的失败」文案在
   恢复开/关两侧不同（例：restore-on 报「第 3 招未能在第 27 帧前起手」、
   restore-off 报「第 5 次命中前连段结束（滞空资源耗尽）」）——
   `_run_ranks_higher` 的并列失败归属对回放机制敏感，说明 **P3 恢复机制在
   默认表循环证明搜索上存在改变个别延迟向量结果的等价性缺口**（夹具级门
   未覆盖默认表；P5 循环搜索路径与 P4 逐字节相同，缺口非 P5 引入）。
4. 处置：P5 各差分门（on/off 指纹全等）全绿；P0-P4 门全绿（其口径是
   PASS/FAIL 与断言序列）。**预存在的恢复等价性缺口单列，建议开票**：
   以 `_delay_prefix_restore_disabled` 为 oracle、默认表全部结构性循环为
   样本、逐叶子投影对拍定位分歧向量。

## 重复遍历减少量（确定性计数口径）

- 环枚举（SCC + Johnson）：默认表邻接图 17 节点/75 环，旧路径从全部 17 个
  起点做全起点 DFS（DAG 区域整棵遍历后靠 seen 丢弃）；新路径只在 3 个非平凡
  SCC 内逐根枚举、每环恰一次——K4 合成图 20 环两组同序同集对拍。
- 路线叶登记：默认表单面向分析（含空间复验 21 档）session_steps 424,643 →
  423,881（−762，0.18%；P3 捕获登记已覆盖大头——默认表兄弟路线的成功向量
  多为最早等待，与捕获基线输入相同）；分支夹具（兄弟路线共享 [S,L1*] 前缀、
  10 路线 × 3 钉位）1737 → 1733 严格下降且指纹全等；空间失败逐条相等。
- 增长夹具（线性链）GROWTH_JSON 与 P4 基线逐字节全等（无共享面，如实为零）。
- 墙钟（信息性，非门）：route 测试 delay_leaf_ms 1485s → 856s、route_walk_ms
  638s → 370s（P4 档案轮疑似受并行争用影响，不据此宣称 P5 加速；combo
  817s → 853s +4% 在噪声内）。

## 报告完整性

- 默认模式不变：MAX_ROUTE_REPORTS=16 上限 + 如实注记「路线集合未完成」
  （P5 门断言：分支夹具默认恰 16 条 + 注记在）。
- complete 模式：94 条叶路线 == 邻接图暴力叶计数 94，无截断注记；默认截断
  集合是完整集合的子集；`complete` 进 solve 请求键（与默认模式互不命中缓存）。
- 看门狗：分析级与 solve 级中断-恢复最终报告与不中断路径**指纹全等**
  （暂停注记剥离后）；暂停报告 paused_incomplete 如实标记且不进结果缓存；
  无恢复路径时如实注记「未能持久化」；缺失/损坏快照被拒绝并说明原因。

## ADR

- 新增 `docs/adr/0007-solver-report-completeness-and-watchdog.md`：报告完整性
  模式与资源看门狗契约（暂停持久化、永不静默截断；等价纪律沿用 ADR 0006
  两级制）。
- `docs/solver-guide.md` 追加 P5 节。
- ADR 0006 本体无需修订：P5 的环枚举/叶登记属其已批准的机械等价变换类
  （前缀快照/恢复的同族），complete/看门狗走新 ADR 0007。
