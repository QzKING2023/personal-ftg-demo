# 20: Solver 完整路线与时序验证

**What to build:** Combo Solver 用一次性 CombatSession 逐帧验证方向派生、取消、jump cancel 和落地接续，输出合法路线、配置缺口和失败原因。

**Blocked by:** 13: 宽松指令、替代串与输入优先级; 15: 普通跳、jump cancel 与落地恢复; 19: Combo Solver 入口与操作说明

**Status:** ready-for-human

- [x] 枚举姿态、输入绑定、方向 variant、取消窗口、jump cancel、落地接续和等待帧，并验证前摇、命中、硬直、运动、落地及自然受身。
- [x] cancel_targets、jump_cancel_targets 和 landing-cancel 目标是运行时硬约束；时序成立但缺配置只报告配置缺口。
- [x] 报告稳定排序的合法边、逐帧输入、命中数据和失败断点；挥空、受身和恢复原因可区分。
- [x] Solver 不修改运行时状态，也不以命中数或时长上限掩盖无效路线。

## Comments

**2026-09-17 实现验收记录（agent）**——改动集中于 `scripts/combat/combo_solver.gd`（报告结构 + 缺口枚举 + variant 验证 + 断链分类 + 落地接缝来源链扩展），新增 `tests/test_solver_route.gd`。

- 配置缺口：`_enumerate_gaps` 对未配置的 (from, to, kind) 候选（同姿态取消 / 地面→空中 jump cancel / 空中→地面落地接续）逐个用一次性探针表验证——`_gap_probe_table` 以 `MoveTable._fresh_copy` 深拷贝来源招式并向对应配置数组注入候选后临时换入 `_table`，走与正式边完全相同的 `_build_edge` 逐帧验证，结束即还原；时序成立才进入 `report.gaps`（`valid` 恒为 false，不进入合法边/路线/循环/操作说明，镜像对拍签名新增 gaps 节）。时序或结构不成立（姿态不符、收尾来源、投技、等待超时、接缝对不齐）的候选保持沉默——补配置也不会使其合法。缺口文案点名缺失字段（如「5D 不在 5A.cancel_targets，命中确认取消 是运行时硬约束」）并携带经验证的时序数据（hit_age/recover_age/等待档/落地对齐 lead）。默认表报告 39 条缺口；补配后同一对成为合法边并从缺口消失（双端一致测试）。
- 落地接缝来源链扩展：`_fill_landing_edge` 此前只支持「经空中取消进入」的来源（如 jB，经 jA 取消）；现以 `LandingSeam` 定位类区分两种进入链——PREV_HIT（两维对齐：空中起手延迟 d + 取消等待 v）与 JUMP_FRAME 直接进入（一维，只有 d）。jump cancel 直接进入的空中招式（如 jA）自此可作为落地接续来源枚举与验证；默认表 jA→5D 缺口对齐 lead 6（受 5C 浮空 36f 自然受身约束，配置后正式边验证对齐 6–8，align 样本回放 3 命中且落地帧当帧起手 5D）。
- 缺口模式的落地对齐搜索 `_fill_landing_gap`：按预测对齐 lead（落地帧 − 来源命中帧）分桶，lead 升序、档内取消等待 v 升序逐一完整模拟，首个成立档证明「若配置则时序成立」；不做代表抽样（同档候选行为等价性无先验保证，漏报真实缺口违背枚举目的），唯一剪枝是算术必败的取消等待（v > 取消窗口 − 组合等待，与正式边 wait_to 同式）。不搜索完整 align 范围（那是正式边的报告内容）。
- 输入绑定与方向 variant：`_binding_variant_lines` 对起始姿态下可单键起手的招式枚举全部声明记法（`direction_derivation` + `input_alternatives`，与运行时 `_move_notations` 同口径），逐 variant 在一次性 CombatSession 中验证（喂方向序列 → 按键 → 前摇 → 命中，窗口按该 variant 实际步数 × 10f 计）；宽松指令标注「宽松」，含上方向段（7/8/9，方向历史不可产生）的记法如实报告「不可表达」而非静默跳过。报告新增「输入绑定与方向 variant」节。
- 失败断点分类：`_run_schedule` 把「预期帧未命中」拆为 挥空（目标已起手但判定未在预期帧连接，`session.player_move_id == 预期招式`）与 未起手（取消窗口关闭或缓存过期）；连段计数断裂的措辞点名「木桩已自然受身、连段被重新计数」；空中目标落地作废的排除理由并入「挥空——剩余判定被落地恢复截断」。挥空 / 未起手 / 自然受身恢复三类原因在边排除理由与路线断点注记中可区分（注入不可达命中框的挥空目标有专项测试）。
- 稳定排序与确定性：gaps 与 edges 共用 `_edge_sort_key`（from→to→kind）在 solve() 路径稳定排序，`_edge_signature` 统一边/缺口镜像签名格式（防两处漂移）；solve() 两次运行整报告逐行一致、双面向镜像一致均有断言。
- 一次性探针隔离：缺口探针的注入只作用于私有 `_table` 换入的深拷贝，调用方注入表与共享 manifest 不被改写（测试对 `cancel_targets` 做前后快照对拍）；活动 CombatSession 全字段快照在 solve()（含缺口枚举）前后一致。
- 性能说明：缺口枚举使默认表单次分析增加约 1–2s（test_solver_route 全文件 ~36s、test_combo_solver ~24s、test_solver_entry ~22s）；落地缺口搜索以算术剪枝把必然失败的取消等待档排除在模拟之外。
- 范围说明：timing-valid/spatial-valid 分层与空间探针属 issue 22、循环状态去重/逐圈快照上限报告属 issue 21、回放联合验收属 issue 23，均未提前实现（`MAX_CYCLE_LAPS`/循环机制未动）；落地接续键固定按「落地前一帧按下、落地帧消费」模型调度，更早按下（如 B/C 组合等待在落地前到期）的落地消费不在本轮搜索范围（与正式边同一模型，两侧一致）。
- 验证：新增 tests/test_solver_route.gd（缺口基础事实与不宣称合法、时序/结构不成立不成缺口、补配置转正、直接进入来源的落地接缝与回放、B 键组合等待诚实不报缺口、绑定与 variant 枚举（宽松/超必杀替代串/不可表达）、挥空措辞、恢复与自然受身区分、排序/确定性/运行时隔离/镜像）；test_combat_session（451）、test_combo_solver（112）、test_move_table（129）、test_solver_entry、test_smoke、diagnose_inputs 全绿；主场景无头 300 帧无错误。
