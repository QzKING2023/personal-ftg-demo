# P7 终差分、默认切换与长期回归门（solver-finalize）

日期：2026-10-04　树：feature 分支工作树（票据09 + P0-P6 + 恢复等价修复，未提交）
证据根：`.scratch/solver-p7-01/`

## 1. 起点：P0-P6 交付物与未决项盘点

| 阶段 | 交付物 | 差分开关（默认=新路径） |
|---|---|---|
| P0 | profile_v2 确定性计数 + 增长夹具 + oracle（`tests/oracle/solver_growth_oracle.json`） | — |
| P1 | CompiledMoveIndex + staged 接种 + 落地死候选剔除 | `_compiled_index_disabled` |
| P2 | 接续探针精确结果缓存 + 显式注入 | `_edge_probe_cache_disabled` |
| P3 | SessionCheckpoint/TransitionMemo/CompiledSchedule 前缀 trie | `_delay_prefix_restore_disabled` |
| P4 | CycleInvariant 四前置条件 + 证明模式子树 DP | `_delay_dp_disabled` |
| P5 | SCC+Johnson 保序环枚举；叶 trie 登记；complete+看门狗+resume | `_cycle_enum_legacy` / `_route_leaf_memo_disabled` |
| P6 | 可复用 worker 池（pool 默认）、心跳/checkpoint 重启/LJF/quarantine/三态 | `--sweep-mode spawn`（oracle） |

接手时未决项与处置：
1. `test_solver_routes_cycles_refactor` 2 红（compiled-scope 基线）→ 恢复等价票据
   （`solver-restore-equivalence/issues/01` + `solver-recovery-followup/`）已修复别名
   根因并锁死 compiled-scope 契约；P7 按已证明契约更新 2 条性能断言
   （`session_steps` 不增；全跨调度夹具 `prefix_restores==0` 为守卫方向），46/46 全绿。
2. 跨期指纹漂移（e071fd→fce779→105c）无归因 → 见 §3，已裁决为既有 bug 的修复。
3. 叶登记 2× 劣化疑虑 → recovery-followup 已证为探针测量错误（内部 `_analyze`
   累计计数 vs 请求边界），独立请求两侧计数相同，无实现问题。
4. 全量验收自票据 09 起从未完整跑过（08/09 归档均为中断残卷）→ 见 §5。

## 2. 全栈差分（Tier A，默认表）

探针 `fullstack_diff_probe.gd`；结果缓存旁路，每相位前清探针缓存。

| 相位 | 指纹 | 墙钟 | session_steps |
|---|---|---|---|
| 新路径冷（六开关默认） | 105c43c7… | 89.7s（复验 40.5s，无并发争抢） | 657,434 |
| 新路径热（探针缓存命中） | 105c43c7… | 70.9s（复验 31.7s） | 435,304 |
| 旧路径 oracle（六开关全 legacy） | **105c43c7…（全等）** | 1031.8s（复验 574.9s） | —（见 fullstack-diff*.log） |

- 新==旧==冷==热，全语义指纹逐字节相等；两轮全栈差分（complete 修复前后各一轮，
  指纹均 105c43c7——一行 replay 修复零语义影响）。默认表单请求 **14.2×**（复验
  轮 574.9s/40.5s；首轮并发争抢下 11.5×）/ **4.2×**（对 HEAD=P2 树冷 376.8s）。
- 计数对照 P2 归档：delay_dfs_leaves 165,506→14,882（−91%），session_steps
  2,113,494→657,434（−69%）；探针命中热跑 99.8%（P2 口径不变）。
- facing mirror：`solve()` 默认 `facings=[1,-1]` 内置左右镜像对拍，上述指纹已含
  双面向；缓存键维隔离另由 `test_solver_edge_cache_equivalence` 门守卫。
- 空间多钉位 48/64/80：`test_solver_routes_cycles_refactor` 空间复验逐条相等断言全过。
- analyze 参照：P7 树 bb638738（HEAD 85ec8b32，差异=§3 同族 6 注记+措辞+schema）。

## 3. 跨期指纹漂移的裁决（ADR 0006 修订七）

在 HEAD 工作树（`../ftgdemo-head-p7`，票据09+P0-P2）重生成锚点：

| 运行 | 指纹 | 结论 |
|---|---|---|
| HEAD solve 冷/热 | e071fdc6…（==P1/P2 归档） | 归档可复现，跨日确定性成立 |
| HEAD solve restore-off | abfcfcce… | **HEAD 两侧本就不等** |
| P5 日 buggy 树 restore-on/off | fce779…/105c… | 别名 bug 使 on≠off |
| P7 树任意开关组合 | 105c43c7… | on==off，干净语义 |

