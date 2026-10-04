# P3（solver-checkpoint）验收记录 — 2026-10-04

## 交付内容

逐叶完整重放 → 基于真实 CombatSession checkpoint 的前缀转移。

- `scripts/combat/combo_solver.gd`：
  - 三个不可变内部类 `CompiledSchedule`（编译表深冻结视图 + 按帧索引/游标）、
    `SessionCheckpoint`（clone_state **全量执行状态** + `_run_schedule` 全部跨帧
    计数器 frame/physics/verified/ended_reasons/snapshots/extra×3/proven_period/
    laps_observed/boundary；构造深冻结、无写入方法；`as_prefix()` 只发投影副本）、
    `TransitionMemo`（按输入内容寻址的持久化 trie，节点=输入帧事件后 checkpoint，
    子边键=(帧,输入摘要)；scope=表摘要+缺口注入摘要+facing+pin_dx+起始+选项形状；
    每 scope 8192 节点确定性饱和）。
  - `_run_schedule`：legacy dict 前缀入口归一化为 checkpoint；memo 最深节点与显式
    父 checkpoint 取更深者恢复；捕获运行（`record_checkpoints`）在每个输入帧登记
    节点；惰性区间批量推进（无输入/无预期命中/无捕获点围栏 + `_session_inert`
    可证明无事件时整段步过，只省事件解析，物理步进照常）；memo 恢复不越过
    capture_at、恰在捕获点时立即发出 prefix_capture。
  - `_delay_dfs`：每个内部节点按边界差分捕获子树共享 checkpoint（证明模式维持
    frozen 短路；**路线模式只恢复不短路**——叶子数/字典序/预算语义不变）；捕获从
    父 checkpoint 增量执行；d-循环显式落链路径赋值（修复 pivot 捕获此前依赖
    「上一叶子残留赋值」的侥幸不变式）。
  - `_capture_delay_prefix` 公共契约保持返回 Dictionary（票据 04 测试口径不变）。
  - `_memo_scope_key` 注入签名按 MoveData 实例缓存（ObjectID 单调不复用）。
- `scripts/combat/combat_session.gd`：新增只读 `has_deferred_event_sources()`
  （无输入事件源的保守超集；与 clone_state 完整性契约注释联动）。
- `tests/test_solver_checkpoint_trie.gd`（新）：从零重放 vs checkpoint 恢复三层
  对拍（oracle/冷恢复/热恢复），覆盖 hitstop/landing/air exit/bounce/charge/
  side swap/失败断点（frozen·超长·预算·观测上限）/空中起始 prologue-skip，
  外加冻结纪律、热确定性、跨搜索不干扰、pin_dx scope 隔离、深层 pivot 变异。
- `docs/solver-guide.md`：新增「Checkpoint 前缀转移（P3）」节。

## 回归（全部与基线逐字节一致；零新增失败）

| 测试 | P3 | 基线 | 备注 |
| --- | --- | --- | --- |
| test_delay_prefix_restore | 34/0 | 34/0 | 票据 04 harness 不动全绿 |
| test_solver_checkpoint_trie | 25/0 | 新增 | |
| test_combat_session_restore | 98/0 | 98/0 | seam 差分 ~50 万检查 |
| test_solver_growth | 全过 | 同 | 指纹+形状量对 oracle 全等 |
| test_solver_cycles | 30/0 | 30/0 | 指纹与 P2 全等 |
| test_solver_index_equiv | 76/0 | 76/0 | 双路径指纹全等 |
| test_solver_edge_cache_equivalence | 47/0 | 47/0 | |
| test_solver_perf_profile | 24/0 | 24/0 | v2 确定性计数全同 |
| test_solver_spatial | 558/1 | 558/1 | FAIL 行逐字节同（票据 09 在途） |
| test_solver_entry | 46/4 | 46/4 | 同上 |
| test_combo_solver | 226/11 | 226/11 | 同上 |
| test_solver_route | 541/1 | 541/1 | 同上 |
| test_move_table | 333/3 | 333/3 | 同上 |
| test_replay_acceptance | 25/13 | HEAD 对照 25/13 | FAIL 行逐字节同 |
| test_charge_motion_sideswap | 54/1 | HEAD 对照 54/1 | 同上 |
| test_hit_profiles | 100/1 | 100/1 | 同上 |
| test_combat_session / bounce / air_d_landing / launcher_air_exits | 853/0, 83/0, 96/0, 39/0 | — | 会话族全绿 |

## 性能（默认表 10 次 solve，test_solver_cycles 内嵌 metrics）

- 总耗时 2961s → 1805s（**1.64×**；其中 1 个请求命中结果缓存，按 9 请求折算 1.42×）。
- route_walk_ms 1,337K → 513K（**2.6×**）；delay_leaf_ms 1554K → 1233K；全部
  指纹与 P2 基线全等（语义零变化）。
- 增长夹具 session_steps（形状量不变）：E=8 21826 → 958、E=4 6510 → 306。
- 冷请求的边枚举 timing 探针先于路线搜索执行（trie 尚空）不受影响——P3 收益
  集中在 P0 认定的绝对大头（route_walk/delay_leaf 重放域）。

## 已知边界

- 惰性批量推进在连段活跃区间保守放弃（取消/恢复窗与木桩计时器都能发
  COMBO_ENDED，无法廉价证明不触发）——中段收益主要来自 trie 而非批量推进。
- `_delay_prefix_restore_disabled` 仍是全机制旧路径 oracle 总开关；变异钩子
  装载时 memo 读写整体旁路（防污染跨样本）。
