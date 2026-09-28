# 票据 07 验收报告：专用击飞、空中普通链与地空出口

日期：2026-09-28。参数版本：frame-data.md **v0.9**（TUNING_INITIAL）。运行环境：Godot 4.5.1 headless。
证据：本目录 `replay-routes.log`（双面向回放 R1–R6）、`unit-tests.log`（tests/test_launcher_air_exits.gd）；全量自动化见 `full/`（run_acceptance.ps1 输出，2026-09-28）。

## 全量自动化结果（full/，2026-09-28）

20 个 job（import + 17 个 test_*.gd + diagnose_inputs + main-smoke）。16 个一次全绿（charge_motion_sideswap 55、combat_session_restore 98、crouch 45、input_normalization 22、joint 28、**launcher_air_exits 39**、move_table 312、replay_acceptance 123、smoke 123、solver_cache 16、solver_cycles 30、solver_route 7118、solver_spatial 9409、import/diagnose/main-smoke）。4 个失败均为「全量运行途中已修复的过时断言」（其进程在修复落盘前启动、加载的是旧测试文件）：

| 任务 | 套件内 | 原因 | 修复后复验 |
| --- | --- | --- | --- |
| test_combat_session | exit=1（852P） | 临界帧 `dummy_hitstun_left == 6` 因 jB untech 12→20 迁移失效（探针实测 11） | `test_combat_session-rerun.log`：854P exit 0 |
| test_combo_solver | exit=1（1074P） | 「2C 唯一有效出边」断言早于票据 07 的 6D/2D 链边 | `test_combo_solver-rerun.log`：1076P exit 0（ALL PASSED） |
| test_solver_entry | exit=1（47P） | 首招候选/空中起始清单未含 2D/6D/jC | `test_solver_entry-rerun.log`：ALL PASSED exit 0 |
| test_hit_profiles | exit=1（104P） | 「6A jump cancel → jA」断言未含 jB/jC | `test_hit_profiles-rerun.log`：ALL PASSED exit 0 |

与票据 06 的 full-rerun 同一口径：套件内失败记录保留，修复后逐文件复跑留档。

## 资源与参数版本

