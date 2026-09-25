# 票据 03 验收记录：木桩防御与被防取消

日期：2026-09-25。票据：`issues/03-dummy-defense-and-blocked-cancel.md`（阶段 4 第 1 票）。
参数版本：frame-data.md v0.5（TUNING_INITIAL；被防三字段落表 8/9 帧、45px/s）。

## 交付内容

- **资源 schema**：MoveData 新增被防结果三字段 `block_freeze_frames`（被防停顿，双方冻结物理帧）、`block_stun_frames`（被防硬直，防守方停顿后不可行动正常帧）、`block_pushback_px_s`（被防推退，停顿后施加给双方的水平速度）——独立于 HitProfile 与命中 Hitstop，逐招显式声明；打击招式缺任一字段整表拒绝，投技声明即拒绝；未声明（哨兵 -1）= 不可被防（默认禁止，无全局回退）。13 个打击 .tres 按 frame-data v0.4 初值迁移（8/9/45），BC 投保持未声明。
- **输入入口**：`FrameInput.dummy_guard_request`（0 无 / 1 站防 / 2 蹲防 / 3 空防，取值同 GuardPosture）——逐帧显式请求，只表达本帧保持的防御姿态；木桩无自主决策。
- **CombatSession**：`dummy_guard`/`dummy_blockstun_left` 可观察量；`_update_dummy_guard` 在输入阶段先于命中判定解析请求——被防硬直期间姿态冻结（连防，与玩家防御硬直同口径）、NONE 不防御；请求不成立按原因可观察拒绝（`DUMMY_GUARD_REJECTED`：STATE=姿态与地面/空中状态不符，不静默回退其他防御；BUSY=受击/倒地/自身招式占用），木桩起手清姿态（与玩家 _start_move 同口径）。被防硬直期间木桩不可按请求出招（硬直结束后的首个输入帧即合法反击时点，R-02 观察口）。
- **被防三分支结算**：`_apply_player_hit` 先判 `_dummy_blocks_attack`（与玩家同一属性矩阵；NEUTRAL 且已声明被防结果的招式才可能被挡）→ 被挡走 `_apply_player_blocked`：`ATTACK_BLOCKED(direction, guard_posture)` 事件、被防停顿（复用冻结机制、长度读招式声明）、被防硬直计时（停顿后按正常帧倒数、被防当帧不消耗）、双方被防推退（速度结果、版边截断沿用既有运动）；不产生伤害/连段计数/starter 锁定/三层修正/命中确认。实际命中与投结果覆盖时清除残留被防硬直。
- **取消资格分层**：接触追踪（`_move_contact_confirmed/_move_blocked/_contact_frame`）。`_phase_cancel` 拆分：命中分支维持原门槛（命中确认 + 连段活跃 + 可追击，三类窗口原样）；被防分支只开链式/必杀窗口（自接触帧按正常帧计龄，Hitstop 不计龄）；挥空无接触无年龄。jump cancel、命中确认取消仍要求 `_move_hit_confirmed`（被防不得借用）；236C→5D 来源资格属票据 05，当前 schema 无该字段可借。
- **训练场**：G 键循环木桩防御训练模式（无→站→蹲→空，逐帧确定性请求）；HUD 状态行显示木桩防御姿态与「防僵 N」、事件行显示「攻击被站防挡下（被防硬直 N）」与防御请求拒绝原因；木桩防御色调与蹲防压缩呈现。
- **Solver**：链式/必杀边新增「被防路径」标注（`blocked_valid/blocked_reason`）——木桩按能挡住来源属性的姿态逐帧请求（low→蹲防、其余→站防），真实结算中验证来源在预期接触帧被防（不产生命中）、目标在被防取消窗口内起手；目标自身接触结果如实入注（再被防/属性漏出命中/MISS_NO_PROFILE/挥空）。被防不是 HIT：标注不进入路线/循环图与邻接表；`_run_schedule` 在预期命中帧收到 ATTACK_BLOCKED 时按 `blocked` 断链分类；报告注记与 SCOPE 声明被防安全性（指定反击/时机/距离/版边/面向）一律 replay-required。快照签名纳入被防字段（跨面向一致性）。

## 回放证据（acceptance/03/replay-routes.log，60 px 身体中心水平，双面向）

- `5A > 5B`（被防链式取消）：F6 5A 被站防（停顿 8、被防硬直 9）→ B 组合等待被停顿吸收、恢复首个正常帧 5B 起手、F21 再被防；F45 释放请求（被防硬直内姿态冻结）、第三记 5A F63 正常命中（starter A、伤 5.8）——命中/被防分支同日志对照。
- `5A > 236C`（被防必杀取消）：停顿中喂 236 + C，恢复后 236C 起手（接触年龄 2 ≤ 窗口 5）、F22 再被防。
- `5A > 2B`（被防转命中混合）：low 从站防漏出，F22 2B 命中并开启全新连段——starter=B、三层修正 0.84/0.82/0.85（A 的被防未锁起手、修正重新起算）。
- 负例挥空（200 px）：无任何接触事件，窗口内 B 从未起手（缓存过期作废）。
- 负例被防不开 jump cancel：6A F9 被站防后按 Space，全程 prejump=0、6A 完整恢复。
- 反击安全矩阵（木桩站防玩家招式，被防硬直结束首个输入帧请求反击 5A；分类按攻击方首个可行动帧 = 招式总长+停顿+1）：
  - 近距 60 px 双面向 × {5A, 5D} × {不防御, 尝试防御}：5A（恢复 F28）不防御时 F29 被反击命中＝「已恢复未防（临界 1 帧）」、按住后方向＝被防；5D（恢复 F38）F31 被反击命中＝确反（两种行为同判）。
  - 中板 100 px × 5D：反击 5A 判定够不着玩家＝距离不足（反击挥空）——安全性结论绑定距离。
  - 版边双面向 × 5D：木桩贴墙推退被截断（x=912.0/48.0 不变），F31 确反不变。
  - 结论绑定当前 TUNING_INITIAL 与上述站位，不扩展为所有距离的普遍安全；手感调校列入待真人判断。

