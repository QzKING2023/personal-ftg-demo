# P4（solver-delay-dp）验收记录 — 2026-10-04

## 交付内容

两项（feature 分支工作树，叠加在 P3 未提交在途树上）：

1. **循环不变量形式化（CycleInvariant）**
   - `scripts/combat/combo_solver.gd` 新增内部类 `CycleInvariant`：票据 09 的
     `_cycle_monotonic_time_reason` 内联启发式升级为声明式契约。`evaluate`
     依次检查四项前置条件——每圈有效 HIT（循环成员全部是表内打击招式）、
     倍率有限且严格落于 (0,1)（starter×4 + 普通/滑行/弹地/落地连接四类每击
     倍率）、time_scale 在完整循环键中（活探针 settlement_state 携带 float
     型 time_scale 的防漂移检查）、无浮点下溢（视野内最小可达 time_scale
     = min(倍率)^(8×每圈判定段数−1) ≥ pow(2,−1022)）。任一不满足即 FALLBACK
     回退精确逐圈状态复现；全部满足才 APPLY（证明级排除）。适用域沿用票据
     09 口径（首命中资料为 GROUND_BOUNCE/LOW_FLOAT_TO_SLIDE），APPLY 文案与
     祑据 09 起逐字节一致——指纹零漂移。
   - `_simulate_cycle` 改用 `_cycle_invariant()`（实例方法收集表/倍率/活探针
     settlement）；倍率取 GameParams 实值（调 1.0 自动回退完整搜索）；测试缝
     `ComboSolver._test_cycle_factor_override`（仅测试可见，不进验收参数）。
   - GDScript 解析器坑：≤1e-308 的字面量被冲洗成 0.0——float64 最小正规数
     下界必须运行时 `pow(2.0, -1022.0)` 计算（写字面量会让下溢检查恒假，
     首轮测试当场抓到）。
2. **精确 delay state DP（证明模式）**
   - `_delay_dfs` 子树结果备忘录：内部节点在 pivot 捕获后按节点键查表，
     命中即返回首访者结果；正常出口登记。节点键四元组 = 剩余 link signature
     哈希（链接身份字段 + 不可调固定等待 + 枚举上限）｜可调槽深度（link
     index）｜前缀延迟赋值｜完整 SessionCheckpoint 内容哈希；命中前对
     checkpoint 全量内容深比较（哈希冲突续查探针键，绝不误合并）。前缀赋值
     必须入键：pivot 边界可能落在上一可调链接的预期命中之前（wait=0 时边界
     =锚点帧），编译预测尚未入态——这是「不能拿 settlement_state 做执行
     缓存键」之外的第二处禁止合并面。
   - 启用域仅证明模式（snapshot_every>0）；路线模式（预算按叶子执行扣减）
     保持旧 DFS——专项断言钉死。报告语义保持：字典序首访 + 失败并列保先，
     证明成立首访即早停。开关 `_delay_dp_disabled`（Tier A oracle）；
     计账 `delay_dp_stats()`/`reset_delay_dp_stats()`（searches/nodes/
     stores/hits，不进验收参数）；叶子日志/变异钩子装载时自动旁路。

## 新增测试

- `tests/test_solver_delay_dp.gd`（Tier A 差分 harness，45 断言）：旧 DFS vs
  DP 最终投影对拍 + DP 确定性 + 搜索形状不增 + 路线模式结果与逐叶日志不受
  开关影响 + 预算截断点不移动 + 计账非空洞。样本：hitstop 跳链 depth1-3、
  landing 接缝、air exit、bounce(j214D) 追击、charge、side swap(facing −1)、
  多段（注入 jB 落地→236C，默认表无可配置的「空中链+多段」共存路径）、空中
  起始、失败域（frozen 前缀断链/超长链 depth4/观测上限/预算）。
