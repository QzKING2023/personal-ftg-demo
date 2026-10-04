# 09: j214D 弹地与跨状态循环边界

Status: implemented
Type: HITL
Stage: 8
Blocked by: 05, 08

## What to build

交付 j214D 的统一 GROUND_BOUNCE、触地／反弹阶段和一次性有限追击，并把 starter grade 与三层修正贯穿普通浮空、slide、Rekka、弹地和落地连接。A 起手可以命中但不能继续弹地后路线；B/C/D 起手只在真实条件成立时消费一次 followup。

## User stories covered

17, 18, 19, 20, 21, 22, 23。

## Acceptance criteria

- [x] j214D 命中 grounded 或 airborne 目标都进入 GROUND_BOUNCE；profile 可分别声明进入运动，但结果状态统一。
- [x] 触地事件首次发生时记录 bounce_contact 并开放追击；一次 j214D 最多一次反弹，弹地不刷新空中资源，不转普通倒地或 OTG。
- [x] A starter 的 bounce_followup 为 0：j214D 可以命中并产生反馈，但弹地后的新命中只能作为收尾；B/C/D starter 为一次性 1，成功追击后消费。
- [x] starter grade 首次有效 HIT 锁定并跨 slide、Rekka、bounce、落地保持；BLOCKED/MISS 不锁定，状态结束清除。
- [x] damage/time/trajectory 三层按乘法累计、分别舍入；伤害保留 10% 底线，时间／轨迹不继承该底线。
- [x] 正例：jC > j214D 对地或对空弹地；B starter 在触地后按剩余硬直接 5B/6A/214C；A starter 命中后不继续。
- [x] 反例：A starter 通过普通命中继续、B starter 每次命中刷新 followup、第二次 j214D 再次弹地、弹地被当作 OTG 倒地、状态转换重置修正。
- [x] 发现真实无限时必须调整局部资格、修正或参数并重放；不能用全局命中数或总时长上限截断。

## Solver and replay scope

Solver 状态键必须加入 starter grade、三层修正、bounce_contact、bounce_followup、反弹次数、受击运动和影响未来行为的位置关系；报告区分有限多圈、有效循环、未完成搜索和 not-supported。静态 spatial-valid 不证明真实弹地距离，触地／墙边／击退需 replay-required。

## Human judgment

必须确认弹地速度、触地节拍、A/B/C/D 起手手感、B+ 一次性继续和 loop 是否自然；真人反馈前只能称为 TUNING_INITIAL。

## Blocked by

- 05
- 08

## Comments

### 2026-10-03 实现（待全量验收回填）

- 运行时：`DummyState.GROUND_BOUNCE` 全新状态机（进入→触地前窗口→bounce_contact 反弹一次→统一追击窗口→自然回中立/空中受身，不转倒地）；`HitProfile.TargetState.GROUND_BOUNCE`（第 4 目标状态）与 `Reaction.GROUND_BOUNCE`（第 7 反应）；profile 只声明进入运动与触地前窗口，反弹速度 330／追击窗 16 为统一流程参数（GameParams，时间/轨迹层换算）。
- 修正：`STARTER_BOUNCE_FOLLOWUP`（A=0/B·C·D=1）于 GROUND_BOUNCE 进入时派生；`BOUNCE_HIT_*`（0.88/0.92/0.93）与 `LANDING_LINK_HIT_*`（0.94/0.95/0.95）分层每击倍率入 GameParams；`move_via_air_link` 标记落地连接起手的招式。A 起手弹地后命中以新结束原因 `BOUNCE_END` 立即收尾。
- 弹地等待语义（新）：j214D 命中后攻击者常先于触地落地恢复——空技延迟普通连接评估推迟到 bounce_contact 开窗（等待期动作缓存不被独立起手窃取），「触地后按剩余硬直接 5B/6A/214C」由此达成；窗口有界（触地前受身/收招未接续按既有口径断链）。
- 资源：新建 `data/moves/j214D.tres`（9/4/22、伤 20、52×36 gap 4、motion 12/64、SPECIAL 层）；jA/jB/jC cancel += j214D、6D/2D air_exit += j214D；5B/6A/214C 新增弹地目标键（LAUNCH 追击资料）；旧地面 214D 保留至阶段 9 迁移（与 j214D 分属不同姿态，无输入冲突）。
- Solver：`_dummy_pursuable` 纳入弹地（仅触地后）、状态文本 bounce、SCOPE_TEXT 移除「地弹不支持」并追加票据 09 扩展（含循环状态键与 replay-required 边界）；settlement_state 自动携带 bounce_contact/bounce_left/bounce_followup 与 via_air_link。
- 测试：`tests/test_bounce_corrections.gd`（83 断言全过：表项/校验拒绝/独立输入/双入口/A 收尾/一次性消费与不刷新/非 OTG/被防挥空不锁定/落地连接分层/slide·Rekka 跨越保持/236C>5D 循环负例/结算键）；`tests/acceptance_replay_09.gd`（R0/R1/R2 双面向 + N1–N4 反例全过）；迁移 test_smoke 临时 j214D 用例为共享表真招式路径、test_move_table 边界断言随表更新（j214D 接线/枚举顺序/target_state 枚举范围）。
- 观察项（EXPERIMENT_REQUIRED）：见 frame-data.md 票据 09 节（触地节拍、目押窗 3–4 帧、5B 弹地 untech 18 撑不满二段延长、airborne 触地前窗深连段余量）。

