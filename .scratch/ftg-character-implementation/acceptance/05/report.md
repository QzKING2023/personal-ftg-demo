# 票据 05 验收报告：236C 两段、ground slide 与来源限定 D

日期：2026-09-25。参数版本：frame-data.md **v0.7**（TUNING_INITIAL）。运行环境：Godot 4.5.1 headless。
证据：本目录 `replay-routes.log`（双面向真实位移回放）；全量自动化见 `full/`（run_acceptance.ps1 输出）。

## 资源与参数版本

- `data/moves/236C.tres`：两段判定（段 1 6/2 基础字段 + 段 2 `MoveSegment` 间隔 3/active 2，全长 35 帧，伤害 8/12，mid）；jump cancel 声明移除（6A 承担 launcher，负例）；`special_entry_targets=["5D"]`、窗口 16 帧。
- `data/moves/5D.tres`：新增 airborne（LAUNCH 32/170/80）与 slide（`GROUND_SLIDE` 键 LAUNCH 32/170/60）捞起资料；`special_entry_link_targets=["5B"]`。
- 新 schema：`HitProfile.slide_frames`、`HitProfile.Reaction.LOW_FLOAT_TO_SLIDE`、`HitProfile.TargetState.GROUND_SLIDE`、`MoveSegment` 资源、`MoveData.segments/special_entry_targets/special_entry_window_frames/special_entry_link_targets`；MoveTable 整表校验（段内资料、slide 键仅捞起 LAUNCH、特殊进入成对声明、跨招式引用与姿态一致）。
- GameParams：`SLIDE_HIT_DAMAGE/TIME/TRAJECTORY_SCALE = 0.92/0.96/0.96`；旧 `MOVE_236C_*` 常量同步为对照值。
- Solver：`_link_press_wait` 命中→收招正常帧距离修正为 `total - startup - 1`（命中当帧招式推进在停顿前完成的既有差一）。

## 回放输入（replay-routes.log，全部保留真实位移/击退，无钉位）

| 场景 | 起始间距 | 面向 | 输入要点 | 结果 |
| --- | --- | --- | --- | --- |
| R1 前置浮空捞起+目押 | 70px | ±1 | 2/3/6+C@F4；D@F26；B@F66 | 段1 F13（8.0）、段2 F26（10.8）→ 特殊进入 5D F41（14.6，airborne 覆盖）→ 5B 目押 F76（5D 收招 F70 当帧消费，8.7）；4 hit 42.1；F95 自然恢复 |
| R2 slide 捞起 | 93px | ±1 | 同上，D@F30 | 段1 挥空（91–97px 窗口）→ 段2 F18（grounded LOW_FLOAT_TO_SLIDE）→ 触地 F36 SLIDE_STARTED（17 帧）→ 5D F37 以 slide 倍率捞起（16.6 = 18×0.92）；2 hit 28.6 |
| R3 段1 命中当帧取消 | 70px | +1 | D@F14（停顿内） | 恢复首帧消费，段 2 不执行；仅一次 236C 命中 + 5D F29（16.2） |
| N1 段1 被防终止 | 70px | ±1 | 木桩站防至 F40；D@F15 | F13 BLOCKED seg1（整招终止、停顿后玩家回中立）；D 只成独立 5D 且 F29 再次被防；全程 0 命中、资格从未开放 |
| N2 资格过期 | 70px | +1 | D@F53（连段 F51 已结束） | 独立 5D 命中已恢复的木桩为**全新连段首击**（F64，18.0），无来源限定边 |
| N3 slide 资料门 | 93px | +1 | 注入表去 5D slide 资料 | 5D F37 HIT_MISS（无 (GROUND_SLIDE, normal) 资料，不回退）；滑行照常 F53 恢复 |
| N4 普通 5D 反向 5B | 70px | +1 | 5A@F1>5B@F5>5D@F21>5B@F38 | 3 hit 后连段结束，迟到的 5B 不构成出口（与既有 `_test_normal_5D_has_no_reverse_5B` 同口径） |