字段级 diff（`report-head-cold.json` vs `report-new-cold.json`）：仅 8 处——6 条
`2C→6D→jA/jB/jC→…→j6D→5B→回2C` 空中链结构性循环注记（HEAD=污染侧早断「第 3 招
未能起手」；P7=干净侧晚断「第 5 次命中前滞空耗尽」）+ 1 处注记措辞精简
（「不下安全结论」→「不下结论」）+ `paused_incomplete` schema 字段（False）。
`report-head-off.json` vs `report-new-cold.json`：仅措辞+schema 两处——**无恢复
路径两侧内容全等**。结论：票据 04 恢复别名污染自 79 边扩表起潜伏于 HEAD；
P7 树（每圈 ChainLink 克隆 + compiled-scope）为正确语义，指纹旋转是 bugfix。

## 4. worker 重启实机复验（pool 三态）

- 小集（4 jobs/30 唯一）spawn oracle：30/30，`test_hit_profiles` 2 script_errors
  （=票据08已知）外全绿。
- pool + 外部 taskkill ×2：早杀（pause=0，564ms）→ gen1 从头重算 26.75s 完成；
  晚杀（pause=1、cycles 阶段在途）→ gen1 **`resumed: true`** 从 checkpoint 续算
  22.33s 完成。两次均 `exit-handled`（worker-exit-code-1）入 pool-events 流水，
  终态 covered=30/30、gaps=[]、status 全 complete。
- canonical 缓存逐字节对拍：spawn vs pool-kill4 / pool-kill5 均为 **30/30 digest
  全等 + 30/30 entry 字节相等**（含续算产出的条目）。

## 5. 完整 acceptance（79 边表首个完整跑；pool 默认参数）

`python tools/run_acceptance.py --sweep --output acceptance-full --cache …`，
总墙 **483.6s**（import 7.4 / 枚举 51.0 / 清扫 370.9 / 热跑 140.7），8 车道
busy 2249.6s、饱和 0.758、**最长单请求 229.6s**（e975ef80；心跳+暂停点全期可见，
无 stall/quarantine/kill）。

- 74 唯一请求：**complete 71 / failed 3**，gaps/事件全量入流水（三态纪律：
  杀/超限结构上不可能静默计过）。
- 3 条 failed 全为「重建请求不相等」：
  - `5aa13ff7…`（routes 测试 complete 模式 solve）：`_sweep_replay` 漏重建
    `SolverOptions.complete`——**P7 已修**（重建分支显式 plumb；`replay_gap_probe.gd`
    定位到字段，定向 sweep 复证 4/4 complete 零缺口；修复后全栈复验指纹不变）。
  - `75f69122…`/`d0497e27…`（test_move_table analyze_manifest ×2）：可变 manifest
    盘中态 + 带外重放的**设计内缺口**（修订四：如实记 gap，热跑就地现算兜底），
    开票 `issues/01-mutable-manifest-replay-gaps.md`。
- 断言面：3745 断言全过（pass_lines==assertions）；失败面全部为票据 08/09 扩表
  在途 FAIL 族（script_errors=FAIL 行+尾行）：combo 11（与 P0 归档 **逐字节相同**，
  diff 为空）、route 1、entry 4、hit_profiles 1、move_table 3、replay 13、spatial 1、
  charge 1、diagnose_inputs S6 红——票据 07 末归档（final-07，22 job 全绿）证明该族
  随 08/09 扩表+测试重写而来，P3-P7 零新增失败。
- 报告字段/失败分类/命中帧/输入顺序/循环集合/语义指纹：由 §2 全栈指纹与
  13 套阶段门承载（含 P5 顺序敏感对拍、票据 04 39 项、checkpoint trie 25 项、
  edge cache 47 项等）。

## 6. 增长曲线（`test_solver_growth` 六门全绿，oracle 未再生成）

| E | 结构候选 | 缺口探针 | session_steps | 延迟叶子 |
|---|---|---|---|---|
| 1 | 16 | 14 | 52 | 2 |
| 2 | 36 | 32 | 76 | 2 |
| 4 | 108 | 100 | 306 | 6 |
| 8 | 324 | 428 | 958 | 220 |

枚举域 O(N²)（结构候选）保持语义事实不压；重放域被 P3/P5 压平
（P0 基线 E=8 steps 21,826 → 958）。E=4/8 的 `prefix_frozen_returns=230` 表明
P3 冻结短路接管了收敛性赋值的子树。

## 7. 阶段测试结果（修复后复跑）