- 新 schema：`MoveData.air_exit_targets`（地面招式实际 HIT 且计划位移真实离地后，命中确认窗口内按空中姿态起手的空中目标；沿用 cancel_window_frames、不另设窗口；仅地面招式可声明、目标须为空中招式；收尾招式不得声明）与 `MoveData.hitbox_y_offset_px`（命中框垂直偏移，正为向下、0=居中；表达真实垂直判定范围，扫掠同样按偏移后的框计算）。MoveTable 整表校验（收尾/AIR 姿态矛盾、跨招式引用、姿态一致性）。
- 新建 `data/moves/jC.tres`（7/5/14、伤 14、mid+air、48×30 gap 4、motion 4/0、starter C、grounded 12/16·100 + airborne untech 20/26·up 60·100）。
- 新建 `data/moves/6D.tres`（9/4/20、伤 18、48×36 gap 4、motion 88/**−48**、starter D、派生 6D·优先级 2；airborne-only untech 30/36·up 140·100——无 grounded 键；`air_exit_targets=["jA","jB","jC"]`；被防 8/9/45）。
- 新建 `data/moves/2D.tres`（8/4/18、伤 17、36×46 gap 3·**y_offset −70**、motion 0/−64、starter D、蹲姿限定·优先级 3；airborne-only untech 26/32·up 180·60；`air_exit_targets=["jA","jB","jC"]`）。
- `6A.tres`：jump_cancel_targets `["jA"] → ["jA","jB","jC"]`。`jA.tres`：cancel += jC。`jB.tres`：cancel += jC（jD 边保留至票据 08 迁移）、airborne untech 12→**20**（对齐「普通空中硬直 20f」全局初值；A 起手时间层下 12 使 demo 路线第 6 击差 1 帧——实测锚点见下）。`2C.tres`：链式 += `["6D","2D"]`（窗口 3）。
- `data/move_manifest.tres` 追加 jC/6D/2D（21 项）。
- 训练场：木桩状态行新增「空中 N px」高度（对空判定与高度失配的可观察口径）；诊断快照新增 `air_exit_open`/`hitbox_y_offset`/`dummy_air_height_px`。
- Solver：新 EdgeKind `AIR_EXIT`（枚举、缺口字段映射、`_links_for_edge` 按停顿中按下（wait=1，命中当帧姿态仍为地面）、`_fill_air_exit_edge` 经「使前招实际命中的接续上下文」逐候选验证（对空限定前招在地面钉位下 solo 必 MISS）、`_context_via_air_exit` 兜底、ground→air 缺口排除 air_exit 已声明对、缓存字段与 SCOPE_TEXT 票据 07 段）。

## 行为锚点（单元与会话实测，全部真实运动）

| 项 | 结果 |
| --- | --- |
| 演示路线 | `5A>5B>5C>6A>jc.jB>jC` 六击**单连段** F6/21/38/54/75/91（双面向一致）；6A 需 5C 命中当帧 w=0 链式取消（A 起手时间层 0.618×14=8 帧硬直恰容 8 前摇）；Space F56 停顿中入槽、F63 pre-jump、F67 真实离地 |
| 6A 被防/挥空 | 无 pre-jump、无追击资格（被防接触不开放命中确认窗与 jc） |
| 2C>6D>jC | F13/31/47：6D F31 命中低浮空（airborne 资料）、F31 离地 12px、空中出口 F31 开（窗口内）、jC F40 起手 F47 命中 |
| 2C>2D 高度负例 | 2D active F25-28 期框底 393 恒高于浮空木桩顶 394.7+（垂直不重叠、木桩仍空中）→ 挥空；木桩 F31 触地倒地结束连段 |
| 2C>5D 时序负例 | F30 LINK_FAILED/CONFIGURATION_GAP（2C 未声明 5D 边）；独立起手 5D 判定全程落在普通倒地外 |
| 对地拒绝 | 6D 对地面目标 HIT_MISS（框触及、无 grounded 资料、无伤害无连段）；2D 高位框从地面木桩上方越过（无接触），挥空仍真实上升 F27 回落 |
| 2D 对空正例 | −40px 空中中立木桩：F9 命中（17.0）→ jA 出口 F18 起手 F22 命中 |
| 6D 穿越 | 命中后 cross_ok 授予，但 88px 在最小合法间距 48px + 击退漂移下终点未越身位——按 M-02 截原侧（正向换边为 motion 调校观察项）；被防截原侧、无出口；版边墙截断标记可观察、不出界、不换边 |
| 有限空中资源 | 上升是计划位移（速度无冲量）；滞空中 Space 无第二次上升冲量；2D 出口后 F38 物理回落；切招（jA/jC）不续期滞空 |
| 资源同步 | 注入仅 grounded 资料的 6D 表：会话 HIT_MISS、Solver 2C→6D 边按 MISS_NO_PROFILE 断链（两端一致） |

## 回放输入（replay-routes.log，双面向真实运动）

| 场景 | 起始 | 面向 | 结果 |
| --- | --- | --- | --- |
| R1 演示路线 | 50px | ±1 | 六击单连段 F6/21/38/54/75/91 |
| R2 2C>6D>jC | 50px | ±1 | F13/31/47；出口 F31 开、jC 滞空起手 |
| R2b 6D 完整位移（M-02） | 50px | ±1 | 命中不取出口：截原侧、不换边（观察项如实记录） |
| R3 2D 高度/5D 时序 | 50px | ±1 | 2D 框底 393 vs 木桩顶 394.7+；5D CONFIGURATION_GAP |
| R4 对地拒绝 | 50px | +1 | 6D HIT_MISS；2D 高位越过 + 上升回落 |
| R5 2D>jA + 空中资源 | 50px | +1 | F9/F22；无二段跳、F38 物理落地 |
| R6 版边/被防 | 版边 | ±1 | 墙截断可观察不出界不换边；被防截原侧无出口 |

## Solver

- 边/路线总量：55 条边（票据 06 基线 43 + 12：6A jc jB/jC、jA/jB→jC、2C→6D/2D 链式、6D/2D→jA/jB/jC 空中出口）、442 条可读路线。
- AIR_EXIT 边：仅命中开放；前招需声明向上位移（无上升即结构拒绝——无离地即无空中姿态）；6D 的出口经「2C 链式进入且实际命中」的上下文验证 valid；2D 的出口在地面钉位下前招无从命中——如实按「无法构造前招能实际命中的上下文」排除（2D 正例由回放承担，replay-required）。
- 2C→2D 链式边：钉位探针按挥空排除（与回放高度失配结论一致）。
- 缓存键：`air_exit_targets`/`hitbox_y_offset_px` 纳入请求 schema（_MOVE_VALUE_FIELDS）。
- 已验证范围：钉位 timing 层；未支持：2D 垂直判定的真实高度窗、6D 真实穿越/墙边、真实空中距离与换边（replay-required，SCOPE_TEXT 已声明）。

## 失败断点与修复记录

1. 2D/6D 同优先级 2 并列键冲突 → 按既有 2A=3/6A=2 惯例改 2D 优先级 3。
2. 6D motion_y −18 在命中停顿（吞 3 个 active 帧）后仅剩 ~9 帧滞空，jC（前摇 7）出口在落地帧作废 → 调校 −48（表值 −18 为初值，如实记入 frame-data）。
3. demo 路线第 6 击差 1 帧：jB airborne untech 12 在 A 起手时间层（×0.547）下 6 帧撑不到 jC 前摇 → 对齐全局初值 20。
4. 6A 需 5C 命中当帧（w=0）链式取消：晚 1 帧则剩余硬直差 1 帧、连段在 6A 处断开重计——按帧序成立并记录（A 起手断链边界的行为事实，不是缺陷）。
5. R2b 正向穿越在 88px/48px 最小间距下几何不可达（终点差 ~13px）→ 改验 M-02 原侧保留；正向换边记为 motion/5B 对空资料调校观察项。
6. R6a 初版木桩置于玩家身后导致面向在消费前翻转、动作方向反向 → 改为悬空于正上方（同 x 不触发翻转）。
7. Solver 注入表测试误用静态 `analyze()`（加载默认 manifest）→ 改 `ComboSolver.analyze(table)`；直接复现 `_links_for_edge`+`_run_schedule` 确认注入表下 2C→6D 按 MISS_NO_PROFILE 断链。

## Code-review 修复（两轴评审后、提交前）

Standards 轴（自审 + 通读 diff）：`_context_via_air_exit` 初版漏掉出口按键尾链（上下文不可达目标）——补 `_links_for_edge` 尾链并改用与 jump 同构的 duplicate 拼接；`_fill_air_exit_edge` 全候选失败时补「对空限定前招在钉位探针内无法实际命中——replay-required」前缀（原样沿用挥空文案会丢失对空语境）；2D 优先级与 6D 并列（2）触发整表拒绝——按 2A=3/6A=2 惯例改 2D=3。
Spec 轴：全量途中 test_combat_session 临界帧断言 `dummy_hitstun_left == 6` 因 jB untech 12→20 迁移失效——探针实测新值 11 后更新断言（同帧顺序语义不变），单文件复跑 854 断言全绿（见下）；Solver 注入表测试误用静态 `analyze()`（加载默认 manifest、注入不生效）——改 `ComboSolver.analyze(table)` 并以 `_links_for_edge`+`_run_schedule` 直证注入表下 MISS_NO_PROFILE 断链。
修复后复验：test_combat_session 854P exit 0；test_launcher_air_exits、acceptance_replay_07 以最终代码复跑（本目录 unit-tests.log / replay-routes.log 为终版）。

## 待真人（EXPERIMENT_REQUIRED）

- 空中追击节拍：jc 起跳（Space→4f 准备）与空中出口（停顿中按键、恢复首个正常帧消费）的输入手感差异。
- 6D/2D 高度容差：2D 命中窗 h>7px 的边界（7px 附近）与 6D 居中框对低浮空的可达感。
- 6D motion_x 88 无法在合法间距换边（需 ≥~115 或 5B 对空资料前置）——「6D sideswap」设计路线的调校方向。
- 出口后滞空长度（−48/−64 上升）与 jA/jB/jC 的空中链节拍。
- 美术动作对齐（阶段 9）。