A 起手循环边界（会话测试 `_test_a_starter_slide_cycle_breaks`）：事件驱动循环 `5A > 236C > 5D > 5B > 236C…`，A 起手时间层下目标在 5D 中途自然受身，5B 目押报 LINK_FAILED/TARGET_RECOVERED 断链——不形成 slide loop，无全局命中数/时长上限参与。

## 失败断点与修复记录

1. 独立起手 236C 的段 2 被「连段内合法接续」门挡住 → `_can_hit_dummy` 允许本招已命中（`_move_hit_confirmed`）后的后续段（S-02 段 2 顺序机会）。
2. 取消窗关闭先于特殊进入窗口/来源限定连接评估就结束连段 → 延迟到资格窗口关闭/完全恢复（`_phase_consume_buffer`）。
3. Solver `_link_press_wait` 差一：命中→收招正常帧距离实为 `total - startup - 1`；修正后 `5D → 5B` 来源限定连接在 solo 236C（D 起手）上下文 timing-valid，规范 A/B/C 入口下如实排除。
4. 5D 捞起后 5B 目押窗口差 1–2 帧 → 5D 捞起资料 untech 30→32、up 180→170（TUNING_INITIAL）。

## Solver 结论（静态证明边界）

- 接续边 36 条（有效 29）：新增 `236C → 5D`（特殊进入，有效等待 0–16 帧，命中时目标状态 airborne/grounded-stun）与 `5D → 5B`（来源限定连接，solo D 起手上下文）；236C→jA jump cancel 边移除。
- 路线 96 条 timing-valid 含 `5B > 236C(两段) > 5D`（4 hit）与 `5A > 5B > 6A > jc.jA > jB > jD`（6 hit，41.3——6A launcher 迁移后的完整空中路线）。
- 结构性循环 `236C → 5D → 5B → 回到 236C` 逐圈模拟**断开**（目标自然受身），无有效循环证明；快照键新增 slide 计时、逐段命中标记、特殊资格与来源标记。
- 明确 replay-required：段间真实可达性（段 1 挥空需 91–97px 站位，钉位网格 48/64/80 不覆盖）、slide 捞起距离、D 后 5B 的真实空间可行性。静态钉位证据与真实回放证据分开记录（本报告回放全部保留真实位移）。

## 待真人（EXPERIMENT_REQUIRED）

slide 可视位移偏小（约 9px，加大击退挤占 5D 捞起距离）；特殊进入 16 帧窗口手感；R2 捞起后 5B 中远距可达性（依赖票据 06 计划位移）；段间距离窗口实机搓招可达性；236C 自身计划位移（28/36）未实现（票据 06 边界）。

## 全量自动化（acceptance/05/full）

- 全部测试文件 exit 0：test_combat_session（850 PASS）、test_combo_solver（487 PASS，841 秒——路线图含来源限定回边后延迟搜索变慢，已按观测上限声明）、test_crouch_stationary、test_hit_profiles（105 PASS）、test_input_normalization、test_joint_acceptance、test_move_table、test_replay_acceptance、test_smoke、diagnose_inputs（全绿）、test_solver_cycles、test_solver_entry（49 PASS）、test_solver_route、test_solver_spatial（全部 ALL PASSED；后四者因默认表分析变慢以加长超时串行补跑，日志见 full/）。
- 性能备注：可读路线枚举上限 8 招 + 路线延迟搜索 64 向量观测上限（SCOPE_TEXT 已声明，循环证明不受限）——成功路线不受影响（字典序首个成立向量返回），全部失败的路线按走得最远的失败如实上报。

## 结论

票据 05 验收清单全部满足：两段判定/段间失败关系、slide 状态机（独立计时/覆盖命中/自然回中立/无 OTG）、来源限定 D 进入（授予/消费/清除）与 5B 目押（来源限定、恢复后消费）、修正跨状态保留与 slide 分层倍率、A 起手循环边界。阶段 5 剩余：票据 06（蓄力 D、计划位移、扫掠、穿越换边）。
