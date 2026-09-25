# 05: 236C 两段、ground slide 与来源限定 D

Status: implemented
Type: AFK
Stage: 5
Blocked by: 01, 03
验收：2026-09-25 完成，证据见 [acceptance/05/report.md](../acceptance/05/report.md)（全量自动化、双面向真实位移回放 R1–R3/N1–N4 与 A 起手循环断点）。待真人：slide 可视位移偏小、特殊进入窗口手感、R2 后 5B 目押中远距可达性（依赖票据 06 计划位移）。

## What to build

交付 236C 两段判定和有限 GROUND_SLIDE 路线，并让实际命中的 236C 在命中当下取得一次性 SPECIAL_D_ENTRY_FROM_236C 资格，进入普通 5D。前置浮空与 slide 都能被普通 5D 命中覆盖；D 后的 5B 只作为 D 完全恢复后的普通连接，不创建特殊 D 或特殊 B 身份。

## User stories covered

9, 10, 18, 19, 21, 22, 23。

## Acceptance criteria

- [x] 236C 段 1 与段 2 有独立 active、profile 和事件；段 1 被防立即终止整招，段 1 挥空不追踪但段 2 按自身 active 继续。（`MoveSegment` 资源 + `MoveData.segments`；会话 `_segment_hit_done` 逐段命中一次、`_apply_player_blocked` 段 1 被防 `_clear_current_move`；HIT/HIT_MISS/ATTACK_BLOCKED 事件携带 `move_segment`；`_test_236c_two_segments_windows_events_and_states`、`_test_236c_seg1_blocked_terminates_whole_move`。）
- [x] 两段实际 HIT 各自取得一次性 D 特殊进入资格；BLOCKED、MISS、缺失 profile 不取得。（`_apply_player_hit` 实际命中路径授予 `_special_entry_open`，段命中各自重置窗口；`_phase_cancel` 仅在 `_special_entry_live()`（授予招式执行中 + 窗口内）开放目标；被防/挥空/HIT_MISS 路径不经过授予；`_test_special_d_entry_pickup_and_5b_link`、`_test_236c_seg1_blocked_terminates_whole_move`、`_test_slide_pickup_requires_explicit_slide_profile`。）
- [x] 段 2 命中 grounded 目标产生浮空并在触地转 GROUND_SLIDE；命中 airborne 目标使用独立空中资料；slide 目标无显式资料则无命中。（新反应 `LOW_FLOAT_TO_SLIDE`（slide_frames 预换算）+ 新目标状态键 `GROUND_SLIDE`；`_motion_dummy` 触地转换发 `SLIDE_STARTED`；`_dummy_target_state` 精确匹配不回退；`_test_236c_seg1_whiff_seg2_ground_slide_lifecycle`、`_test_slide_pickup_requires_explicit_slide_profile`。）
- [x] GROUND_SLIDE 有独立计时、覆盖式命中和自然回中立事件；不接受通用 OTG，不与普通倒地混用。（`dummy_slide_left` 自触地下一正常帧倒数、归零 `DUMMY_RECOVERED` 回中立并结束连段；有效命中按新资料整体覆盖（5D slide LAUNCH）；路径不经过 KNOCKED_DOWN；`_test_236c_seg1_whiff_seg2_ground_slide_lifecycle`。）
- [x] 特殊资格只绑定本次连段和当前目标，在启动普通 5D 时消费；窗口关闭、目标恢复、倒地或连段结束时清除。（`_start_move` 消费并置 `_move_via_special_entry`；`_end_combo`/`_clear_current_move`/窗口过期关闭；`_test_special_d_entry_expired_window_is_independent`、`_test_special_d_entry_pickup_and_5b_link`。）
- [x] 正例：236C 段 1 命中 > 普通 5D；段 2 命中 > slide > 普通 5D；D 完全恢复后在剩余硬直与距离成立时普通连接 5B。（R3：段 1 命中当帧取消跳过段 2 后 5D 命中；R2：@93px 段 1 挥空→段 2→slide F36→5D F37 以 slide 倍率捞起；R1：两段→5D F41→5B 目押 F76（5D 收招 F70 当帧消费）；回放 acceptance/05/replay-routes.log。）
- [x] 反例：段 1 被防仍进入 D、段 1 挥空追踪、236C 被防取得 D 资格、普通 5D 直接反向接 5B、slide 目标借普通 grounded profile 命中、D recovery 中打断进入 5B。（N1 被防零命中零资格；挥空段 2 不追踪（每段几何独立判定）；N3 slide 无资料 HIT_MISS 且滑行照常；普通 5D 的 5B 缓存在收招时报 CONFIGURATION_GAP 或按独立招式继续（`_test_normal_5D_has_no_reverse_5B`）；5B 只在 5D 完全恢复帧起手（R1 F70，恢复期间 `_resolve_pending_link` 不打断）。）
- [x] 起手修正跨浮空与 slide 保留；A starter 不因 slide 自动形成 loop。（修正只在 `_end_combo` 清除；slide 命中使用 SLIDE_HIT_* 分层倍率（0.92/0.96/0.96）；`_test_slide_corrections_and_starter_lock`；A 起手循环 `_test_a_starter_slide_cycle_breaks` 实测断于 5B 目押（目标先恢复，LINK_FAILED/TARGET_RECOVERED），无全局上限参与。）

## Solver and replay scope

- [x] Solver 支持 236C 两段状态（多段命中逐段预测与逐帧复验——`5B > 236C > 5D` 路线 4 hit timing-valid）、slide 覆盖（滑行状态/资料门/分层倍率/状态键由真实结算承载；钉位网格 48/64/80px 上段 1 恒先命中，不产生 slide）、来源资格消费（`SPECIAL_ENTRY` 边：仅命中开放、报告命中时目标状态集合）与普通连接分类（`SPECIAL_ENTRY_LINK` 边以 solo 起手上下文验证，规范 A/B/C 入口下如实排除）。段间真实可达性（>91px）、slide 捞起距离与 D 后 5B 真实空间一律 replay-required，静态报告不冒充（`_test_special_entry_edges_and_slide_scope`、SCOPE_TEXT 声明）。
- [x] 结构性循环 `5B > 236C > 5D > 5B` 只产生断链/未完成观测，不形成有效循环证明；快照键新增 slide 计时、逐段命中标记、特殊资格与来源标记（settlement_state）。

## Human judgment

待真人确认（不阻塞本票行为验收）：slide 可视位移偏小（触地前后约 9px，加大击退会挤占 5D 捞起距离）；特殊进入 16 帧窗口与命中确认 8 帧窗并存手感；R2 slide 捞起后 5B 目押在中远距不可达（依赖票据 06 的 236C/D 计划位移）；段间距离窗口（91–97px）实机搓招可达性。全部数值 TUNING_INITIAL。
