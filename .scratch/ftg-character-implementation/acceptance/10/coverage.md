# 票据 10 逐招覆盖核对

日期：2026-10-05。对照对象：`docs/player-character-move-design.md`（2026-09-23 基线）§1–§8 与 `spec.md` §8 取消矩阵。
数据来源：`data/move_manifest.tres`（23 招）实测探针 `coverage-dump.txt`（本目录）；接续/资料/标记字段全部为资源事实。
帧数为 startup/active/recovery（60Hz）；「资料」栏 n/c = normal/counter；证据列为该行为的主自动化归属。

## 逐招核对表

| 招式 | 设计职责（基线 §2/§3） | 资源事实 | 核对结论 | 主证据 |
| --- | --- | --- | --- | --- |
| 5A | 徒手最快确认/打断，A 起手 | mid、A 键、5/4/10、伤 8、A 起手；链式 5B/2B、必杀 236C/214C、连接 5B | 一致 | replay_10 J0/J1a、test_move_table |
| 2A | 徒手低位确认 | low、A 键、5/4/10、蹲姿限定；链式 5A/2A/5B/2B、必杀 214C | 一致 | test_crouch_stationary、replay_01 |
| 5B | 徒手前送连接、主要浮空组件 | mid、6/5/12、B 起手；grounded n/c + 弹地键（u18/24）；链式 5C/2C/6A/5D、必杀 236C/214C、连接 5C/5D | 一致（弹地资料随票据 09） | replay_10 J1、test_bounce |
| 2B | 徒手次位连接 | low、蹲姿限定、7/5/12；链式 5C/2C/6A | 一致 | test_crouch_stationary |
| 5C | 短刀重地面连接、非 launcher | mid、8/5/16、C 起手；链式 6A/5D、必杀 236C/214C、连接 5D；**无 jump cancel** | 一致 | replay_10 J0/J5 |
| 2C | 短刀扫倒、低浮空入口 | low、9/3/18；LOW_FLOAT 资料（触地转倒地）；链式 6D/2D、必杀 214C | 一致 | replay_10 J2/J8、test_smoke |
| 6A | 短刀专用击飞（A 键出刀型） | **high**、指令 6A、8/6/20、C 起手；LAUNCH u36/42 + 弹地键；jc jA/jB/jC（仅实际 HIT） | 属性 high 与设计「中段」措辞不同——按资源事实记录，属性是否改 mid 属调校轮 | replay_10 J5/N1a、test_hit_profiles |
| 5D | 短刀地面位移/换边点 | mid、7/4/18、motion(72,0)；grounded/airborne/slide 三组资料；来源限定连接 5B；蓄力 8→5[D] | 一致 | replay_10 J3a/J4、test_charge_motion_sideswap |
| 5[D] | 蓄力版更远更慢 | mid、7/4/22、motion(120,0)、charge_only、镜像三组资料、来源限定连接 5B | 一致 | replay_10 J3b、test_charge_motion_sideswap |
| 6D | 短刀斜上对空限定 | mid、指令 6D、9/4/20、motion(88,−48)；**无 grounded 键**（对地 MISS_NO_PROFILE）；空出口 jA–j214D 全集 | 一致 | replay_10 J0/J8、test_air_d_landing |
| 2D | 短刀垂直拦截对空限定 | mid、蹲姿限定、8/4/18、motion(0,−64)、y_offset −70；无 grounded 键；空出口全集 | 一致 | replay_10 N4、replay_07 R3a |
| 236C | 两段判定：浮空/ground slide | mid、指令 236C、6/2/22（段 2 由 segments 承载）；段 1 grounded→LAUNCH u32、airborne→u34；特殊进入 5D（仅命中） | 一致（段 2 资料在 236C.tres segments） | replay_10 J3a/N1b、replay_05/06 |
| 214C | 首段 mid，命中/被防开派生窗 | mid、指令 214C、8/4/20；grounded n/c + airborne n/c（u28/34）+ 弹地键（u28/34）；Rekka ~B/~C 首按锁定 | 一致 | replay_10 J2/J5、replay_04 |
| 214C~B | low 地面倒地/空中延长 | low、7/3/18、rekka_only；grounded KNOCKDOWN 30/30、airborne LAUNCH u36/44；连接 5B | 一致（counter 倒地与 normal 同 30：TUNING_INITIAL 事实） | replay_10 J2、test_hit_profiles |
| 214C~C | overhead 直接收尾 | overhead、9/3/24、rekka_only、**收尾**；grounded KNOCKDOWN 30、airborne 向下击落资料 | 一致 | replay_10 J0、replay_04 spike |
| jA | 徒手最快空中确认 | high+air、4/6/10、A 起手；grounded s12/airborne u12；命中确认 jB/jC/j5D/j6D/j2D/j214D | 一致（无 counter 资料为设计允许的可选配对） | replay_10 J7、test_air_d_landing |
| jB | 徒手空中连接 | high+air、4/6/12、B 起手；airborne u20（票据 07 对齐）；命中确认 jC/三 D 系/j214D | 一致 | replay_10 J5/J7 |
| jC | 短刀空中重连接 | mid+air、7/5/14、motion(4,0)、n/c 全配；命中确认三 D 系/j214D（进 j214D 最低等级） | 一致 | replay_10 J5/J6 前缀 |
| j5D | 短刀水平收束 | mid+air、6/4/16、motion(74,0)；**无取消/无连接/无落地特权/非收尾标记** | 一致（收束靠取消窗自然关闭） | replay_08 R3、test_air_d_landing |
| j6D | 短刀斜下速降 | mid+air、指令 6D、7/4/18、motion(68,26)；连接 5B（落地恢复后延迟普通连接） | 一致 | replay_10 J8b、replay_08 R2 |
| j2D | 短刀垂直带落地 | mid+air、指令 2D、8/4/20、motion(0,70)、落地+2（仅挥空/被防路径）；落地取消仅 214C（窗 24） | 一致 | replay_10 J5/J8a、test_air_d_landing |
| j214D | 短刀统一弹地 | mid+air、指令 214D、9/4/22、motion(12,64)；grounded/airborne 全 BOUNCE 资料（u12/16/24/30）；**不声明弹地目标键**；连接 5B/6A/214C | 一致 | replay_10 J6/J7/N5、test_bounce |
| BC | 普通投 | 无键（I+K 组合）、5/11/10、投距 64；无资料、不可被防三字段（投不得声明） | 一致 | test_combat_session 投族、test_smoke |

