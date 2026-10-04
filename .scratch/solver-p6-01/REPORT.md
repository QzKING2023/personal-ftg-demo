# P6 solver-pool：可复用 worker 池、心跳/checkpoint、LJF、quarantine、三态（2026-10-04）

票据：solver-scalability 10（P6）。交付物：`tools/run_acceptance.py`（WorkerSlot/SweepPool/LJF/durations 副车/三态/--only/--sweep-mode）、`tools/solver_pool_worker.gd`（新）、`scripts/combat/combo_solver.gd` 六处最小接缝（solve 的 resource_mode、analyze/analyze_manifest 的 mode、_finish_analyze_request 暂停不入缓存、_sweep_replay overrides+report 返回、新增 _sweep_store_completed）、ADR 0006 修订六、`tools/test_run_acceptance.py` PoolTests 10 例（真子进程 fake 引擎，Popen argv shim 注入）。

## 门与结果

| 门 | 结果 |
|---|---|
| Python 单测（test_run_acceptance + compare_summaries） | 35/35 OK |
| Godot 语法（--check-only worker；真引擎加载 combo_solver） | PASS |
| solver 既有测试（cache / checkpoint_trie / delay_dp / cycle_invariant / delay_prefix_restore） | 全绿 exit=0 |
| test_solver_routes_cycles_refactor | 2 FAIL = **在途基线，与 P6 无关**（见下"归因"） |
| 小集差分 spawn(A) vs pool(B)：canonical 缓存 | 30/30 digest 集合相等，逐条 entry 文本逐字节相等 |
| 小集差分 warm summary（compare_summaries --tier-b） | 全过（指纹+keys+断言+退出码逐字段相等） |
| test_hit_profiles warm 2 script_errors | 两侧同值（在途基线，票据 08 已知） |

小集：`--only test_solver_cache,test_hit_profiles,test_solver_growth,test_solver_index_equiv`（188 请求普查后选定；枚举 30 唯一 descriptor，含两个 ~86s 重请求）。

## 池化实测（真引擎）

- Run A（spawn 基线，6 车道）：30/30 complete，sweep 墙 87.0s，总 98.1s。
- Run B（pool，6 车道，watchdog 2000ms）：30/30 complete/covered；**外部 taskkill 击杀 lane0（PID 17420，重任务 32fbba… 在途）**→ runner 捕获 `worker-exit-code-1`（事件 `exit-handled`，不计 runner kill）→ gen1 重生（PID 29932）→ **从 checkpoint 续算**（终行 `resumed: true, attempts: 2, worker_exits: [1]`）→ 仍入缓存、covered。总墙 156.7s（重启重算 ~55s 代价如实计入）。
- Run E（pool，2 车道，durations 副车来自 Run B）：30/30 complete，墙 90.9s；**LJF 派发顺序 = durations 降序**（首两个派发 32fbba[143.18s]、6dddfe[97.2s]）。
- worker 复用：Run B 6 进程 served 30 任务（slot2 单进程 8 个）；Run E 2 进程 served 30（17+13）。spawn 模式需 30 次引擎冷启动。
- 心跳样本（Run B worker-00）：`{"digest":"32fbba…","pause":1,"phase":"cycles","cycles_done":1,"profile":{…P0 v2 计数…}}`——P5 看门狗安全点 + P0 profile_v2 即心跳载荷。

## 缓存命中 / 损坏（真引擎）

- 命中（Run D，cacheD=cacheB 完好）：枚举阶段即全命中 → sweep **0 任务、0 worker**、cache_hit 零派发；warm 指纹与冷算全等（Tier B 同门）。
- 损坏（Run C，cacheC=cacheB 首条 entry 行替换为非法 JSON）：坏行逐行跳过（Godot `_load_persistent_entries` 与 python `_read_cache_file` 同口径）→ 受损 digest 枚举 miss → pool 重算 1 任务 → merge 后 canonical 自愈（30 行 0 坏行）。**坏行绝不当作 cache hit**。
  - 注记：损坏注入行漏写换行符，坏行与次行拼成一行（等价于"一行损坏"），32fb 恰为次行故被重算——语义结论不受影响，且顺带实测了拼接型损坏。
- pool 级 pre-covered skip（canonical 已含 digest → attempts=0/cache_hit=true/零进程）由单测 `test_precovered_digest_is_skipped_without_any_worker` 锁死；真机常态下命中在枚举阶段吸收（Run D 形态）。

## 三态与"禁止被杀进程静默计过"