| 套件 | 结果 | 秒 |
|---|---|---|
| test_solver_restore_schedule_scope | PASS | 1 |
| test_solver_cycle_restore_alias | PASS | 1 |
| test_solver_cycle_invariant | PASS | 1 |
| test_delay_prefix_restore（票据04） | PASS 39 项 | 3 |
| test_solver_checkpoint_trie | PASS 25 项 | 10 |
| test_solver_delay_dp | PASS 45 项 | 30 |
| test_solver_edge_cache_equivalence | PASS 47 项 | 5 |
| test_solver_index_equiv | PASS 76 项 | 3 |
| test_solver_cache | PASS 63 项 | 1 |
| test_solver_perf_profile | PASS 24 项 | 2 |
| test_solver_growth | PASS 59 项 | 6 |
| test_solver_routes_cycles_refactor | PASS 46 项 | 5.4 |
| python -m unittest tools.test_run_acceptance | OK 29/29 | 27 |

## 8. complete 模式与观察上限审计

- `complete` 是语义维度（进请求键，与默认截断互不命中缓存）；`_analyze` 在
  complete 模式把报告容量换成 `1<<30`（`_route_report_cap`）——**不依赖
  MAX_ROUTE_REPORTS 语义截断**，`MAX_ROUTE_NODES=8` 仍是语义常量。
- 观察上限全部显式未完成：`MAX_ROUTE_REPORTS` 触顶注记「路线集合未完成」；
  `MAX_ROUTE_DELAY_TRIALS` 全败按最远失败如实上报（循环证明不受限）；
  `MAX_CYCLE_LAPS/FRAMES` 截断以 LAPS_EXHAUSTED/截断观测上报（不宣称证明）；
  240 帧恢复观测 `recover_truncated` 置位；`MAX_AIR_DELAY=40` 规格保证枚举完备。
- 看门狗暂停 `paused_incomplete` 且不进结果缓存；resume 续算剥离暂停注记后与
  不中断路径指纹全等（P5 门 + P6 缓存字节全等证）。

## 9. 剩余风险与回滚入口

**剩余风险**
1. test_move_table 可变 manifest 带外重放缺口（2 条/全量跑，已开票 01）——gap
   如实记录、热跑兜底，不影响 job 断言；修复不得改请求键语义。
2. 票据 08/09 在途 FAIL 族（combo 11/route 1/entry 4/hit_profiles 1/move_table 3/
   replay 13/spatial 1/charge 1/diagnose S6）＝测试期望未随 79 边表更新，属票据
   09 验收尾巴，非性能栈问题。
3. 恢复别名修复改变 6 条循环注记的正确语义 ⇒ 所有钉死旧注记文案的外部对照
   （旧归档 Tier B 指纹 e071fd/85ec8b）按 ADR 0006 修订七记账，不判回归。
4. 跨调度前缀共享（compiled-scope 阻断）是保守口径：合并域收益（默认表 ~1.3%
   steps）搁置，重新打开需逐字节等价证明（routes 测试断言已钉死方向）。

**回滚入口（旧路径全部保留为 oracle）**
- 逐层：`ComboSolver._compiled_index_disabled`（P1）/`_edge_probe_cache_disabled`
  （P2）/`_delay_prefix_restore_disabled`（P3）/`_delay_dp_disabled`（P4）/
  `_route_leaf_memo_disabled`、`_cycle_enum_legacy`（P5）置 true；
  **差分第二路径前必须清两层缓存**（`clear_result_cache()`+`clear_edge_probe_cache()`）。
- 清扫层：`--sweep-mode spawn`。
- 别名修复与 compiled-scope **无行为回退开关**（回退＝回到已知 bug）。
- 任何 combo_solver.gd 文本改动轮换全部持久缓存 digest（semantics 签名），
  回滚后首次冷跑自愈；本次 `_sweep_replay` 修复已使 08 时代缓存全部轮换（预期）。

## 10. 复现命令

```bash
# 全栈差分（独立 APPDATA）
APPDATA=$PWD/.scratch/solver-p7-01/appdata-diff LOCALAPPDATA=$PWD/.scratch/solver-p7-01/appdata-diff \
  "D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path . \
  -s res://.scratch/solver-p7-01/fullstack_diff_probe.gd
# HEAD 锚点（git worktree add ../ftgdemo-head-p7 HEAD 后）
  … -s res://.scratch/head_probe.gd        # 期望 e071fdc6…
  … -s res://.scratch/head_restore_off_probe.gd  # 期望 abfcfcce…
# 阶段套件
bash .scratch/solver-p7-01/run_stage_suite.sh
# 击杀复验
bash .scratch/solver-p7-01/run_pool_kill5.sh
# 全量验收
python tools/run_acceptance.py --sweep --output <新目录> --cache <新目录>/solver-results.cache
# 重建门探针（complete 修复验证）
… -s res://.scratch/solver-p7-01/replay_gap_probe.gd
```