## 旧资源迁移结论

| 旧项 | 处置 | 证据 |
| --- | --- | --- |
| 地面 `214D` | **已移除**（设计 §5「地面 214D 已移除」；票据 10 从 manifest 与资源删除）。识别主体迁移：214 后撤指令的输入识别测试改用 214C（C 键配对 +3 帧）；倒地生命周期样例迁移为注入探针 214P（同形同值）；收尾回边样例迁移至 214C~C；5B 场景改为「窗口关闭后独立起手 214C」 | J0 断言、test_move_table/test_hit_profiles/test_combat_session/test_smoke/diagnose_inputs/test_solver_entry/test_solver_route/test_combo_solver 八套迁移 |
| 单一 `jD` | 票据 08 已拆为 j5D/j6D/j2D 并移除（本轮 J0 复核不在表） | J0、replay_08 |
| `hit_result`/`hitstun_frames`/`knockback`/`knockback_up` | 早已删除，无回退（本轮表加载零错误复核） | J0 表加载、test_move_table 拒绝路径 |

## 帧表与文档对账（阶段 9 统一复检项）

- **6A**：在役 8/6/20、命中框 64×60（承载 853+ 既有断言）；frame-data v0.11 的 8/5/20、38×48 是未落表初稿。本轮以在役值为准，frame-data v0.12 注记对账（不改资源）。
- **236C 基础伤害**：在役 8（move-data.md 旧文写 18，系陈旧文档）；以资源为准，本轮重写 move-data.md。
- **6A 属性**：在役 high；设计基线行文「站立中段」。不改行为，登记为调校轮候选（改属性会改变防御矩阵交集，须复验站防/蹲防测试）。
- 2C LOW_FLOAT 资料的 untech 数值在资源内为独立声明（探针未展开反应参数全量），行为由 test_combat_session/replay_04 既有断言承载。

## 自动化映射小结

- 表级绑定/接续断言：`tests/acceptance_replay_10.gd` J0（23 招全查 + 取消矩阵要点 + 旧资源迁移断言）。
- 帧数/伤害基线：`tests/test_move_table.gd`（manifest 序 + 逐招窗口）。
- 资料合法性/精确匹配：`tests/test_hit_profiles.gd`。
- 逐路线回放：`tests/acceptance_replay_01..10.gd`（票据 10 联合口径见 `replay-joint.log`）。
- Solver 边图一致性：`tests/test_combo_solver.gd`（79 边基线维持——214D 无出边亦非任何声明目标，移除不改变边图；缺口枚举集合随候选目标减少而收缩，无计数断言依赖）。
