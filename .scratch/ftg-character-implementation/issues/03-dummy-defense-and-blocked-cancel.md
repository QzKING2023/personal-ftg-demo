# 03: 木桩防御与被防取消

Status: implemented
Type: HITL
Stage: 4
Blocked by: 01, 02
验收：2026-09-25 完成，证据见 [acceptance/03/report.md](../acceptance/03/report.md)（全量自动化、双面向回放日志与反击安全矩阵）。被防停顿/硬直/推退手感、指定反击招式集合与不同距离版边的安全性为已声明的待真人判断项（replay-required 的最终手感调校）。

## What to build

为木桩增加逐帧 NONE/STAND/CROUCH/AIR 防御请求，建立玩家攻击的真实命中／被防／挥空三分支，并把被防停顿、被防硬直和被防推退作为独立结果。接通链式／必杀取消的被防资格，禁止被防借用 jump cancel、命中确认取消、专用击飞和来源资格。

## User stories covered

5, 6, 12, 21, 22, 23。

## Acceptance criteria

- [x] 木桩防御只由显式逐帧请求驱动；NONE 不防御，非法姿态请求给出失败原因，不自动改成另一种防御或引入 AI。（`FrameInput.dummy_guard_request`；`_update_dummy_guard`——状态不符→`DUMMY_GUARD_REJECTED/STATE`、受击/倒地/出招占用→`BUSY`，姿态不静默回退；`_test_dummy_guard_request_drives_posture`、`_test_dummy_guard_rejections_observable`。）
- [x] 玩家攻击被木桩挡住时生成 BLOCKED 事件，记录姿态、被防停顿、被防硬直和被防推退；这些字段独立于 HitProfile 命中硬直。（`ATTACK_BLOCKED(direction, guard_posture)`；停顿/硬直/推退读招式 `block_freeze_frames/block_stun_frames/block_pushback_px_s` 三字段（不读 profile），未声明默认不可被防；`_test_player_attack_blocked_independent_result`、`_test_blocked_freeze_uses_declared_frames`、`_test_undeclared_block_fields_default_deny`。）
- [x] 命中、被防、挥空的事件、位置结果、取消年龄和训练场反馈可区分；被防不增加 starter grade 或三层修正。（HIT/ATTACK_BLOCKED/无接触三分支；被防分支零伤害、零连段、starter UNSET、三层 1.0；诊断快照 `blocked_contact/blocked_age`；HUD「攻击被站防挡下（被防硬直 N）」；同前测试。）
- [x] 命中或被防可按逐招配置开放链式／必杀取消；挥空不能取消。（接触追踪 `_move_contact_confirmed/_move_blocked`；被防分支仅开 chain/special 窗口（接触帧计龄）；`_test_blocked_contact_opens_chain_and_special_cancels`、`_test_whiff_still_cannot_cancel`。）
- [x] 被防不能取得 jump cancel、空中出口、236C → 5D/5[D] 来源资格或命中确认取消。（命中确认/jump cancel 仍要求 `_move_hit_confirmed`；`_test_blocked_denies_hit_confirm_and_jump_cancel`——命中确认目标 5X 不起手、Space 无 prejump、链式 5B 同帧成立作对照。236C 来源资格属票据 05，本票无该字段可借。）
- [x] 正例：5A/5B 被站防后按配置进入链式／必杀取消；NONE 下同一招正常命中。（回放 `5A>5B`、`5A>236C` 双面向被防成立、`5A>2B` low 漏站防转命中（B 起手重新锁定）；释放请求后同站位 5A 正常命中——acceptance/03/replay-routes.log。）
- [x] 反例：挥空取消、被防后 jump cancel、被防 236C 特殊 D、地面攻击请求 AIR 防御却静默回退。（挥空与 6A 被防 Space 见上两条测试与回放负例；236C→D 来源资格随票据 05 交付时以负例复验（当前 schema 无来源资格字段）；地面 AIR 请求→STATE 拒绝且攻击照常命中。）
- [x] 用固定反击招式和固定起始距离记录安全性；报告区分“反击命中且攻击方不能防御的确反”和“攻击方已恢复但没有防住”。（反击矩阵：近距 60px 双面向 × {5A, 5D} × {不防御, 尝试防御} + 中板 100px + 版边双面向；分类按攻击方首个可行动帧（总长+停顿+1）与反击命中帧比较——5A 已恢复未防/可挡、5D 确反、中板距离不足、版边推退截断；acceptance/03/replay-routes.log。结论绑定当前 TUNING_INITIAL，不扩展为所有距离的普遍安全。）
- [x] 既有玩家防御和投／拆投回归不改变。（全量 test_combat_session 770 PASS 含全部 guard/throw/tech 组；玩家侧 BLOCKED 路径未动。）

## Solver and replay scope

- [x] Solver 新增 BLOCKED 结果和被防取消边，但不把被防当成 HIT；安全性报告标记 replay-required。（链式/必杀边附「被防路径」标注——站防/蹲防（low 来源）探针、真实结算验证取消时序、目标接触结果如实入注；被防不入路线/循环图；`_run_schedule` 预期命中帧收到 ATTACK_BLOCKED 按 blocked 断链；报告注记与 SCOPE 声明 replay-required。`_test_blocked_cancel_edge_variants`、`_test_blocked_contact_not_treated_as_hit`。）

## Human judgment

待真人确认（不阻塞本票行为验收）：被防停顿/硬直/推退手感（45px/s 攻击方推退在接触当帧被摩擦抵消——数值待试玩）、指定反击招式集合（当前仅 5A）、不同距离和版边的安全性结论扩展。自动化证明确定性结果和事件字段。

## Blocked by

- 01
- 02
