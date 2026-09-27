# 06: 蓄力 D、计划位移与真实换边

Status: implemented
Type: HITL
Stage: 5
Blocked by: 05
验收：2026-09-27 完成，证据见 [acceptance/06/report.md](../acceptance/06/report.md)（单元/回放/全量自动化）。待真人：蓄力阈值可操作性、5[D] 收招节拍、版边穿越手感、扫掠包络边界容差与换边后镜像指令手感。

## What to build

交付普通 5D 与蓄力 5[D] 的动作内蓄力、计划位移、active 帧扫掠、身体穿越约束、版边截断和换边面向。扩展中板蓄力、版边普通 D、手动 665B/665C 的可回放场景，并让方向候选锁定首次相对面向。

## User stories covered

11, 12, 21, 22, 23。

## Acceptance criteria

- [x] D 请求真正启动动作后才开始蓄力；阈值前走普通 5D，达到阈值在最早正常帧自动提交 5[D]；启动前按住和 Hitstop 不积攒。（`MoveData.charge_threshold_frames/charge_move_id/charge_only` + 会话 `_advance_move` 蓄力仲裁：active 边界按住延长 startup、达阈值 `_commit_charge` 自动提交、松开走普通版（提交帧钟回卷至提交版 active_from）；启动前按住无新按下不构成请求（I-01 拒绝例实测）；地面单段 D 的蓄力判定先于本招任何命中，与停顿的交叠情形为空。`test_charge_motion_sideswap.gd`：tap F8 普通命中、按住 F9 提交/F10 命中、暂停中松开 F9 提交普通版、预按住不积攒（F29 提交）。）
- [x] 计划位移在命中前生成，active 使用起点到计划姿态的确定性扫掠，正式位置在运动阶段提交；startup/recovery 不产生扫掠命中。（`MoveData.motion_x/y_px`；`step()` 输入后新增 `_phase_plan_motion()`（累计比例步长，锚点推算无逐帧漂移）；`player_attack_rect()` 取锁定动作方向 + 本帧扫掠的轴对齐包络（无细分采样误差）；`_commit_planned_step()` 在运动阶段提交（版边截断→身体穿越约束）。startup 不位移（实测 0px）、中步扫掠命中（起点姿态挥空、步长跨入命中 F8）。）
- [x] 实际 HIT 且真实终点跨过目标时才换边；BLOCKED、MISS、缺失资料或墙截断停在原侧，不能靠终点穿身或瞬移伪造换边。（实际 HIT 授予 `_cross_ok`（M-02，仅限本动作位移段，招式结束清零）；`_commit_planned_step`：无许可或终点仍与身体重叠时截在移动前所在侧身体边界；中板 236C>5[D] F42 真实穿越（SWITCHED_SIDES + 终点越过）；@70px 普通路径 5D 终点重叠截原侧 -48px；被防截原侧 -48px；版边墙截断标记可观察且不换边、不越界。）
- [x] 命中当帧完成攻击和位移，下一帧才按真实横向关系更新面向；已开始的 214/236 方向候选不因换边重解释。（`_update_facing_after_motion` 每帧运动后按横向关系更新（M-04，含空中）；`_move_direction` 启动锁定驱动本招 hitbox/位移/击退（换边后 hitbox 仍朝锁定方向、击退按原方向实测）；`_direction_ref_facing` + `_command_candidate_active()`：后缀-前缀匹配的已开始候选锁定首次相对面向（换边后新面向前向折为 4、234 断链；新候选按新面向折算；无候选的普通移动照常按当前面向）。）
- [x] 蓄力 D 与普通 D 共用招式身份和换边规则；蓄力版的轨迹、提交时点和修正来自资源。（提交是同一次动作换轨：来源标记（特殊进入/普通连接）、连段与修正保持；`5D_charge.tres` 声明 7/4/22、伤 20、命中框 70×28、motion 120/0、`special_entry_link_targets=["5B"]`；修正跨蓄力提交保留（D 起手 0.96 实测）；MoveTable 校验蓄力对（入口唯一、不链式、不入接续目标、同姿态同键、孤儿拒绝）。）
- [x] 正例：中板 236C > 5[D] 穿越、版边 5D 被墙截断、真实命中后镜像方向继续输入。（acceptance/06 回放 R1 双面向 @50px：F30 蓄力提交、F31 命中、F42 穿越换边、下一帧面向翻转；R5 双面向版边 5D 墙截断；R2a 换边后新候选按新面向折算 236C 起手、R8 换边后 665B/665C 手动场景；另 R3 airborne 段 2 资料、R4 slide 捞起、R6 挥空轨迹继续、R7 被防不穿越。）
- [x] 反例：Hitstop 中蓄力年龄增长、挥空穿到另一侧、被防穿身、startup 路径命中、墙外越界、同帧用新面向重算旧方向候选。（挥空全程 72/120px 不穿越；被防截原侧；startup 0 位移不扫掠；墙截断不出界；R2b 换边后新面向前向折为 4、234 断链。Hitstop 计龄：蓄力判定位于本招首个判定帧前、地面单段 D 结构上无法在蓄力期遭遇停顿（停顿只随命中产生）——判定顺序上由「停顿帧不进入 `_advance_move`」承载，无独立反例可构造，如实记录。）
- [x] 记录计划终点、实际终点、接触结果、墙截断、换边标记和下一帧面向；训练场反馈能区分 rule rejection 与空间不足。（`CHARGE_COMMITTED`/`SWITCHED_SIDES` 事件；`debug_snapshot` 增 charge_age/charged_active/move_direction/cross_ok/motion_wall_clamped/planned_step/direction_ref_facing；训练场诊断行增 蓄力/位移（方向·穿越·墙截）段、事件注记蓄力提交与换边；回放逐帧记录计划/实际终点与接触结果（acceptance/06/replay-routes.log）。）

## Solver and replay scope

Solver 可验证蓄力输入、窗口和固定站位空间，但不搜索自由走位、身体推挤或屏幕边界。真实命中穿越、墙边和双面向必须由保留实际位置的回放证明；报告分别标记 spatial-valid 与 replay-required。

## Human judgment

必须确认扫掠细分／边界容差、版边穿越手感、D 的出刀节拍、蓄力阈值可操作性和换边后继续搓招。自动化结果不能替代这些判断。

## Blocked by

- 05