## 自动化证据

- 全量：`acceptance/03/full/summary.json`——与票据 01/02 同款现象（Windows PowerShell 5.1 因测试预期的 stderr 中断官方脚本，停在 test_move_table 的「资源无法加载」负例），前 7 个作业由脚本完成、其余作业以相同引擎参数与判定口径补跑；共 16 个作业全部退出 0、无脚本错误，合计 **2665 PASS**（combat_session 771、combo_solver 214、hit_profiles 105、move_table 214、replay_acceptance 123、smoke 123、solver 系列 cycles 30 / entry 49 / route 322 / spatial 619 等，逐项见 summary.json）。
- 正例断言：test_combat_session 票据 03 组 11 个用例（请求驱动姿态/拒绝可观察、被防独立结果与快照键、属性漏出矩阵、被防开链式必杀、被防禁命中确认与 jump cancel、挥空、被防硬直锁木桩行动与连防、释放转命中、未声明默认禁止、停顿长度读声明）；test_move_table（三字段必填/负值/投技矛盾/清单基线 8/9/45）；test_combo_solver（被防路径标注、low 蹲防探针、2B 漏站防转命中如实入注、replay-required 注记、注入未声明来源拒绝被防变体）。
- 反例断言：挥空（`_test_whiff_still_cannot_cancel`）、被防 jump cancel/命中确认（`_test_blocked_denies_hit_confirm_and_jump_cancel`）、地面 AIR 请求 STATE 拒绝且攻击照常命中（`_test_dummy_guard_rejections_observable` + `_test_dummy_guard_attribute_leak_matrix`）、未声明被防默认禁止（`_test_undeclared_block_fields_default_deny`）。
- 回归：既有玩家防御（guard 矩阵/防僵/连防/受击破防）、投/拆投、HitProfile 精确匹配、Hitstop、自然恢复、资源整表拒绝全部保留（combat_session 771 PASS 全量含旧组；hit_profiles/move_table 全绿）。

## 交付边界（如实声明）

- `236C → 5D/5[D]` 来源资格随票据 05 交付；本票只能证明被防不设命中确认（结构上无来源资格字段可借），其被防负例随 05 接通字段后复验。
- 被防安全性仅覆盖反击 5A 与上述站位/面向/行为组合；反击招式集合与更多距离属真人调校（replay-required 的最终手感）。
- 45px/s 被防推退初值下，攻击方推退在接触当帧被摩擦抵消（位移不可观察）、防守方推退约 +1px——数值可见性待试玩调参（frame-data v0.5 观察项）。
- 木桩空防请求在当前受击状态机下恒为拒绝（空中可行动中立态不存在：浮空受身后为 AIR_RECOVERED，落地才回 NEUTRAL）——STATE/BUSY 两类拒绝原因均可观察，空防的实际挡下待后续有空中可行动木桩状态时复验。
- 5A 被站防 60 px 反击 5A 的「已恢复未防」与「被防」仅 1 帧之差——调校值变更（停顿/硬直/前摇任一）会翻转结论，属 TUNING_INITIAL 观察项而非稳定设计结论。

## Code review 记录（提交前，双轴）

- Standards 轴：1 项硬违规已处置——CONTEXT.md 混有阶段 0–2 未提交词条（短刀/影步/D 系/GROUND_*/面向重写等），提交时选择性暂存仅纳入本票词条（木桩防御请求/被防/链式取消/必杀取消），其余保留为未提交的阶段文档批次。判断项采纳 3 项：玩家/木桩属性矩阵去重为 `CombatSession._posture_blocks`（CONTEXT「同一属性矩阵」单处定义）；`FrameInput.make` 新参补显式 `int` 类型标注；move-data/测试注释的参数版本号同步 v0.5。判断项记录不采纳 3 项：被防三字段的扁平 @export＋哨兵沿用仓库 schema 惯例；迁移测试钉住落表初值与票据 01/02 基线断言同口径；`_run_blocked_probe` 与 `_run_schedule` 的循环同构保持分离（命中预期与被防探针的验证口径不同，合并引入模式分支大于收益）。
- Spec 轴：无缺失、无实现错误项；采纳 1 项字面对齐——spec 要求被防事件「至少记录 BLOCKED、防御姿态、被防停顿、被防硬直和被防推退」，`ATTACK_BLOCKED` 已补齐三值字段（测试断言事件自带 8/9/45）。记录 2 项边界：236C→5D 来源资格负例随票据 05 接通字段后复验（当前 schema 无该字段可借）；木桩空防挡下在当前受击状态机下不可达（空中无中立可行动态），请求协议与拒绝原因已可观察。
- 双轴一致确认：`_phase_cancel` 拆分与拆分前命中路径逐门槛等价；被防只开链式/必杀窗口；被防不入路线/循环图。
