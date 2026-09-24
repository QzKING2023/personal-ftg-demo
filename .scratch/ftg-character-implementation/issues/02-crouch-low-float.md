# 02: 蹲姿普通技与低浮空扫倒

Status: implemented
Type: AFK
Stage: 3
Blocked by: 01
验收：2026-09-24 完成，证据见 [acceptance/02/report.md](../acceptance/02/report.md)（回放双面向日志、全量测试与正反例断言位置）。2D 高度不匹配负例与 2C 的 214C 出口为已声明的交付边界（分别待票据 07/04）。

## What to build

交付 2A、2B、2C 的姿态绑定、low 属性和可观察受击转换。2C 命中后进入 LOW_FLOAT_SWEEP，短暂低浮空后在触地转换为 GROUND_KNOCKDOWN；把该状态、倒地计时和连段结束事件接入训练场与 Solver。保留 2A/2B 的地面普通链，并让 2C 的后续入口由显式配置决定。

## User stories covered

3, 4, 5, 18, 19, 22, 23。

## Acceptance criteria

- [x] 2A/2B/2C 只能在合法地面姿态启动；2A/2B 是 low，站防可挡、蹲防可按规则处理，属性来自资源而非 id 推断。（新增 `requires_crouch` 姿态限定：当帧下方向 ∈ {1,2,3}（斜下含）才是单键候选，空中回落 jA；持续按住下连续按键不需方向重建段——`_test_crouch_normals_select_by_down_state`、`_test_crouch_rapid_repress_without_direction_reentry`。属性 LOW 来自 .tres。）
- [x] 2C 命中 grounded 目标后进入 LOW_FLOAT_SWEEP，记录低浮空计时、运动和触地事件；触地转 GROUND_KNOCKDOWN，进入时结束连段，倒地期间不接受 OTG。（`HitProfile.Reaction.LOW_FLOAT_SWEEP`：受击窗口入 hitstun 计数、倒地计时按时间层预换算入 knockdown 计数；触地同帧转换发 `LOW_FLOAT_LANDED` 并以运动阶段先于取消窗口关闭结算的顺序结束连段——`_test_2C_low_float_sweep_lifecycle`、`_test_2C_low_float_corrections_and_combo_end`。）
- [x] 2C 的 grounded/airborne profile 按精确键选择；缺失 profile 不回退到普通 grounded 命中。（2C 仅声明 grounded normal/counter；对空 HIT_MISS 负例见 `_test_2C_airborne_target_miss_no_profile`；MoveTable 校验拒绝 AIRBORNE 键的 LOW_FLOAT 资料。）
- [x] 正例：2A > 2B、2B > 2C、2C > 214C~B（在 04 完成后接通）。（会话正例 `_test_crouch_chain_route_2A_2B`、`_test_stand_chains_into_crouch_5A_2B_5B_2C`；Solver 路线 `2B → 2C` timing-valid、`2A → 2B → 5C → 5D` 成立。214C 出口待票据 04。）
- [x] 反例：2C 后以普通 5D 因 startup／剩余硬直失败、2C 后以 2D 因高度失败、倒地期间命中刷新倒地计时、被防或挥空进入低浮空。（5D：`_test_2C_then_5D_fails_and_no_otg`——窗口关闭当帧 LINK_FAILED/CONFIGURATION_GAP + 独立 5D 全程倒地不可命中、倒地计时 F58 不受刷新；挥空：`_test_2C_whiff_no_low_float`。2D 高度负例待票据 07 交付 2D 资源后接通——当前表内无 2D，属已声明边界。被防负例待票据 03 的木桩防御入口。）
- [x] 训练场显示 LOW_FLOAT_SWEEP、触地、GROUND_KNOCKDOWN 和连段结束原因；Solver 区分允许的普通连接与 state-incompatible。（HUD 状态行新增「低浮空（N）」、事件行显示触地与连段结束原因；Solver `_dummy_pursuable` 覆盖 LOW_FLOAT、MISS_NO_PROFILE/截断按原文上报。）
- [x] 低浮空状态沿用当前 starter grade 和三层修正，不重新起手；状态结束时清除修正。（`_test_2C_low_float_corrections_and_combo_end`：B 起手三层跨浮空保留，触地转倒地清除回 UNSET/1.0。）

## Solver and replay scope

Solver 支持 LOW_FLOAT_SWEEP 到 GROUND_KNOCKDOWN 的有限状态转换，并报告 height-mismatch、timing-invalid、state-incompatible。固定高度的静态结果不能证明真实扫倒距离；真实低浮空节拍在阶段 9 的回放中复验。

## Human judgment

无需先行真人批准；2C 的触地节拍和 5D/2D 负例按初表自动验证，手感调整列为后续 HITL 内容。

## Blocked by

- 01

