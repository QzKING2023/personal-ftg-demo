# 07: 专用击飞、空中普通链与地空出口

Status: implemented
Type: AFK
Stage: 6
Blocked by: 05, 06
验收：2026-09-28 完成，证据见 [acceptance/07/report.md](../acceptance/07/report.md)（单元/回放/全量自动化）。待真人：空中追击节拍、6D/2D 高度容差、出口停顿中按键手感与美术动作对齐（阶段 9）。

## What to build

把 6A 恢复为唯一专用地面击飞入口，交付命中确认 jump cancel、jA/jB/jC 和地面 6D/2D 的真实运动与空中出口。出口必须由显式资源和目标状态决定，不以姿态瞬移替代真实上升、垂直判定或有限空中资源。

## User stories covered

13, 14, 18, 19, 21, 22, 23。

## Acceptance criteria

- [x] 6A 只有实际 HIT 才可 jump cancel；BLOCKED、MISS、缺失 profile 不取得空中追击资格。（既有命中确认窗口机制承载；6A `jump_cancel_targets` 扩展至 `["jA","jB","jC"]`。负例实测：被防 6A 按 Space 无 pre-jump（`_test_6a_blocked_no_jump_cancel`）；挥空 6A 期内 Space 不起跳（`_test_6a_whiff_no_jump_cancel`）；5C/5B 无 jc 声明沿用既有回归。）
- [x] 6A 命中 grounded 目标进入 LAUNCH，按真实垂直速度和受身计时进入 jA/jB/jC；5C/5B 的入口由显式配置决定。（R1 `5A>5B>5C>6A>jc.jB>jC` 六击单连段 F6/21/38/54/75/91：Space F56 停顿中入槽、F63 pre-jump、F67 真实离地；A 起手时间层下 6A 需 5C 命中当帧 w=0 取消才赶上剩余硬直——按帧序如实成立。）
- [x] 6D/2D 只在合法地空和高度范围命中；命中后可直接进入已配置的 jA/jB/jC/j5D/j6D/j2D/j214D。（airborne-only 资料：对地 6D HIT_MISS 可读、2D 高位框无接触；`air_exit_targets=["jA","jB","jC"]`——j5D/j6D/j2D/j214D 未交付，随票据 08/09 接入（追踪见 frame-data 票据 07 观察项）。正例 `2C>6D>jC` F13/31/47 与 `2D>jA` F9/F22。）
- [x] 2C 的低浮空下，2D 因高度不匹配失败；5D 因时序／剩余硬直失败；失败原因可读。（2D active F25-28 期框底 393 恒高于浮空木桩顶 394.7+（垂直不重叠挥空，木桩仍在空中——高度而非时序）；5D F30 LINK_FAILED/CONFIGURATION_GAP（2C 未声明 5D 边，独立起手落在倒地外）。训练场状态行新增木桩空中高度。）
- [x] 6D 的实际穿越遵守 06 的命中、墙和面向规则；空中资源不会因切招自动续期或二段跳。（cross_ok 仅实际 HIT 授予；被防/版边不穿越；88px 在最小合法间距 48px 下终点未越身位——按 M-02 截原侧（正向换边为 motion 调校观察项，如实记录）；滞空中 Space 无第二次上升冲量、出口后滞空按物理回落（R5 F38 落地）。）
- [x] 正例：5A > 5B > 5C > 6A > jc.jB > jC；浮空目标被 6D/2D 命中后进入配置空技。（双面向回放见 acceptance/07/replay-routes.log R1/R2/R5。）
- [x] 反例：6A 被防或挥空 jump cancel、6D/2D 命中地面目标、2C 后 2D 因高度失败、有限空中资源被重复刷新。（R3/R4/R6 + 单元 `_test_6d_ground_target_no_profile`、`_test_2d_ground_target_no_hit`、`_test_air_resource_not_renewed`、`_test_6d_blocked_no_air_exit`。）
- [x] 资源修改同时改变训练场和 Solver；缺失 airborne profile 时两端都报告 no-profile。（`_test_missing_airborne_profile_reports_no_profile`：注入仅 grounded 资料的 6D 表——会话 HIT_MISS、Solver 2C→6D 边按 MISS_NO_PROFILE 断链。）

## Solver and replay scope

Solver 新增 AIR_EXIT 边（实际 HIT + 真实离地 + 命中确认窗口内空中姿态起手；被防不开放），对空限定前招经「使其实际命中的接续上下文」验证（2C 链式进入 6D 打低浮空）；2D 出口在固定钉位下不可达（命中依赖高浮空）——如实排除并标注 replay-required。垂直判定范围（hitbox_y_offset_px）、6D 穿越/墙边与真实空中距离维持 replay-required（SCOPE_TEXT 票据 07 段）。固定站位 spatial-valid 不等于真实空中距离证明。

## Human judgment

本票可用自动化完成首轮；空中追击节拍、6D/2D 的高度容差和美术动作对齐在阶段 9 由真人确认。

## Blocked by

- 05
- 06