- `tests/test_solver_cycle_invariant.gd`（29 断言）：bounce/slide APPLY（含
  注入滑行克隆）+ 倍率=1（五类倍率逐一）+ 0/负/inf/nan 回退 + 下溢边界
  （0.5 APPLY / 1e-200 FALLBACK）+ 多 HIT 指数（hits_per_lap 计数与下溢
  触发）+ settlement 键漂移（缺字段/非 float）+ 每圈 HIT 缺失 + 端到端
  （APPLY 零快照 vs 倍率=1 回退真实产生逐圈快照）。

## 回归（与 P3 基线 PASS/FAIL 序列逐行一致；零新增失败）

| 测试 | 结果 | 基线对比 |
| --- | --- | --- |
| test_solver_checkpoint_trie (P3 门) | 25/0 exit=0 | PASS/FAIL IDENTICAL |
| test_delay_prefix_restore (票据 04) | 34/0 exit=0 | PASS/FAIL IDENTICAL |
| test_solver_index_equiv (P1) | 76/0 exit=0 | PASS/FAIL IDENTICAL |
| test_solver_edge_cache_equivalence (P2) | 47/0 exit=0 | PASS/FAIL IDENTICAL |
| test_solver_perf_profile (P0) | 24/0 exit=0 | PASS/FAIL IDENTICAL |
| test_solver_growth（增长夹具+oracle 门） | 全过 exit=0 | PASS/FAIL 与 SOLVER_GROWTH_JSON 全等 |
| test_solver_route | 541/1 exit=1 | PASS/FAIL 与全部 fingerprint 逐字节同（票据 09 在途 1 FAIL 不变） |
| test_solver_entry | 46/4 exit=1 | PASS/FAIL IDENTICAL（在途 4 FAIL 不变） |
| test_combo_solver | 226/11 exit=1 | PASS/FAIL IDENTICAL（在途 11 FAIL 不变） |
| test_solver_cycles | 30/0 exit=0 | PASS/FAIL IDENTICAL，10 个 per-key 指纹与 P3 基线全等 |

test_solver_cycles 的 metrics 账目差异（本运行 combo_cache hits=3 vs 基线 1）已归因：
本运行中同内容重建表请求（t1'→t1、plain'→plain）自然命中缓存，全部命中的
per-key 指纹与基线计算值全等；独立探针证明同内容重建表的请求摘要在进程内
稳定（t1-first == t1-rebuild，慢回边注入表构造不泄漏）。基线归档轮的两次
miss 属该轮环境差异（P2 归档 0 hits / P3 归档 1 hit / 本轮 3 hits，三轮
per-key 指纹全部一致）。总耗时 1805s → 1436s 的差额恰为基线多算的两次
重请求（≈326s），逐计算请求的 delay_leaf_ms 与基线噪声级一致——DP 未带来
可观测减速（每节点一次内容哈希，24 个证明搜索 2514 节点）。

## DP 合并域的实测结论（如实记录）

默认表全部差分样本 stores>0、hits=0——**当前编译/复验契约下合并域为空**：
存活的延迟前缀把绝对帧钉进完整 checkpoint（预期帧=实际帧的逐帧复验），不同
赋值必不同态；会收敛的赋值（越窗缓冲后被清、滞空耗尽作废）恰是会断链/截断
的赋值，先被 P3 的 frozen 短路处理。DP 的价值定位是**精确性保险**：输入
缓冲窗口、尾部发现等使不同延迟前缀收敛到同一完整状态的语义一旦出现，合并
自动生效且由 Tier A 门保证语义不变；当前开销为每节点一次内容哈希（24 个
证明搜索 2514 节点，无可观测量级差）。

## 观察常量未动

MAX_CYCLE_LAPS / MAX_CYCLE_FRAMES / MAX_ROUTE_DELAY_TRIALS / MAX_ROUTE_REPORTS /
MAX_ROUTE_NODES / MAX_AIR_DELAY / RECOVER_HORIZON 全部保持原值——DP 正确性
不靠调观测上限或报告容量掩盖。