验收：2026-10-03 实现完成，证据见 [acceptance/09/](../acceptance/09/)（回放 R0–R2/N1–N4 双面向、单元 83 断言、全量与 Solver 证据见 report 回填）。待真人：弹地速度与触地节拍、A/B/C/D 起手手感、B+ 一次性继续的目押容差。

### 2026-10-03 性能诊断与防线

- 复盘发现超长 solver 的真正成本在单请求内部：循环证明的延迟笛卡尔积（每个 jump 槽最多 41 个值，证明模式无 64 叶预算）以及扩展接续图带来的可读路线叶爆炸；并行/缓存只能分摊或复用，不能解决首次请求。
- `ComboSolver` 现在对证明搜索使用真实 CombatSession 前缀剪枝；对包含 GROUND_BOUNCE/滑行反应的循环使用严格递减 `time_scale` 状态不变量，直接证明回边不能重现；可读路线最多输出 64 条，并在 notes 明确标记集合未完成。
- 诊断记录：[solver-performance-09.md](../solver-performance-09.md)。后台 09 runner/worker 已停止，进程证据保存在 `.scratch/solver-scalability/`。

### 2026-10-04 可扩展性 P3–P6 叠加与 P7 终差分、默认切换（全量验收回填）

- 在途叠加（均未提交，feature 分支工作树）：P3 checkpoint 前缀 trie（`SessionCheckpoint`/`TransitionMemo`/`CompiledSchedule`）、P4 CycleInvariant + delay DP、P5 路线/循环/空间层重构（SCC+Johnson 保序环枚举、叶 trie 登记、complete 模式 + 看门狗 + resume_analysis）、P6 可复用 worker 池（`tools/solver_pool_worker.gd`，run_acceptance `--sweep` 默认 pool；spawn 降级差分 oracle）。
- 恢复等价修复（2026-10-04 两票已 resolved，`.scratch/solver-restore-equivalence/issues/01`）：循环证明每圈独立 `ChainLink` 克隆（别名污染根因）+ memo scope 并入编译调度语义（compiled-scope 契约，`tests/test_solver_restore_schedule_scope.gd`）。
- P7 终差分（`.scratch/solver-p7-01/`）：默认表 `solve()` 六开关全栈对拍新/旧路径指纹逐字节相等（105c43c7…，冷 89.7s/热 70.9s/旧路径 1031.8s＝11.5×）；HEAD 锚点复现 e071fd 并证明 e071fd↔abfc 的跨期差＝票据 04 恢复别名在 79 边表的既有缺口（字段级 diff 隔离到 6 条空中链循环注记），P7 树为干净语义（ADR 0006 修订七记账）。
- `_sweep_replay` 补漏 `SolverOptions.complete` 重建（complete 模式请求此前必被重建门拒绝；定向 sweep 复证 4/4）。test_move_table 2 条 analyze_manifest 的可变 manifest 带外重放缺口开票：[solver-p7-01/issues/01](../../solver-p7-01/issues/01-mutable-manifest-replay-gaps.md)。
- 全量验收（79 边表首个完整跑）：74 唯一请求 complete 71 / failed 3，总墙 483.6s（清扫 370.9s，8 车道饱和 0.758，最长单请求 229.6s）；3745 断言全过；票据 09 在途 FAIL 族与 P0 时代逐字一致（combo 11 条 FAIL 行 diff 为空），无新增失败；阶段门 13 套全绿 + runner 单测 29/29 + spawn↔pool（含两次实机击杀续算）缓存 30/30 字节全等。证据：[acceptance-full](../../solver-p7-01/acceptance-full/)、REPORT.md。
- 回滚：六差分开关逐层回退 + 清两层缓存（`--sweep-mode spawn` 回退清扫层）；别名修复与 compiled-scope 无行为回退开关（回退＝回到已知 bug）。恢复别名修复后默认表 solve/analyze 指纹自 e071fd/85ec8b 旋转为 105c43c7/bb638738——已裁决为 bugfix 语义修正，旧 Tier B 归档对照时按修订七记账。