- complete：仅当健康 attempt 产出 ok 结果（且缓存覆盖，或池前已覆盖）。被杀 attempt 不产生结果行 → 不可能 complete。
- incomplete：重启额度耗尽但观察到过进展（心跳/暂停 checkpoint）→ gap 如实记录，热跑 miss 兜底（ADR 0006 修订四口径，不判死）。
- failed：replay ok=false / worker 自死且重启耗尽且零进展 / slow quarantine。
- 样例落盘：`sample-quarantine-failed-sweep.json`（failed, kill_reasons=["slow-quarantine"]）、`sample-recovery-interrupted-incomplete-sweep.json`（incomplete, ["stall","stall"]）、`sample-zero-progress-failed-sweep.json`（failed, ["stall","stall"]）。
- 无进展双探测器：心跳 mtime 停滞（进程卡死）与阶段计数停滞（心跳在跳但 phase/sources/cycles/spatial 不动）分别单测锁定；慢请求 quarantine 走预算（默认 3600s）强制 failed + quarantined 列表，绝不隐藏超时。

## 归因：test_solver_routes_cycles_refactor 2 FAIL 非本票

失败断言（session_steps 4973→4973、prefix_restores=0）由 15:38 后的在途改动 `_memo_scope_key(opts, compiled)`（compiled 语义并入叶 memo 作用域键）引起：本票树上仅反转该一处即全绿（4973→4923、restores=20，与 14:14 绿证据逐字同）；P5 backup（无该改动）亦绿。P6 六处接缝与该差分正交。处置：记录为在途基线（同 test_combo_solver 11 FAIL 先例），断言是否随 compiled-scope 键放宽由票主决定。

## 复核补记（2026-10-04 晚，compiled-scope 取舍终审）

在当前树（含 compiled 键 + P6）重跑你在途调查的两个探针（证据 `recheck-field-diff.log` / `recheck-default-memo.log`，并归档至 solver-p5-01）：

- **field-diff（restore on/off，默认表 solve(null)）：分歧与加键前逐字节相同**——同样 6 条循环断链注记（note#20/22/25/33/36/41），on 侧早断（"第 3 招未能在第 26 帧前起手——取消窗口关闭"），off 侧晚断（"第 5 次命中前连段结束——滞空资源耗尽"），1/514 部件差异、全部集中在 cycles 注记。
- **default-memo（leaf 登记开关，默认表单面向 analyze+spatial）：compiled 键仅移除 47/94 次跨 schedule 恢复（steps +5238/+11238，≈1.3%）**，其余计数（leaves 83215/166430、spatial_rechecks 21/42、frozen 521/1042）与 13:41 加键前完全相同；off/on 指纹两侧均相等。
- 判定链：compiled 键使 trie 恢复全部落在 same-compiled 域（按构造精确）→ 该域内分歧依旧 → **默认表恢复路径漂移不从 trie 跨 schedule 复用进入，而从 compiled 键管不到的显式父链 / frozen_run 嫁接（票据 04 机制）进入**。
- 症状定位：差异全部是空中链循环（2C→6D→jA/jB/jC→…→5B）的代表性断链归因；off 侧"滞空资源耗尽"vs on 侧"取消窗口关闭"——指向恢复快照的空中资源/滞空记账或 hitstop 边界帧偏移。
- 另一独立发现（加键前已存在、加键后依旧）：leaf 登记开时默认表 steps/leaves/spatial_rechecks 全线 2×（429881→859762），指纹相等——P5 叶登记在默认表是 2× 劣化而非优化，属另一张待开票。

**结论**：compiled 键理论正确（跨 schedule 恢复确实不安全）、成本已量化（默认表 ≈1.3% steps + routes 夹具跨路线共享清零），但**不是当前漂移的修复**；routes 测试的两条断言**暂不按新契约修改**——病根（票据04 恢复路径透明性被破坏）修复后跨路线共享可能复活，现在固化 restores==0 契约为时过早。

## 运行方式

```
python tools/run_acceptance.py --sweep --output <dir> --cache <f>   # 默认 pool
python tools/run_acceptance.py --sweep --sweep-mode spawn ...       # 票据08差分 oracle
--pool-watchdog-ms 30000 --pool-stall-limit 900 --pool-restarts 2 --pool-budget 3600
--only job1,job2                                                     # 证据小集
```

## 证据文件索引

- runA.log/runA-spawn/（spawn 基线）；runB.log/runB-pool/（pool+真杀恢复；pool-events.jsonl 含 spawn/exit-handled/kill 流水）；runC\*/（缓存损坏）；runD\*/（缓存全命中零任务）；runE\*/（LJF+复用）；enumerate-census/（188→74 普查）；sample-\*-sweep.json（三态样例）；test_solver_cache.log 等（单测日志）；test_routes_p6_nocompiled.log（归因实验：仅撤 compiled-scope 改动全绿）；test_routes_prep6.log（P5 backup 全绿）。
